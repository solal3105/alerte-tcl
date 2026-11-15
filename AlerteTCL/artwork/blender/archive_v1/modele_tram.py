"""Native, editable 3D tram model inspired by the app icon.
blender --background --factory-startup --python modele_tram.py -- --render
Use --preview for a quick 640 px render.
"""
import bpy
import bmesh
import math
import os
import sys
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT=os.path.dirname(os.path.abspath(__file__))
PREVIEW='--preview' in sys.argv
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for c in list(bpy.data.collections):bpy.data.collections.remove(c)
GROUPS={}
for key,label in [('body','01 · Carrosserie'),('glass','02 · Vitrages'),('lamps','03 · Phares'),
                  ('details','04 · Livrée et accessoires'),('panto','05 · Pantographe'),
                  ('wheels','06 · Châssis et roues'),('stage','07 · Décor'),('studio','08 · Studio'),
                  ('reference','09 · Référence')]:
    c=bpy.data.collections.new(label);bpy.context.scene.collection.children.link(c);GROUPS[key]=c

def link(obj,group):
    for c in list(obj.users_collection):c.objects.unlink(obj)
    GROUPS[group].objects.link(obj)
    return obj

def rgb(h):
    def lin(c):return c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4
    return tuple(lin(int(h[i:i+2],16)/255) for i in (0,2,4))

def material(name,color,rough=.35,metal=0,coat=0,emission=0):
    m=bpy.data.materials.new(name);m.use_nodes=True
    m.diffuse_color=(*rgb(color),1)
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*rgb(color),1)
    p.inputs['Roughness'].default_value=rough
    p.inputs['Metallic'].default_value=metal
    p.inputs['Coat Weight'].default_value=coat
    p.inputs['Coat Roughness'].default_value=.22
    p.inputs['Emission Color'].default_value=(*rgb(color),1)
    p.inputs['Emission Strength'].default_value=emission
    return m

WHITE=material('01 · Laque porcelaine','DEDEE2',.32,coat=.18)
NAVY=material('02 · Bleu graphite','253E52',.40)
RUBBER=material('03 · Caoutchouc','172B39',.62)
RED=material('04 · Corail','F63D40',.30,coat=.20)
GLASS=material('05 · Vitrage bleu • profondeur','13446E',.30,coat=.14)
GLASS.node_tree.nodes.get('Principled BSDF').inputs['Specular IOR Level'].default_value=.22
PANTO=material('06 · Pantographe bleu mat','334F65',.43)
GOLD=material('07 · Réflecteur laiton','BD8A36',.27,metal=.65)
LAMP=material('08 · Lentille jaune • émission réglable','FFE27A',.28,coat=.20,emission=.45)
HUB=material('09 · Moyeux','425465',.4,metal=.25)
for m in (WHITE,NAVY,RUBBER,PANTO):
    m.node_tree.nodes.get('Principled BSDF').inputs['Specular IOR Level'].default_value=.28

def mesh(name,vertices,faces,mat,group):
    data=bpy.data.meshes.new(name);data.from_pydata(vertices,[],faces);data.update()
    obj=bpy.data.objects.new(name,data);GROUPS[group].objects.link(obj);data.materials.append(mat)
    for p in data.polygons:p.use_smooth=True
    return obj

def normals(obj):
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True);bpy.context.view_layer.objects.active=obj
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT')
    obj.select_set(False)

def subdivision(obj,level=1):
    m=obj.modifiers.new('Subdivision · finition douce','SUBSURF');m.levels=level;m.render_levels=2

