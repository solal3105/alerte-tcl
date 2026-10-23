"""Real glazed openings and a restrained toy-tram interior, with unchanged exterior.

Called by finition_tram.py. Hollowing is applied once; materials remain editable.
"""
import bpy, bmesh, json
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import barycentric_transform
import tram_geometry as g


def build_interior(material, root_path):
    if bpy.context.scene.get('vitrage_traversant'):
        return json.loads(bpy.context.scene.get('verification_vitrage') or (root_path/'verification_vitrage.json').read_text())
    scene=bpy.context.scene
    cutters=bpy.data.collections['90 Decoupes'];cutters.hide_viewport=False
    col=bpy.data.collections.new('07 Interieur visible');scene.collection.children.link(col)
    root=bpy.data.objects['TRAM / reconstruction de la photo']
    shells=[bpy.data.objects[n] for n in ('Cabine / volume continu','Remorque / volume continu')]
    original_bounds={o.name:tuple(tuple(v) for v in o.bound_box) for o in shells}
    guides={o.name:bpy.data.objects['Guide de section / '+o.name] for o in shells}
    cavities={}

    def subtract(shell,tool,label):
        tool.data.update();bpy.context.view_layer.update()
        mod=shell.modifiers.new(label,'BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=tool
        bpy.context.view_layer.objects.active=shell;bpy.ops.object.modifier_apply(modifier=mod.name)
        bm=bmesh.new();bm.from_mesh(shell.data)
        bmesh.ops.dissolve_degenerate(bm,dist=1e-6,edges=list(bm.edges))
        bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(shell.data);bm.free()
        bm=bmesh.new();bm.from_mesh(shell.data)
        print('CUT_STAGE',shell.name,tool.name,'volume',bm.calc_volume(signed=True),'open',sum(not e.is_manifold for e in bm.edges),flush=True)
        bm.free()

    # Consistent shell thickness rather than a solid wall behind transparent panes.
    for shell,yc in zip(shells,(2.0,6.16)):
        inner=guides[shell.name].copy();inner.data=guides[shell.name].data.copy()
        inner.name='Volume interieur / '+shell.name;cutters.objects.link(inner)
        for v in inner.data.vertices:
            v.co.x*=.86;v.co.y=yc+(v.co.y-yc)*.94;v.co.z=1.67+(v.co.z-1.67)*.89
        inner.hide_render=True;inner.hide_set(True);cavities[shell.name]=inner
        subtract(shell,inner,'Habitacle creux')

    tools=[o for o in cutters.objects if ' / outil' in o.name and ('vitre' in o.name or o.name.startswith('Pare brise'))]
    for source in tools:
        tool=source.copy();tool.data=source.data.copy();tool.name='Ouverture traversante / '+source.name
        cutters.objects.link(tool);tool.hide_render=True;tool.hide_set(True)
        count=len(tool.data.vertices)//2
        center=sum((v.co for v in tool.data.vertices),Vector())/len(tool.data.vertices)
        axis=1 if source.name.startswith('Pare brise') else 0
        step=.65 if axis==1 or center.x<0 else -.65
        for i in range(count):
            tool.data.vertices[i+count].co[axis]+=step
        # Avoid exact coincidence with the old pocket's side faces.
        for v in tool.data.vertices:
            for a in range(3):
                if a!=axis:v.co[a]=center[a]+(v.co[a]-center[a])*1.001
        g.orient(tool)
        shell=shells[1] if source.name.startswith('Remorque') else shells[0]
        subtract(shell,tool,'Baie vitree traversante')

    def guide_tree(obj):
        mesh=obj.data;mesh.calc_loop_triangles()
        verts=[v.co.copy() for v in mesh.vertices];normals=[v.normal.copy() for v in mesh.vertices]
        tris=[tuple(t.vertices) for t in mesh.loop_triangles]
        return BVHTree.FromPolygons(verts,tris,all_triangles=True),verts,normals,tris

    # Restore continuous outer shading; the reveals have their own physical normals.
    for shell in shells:
        sources=[guide_tree(guides[shell.name]),guide_tree(cavities[shell.name])];custom=[]
        for poly in shell.data.polygons:
            for vi in poly.vertices:
                p=shell.data.vertices[vi].co;normal=poly.normal.copy()
                for sign,(tree,verts,normals,tris) in zip((1,-1),sources):
                    hit,n,idx,dist=tree.find_nearest(p)
                    if dist<.018:
                        a,b,c=tris[idx]
                        normal=sign*barycentric_transform(hit,verts[a],verts[b],verts[c],normals[a],normals[b],normals[c]).normalized()
                        break
                custom.append(normal)
        shell.data.normals_split_custom_set(custom)

    ivory,_=material('Interieur - ivoire','E7E3D7',.55)
    floor_mat,_=material('Interieur - sol chaud','ACA99C',.7)
    seat_mat,_=material('Interieur - assises corail','D96353',.56)
    seat_edge,_=material('Interieur - coques de siege','DFE6E7',.4)
    dark,_=material('Interieur - console bleu nuit','243D50',.38)
    rail,_=material('Interieur - mains courantes','B6C4C9',.28,.65)
    panel,pp=material('Interieur - ecran discret','3C899F',.32)
    pp.inputs['Emission Color'].default_value=(.04,.15,.19,1);pp.inputs['Emission Strength'].default_value=.25
    for label,yc,length in [('Avant',2.,3.62),('Arriere',6.16,3.44)]:
        g.box(label+' / plancher',(0,yc,.79),(1.92,length,.10),col,floor_mat,.035)
        # Soft ceiling light keeps the cabin legible through the tinted panes.
        g.box(label+' / plafonnier',(0,yc,2.85),(.58,length*.62,.028),col,ivory,.013)
        data=bpy.data.lights.new(label+' / eclairage interieur','AREA');data.energy=22;data.color=(1,.87,.69)
        data.shape='RECTANGLE';data.size=.70;data.size_y=length*.65
        light=bpy.data.objects.new(data.name,data);col.objects.link(light);light.location=(0,yc,2.78)
    # Simple seats, low enough to retain clear sightlines through the opposite windows.
    for row,y in enumerate((2.2,3.12,5.26,6.98),1):
        for sign in (-1,1):
            x=sign*.64
            g.box(f'Siege {row} {sign:+} / pied',(x,y,.94),(.11,.19,.22),col,dark,.045)
            g.box(f'Siege {row} {sign:+} / coque',(x,y,1.075),(.49,.43,.10),col,seat_edge,.048)
            g.box(f'Siege {row} {sign:+} / assise',(x,y-.012,1.13),(.45,.40,.08),col,seat_mat,.037)
            g.box(f'Siege {row} {sign:+} / dossier',(x,y+.18,1.38),(.46,.11,.48),col,seat_mat,.052)
    g.box('Cabine / pupitre',(0,.56,1.23),(1.28,.34,.29),col,dark,.11)
    g.box('Cabine / petit ecran',(0,.58,1.381),(.33,.20,.016),col,panel,.007)
    g.box('Cabine / siege conducteur',(0,1.16,1.11),(.48,.47,.14),col,seat_mat,.065)
    g.box('Cabine / dossier conducteur',(0,1.38,1.40),(.45,.13,.53),col,seat_mat,.06)
    for y in (3.5,4.82):
        for sign in (-1,1):g.cylinder('Main courante',(sign*.84,y,.86),(sign*.84,y,2.73),.022,col,rail,32,.01)
    for ob in col.objects:ob.parent=root
    cutters.hide_viewport=True
    bpy.context.view_layer.update()

    failures=[];checks=[]
    for shell in shells:
        bm=bmesh.new();bm.from_mesh(shell.data)
        row={'shell':shell.name,'non_manifold_edges':sum(not e.is_manifold for e in bm.edges),
             'degenerate_faces':sum(f.calc_area()<1e-11 for f in bm.faces),'volume':bm.calc_volume(signed=True)}
        bm.free();checks.append(row)
        if row['non_manifold_edges'] or row['degenerate_faces'] or row['volume']<=0:failures.append(row)
        if any(abs(a-b)>1e-5 for v,w in zip(original_bounds[shell.name],shell.bound_box) for a,b in zip(v,w)):
            failures.append({'exterior_bounds_changed':shell.name})
    # Check the physical openings, not just the glass material's transmission slider.
    apertures=[]
    for pane in bpy.data.collections['02 Vitres encastrees'].objects:
        if ' / vitrage' not in pane.name:continue
        n=len(pane.data.vertices)//2
        front=sum((v.co for v in pane.data.vertices[:n]),Vector())/n
        back=sum((v.co for v in pane.data.vertices[n:]),Vector())/n
        normal=(front-back).normalized()
        shell=shells[1] if pane.name.startswith('Remorque') else shells[0]
        hit,*_=shell.ray_cast(front+normal*.06,-normal,distance=.55)
        apertures.append({'pane':pane.name,'open_into_cabin':not hit})
        if hit:failures.append({'blocked_glazing':pane.name})
    report={'exterior_bounds_unchanged':True,'shells':checks,'apertures':apertures,'failures':failures}
    (root_path/'verification_vitrage.json').write_text(json.dumps(report,indent=2))
    if failures:
        bpy.ops.wm.save_as_mainfile(filepath='/tmp/tram_vitrage_debug.blend')
        raise RuntimeError('Glazing validation failed: '+str(failures))
    scene['vitrage_traversant']=True
    scene['verification_vitrage']=json.dumps(report)
    return report
