@tool
class_name BuildingOpening3D
extends Node3D

const GENERATED_META := &"building_opening_generated"

# Gap between the opening node origin and the wall face it is placed against.
# Mirrors the placement offset applied by the editor plugin so the frame casing
# can be positioned relative to both wall faces.
const FRAME_FACE_GAP := 0.035

# Which wall faces the frame casing covers. FRONT keeps the legacy single-sided
# casing on the placement face; BOTH centers the casing in the wall so trim shows
# (and protrudes) on both faces.
enum FrameSides { FRONT, BOTH }

@export var rebuild := false:
	set(value):
		if !value:
			return
		call_deferred("_rebuild")

@export_range(0.1, 12.0, 0.01) var opening_width := 1.0:
	set(value):
		var clamped_value := maxf(value, 0.1)
		if is_equal_approx(opening_width, clamped_value):
			return
		opening_width = clamped_value
		_request_rebuild()

@export_range(0.1, 12.0, 0.01) var opening_height := 1.0:
	set(value):
		var clamped_value := maxf(value, 0.1)
		if is_equal_approx(opening_height, clamped_value):
			return
		opening_height = clamped_value
		_request_rebuild()

@export_range(0.01, 1.0, 0.01) var frame_thickness := 0.08:
	set(value):
		var clamped_value := maxf(value, 0.01)
		if is_equal_approx(frame_thickness, clamped_value):
			return
		frame_thickness = clamped_value
		_request_rebuild()

@export_range(0.01, 1.0, 0.01) var frame_depth := 0.08:
	set(value):
		var clamped_value := maxf(value, 0.01)
		if is_equal_approx(frame_depth, clamped_value):
			return
		frame_depth = clamped_value
		_request_rebuild()

@export var frame_color := Color(0.86, 0.92, 0.94, 1.0):
	set(value):
		if frame_color == value:
			return
		frame_color = value
		_request_rebuild()

@export var frame_sides: FrameSides = FrameSides.FRONT:
	set(value):
		if frame_sides == value:
			return
		frame_sides = value
		_request_rebuild()

# How far the casing protrudes beyond each covered wall face (BOTH mode).
@export_range(0.0, 0.5, 0.005) var frame_protrusion := 0.02:
	set(value):
		var clamped_value := clampf(value, 0.0, 0.5)
		if is_equal_approx(frame_protrusion, clamped_value):
			return
		frame_protrusion = clamped_value
		_request_rebuild()

# Thickness of the wall this opening is mounted in. Lets a BOTH-sided casing span
# the wall and protrude past both faces. 0 derives it from frame_depth so
# openings authored before this property existed still build a valid casing.
@export_range(0.0, 4.0, 0.01) var wall_thickness := 0.0:
	set(value):
		var clamped_value := maxf(value, 0.0)
		if is_equal_approx(wall_thickness, clamped_value):
			return
		wall_thickness = clamped_value
		_request_rebuild()

@export var show_bottom_frame := true:
	set(value):
		if show_bottom_frame == value:
			return
		show_bottom_frame = value
		_request_rebuild()

# Generate static collision for the solid opening parts (frame jambs, door panels,
# window panes) so the character is blocked by a closed door/window and by the door
# frame, instead of walking through it. An open doorway (no panels) stays passable
# because only the edge frame carries collision. Mirrors the generate_collision
# convention on the other building_editor modules.
@export var generate_collision := true:
	set(value):
		if generate_collision == value:
			return
		generate_collision = value
		_request_rebuild()

@export_range(0, 2, 1) var door_panel_count := 0:
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

@export_range(0, 2, 1) var window_pane_count := 0:
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

# Muntin grid drawn over glass (window panes and glazed door lites). Rows are
# interior horizontal bars, cols are interior vertical bars; 0/0 leaves a plain pane.
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

# When > 0, the pane area is filled with this many tilted horizontal slats
# (a louvered window) instead of a flat glass pane.
@export_range(0, 16, 1) var louver_count := 0:
	set(value):
		var clamped_value := clampi(value, 0, 16)
		if louver_count == clamped_value:
			return
		louver_count = clamped_value
		_request_rebuild()

# When > 0, the top of the pane gets a stepped low-poly arch (frame-colored
# corner fillers); 0 keeps a square-topped pane.
@export_range(0, 6, 1) var arch_steps := 0:
	set(value):
		var clamped_value := clampi(value, 0, 6)
		if arch_steps == clamped_value:
			return
		arch_steps = clamped_value
		_request_rebuild()