def shell(name,y0,y1,width0,width1,height0,height1,bottom,group='body',mat=WHITE,n=20,power=6):
    """Six welded quad grids: watertight, clean, subdividable rounded body."""
    verts=[];faces=[];lookup={}
    def point(p):
        key=tuple(round(v,8) for v in p)
        if key in lookup:return lookup[key]
        norm=sum(abs(v)**power for v in p)**(1/power)
        u,v,w=(q/norm for q in p)
        t=(v+1)/2
        width=width0*(1-t)+width1*t
        height=height0*(1-t)+height1*t
        taper=1-.085*((w+1)/2)**3
        co=(u*width/2*taper,y0+(v+1)/2*(y1-y0),bottom+(w+1)/2*height)
        lookup[key]=len(verts);verts.append(co);return len(verts)-1
    for axis in range(3):
        for sign in (-1,1):
            ids=[]
            other=[a for a in range(3) if a!=axis]
            for j in range(n+1):
                for i in range(n+1):
                    p=[0,0,0];p[axis]=sign;p[other[0]]=-1+2*i/n;p[other[1]]=-1+2*j/n
                    ids.append(point(p))
            for j in range(n):
                for i in range(n):
                    k=j*(n+1)+i;faces.append((ids[k],ids[k+1],ids[k+n+2],ids[k+n+1]))
    obj=mesh(name,verts,faces,mat,group);normals(obj);subdivision(obj)
    obj['Construction']='Volume fermé · maillage quad soudé · subdivision non destructive'
    return obj

def bvh_for(obj):
    bpy.context.view_layer.update()
    dg=bpy.context.evaluated_depsgraph_get();ev=obj.evaluated_get(dg)
    data=ev.to_mesh()
    tree=BVHTree.FromPolygons([v.co for v in data.vertices],[list(p.vertices) for p in data.polygons])
    ev.to_mesh_clear();return tree

def project(tree,axis,sign,offset):
    other=[a for a in range(3) if a!=axis]
    def position(u,v):
        start=[0,0,0];start[axis]=sign*12;start[other[0]]=u;start[other[1]]=v
        direction=[0,0,0];direction[axis]=-sign
        hit,normal,_,_=tree.ray_cast(Vector(start),Vector(direction),30)
        if hit is None:raise ValueError(f'Panel outside shell: {axis}, {u}, {v}')
        hit[axis]+=offset*sign
        return hit
    return position

def panel(name,cx,cy,width,height,projection,mat,group='glass',power=5,n=28,thickness=.009,taper=0):
    """All-quad superellipse panel, conformed to the evaluated body surface."""
    verts=[];faces=[]
    for j in range(n+1):
        for i in range(n+1):
            u=-1+2*i/n;v=-1+2*j/n;r=max(abs(u),abs(v))
            f=1 if r==0 else (abs(u/r)**power+abs(v/r)**power)**(-1/power)
            a=u*f*width/2*(1-taper*(v+1)/2);b=v*f*height/2
            verts.append(projection(cx+a,cy+b))
    for j in range(n):
        for i in range(n):
            k=j*(n+1)+i;faces.append((k,k+1,k+n+2,k+n+1))
    obj=mesh(name,verts,faces,mat,group)
    normals(obj)
    if thickness:
        m=obj.modifiers.new('Épaisseur réelle','SOLIDIFY');m.thickness=thickness;m.offset=0
    obj['Construction']='Surface quad conformée à la coque · épaisseur modifiable'
    return obj

def rounded_box(name,location,dimensions,mat,group,radius=.10):
    bpy.ops.mesh.primitive_cube_add(size=1,location=location)
    obj=bpy.context.object;obj.name=name;obj.dimensions=dimensions
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    obj.data.materials.append(mat);link(obj,group)
    m=obj.modifiers.new('Congés paramétriques','BEVEL');m.width=radius;m.segments=6
    obj.modifiers.new('Normales pondérées','WEIGHTED_NORMAL')
    for p in obj.data.polygons:p.use_smooth=True
    return obj

def sphere(name,location,scale,mat,group):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48,ring_count=24,location=location)
    obj=bpy.context.object;obj.name=name;obj.scale=scale;obj.data.materials.append(mat);link(obj,group)
    for p in obj.data.polygons:p.use_smooth=True
    return obj

