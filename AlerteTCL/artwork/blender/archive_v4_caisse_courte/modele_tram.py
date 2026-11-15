"""Clean native 3D tram inspired by the app icon.
Both coach bodies share one physical section. Features are built in local X/Z or Y/Z
coordinates and seated on the actual surfaces, independently of any camera or image.
"""
from pathlib import Path
import sys, math, json
import bpy, bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import tessellate_polygon, barycentric_transform
ROOT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT))
import tram_geometry as g

bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
for c in list(bpy.data.collections):bpy.data.collections.remove(c)
COL={}
for k,n in [('body','01 Volumes du logo'),('glass','02 Vitres encastrees'),('lamps','03 Phares et sourire'),('livery','04 Rubans corail'),('wheels','05 Roues et chassis'),('panto','06 Pantographe'),('cutters','90 Decoupes'),('reference','91 Reference et point de vue')]:
 c=bpy.data.collections.new(n);bpy.context.scene.collection.children.link(c);COL[k]=c

def mat(n,c):
 m=bpy.data.materials.new(n);m.diffuse_color=(*c,1);return m
WHITE=mat('Blanc porcelaine',(.90,.915,.95));NAVY=mat('Bleu graphite',(.035,.075,.115));RUBBER=mat('Joints bleu sombre',(.020,.043,.065));GLASS=mat('Bleu du vitrage',(.038,.17,.34));RED=mat('Rouge corail',(.95,.045,.040));YELLOW=mat('Jaune doux des phares',(1,.80,.18));GOLD=mat('Reflecteurs',(.53,.33,.065));WIPER=mat('Essuie glace',(.14,.21,.29))
# Shared physical dimensions, in metres. Both bodies use exactly the same section.
H=2.74
L=4.00
RL=1.88
GAP=.26
WR=HR=1.0
POWER=7.0

def surface(p,y0,y1,w0,w1,h0,h1,bottom=.30,power=POWER):
 norm=sum(abs(v)**power for v in p)**(1/power)
 u,v,w=(q/norm for q in p);t=(v+1)/2
 width=w0*(1-t)+w1*t;height=h0*(1-t)+h1*t
 return (u*width/2*(1-.045*((w+1)/2)**3),y0+t*(y1-y0),bottom+(w+1)/2*height)

def body(name,y0,y1,w0,w1,h0,h1,bottom=.30,n=44,material=WHITE,power=POWER):
 vs=[];fs=[];look={}
 def pt(p):
  key=tuple(round(v,8) for v in p)
  if key not in look:
   look[key]=len(vs);vs.append(surface(p,y0,y1,w0,w1,h0,h1,bottom,power))
  return look[key]
 for axis in range(3):
  for sign in (-1,1):
   other=[a for a in range(3) if a!=axis];ids=[]
   for j in range(n+1):
    for i in range(n+1):
     p=[0.,0.,0.];p[axis]=sign;p[other[0]]=-1+2*i/n;p[other[1]]=-1+2*j/n;ids.append(pt(p))
   for j in range(n):
    for i in range(n):
     k=j*(n+1)+i;fs.append((ids[k],ids[k+1],ids[k+n+2],ids[k+n+1]))
 obj=g.mesh(name,vs,fs,COL['body'],material,smooth=True);g.orient(obj)
 return obj

cab=body('Cabine / volume continu',0,L,2.30,2.30*WR,H,H*HR)
rear=body('Remorque / volume continu',L+GAP,L+GAP+RL,2.30*WR,2.30*WR,H*HR,H*HR)
# Closed quad body, with no separate roof-to-nose seam.
BVH_DATA={}
def tree(obj):
 bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();ev=obj.evaluated_get(dg);data=ev.to_mesh()
 data.calc_loop_triangles()
 vs=[obj.matrix_world@v.co for v in data.vertices]
 ns=[(obj.matrix_world.to_3x3()@v.normal).normalized() for v in data.vertices]
 ts=[tuple(t.vertices) for t in data.loop_triangles]
 result=BVHTree.FromPolygons(vs,ts,all_triangles=True)
 BVH_DATA[result]=(vs,ns,ts);ev.to_mesh_clear();return result

