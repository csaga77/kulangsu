@tool
class_name Window3D
extends BuildingOpening3D

@export_range(0, 2, 1) var window_pane_count := 1:
	set(value):
		var clamped_value := clampi(value, 0, 2)
		if window_pane_count == clamped_value:
			return
		window_pane_count = clamped_value
		_request_rebuild()

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

@export_range(0, 8, 1) var pane_grid_rows := 0:
	set(value):
		var clamped_value := clampi(value, 0, 8)
		if pane_grid_rows == clamped_value:
			return
		pane_grid_rows = clamped_value
		_request_rebuild()

@export_range(0, 8, 1) var pane_grid_cols := 0:
	set(value):
		var clamped_value := clampi(value, 0, 8)
		if pane_grid_cols == clamped_value:
			return
		pane_grid_cols = clamped_value
		_request_rebuild()

@export_range(0.005, 0.3, 0.005) var muntin_thickness := 0.03:
	set(value):
		var clamped_value := clampf(value, 0.005, 0.3)
		if is_equal_approx(muntin_thickness, clamped_value):
			return
		muntin_thickness = clamped_value
		_request_rebuild()

@export_range(0, 16, 1) var louver_count := 0:
	set(value):
		var clamped_value := clampi(value, 0, 16)
		if louver_count == clamped_value:
			return
		louver_count = clamped_value
		_request_rebuild()

@export_range(0, 6, 1) var arch_steps := 0:
	set(value):
		var clamped_value := clampi(value, 0, 6)
		if arch_steps == clamped_value:
			return
		arch_steps = clamped_value
		_request_rebuild()

@export_range(0.0, 0.9, 0.01) var transom_ratio := 0.0:
	set(value):
		var clamped_value := clampf(value, 0.0, 0.9)
		if is_equal_approx(transom_ratio, clamped_value):
			return
		transom_ratio = clamped_value
		_request_rebuild()


func _build_opening_content() -> void:
	var spans := _leaf_spans(window_pane_count)
	for index in range(spans.size()):
		var part_name := _leaf_part_name("WindowPane", index, spans.size())
		_build_glass(
			part_name,
			spans[index],
			window_pane_depth,
			window_pane_color,
			pane_grid_rows,
			pane_grid_cols,
			muntin_thickness,
			louver_count,
			arch_steps,
			transom_ratio
		)
