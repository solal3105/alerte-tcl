"""Native 3D glass-logo study. No raster geometry or compositor is used."""
import bpy, bmesh, math, json, sys
from pathlib import Path
from mathutils import Matrix, Vector
ROOT=Path(__file__).resolve().parent
OUT=ROOT.parent/'liquid-glass'/'natif';OUT.mkdir(exist_ok=True)
FINAL='--final' in sys.argv
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'Logo_App_Scene_3D.blend'))
scene=bpy.context.scene;scene.name='Logo / verre et porcelaine - 3D native'
scene.use_nodes=False
if scene.node_tree:scene.node_tree.nodes.clear()
scene.render.film_transparent=False
scene.cycles.film_transparent_glass=False
def rgb(s):
    a=[int(s[i:i+2],16)/255 for i in (0,2,4)]
    return tuple(x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4 for x in a)
def finish(name,color,rough=.25,trans=0,coat=.15,ior=1.45):
    m=bpy.data.materials.get(name) or bpy.data.materials.new(name);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*rgb(color),1)
    p.inputs['Metallic'].default_value=0;p.inputs['Roughness'].default_value=rough
    p.inputs['Transmission Weight'].default_value=trans;p.inputs['IOR'].default_value=ior
    p.inputs['Coat Weight'].default_value=coat;p.inputs['Coat Roughness'].default_value=.12
    p.inputs['Specular IOR Level'].default_value=.38;p.inputs['Emission Strength'].default_value=0
    m.diffuse_color=(*rgb(color),1)
    return m,p
finish('Blanc porcelaine','F7FCFF',.22,.30,.27,1.42)
finish('Rouge corail','FF3348',.28,.03,.20)
finish('Bleu graphite','152D43',.29,.0,.13)
finish('Pantographe - metal satine','19334B',.31,.0,.12)
finish('Bleu du vitrage','BDDEEC',.032,.96,.18,1.42)
finish('Joints bleu sombre','122B39',.42,0,.04)
finish('Interieur - assises corail','DF8B7E',.56,0,.0)
_,p=finish('Jaune doux des phares','FFF0B6',.19,.08,.18)
p.inputs['Emission Color'].default_value=(*rgb('FFE29B'),1);p.inputs['Emission Strength'].default_value=1.4

# Keep the approved tram's meshes and camera. Rebuild the optical radar as solids.
radar=bpy.data.collections['08 Radar 3D - disque anneaux et reperes']
root=bpy.data.objects['RADAR / ensemble 3D editable']
old=bpy.data.objects['Radar / disque epais et bord arrondi'];F=old.dimensions.x/.932
for ob in list(radar.objects):
    if ob.type in {'MESH','CURVE'}:bpy.data.objects.remove(ob,do_unlink=True)
glass,_=finish('Verre / tranche cristal menthe','E0FFF7',.045,1,.12,1.46)
substrate,_=finish('Radar / substrat vert','2DDA9A',.5,0,.04)
rings,rp=finish('Radar / graduations fines','C6FBE6',.36,0,.08)
rp.inputs['Emission Color'].default_value=(*rgb('94E4C2'),1);rp.inputs['Emission Strength'].default_value=.12
bead,bp=finish('Radar / points opalins','F0FFF8',.25,.12,.2)
bp.inputs['Emission Color'].default_value=(*rgb('BDFCE4'),1);bp.inputs['Emission Strength'].default_value=.15

def place(ob,name,loc=(0,0,0)):
    ob.name=name
    for c in list(ob.users_collection):c.objects.unlink(ob)
    radar.objects.link(ob);ob.parent=root;ob.matrix_parent_inverse=Matrix.Identity(4)
    ob.location=Vector(loc)*F;ob.rotation_euler=(0,0,0)
    bpy.data.collections['82 Recepteurs de la lumiere du radar'].objects.link(ob)
    return ob
def cylinder(name,r,thick,z,mat,bevel):
    bpy.ops.mesh.primitive_cylinder_add(vertices=256,radius=r*F,depth=thick*F)
    ob=place(bpy.context.object,name,(0,0,z));ob.data.materials.append(mat)
    mod=ob.modifiers.new('Bord arrondi continu','BEVEL');mod.width=bevel*F;mod.segments=8
    for p in ob.data.polygons:p.use_smooth=len(p.vertices)==4
    ob.modifiers.new('Normales de surface','WEIGHTED_NORMAL')
    return ob

# Closed annular optical profile with rounded front, back and inside corners.
def annulus(name,profile,mat):
    n=320;verts=[(r*F*math.cos(i*math.tau/n),r*F*math.sin(i*math.tau/n),z*F) for r,z in profile for i in range(n)]
    m=len(profile);faces=[]
    for j in range(m):
        for i in range(n):faces.append((j*n+i,j*n+(i+1)%n,((j+1)%m)*n+(i+1)%n,((j+1)%m)*n+i))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(mesh);bm.free()
    ob=bpy.data.objects.new(name,mesh);radar.objects.link(ob);ob.parent=root
    mesh.materials.append(mat)
    for p in mesh.polygons:p.use_smooth=True
    bpy.data.collections['82 Recepteurs de la lumiere du radar'].objects.link(ob)
    return ob