def smooth_normal(bvh,p,index):
 vs,ns,ts=BVH_DATA[bvh];a,b,c=ts[index]
 return barycentric_transform(p,vs[a],vs[b],vs[c],ns[a],ns[b],ns[c]).normalized()
CAB=tree(cab);REAR=tree(rear)
def hit(uv,chart):
 return chart(uv)

def bezier(points,steps=12):
 """Closed sequence: starting point, then cubic control triplets."""
 out=[];a=Vector(points[0])
 for i in range(1,len(points),3):
  b,c,d=map(Vector,points[i:i+3])
  for j in range(steps):
   t=j/steps;out.append(tuple((1-t)**3*a+3*(1-t)**2*t*b+3*(1-t)*t*t*c+t**3*d))
  a=d
 return out

def scaled(loop,scale):
 cx=sum(x for x,y in loop)/len(loop);cy=sum(y for x,y in loop)/len(loop)
 return [(cx+(x-cx)*scale,cy+(y-cy)*scale) for x,y in loop]

def patch(name,loop,bvh,front,back,collection,material,mirror=False):
 """Triangulated and subdivided curved solid patch, with a clean sealed perimeter."""
 # Remove redundant collinear contour samples before tessellation. In metre units,
 # a triangle fan through those samples creates zero-area slivers in Boolean inputs.
 loop=list(loop)
 changed=True
 while changed and len(loop)>3:
  changed=False;clean=[]
  for i,b in enumerate(loop):
   a=loop[i-1];c=loop[(i+1)%len(loop)]
   length=math.hypot(c[0]-a[0],c[1]-a[1])
   distance=abs((b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0]))/max(length,1e-12)
   if distance<1e-6:changed=True
   else:clean.append(b)
  if len(clean)<3:break
  loop=clean
 coords=[Vector((x,y,0)) for x,y in loop]
 tris=tessellate_polygon([coords]);lookup={tuple(v):i for i,v in enumerate(coords)}
 bm=bmesh.new();vv=[bm.verts.new(v) for v in coords]
 for t in tris:bm.faces.new([vv[v if isinstance(v,int) else lookup[tuple(v)]] for v in t])
 bmesh.ops.subdivide_edges(bm,edges=list(bm.edges),cuts=10,use_grid_fill=True)
 bm.verts.index_update();bm.faces.index_update()
 uv=[(v.co.x,v.co.y) for v in bm.verts];faces=[tuple(v.index for v in f.verts) for f in bm.faces]
 borders=[(e.verts[0].index,e.verts[1].index) for e in bm.edges if e.is_boundary];bm.free()
 pn=[hit(p,bvh) for p in uv];n=len(pn)
 vs=[p+no*front for p,no in pn]+[p+no*back for p,no in pn]
 fs=faces+[tuple(i+n for i in reversed(f)) for f in faces]
 fs += [(a,b,b+n,a+n) for a,b in borders]
 obj=g.mesh(name,vs,fs,collection,material,smooth=True);g.orient(obj)
 # Use the body surface normals on the curved glazing/livery, independent of skinny triangles.
 custom=[]
 for poly in obj.data.polygons:
  top=all(i<n for i in poly.vertices);bottom=all(i>=n for i in poly.vertices)
  for i in poly.vertices:custom.append(pn[i%n][1] if top else (-pn[i%n][1] if bottom else poly.normal))
 obj.data.normals_split_custom_set(custom)
 if mirror:
  dup=obj.copy();dup.data=obj.data.copy();dup.name=name+' / cote oppose';collection.objects.link(dup)
  for v in dup.data.vertices:v.co.x=-v.co.x
  g.orient(dup)
  cn=[]
  for poly in dup.data.polygons:
   top=all(i<n for i in poly.vertices);bottom=all(i>=n for i in poly.vertices)
   for i in poly.vertices:
    no=pn[i%n][1].copy() if top else (-pn[i%n][1] if bottom else Vector((-poly.normal.x,poly.normal.y,poly.normal.z)))
    no.x=-no.x;cn.append(no)
  dup.data.normals_split_custom_set(cn)
  return obj,dup
 return obj

