@tool
class_name Door3D
extends BuildingOpening3D

@export_range(0, 2, 1) var door_panel_count := 1:
	set(value):
		var clamped_value := clampi(value, 0, 2)
		if door_panel_count == clamped_value:
			return
		door_panel_count = clamped_value
		_request_rebuild()

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

@export_range(0.01, 0.5, 0.01) var door_glass_depth := 0.03:
	set(value):
		var clamped_value := maxf(value, 0.01)
		if is_equal_approx(door_glass_depth, clamped_value):
			return
		door_glass_depth = clamped_value
		_request_rebuild()

@export var door_glass_color := Color(0.58, 0.82, 0.95, 0.52):
	set(value):
		if door_glass_color == value:
			return
		door_glass_color = value
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

@export_range(0.0, 0.95, 0.01) var door_glazing_ratio := 0.0:
	set(value):
		var clamped_value := clampf(value, 0.0, 0.95)
		if is_equal_approx(door_glazing_ratio, clamped_value):
			return
		door_glazing_ratio = clamped_value
		_request_rebuild()

@export_range(0, 4, 1) var door_inset_rows := 0:
	set(value):
		var clamped_value := clampi(value, 0, 4)
		if door_inset_rows == clamped_value:
			return
		door_inset_rows = clamped_value
		_request_rebuild()

@export_range(0, 3, 1) var door_inset_cols := 0:
	set(value):
		var clamped_value := clampi(value, 0, 3)
		if door_inset_cols == clamped_value:
			return
		door_inset_cols = clamped_value
		_request_rebuild()

@export var door_split := false:
	set(value):
		if door_split == value:
			return
		door_split = value
		_request_rebuild()


func _init() -> void:
	opening_width = 0.9
	opening_height = 2.1
	show_bottom_frame = false


func _build_opening_content() -> void:
	var spans := _leaf_spans(door_panel_count)
	for index in range(spans.size()):
		var part_name := _leaf_part_name("DoorPanel", index, spans.size())
		_build_door_leaf(part_name, spans[index])


func _build_door_leaf(part_name: String, rect: Rect2) -> void:
	if door_split:
		var gap := frame_thickness
		var leaf_height := maxf((rect.size.y - gap) * 0.5, 0.01)
		var lower := Rect2(rect.position.x, rect.position.y, rect.size.x, leaf_height)
		var upper := Rect2(rect.position.x, rect.position.y + leaf_height + gap, rect.size.x, leaf_height)
		_build_door_face("%sLower" % part_name, lower)
		_build_door_face("%sUpper" % part_name, upper)
		_add_box(
			"%sMidRail" % part_name,
			Vector3(rect.size.x, gap, door_panel_depth),
			Vector3(rect.position.x + rect.size.x * 0.5, rect.position.y + leaf_height + gap * 0.5, 0.0),
			frame_color,
			false
		)
		return
	if door_glazing_ratio > 0.0:
		var rail := frame_thickness
		var glass_height := maxf(rect.size.y * door_glazing_ratio, 0.01)
		var solid_height := maxf(rect.size.y - glass_height - rail, 0.01)
		var solid_rect := Rect2(rect.position.x, rect.position.y, rect.size.x, solid_height)
		var glass_rect := Rect2(
			rect.position.x,
			rect.position.y + solid_height + rail,
			rect.size.x,
			maxf(rect.size.y - solid_height - rail, 0.01)
		)
		_build_door_face("%sPanel" % part_name, solid_rect)
		_add_box(
			"%sRail" % part_name,
			Vector3(rect.size.x, rail, door_panel_depth),
			Vector3(rect.position.x + rect.size.x * 0.5, rect.position.y + solid_height + rail * 0.5, 0.0),
			door_panel_color,
			false
		)
		_build_glass(
			"%sGlass" % part_name,
			glass_rect,
			door_glass_depth,
			door_glass_color,
			pane_grid_rows,
			pane_grid_cols,
			muntin_thickness
		)
		return
	_build_door_face(part_name, rect)


func _build_door_face(part_name: String, rect: Rect2) -> void:
	_add_box(
		part_name,
		Vector3(rect.size.x, rect.size.y, door_panel_depth),
		_rect_center(rect),
		door_panel_color
	)
	if door_inset_rows <= 0 or door_inset_cols <= 0:
		return
	var margin := minf(minf(rect.size.x, rect.size.y) * 0.18, 0.12)
	var cell_width := (rect.size.x - margin * float(door_inset_cols + 1)) / float(door_inset_cols)
	var cell_height := (rect.size.y - margin * float(door_inset_rows + 1)) / float(door_inset_rows)
	if cell_width <= 0.02 or cell_height <= 0.02:
		return
	var raise := door_panel_depth * 0.6
	for row in range(door_inset_rows):
		for col in range(door_inset_cols):
			var x := rect.position.x + margin * float(col + 1) + cell_width * (float(col) + 0.5)
			var y := rect.position.y + margin * float(row + 1) + cell_height * (float(row) + 0.5)
			_add_box(
				"%sInset%d_%d" % [part_name, row, col],
				Vector3(cell_width, cell_height, door_panel_depth + raise),
				Vector3(x, y, 0.0),
				door_panel_color,
				false
			)
