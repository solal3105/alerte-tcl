"""Reconstruction of the app's actual tram, built from code and measured reference.
The body is genuine closed 3D geometry. Contours are lifted onto that body to locate
recessed glass and livery. No photograph or reflection is used as a model texture.
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
C=json.loads((ROOT/'reference_calibree.json').read_text())
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
for c in list(bpy.data.collections):bpy.data.collections.remove(c)
COL={}
for k,n in [('body','01 Volumes du logo'),('glass','02 Vitres encastrees'),('lamps','03 Phares et sourire'),('livery','04 Rubans corail'),('wheels','05 Roues et chassis'),('panto','06 Pantographe'),('cutters','90 Decoupes'),('reference','91 Reference et point de vue')]:
 c=bpy.data.collections.new(n);bpy.context.scene.collection.children.link(c);COL[k]=c

def mat(n,c):
 m=bpy.data.materials.new(n);m.diffuse_color=(*c,1);return m
WHITE=mat('Blanc porcelaine',(.90,.915,.95));NAVY=mat('Bleu graphite',(.035,.075,.115));RUBBER=mat('Joints bleu sombre',(.020,.043,.065));GLASS=mat('Bleu du vitrage',(.038,.17,.34));RED=mat('Rouge corail',(.95,.045,.040));YELLOW=mat('Jaune doux des phares',(1,.80,.18));GOLD=mat('Reflecteurs',(.53,.33,.065));WIPER=mat('Essuie glace',(.14,.21,.29))
H=C['height'];L=C['length'];RL=C['rear_length']+.085;WR=C['rear_width_ratio'];HR=C['rear_height_ratio'];POWER=C['power'];GAP=.26

# Calibrated pinhole projection; used for construction measurements and comparison only.
target=Vector((0,L*.28,1.5));yaw=math.radians(C['yaw']);elev=math.radians(C['elevation'])
OUT=Vector((-math.sin(yaw)*math.cos(elev),-math.cos(yaw)*math.cos(elev),math.sin(elev)))
RIGHT=Vector((math.cos(yaw),-math.sin(yaw),0));UP=OUT.cross(RIGHT)
EYE=target+OUT*C['distance']
def ray(pixel):
 x,y=pixel
 return (RIGHT*((x-C['cx'])/C['focal_px'])+UP*((C['cy']-y)/C['focal_px'])-OUT).normalized()
def project(p):
 q=Vector(p)-target;d=C['distance']-q.dot(OUT)
 return (C['cx']+C['focal_px']*q.dot(RIGHT)/d,C['cy']-C['focal_px']*q.dot(UP)/d)

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
def hit(pixel,bvh=CAB):
 p,n,index,_=bvh.ray_cast(EYE,ray(pixel),50)
 if p is None:raise RuntimeError('Reference contour outside body: '+str(pixel))
 return p,smooth_normal(bvh,p,index)

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

# Actual photo contours, not generic rectangles. They are lifted onto the 3D body.
windshield=bezier([(476,584),(469,520),(466,421),(496,368),(521,322),(607,315),(687,322),
 (746,327),(768,359),(784,407),(801,458),(814,534),(821,589),(826,618),(810,626),(784,635),
 (692,658),(570,648),(502,624),(483,617),(479,602),(476,584)],14)
window('Pare brise enveloppant',windshield,cab,CAB)
side1=bezier([(309,428),(330,417),(353,408),(375,399),(384,395),(388,401),(389,411),
 (394,480),(397,555),(398,621),(399,631),(397,634),(391,633),(368,628),(338,624),(311,621),
 (308,621),(307,618),(307,614),(306,554),(306,484),(306,438),(306,433),(307,430),(309,428)],8)
side2=bezier([(219,449),(235,441),(258,433),(281,426),(285,425),(286,427),(286,433),
 (285,488),(285,550),(285,610),(285,616),(284,619),(280,618),(258,615),(236,612),(215,609),
 (211,608),(210,604),(210,599),(210,553),(210,501),(212,462),(212,455),(215,451),(219,449)],8)
window('Cabine / vitre cote nez',side1,cab,CAB,True)
window('Cabine / vitre cote articulation',side2,cab,CAB,True)
rearwindow=bezier([(104,477),(122,471),(145,463),(169,454),(174,453),(177,455),(177,461),
 (178,502),(178,553),(177,597),(177,603),(175,605),(170,604),(149,602),(125,599),(104,596),
 (100,596),(99,593),(99,588),(99,550),(99,511),(100,486),(100,481),(101,478),(104,477)],8)
# The reference's rear-most contour is close to the measured silhouette. Keep glazing inside it.
rearwindow=[(x+3*max(0,(177-x)/78),y) for x,y in rearwindow]
window('Remorque / grande vitre',rearwindow,rear,REAR,True)

# Fine coral inlays follow the actual side and its clipped downward terminal.
for name,loop,obj,bvh in [
 ('Cabine / bande corail',[(209,636),(390,678),(394,683),(402,751),(398,755),(366,746),(350,719),(210,674)],cab,CAB),
 ('Remorque / bande corail',[(103,624),(178,645),(178,676),(104,653)],rear,REAR)]:
 patch(name,loop,bvh,.010,.002,COL['livery'],RED,True)
# Roof ribbon reconstructed as a continuous strip along the actual cross section.
ribbon_end=hit((297,417))[0]
y_ribbon=ribbon_end.y
ribbon_angle=math.atan2(abs(ribbon_end.x),ribbon_end.z-(.30+H*.46))
rv=[];rf=[];N=80
for j in range(5):
 y=y_ribbon+(j/4-.5)*.15
 for i in range(N+1):
  a=-ribbon_angle+2*ribbon_angle*i/N;direction=Vector((math.sin(a),0,math.cos(a)))
  center=Vector((0,y,.30+H*.46));p,no,_,_=CAB.ray_cast(center+direction*7,-direction,15)
  rv.append(p+no*.010)
for j in range(4):
 for i in range(N):
  k=j*(N+1)+i;rf.append((k,k+1,k+N+2,k+N+1))
rib=g.mesh('Cabine / retour corail sur le toit',rv,rf,COL['livery'],RED,smooth=True);g.orient(rib,(0,0,1));g.thickness(rib,.008)

# Navy lower body formed by trimming a duplicate of the true silhouette, no bolted-on box.
# Separate skin band spans the lower .19m of the original body, above tucked wheels.
def skirt(obj,name):
 duplicate=obj.copy();duplicate.data=obj.data.copy();COL['body'].objects.link(duplicate);duplicate.name=name
 duplicate.data.materials.clear();duplicate.data.materials.append(NAVY)
 # Intersect the original volume with a low slab, using the same sculpted lower corners.
 slab=g.box(name+' / outil', (0,L/2,.405),(8,20,.47),COL['cutters'],NAVY,0)
 bpy.context.view_layer.objects.active=duplicate
 m=duplicate.modifiers.new('Decoupe du bandeau inferieur','BOOLEAN');m.operation='INTERSECT';m.solver='EXACT';m.object=slab
 bpy.ops.object.modifier_apply(modifier=m.name);slab.hide_render=True;slab.hide_set(True)
 # Offset only the original exterior. The slab's interior top remains buried in the body.
 source=CAB if obj==cab else REAR
 for v in duplicate.data.vertices:
  nearest,no,_,distance=source.find_nearest(v.co)
  if distance<.002:v.co+=no*.009
 return duplicate
front_skirt=skirt(cab,'Cabine / jupe bleue continue');rear_skirt=skirt(rear,'Remorque / jupe bleue continue')

# Lamp casings and lenses share one local normal and are embedded in actual body recesses.
LAMPS=[]
for label,pix in [('gauche',(525,708)),('droit',(810,705))]:
 origin,normal=hit(pix)
 # Same family of geometry; small radius variation in the source is retained.
 radius=.240 if label=='gauche' else .200
 cutter=g.cylinder('Phare '+label+' / outil',origin-normal*.12,origin+normal*.11,radius*.92,COL['cutters'],None,96,0)
 cut(cab,cutter,'Poche phare '+label)
 profile=[(-.042,radius*.95),(.006,radius),(.046,radius*.96),(.061,radius*.83),(.050,radius*.64),(-.042,radius*.64)]
 housing=g.lathe('Phare '+label+' / cerclage joufflu',profile,origin,normal,COL['lamps'],NAVY,96)
 rr=radius*.62
 gold=g.lathe('Phare '+label+' / reflecteur',[(.010,rr*1.05),(.037,rr*1.05),(.037,rr*.98),(.010,rr*.98)],origin,normal,COL['lamps'],GOLD,96)
 lens=g.lathe('Phare '+label+' / lentille bombee',[(-.012,0),(-.012,rr*.97),(.032,rr*.97),(.055,rr*.78),(.066,rr*.42),(.071,0)],origin,normal,COL['lamps'],YELLOW,96)
 LAMPS.append((lens,housing))
smile=bezier([(622,719),(641,724),(684,732),(726,720),(735,715),(740,720),(739,728),
 (737,744),(708,754),(678,754),(648,754),(619,746),(616,734),(613,727),(615,720),(622,719)],12)
smiletool=patch('Sourire / outil',smile,CAB,.045,-.080,COL['cutters'],None);cut(cab,smiletool,'Sourire du logo')
patch('Sourire / fond',scaled(smile,.97),CAB,-.013,-.035,COL['lamps'],NAVY)
# The same short diagonal wiper as in the reference; a thick blade rather than a thin mechanism.
wp=[]
for pix in [(691,635),(731,585),(780,534)]:
 p,no=hit(pix);wp.append(p+no*.028)
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
# The body interiors have a real underside recess, so wheels are not simply stuck through a solid block.
for obj in (cab,rear,front_skirt,rear_skirt):
 ymin=0 if obj in (cab,front_skirt) else L+GAP
 ymax=L if obj in (cab,front_skirt) else L+GAP+RL
 tool=g.box(obj.name+' / degagement roues',(0,(ymin+ymax)/2,.30),(1.94,ymax-ymin-.76,1.0),COL['cutters'],NAVY,.06)
 cut(obj,tool,'Degagement reel sous chassis')

# Roof V: attach the base to the real roof and calibrate the bar position against the source.
best=None
for k in range(301):
 y=.5+(L+GAP+RL-1)*k/300
 bvh=CAB if y<L else REAR
 p,no,_,_=bvh.ray_cast(Vector((0,y,10)),Vector((0,0,-1)),20)
 if p is None:continue
 u,v=project(p+Vector((0,0,.08)));score=(u-339)**2+(v-332)**2
 if best is None or score<best[0]:best=(score,p)
base=best[1]
g.box('Pantographe / socle ancre au toit',base+Vector((0,0,.07)),(.43,.38,.14),COL['panto'],NAVY,.065)
# Reconstruct the reference's slightly tilted contact bar in the transverse plane.
# It is a genuine solid 3D rod; its two supports share the same base plane.
def panto_plane(pixel):
 direction=ray(pixel);t=(base.y-EYE.y)/direction.y
 return EYE+direction*t
bar_a=panto_plane((246,226));bar_b=panto_plane((419,196))
v_joint=panto_plane((335,316))
g.cylinder('Pantographe / pied du V',base+Vector((0,0,.10)),v_joint,.071,COL['panto'],NAVY,48,.030)
for t in (.22,.77):
 end=bar_a.lerp(bar_b,t)
 g.cylinder('Pantographe / branche V',v_joint,end,.060,COL['panto'],NAVY,64,.030)
g.cylinder('Pantographe / archet arrondi',bar_a,bar_b,.09,COL['panto'],NAVY,64,.085)

# Transfer the original continuous body's normals to the boolean-cut exterior.
# This removes false dents around openings without changing any vertex positions.
for obj,source in [(cab,CAB),(rear,REAR),(front_skirt,CAB),(rear_skirt,REAR)]:
 cn=[]
 for poly in obj.data.polygons:
  for vi in poly.vertices:
   v=obj.data.vertices[vi].co;nearest,no,idx,distance=source.find_nearest(v)
   cn.append(smooth_normal(source,nearest,idx) if distance<.018 else poly.normal)
 obj.data.normals_split_custom_set(cn)

# Hierarchy and embedded reference; the photo is available for inspection only.
root=bpy.data.objects.new('TRAM / reconstruction de la photo',None);bpy.context.scene.collection.objects.link(root)
for key,col in COL.items():
 if key in ('reference','cutters'):continue
 for ob in col.objects:ob.parent=root
COL['cutters'].hide_viewport=True;COL['cutters'].hide_render=True
reference=bpy.data.images.load(str(ROOT/'../../Assets.xcassets/AppIcon.appiconset/iOS App Icons.png'));reference.pack()
# A calibrated camera is a measurement aid, not a lighting/render setup.
camdata=bpy.data.cameras.new('Point de vue de la photo');cam=bpy.data.objects.new('REFERENCE / point de vue calibre',camdata);COL['reference'].objects.link(cam)
cam.location=EYE;cam.rotation_euler=(-OUT).to_track_quat('-Z','Y').to_euler();camdata.lens=C['focal_px']/1024*36;camdata.sensor_width=36
camdata.shift_x=(512-C['cx'])/1024;camdata.shift_y=(C['cy']-512)/1024
scene=bpy.context.scene;scene.camera=cam;scene.unit_settings.system='METRIC'
scene.render.resolution_x=1024;scene.render.resolution_y=1024;scene.render.resolution_percentage=100
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':
   space=area.spaces.active;space.shading.type='SOLID';space.shading.color_type='MATERIAL';space.overlay.show_overlays=False
   space.region_3d.view_perspective='CAMERA';space.region_3d.view_camera_zoom=8
scene['reference']='Contours mesures sur iOS App Icons.png; aucune image appliquee au modele.'
scene['comparaison']='La camera reproduit le point de vue mesure. Orbiter librement pour examiner la vraie geometrie.'

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
report={'mesh_parts':len(rows),'glazing_checks':len(GLAZING),'failures':fail,'parts':rows,'reference_calibration':C}
(ROOT/'verification_geometrie.json').write_text(json.dumps(report,indent=2))
(ROOT/'verification.txt').write_text(f'{len(rows)} pieces fermees controlees. {len(GLAZING)} vitrages controles.\n'+('ECHECS: '+str(fail) if fail else 'Controles passes.\n')+'Contours calibres sur la photo ; aucune texture photographique.\n')
if fail:
 bpy.ops.wm.save_as_mainfile(filepath='/tmp/tram_debug.blend')
 scene.render.engine='BLENDER_WORKBENCH';scene.display.shading.color_type='MATERIAL';scene.display.shading.show_shadows=False;scene.display.shading.show_cavity=False
 scene.display.shading.background_type='WORLD';scene.world.color=(1,1,1);scene.view_settings.view_transform='Standard';scene.render.filepath='/tmp/tram_controle_geometrie.png'
 bpy.ops.render.render(write_still=True)
 raise RuntimeError('Geometry failures: '+str(fail))
bpy.ops.object.select_all(action='DESELECT');root.select_set(True);bpy.context.view_layer.objects.active=root
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'Logo_Tram.blend'),compress=True)
print('MODEL_READY',len(rows), 'parts; contour RMS',C['contour_rms_px'])
# Optional solid-model diagnostic. No lights, reflections or decorative logo background.
if '--controle-visuel' in sys.argv:
 scene.render.engine='BLENDER_WORKBENCH';scene.display.shading.light='STUDIO';scene.display.shading.studiolight_rotate_z=0
 scene.display.shading.color_type='MATERIAL';scene.display.shading.show_shadows=False;scene.display.shading.show_cavity=False
 scene.display.shading.background_type='WORLD';scene.world.color=(1,1,1);scene.render.film_transparent=False
 scene.view_settings.view_transform='Standard';scene.render.filepath='/tmp/tram_controle_geometrie.png'
 bpy.ops.render.render(write_still=True)