def ring(name,outer,inner,bvh,collection,material,mirror=False):
 n=len(outer);vs=[]
 for loop,depth in [(outer,.010),(inner,.013),(inner,-.054),(outer,-.054)]:
  for pix in loop:
   p,no=hit(pix,bvh);vs.append(p+no*depth)
 fs=[]
 for j in range(4):
  for i in range(n):fs.append((j*n+i,j*n+(i+1)%n,((j+1)%4)*n+(i+1)%n,((j+1)%4)*n+i))
 ob=g.mesh(name,vs,fs,collection,material,smooth=True);g.orient(ob)
 if mirror:
  dup=ob.copy();dup.data=ob.data.copy();dup.name=name+' / cote oppose';collection.objects.link(dup)
  for v in dup.data.vertices:v.co.x=-v.co.x
  g.orient(dup)
 return ob

def cut(obj,tool,label):
 m=obj.modifiers.new(label,'BOOLEAN');m.operation='DIFFERENCE';m.solver='EXACT';m.object=tool
 tool.hide_render=True;tool.hide_set(True);tool.display_type='WIRE'
 # Apply so the delivered model has actual pocket topology and no evaluation ambiguity.
 bpy.context.view_layer.objects.active=obj
 bpy.ops.object.modifier_apply(modifier=m.name)
 bm=bmesh.new();bm.from_mesh(obj.data)
 bmesh.ops.dissolve_degenerate(bm,dist=1e-6,edges=list(bm.edges))
 bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7)
 bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(obj.data);bm.free()

GLAZING=[]
def window(name,loop,obj,bvh,mirror=False):
 inner=scaled(loop,.969)
 cutters=patch(name+' / outil',scaled(loop,.998),bvh,.046,-.110,COL['cutters'],None,mirror)
 if not isinstance(cutters,tuple):cutters=(cutters,)
 for tool in cutters:cut(obj,tool,'Poche reelle '+name)
 ring(name+' / joint fin',loop,inner,bvh,COL['glass'],RUBBER,mirror)
 panes=patch(name+' / vitrage',scaled(inner,.998),bvh,-.009,-.021,COL['glass'],GLASS,mirror)
 if not isinstance(panes,tuple):panes=(panes,)
 GLAZING.extend((p,obj) for p in panes)

# Native modelling constraints. The photo informs these proportions, not the depth of vertices.
# All side windows share the same real Z levels.
def side_chart(source):
    def chart(uv):
        y,z=uv
        point,no,index,_=source.ray_cast(Vector((-5,y,z)),Vector((1,0,0)),10)
        if point is None:raise RuntimeError('Side feature outside body')
        return point,smooth_normal(source,point,index)
    return chart

def front_chart(uv):
    x,z=uv
    point,no,index,_=CAB.ray_cast(Vector((x,-5,z)),Vector((0,1,0)),10)
    if point is None:raise RuntimeError('Front feature outside body')
    return point,smooth_normal(CAB,point,index)

SIDE_CAB=side_chart(CAB);SIDE_REAR=side_chart(REAR);FRONT=front_chart
# Parameters below are native surface coordinates, independent of the inspection camera.
def side_uv(y,z,chart=None):return (y,z)
def front_uv(x,z):return (x,z)

def front_outline(points,steps=12):
    return [front_uv(x,z) for x,z in bezier(points,steps)]

windshield=front_outline([(-.90,1.33),(-.99,1.40),(-1.00,2.05),(-.91,2.43),
 (-.87,2.68),(-.61,2.76),(-.28,2.77),(-.10,2.79),(.10,2.79),(.28,2.77),
 (.61,2.76),(.87,2.68),(.91,2.43),(1.00,2.05),(.99,1.40),(.90,1.33),
 (.60,1.21),(-.60,1.21),(-.90,1.33)],12)