# When > 0, a horizontal rail splits this top fraction of the pane into a
# separate transom light above the main glass.
@export_range(0.0, 0.9, 0.01) var transom_ratio := 0.0:
	set(value):
		var clamped_value := clampf(value, 0.0, 0.9)
		if is_equal_approx(transom_ratio, clamped_value):
			return
		transom_ratio = clamped_value
		_request_rebuild()

# When > 0, the top fraction of each door panel becomes a translucent glass
# lite (a glazed door) separated from the solid panel by a rail.
@export_range(0.0, 0.95, 0.01) var door_glazing_ratio := 0.0:
	set(value):
		var clamped_value := clampf(value, 0.0, 0.95)
		if is_equal_approx(door_glazing_ratio, clamped_value):
			return
		door_glazing_ratio = clamped_value
		_request_rebuild()

# Recessed-panel grid raised on solid door faces (a paneled door). 0 rows or
# 0 cols leaves a flat door face.
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

# When true, each solid door panel is split horizontally into two stacked
# leaves with a mid rail (a Dutch/stable door).
@export var door_split := false:
	set(value):
		if door_split == value:
			return
		door_split = value
		_request_rebuild()

@export var build_on_ready := true

var m_is_ready := false
var m_rebuild_queued := false


func _ready() -> void:
	m_is_ready = true
	if build_on_ready:
		_rebuild()


func get_opening_rect() -> Rect2:
	var size := Vector2(opening_width, opening_height)
	var center := Vector2(position.x, position.y)
	return Rect2(center - size * 0.5, size)


func _request_rebuild() -> void:
	if !m_is_ready:
		return
	if m_rebuild_queued:
		return
	m_rebuild_queued = true
	call_deferred("_rebuild")


func _rebuild() -> void:
	m_rebuild_queued = false
	_clear_generated_children()

	var half_width := opening_width * 0.5
	var half_height := opening_height * 0.5
	var bottom_extra := frame_thickness if show_bottom_frame else 0.0
	var side_height := opening_height + frame_thickness + bottom_extra
	var side_y := (frame_thickness - bottom_extra) * 0.5
	var top_width := opening_width + frame_thickness * 2.0

	var casing := _frame_casing()
	var casing_depth: float = casing["depth"]
	var casing_z: float = casing["center_z"]

	_add_box(
		"LeftFrame",
		Vector3(frame_thickness, side_height, casing_depth),
		Vector3(-half_width - frame_thickness * 0.5, side_y, casing_z),
		frame_color
	)
	_add_box(
		"RightFrame",
		Vector3(frame_thickness, side_height, casing_depth),
		Vector3(half_width + frame_thickness * 0.5, side_y, casing_z),
		frame_color
	)
	_add_box(
		"TopFrame",
		Vector3(top_width, frame_thickness, casing_depth),
		Vector3(0.0, half_height + frame_thickness * 0.5, casing_z),
		frame_color
	)
	if show_bottom_frame:
		_add_box(
			"BottomFrame",
			Vector3(top_width, frame_thickness, casing_depth),
			Vector3(0.0, -half_height - frame_thickness * 0.5, casing_z),
			frame_color
		)
	_add_door_panels()
	_add_window_panes()


# Returns the depth and local-z center of the frame casing. FRONT keeps the
# legacy casing (frame_depth centered on the node origin). BOTH spans the wall
# and protrudes past both faces, centered on the wall mid-plane: in node-local
# space the placed face sits at -FRAME_FACE_GAP and the far face at
# -(thickness + FRAME_FACE_GAP), independent of which face it was placed against.
func _frame_casing() -> Dictionary:
	if frame_sides != FrameSides.BOTH:
		return {"depth": frame_depth, "center_z": 0.0}
	var thickness := wall_thickness if wall_thickness > 0.0 else maxf(frame_depth - 0.04, 0.02)
	var front_edge := -FRAME_FACE_GAP + frame_protrusion
	var back_edge := -(thickness + FRAME_FACE_GAP) - frame_protrusion
	return {"depth": front_edge - back_edge, "center_z": (front_edge + back_edge) * 0.5}


func _add_door_panels() -> void:
	if door_panel_count <= 0:
		return
	var spans := _leaf_spans(door_panel_count)
	for index in range(spans.size()):
		var leaf_name := _leaf_part_name("DoorPanel", index, spans.size())
		_build_door_leaf(leaf_name, spans[index], door_panel_depth, door_panel_color)


func _add_window_panes() -> void:
	if window_pane_count <= 0:
		return
	var spans := _leaf_spans(window_pane_count)
	for index in range(spans.size()):
		var leaf_name := _leaf_part_name("WindowPane", index, spans.size())
		_build_glass(leaf_name, spans[index], window_pane_depth, window_pane_color)


