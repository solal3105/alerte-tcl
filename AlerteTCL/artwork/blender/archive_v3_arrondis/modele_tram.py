"""Logo tram: soft mascot forms on the validated coherent structure, model only. Blender 4.5+.

Run with Blender --background --factory-startup --python modele_tram.py
Builds Logo_Tram.blend and runs geometric checks. No camera, lighting or render.
Coordinates: X across the tram, Y along it (front negative), Z up. Units: metres.
"""
from dataclasses import dataclass
from pathlib import Path
import sys
import math
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))
import tram_geometry as g


@dataclass(frozen=True)
class Dimensions:
    half_width: float = 1.15
    bottom: float = .62
    side_bottom: float = .85
    shoulder: float = 2.55
    roof: float = 3.03
    upper_radius: float = .48
    lower_radius: float = .23
    wall: float = .055
    floor: float = .75
    nose: float = -3.30
    front_side: float = -2.72
    front_end: float = 0.0
    rear_start: float = .56
    rear_side_end: float = 2.90
    rear_end: float = 3.10
    axle_half_track: float = .75
    wheel_radius: float = .275
    axle_spacing: float = .72
    bogie_front: float = -1.96
    bogie_rear: float = 2.25

    @property
    def joint(self):
        return (self.front_end + self.rear_start) / 2


D = Dimensions()
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for collection in list(bpy.data.collections):
    bpy.data.collections.remove(collection)

COL = {}
for key,label in [('front','01 Caisse avant'),('rear','02 Caisse arriere'),
                  ('windows','03 Vitrages et joints'),('doors','04 Portes'),
                  ('joint','05 Intercirculation'),('bogies','06 Bogies'),
                  ('lamps','07 Phares et essuie-glace'),('panto','08 Pantographe'),
                  ('cutters','90 Outils de decoupe')]:
    collection = bpy.data.collections.new(label)
    bpy.context.scene.collection.children.link(collection)
    COL[key] = collection
COL['cutters'].hide_render = True


def material(name, color):
    m = bpy.data.materials.new(name)
    # Simple colour coding for solid modelling view; no shading work is required.
    m.diffuse_color = (*color,1)
    return m


WHITE = material('Carrosserie ivoire du logo',(.94,.955,.98))
RUBBER = material('Joints et soufflet',(.032,.045,.059))
NAVY = material('Chassis et cerclages',(.065,.105,.145))
GLASS = material('Grandes vitres bleues',(.055,.245,.46))
RED = material('Reperes corail',(.98,.065,.055))
STEEL = material('Acier mecanique',(.24,.28,.32))
LENS = material('Lentilles',(1.0,.83,.20))
GOLD = material('Reflecteurs',(.47,.30,.07))

checks = {'glazing':[], 'lamps':[], 'wheels':[], 'skins':[], 'panto_feet':[],
          'joint_parts':[], 'flanges':[]}
module_objects = {'front':[], 'rear':[]}


def owned(obj, module):
    if module:
        module_objects[module].append(obj)
    return obj


def chart_side(sign):
    return lambda y,z,d=0: (sign*(D.half_width+d),y,z)


def section():
    """Identical cross section for both bodies, their caps, floor and roof."""
    points = []
    def line(a,b,n):
        points.extend([(a[0]+(b[0]-a[0])*i/n,a[1]+(b[1]-a[1])*i/n) for i in range(n)])
    def arc(cx,cz,r,a,b,n=12):
        points.extend([(cx+r*math.cos(math.radians(a+(b-a)*i/n)),
                        cz+r*math.sin(math.radians(a+(b-a)*i/n))) for i in range(n)])
    w,lo,hi,r,b = D.half_width,D.side_bottom,D.shoulder,D.upper_radius,D.lower_radius
    line((-w+b,D.bottom),(w-b,D.bottom),36)
    arc(w-b,lo,b,-90,0,8)
    line((w,lo),(w,hi),36)
    arc(w-r,hi,r,0,90)
    line((w-r,D.roof),(-w+r,D.roof),36)
    arc(-w+r,hi,r,90,180)
    line((-w,hi),(-w,lo),36)
    arc(-w+b,lo,b,180,270,8)
    return points


