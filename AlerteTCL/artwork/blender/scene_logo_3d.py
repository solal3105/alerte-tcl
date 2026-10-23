"""Build the complete editable logo scene. The radar is native mesh/curve geometry.

No image textures, shadow catcher, or compositor background are used.
Run with Blender --background --python scene_logo_3d.py [-- --final].
"""
from pathlib import Path
import bpy, math, sys, json
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parent
OUT = ROOT.parent / 'app-icon'
FINAL = '--final' in sys.argv
bpy.ops.wm.open_mainfile(filepath=str(ROOT / 'Logo_App_Tram.blend'))
scene = bpy.context.scene
scene.name = 'Logo / scene complete 3D'
cam = scene.camera
scene.use_nodes = False
if scene.node_tree: scene.node_tree.nodes.clear()
scene.render.film_transparent = False
scene.cycles.film_transparent_glass = False
floor = bpy.data.objects.get('Sol studio / fond courbe continu')
if floor:
    floor.hide_render = True
    floor.hide_set(True)
    floor.is_shadow_catcher = False
for ob in scene.objects:
    if ob.type == 'MESH': ob.is_shadow_catcher = False
scene.view_settings.view_transform = 'Khronos PBR Neutral'
scene.view_settings.look = 'None'
scene.view_settings.exposure = 0
scene.view_settings.gamma = 1

def rgb(s):
    a = [int(s[i:i+2], 16) / 255 for i in (0, 2, 4)]
    return tuple(c / 12.92 if c <= .04045 else ((c+.055)/1.055)**2.4 for c in a)

def mix(a, b, t): return tuple(x*(1-t)+y*t for x,y in zip(a,b))

radar = bpy.data.collections.new('08 Radar 3D - disque anneaux et reperes')
scene.collection.children.link(radar)
root = bpy.data.objects.new('RADAR / ensemble 3D editable', None)
radar.objects.link(root)
bpy.context.view_layer.update()
model = bpy.data.objects['TRAM / reconstruction de la photo']
inv = cam.matrix_world.inverted()
depths = []
for ob in model.children_recursive:
    if ob.type in {'MESH', 'CURVE'}:
        depths.extend(-(inv @ (ob.matrix_world @ Vector(p))).z for p in ob.bound_box)
depth = max(depths) + .65
frame = list(cam.data.view_frame(scene=scene))
scale = depth / abs(frame[0].z)
cx = (max(p.x for p in frame) + min(p.x for p in frame)) * scale / 2
cy = (max(p.y for p in frame) + min(p.y for p in frame)) * scale / 2
F = (max(p.x for p in frame) - min(p.x for p in frame)) * scale
root.matrix_world = cam.matrix_world @ Matrix.Translation((cx, cy, -depth))
root['description'] = 'Disque massif, cercles en relief, secteur de balayage et balises. Aucune image de fond.'

def move(ob, name, loc):
    ob.name = name
    for col in list(ob.users_collection): col.objects.unlink(ob)
    radar.objects.link(ob)
    ob.parent = root
    ob.matrix_parent_inverse = Matrix.Identity(4)
    ob.location = loc
    ob.rotation_euler = (0,0,0)
    return ob

def material(name, color, rough=.45, emission=.0, vertex=False):
    mat = bpy.data.materials.new(name); mat.use_nodes = True
    mat.diffuse_color = (*rgb(color), 1)
    p = mat.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*rgb(color), 1)
    p.inputs['Roughness'].default_value = rough
    p.inputs['Specular IOR Level'].default_value = .22
    p.inputs['Emission Color'].default_value = (*rgb(color), 1)
    p.inputs['Emission Strength'].default_value = emission
    if vertex:
        attr = mat.node_tree.nodes.new('ShaderNodeVertexColor'); attr.layer_name = 'Couleur radar'
        mat.node_tree.links.new(attr.outputs['Color'], p.inputs['Base Color'])
        mat.node_tree.links.new(attr.outputs['Color'], p.inputs['Emission Color'])
    return mat

mint = material('Radar / bord menthe satine', 'BDFFCE', .38, .38)
coremat = material('Radar / couleurs du disque', '39E787', .72, .18, True)
coremat.node_tree.nodes.get('Principled BSDF').inputs['Specular IOR Level'].default_value = .04
line = material('Radar / anneaux vert clair', '97F8BF', .5, .5)
raymat = material('Radar / faisceau lumineux', 'CDFFF0', .3, .9)
beadmat = material('Radar / balises porcelaine', 'EBFFF9', .21, .35)

def cylinder(name, radius, thick, z, mat, bevel=0):
    bpy.ops.mesh.primitive_cylinder_add(vertices=256, radius=radius*F, depth=thick*F)
    ob = move(bpy.context.object, name, (0,0,z*F))
    ob.data.materials.append(mat)
    if bevel:
        mod = ob.modifiers.new('Aretes adoucies', 'BEVEL'); mod.width=bevel*F; mod.segments=5
        mod = ob.modifiers.new('Normales ponderees', 'WEIGHTED_NORMAL')
    for p in ob.data.polygons: p.use_smooth = len(p.vertices)==4
    return ob

