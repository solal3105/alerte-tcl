"""Afficher la scene native complete en Cycles depuis la console Blender."""
import bpy

scene=bpy.context.scene
assert bpy.data.objects.get('RADAR / ensemble 3D editable'), 'Ouvrir Logo_App_Scene_3D.blend'
scene.use_nodes=False
area=max(bpy.context.screen.areas,key=lambda a:a.width*a.height)
area.type='VIEW_3D'
space=area.spaces.active
ground=bpy.data.objects.get('Sol studio / fond courbe continu')
if ground:ground.hide_set(True)
prefs=bpy.context.preferences.addons['cycles'].preferences
prefs.compute_device_type='METAL';prefs.get_devices()
for device in prefs.devices:device.use=device.type=='METAL'
scene.cycles.device='GPU'
scene.cycles.preview_samples=48
scene.cycles.preview_adaptive_threshold=.04
scene.cycles.use_preview_denoising=True
space.camera=scene.camera
space.shading.use_scene_world_render=True
space.shading.use_scene_lights_render=True
space.shading.use_compositor='DISABLED'
space.shading.type='RENDERED'
space.overlay.show_overlays=False
space.region_3d.view_perspective='CAMERA'
space.region_3d.view_camera_offset=(0,0)
space.region_3d.view_camera_zoom=0
area.type='VIEW_3D'
for other in bpy.context.screen.areas:
    if other!=area and other.type=='CONSOLE' and any(s.type=='PROPERTIES' for s in other.spaces):
        other.type='PROPERTIES'
with bpy.context.temp_override(area=area,region=next(r for r in area.regions if r.type=='WINDOW')):
    bpy.ops.wm.tool_set_by_id(name='builtin.select_box')
bpy.ops.wm.save_mainfile()