SECTION = section()


def section_inset(x,z):
    """Signed inward distance to the shared rounded body section."""
    if z >= (D.side_bottom+D.shoulder)/2:
        r=D.upper_radius
        qx=abs(x)-(D.half_width-r)
        qz=z-D.shoulder
    else:
        r=D.lower_radius
        qx=abs(x)-(D.half_width-r)
        qz=D.side_bottom-z
    return r-(math.hypot(max(qx,0),max(qz,0))+min(max(qx,qz),0))


def end_roll(x,z,r):
    inset=max(0,section_inset(x,z))
    t=max(0,r-inset)
    return r-math.sqrt(max(0,r*r-t*t))


def front_y(x,z):
    # A genuine rounded end in 3D: the face turns tangentially into the sides/roof.
    u=max(0,min(1,(z-1.4)/(D.roof-1.4)))
    return D.nose + .035*(x/D.half_width)**2 + .07*u*u + end_roll(x,z,.27)


def front_normal(x,z):
    e = 1e-5
    dx = (front_y(x+e,z)-front_y(x-e,z))/(2*e)
    dz = (front_y(x,z+e)-front_y(x,z-e))/(2*e)
    return Vector((dx,-1,dz)).normalized()


def front_chart(x,z,d=0):
    return Vector((x,front_y(x,z),z))+front_normal(x,z)*d


def gasket(name, opening, chart, module=None):
    """Stepped rubber section: external lip, stem inside the aperture, rear glass bead."""
    cx,cz,w,h,r = opening
    sections = [(+.010,.003),(+.010,.012),(-.058,.012),(-.058,-.026),
                (-.090,-.026),(-.090,-.038),(-.010,-.038),(-.010,.003)]
    vertices,faces = [],[]
    count = 128
    for delta,depth in sections:
        loop = g.rounded_loop(cx,cz,w+delta,h+delta,max(.012,r+delta/2),32)
        vertices.extend(chart(x,z,depth) for x,z in loop)
    for j in range(len(sections)):
        for i in range(count):
            k = j*count+i
            a = j*count+(i+1)%count
            b = ((j+1)%len(sections))*count+(i+1)%count
            c = ((j+1)%len(sections))*count+i
            faces.append((k,a,b,c))
    obj = g.mesh(name,vertices,faces,COL['windows'],RUBBER,smooth=True)
    g.orient(obj)
    return owned(obj,module)


def glazing(name, opening, chart, normal, shell, module=None):
    gasket(name+' / joint',opening,chart,module)
    cx,cz,w,h,r = opening
    pane = (cx,cz,w-.064,h-.064,max(.012,r-.032))
    obj = g.panel(name+' / verre',pane,lambda x,z: chart(x,z,-.008),
                  COL['windows'],GLASS,normal,wall=.018,n=28)
    for poly in obj.data.polygons: poly.use_smooth = True
    owned(obj,module)
    checks['glazing'].append((obj,shell))
    return obj


def wall(name, y0,y1,features,sign,module):
    chart = chart_side(sign)
    edges = [y0]+[(a['opening'][0]+a['opening'][2]/2+b['opening'][0]-b['opening'][2]/2)/2
                   for a,b in zip(features,features[1:])]+[y1]
    vertices,faces = [],[]
    for i,feature in enumerate(features):
        outer = g.rect_loop(edges[i],edges[i+1],D.side_bottom,D.shoulder,32)
        inner = g.opening_loop(outer,feature['opening'])
        vv,ff = g.annulus_data(outer,inner,lambda u,v: chart(u,v),rings=5)
        offset = len(vertices)
        vertices.extend(vv)
        faces.extend(tuple(offset+k for k in f) for f in ff)
    obj = g.mesh(name,vertices,faces,COL[module],WHITE,weld=True)
    g.orient(obj,(sign,0,0))
    g.thickness(obj,D.wall)
    owned(obj,module)
    checks['skins'].append(obj)
    for feature in features:
        if feature['kind']=='window':
            glazing(name+' / '+feature['label'],feature['opening'],chart,(sign,0,0),obj,module)
        else:
            door(name+' / porte',feature['opening'],chart,sign,obj,module)
    return obj