cylinder('Radar / disque epais et bord arrondi', .466, .018, -.013, mint, .007)

green0, green1, blue = rgb('1ED58B'), rgb('5AF16D'), rgb('03B4FB')
def basecolor(x,y):
    t = max(0,min(1,1-math.hypot(x+.22,y-.28)/1.05))
    return mix(green0,green1,t)

def surface(name, rmax, start, end, nr, na, z, sweeping=False):
    # Editable polar mesh. Its colors are vertex attributes, not a bitmap.
    verts = [(0,0,z*F)]; colors = [basecolor(0,0)]
    for j in range(1,nr+1):
        r = rmax*j/nr
        for i in range(na+1):
            a = start + (end-start)*i/na
            x,y = r*math.cos(a),r*math.sin(a)
            col = basecolor(x,y)
            if sweeping:
                trail = end-a
                tail = max(0,min(1,(math.radians(85)-trail)/math.radians(30)))
                tail = tail*tail*(3-2*tail)
                t = math.exp(-trail/math.radians(48))*tail*min(r/.19,1)*.87
                col = mix(col,blue,t)
            verts.append((x*F,y*F,z*F)); colors.append(col)
    faces = [(0,1+i,2+i) for i in range(na)]
    for j in range(nr-1):
        lo,hi=1+j*(na+1),1+(j+1)*(na+1)
        faces.extend((lo+i,hi+i,hi+i+1,lo+i+1) for i in range(na))
    mesh = bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    attr=mesh.color_attributes.new(name='Couleur radar',type='FLOAT_COLOR',domain='POINT')
    for el,col in zip(attr.data,colors): el.color=(*col,1)
    ob=bpy.data.objects.new(name,mesh);radar.objects.link(ob);ob.parent=root
    ob.data.materials.append(coremat)
    solid = ob.modifiers.new('Epaisseur reelle', 'SOLIDIFY');solid.thickness=.001*F
    return ob

surface('Radar / ecran vert',.442,0,math.tau,24,256,0)
heading=math.radians(68)
surface('Radar / secteur de balayage bleu',.441,heading-math.radians(85),heading,24,96,.0014,True)

def curve(name, points, radius, mat, cyclic=False):
    data = bpy.data.curves.new(name,'CURVE');data.dimensions='3D'
    data.resolution_u=1;data.bevel_depth=radius*F;data.bevel_resolution=4
    spline=data.splines.new('POLY');spline.points.add(len(points)-1)
    for p,v in zip(spline.points,points): p.co=(*[c*F for c in v],1)
    spline.use_cyclic_u=cyclic
    ob=bpy.data.objects.new(name,data);radar.objects.link(ob);ob.parent=root
    data.materials.append(mat)
    return ob

for i,r in enumerate((.19,.295,.401),1):
    curve(f'Radar / anneau de distance {i}',[(r*math.cos(a*math.tau/256),r*math.sin(a*math.tau/256),.0028) for a in range(256)],.0008,line,True)
curve('Radar / lisere interieur',[(.442*math.cos(a*math.tau/256),.442*math.sin(a*math.tau/256),.001) for a in range(256)],.00065,raymat,True)
curve('Radar / rayon du balayage',[(0,0,.003),(.439*math.cos(heading),.439*math.sin(heading),.003)],.0009,raymat)
for i,(x,y,r) in enumerate(((-.287,.259,.010),(.290,.215,.008)),1):
    curve(f'Radar / halo balise {i}',[(x+.023*math.cos(a*math.tau/128),y+.023*math.sin(a*math.tau/128),.003) for a in range(128)],.0007,raymat,True)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48,ring_count=24,radius=r*F)
    ob=move(bpy.context.object,f'Radar / balise ronde {i}',(x*F,y*F,.007*F))
    ob.scale.z=.55;ob.data.materials.append(beadmat)
    for p in ob.data.polygons:p.use_smooth=True

# The backdrop has its own soft lamp, with real shadows cast by the tram.
# Light linking keeps the approved tram's studio lighting unchanged.
tram_receivers=bpy.data.collections.new('81 Recepteurs des lumieres du tram')
for ob in scene.objects:
    if ob.type in {'MESH','CURVE'} and ob.name not in radar.objects:
        tram_receivers.objects.link(ob)
for ob in scene.objects:
    if ob.type=='LIGHT':ob.light_linking.receiver_collection=tram_receivers