window('Pare brise enveloppant',windshield,cab,FRONT)
for name,yc,width,obj,bvh in [
 ('Cabine / vitre cote nez',1.15,1.20,cab,SIDE_CAB),
 ('Cabine / vitre cote articulation',2.70,1.28,cab,SIDE_CAB),
 ('Remorque / grande vitre',L+GAP+RL/2,RL-.55,rear,SIDE_REAR)]:
    outline=[side_uv(y,z,bvh) for y,z in g.rounded_loop(yc,1.915,width,1.17,.095,20)]
    window(name,outline,obj,bvh,True)

# Solid, thin coral bands at common elevations, with the reference's downward front tip.
for name,outline,bvh in [
 ('Cabine / bande corail',[(.40,1.24),(L-.28,1.24),(L-.28,1.05),(.72,1.05),(.60,.91),(.40,.91)],SIDE_CAB),
 ('Remorque / bande corail',[(L+GAP+.24,1.24),(L+GAP+RL-.24,1.24),(L+GAP+RL-.24,1.05),(L+GAP+.24,1.05)],SIDE_REAR)]:
    patch(name,[side_uv(y,z,bvh) for y,z in outline],bvh,.010,.002,COL['livery'],RED,True)

# Roof ribbon stops at the window heads; it follows the same continuous body surface.
ribbon_end=hit(side_uv(1.90,2.50),SIDE_CAB)[0]
y_ribbon=ribbon_end.y
ribbon_angle=math.atan2(abs(ribbon_end.x),ribbon_end.z-(.30+H*.46))
rv=[];rf=[];N=80
for j in range(5):
 y=y_ribbon+(j/4-.5)*.15
 for i in range(N+1):
  a=-ribbon_angle+2*ribbon_angle*i/N;direction=Vector((math.sin(a),0,math.cos(a)))
  center=Vector((0,y,.30+H*.46));p,no,idx,_=CAB.ray_cast(center+direction*7,-direction,15)
  rv.append(p+smooth_normal(CAB,p,idx)*.010)
for j in range(4):
 for i in range(N):
  k=j*(N+1)+i;rf.append((k,k+1,k+N+2,k+N+1))
rib=g.mesh('Cabine / retour corail sur le toit',rv,rf,COL['livery'],RED,smooth=True);g.orient(rib,(0,0,1));g.thickness(rib,.008)

# Lamp casings and lenses share one local normal and are embedded in actual body recesses.
LAMPS=[]
for label,pix in [('gauche',front_uv(-.79,.91)),('droit',front_uv(.79,.91))]:
 origin,normal=hit(pix,FRONT)
 # Same family of geometry; small radius variation in the source is retained.
 radius=.245
 cutter=g.cylinder('Phare '+label+' / outil',origin-normal*.12,origin+normal*.11,radius*.92,COL['cutters'],None,96,0)
 cut(cab,cutter,'Poche phare '+label)
 profile=[(-.042,radius*.95),(.006,radius),(.046,radius*.96),(.061,radius*.83),(.050,radius*.64),(-.042,radius*.64)]
 housing=g.lathe('Phare '+label+' / cerclage joufflu',profile,origin,normal,COL['lamps'],NAVY,96)
 rr=radius*.62
 gold=g.lathe('Phare '+label+' / reflecteur',[(.010,rr*1.05),(.037,rr*1.05),(.037,rr*.98),(.010,rr*.98)],origin,normal,COL['lamps'],GOLD,96)
 lens=g.lathe('Phare '+label+' / lentille bombee',[(-.012,0),(-.012,rr*.97),(.032,rr*.97),(.055,rr*.78),(.066,rr*.42),(.071,0)],origin,normal,COL['lamps'],YELLOW,96)
 LAMPS.append((lens,housing))