def door(name,opening,chart,sign,shell,module):
    cy,cz,w,h,r = opening
    gasket(name+' / dormant',opening,chart,module)
    gap = .016
    leaf_width = (w-.070-gap)/2
    leaf_height = h-.068
    for side,label in [(-1,'vantail A'),(1,'vantail B')]:
        ly = cy+side*(gap+leaf_width)/2
        outer = g.rounded_loop(ly,cz,leaf_width,leaf_height,.028,32)
        aperture = (ly,2.09,leaf_width-.10,.89,.055)
        leaf_chart = lambda u,v,d=0: chart(u,v,d-.012)
        leaf = g.annulus(name+' / '+label,outer,aperture,lambda u,v: leaf_chart(u,v),
                         COL['doors'],WHITE,(sign,0,0),wall=.042,rings=6)
        owned(leaf,module)
        checks['skins'].append(leaf)
        glazing(name+' / '+label,aperture,leaf_chart,(sign,0,0),leaf,module)
        # Handles connect to the leaf with two short studs, below the glazing.
        hy = ly-side*(leaf_width/2-.05)
        for hz in (1.27,1.43):
            owned(g.cylinder(name+' / fixation poignee',leaf_chart(hy,hz,.002),leaf_chart(hy,hz,.027),
                             .012,COL['doors'],NAVY,edge=.002),module)
        owned(g.cylinder(name+' / poignee',leaf_chart(hy,1.27,.027),leaf_chart(hy,1.43,.027),
                         .013,COL['doors'],NAVY,edge=.003),module)
    # A threshold connects the opening to the common interior floor level.
    owned(g.box(name+' / seuil',chart(cy,D.floor+.018,-.035),( .09,w-.070,.036),
                COL['doors'],NAVY,.004),module)


def roof_and_floor(module,y0,y1):
    # Roof: one continuous section, tangent to the vertical flanks at the shoulder.
    arc = []
    for i in range(17):
        a = math.pi-i*math.pi/32
        arc.append((-D.half_width+D.upper_radius+D.upper_radius*math.cos(a),
                    D.shoulder+D.upper_radius*math.sin(a)))
    for i in range(1,25):
        arc.append((-D.half_width+D.upper_radius+2*(D.half_width-D.upper_radius)*i/24,D.roof))
    for i in range(1,17):
        a = math.pi/2-i*math.pi/32
        arc.append((D.half_width-D.upper_radius+D.upper_radius*math.cos(a),
                    D.shoulder+D.upper_radius*math.sin(a)))
    verts,faces = [],[]
    n = len(arc)
    for j in range(17):
        y = y0+(y1-y0)*j/16
        verts.extend((x,y,z) for x,z in arc)
    for j in range(16):
        for i in range(n-1):
            k = j*n+i
            faces.append((k,k+1,k+1+n,k+n))
    roof = g.mesh(module+' / toit',verts,faces,COL[module],WHITE,smooth=True)
    g.orient(roof,(0,0,1));g.thickness(roof,D.wall)
    owned(roof,module);checks['skins'].append(roof)
    # Soft lower quarter rounds match the common nose section exactly.
    for sign in (-1,1):
        vv,ff = [],[]
        for j in range(17):
            y = y0+(y1-y0)*j/16
            for i in range(9):
                a = -math.pi/2+i*math.pi/16
                x = sign*(D.half_width-D.lower_radius+D.lower_radius*math.cos(a))
                z = D.side_bottom+D.lower_radius*math.sin(a)
                vv.append((x,y,z))
        for j in range(16):
            for i in range(8):
                k = j*9+i;ff.append((k,k+1,k+10,k+9))
        lower = g.mesh(module+f' / bas de caisse {sign}',vv,ff,COL[module],NAVY,smooth=True)
        g.orient(lower,(sign,0,-1));g.thickness(lower,.04);owned(lower,module)
    floor = owned(g.box(module+' / plancher',(0,(y0+y1)/2,D.floor-.03),
                        (2*(D.half_width-D.wall),y1-y0,.060),COL[module],NAVY,.004),module)
    # Chassis members lie inside the wheel inner faces, not through the wheels.
    for x in (-.46,.46):
        owned(g.box(module+' / longeron',(x,(y0+y1)/2,.65),(.14,y1-y0,.080),COL[module],STEEL,.008),module)
    return roof,floor