# Returns one local-space XY Rect2 per leaf: a single full-width leaf, or two
# split leaves separated by a seam gap. The opening is centered on the origin.
func _leaf_spans(count: int) -> Array:
	var spans: Array = []
	if count <= 0:
		return spans
	var half_width := opening_width * 0.5
	var half_height := opening_height * 0.5
	if count == 1:
		spans.append(Rect2(-half_width, -half_height, opening_width, opening_height))
		return spans
	var seam_gap := minf(0.035, opening_width * 0.08)
	var panel_width := maxf((opening_width - seam_gap) * 0.5, 0.01)
	var offset_x := panel_width * 0.5 + seam_gap * 0.5
	spans.append(Rect2(-offset_x - panel_width * 0.5, -half_height, panel_width, opening_height))
	spans.append(Rect2(offset_x - panel_width * 0.5, -half_height, panel_width, opening_height))
	return spans


# Keeps the original node naming so existing scenes and tooling stay stable:
# one leaf uses the base name, two leaves use Left/Right prefixes.
func _leaf_part_name(base: String, index: int, count: int) -> String:
	if count <= 1:
		return base
	return ("Left" if index == 0 else "Right") + base


func _build_door_leaf(part_name: String, rect: Rect2, depth: float, color: Color) -> void:
	if door_split:
		var gap := frame_thickness
		var leaf_height := maxf((rect.size.y - gap) * 0.5, 0.01)
		var lower := Rect2(rect.position.x, rect.position.y, rect.size.x, leaf_height)
		var upper := Rect2(rect.position.x, rect.position.y + leaf_height + gap, rect.size.x, leaf_height)
		_build_door_face("%sLower" % part_name, lower, depth, color)
		_build_door_face("%sUpper" % part_name, upper, depth, color)
		_add_box(
			"%sMidRail" % part_name,
			Vector3(rect.size.x, gap, depth),
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
		_build_door_face("%sPanel" % part_name, solid_rect, depth, color)
		_add_box(
			"%sRail" % part_name,
			Vector3(rect.size.x, rail, depth),
			Vector3(rect.position.x + rect.size.x * 0.5, rect.position.y + solid_height + rail * 0.5, 0.0),
			color,
			false
		)
		_build_glass("%sGlass" % part_name, glass_rect, window_pane_depth, window_pane_color)
		return
	_build_door_face(part_name, rect, depth, color)


func _build_door_face(part_name: String, rect: Rect2, depth: float, color: Color) -> void:
	_add_box(part_name, Vector3(rect.size.x, rect.size.y, depth), _rect_center(rect), color)
	if door_inset_rows <= 0 or door_inset_cols <= 0:
		return
	var margin := minf(minf(rect.size.x, rect.size.y) * 0.18, 0.12)
	var cell_width := (rect.size.x - margin * float(door_inset_cols + 1)) / float(door_inset_cols)
	var cell_height := (rect.size.y - margin * float(door_inset_rows + 1)) / float(door_inset_rows)
	if cell_width <= 0.02 or cell_height <= 0.02:
		return
	var raise := depth * 0.6
	for row in range(door_inset_rows):
		for col in range(door_inset_cols):
			var px := rect.position.x + margin * float(col + 1) + cell_width * (float(col) + 0.5)
			var py := rect.position.y + margin * float(row + 1) + cell_height * (float(row) + 0.5)
			_add_box(
				"%sInset%d_%d" % [part_name, row, col],
				Vector3(cell_width, cell_height, depth + raise),
				Vector3(px, py, 0.0),
				color,
				false
			)


# Builds a glass pane in the given rect, with optional louvers, muntin grid,
# transom rail, and stepped arch top driven by the exported style properties.
func _build_glass(part_name: String, rect: Rect2, depth: float, color: Color) -> void:
	if louver_count > 0:
		_build_louvers(part_name, rect, depth)
		return
	_add_box(part_name, Vector3(rect.size.x, rect.size.y, depth), _rect_center(rect), color)
	_add_muntins(part_name, rect, depth)
	if arch_steps > 0:
		_add_arch_fillers(part_name, rect, depth)


func _add_muntins(part_name: String, rect: Rect2, depth: float) -> void:
	var bar_depth := maxf(depth + 0.01, frame_depth * 0.6)
	var center_x := rect.position.x + rect.size.x * 0.5
	var center_y := rect.position.y + rect.size.y * 0.5
	if transom_ratio > 0.0:
		var split_y := rect.end.y - rect.size.y * transom_ratio
		_add_box(
			"%sTransomRail" % part_name,
			Vector3(rect.size.x, muntin_thickness, bar_depth),
			Vector3(center_x, split_y, 0.0),
			frame_color,
			false
		)
	for row in range(pane_grid_rows):
		var ry := rect.position.y + rect.size.y * float(row + 1) / float(pane_grid_rows + 1)
		_add_box(
			"%sMuntinH%d" % [part_name, row],
			Vector3(rect.size.x, muntin_thickness, bar_depth),
			Vector3(center_x, ry, 0.0),
			frame_color,
			false
		)
	for col in range(pane_grid_cols):
		var cx := rect.position.x + rect.size.x * float(col + 1) / float(pane_grid_cols + 1)
		_add_box(
			"%sMuntinV%d" % [part_name, col],
			Vector3(muntin_thickness, rect.size.y, bar_depth),
			Vector3(cx, center_y, 0.0),
			frame_color,
			false
		)


func _add_arch_fillers(part_name: String, rect: Rect2, depth: float) -> void:
	var zone := minf(rect.size.x * 0.45, rect.size.y * 0.5)
	if zone <= 0.001 or arch_steps <= 0:
		return
	var band_height := zone / float(arch_steps)
	var fill_depth := maxf(depth + 0.01, frame_depth)
	for i in range(arch_steps):
		var fill := zone * (1.0 - float(i) / float(arch_steps))
		if fill <= 0.001:
			continue
		var y := rect.end.y - band_height * (float(i) + 0.5)
		_add_box(
			"%sArchL%d" % [part_name, i],
			Vector3(fill, band_height, fill_depth),
			Vector3(rect.position.x + fill * 0.5, y, 0.0),
			frame_color,
			false
		)
		_add_box(
			"%sArchR%d" % [part_name, i],
			Vector3(fill, band_height, fill_depth),
			Vector3(rect.end.x - fill * 0.5, y, 0.0),
			frame_color,
			false
		)


func _build_louvers(part_name: String, rect: Rect2, depth: float) -> void:
	if louver_count <= 0:
		return
	var slat_gap := rect.size.y / float(louver_count)
	var slat_height := slat_gap * 0.92
	var slat_depth := maxf(depth * 2.0, frame_depth)
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(28.0))
	var center_x := rect.position.x + rect.size.x * 0.5
	for i in range(louver_count):
		var y := rect.position.y + slat_gap * (float(i) + 0.5)
		_add_oriented_box(
			"%sSlat%d" % [part_name, i],
			Vector3(rect.size.x, slat_height, slat_depth),
			Vector3(center_x, y, 0.0),
			frame_color,
			tilt
		)