smile=[front_uv(x,z+.078*(x/.38)**2) for x,z in g.rounded_loop(0,.785,.76,.145,.066,24)]
smiletool=patch('Sourire / outil',smile,FRONT,.045,-.080,COL['cutters'],None);cut(cab,smiletool,'Sourire du logo')
patch('Sourire / fond',scaled(smile,.97),FRONT,-.013,-.035,COL['lamps'],NAVY)
# The same short diagonal wiper as in the reference; a thick blade rather than a thin mechanism.
wp=[]
for pix in [front_uv(.14,1.29),front_uv(.38,1.59),front_uv(.66,1.95)]:
 p,no=hit(pix,FRONT);wp.append(p+no*.028)
g.curve('Essuie glace / lame arrondie',wp,.041,COL['lamps'],WIPER)
for pos in (wp[0],wp[-1]):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,radius=.041,location=pos)
 ob=bpy.context.object;ob.name='Essuie glace / bout arrondi'
 for col in list(ob.users_collection):col.objects.unlink(ob)
 COL['lamps'].objects.link(ob);ob.data.materials.append(WIPER)
 for f in ob.data.polygons:f.use_smooth=True

# Compact dark gangway physically joins the matching rear/front ends.
joint=g.box('Articulation / soufflet continu',(0,L+GAP/2,.30+H*HR*.49),(2.30*WR*.86,GAP+.30,H*HR*.90),COL['body'],NAVY,.15)
# Hidden 3D axles, with rounded tyres almost entirely tucked under the silhouette.
WHEELS=[]
for i,y in enumerate((1.50,L-.70,L+GAP+RL*.57),1):
 radius=.245
 axle_z=.43
 g.cylinder(f'Essieu {i}',(-.84,y,axle_z),(.84,y,axle_z),.07,COL['wheels'],NAVY,32,.01)
 for sign in (-1,1):
  # Plain rounded wheels from the icon, without industrial hubs or exposed bogies.
  ob=g.cylinder(f'Roue {i} {sign:+}',(sign*.65,y,axle_z),(sign*.93,y,axle_z),radius,COL['wheels'],RUBBER,64,.075)
  WHEELS.append(ob)
# Local wheel wells and axle bores preserve a continuous lower silhouette.
# A broad rectangular underside cut would leave arbitrary notches at the coach ends.
for i,y in enumerate((1.50,L-.70,L+GAP+RL*.57),1):
    coach=cab if y<L else rear
    shaft=g.cylinder(f'Degagement essieu {i}',(-.96,y,.43),(.96,y,.43),.091,COL['cutters'],None,64,0)
    cut(coach,shaft,'Alésage essieu')
    for sign in (-1,1):
        well=g.cylinder(f'Passage roue {i} {sign:+}',(sign*.61,y,.43),(sign*.97,y,.43),.271,COL['cutters'],None,96,0)
        cut(coach,well,'Passage de roue arrondi')

# A true symmetric V and level transverse contact bar, seated on the roof.
panto_y=L-.62
base,no,_,_=CAB.ray_cast(Vector((0,panto_y,10)),Vector((0,0,-1)),20)
g.box('Pantographe / socle ancre au toit',base+Vector((0,0,.07)),(.43,.38,.14),COL['panto'],NAVY,.065)
for sign in (-1,1):
    g.cylinder('Pantographe / branche V',base+Vector((0,0,.15)),base+Vector((sign*.43,0,.88)),.064,COL['panto'],NAVY,64,.032)
g.cylinder('Pantographe / archet arrondi',base+Vector((-.69,0,.92)),base+Vector((.69,0,.92)),.09,COL['panto'],NAVY,64,.085)