front_features = [
    {'kind':'window','label':'grande vitre avant','opening':(-1.98,1.985,1.13,1.08,.12)},
    {'kind':'window','label':'grande vitre arriere','opening':(-.68,1.985,1.13,1.08,.12)}]
rear_features = [
    {'kind':'window','label':'grande baie bleue','opening':(1.74,1.985,1.94,1.08,.14)}]

for sign in (-1,1):
    wall('Avant '+('gauche' if sign<0 else 'droit'),D.front_side,D.front_end,front_features,sign,'front')
    wall('Arriere '+('gauche' if sign<0 else 'droit'),D.rear_start,D.rear_side_end,rear_features,sign,'rear')
roof_and_floor('front',D.front_side,D.front_end)
roof_and_floor('rear',D.rear_start,D.rear_side_end)

# Front face: a hollow shell with a real windshield aperture, joined to the nose sides.
windshield_opening = (0,2.075,1.88,1.45,.38)
inner = g.opening_loop(SECTION,windshield_opening)
verts,faces = g.annulus_data(SECTION,inner,lambda x,z: front_chart(x,z),rings=14)
n = len(SECTION)
previous = 0  # The outer boundary of the annular front face.
for j in range(1,13):
    t = j/12
    start = len(verts)
    for x,z in SECTION:
        verts.append((x,front_y(x,z)*(1-t)+D.front_side*t,z))
    for i in range(n):
        faces.append((previous+i,previous+(i+1)%n,start+(i+1)%n,start+i))
    previous = start
nose = g.mesh('Avant / nez creux et baie de pare-brise',verts,faces,COL['front'],WHITE,smooth=True)
g.orient(nose,(0,-1,0));g.thickness(nose,D.wall)
owned(nose,'front');checks['skins'].append(nose)
glazing('Pare-brise',windshield_opening,front_chart,(0,-1,0),nose,'front')

# Floor continues into the nose at exactly the same level as the passenger floor.
vv,ff = [],[]
for j in range(9):
    t=j/8
    for i in range(49):
        x=-(D.half_width-D.wall)+2*(D.half_width-D.wall)*i/48
        y=front_y(x,D.floor)+D.wall+.004
        vv.append((x,y*(1-t)+D.front_side*t,D.floor))
for j in range(8):
    for i in range(48):
        k=j*49+i;ff.append((k,k+1,k+50,k+49))
nose_floor=g.mesh('Avant / prolongement plancher',vv,ff,COL['front'],NAVY)
g.orient(nose_floor,(0,0,1));g.thickness(nose_floor,.06);owned(nose_floor,'front')


def cut(obj,cutter,name):
    mod = obj.modifiers.new(name,'BOOLEAN')
    mod.operation = 'DIFFERENCE';mod.solver = 'EXACT';mod.object = cutter
    cutter.hide_render = True
    cutter.hide_set(True)
    cutter.display_type = 'WIRE'


