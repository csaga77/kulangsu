@tool
extends Node

var m_plugin: EditorPlugin


func setup(plugin: EditorPlugin) -> void:
	m_plugin = plugin
	set_process_input(true)


func _input(event: InputEvent) -> void:
	if !_is_building_tool_active():
		return
	if m_plugin == null or !is_instance_valid(m_plugin):
		return

	if event is InputEventKey:
		var camera := _get_first_camera()
		if camera != null and bool(m_plugin.call("_handle_viewport_overlay_input", camera, event)):
			get_viewport().set_input_as_handled()
		return

	if !(event is InputEventMouse):
		return

	var mouse_event := event as InputEventMouse
	var viewport_state := _find_viewport_state(mouse_event.position)
	if viewport_state.is_empty():
		return
	var camera_3d := viewport_state["camera"] as Camera3D
	if camera_3d == null:
		return

	var local_event := event.duplicate() as InputEvent
	var local_mouse := local_event as InputEventMouse
	if local_mouse != null:
		local_mouse.position = Vector2(viewport_state["local_position"])
		local_mouse.global_position = local_mouse.position

	if bool(m_plugin.call("_handle_viewport_overlay_input", camera_3d, local_event)):
		get_viewport().set_input_as_handled()


func _is_building_tool_active() -> bool:
	if m_plugin == null or !is_instance_valid(m_plugin):
		return false
	if !m_plugin.has_method("is_building_tool_active"):
		return false
	return bool(m_plugin.call("is_building_tool_active"))


func _find_viewport_state(mouse_position: Vector2) -> Dictionary:
	for index in range(4):
		var sub_viewport := EditorInterface.get_editor_viewport_3d(index)
		if sub_viewport == null:
			continue
		var control := sub_viewport.get_parent() as Control
		if control == null:
			continue
		var rect := control.get_global_rect()
		if !rect.has_point(mouse_position):
			continue
		return {
			"camera": sub_viewport.get_camera_3d(),
			"local_position": mouse_position - rect.position,
		}
	return {}


func _get_first_camera() -> Camera3D:
	for index in range(4):
		var sub_viewport := EditorInterface.get_editor_viewport_3d(index)
		if sub_viewport == null:
			continue
		var camera := sub_viewport.get_camera_3d()
		if camera != null:
			return camera
	return null
