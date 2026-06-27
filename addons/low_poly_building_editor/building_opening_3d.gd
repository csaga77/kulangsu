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

@export_range(0.0, 0.5, 0.005) var frame_protrusion := 0.02:
	set(value):
		var clamped_value := clampf(value, 0.0, 0.5)
		if is_equal_approx(frame_protrusion, clamped_value):
			return
		frame_protrusion = clamped_value
		_request_rebuild()

# Thickness of the wall this opening is mounted in. A value of 0 derives the
# thickness from frame_depth for compatibility with older authored openings.
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

@export var generate_collision := true:
	set(value):
		if generate_collision == value:
			return
		generate_collision = value
		_request_rebuild()

@export var build_on_ready := true

var m_is_ready := false
var m_rebuild_queued := false
var m_legacy_door_panel_count := 0
var m_legacy_door_panel_depth := 0.05
var m_legacy_door_panel_color := Color(0.50, 0.34, 0.20, 1.0)


# Storage-only compatibility for scenes authored before door styles became
# Door3D subclasses. Concrete Door3D nodes use their real exported properties,
# while a legacy base-class opening can still deserialize and render solid panels.
func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"door_panel_count":
			m_legacy_door_panel_count = clampi(int(value), 0, 2)
		&"door_panel_depth":
			m_legacy_door_panel_depth = maxf(float(value), 0.01)
		&"door_panel_color":
			m_legacy_door_panel_color = Color(value)
		_:
			return false
	_request_rebuild()
	return true


func _get(property: StringName) -> Variant:
	match property:
		&"door_panel_count":
			return m_legacy_door_panel_count
		&"door_panel_depth":
			return m_legacy_door_panel_depth
		&"door_panel_color":
			return m_legacy_door_panel_color
	return null


func _get_property_list() -> Array[Dictionary]:
	if get_script().resource_path != "res://addons/low_poly_building_editor/building_opening_3d.gd":
		return []
	return [
		{
			"name": "door_panel_count",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_STORAGE,
		},
		{
			"name": "door_panel_depth",
			"type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_STORAGE,
		},
		{
			"name": "door_panel_color",
			"type": TYPE_COLOR,
			"usage": PROPERTY_USAGE_STORAGE,
		},
	]


func _ready() -> void:
	m_is_ready = true
	if build_on_ready:
		_rebuild()


func get_opening_rect() -> Rect2:
	var size := Vector2(opening_width, opening_height)
	var center := Vector2(position.x, position.y)
	return Rect2(center - size * 0.5, size)


func _request_rebuild() -> void:
	if !m_is_ready or m_rebuild_queued:
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
	_build_opening_content()


# Implemented by Door3D and Window3D. BuildingOpening3D itself remains a useful
# frame-only opening and owns the wall-cut dimensions shared by every style.
# Legacy base-class scenes may still render their old solid door panels here.
func _build_opening_content() -> void:
	var spans := _leaf_spans(m_legacy_door_panel_count)
	for index in range(spans.size()):
		var part_name := _leaf_part_name("DoorPanel", index, spans.size())
		var rect := spans[index]
		_add_box(
			part_name,
			Vector3(rect.size.x, rect.size.y, m_legacy_door_panel_depth),
			_rect_center(rect),
			m_legacy_door_panel_color
		)


func _frame_casing() -> Dictionary:
	if frame_sides != FrameSides.BOTH:
		return {"depth": frame_depth, "center_z": 0.0}
	var thickness := wall_thickness if wall_thickness > 0.0 else maxf(frame_depth - 0.04, 0.02)
	var front_edge := -FRAME_FACE_GAP + frame_protrusion
	var back_edge := -(thickness + FRAME_FACE_GAP) - frame_protrusion
	return {"depth": front_edge - back_edge, "center_z": (front_edge + back_edge) * 0.5}


func _leaf_spans(count: int) -> Array[Rect2]:
	var spans: Array[Rect2] = []
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


func _leaf_part_name(base: String, index: int, count: int) -> String:
	if count <= 1:
		return base
	return ("Left" if index == 0 else "Right") + base


func _build_glass(
	part_name: String,
	rect: Rect2,
	depth: float,
	color: Color,
	pane_grid_rows: int = 0,
	pane_grid_cols: int = 0,
	muntin_thickness: float = 0.03,
	louver_count: int = 0,
	arch_steps: int = 0,
	transom_ratio: float = 0.0
) -> void:
	if louver_count > 0:
		_build_louvers(part_name, rect, depth, louver_count)
		return
	_add_box(part_name, Vector3(rect.size.x, rect.size.y, depth), _rect_center(rect), color)
	_add_muntins(
		part_name,
		rect,
		depth,
		pane_grid_rows,
		pane_grid_cols,
		muntin_thickness,
		transom_ratio
	)
	if arch_steps > 0:
		_add_arch_fillers(part_name, rect, depth, arch_steps)


func _add_muntins(
	part_name: String,
	rect: Rect2,
	depth: float,
	pane_grid_rows: int,
	pane_grid_cols: int,
	muntin_thickness: float,
	transom_ratio: float
) -> void:
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
		var row_y := rect.position.y + rect.size.y * float(row + 1) / float(pane_grid_rows + 1)
		_add_box(
			"%sMuntinH%d" % [part_name, row],
			Vector3(rect.size.x, muntin_thickness, bar_depth),
			Vector3(center_x, row_y, 0.0),
			frame_color,
			false
		)
	for col in range(pane_grid_cols):
		var col_x := rect.position.x + rect.size.x * float(col + 1) / float(pane_grid_cols + 1)
		_add_box(
			"%sMuntinV%d" % [part_name, col],
			Vector3(muntin_thickness, rect.size.y, bar_depth),
			Vector3(col_x, center_y, 0.0),
			frame_color,
			false
		)


func _add_arch_fillers(part_name: String, rect: Rect2, depth: float, arch_steps: int) -> void:
	var zone := minf(rect.size.x * 0.45, rect.size.y * 0.5)
	if zone <= 0.001 or arch_steps <= 0:
		return
	var band_height := zone / float(arch_steps)
	var fill_depth := maxf(depth + 0.01, frame_depth)
	for index in range(arch_steps):
		var fill := zone * (1.0 - float(index) / float(arch_steps))
		if fill <= 0.001:
			continue
		var y := rect.end.y - band_height * (float(index) + 0.5)
		_add_box(
			"%sArchL%d" % [part_name, index],
			Vector3(fill, band_height, fill_depth),
			Vector3(rect.position.x + fill * 0.5, y, 0.0),
			frame_color,
			false
		)
		_add_box(
			"%sArchR%d" % [part_name, index],
			Vector3(fill, band_height, fill_depth),
			Vector3(rect.end.x - fill * 0.5, y, 0.0),
			frame_color,
			false
		)


func _build_louvers(part_name: String, rect: Rect2, depth: float, louver_count: int) -> void:
	if louver_count <= 0:
		return
	var slat_gap := rect.size.y / float(louver_count)
	var slat_height := slat_gap * 0.92
	var slat_depth := maxf(depth * 2.0, frame_depth)
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(28.0))
	var center_x := rect.position.x + rect.size.x * 0.5
	for index in range(louver_count):
		var y := rect.position.y + slat_gap * (float(index) + 0.5)
		_add_oriented_box(
			"%sSlat%d" % [part_name, index],
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