def tube(name,points,radius,mat,group='details',caps=True):
    curve=bpy.data.curves.new(name,'CURVE');curve.dimensions='3D';curve.resolution_u=24
    curve.bevel_depth=radius;curve.bevel_resolution=5;curve.use_fill_caps=True
    s=curve.splines.new('BEZIER');s.bezier_points.add(len(points)-1)
    for p,co in zip(s.bezier_points,points):p.co=co;p.handle_left_type='AUTO';p.handle_right_type='AUTO'
    obj=bpy.data.objects.new(name,curve);GROUPS[group].objects.link(obj);curve.materials.append(mat)
    if caps:
        for i,p in enumerate((points[0],points[-1])):sphere(name+f' · embout {i+1}',p,(radius,)*3,mat,group)
    return obj

cab=shell('Cabine principale · volume quad',-1.55,2.00,2.90,2.12,3.40,2.51,.48,n=24,power=5)
rear=shell('Remorque · volume quad',2.38,4.05,2.04,1.96,2.30,2.17,.49,n=18)
cab_tree=bvh_for(cab);rear_tree=bvh_for(rear)
front=project(cab_tree,1,-1,.025)

# Separate substantial, rounded underbody volumes.
shell('Cabine · jupe inférieure',-1.49,1.97,2.63,1.94,.35,.29,.38,mat=NAVY,n=12,power=5)
rounded_box('Remorque · jupe inférieure',(0,3.18,.58),(1.83,1.52,.30),NAVY,'body',.13)
rounded_box('Articulation · soufflet',(0,2.19,1.58),(1.93,.35,2.12),RUBBER,'body',.19)
for y in (2.08,2.18,2.28):
    rounded_box('Articulation · nervure', (0,y,1.58),(1.98,.05,2.15),NAVY,'body',.02)

# Windshield: uniform solid thickness, proper blue glazing and a modeled gasket.
panel('Pare-brise · joint arrondi',0,2.61,2.34,1.79,project(cab_tree,1,-1,.018),RUBBER,power=4.2,n=36,taper=.07)
windshield=panel('Pare-brise · vitre bombée',0,2.61,2.22,1.67,project(cab_tree,1,-1,.037),GLASS,power=4.2,n=36,taper=.07)
windshield['Réglage']='Matériau 05 : couleur, rugosité et vernis. Les reflets proviennent des softboxes.'

# Side windows on both sides; identical construction, independently editable.
for sign,label in [(-1,'gauche'),(1,'droit')]:
    for i,(yc,zc,w,h) in enumerate([(-.30,2.30,1.18,1.50),(1.06,2.12,1.15,1.25)],1):
        panel(f'Cabine {label} · fenêtre {i} · joint',yc,zc,w,h,project(cab_tree,0,sign,.018),RUBBER,n=24,power=8)
        panel(f'Cabine {label} · fenêtre {i} · verre',yc,zc,w-.052,h-.052,project(cab_tree,0,sign,.035),GLASS,n=24,power=8)
    panel(f'Remorque {label} · joint',3.20,1.90,1.30,1.02,project(rear_tree,0,sign,.018),RUBBER,n=28,power=8)
    panel(f'Remorque {label} · verre',3.20,1.90,1.24,.96,project(rear_tree,0,sign,.034),GLASS,n=28,power=8)
    panel(f'Livrée {label} · bande cabine',.30,1.18,2.85,.22,project(cab_tree,0,sign,.023),RED,'details',power=14,n=36,thickness=.005)
    panel(f'Livrée {label} · bande remorque',3.20,1.13,1.35,.22,project(rear_tree,0,sign,.023),RED,'details',power=12,n=24,thickness=.005)

# A real red roof ribbon conforming to the 3D roof, with no projected image.
verts=[];faces=[]
for j in range(5):
    y=.39+(j/4-.5)*.17
    for i in range(65):
        angle=-1.19+2.38*i/64;direction=Vector((math.sin(angle),0,math.cos(angle)))
        origin=Vector((0,y,1.8))+direction*9
        hit,normal,_,_=cab_tree.ray_cast(origin,-direction,20)
        verts.append(hit+normal*.012)
