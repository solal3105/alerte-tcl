"""Native, editable PBR finish for the approved two-coach tram.

Run after modele_tram.py, or rerun on Logo_Tram.blend. --preview makes a fast
inspection image; otherwise save a 2048px Cycles render and the finished scene.
"""
from pathlib import Path
import math, sys, json
import bpy
from mathutils import Vector

ROOT=Path(__file__).resolve().parent
PREVIEW='--preview' in sys.argv
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'Logo_Tram.blend'))
scene=bpy.context.scene
MODEL_NAMES=[o.name for o in scene.objects if o.parent and o.parent.name.startswith('TRAM /')]
before={name:tuple(tuple(v) for v in bpy.data.objects[name].bound_box) for name in MODEL_NAMES}

# Idempotent studio: rerunning changes finishes, never the approved body meshes.
old=bpy.data.collections.get('80 Studio - finition')
if old:
    for ob in list(old.objects):bpy.data.objects.remove(ob,do_unlink=True)
    bpy.data.collections.remove(old)
studio=bpy.data.collections.new('80 Studio - finition')
scene.collection.children.link(studio)

def rgb(hexcode):
    s=[int(hexcode[i:i+2],16)/255 for i in (0,2,4)]
    return tuple(c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in s)

def material(name,color,roughness=.3,metallic=0,coat=0,coat_roughness=.2,bevel=0):
    m=bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes=True;m.diffuse_color=(*rgb(color),1)
    m.node_tree.nodes.clear();n=m.node_tree.nodes;links=m.node_tree.links
    p=n.new('ShaderNodeBsdfPrincipled');p.location=(0,0);p.label=name
    p.inputs['Base Color'].default_value=(*rgb(color),1)
    p.inputs['Roughness'].default_value=roughness
    p.inputs['Metallic'].default_value=metallic
    p.inputs['IOR'].default_value=1.46
    p.inputs['Coat Weight'].default_value=coat
    p.inputs['Coat Roughness'].default_value=coat_roughness
    p.inputs['Transmission Weight'].default_value=0
    p.inputs['Alpha'].default_value=1
    out=n.new('ShaderNodeOutputMaterial');out.location=(340,0)
    links.new(p.outputs['BSDF'],out.inputs['Surface'])
    if bevel:
        b=n.new('ShaderNodeBevel');b.location=(-240,-180);b.samples=4
        b.inputs['Radius'].default_value=bevel;links.new(b.outputs['Normal'],p.inputs['Normal'])
    return m,p

body,_=material('Blanc porcelaine','EDF1F4',.28,.03,.34,.21,.006)
navy,_=material('Bleu graphite','1E3447',.36,.12,.18,.24,.004)
rubber,_=material('Joints bleu sombre','122431',.48,0,0,bevel=.0015)
glass,gp=material('Bleu du vitrage','103855',.145,.09,.40,.105)
# Opaque lacquered glazing: real reflected studio lights, no fake image texture,
# no transparency and no view through to the hollow body.
gp.inputs['IOR'].default_value=1.48
coral,_=material('Rouge corail','F33632',.27,0,.30,.18,.001)
lamp,lp=material('Jaune doux des phares','FFE6A0',.22,.04,.3,.17)
lp.inputs['Emission Color'].default_value=(*rgb('FFD781'),1)
lp.inputs['Emission Strength'].default_value=3.0
gold,_=material('Reflecteurs','D7BD82',.23,.78,.12,.2,.001)
wiper,_=material('Essuie glace','3D566A',.36,.10,.12,.25,.002)
tyre,_=material('Pneus - gomme mate','172630',.68)
panto,_=material('Pantographe - metal satine','203747',.36,.15,.15,.23,.003)
gangway,_=material('Soufflet - elastomere','253B49',.52)
for ob in scene.objects:
    target=None
    if ob.name.startswith('Roue '):target=tyre
    elif ob.name.startswith('Pantographe /'):target=panto
    elif ob.name.startswith('Articulation /'):target=gangway
    if target and ob.data and hasattr(ob.data,'materials'):
        ob.data.materials.clear();ob.data.materials.append(target)

