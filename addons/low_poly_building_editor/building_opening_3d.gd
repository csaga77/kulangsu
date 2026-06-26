@tool
class_name BuildingOpening3D
extends Node3D

const GENERATED_META := &"building_opening_generated"

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

	_add_box(
		"LeftFrame",
		Vector3(frame_thickness, side_height, frame_depth),
		Vector3(-half_width - frame_thickness * 0.5, side_y, 0.0),
		frame_color
	)
	_add_box(
		"RightFrame",
		Vector3(frame_thickness, side_height, frame_depth),
		Vector3(half_width + frame_thickness * 0.5, side_y, 0.0),
		frame_color
	)
	_add_box(
		"TopFrame",
		Vector3(top_width, frame_thickness, frame_depth),
		Vector3(0.0, half_height + frame_thickness * 0.5, 0.0),
		frame_color
	)
	if show_bottom_frame:
		_add_box(
			"BottomFrame",
			Vector3(top_width, frame_thickness, frame_depth),
			Vector3(0.0, -half_height - frame_thickness * 0.5, 0.0),
			frame_color
		)
	_add_door_panels()
	_add_window_panes()


func _add_door_panels() -> void:
	if door_panel_count <= 0:
		return
	_add_split_panels("DoorPanel", "DoorPanel", door_panel_count, door_panel_depth, door_panel_color)


func _add_window_panes() -> void:
	if window_pane_count <= 0:
		return
	_add_split_panels("WindowPane", "WindowPane", window_pane_count, window_pane_depth, window_pane_color)


func _add_split_panels(
	single_name: String,
	double_suffix: String,
	panel_count: int,
	panel_depth: float,
	panel_color: Color
) -> void:
	var seam_gap := minf(0.035, opening_width * 0.08)
	if panel_count == 1:
		_add_box(
			single_name,
			Vector3(opening_width, opening_height, panel_depth),
			Vector3.ZERO,
			panel_color
		)
		return

	var panel_width := maxf((opening_width - seam_gap) * 0.5, 0.01)
	var offset_x := panel_width * 0.5 + seam_gap * 0.5
	_add_box(
		"Left%s" % double_suffix,
		Vector3(panel_width, opening_height, panel_depth),
		Vector3(-offset_x, 0.0, 0.0),
		panel_color
	)
	_add_box(
		"Right%s" % double_suffix,
		Vector3(panel_width, opening_height, panel_depth),
		Vector3(offset_x, 0.0, 0.0),
		panel_color
	)


func _add_box(part_name: String, size: Vector3, local_position: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size

	var instance := MeshInstance3D.new()
	instance.name = part_name
	instance.mesh = mesh
	instance.position = local_position
	instance.material_override = _build_material(color)
	instance.set_meta(GENERATED_META, true)
	add_child(instance)
	if Engine.is_editor_hint():
		instance.owner = null
	if generate_collision:
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
