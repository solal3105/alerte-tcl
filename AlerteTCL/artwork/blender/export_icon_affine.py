"""Project the approved model into separate Icon Composer source layers.

The .blend stays native and untouched. Apple receives PNG body parts and SVG
window silhouettes; its own material system supplies the glass on those panes.
"""
from pathlib import Path
import bpy, json, sys
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

ROOT = Path(__file__).resolve().parent
OUT = ROOT.parent / 'liquid-glass' / 'affine'
OUT.mkdir(exist_ok=True)
NIGHT = '--dark' in sys.argv
SUFFIX = '_Nuit' if NIGHT else ''
bpy.ops.wm.open_mainfile(filepath=str(ROOT / 'Logo_Verre_Natif.blend'))
scene = bpy.context.scene
model = bpy.data.objects['TRAM / reconstruction de la photo']
# Icon Composer interprets source pixels as points; the SVG artboard is 1024pt.
scene.render.resolution_x = scene.render.resolution_y = 1024
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.image_settings.color_depth = '16'
scene.render.film_transparent = True
scene.cycles.film_transparent_glass = True
scene.cycles.samples = 160
scene.cycles.adaptive_threshold = .012
prefs = bpy.context.preferences.addons['cycles'].preferences
prefs.compute_device_type = 'METAL'
prefs.get_devices()
for d in prefs.devices:
    d.use = d.type == 'METAL'
scene.cycles.device = 'GPU'

if NIGHT:
    def linear(hexcolor):
        c = [int(hexcolor[i:i+2], 16)/255 for i in (0,2,4)]
        return tuple(v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4 for v in c)
    for name, color in [('Blanc porcelaine','B4CDDE'), ('Rouge corail','F84B63'),
                        ('Interieur - assises corail','A16468'), ('Bleu graphite','172F46')]:
        m = bpy.data.materials[name]
        p = m.node_tree.nodes.get('Principled BSDF')
        p.inputs['Base Color'].default_value = (*linear(color), 1)
        if name == 'Blanc porcelaine':
            p.inputs['Transmission Weight'].default_value = .12
            p.inputs['Roughness'].default_value = .27
    for ob in bpy.data.collections['80 Studio - finition'].objects:
        if ob.type == 'LIGHT' and ob.data.type == 'AREA':
            ob.data.energy *= .62
    for ob in bpy.data.objects:
        if ob.type == 'LIGHT' and 'eclairage interieur' in ob.name:
            ob.data.energy *= .6

for colname in ('08 Radar 3D - disque anneaux et reperes', '09 Fond blanc 3D'):
    for ob in bpy.data.collections[colname].objects:
        if ob.type in {'MESH', 'CURVE'}:
            ob.hide_render = True

def hull(points):
    pts = sorted(set(points))
    def cross(o, a, b):
        return (a[0]-o[0])*(b[1]-o[1])-(a[1]-o[1])*(b[0]-o[0])
    lower, upper = [], []
    for p in pts:
        while len(lower)>1 and cross(lower[-2], lower[-1], p)<=0: lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper)>1 and cross(upper[-2], upper[-1], p)<=0: upper.pop()
        upper.append(p)
    return lower[:-1]+upper[:-1]

def outline(ob):
    pts = []
    for v in ob.data.vertices:
        p = world_to_camera_view(scene, scene.camera, ob.matrix_world @ v.co)
        pts.append((round(p.x*1024, 4), round((1-p.y)*1024, 4)))
    pts = hull(pts)
    return 'M'+' L'.join(f'{x:.3f} {y:.3f}' for x,y in pts)+' Z'

inv = model.matrix_world.inverted()
front_glass = []
record = {'native_master':str(ROOT / 'Logo_Verre_Natif.blend'), 'parts':{}, 'windows':[]}
for ob in model.children_recursive:
    if ob.type not in {'MESH', 'CURVE'} or ob.hide_render:
        continue
    center = inv @ (ob.matrix_world @ (sum((Vector(v) for v in ob.bound_box), Vector())/8))
    part = 2 if center.y > 4.13 else 1
    if 'Essuie' in ob.name or 'essuie' in ob.name:
        part = 3
    ob.pass_index = part
    record['parts'][ob.name] = part
    if ' / vitrage' in ob.name and ('Pare brise' in ob.name or center.x < 0):
        front_glass.append(ob)
        record['windows'].append(ob.name)

assert len(front_glass) == 5, record['windows']
svg = '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">\n'
svg += '<defs><linearGradient id="tint" x1="0" y1="0" x2=".8" y2="1"><stop stop-color="#82C4D7" stop-opacity=".36"/><stop offset="1" stop-color="#194963" stop-opacity=".60"/></linearGradient></defs>\n'
svg += '\n'.join('<path d="'+outline(ob)+'" fill="url(#tint)"/>' for ob in front_glass)
svg += '\n</svg>\n'
if not NIGHT:
    (OUT / 'Vitres.svg').write_text(svg)
for ob in front_glass:
    ob.hide_render = True

# AOV masks classify the camera-visible surface, so the body layers remain
# registered and preserve occlusion instead of showing the hidden rear coach.
layer = bpy.context.view_layer
for name in ('CaisseAvant', 'CaisseArriere', 'EssuieGlace'):
    aov = layer.aovs.add(); aov.name = name; aov.type = 'VALUE'
for mat in bpy.data.materials:
    if not mat.use_nodes:
        continue
    n, l = mat.node_tree.nodes, mat.node_tree.links
    info = n.new('ShaderNodeObjectInfo')
    for index, name in enumerate(('CaisseAvant', 'CaisseArriere', 'EssuieGlace'), 1):
        compare = n.new('ShaderNodeMath'); compare.operation = 'COMPARE'
        compare.inputs[1].default_value = index; compare.inputs[2].default_value = .1
        l.new(info.outputs['Object Index'], compare.inputs[0])
        aov = n.new('ShaderNodeOutputAOV'); aov.aov_name = name
        l.new(compare.outputs[0], aov.inputs['Value'])

scene.use_nodes = True
tree = scene.node_tree; tree.nodes.clear()
rl = tree.nodes.new('CompositorNodeRLayers')
for name in ('CaisseAvant', 'CaisseArriere', 'EssuieGlace'):
    alpha = tree.nodes.new('CompositorNodeSetAlpha'); alpha.mode = 'REPLACE_ALPHA'
    tree.links.new(rl.outputs['Image'], alpha.inputs['Image'])
    tree.links.new(rl.outputs[name], alpha.inputs['Alpha'])
    out = tree.nodes.new('CompositorNodeOutputFile'); out.base_path = str(OUT)
    out.file_slots[0].path = name+SUFFIX
    out.format.file_format = 'PNG'; out.format.color_mode = 'RGBA'; out.format.color_depth = '16'
    tree.links.new(alpha.outputs['Image'], out.inputs[0])
comp = tree.nodes.new('CompositorNodeComposite')
tree.links.new(rl.outputs['Image'], comp.inputs[0])
scene.render.filepath = str(OUT / ('Tram_sans_vitres'+SUFFIX+'.png'))
(OUT / ('projection'+SUFFIX+'.json')).write_text(json.dumps(record, indent=2, ensure_ascii=False))
bpy.ops.render.render(write_still=True)
for name in ('CaisseAvant', 'CaisseArriere', 'EssuieGlace'):
    (OUT / f'{name}{SUFFIX}{scene.frame_current:04d}.png').replace(OUT / f'{name}{SUFFIX}.png')
print('ICON_LAYERS_EXPORTED', str(OUT), flush=True)
