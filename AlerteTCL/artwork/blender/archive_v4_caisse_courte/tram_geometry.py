"""Geometry primitives for the tram. Dimensions are in metres, independent of any camera.

X = transverse, Y = longitudinal (front negative), Z = vertical.
No image projection, ray-cast decoration, lighting or rendering is used here.
"""
import math
import bpy
import bmesh
from mathutils import Vector


def mesh(name, vertices, faces, collection, material, smooth=False, weld=False):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    if weld:
        bm = bmesh.new()
        bm.from_mesh(data)
        bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-7)
        bm.to_mesh(data)
        bm.free()
    obj = bpy.data.objects.new(name, data)
    collection.objects.link(obj)
    if material:
        data.materials.append(material)
    for face in data.polygons:
        face.use_smooth = smooth
    return obj


def orient(obj, expected=None):
    """Consistent outward normals. Open surfaces need an explicit normal hint."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    if expected is not None:
        direction = Vector(expected)
        score = sum(f.normal.dot(direction) * f.calc_area() for f in bm.faces)
    else:
        score = bm.calc_volume(signed=True)
    if score < 0:
        bmesh.ops.reverse_faces(bm, faces=list(bm.faces))
    bm.to_mesh(obj.data)
    bm.free()


def thickness(obj, value, inward=True):
    mod = obj.modifiers.new('Epaisseur de paroi', 'SOLIDIFY')
    mod.thickness = value
    mod.offset = -1 if inward else 0
    mod.use_even_offset = True
    return mod


def bevel(obj, amount=.003, segments=3):
    mod = obj.modifiers.new('Conges des aretes', 'BEVEL')
    mod.width = amount
    mod.segments = segments
    mod.limit_method = 'ANGLE'
    return mod


def rect_loop(left, right, bottom, top, n=24):
    points = []
    corners = [(left,bottom), (right,bottom), (right,top), (left,top)]
    for a, b in zip(corners, corners[1:] + corners[:1]):
        points.extend([(a[0]+(b[0]-a[0])*i/n, a[1]+(b[1]-a[1])*i/n) for i in range(n)])
    return points


def rounded_hit(dx, dy, half_w, half_h, radius):
    """Intersection of a centre-to-outside ray with an exact rounded rectangle."""
    r = min(radius, half_w, half_h)
    t = min(half_w / abs(dx) if abs(dx)>1e-12 else math.inf,
            half_h / abs(dy) if abs(dy)>1e-12 else math.inf)
    px, py = dx*t, dy*t
    if abs(px) <= half_w-r+1e-10 or abs(py) <= half_h-r+1e-10 or r == 0:
        return px, py
    cx = math.copysign(half_w-r, dx)
    cy = math.copysign(half_h-r, dy)
    aa = dx*dx+dy*dy
    bb = dx*cx+dy*cy
    disc = max(0, bb*bb-aa*(cx*cx+cy*cy-r*r))
    t = (bb+math.sqrt(disc))/aa
    return dx*t, dy*t


def rounded_loop(cx, cy, width, height, radius, n=32):
    points = []
    for x, y in rect_loop(-width/2,width/2,-height/2,height/2,n):
        px, py = rounded_hit(x,y,width/2,height/2,radius)
        points.append((cx+px,cy+py))
    return points


def opening_loop(outer, opening):
    cx, cy, width, height, radius = opening
    points = []
    for x,y in outer:
        px,py = rounded_hit(x-cx,y-cy,width/2,height/2,radius)
        points.append((cx+px,cy+py))
    return points


def annulus_data(outer, inner, mapping, rings=5):
    assert len(outer) == len(inner)
    count = len(outer)
    vertices, faces = [], []
    for j in range(rings+1):
        t = j/rings
        for a,b in zip(outer,inner):
            vertices.append(mapping(a[0]*(1-t)+b[0]*t,a[1]*(1-t)+b[1]*t))
    for j in range(rings):
        for i in range(count):
            k = j*count+i
            q = j*count+(i+1)%count
            faces.append((k,q,q+count,k+count))
    return vertices, faces


def annulus(name, outer, opening, mapping, collection, material,
            normal, wall=None, rings=5, smooth=False):
    inner = opening_loop(outer,opening)
    v,f = annulus_data(outer,inner,mapping,rings)
    obj = mesh(name,v,f,collection,material,smooth=smooth)
    orient(obj,normal)
    if wall:
        thickness(obj,wall)
    return obj


def panel(name, opening, mapping, collection, material, normal,
          wall=.018, n=24, dome=0):
    """Regular quad grid filling a rounded rectangle, with real closed thickness."""
    cx, cy, width, height, radius = opening
    vertices, faces = [], []
    normal = Vector(normal)
    for j in range(n+1):
        for i in range(n+1):
            u, v = -1+2*i/n, -1+2*j/n
            rho = max(abs(u),abs(v))
            if rho < 1e-12:
                px = py = 0
            else:
                px,py = rounded_hit(u/rho*width/2,v/rho*height/2,width/2,height/2,radius)
                px *= rho
                py *= rho
            co = Vector(mapping(cx+px,cy+py)) + normal*dome*(1-rho*rho)
            vertices.append(co)
    for j in range(n):
        for i in range(n):
            k = j*(n+1)+i
            faces.append((k,k+1,k+n+2,k+n+1))
    obj = mesh(name,vertices,faces,collection,material,smooth=bool(dome))
    orient(obj,normal)
    if wall:
        thickness(obj,wall)
    return obj


def box(name, location, dimensions, collection, material, radius=.01):
    bpy.ops.mesh.primitive_cube_add(size=1,location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    collection.objects.link(obj)
    obj.data.materials.append(material)
    if radius:
        bevel(obj,radius,4)
        obj.modifiers.new('Normales ponderees','WEIGHTED_NORMAL')
    return obj


def cylinder(name, a, b, radius, collection, material, vertices=48, edge=.005):
    a,b = Vector(a),Vector(b)
    delta = b-a
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=delta.length,location=(a+b)/2)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = delta.to_track_quat('Z','Y').to_euler()
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    collection.objects.link(obj)
    if material:
        obj.data.materials.append(material)
    for p in obj.data.polygons:
        p.use_smooth = len(p.vertices)==4
    if edge:
        bevel(obj,edge,3)
    return obj


def curve(name, points, radius, collection, material):
    data = bpy.data.curves.new(name,'CURVE')
    data.dimensions = '3D'
    data.resolution_u = 16
    data.bevel_depth = radius
    data.bevel_resolution = 4
    data.use_fill_caps = True
    spline = data.splines.new('BEZIER')
    spline.bezier_points.add(len(points)-1)
    for p,co in zip(spline.bezier_points,points):
        p.co = co
        p.handle_left_type = p.handle_right_type = 'AUTO'
    obj = bpy.data.objects.new(name,data)
    collection.objects.link(obj)
    data.materials.append(material)
    return obj


def lathe(name, profile, origin, axis, collection, material, count=64):
    """Closed radial profile. Axis poles are single vertices, never collapsed quads."""
    axis = Vector(axis).normalized()
    origin = Vector(origin)
    helper = Vector((0,0,1)) if abs(axis.z)<.9 else Vector((0,1,0))
    u = axis.cross(helper).normalized()
    v = axis.cross(u).normalized()
    vertices, faces, loops = [], [], []
    for d,r in profile:
        loop = []
        for i in range(count if r>1e-9 else 1):
            angle = math.tau*i/count
            co = origin+axis*d+(u*math.cos(angle)+v*math.sin(angle))*r
            loop.append(len(vertices))
            vertices.append(co)
        loops.append(loop)
    for a,b in zip(loops,loops[1:]+loops[:1]):
        if len(a)==1 and len(b)==1:
            continue
        for i in range(count):
            j = (i+1)%count
            if len(a)==1:
                faces.append((a[0],b[i],b[j]))
            elif len(b)==1:
                faces.append((a[i],b[0],a[j]))
            else:
                faces.append((a[i],b[i],b[j],a[j]))
    obj = mesh(name,vertices,faces,collection,material,smooth=True)
    orient(obj)
    return obj


def extrude_loop(name, outline, map_a, map_b, collection, material):
    n = len(outline)
    vertices = [map_a(*p) for p in outline]+[map_b(*p) for p in outline]
    faces = [tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]
    faces.extend((i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n))
    obj = mesh(name,vertices,faces,collection,material)
    orient(obj)
    return obj


def evaluated_mesh(obj, depsgraph):
    ev = obj.evaluated_get(depsgraph)
    data = ev.to_mesh()
    vertices = [obj.matrix_world@v.co for v in data.vertices]
    faces = [tuple(p.vertices) for p in data.polygons]
    ev.to_mesh_clear()
    return vertices, faces