for j in range(4):
    for i in range(64):
        k=j*65+i;faces.append((k,k+1,k+66,k+65))
ribbon=mesh('Livrée · retour de toit',verts,faces,RED,'details')
m=ribbon.modifiers.new('Épaisseur de la livrée','SOLIDIFY');m.thickness=.004

# Headlights: matching objects built from quad annular rings and domed lenses.
def headlight(label,cx):
    cz=1.31
    profiles=[(.274,.011),(.277,.033),(.261,.061),(.224,.081),(.196,.083),(.173,.064)]
    verts=[];faces=[]
    for radius,offset in profiles:
        for i in range(96):
            t=2*math.pi*i/96;p=front(cx+radius*math.cos(t),cz+radius*math.sin(t));p.y-=offset
            verts.append(p)
    for j in range(len(profiles)-1):
        for i in range(96):faces.append((j*96+i,j*96+(i+1)%96,(j+1)*96+(i+1)%96,(j+1)*96+i))
    housing=mesh(f'Phare {label} · cerclage',verts,faces,NAVY,'lamps');normals(housing)
    housing.data.materials.append(RUBBER);housing.data.materials.append(GOLD)
    for p in housing.data.polygons:
        p.material_index=2 if p.index//96==4 else (1 if p.index//96==3 else 0)
    hit,normal,_,_=cab_tree.ray_cast(Vector((cx,-12,cz)),Vector((0,1,0)),30)
    lenscenter=hit+normal*.086
    lens=sphere(f'Phare {label} · lentille',lenscenter,(.170,.035,.170),LAMP,'lamps')
    lens.rotation_mode='QUATERNION';lens.rotation_quaternion=Vector((0,-1,0)).rotation_difference(normal)
    thickness=housing.modifiers.new('Épaisseur du cerclage','SOLIDIFY');thickness.thickness=.012
    housing['Réglage']='Cerclage et réflecteur en anneaux quad. Lentille séparée, émission dans matériau 08.'
headlight('gauche',-.91);headlight('droit',.91)

# Smooth recessed mouth grille, all quads.
verts=[];faces=[]
for j in range(9):
    for i in range(49):
        u=-1+2*i/48;x=.46*u
        z=1.12-.055*(1-u*u)-j/8*.105*math.sqrt(max(0,1-u*u))
        p=front(x,z);p.y-=.018;verts.append(p)
for j in range(8):
    for i in range(48):
        k=j*49+i;faces.append((k,k+1,k+50,k+49))
grille=mesh('Calandre · sourire',verts,faces,RUBBER,'details')
bm=bmesh.new();bm.from_mesh(grille.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001);bm.to_mesh(grille.data);bm.free()
solid=grille.modifiers.new('Épaisseur','SOLIDIFY');solid.thickness=.012

# Real curved wiper following the windshield; independently adjustable.
points=[]
for x,z in [(.20,1.85),(.48,2.12),(.86,2.47)]:
    p=front(x,z);p.y-=.075;points.append(p)
tube('Essuie-glace · lame',points,.037,PANTO)
pivot=front(.20,1.85);pivot.y-=.07
sphere('Essuie-glace · axe',pivot,(.065,.045,.065),RUBBER,'details')

# Roof pantograph, based on real 3D rods. Its crossbar is aligned to the tram.
rounded_box('Pantographe · socle',(0,2.68,2.84),(.43,.40,.18),NAVY,'panto',.07)
tube('Pantographe · branche gauche',[(-.41,2.68,3.57),(0,2.68,2.93)],.068,PANTO,'panto')
tube('Pantographe · branche droite',[(.41,2.68,3.57),(0,2.68,2.93)],.068,PANTO,'panto')
tube('Pantographe · archet',[(-.68,2.68,3.61),(.68,2.68,3.61)],.105,PANTO,'panto')