func _rect_center(rect: Rect2) -> Vector3:
	return Vector3(rect.position.x + rect.size.x * 0.5, rect.position.y + rect.size.y * 0.5, 0.0)


func _add_box(
	part_name: String,
	size: Vector3,
	local_position: Vector3,
	color: Color,
	with_collision: bool = true
) -> void:
	_spawn_box(part_name, size, Transform3D(Basis(), local_position), color, with_collision)


func _add_oriented_box(
	part_name: String,
	size: Vector3,
	local_position: Vector3,
	color: Color,
	basis: Basis
) -> void:
	_spawn_box(part_name, size, Transform3D(basis, local_position), color, true)


func _spawn_box(
	part_name: String,
	size: Vector3,
	local_transform: Transform3D,
	color: Color,
	with_collision: bool
) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size

	var instance := MeshInstance3D.new()
	instance.name = part_name
	instance.mesh = mesh
	instance.transform = local_transform
	instance.material_override = _build_material(color)
	instance.set_meta(GENERATED_META, true)
	add_child(instance)
	if Engine.is_editor_hint():
		instance.owner = null
	if generate_collision and with_collision:
		_attach_part_collision(instance, size)


# Parents a StaticBody3D + box CollisionShape3D under a generated opening part so it
# blocks the character. The body rides the part's transform and is freed with it on
# rebuild (it lives under a GENERATED_META-tagged part), and is kept owner-less in the
# editor so it stays a rebuild artifact. The default StaticBody3D layer (1) matches
# the character's collision mask, like the other building_editor collision bodies.
func _attach_part_collision(part: Node3D, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size

	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	collision_shape.shape = shape
	collision_shape.set_meta(GENERATED_META, true)

	var body := StaticBody3D.new()
	body.name = "Collision"
	body.set_meta(GENERATED_META, true)
	body.add_child(collision_shape)
	part.add_child(body)
	if Engine.is_editor_hint():
		body.owner = null
		collision_shape.owner = null


func _build_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if color.a < 0.99:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _clear_generated_children() -> void:
	for child in get_children():
		if !child.has_meta(GENERATED_META):
			continue
		remove_child(child)
		child.free()