# The lower blue band is part of the SAME body mesh. No overlapping skirt, no extra
# surface patch at the right-hand corner, and no unsupported geometry under the face.
for ob in (cab,rear):
    ob.data.materials.append(NAVY)
    bm=bmesh.new();bm.from_mesh(ob.data)
    bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=1e-7,
                          plane_co=(0,0,.62),plane_no=(0,0,1),clear_inner=False,clear_outer=False)
    bmesh.ops.dissolve_degenerate(bm,dist=1e-6,edges=list(bm.edges))
    for face in bm.faces:face.material_index=1 if face.calc_center_median().z<.62 else 0
    bm.to_mesh(ob.data);bm.free()
# Continuous surface normals from the clean parametric guide preserve the real smooth body.
for ob,yy0,yy1 in [(cab,0,L),(rear,L+GAP,L+GAP+RL)]:
    guide=body('Guide de section / '+ob.name,yy0,yy1,2.30,2.30,H,H)
    source=tree(guide);cn=[]
    for poly in ob.data.polygons:
      for vi in poly.vertices:
        v=ob.data.vertices[vi].co;nearest,no,idx,distance=source.find_nearest(v)
        cn.append(smooth_normal(source,nearest,idx) if distance<.018 else poly.normal)
    ob.data.normals_split_custom_set(cn)
    COL['body'].objects.unlink(guide);COL['cutters'].objects.link(guide);guide.hide_set(True);guide.hide_render=True

# Hierarchy and embedded reference; the photo is available for inspection only.
root=bpy.data.objects.new('TRAM / reconstruction de la photo',None);bpy.context.scene.collection.objects.link(root)
for key,col in COL.items():
 if key in ('reference','cutters'):continue
 for ob in col.objects:ob.parent=root
COL['cutters'].hide_viewport=True;COL['cutters'].hide_render=True
reference=bpy.data.images.load(str(ROOT/'../../Assets.xcassets/AppIcon.appiconset/iOS App Icons.png'));reference.pack()
# Neutral inspection camera; the model is independent of its position.
camdata=bpy.data.cameras.new('Vue de travail');cam=bpy.data.objects.new('VUE / trois quarts',camdata);COL['reference'].objects.link(cam)
view_target=Vector((0,2.3,1.80));view_out=Vector((-.42,-.89,.18)).normalized()
cam.location=view_target+view_out*11.7;cam.rotation_euler=(-view_out).to_track_quat('-Z','Y').to_euler();camdata.lens=57;camdata.sensor_width=36
scene=bpy.context.scene;scene.camera=cam;scene.unit_settings.system='METRIC'
scene.render.resolution_x=1024;scene.render.resolution_y=1024;scene.render.resolution_percentage=100
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':
   space=area.spaces.active;space.shading.type='SOLID';space.shading.color_type='MATERIAL';space.overlay.show_overlays=False
   space.region_3d.view_perspective='CAMERA';space.region_3d.view_camera_zoom=8
for screen in bpy.data.screens:
 if screen.name=='Modeling':
  for area in screen.areas:
   if area.type=='VIEW_3D':
    space=area.spaces.active;space.region_3d.view_perspective='ORTHO'
    space.region_3d.view_rotation=Vector((-1,0,0)).to_track_quat('Z','Y')
    space.region_3d.view_location=(0,3.06,1.90);space.region_3d.view_distance=8.2
    space.overlay.show_overlays=False
if 'Layout' in bpy.data.workspaces:bpy.data.workspaces['Layout'].name='Tram - 3D'
if 'Modeling' in bpy.data.workspaces:bpy.data.workspaces['Modeling'].name='Tram - Profil'
scene['reference']='Photo comme reference de style; volumes et niveaux contraints en 3D; aucune texture photographique.'
scene['comparaison']='Deux caisses de meme hauteur et largeur. Bandeau bleu integre aux coques. Vue de travail, orbite libre.'