# Both headlight assemblies use the SAME surface frame for hole, housing and lens.
for side,label in [(-1,'gauche'),(1,'droit')]:
    x,z = side*.78,1.03
    origin = Vector(front_chart(x,z))
    normal = front_normal(x,z)
    cutter = g.cylinder('Decoupe phare '+label,origin-normal*.20,origin+normal*.12,.232,COL['cutters'],None,96,0)
    cut(nose,cutter,'Logement reel phare '+label)
    profile = [(-.065,.235),(.004,.245),(.023,.232),(.023,.178),(-.065,.178)]
    housing = owned(g.lathe('Phare '+label+' / boitier',profile,origin,normal,COL['lamps'],NAVY),'front')
    ring = [(0.010,.183),(.025,.183),(.025,.174),(.010,.174)]
    owned(g.lathe('Phare '+label+' / reflecteur',ring,origin,normal,COL['lamps'],GOLD),'front')
    # Lens is recessed within the housing; it cannot drift to a different local normal.
    lens_profile = [(-.027,0),(-.027,.169),(.011,.169),(.023,.135),(.030,.075),(.033,0)]
    lens = owned(g.lathe('Phare '+label+' / lentille',lens_profile,origin,normal,COL['lamps'],LENS),'front')
    checks['lamps'].append((lens,housing,origin,normal))

# The logo's smiling opening, curved in the face itself.
grille_opening = (0,.905,.74,.145,.070)
def smile_chart(x,z,d=0):
    return front_chart(x,z+.090*(x/.37)**2,d)
outline = g.rounded_loop(*grille_opening,32)
cutter = g.extrude_loop('Decoupe sourire',outline,lambda x,z: smile_chart(x,z,-.15),
                        lambda x,z: smile_chart(x,z,.15),COL['cutters'],None)
cut(nose,cutter,'Sourire creuse dans la coque')
grille = g.panel('Sourire / fond arrondi',grille_opening,lambda x,z: smile_chart(x,z,-.025),
                 COL['lamps'],NAVY,(0,-1,0),wall=.02,n=32)
for poly in grille.data.polygons: poly.use_smooth=True
owned(grille,'front')

# Continuous navy bumper, following the same curved nose and lower body section.
vv,ff=[],[]
for j in range(13):
    z=D.bottom+.004+(D.side_bottom-D.bottom-.004)*j/12
    half=D.half_width-D.lower_radius+math.sqrt(max(0,D.lower_radius**2-(z-D.side_bottom)**2))
    for i in range(65):
        x=-half+2*half*i/64
        vv.append(front_chart(x,z,.006))
for j in range(12):
    for i in range(64):
        k=j*65+i;ff.append((k,k+1,k+66,k+65))
trim=g.mesh('Avant / pare-chocs enveloppant',vv,ff,COL['front'],NAVY,smooth=True)
g.orient(trim,(0,-1,0));g.thickness(trim,.014);owned(trim,'front')

# Short, thick and rounded single wiper from the logo.
pivot=Vector(front_chart(.20,1.34,.035))
owned(g.cylinder('Essuie-glace / pivot',front_chart(.20,1.34,-.012),pivot,.043,COL['lamps'],NAVY),'front')
owned(g.cylinder('Essuie-glace / fixation lame',pivot,front_chart(.24,1.40,.040),.026,COL['lamps'],NAVY),'front')
blade=g.cylinder('Essuie-glace / lame douce',front_chart(.24,1.40,.041),front_chart(.69,1.94,.041),
                 .044,COL['lamps'],STEEL,64,.035)
owned(blade,'front')

# Coral ribbons are thin geometry attached to the flanks, interrupted at the gangway.
for module,y0,y1 in [('front',D.front_side,-.08),('rear',D.rear_start+.08,D.rear_side_end)]:
    for sign in (-1,1):
        band=g.panel(module+f' / bande corail {sign}',((y0+y1)/2,1.175,y1-y0,.20,.035),
                     lambda y,z,sign=sign: chart_side(sign)(y,z,.006),COL[module],RED,(sign,0,0),wall=.012,n=36)
        owned(band,module)