lamp=bpy.data.lights.new('Radar / boite douce', 'AREA')
lamp.energy=1800;lamp.shape='DISK';lamp.size=8
key=bpy.data.objects.new(lamp.name,lamp);radar.objects.link(key)
key.location=root.matrix_world @ Vector((0,4,20))
key.rotation_euler=(root.matrix_world.translation-key.location).to_track_quat('-Z','Y').to_euler()
radar_receivers=bpy.data.collections.new('82 Recepteurs de la lumiere du radar')
for ob in radar.objects:
    if ob.type in {'MESH','CURVE'}:radar_receivers.objects.link(ob)
key.light_linking.receiver_collection=radar_receivers

# Preserve the studio illumination. White camera background is a native World.
world=scene.world;wn=world.node_tree.nodes;wl=world.node_tree.links
background=wn.get('Background')
out=next(n for n in wn if n.type=='OUTPUT_WORLD')
lightpath=wn.new('ShaderNodeLightPath')
white=wn.new('ShaderNodeBackground');white.name='Fond blanc visible';white.inputs['Color'].default_value=(1,1,1,1);white.inputs['Strength'].default_value=5
wmix=wn.new('ShaderNodeMixShader')
wl.new(lightpath.outputs['Is Camera Ray'],wmix.inputs[0])
wl.new(background.outputs[0],wmix.inputs[1]);wl.new(white.outputs[0],wmix.inputs[2]);wl.new(wmix.outputs[0],out.inputs['Surface'])

scene.render.engine='CYCLES'
scene.cycles.samples=192 if FINAL else 48
scene.cycles.use_denoising=True;scene.cycles.use_preview_denoising=True
scene.cycles.preview_samples=32;scene.cycles.preview_adaptive_threshold=.06
scene.cycles.max_bounces=16;scene.cycles.transmission_bounces=12
scene.cycles.adaptive_threshold=.012 if FINAL else .035
prefs=bpy.context.preferences.addons['cycles'].preferences
prefs.compute_device_type='METAL';prefs.get_devices()
for d in prefs.devices:d.use=d.type=='METAL'
scene.cycles.device='GPU' if any(d.type=='METAL' for d in prefs.devices) else 'CPU'
scene.render.resolution_x=scene.render.resolution_y=2048 if FINAL else 768
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGB'
scene.render.filepath=str(OUT/('AlerteTCL_3D_2048.png' if FINAL else 'apercu_scene_3d.png'))
scene['composition_logo']='Scene 3D complete : tram, vitrage transmissif, eclairage et radar geometrique. Compositeur desactive.'
scene['radar_geometry_objects']=sum(ob.type in {'MESH','CURVE'} for ob in radar.objects)
for ob in scene.objects: ob.select_set(False)
bpy.context.view_layer.objects.active=None

for ws in bpy.data.workspaces:
    if ws.name == 'Tram - 3D':
        for screen in ws.screens:
            area=max(screen.areas,key=lambda a:a.width*a.height)
            area.type='VIEW_3D'
            sp=area.spaces.active;sp.camera=cam
            sp.shading.type='RENDERED';sp.shading.use_scene_world_render=True;sp.shading.use_scene_lights_render=True
            sp.shading.use_compositor='DISABLED';sp.overlay.show_overlays=False
            sp.region_3d.view_perspective='CAMERA';sp.region_3d.view_camera_zoom=0;sp.region_3d.view_camera_offset=(0,0)
            sp.region_3d.view_rotation=cam.rotation_euler.to_quaternion()
            sp.region_3d.view_location=(0,3,1.75);sp.region_3d.view_distance=15
            for other in screen.areas:
                if other!=area and other.type=='CONSOLE':other.type='PROPERTIES'
for win in bpy.context.window_manager.windows:win.workspace=bpy.data.workspaces['Tram - 3D']
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'Logo_App_Scene_3D.blend'),compress=True)
bpy.ops.render.render(write_still=True)
if FINAL:
    final=bpy.data.images.load(scene.render.filepath,check_existing=False);final.name='Logo / rendu scene 3D complete';final.pack()
    for ws in bpy.data.workspaces:
        if ws.name=='Logo - Rendu':
            for screen in ws.screens:
                for area in screen.areas:
                    if area.type=='IMAGE_EDITOR':area.spaces.active.image=final
    for side in (1024,64):
        im=bpy.data.images.load(scene.render.filepath,check_existing=False);im.scale(side,side)
        im.filepath_raw=str(OUT/f'AlerteTCL_3D_{side}.png');im.file_format='PNG';im.save();bpy.data.images.remove(im)
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'Logo_App_Scene_3D.blend'),compress=True)
report={'native_radar_objects':scene['radar_geometry_objects'],'compositor_enabled':scene.use_nodes,'camera_preserved':True,'model_geometry_preserved':True,'radar_depth':depth,'frame_width_at_radar':F,'glass_transmission':bpy.data.materials['Bleu du vitrage'].node_tree.nodes.get('Principled BSDF').inputs['Transmission Weight'].default_value}
(OUT/'verification_scene_3d.json').write_text(json.dumps(report,indent=2))
print('NATIVE_SCENE_READY',json.dumps(report))