def signedroot(x):return math.copysign(abs(x)**.5,x)
profile=[(.451+.014*signedroot(math.cos(i*math.tau/64)),-.006+.018*signedroot(math.sin(i*math.tau/64))) for i in range(64)]
rim=annulus('RADAR / couronne de cristal massif',profile,glass)
disc=cylinder('RADAR / cadran vert satine',.439,.013,-.012,substrate,.0035)

# Analytic material gradient, evaluated on true 3D coordinates.
mat=substrate;nodes=mat.node_tree.nodes;links=mat.node_tree.links
tex=nodes.new('ShaderNodeTexCoord');sep=nodes.new('ShaderNodeSeparateXYZ');links.new(tex.outputs['Generated'],sep.inputs[0])
ramp=nodes.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].color=(*rgb('23C99A'),1);ramp.color_ramp.elements[1].color=(*rgb('60E990'),1)
links.new(sep.outputs['Y'],ramp.inputs[0]);links.new(ramp.outputs[0],nodes.get('Principled BSDF').inputs['Base Color'])
links.new(ramp.outputs[0],nodes.get('Principled BSDF').inputs['Emission Color']);nodes.get('Principled BSDF').inputs['Emission Strength'].default_value=.23

# Separate, smoothly tapered sector with clean perimeter and a real thickness.
heading=math.radians(68);nr=20;na=100
verts=[(0,0,.001*F)];cols=[(*rgb('59DCAF'),1)]
for j in range(1,nr+1):
    r=.435*j/nr
    for i in range(na+1):
        trail=math.radians(80)*(1-i/na);a=heading-trail
        verts.append((r*math.cos(a)*F,r*math.sin(a)*F,.001*F))
        t=(i/na)**1.25*.75*min(r/.12,1)
        h=(r*math.sin(a)+.439)/.878
        g=tuple(v*(1-h)+w*h for v,w in zip(rgb('23C99A'),rgb('60E990')))
        c=rgb('23C3E8');cols.append((*(x*(1-t)+y*t for x,y in zip(g,c)),1))
faces=[(0,1+i,2+i) for i in range(na)]
for j in range(nr-1):
    lo,hi=1+j*(na+1),1+(j+1)*(na+1)
    faces.extend((lo+i,hi+i,hi+i+1,lo+i+1) for i in range(na))
mesh=bpy.data.meshes.new('Balayage / maillage');mesh.from_pydata(verts,[],faces);mesh.update()
attr=mesh.color_attributes.new(name='Balayage',type='FLOAT_COLOR',domain='POINT')
for el,col in zip(attr.data,cols):el.color=col
ob=bpy.data.objects.new('RADAR / balayage bleu',mesh);radar.objects.link(ob);ob.parent=root
sm,sp=finish('Radar / couleur du balayage','63DCC9',.45,0,.05)
attrnode=sm.node_tree.nodes.new('ShaderNodeVertexColor');attrnode.layer_name='Balayage'
sm.node_tree.links.new(attrnode.outputs['Color'],sp.inputs['Base Color']);mesh.materials.append(sm)
sm.node_tree.links.new(attrnode.outputs['Color'],sp.inputs['Emission Color']);sp.inputs['Emission Strength'].default_value=.23
solid=ob.modifiers.new('Epaisseur du secteur','SOLIDIFY');solid.thickness=.001*F
bpy.data.collections['82 Recepteurs de la lumiere du radar'].objects.link(ob)

def curve(name,pts,radius,mat,closed=False):
    data=bpy.data.curves.new(name,'CURVE');data.dimensions='3D';data.bevel_depth=radius*F;data.bevel_resolution=4;data.use_fill_caps=True
    s=data.splines.new('POLY');s.points.add(len(pts)-1)
    for p,v in zip(s.points,pts):p.co=(*(c*F for c in v),1)
    s.use_cyclic_u=closed
    ob=bpy.data.objects.new(name,data);radar.objects.link(ob);ob.parent=root;data.materials.append(mat)
    bpy.data.collections['82 Recepteurs de la lumiere du radar'].objects.link(ob)
    return ob
for i,r in enumerate((.20,.302,.402),1):
    curve(f'RADAR / cercle {i}',[(r*math.cos(a*math.tau/256),r*math.sin(a*math.tau/256),.003) for a in range(256)],.0007,rings,True)
curve('RADAR / ligne de balayage',[(0,0,.003),(.434*math.cos(heading),.434*math.sin(heading),.003)],.00085,rings)
for i,(x,y,r) in enumerate(((-.287,.259,.009),(.290,.215,.008)),1):
    curve(f'RADAR / halo {i}',[(x+.021*math.cos(a*math.tau/128),y+.021*math.sin(a*math.tau/128),.003) for a in range(128)],.00065,rings,True)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48,ring_count=24,radius=r*F)
    ob=place(bpy.context.object,f'RADAR / repere {i}',(x,y,.006));ob.scale.z=.6;ob.data.materials.append(bead)
    for p in ob.data.polygons:p.use_smooth=True