# The upright ribbon wraps over the main coach roof, as on the icon.
ribbon_y=-1.33
for sign in (-1,1):
    band=g.panel('Avant / montant corail '+str(sign),(ribbon_y,2.525,.14,.05,.014),
                 lambda y,z,sign=sign: chart_side(sign)(y,z,.007),COL['front'],RED,(sign,0,0),wall=.012,n=12)
    owned(band,'front')
roof_obj=bpy.data.objects['front / toit']
# Duplicate a narrow actual roof strip, preserving the cross-section and genuine curvature.
rv,rf=[],[]
roof_n=len(roof_obj.data.vertices)//17
for j in range(3):
    y=ribbon_y-.07+.14*j/2
    for v in list(roof_obj.data.vertices)[:roof_n]:
        x,z=v.co.x,v.co.z
        normal=Vector((x-(math.copysign(D.half_width-D.upper_radius,x)),0,z-D.shoulder))
        if z>=D.roof-1e-6: normal=Vector((0,0,1))
        else: normal.normalize()
        rv.append(Vector((x,y,z))+normal*.006)
for j in range(2):
    for i in range(roof_n-1):
        k=j*roof_n+i;rf.append((k,k+1,k+1+roof_n,k+roof_n))
ribbon=g.mesh('Avant / ruban corail sur le toit',rv,rf,COL['front'],RED,smooth=True)
g.orient(ribbon,(0,0,1));g.thickness(ribbon,.012);owned(ribbon,'front')

# End bulkheads have actual gangway apertures with a common floor and ceiling.
gangway = (0,1.675,1.12,1.97,.025)
# Bulkheads sit inside the skin; their end walls must not share coplanar exterior faces.
BULKHEAD_SECTION=[(x*.954,1.825+(z-1.825)*.954) for x,z in SECTION]
for module,y,sign in [('front',D.front_end,1),('rear',D.rear_start,-1)]:
    bulkhead = g.annulus(module+' / cloison intercirculation',BULKHEAD_SECTION,gangway,
                         lambda x,z,y=y: (x,y,z),COL[module],WHITE,(0,sign,0),wall=.055,rings=9)
    owned(bulkhead,module);checks['skins'].append(bulkhead)

# Rear cap repeats the same outer section and joins the longitudinal panels.
rear_aperture = (0,2.04,1.63,1.22,.27)
def rear_y(x,z): return D.rear_end-end_roll(x,z,.16)
inner = g.opening_loop(SECTION,rear_aperture)
verts,faces = g.annulus_data(SECTION,inner,lambda x,z:(x,rear_y(x,z),z),rings=12)
previous = 0
for j in range(1,7):
    start = len(verts)
    verts.extend((x,rear_y(x,z)+(D.rear_side_end-rear_y(x,z))*j/6,z) for x,z in SECTION)
    for i in range(n):faces.append((previous+i,start+i,start+(i+1)%n,previous+(i+1)%n))
    previous = start
rear_cap = g.mesh('Arriere / face terminale',verts,faces,COL['rear'],WHITE,smooth=True)
g.orient(rear_cap,(0,1,0));g.thickness(rear_cap,D.wall);owned(rear_cap,'rear')
checks['skins'].append(rear_cap)
owned(g.box('Arriere / prolongement plancher',
            (0,(D.rear_side_end+D.rear_end-D.wall)/2,D.floor-.03),
            (2*(D.half_width-D.wall),D.rear_end-D.wall-D.rear_side_end,.06),
            COL['rear'],NAVY,.003),'rear')
rear_chart = lambda x,z,d=0:(x,rear_y(x,z)+d,z)
glazing('Lunette arriere',rear_aperture,rear_chart,(0,1,0),rear_cap,'rear')
for sign in (-1,1):
    owned(g.box('Arriere / feu de position',(sign*.84,D.rear_end+.014,1.09),(.095,.028,.16),COL['rear'],RED,.007),'rear')

