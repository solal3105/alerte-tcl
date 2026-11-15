"""Separate native Blender Liquid Glass variant and Icon Composer source layers."""
from pathlib import Path
import bpy, sys, math
from mathutils import Vector

ROOT=Path(__file__).resolve().parent
OUT=ROOT.parent/'liquid-glass';OUT.mkdir(exist_ok=True)
LAYERS=OUT/'layers';LAYERS.mkdir(exist_ok=True)
FINAL='--final' in sys.argv
EXPORT='--layers' in sys.argv
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'Logo_App_Scene_3D.blend'))
scene=bpy.context.scene;scene.name='Logo / Liquid Glass'
scene.use_nodes=False
def rgb(s):
    a=[int(s[i:i+2],16)/255 for i in (0,2,4)]
    return tuple(c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in a)
def finish(name,col,trans,rough,coat,ior=1.45):
    m=bpy.data.materials[name];p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*rgb(col),1)
    p.inputs['Transmission Weight'].default_value=trans
    p.inputs['Roughness'].default_value=rough
    p.inputs['Coat Weight'].default_value=coat
    p.inputs['Coat Roughness'].default_value=.065
    p.inputs['Metallic'].default_value=0
    p.inputs['Specular IOR Level'].default_value=.5
    p.inputs['IOR'].default_value=ior
    m.diffuse_color=(*rgb(col),1)
    return p
finish('Blanc porcelaine','F4FAFF',.38,.145,.65,1.42)
finish('Rouge corail','FF536B',.28,.12,.65)
finish('Bleu graphite','335A76',.12,.13,.6)
finish('Pantographe - metal satine','375975',.10,.16,.5)
finish('Bleu du vitrage','B4DCEE',.97,.024,.4,1.42)
finish('Joints bleu sombre','243F54',.08,.2,.35)
p=finish('Jaune doux des phares','FFE9AA',.25,.09,.5)
p.inputs['Emission Strength'].default_value=2
finish('Radar / bord menthe satine','BBFBE8',.91,.06,.4,1.45)
for name in ('Radar / couleurs du disque',):
    m=bpy.data.materials[name];p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Transmission Weight'].default_value=.68
    p.inputs['Roughness'].default_value=.075
    p.inputs['Coat Weight'].default_value=.4
    p.inputs['Coat Roughness'].default_value=.045
    p.inputs['Emission Strength'].default_value=.015
    p.inputs['Specular IOR Level'].default_value=.5
    p.inputs['IOR'].default_value=1.42
radar=bpy.data.collections['08 Radar 3D - disque anneaux et reperes']
root=bpy.data.objects['RADAR / ensemble 3D editable']
disk=bpy.data.objects['Radar / disque epais et bord arrondi']
F=disk.dimensions.x/.932
for ob in radar.objects:
    if ob.type=='MESH' and 'Couleur radar' in ob.data.color_attributes:
        attr=ob.data.color_attributes['Couleur radar']
        for el in attr.data:
            c=el.color;el.color=(*(v*.55+.45 for v in c[:3]),1)
        solid=ob.modifiers.get('Epaisseur reelle')
        if solid:solid.thickness=.008*F
        if 'secteur' in ob.name:ob.location.z+=.009*F
    if ob.type=='CURVE':ob.location.z+=.018*F

# A native pastel back panel is visible through the thick glass radar.
backcol=bpy.data.collections.new('09 Fond nacre 3D');scene.collection.children.link(backcol)
mesh=bpy.data.meshes.new('Fond nacre / surface')
mesh.from_pydata([(-F,-F,-.4*F),(F,-F,-.4*F),(F,F,-.4*F),(-F,F,-.4*F)],[],[(0,1,2,3)])
ob=bpy.data.objects.new('Fond nacre / panneau 3D',mesh);backcol.objects.link(ob);ob.parent=root
attr=mesh.color_attributes.new(name='Teinte nacree',type='FLOAT_COLOR',domain='POINT')
for el,col in zip(attr.data,('D0F8E9','E2E4FB','F5F7FD','E4FBF6')):el.color=(*rgb(col),1)
m=bpy.data.materials.new('Fond / nacre menthe et pervenche');m.use_nodes=True
n=m.node_tree.nodes;n.clear();a=n.new('ShaderNodeVertexColor');a.layer_name='Teinte nacree'
e=n.new('ShaderNodeEmission');e.inputs['Strength'].default_value=1
o=n.new('ShaderNodeOutputMaterial');m.node_tree.links.new(a.outputs['Color'],e.inputs['Color']);m.node_tree.links.new(e.outputs[0],o.inputs['Surface'])
mesh.materials.append(m)

# Clear, slender reflections emphasize the glass without changing the silhouette.
ld=bpy.data.lights.new('Liquid Glass / reflet vertical','AREA');ld.energy=360;ld.shape='RECTANGLE';ld.size=.7;ld.size_y=5
lo=bpy.data.objects.new(ld.name,ld);bpy.data.collections['80 Studio - finition'].objects.link(lo)
lo.location=(-4,-3,5);lo.rotation_euler=(Vector((0,2,1.7))-lo.location).to_track_quat('-Z','Y').to_euler()
lo.light_linking.receiver_collection=bpy.data.collections['81 Recepteurs des lumieres du tram']

scene.render.engine='CYCLES';scene.cycles.samples=160 if FINAL else 48
scene.cycles.adaptive_threshold=.015 if FINAL else .045
scene.cycles.max_bounces=20;scene.cycles.transmission_bounces=16
scene.cycles.preview_samples=40;scene.cycles.use_preview_denoising=True
prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='METAL';prefs.get_devices()
for d in prefs.devices:d.use=d.type=='METAL'
scene.cycles.device='GPU'
scene.render.resolution_x=scene.render.resolution_y=1600 if FINAL else 768
scene.render.resolution_percentage=100
scene.render.film_transparent=False
scene.render.image_settings.color_mode='RGB';scene.render.image_settings.file_format='PNG'
scene.render.filepath=str(OUT/('AlerteTCL_LiquidGlass_1600.png' if FINAL else 'apercu_liquid_glass.png'))
scene['variante']='Liquid Glass : coque opaline, liseres corail translucides, vitrage bleu et radar en verre. Scene native separee.'
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'Logo_App_LiquidGlass.blend'),compress=True)
bpy.ops.render.render(write_still=True)
if FINAL:
    im=bpy.data.images.load(scene.render.filepath,check_existing=False);im.name='Logo / rendu Liquid Glass';im.pack()
    for ws in bpy.data.workspaces:
        if ws.name=='Logo - Rendu':
            for screen in ws.screens:
                for area in screen.areas:
                    if area.type=='IMAGE_EDITOR':area.spaces.active.image=im
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'Logo_App_LiquidGlass.blend'),compress=True)
if EXPORT:
    # Full-size aligned alpha layers. Icon Composer supplies the dynamic finish.
    # The Blender master remains complete; these visibility changes are unsaved.
    for ob in radar.objects:
        if ob.type in {'MESH','CURVE'}:ob.hide_render=True
    for ob in backcol.objects:ob.hide_render=True
    scene.render.film_transparent=True;scene.cycles.film_transparent_glass=True
    scene.render.image_settings.color_mode='RGBA'
    scene.render.resolution_x=scene.render.resolution_y=1024
    scene.cycles.samples=96;scene.cycles.adaptive_threshold=.025
    scene.render.filepath=str(LAYERS/'Tram_3D.png')
    bpy.ops.render.render(write_still=True)
print('LIQUID_GLASS_READY',scene.render.filepath)
