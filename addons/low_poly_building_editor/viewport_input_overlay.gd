@tool
extends Control

var m_plugin: EditorPlugin


func setup(plugin: EditorPlugin) -> void:
	m_plugin = plugin
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	z_index = 4096
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(_delta: float) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if _is_building_tool_active() else Control.MOUSE_FILTER_IGNORE
	if get_parent() != null:
		move_to_front()


func _gui_input(event: InputEvent) -> void:
	if !_is_building_tool_active():
		return
	if m_plugin == null or !is_instance_valid(m_plugin):
		return
	if event is InputEventMouseButton and m_plugin.has_method("notify_viewport_overlay_event"):
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			m_plugin.call(
				"notify_viewport_overlay_event",
				"press" if mouse_button.pressed else "release"
			)
	var camera := _get_sub_viewport_camera()
	if camera == null:
		return
	var handled := bool(m_plugin.call("handle_viewport_overlay_input", camera, event))
	if handled:
		accept_event()


func _is_building_tool_active() -> bool:
	if m_plugin == null or !is_instance_valid(m_plugin):
		return false
	if !m_plugin.has_method("is_building_tool_active"):
		return false
	return bool(m_plugin.call("is_building_tool_active"))


func _get_sub_viewport_camera() -> Camera3D:
	var viewport_control := get_parent()
	if viewport_control == null:
		return null
	for child in viewport_control.get_children():
		if child is SubViewport:
			var sub_viewport := child as SubViewport
			return sub_viewport.get_camera_3d()
	return null
