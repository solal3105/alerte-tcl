"""App-icon composition rendered from the editable, finished Blender tram.

The bright green localization radar is rebuilt procedurally. No photo is mapped
onto the model. The approved model and the app's existing icon are preserved.
"""
from pathlib import Path
import sys, math, json
import bpy
import numpy as np
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

ROOT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT))
from radar_background import build_radar,linear
OUT=ROOT.parent/'app-icon';OUT.mkdir(exist_ok=True)
PREVIEW='--preview' in sys.argv
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'Logo_Tram.blend'))
scene=bpy.context.scene;scene.name='Logo app / tram'
cam=scene.camera

# A slightly more frontal portrait restores the friendly face at small icon sizes.
direction=Vector((-.30,-.95,.17)).normalized()
target=Vector((0,3.0,1.75))
cam.location=target+direction*12.8
cam.rotation_euler=(-direction).to_track_quat('-Z','Y').to_euler()
cam.data.type='PERSP';cam.data.lens=65;cam.data.shift_x=0;cam.data.shift_y=0
scene.render.resolution_x=scene.render.resolution_y=768 if PREVIEW else 2048
scene.render.resolution_percentage=100
bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
points=[]
for ob in scene.objects:
    if ob.type not in {'MESH','CURVE'} or not ob.parent or not ob.parent.name.startswith('TRAM /'):continue
    ev=ob.evaluated_get(dg);mesh=ev.to_mesh()
    step=max(1,len(mesh.vertices)//1600)
    points.extend(ob.matrix_world@mesh.vertices[i].co for i in range(0,len(mesh.vertices),step))
    ev.to_mesh_clear()

def projected():return [world_to_camera_view(scene,cam,p) for p in points]
uv=projected();cx=(min(p.x for p in uv)+max(p.x for p in uv))/2;cy=(min(p.y for p in uv)+max(p.y for p in uv))/2
cam.data.shift_x=cx-.5;cam.data.shift_y=cy-.5
bpy.context.view_layer.update();uv=projected()
r=max(math.hypot(p.x-.5,p.y-.5) for p in uv)
factor=.425/r;cam.data.lens*=factor;cam.data.shift_x*=factor;cam.data.shift_y*=factor
bpy.context.view_layer.update();uv=projected()
framing={'left':min(p.x for p in uv),'right':max(p.x for p in uv),
         'bottom':min(p.y for p in uv),'top':max(p.y for p in uv),
         'max_radius':max(math.hypot(p.x-.5,p.y-.5) for p in uv)}
assert framing['max_radius']<.432,framing

# Keep real ground/contact shadows as a separate alpha contribution.
for ob in bpy.data.collections['80 Studio - finition'].objects:
    if ob.type=='MESH':ob.is_shadow_catcher=True
scene.render.film_transparent=True
scene.cycles.film_transparent_glass=True
scene.cycles.film_transparent_roughness=.2

# More readable blue glazing, while retaining real transmission and the cabin.
glass=bpy.data.materials['Bleu du vitrage']
gp=next(n for n in glass.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
gp.inputs['Base Color'].default_value=(*linear('80B2D7'),1)
gp.inputs['Transmission Weight'].default_value=.90
gp.inputs['Roughness'].default_value=.035
gp.inputs['Coat Weight'].default_value=.18
glass.diffuse_color=(*linear('80B2D7'),1)

def finish(name,color,roughness=None):
    mat=bpy.data.materials[name]
    p=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value=(*linear(color),1);mat.diffuse_color=(*linear(color),1)
    if roughness is not None:p.inputs['Roughness'].default_value=roughness
    return p
finish('Blanc porcelaine','FAFCFF',.33)
cp=finish('Rouge corail','F62E35',.38);cp.inputs['Coat Weight'].default_value=0;cp.inputs['Specular IOR Level'].default_value=.06
npbr=finish('Bleu graphite','10263D',.42);npbr.inputs['Coat Weight'].default_value=.12
pp=finish('Pantographe - metal satine','162C43',.44);pp.inputs['Metallic'].default_value=0
finish('Interieur - assises corail','F39780',.56)
lp=finish('Jaune doux des phares','FFE280',.22)
lp.inputs['Emission Color'].default_value=(*linear('FFC144'),1)
lp.inputs['Emission Strength'].default_value=3

# Saturated but controlled livery and glass highlights for a small, bright icon.
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.32
for ob in bpy.data.collections['80 Studio - finition'].objects:
    if ob.type=='LIGHT' and ob.data.type=='AREA':ob.data.energy*=1.5
d=bpy.data.lights.new('Logo / eclairage frontal doux','AREA');d.energy=650;d.shape='DISK';d.size=5;d.color=(1,1,1)
fill=bpy.data.objects.new(d.name,d);bpy.data.collections['80 Studio - finition'].objects.link(fill)
fill.location=(-2,-7,6);fill.rotation_euler=(Vector((0,1.5,1.7))-fill.location).to_track_quat('-Z','Y').to_euler()

# Native generated Blender image, computed from vector geometry at final size.
# It remains packed in the .blend and can be reproduced at any resolution.
size=scene.render.resolution_x
background=build_radar(size)
bg=bpy.data.images.new('Logo / radar de localisation',width=size,height=size,alpha=False,float_buffer=True)
bg.colorspace_settings.name='Linear Rec.709';bg.pixels.foreach_set(background.ravel());bg.update();bg.pack()

scene.use_nodes=True;nodes=scene.node_tree.nodes;nodes.clear();links=scene.node_tree.links
rl=nodes.new('CompositorNodeRLayers');rl.location=(-1250,100)
glare=nodes.new('CompositorNodeGlare');glare.glare_type='FOG_GLOW';glare.quality='HIGH';glare.location=(-1050,100)
glare.inputs['Threshold'].default_value=1.8;glare.inputs['Strength'].default_value=.20;glare.inputs['Size'].default_value=.16
links.new(rl.outputs['Image'],glare.inputs['Image'])
# Apply a product-rendering view transform to the tram only. The brand colors
# and white canvas remain exact sRGB, independently of the rendered lighting.
straight=nodes.new('CompositorNodePremulKey');straight.mapping='PREMUL_TO_STRAIGHT';straight.location=(-850,100)
links.new(glare.outputs['Image'],straight.inputs['Image'])
tonemap=nodes.new('CompositorNodeConvertColorSpace');tonemap.from_color_space='Linear Rec.709';tonemap.to_color_space='Khronos PBR Neutral sRGB';tonemap.location=(-650,100)
links.new(straight.outputs['Image'],tonemap.inputs['Image'])
contrast=nodes.new('CompositorNodeCurveRGB');contrast.location=(-430,100)
contrast.mapping.curves[3].points.new(.25,.21);contrast.mapping.curves[3].points.new(.75,.79);contrast.mapping.update()
sat=nodes.new('CompositorNodeHueSat');sat.inputs['Saturation'].default_value=1.04;sat.location=(-520,320)
links.new(tonemap.outputs['Image'],sat.inputs['Image']);links.new(sat.outputs['Image'],contrast.inputs['Image'])
decode=nodes.new('CompositorNodeConvertColorSpace');decode.from_color_space='sRGB';decode.to_color_space='Linear Rec.709';decode.location=(-180,100)
links.new(contrast.outputs['Image'],decode.inputs['Image'])
premul=nodes.new('CompositorNodePremulKey');premul.mapping='STRAIGHT_TO_PREMUL';premul.location=(30,100)
mask=nodes.new('CompositorNodeEllipseMask');mask.inputs['Size'].default_value=(.891,.891);mask.inputs['Position'].default_value=(.5,.5);mask.location=(-450,-320)
mul=nodes.new('CompositorNodeMath');mul.operation='MULTIPLY';mul.location=(-220,-270)
links.new(rl.outputs['Alpha'],mul.inputs[0]);links.new(mask.outputs['Mask'],mul.inputs[1])
setalpha=nodes.new('CompositorNodeSetAlpha');setalpha.mode='REPLACE_ALPHA';setalpha.location=(-10,-100)
links.new(decode.outputs['Image'],setalpha.inputs['Image']);links.new(mul.outputs[0],setalpha.inputs['Alpha'])
links.new(setalpha.outputs['Image'],premul.inputs['Image'])
image=nodes.new('CompositorNodeImage');image.image=bg;image.location=(30,-160)
over=nodes.new('CompositorNodeAlphaOver');over.location=(250,20);over.inputs[0].default_value=1
links.new(image.outputs['Image'],over.inputs[1]);links.new(premul.outputs['Image'],over.inputs[2])
out=nodes.new('CompositorNodeComposite');out.location=(470,20);links.new(over.outputs['Image'],out.inputs['Image'])
scene.view_settings.view_transform='Standard';scene.view_settings.look='None';scene.view_settings.exposure=0;scene.view_settings.gamma=1

scene.render.engine='CYCLES';scene.cycles.samples=48 if PREVIEW else 256
scene.cycles.use_denoising=True;scene.cycles.adaptive_threshold=.035 if PREVIEW else .009
scene.cycles.max_bounces=16;scene.cycles.transmission_bounces=12;scene.cycles.transparent_max_bounces=12
prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='METAL';prefs.get_devices()
for d in prefs.devices:d.use=d.type=='METAL'
scene.cycles.device='GPU' if any(d.type=='METAL' for d in prefs.devices) else 'CPU'
scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGB';scene.render.image_settings.color_depth='8'
scene.render.filepath=str(OUT/('apercu_logo.png' if PREVIEW else 'AlerteTCL_Icon_2048.png'))
scene['composition_logo']='Petit tram lumineux, blanc porcelaine et corail, verre bleu brillant. Radar vert pomme a trois anneaux, balayage bleu ciel et pastilles de localisation.'
scene['cadre_logo']=json.dumps(framing)
if not PREVIEW:bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'Logo_App_Tram.blend'),compress=True)
bpy.ops.render.render(write_still=True)
if not PREVIEW:
    final=bpy.data.images.load(scene.render.filepath,check_existing=False)
    final.name='Logo app / rendu final';final.pack()
    for ws in bpy.data.workspaces:
        if ws.name=='Tram - Rendu':
            ws.name='Logo - Rendu'
            for screen in ws.screens:
                for area in screen.areas:
                    if area.type=='IMAGE_EDITOR':area.spaces.active.image=final
    # Scale the already color-managed render without applying a second view transform.
    for side in (1024,64):
        export=bpy.data.images.load(str(OUT/'AlerteTCL_Icon_2048.png'),check_existing=False)
        export.scale(side,side);export.file_format='PNG'
        export.filepath_raw=str(OUT/f'AlerteTCL_Icon_{side}.png');export.save()
        bpy.data.images.remove(export)
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'Logo_App_Tram.blend'),compress=True)
    (OUT/'verification_logo.json').write_text(json.dumps({'framing':framing,'sizes':[2048,1024,64],'model_geometry_preserved':True,'glass_transmission':.90,'glass_roughness':.035,'radar_range_rings':3,'radar_echoes':2,'camera_direction':list(direction)},indent=2))
print('APP_ICON_READY',scene.render.filepath,framing)
