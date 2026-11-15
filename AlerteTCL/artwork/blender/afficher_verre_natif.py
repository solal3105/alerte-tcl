"""Show the actual editable scene, with an additional solid model inspection view."""
import bpy
from mathutils import Vector
scene=bpy.context.scene
assert bpy.data.objects.get('RADAR / couronne de cristal massif')
scene.use_nodes=False
prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='METAL';prefs.get_devices()
for d in prefs.devices:d.use=d.type=='METAL'
scene.cycles.device='GPU';scene.cycles.preview_samples=48;scene.cycles.use_preview_denoising=True
screen=bpy.context.screen
main=max(screen.areas,key=lambda a:a.width*a.height)
main.type='VIEW_3D';s=main.spaces.active
s.camera=scene.camera;s.shading.type='RENDERED';s.shading.use_compositor='DISABLED'
s.shading.use_scene_lights_render=True;s.shading.use_scene_world_render=True
s.overlay.show_overlays=False
s.region_3d.view_perspective='CAMERA';s.region_3d.view_camera_zoom=0;s.region_3d.view_camera_offset=(0,0)
for area in screen.areas:
    if area==main or area.type not in {'PROPERTIES','CONSOLE'}:continue
    area.type='VIEW_3D';sp=area.spaces.active
    sp.shading.type='SOLID';sp.shading.color_type='MATERIAL';sp.shading.light='STUDIO'
    sp.overlay.show_overlays=False
    for ob in scene.objects:ob.select_set(False)
    model=bpy.data.objects['TRAM / reconstruction de la photo']
    for ob in model.children_recursive:
        if ob.type in {'MESH','CURVE'} and not ob.hide_get():ob.select_set(True)
    with bpy.context.temp_override(area=area,region=next(r for r in area.regions if r.type=='WINDOW')):
        bpy.ops.view3d.localview(frame_selected=False)
        bpy.ops.wm.tool_set_by_id(name='builtin.select_box')
    sp.region_3d.view_perspective='PERSP'
    sp.region_3d.view_rotation=(-Vector((-1,-1.1,.7))).to_track_quat('-Z','Y')
    sp.region_3d.view_location=(0,3.5,1.6);sp.region_3d.view_distance=15;sp.lens=45
    break
for ob in scene.objects:ob.select_set(False)
bpy.context.view_layer.objects.active=None
with bpy.context.temp_override(area=main,region=next(r for r in main.regions if r.type=='WINDOW')):
    bpy.ops.wm.tool_set_by_id(name='builtin.select_box')
bpy.ops.wm.save_mainfile()