# Actual evaluated topology and intersections, not a test of names or constants.
bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();rows=[];fail=[]
for obj in scene.objects:
 if obj.type!='MESH' or obj.name in COL['cutters'].objects:continue
 ev=obj.evaluated_get(dg);data=ev.to_mesh();bm=bmesh.new();bm.from_mesh(data)
 nonmanifold=sum(not e.is_manifold for e in bm.edges);degenerate=sum(f.calc_area()<1e-11 for f in bm.faces)
 volume=bm.calc_volume(signed=True)
 rows.append({'object':obj.name,'non_manifold_edges':nonmanifold,'degenerate_faces':degenerate,'volume':volume})
 if nonmanifold or degenerate or volume<=0:fail.append(rows[-1])
 bm.free();ev.to_mesh_clear()
for pane,shell in GLAZING:
 overlap=len(tree(pane).overlap(tree(shell)))
 if overlap:
  print('GLASS_CONTACT',pane.name,tree(pane).overlap(tree(shell)))
  fail.append({'glass':pane.name,'surface_intersections':overlap})
for lens,housing in LAMPS:
 overlap=len(tree(lens).overlap(tree(housing)))
 if overlap:fail.append({'lamp':lens.name,'surface_intersections':overlap})
bounds={}
for ob in (cab,rear):
    ps=[ob.matrix_world@v.co for v in ob.data.vertices]
    bounds[ob.name]=[(min(p[a] for p in ps),max(p[a] for p in ps)) for a in range(3)]
roof_values=[b[2][1] for b in bounds.values()]
if abs(roof_values[0]-roof_values[1])>1e-5:fail.append({'roof_height_mismatch':roof_values})
for b in bounds.values():
    if abs((b[0][1]-b[0][0])-2.30)>0.015:fail.append({'body_width_mismatch':b[0]})
wheel_contacts=[]
for wheel in WHEELS:
    for coach in (cab,rear):
        count=len(tree(wheel).overlap(tree(coach)))
        if count:wheel_contacts.append((wheel.name,coach.name,count))
if wheel_contacts:fail.append({'wheel_body_intersections':wheel_contacts})
report={'mesh_parts':len(rows),'glazing_checks':len(GLAZING),'failures':fail,'parts':rows,'body_bounds':bounds,'common_roof_height':roof_values[0],'wheel_body_surface_intersections':len(wheel_contacts)}
(ROOT/'verification_geometrie.json').write_text(json.dumps(report,indent=2))
(ROOT/'verification.txt').write_text(f'{len(rows)} pieces fermees controlees. {len(GLAZING)} vitrages controles.\n'+('ECHECS: '+str(fail) if fail else 'Controles passes.\n')+'Niveaux de toiture identiques verifies sur les maillages ; bandeau bleu integre.\n')
if fail:
 bpy.ops.wm.save_as_mainfile(filepath='/tmp/tram_debug.blend')
 scene.render.engine='BLENDER_WORKBENCH';scene.display.shading.color_type='MATERIAL';scene.display.shading.show_shadows=False;scene.display.shading.show_cavity=False
 scene.display.shading.background_type='WORLD';scene.world.color=(1,1,1);scene.view_settings.view_transform='Standard';scene.render.filepath='/tmp/tram_controle_geometrie.png'
 bpy.ops.render.render(write_still=True)
 raise RuntimeError('Geometry failures: '+str(fail))
bpy.ops.object.select_all(action='DESELECT');root.select_set(True);bpy.context.view_layer.objects.active=root
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'Logo_Tram.blend'),compress=True)
print('MODEL_READY',len(rows),'parts; common roof',roof_values)
# Optional solid-model diagnostic, without lights or decorative background.
if '--controle-visuel' in sys.argv:
 scene.render.engine='BLENDER_WORKBENCH';scene.display.shading.light='STUDIO';scene.display.shading.studiolight_rotate_z=0
 scene.display.shading.color_type='MATERIAL';scene.display.shading.show_shadows=False;scene.display.shading.show_cavity=False
 scene.display.shading.background_type='WORLD';scene.world.color=(1,1,1);scene.render.film_transparent=False
 scene.view_settings.view_transform='Standard';scene.render.filepath='/tmp/tram_controle_geometrie.png'
 bpy.ops.render.render(write_still=True)