# Real wheels with axles and hubs, partly enclosed by the shell.
for i,y in enumerate([-.85,1.51,3.28],1):
    axle_width=1.60 if i<3 else 1.40
    tube(f'Essieu {i}',[(-axle_width/2,y,.35),(axle_width/2,y,.35)],.10,NAVY,'wheels',False)
    for sign,label in [(-1,'gauche'),(1,'droit')]:
        bpy.ops.mesh.primitive_cylinder_add(vertices=64,radius=.315,depth=.28,location=(sign*axle_width/2,y,.35),rotation=(0,math.pi/2,0))
        wheel=bpy.context.object;wheel.name=f'Roue {i} {label}';link(wheel,'wheels');wheel.data.materials.append(RUBBER)
        bevel=wheel.modifiers.new('Flanc arrondi','BEVEL');bevel.width=.075;bevel.segments=5
        wheel.modifiers.new('Normales pondérées','WEIGHTED_NORMAL')
        for p in wheel.data.polygons:p.use_smooth=True
        sphere(f'Moyeu {i} {label}',(sign*(axle_width/2+.13),y,.35),(.025,.13,.13),HUB,'wheels')

# Perspective camera: natural geometry, no camera-dependent deformation.
bpy.ops.object.camera_add(location=(-5.4,-9.1,5.15))
camera=bpy.context.object;camera.name='CAMÉRA · logo'
target=Vector((0,.43,1.94));camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.lens=65;camera.data.sensor_width=36;link(camera,'studio')
scene=bpy.context.scene;scene.camera=camera
bpy.context.view_layer.update()

# Decorative medallion behind the model, independent of the model collection.
def flatmat(name,color,top=None):
    m=bpy.data.materials.new(name);m.use_nodes=True;n=m.node_tree.nodes;n.clear()
    out=n.new('ShaderNodeOutputMaterial');em=n.new('ShaderNodeEmission')
    em.inputs['Color'].default_value=(*rgb(color),1);m.node_tree.links.new(em.outputs[0],out.inputs[0])
    if top:
        tex=n.new('ShaderNodeTexCoord');sep=n.new('ShaderNodeSeparateXYZ');ramp=n.new('ShaderNodeValToRGB')
        ramp.color_ramp.elements[0].color=(*rgb(color),1);ramp.color_ramp.elements[1].color=(*rgb(top),1)
        links=m.node_tree.links;links.new(tex.outputs['Generated'],sep.inputs[0]);links.new(sep.outputs['Y'],ramp.inputs[0]);links.new(ramp.outputs[0],em.inputs['Color'])
    return m

def backmesh(name,pixels,faces,depth,mat):
    width=depth*camera.data.sensor_width/camera.data.lens
    vertices=[((x/1024-.5)*width,(.5-y/1024)*width,-depth) for x,y in pixels]
    obj=mesh(name,vertices,faces,mat,'stage');obj.matrix_world=camera.matrix_world.copy()
    obj.visible_diffuse=False;obj.visible_glossy=False;obj.visible_shadow=False
    return obj

def disk(name,radius,depth,mat):
    pts=[(512,512)]+[(512+radius*math.cos(t),512+radius*math.sin(t)) for t in [i*math.tau/256 for i in range(256)]]
    return backmesh(name,pts,[(0,i+1,(i+1)%256+1) for i in range(256)],depth,mat)

backmesh('Fond blanc',[(0,0),(1024,0),(1024,1024),(0,1024)],[(0,1,2,3)],27,flatmat('Décor · blanc','FFFFFF'))
disk('Médaillon · couronne',468,26.8,flatmat('Décor · menthe','ADF8BF','C0FBCF'))
disk('Médaillon · vert',434,26.6,flatmat('Décor · vert','23D74D','52EF76'))
for name,r,depth,a,mat in [('Médaillon · bord cyan',468,26.7,75.7,flatmat('Décor · cyan','91DFF6')),
                            ('Médaillon · secteur bleu',434,26.5,76.35,flatmat('Décor · azur','009FF1','0BB9F4'))]:
    pts=[(412,589)]+[(512+r*math.cos(t),512-r*math.sin(t)) for t in [math.radians(15+(a-15)*i/100) for i in range(101)]]
    backmesh(name,pts,[(0,i,i+1) for i in range(1,101)],depth,mat)