def light(name,kind,loc,energy,color,target=None,size=1,size_y=None):
    d=bpy.data.lights.new(name,kind);d.energy=energy;d.color=rgb(color)
    ob=bpy.data.objects.new(name,d);studio.objects.link(ob);ob.location=loc
    if target:ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler()
    if kind=='AREA':
        d.shape='RECTANGLE' if size_y else 'DISK';d.size=size
        if size_y:d.size_y=size_y
    return ob

# Large lights preserve the smooth toy silhouette; narrow strips describe glass.
light('01 Grande boite douce','AREA',(-4,-3,9),1000,'FFF4E5',(0,2.4,1.5),5)
light('02 Remplissage bleu ciel','AREA',(5,-.5,5.2),240,'C7E6FF',(0,2.0,1.6),4)
light('03 Liseré arriere','AREA',(-1,8.5,7.5),1100,'E2FFF2',(0,3.5,1.8),4,5)
light('04 Reflet long des vitres','AREA',(-5,10,4.6),320,'D4F0FF',(0,3.5,1.8),1.4,6)
light('05 Reflet doux pare brise','AREA',(4,-6,4.7),220,'FFFFFF',(0,0,2),1.7,4)

# Real low-power headlight beams supplement the luminous lenses.
for ob in [bpy.data.objects[n] for n in MODEL_NAMES if 'lentille bombee' in n]:
    vs=[ob.matrix_world@v.co for v in ob.data.vertices]
    center=sum(vs,Vector())/len(vs)
    normal=Vector((-.27 if center.x<0 else .27,-1,-.06)).normalized()
    src=center+normal*.10
    beam=light('Phare allume / '+ob.name,'SPOT',src,32,'FFE3A0',src+normal*4)
    beam.data.spot_size=math.radians(88);beam.data.spot_blend=.85;beam.data.shadow_soft_size=.13

# Quiet mint-grey studio, with the tyres actually resting on the floor.
bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
wheel_bottom=[]
for ob in scene.objects:
    if ob.name.startswith('Roue ') and ob.type=='MESH':
        ev=ob.evaluated_get(dg);me=ev.to_mesh()
        wheel_bottom.extend((ob.matrix_world@v.co).z for v in me.vertices);ev.to_mesh_clear()
ground,_=material('Studio - sauge claire','C6DCD9',.83)
floor_z=min(wheel_bottom)-.003
forward=Vector((.55,.82,0)).normalized();across=Vector((forward.y,-forward.x,0))
origin=Vector((0,3.35,0));cross=[(-70,floor_z),(10,floor_z)]
for i in range(1,65):
    a=(math.pi/2)*i/64;cross.append((10+7*math.sin(a),floor_z+7*(1-math.cos(a))))
cross.append((17,70))
vertices=[origin+forward*d+across*w+Vector((0,0,z)) for d,z in cross for w in (-70,70)]
faces=[(2*i,2*i+1,2*i+3,2*i+2) for i in range(len(cross)-1)]
mesh=bpy.data.meshes.new('Cyclorama sans horizon');mesh.from_pydata(vertices,[],faces);mesh.update()
floor=bpy.data.objects.new('Sol studio / fond courbe continu',mesh);studio.objects.link(floor);mesh.materials.append(ground)
for p in mesh.polygons:p.use_smooth=True

world=bpy.data.worlds.get('Studio - ambiance') or bpy.data.worlds.new('Studio - ambiance')
scene.world=world;world.use_nodes=True
world.node_tree.nodes['Background'].inputs['Color'].default_value=(*rgb('D9E8F6'),1)
world.node_tree.nodes['Background'].inputs['Strength'].default_value=.16

cam=scene.camera
direction=Vector((-.55,-.82,.22)).normalized();target=Vector((0,3.35,1.86))
cam.location=target+direction*19
cam.rotation_euler=(-direction).to_track_quat('-Z','Y').to_euler()
cam.data.type='PERSP';cam.data.lens=70;cam.data.ortho_scale=10.2
cam.data.dof.use_dof=False;cam.data.clip_end=250
scene.render.engine='CYCLES'
scene.cycles.samples=48 if PREVIEW else 256
scene.cycles.preview_samples=24;scene.cycles.use_denoising=True;scene.cycles.use_preview_denoising=True
scene.cycles.adaptive_threshold=.04 if PREVIEW else .012
scene.cycles.max_bounces=8;scene.cycles.diffuse_bounces=4;scene.cycles.glossy_bounces=4
scene.cycles.transparent_max_bounces=4
scene.cycles.use_light_tree=True
try:
    prefs=bpy.context.preferences.addons['cycles'].preferences
    prefs.compute_device_type='METAL';prefs.get_devices()
    available=[d for d in prefs.devices if d.type=='METAL']
    for d in prefs.devices:d.use=d.type=='METAL'
    scene.cycles.device='GPU' if available else 'CPU'
    print('RENDER_DEVICE',scene.cycles.device,[d.name for d in available])