# Closed flexible bellows section, matched to the coach end faces.
verts,faces = [],[]
bellows_loop = g.rounded_loop(0,1.815,2.14,2.33,.40,32)
bn = len(bellows_loop)
stations = 25
for j in range(stations):
    y = D.front_end+.006+(D.rear_start-D.front_end-.012)*j/(stations-1)
    inset = .048*(1-math.cos(math.tau*6*j/(stations-1)))/2
    for x,z in bellows_loop:
        # Fold inward; never exceed the shared body outline.
        t=(z-.65)/2.33
        zz=(.65+.20*inset)*(1-t)+(2.98-inset)*t
        verts.append((x*(1-inset/1.09),y,zz))
for j in range(stations-1):
    for i in range(bn):
        faces.append((j*bn+i,j*bn+(i+1)%bn,(j+1)*bn+(i+1)%bn,(j+1)*bn+i))
bellows = g.mesh('Soufflet / six plis continus',verts,faces,COL['joint'],RUBBER)
# At the first vertex the radial direction is outward and below the centre.
g.orient(bellows);g.thickness(bellows,.016)
bridge=g.box('Passerelle / plancher commun',(0,D.joint,D.floor-.026),
             (1.07,D.rear_start-D.front_end,.052),COL['joint'],STEEL,.006)
checks['joint_parts'].append((bridge,bellows))
for y,sign in ((D.front_end+.018,1),(D.rear_start-.018,-1)):
    outer = g.rounded_loop(0,1.815,2.17,2.345,.415,32)
    opening = (0,1.815,2.09,2.265,.375)
    frame = g.annulus('Soufflet / bride de fixation',outer,opening,lambda x,z,y=y:(x,y,z),
                       COL['joint'],NAVY,(0,sign,0),wall=.018,rings=2)
    checks['flanges'].append((frame,sign))

# Three two-axle bogies, including a shared bogie under the articulation.
# A 53 mm hub bore leaves 1 mm radial clearance around each 52 mm axle.
wheel_profile = [(-.115,.053),(-.115,.105),(-.075,.105),(-.075,.245),(-.092,.255),
                 (-.092,.275),(-.060,.275),(-.050,.255),(.070,.255),(.090,.235),
                 (.065,.195),(.028,.170),(.028,.100),(.090,.100),(.090,.053)]
for index,yc in enumerate((D.bogie_front,D.joint,D.bogie_rear),1):
    prefix = f'Bogie {index}'
    pivot = bpy.data.objects.new(prefix+' / ensemble',None)
    COL['bogies'].objects.link(pivot)
    pivot.location = (0,yc,0)
    before = set(COL['bogies'].objects)
    for sign in (-1,1):
        g.box(prefix+' / longeron lateral',(sign*.49,yc,.40),(.16,1.04,.10),COL['bogies'],NAVY,.010)
        g.cylinder(prefix+' / suspension',(sign*.49,yc,.415),(sign*.49,yc,.56),.085,COL['bogies'],STEEL)
        for z in (.425,.545):
            g.cylinder(prefix+' / coupelle',(sign*.49,yc,z-.012),(sign*.49,yc,z+.012),.105,COL['bogies'],NAVY)
    g.box(prefix+' / traverse',(0,yc,.56),(1.18,.22,.10),COL['bogies'],STEEL,.012)
    g.cylinder(prefix+' / pivot de caisse',(0,yc,.59),(0,yc,.725),.145,COL['bogies'],NAVY)
    for axle in (-1,1):
        y = yc+axle*D.axle_spacing/2
        g.cylinder(prefix+' / essieu',(-.845,y,D.wheel_radius),(.845,y,D.wheel_radius),.052,COL['bogies'],STEEL)
        for sign in (-1,1):
            g.box(prefix+' / boite essieu',(sign*.55,y,D.wheel_radius),(.13,.18,.18),COL['bogies'],NAVY,.018)
            wheel = g.lathe(prefix+f' / roue {axle:+} {sign:+}',wheel_profile,
                            (sign*D.axle_half_track,y,D.wheel_radius),(sign,0,0),COL['bogies'],NAVY)
            checks['wheels'].append(wheel)
    for obj in set(COL['bogies'].objects)-before:
        matrix = obj.matrix_world.copy()
        obj.parent = pivot
        obj.matrix_world = matrix

