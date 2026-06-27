@tool
extends Window3D

@export_range(0.01, 0.5, 0.01) var window_pane_depth := 0.03:
	set(value):
		var clamped_value := maxf(value, 0.01)
		if is_equal_approx(window_pane_depth, clamped_value):
			return
		window_pane_depth = clamped_value
		_request_rebuild()

@export var window_pane_color := Color(0.58, 0.82, 0.95, 0.52):
	set(value):
		if window_pane_color == value:
			return
		window_pane_color = value
		_request_rebuild()


func _build_window_panes(count: int) -> void:
	var spans := _leaf_spans(count)
	for index in range(spans.size()):
		var part_name := _leaf_part_name("WindowPane", index, spans.size())
		_add_window_pane(part_name, spans[index])


func _add_window_pane(part_name: String, rect: Rect2) -> void:
	_add_glass(part_name, rect, window_pane_depth, window_pane_color)