except Exception as ex:
    scene.cycles.device='CPU';print('CPU_FALLBACK',ex)
scene.render.resolution_x=1000 if PREVIEW else 2048
scene.render.resolution_y=1000 if PREVIEW else 2048
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA';scene.render.image_settings.color_depth='8'
scene.render.film_transparent=False
scene.view_settings.view_transform='AgX'
scene.view_settings.look='AgX - Medium High Contrast'
scene.view_settings.exposure=0

# Very restrained optical glow; the shape of each lens remains visible.
scene.use_nodes=True;n=scene.node_tree.nodes;n.clear();links=scene.node_tree.links
rl=n.new('CompositorNodeRLayers');rl.location=(-300,0)
glow=n.new('CompositorNodeGlare');glow.location=(0,0);glow.glare_type='FOG_GLOW';glow.quality='HIGH'
glow.inputs['Threshold'].default_value=2.0
glow.inputs['Strength'].default_value=.16
glow.inputs['Size'].default_value=.22
out=n.new('CompositorNodeComposite');out.location=(260,0)
links.new(rl.outputs['Image'],glow.inputs['Image']);links.new(glow.outputs['Image'],out.inputs['Image'])

# PBR preview is immediately visible, with profile workspace kept useful for edits.
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type!='VIEW_3D':continue
        space=area.spaces.active
        if screen.name=='Layout':
            space.shading.type='MATERIAL';space.shading.use_scene_lights=True;space.shading.use_scene_world=True
            space.overlay.show_overlays=False;space.region_3d.view_perspective='CAMERA';space.region_3d.view_camera_zoom=8

scene['finition']='Carrosserie nacree; vitres opaques laquees; phares emisifs et faisceaux chauds; studio editable.'
scene['proportions_validees']='Avant 4,00 m / arriere 3,80 m. Aucun sommet du tram modifie par la finition.'
assert all(before[name]==tuple(tuple(v) for v in bpy.data.objects[name].bound_box) for name in MODEL_NAMES)
assert gp.inputs['Transmission Weight'].default_value==0 and gp.inputs['Alpha'].default_value==1
assert lp.inputs['Emission Strength'].default_value>0
report={'approved_model_bounds_unchanged':True,'opaque_glazing':True,'emissive_headlights':True,
        'headlight_beams':2,'render_engine':'Cycles','device':scene.cycles.device,'samples':scene.cycles.samples}
(ROOT/'verification_finition.json').write_text(json.dumps(report,indent=2))
root=bpy.data.objects.get('TRAM / reconstruction de la photo')
bpy.ops.object.select_all(action='DESELECT');root.select_set(True);bpy.context.view_layer.objects.active=root
scene.render.filepath=str(ROOT/('apercu_finition.png' if PREVIEW else 'Tram_Finition.png'))
if not PREVIEW:bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'Logo_Tram.blend'),compress=True)
bpy.ops.render.render(write_still=True)
if not PREVIEW:
    old_image=bpy.data.images.get('Tram - rendu final')
    if old_image:bpy.data.images.remove(old_image)
    result=bpy.data.images.load(scene.render.filepath,check_existing=False)
    result.name='Tram - rendu final';result.pack()
    ws=bpy.data.workspaces.get('Rendering') or bpy.data.workspaces.get('Tram - Rendu')
    if ws:
        ws.name='Tram - Rendu'
        for screen in ws.screens:
            for area in screen.areas:
                if area.type=='IMAGE_EDITOR':area.spaces.active.image=result
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'Logo_Tram.blend'),compress=True)
print('FINISH_READY',scene.render.filepath)