# The icon's compact V-shaped pantograph; mechanically attached, simple rounded rods.
panto_y=1.80
for x in (-.22,.22):
    for y in (panto_y-.17,panto_y+.17):
        foot=g.cylinder('Pantographe / isolateur',(x,y,D.roof),(x,y,D.roof+.10),.06,COL['panto'],RUBBER)
        checks['panto_feet'].append(foot)
g.box('Pantographe / socle doux',(0,panto_y,D.roof+.135),(.62,.51,.11),COL['panto'],NAVY,.05)
for side in (-1,1):
    g.cylinder('Pantographe / branche du V',(side*.065,panto_y,D.roof+.20),
               (side*.43,panto_y,D.roof+.91),.065,COL['panto'],NAVY,64,.028)
g.cylinder('Pantographe / pivot',(-.15,panto_y,D.roof+.21),(.15,panto_y,D.roof+.21),.09,COL['panto'],NAVY,64,.025)
g.box('Pantographe / archet arrondi',(0,panto_y,D.roof+.96),(1.42,.22,.19),COL['panto'],NAVY,.09)

# Hierarchy: independent bodies, joint and running gear under one model root.
root = bpy.data.objects.new('TRAM / modele complet',None)
bpy.context.scene.collection.objects.link(root)
for module,origin in [('front',(0,-1.65,0)),('rear',(0,1.83,0))]:
    pivot = bpy.data.objects.new(module+' / caisse complete',None)
    COL[module].objects.link(pivot)
    pivot.location = origin
    pivot.parent = root
    bpy.context.view_layer.update()
    for obj in module_objects[module]:
        matrix = obj.matrix_world.copy()
        obj.parent = pivot
        obj.matrix_world = matrix
for key in ('joint','bogies','panto'):
    for obj in COL[key].objects:
        if obj.parent is None:
            obj.parent = root

scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1.0
scene.camera = None
scene['modele'] = 'Tram mascotte du logo: volumes doux, sourire, grandes vitres et rubans corail; modele uniquement.'
scene['axes'] = 'X transversal / Y longitudinal / Z vertical'
scene['largeur_commune'] = D.half_width*2
scene['toiture_commune'] = D.roof
scene['plancher_commun'] = D.floor
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D':
            space = area.spaces.active
            space.shading.type = 'SOLID'
            space.shading.color_type = 'MATERIAL'
            space.overlay.show_overlays = True
            space.overlay.show_relationship_lines = False
            space.overlay.show_extras = False
            space.region_3d.view_perspective = 'ORTHO'
            space.region_3d.view_location = (0,-.10,1.85)
            space.region_3d.view_distance = 10.5
            space.region_3d.view_rotation = Vector((-7,-12,5.5)).to_track_quat('Z','Y')

readme = bpy.data.texts.new('A LIRE / construction du modele')
readme.write('TRAM DU LOGO — MODELE UNIQUEMENT\n\n'
 'Proportions et structure conservees; formes de la mascotte du logo retablies.\n'
 'Coque arrondie, grand pare-brise, sourire creuse, bande corail, pantographe en V.\n'
 'Ouvertures reelles, vitrages en retrait, phares assembles dans le meme axe.\n'
 'Trois bogies communs conserves sous la carrosserie.\n'
 'Aucune camera, aucun eclairage, aucun decor.\n'
 'Construction: modele_tram.py. Archives: archive_v1 et archive_v2_structure.\n')

bpy.context.view_layer.update()
from verification_modele import verify
report = verify(D,checks,COL,ROOT)
bpy.ops.object.select_all(action='DESELECT')
root.select_set(True)
bpy.context.view_layer.objects.active = root
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'Logo_Tram.blend'),compress=True)
print('MODEL_SAVED',ROOT/'Logo_Tram.blend')
print('GEOMETRY_CHECKS',report['summary'])