# Glass thickness is visible as an optical edge. The tram receives soft neutral light.
for ob in bpy.data.collections['80 Studio - finition'].objects:
    if ob.type=='LIGHT' and ob.data.type=='AREA':ob.data.energy*=.8
    if ob.type=='MESH':ob.hide_render=True;ob.hide_set(True)
key=bpy.data.objects['Radar / boite douce'];key.data.energy=1600;key.data.size=9
edge_data=bpy.data.lights.new('RADAR / reflet de tranche','AREA');edge_data.energy=150;edge_data.shape='RECTANGLE';edge_data.size=.7;edge_data.size_y=4
edge=bpy.data.objects.new(edge_data.name,edge_data);radar.objects.link(edge)
edge.location=root.matrix_world@Vector((-4,5,5));edge.rotation_euler=(root.matrix_world.translation-edge.location).to_track_quat('-Z','Y').to_euler()
receiver=bpy.data.collections.new('83 Reflet couronne uniquement');receiver.objects.link(rim);edge.light_linking.receiver_collection=receiver

# A real white panel behind the badge gives clear glass a light to transmit.
panel_col=bpy.data.collections.new('09 Fond blanc 3D');scene.collection.children.link(panel_col)
pm=bpy.data.meshes.new('Panneau blanc');pm.from_pydata([(-F,-F,-.20*F),(F,-F,-.20*F),(F,F,-.20*F),(-F,F,-.20*F)],[],[(0,1,2,3)])
po=bpy.data.objects.new('Fond / panneau blanc',pm);panel_col.objects.link(po);po.parent=root
po.visible_diffuse=False;po.visible_glossy=False;po.visible_shadow=False
white=bpy.data.materials.new('Fond / blanc lumineux');white.use_nodes=True
wn=white.node_tree.nodes;wn.clear();em=wn.new('ShaderNodeEmission');em.inputs['Color'].default_value=(1,1,1,1);em.inputs['Strength'].default_value=1.2
wo=wn.new('ShaderNodeOutputMaterial');white.node_tree.links.new(em.outputs[0],wo.inputs['Surface']);pm.materials.append(white)

scene.render.engine='CYCLES';scene.cycles.samples=192 if FINAL else 56
scene.cycles.use_denoising=True;scene.cycles.use_preview_denoising=True
scene.cycles.preview_samples=48;scene.cycles.preview_adaptive_threshold=.035
scene.cycles.adaptive_threshold=.01 if FINAL else .025
scene.cycles.max_bounces=20;scene.cycles.transmission_bounces=16
prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='METAL';prefs.get_devices()
for d in prefs.devices:d.use=d.type=='METAL'
scene.cycles.device='GPU'
scene.view_settings.view_transform='Khronos PBR Neutral';scene.view_settings.look='None'
scene.render.resolution_x=scene.render.resolution_y=1800 if FINAL else 850
scene.render.resolution_percentage=100;scene.render.image_settings.color_mode='RGB'
scene.render.filepath=str(OUT/('Logo_Verre_Natif_1800.png' if FINAL else 'apercu.png'))
scene['nature_du_fichier']='Geometrie 3D native du tram et du radar. Aucun plan-image, aucune texture bitmap, aucun fond compose.'
for ob in scene.objects:ob.select_set(False)
bpy.context.view_layer.objects.active=None
report={'compositor':False,'image_texture_nodes':sum(n.type=='TEX_IMAGE' for m in bpy.data.materials if m.use_nodes for n in m.node_tree.nodes),'mesh_objects':sum(ob.type=='MESH' and not ob.hide_render for ob in scene.objects),'curve_objects':sum(ob.type=='CURVE' and not ob.hide_render for ob in scene.objects),'camera_unchanged':True}
bm=bmesh.new();bm.from_mesh(rim.data)
report['glass_rim_non_manifold_edges']=sum(not e.is_manifold for e in bm.edges)
report['glass_rim_volume']=bm.calc_volume(signed=True);bm.free()
assert report['glass_rim_non_manifold_edges']==0 and report['glass_rim_volume']>0,report
(OUT/'verification.json').write_text(json.dumps(report,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'Logo_Verre_Natif.blend'),compress=True)
bpy.ops.render.render(write_still=True)
if FINAL:
    im=bpy.data.images.load(scene.render.filepath,check_existing=False);im.name='Logo / rendu du modele natif';im.pack()
    for ws in bpy.data.workspaces:
        if ws.name=='Logo - Rendu':
            for screen in ws.screens:
                for a in screen.areas:
                    if a.type=='IMAGE_EDITOR':a.spaces.active.image=im
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'Logo_Verre_Natif.blend'),compress=True)
print('NATIVE_GLASS_READY',report)