# A soft procedural shadow grounds the decorative icon without cutting the medallion.
shadowmat=flatmat('Décor · ombre douce','064524')
n=shadowmat.node_tree.nodes;links=shadowmat.node_tree.links
em=next(x for x in n if x.type=='EMISSION');out=next(x for x in n if x.type=='OUTPUT_MATERIAL')
tex=n.new('ShaderNodeTexCoord');sep=n.new('ShaderNodeSeparateXYZ');links.new(tex.outputs['Generated'],sep.inputs[0])
def calc(op,a,b=None):
    p=n.new('ShaderNodeMath');p.operation=op
    if isinstance(a,(int,float)):p.inputs[0].default_value=a
    else:links.new(a,p.inputs[0])
    if b is not None:
        if isinstance(b,(int,float)):p.inputs[1].default_value=b
        else:links.new(b,p.inputs[1])
    return p.outputs[0]
x=calc('SUBTRACT',sep.outputs['X'],.5);y=calc('SUBTRACT',sep.outputs['Y'],.5)
r2=calc('ADD',calc('MULTIPLY',x,x),calc('MULTIPLY',y,y))
alpha=calc('MULTIPLY',calc('EXPONENT',calc('MULTIPLY',r2,-16)),.80)
transparent=n.new('ShaderNodeBsdfTransparent');mix=n.new('ShaderNodeMixShader')
links.new(alpha,mix.inputs[0]);links.new(transparent.outputs[0],mix.inputs[1]);links.new(em.outputs[0],mix.inputs[2]);links.new(mix.outputs[0],out.inputs[0])
backmesh('Ombre · assise du tram',[(125,701),(867,701),(867,933),(125,933)],[(0,1,2,3)],26.2,shadowmat)

def area(name,location,target,power,size,color=(1,1,1),height=None):
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.color=color
    data.shape='RECTANGLE' if height else 'DISK';data.size=size
    if height:data.size_y=height
    obj=bpy.data.objects.new(name,data);GROUPS['studio'].objects.link(obj);obj.location=location
    obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()

area('Softbox · principal',(-3.8,-4.5,7),(0,0,1.5),540,5,(1,.98,.96))
area('Softbox · reflet vertical gauche',(-4,-6,3.9),(0,-1.4,2.3),120,1.0,(.75,.89,1),4.5)
area('Softbox · reflet vertical droit',(3.6,-4.3,3.8),(0,-1.4,2.3),180,1.1,(.87,.94,1),4.0)
area('Softbox · remplissage',(-1,-6,1.0),(0,0,1.7),95,4.0)
area('Softbox · toit',(2.0,3,6.5),(0,0,2),450,4)
scene.world.use_nodes=True
scene.world.node_tree.nodes.get('Background').inputs[0].default_value=(.87,.91,1,1)
scene.world.node_tree.nodes.get('Background').inputs[1].default_value=.35
scene.render.engine='CYCLES';scene.cycles.samples=32 if PREVIEW else 160;scene.cycles.use_denoising=True
scene.cycles.max_bounces=8
scene.render.resolution_x=640 if PREVIEW else 1024;scene.render.resolution_y=scene.render.resolution_x
scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
scene.view_settings.view_transform='Standard';scene.view_settings.look='None';scene.view_settings.exposure=0
scene.render.filepath=os.path.join(ROOT,'modele_tram_preview.png' if PREVIEW else 'logo_tram_render.png')

