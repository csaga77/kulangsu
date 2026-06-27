@tool
extends Door3D

@export_range(0.01, 0.5, 0.01) var door_panel_depth := 0.05:
	set(value):
		var clamped_value := maxf(value, 0.01)
		if is_equal_approx(door_panel_depth, clamped_value):
			return
		door_panel_depth = clamped_value
		_request_rebuild()

@export var door_panel_color := Color(0.50, 0.34, 0.20, 1.0):
	set(value):
		if door_panel_color == value:
			return
		door_panel_color = value
		_request_rebuild()


func _build_solid_door_leaves(count: int) -> void:
	var spans := _leaf_spans(count)
	for index in range(spans.size()):
		var part_name := _leaf_part_name("DoorPanel", index, spans.size())
		_add_solid_door_panel(part_name, spans[index])


func _add_solid_door_panel(part_name: String, rect: Rect2) -> void:
	_add_box(
		part_name,
		Vector3(rect.size.x, rect.size.y, door_panel_depth),
		_rect_center(rect),
		door_panel_color
	)
