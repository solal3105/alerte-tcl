"""Geometric acceptance checks, using the evaluated model rather than rendered images."""
import json
import math
import bpy
import bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
import tram_geometry as g


def verify(dim, checks, collections, root):
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    cache, rows, failures = {}, [], []

    def geometry(obj):
        if obj.name not in cache:
            vertices,faces = g.evaluated_mesh(obj,dg)
            bounds = [(min(v[a] for v in vertices),max(v[a] for v in vertices)) for a in range(3)]
            tree = BVHTree.FromPolygons(vertices,faces,all_triangles=False,epsilon=0)
            cache[obj.name] = (vertices,faces,bounds,tree)
        return cache[obj.name]

    def require(condition, message):
        if not condition:
            failures.append(message)

    # A model-only scene must have no camera or light and no obsolete logo background.
    require(not any(o.type in {'CAMERA','LIGHT'} for o in bpy.data.objects),'Camera or light present')
    require(bpy.context.scene.camera is None,'Scene has a render camera')

    for obj in bpy.context.scene.objects:
        if obj.type != 'MESH' or obj.name in collections['cutters'].objects:
            continue
        ev = obj.evaluated_get(dg)
        data = ev.to_mesh()
        bm = bmesh.new()
        bm.from_mesh(data)
        nonmanifold = sum(not e.is_manifold for e in bm.edges)
        degenerate = sum(f.calc_area()<1e-10 for f in bm.faces)
        loose = sum(not v.link_faces for v in bm.verts)
        finite = all(math.isfinite(c) for v in bm.verts for c in v.co)
        volume = bm.calc_volume(signed=True)
        row = {'object':obj.name,'vertices':len(bm.verts),'faces':len(bm.faces),
               'non_manifold_edges':nonmanifold,'degenerate_faces':degenerate,
               'loose_vertices':loose,'signed_volume_m3':round(volume,9)}
        rows.append(row)
        require(nonmanifold==0,f'{obj.name}: {nonmanifold} non-manifold edges')
        require(degenerate==0,f'{obj.name}: {degenerate} degenerate faces')
        require(loose==0 and finite,f'{obj.name}: invalid vertices')
        require(volume>1e-10,f'{obj.name}: inverted or zero volume ({volume})')
        bm.free()
        ev.to_mesh_clear()

    # Verify glazing actually clears the metal surrounding the aperture, not just its normals.
    contacts = []
    for pane,shell in checks['glazing']:
        intersections = len(geometry(pane)[3].overlap(geometry(shell)[3]))
        contacts.append({'glass':pane.name,'wall':shell.name,'triangle_intersections':intersections})
        require(intersections==0,f'{pane.name}: intersects its metal wall ({intersections})')

    for lens,housing,origin,normal in checks['lamps']:
        intersections = len(geometry(lens)[3].overlap(geometry(housing)[3]))
        require(intersections==0,f'{lens.name}: intersects housing')
        # Test the full mesh in the housing's actual local cylindrical frame.
        radial=[];axial=[]
        for p in geometry(lens)[0]:
            q=p-origin
            depth=q.dot(normal)
            axial.append(depth)
            radial.append((q-normal*depth).length)
        require(max(radial)<.178-1e-5,f'{lens.name}: outside housing bore')
        require(min(axial)>=-.065 and max(axial)<.045,f'{lens.name}: incorrect recess')

    for bridge,bellows in checks['joint_parts']:
        require(not geometry(bridge)[3].overlap(geometry(bellows)[3]),
                'Articulation bellows intersects the gangway floor')
        bounds=geometry(bridge)[2]
        require(abs(bounds[1][0]-dim.front_end)<1e-5 and abs(bounds[1][1]-dim.rear_start)<1e-5,
                'Gangway floor does not meet both coach floor ends')
    for flange,sign in checks['flanges']:
        bounds=geometry(flange)[2]
        contact=bounds[1][0] if sign>0 else bounds[1][1]
        expected=dim.front_end if sign>0 else dim.rear_start
        require(abs(contact-expected)<1e-5,f'{flange.name}: floating flange')

    require(len(checks['wheels'])==12,'Expected 3 bogies, 2 axles each, 2 wheels per axle')
    wheel_bounds=[]
    for wheel in checks['wheels']:
        b=geometry(wheel)[2]
        require(abs(b[2][0])<1e-5,f'{wheel.name}: inconsistent contact level {b[2][0]}')
        require(abs(b[2][1]-2*dim.wheel_radius)<1e-5,f'{wheel.name}: inconsistent radius')
        wheel_bounds.append({'object':wheel.name,'bounds_m':b})
        for skin in checks['skins']:
            sb=geometry(skin)[2]
            # Cheap broad-phase rejection, followed by a real mesh intersection test when needed.
            separated=any(b[a][1]<sb[a][0]-1e-6 or sb[a][1]<b[a][0]-1e-6 for a in range(3))
            if not separated:
                require(not geometry(wheel)[3].overlap(geometry(skin)[3]),
                        f'{wheel.name}: collides with {skin.name}')
        for part in collections['bogies'].objects:
            if part.type!='MESH' or part in checks['wheels']:
                continue
            pb=geometry(part)[2]
            separated=any(b[a][1]<pb[a][0]-1e-6 or pb[a][1]<b[a][0]-1e-6 for a in range(3))
            if not separated:
                require(not geometry(wheel)[3].overlap(geometry(part)[3]),
                        f'{wheel.name}: collides with running gear {part.name}')
    wheel_top=max(b['bounds_m'][2][1] for b in wheel_bounds)
    clearance=dim.bottom-wheel_top
    require(clearance>=.05,'Insufficient wheel-to-body vertical clearance')

    for foot in checks['panto_feet']:
        b=geometry(foot)[2]
        require(abs(b[2][0]-dim.roof)<1e-5,f'{foot.name}: does not sit on the roof')
        require(b[0][0]>-dim.half_width+dim.upper_radius and
                b[0][1]<dim.half_width-dim.upper_radius,f'{foot.name}: outside flat roof')
        require(b[1][0]>dim.rear_start and b[1][1]<dim.rear_side_end,f'{foot.name}: outside rear roof')

    # The evaluated shells must retain the common nominal section on both bodies.
    for name in ('front / toit','rear / toit'):
        b=geometry(bpy.data.objects[name])[2]
        require(abs(b[2][1]-dim.roof)<1e-5,f'{name}: roof height mismatch')
        require(abs(b[0][0]+dim.half_width)<1e-5 and abs(b[0][1]-dim.half_width)<1e-5,
                f'{name}: body width mismatch')
    for name in ('front / plancher','rear / plancher','Avant / prolongement plancher',
                 'Arriere / prolongement plancher','Passerelle / plancher commun'):
        b=geometry(bpy.data.objects[name])[2]
        require(abs(b[2][1]-dim.floor)<1e-5,f'{name}: floor height mismatch')

    report = {
        'summary': {'mesh_parts':len(rows),'glazing_clearance_checks':len(contacts),
                    'wheels':len(checks['wheels']),'bogies':3,
                    'minimum_wheel_body_clearance_m':round(clearance,6),
                    'body_width_m':2*dim.half_width,'roof_height_m':dim.roof,
                    'floor_height_m':dim.floor,'cameras':0,'lights':0,
                    'gangway_and_flange_contact_checks':True,
                    'wheel_running_gear_clearance_checks':True,
                    'failures':len(failures)},
        'parts':rows,'glazing':contacts,'wheels':wheel_bounds,'failures':failures}
    (root/'verification_geometrie.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    lines = ['CONTROLE GEOMETRIQUE DU MODELE','',
             f'{len(rows)} pieces maillees controlees apres evaluation des modificateurs.',
             f'{len(contacts)} vitrages controles contre les parois metalliques.',
             f'12 roues, 6 essieux, 3 bogies. Degagement vertical roue/coque : {clearance*1000:.1f} mm.',
             f'Section commune : largeur {2*dim.half_width:.2f} m ; toit {dim.roof:.2f} m ; plancher {dim.floor:.2f} m.',
             'Controle des appuis du pantographe sur le toit.',
             'Raccords plancher/passerelle et brides/cloisons controles.',
             'Roues controlees contre les chassis de bogie, boites d’essieu et arbres.',
             'Aucune camera, aucun eclairage, aucun rendu.','',
             'ECHECS :' if failures else 'Tous les controles ci-dessus sont passes.']
    lines.extend(failures)
    (root/'verification.txt').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    if failures:
        raise RuntimeError('Geometric validation failed:\n'+'\n'.join(failures))
    return report