reference_path=os.path.abspath(os.path.join(ROOT,'../../Assets.xcassets/AppIcon.appiconset/iOS App Icons.png'))
im=bpy.data.images.load(reference_path);im.pack()
ref=bpy.data.objects.new('Logo original · référence embarquée',None);ref.empty_display_type='IMAGE';ref.data=im;ref.empty_display_size=5
ref.location=(6,0,2);ref.rotation_euler=(math.pi/2,0,0);ref.hide_render=True;GROUPS['reference'].objects.link(ref)
GROUPS['reference'].hide_viewport=True;GROUPS['reference'].hide_render=True

# One convenient parent controls the entire tram without moving the studio or logo background.
root=bpy.data.objects.new('TRAM · déplacer ou tourner le modèle ici',None)
root.empty_display_type='PLAIN_AXES';root.empty_display_size=.6;GROUPS['body'].objects.link(root)
for key in ('body','glass','lamps','details','panto','wheels'):
    for obj in GROUPS[key].objects:
        if obj!=root:obj.parent=root

# Check the actual deliverable topology, including evaluated panel thicknesses.
qa=[]
for obj in (cab,rear):
    bm=bmesh.new();bm.from_mesh(obj.data)
    bad=sum(not e.is_manifold for e in bm.edges)
    area_min=min(f.calc_area() for f in bm.faces)
    assert bad==0 and area_min>1e-8, f'Invalid shell: {obj.name}'
    assert all(len(f.verts)==4 for f in bm.faces), f'Non-quad shell: {obj.name}'
    qa.append(f'{obj.name}: {len(bm.faces)} quads, fermé, 0 arête non-manifold, 0 face dégénérée.')
    bm.free()
bpy.context.view_layer.update()
dg=bpy.context.evaluated_depsgraph_get()
for obj in GROUPS['glass'].objects:
    ev=obj.evaluated_get(dg);data=ev.to_mesh();bm=bmesh.new();bm.from_mesh(data)
    bad=sum(not e.is_manifold for e in bm.edges)
    assert bad==0, f'Panel thickness not closed: {obj.name}'
    qa.append(f'{obj.name}: épaisseur évaluée fermée, 0 arête non-manifold.')
    bm.free();ev.to_mesh_clear()
with open(os.path.join(ROOT,'verification.txt'),'w',encoding='utf-8') as f:
    f.write('\n'.join(qa)+'\nRéférence PNG embarquée. Aucun matériau ne dépend de cette image.\n')

readme=bpy.data.texts.new('À LIRE · Modèle du tram')
readme.write('MODÈLE 3D ÉDITABLE DU TRAM\n\n'
 'La silhouette reprend l’icône, avec des détails reconstruits proprement en 3D.\n'
 'Les coques sont des volumes quad fermés, avec subdivision non destructive.\n'
 'Les vitres utilisent des panneaux quad à épaisseur réelle, avec des joints séparés.\n'
 'Les reflets sont produits par les lumières du studio, sans texture du logo ni reflet dessiné.\n'
 'Phares : cerclages quad, réflecteurs et lentilles séparés, matériau 08 pour l’émission.\n'
 'Pantographe et essuie-glace : courbes 3D réglables. Roues et axes entièrement modélisés.\n'
 'Collection 07 : décor du logo, indépendant du tram. Collection 09 : référence PNG embarquée.\n'
 'La face arrière et les côtés invisibles dans la référence sont une interprétation.\n\n'
 'F12 : rendu. Pavé numérique 0 : caméra. Bouton central : orbite.\n')
for screen in bpy.data.screens:
    for a in screen.areas:
        if a.type=='VIEW_3D':
            s=a.spaces.active;s.region_3d.view_perspective='CAMERA';s.region_3d.view_camera_zoom=10
            s.overlay.show_overlays=False;s.shading.type='MATERIAL'
bpy.ops.object.select_all(action='DESELECT');cab.select_set(True);bpy.context.view_layer.objects.active=cab
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'Logo_Tram.blend'),compress=True)
print('MODEL_READY',len(bpy.data.objects))
if '--render' in sys.argv:bpy.ops.render.render(write_still=True);print('RENDER_READY',scene.render.filepath)
