@tool
class_name HumanBody3D
extends CharacterBody3D

signal global_position_changed()
signal configuration_changed(cfg: Dictionary)

const DEFAULT_WALK_SPEED := 4.0
const DEFAULT_RUN_SPEED := 7.5
const JUMP_DURATION := 0.55
const JUMP_HEIGHT := 0.48
const DEFAULT_BODY_HEIGHT := 1.72
const DEFAULT_BODY_RADIUS := 0.28
const BaseController3DScript = preload("res://characters/control/base_controller_3d.gd")

enum FacialMoodEnum {
	MANUAL = 0,
	NORMAL = 1,
	SMILE = 2,
	BLUSH = 3,
	ANGRY = 4,
	SAD = 5,
	SHAME = 6,
	SHOCK = 7,
}

enum FacialActionEnum {
	NONE = 0,
	BLINK = 1,
	ROLLING_EYES = 2,
}

@export var draw_bounding_box := false:
	set(value):
		if draw_bounding_box == value:
			return
		draw_bounding_box = value
		_sync_debug_box()

@export var direction: float = 90.0:
	set(value):
		if is_equal_approx(direction, value):
			return
		direction = value
		_update_state()

@export var is_walking := false:
	set(value):
		if is_walking == value:
			return
		is_walking = value
		_update_state()

@export var is_running := false:
	set(value):
		if is_running == value:
			return
		is_running = value
		_update_state()

@export var walk_speed := DEFAULT_WALK_SPEED
@export var run_speed := DEFAULT_RUN_SPEED

@export var facial_mood: FacialMoodEnum = FacialMoodEnum.NORMAL:
	set(value):
		if facial_mood == value:
			return
		facial_mood = value
		_update_face_marker()

@export var facial_action: FacialActionEnum = FacialActionEnum.NONE:
	set(value):
		if facial_action == value:
			return
		facial_action = value
		_update_face_marker()

@export var configuration: Dictionary:
	get:
		return get_configuration()
	set(value):
		set_configuration(value)

@export var controller: BaseController3DScript:
	set(value):
		if controller == value:
			return
		_teardown_controller()
		controller = value
		_setup_controller()

var m_cached_configuration: Dictionary = {}
var m_has_ready := false
var m_last_global_position := Vector3.ZERO
var m_is_currently_jumping := false
var m_jump_timer := 0.0
var m_current_animation_name := "idle-s"

var m_visual_root: Node3D = null
var m_body_part: MeshInstance3D = null
var m_head_part: MeshInstance3D = null
var m_hair_part: MeshInstance3D = null
var m_torso_part: MeshInstance3D = null
var m_left_leg_part: MeshInstance3D = null
var m_right_leg_part: MeshInstance3D = null
var m_left_shoe_part: MeshInstance3D = null
var m_right_shoe_part: MeshInstance3D = null
var m_face_marker_part: MeshInstance3D = null
var m_debug_box_part: MeshInstance3D = null
var m_collision_shape: CollisionShape3D = null

var m_skin_color := Color(0.86, 0.64, 0.48, 1.0)
var m_hair_color := Color(0.30, 0.18, 0.10, 1.0)
var m_shirt_color := Color(0.16, 0.54, 0.57, 1.0)
var m_pants_color := Color(0.18, 0.21, 0.23, 1.0)
var m_shoe_color := Color(0.32, 0.20, 0.12, 1.0)

const PALETTE := {
	"light": Color(0.86, 0.64, 0.48, 1.0),
	"tan": Color(0.70, 0.48, 0.32, 1.0),
	"brown": Color(0.38, 0.23, 0.14, 1.0),
	"chestnut": Color(0.37, 0.18, 0.08, 1.0),
	"blonde": Color(0.82, 0.65, 0.33, 1.0),
	"black": Color(0.06, 0.06, 0.06, 1.0),
	"charcoal": Color(0.16, 0.18, 0.20, 1.0),
	"teal": Color(0.10, 0.48, 0.50, 1.0),
	"leather": Color(0.39, 0.24, 0.13, 1.0),
	"blue": Color(0.19, 0.34, 0.68, 1.0),
	"green": Color(0.24, 0.48, 0.26, 1.0),
	"red": Color(0.66, 0.18, 0.16, 1.0),
	"white": Color(0.90, 0.88, 0.82, 1.0),
	"gray": Color(0.44, 0.45, 0.45, 1.0),
}


func _ready() -> void:
	_ensure_collision_shape()
	_ensure_visual_nodes()
	_apply_configuration_colors()
	_update_state()
	_update_face_marker()
	_sync_debug_box()
	m_has_ready = true
	m_last_global_position = global_position
	_setup_controller()


func _exit_tree() -> void:
	_teardown_controller()


func get_configuration() -> Dictionary:
	return m_cached_configuration.duplicate(true)


func set_configuration(new_configuration: Dictionary) -> void:
	if m_cached_configuration == new_configuration:
		return
	m_cached_configuration = new_configuration.duplicate(true)
	_apply_configuration_colors()
	configuration_changed.emit(get_configuration())


func move(direction_vector: Vector3) -> void:
	var movement_speed := run_speed if is_running else walk_speed
	move_with_speed(direction_vector, movement_speed)


func move_with_speed(direction_vector: Vector3, movement_speed: float) -> void:
	var flat_direction := Vector3(direction_vector.x, 0.0, direction_vector.z)
	if flat_direction.length_squared() > 0.000001:
		flat_direction = flat_direction.normalized()
	velocity.x = flat_direction.x * movement_speed
	velocity.z = flat_direction.z * movement_speed
	move_and_slide()


func jump() -> void:
	if m_is_currently_jumping:
		return
	m_is_currently_jumping = true
	m_jump_timer = 0.0
	_update_state()


func get_direction_vector() -> Vector3:
	var radians := deg_to_rad(direction)
	return Vector3(cos(radians), 0.0, sin(radians)).normalized()


func set_direction_vector(vector: Vector3) -> void:
	var flat_vector := Vector3(vector.x, 0.0, vector.z)
	if flat_vector.length_squared() <= 0.000001:
		return
	direction = rad_to_deg(atan2(flat_vector.z, flat_vector.x))


func get_flat_position() -> Vector2:
	return Vector2(global_position.x, global_position.z)


func set_flat_position(flat_position: Vector2) -> void:
	global_position.x = flat_position.x
	global_position.z = flat_position.y


func get_local_bounding_box() -> AABB:
	return AABB(
		Vector3(-DEFAULT_BODY_RADIUS, 0.0, -DEFAULT_BODY_RADIUS),
		Vector3(DEFAULT_BODY_RADIUS * 2.0, DEFAULT_BODY_HEIGHT, DEFAULT_BODY_RADIUS * 2.0)
	)


func get_bounding_box() -> AABB:
	var local_box := get_local_bounding_box()
	local_box.position += global_position
	return local_box


func get_local_ground_rect() -> Rect2:
	return Rect2(
		Vector2(-DEFAULT_BODY_RADIUS, -DEFAULT_BODY_RADIUS),
		Vector2(DEFAULT_BODY_RADIUS * 2.0, DEFAULT_BODY_RADIUS * 2.0)
	)


func get_ground_rect() -> Rect2:
	var rect := get_local_ground_rect()
	rect.position += get_flat_position()
	return rect


func get_current_animation_name() -> String:
	return m_current_animation_name


func _process(delta: float) -> void:
	_process_controller(delta)
	_process_jump(delta)
	if !m_last_global_position.is_equal_approx(global_position):
		m_last_global_position = global_position
		global_position_changed.emit()


func _setup_controller() -> void:
	if !is_inside_tree():
		return
	if controller == null:
		return
	controller.setup(self)


func _teardown_controller() -> void:
	if controller == null:
		return
	controller.teardown()


func _process_controller(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if controller == null:
		return
	controller.process(delta)


func _process_jump(delta: float) -> void:
	if !m_is_currently_jumping:
		return

	m_jump_timer += delta
	if m_jump_timer >= JUMP_DURATION:
		m_jump_timer = 0.0
		m_is_currently_jumping = false
		_update_state()
		return

	_apply_visual_offset()


func _update_state() -> void:
	_sync_visual_rotation()
	_apply_visual_offset()

	var base_animation_name := "walk"
	if !is_walking:
		base_animation_name = "idle"
	elif is_running:
		base_animation_name = "run"

	if m_is_currently_jumping:
		base_animation_name = "jump"

	m_current_animation_name = "%s-%s" % [base_animation_name, _get_direction_suffix()]


func _get_direction_suffix() -> String:
	var normalized_direction := fposmod(direction, 360.0)
	if normalized_direction <= 45.01 or normalized_direction >= 314.09:
		return "e"
	if normalized_direction >= 135.0 and normalized_direction <= 225.0:
		return "w"
	if normalized_direction >= 45.0 and normalized_direction <= 135.0:
		return "s"
	return "n"


func _apply_visual_offset() -> void:
	if !is_instance_valid(m_visual_root):
		return
	var jump_y := 0.0
	if m_is_currently_jumping:
		var t := clampf(m_jump_timer / JUMP_DURATION, 0.0, 1.0)
		var parabola := 1.0 - pow(2.0 * t - 1.0, 2.0)
		jump_y = JUMP_HEIGHT * parabola
	m_visual_root.position = Vector3(0.0, jump_y, 0.0)


func _sync_visual_rotation() -> void:
	if !is_instance_valid(m_visual_root):
		return
	m_visual_root.rotation.y = (PI * 0.5) - deg_to_rad(direction)


func _ensure_collision_shape() -> void:
	m_collision_shape = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if m_collision_shape == null:
		m_collision_shape = CollisionShape3D.new()
		m_collision_shape.name = "CollisionShape3D"
		add_child(m_collision_shape)
		if Engine.is_editor_hint():
			m_collision_shape.owner = null

	var capsule := m_collision_shape.shape as CapsuleShape3D
	if capsule == null:
		capsule = CapsuleShape3D.new()
		m_collision_shape.shape = capsule
	capsule.radius = DEFAULT_BODY_RADIUS
	capsule.height = DEFAULT_BODY_HEIGHT
	m_collision_shape.position = Vector3(0.0, DEFAULT_BODY_HEIGHT * 0.5, 0.0)


func _ensure_visual_nodes() -> void:
	m_visual_root = get_node_or_null("VisualRoot") as Node3D
	if m_visual_root == null:
		m_visual_root = Node3D.new()
		m_visual_root.name = "VisualRoot"
		add_child(m_visual_root)
		if Engine.is_editor_hint():
			m_visual_root.owner = null

	m_body_part = _ensure_box_part("Body", Vector3(0.46, 0.58, 0.30), Vector3(0.0, 0.92, 0.0))
	m_torso_part = _ensure_box_part("Torso", Vector3(0.52, 0.42, 0.34), Vector3(0.0, 1.02, 0.0))
	m_head_part = _ensure_box_part("Head", Vector3(0.34, 0.34, 0.32), Vector3(0.0, 1.48, 0.0))
	m_hair_part = _ensure_box_part("Hair", Vector3(0.37, 0.15, 0.34), Vector3(0.0, 1.67, -0.01))
	m_left_leg_part = _ensure_box_part("LeftLeg", Vector3(0.18, 0.54, 0.20), Vector3(-0.13, 0.41, 0.0))
	m_right_leg_part = _ensure_box_part("RightLeg", Vector3(0.18, 0.54, 0.20), Vector3(0.13, 0.41, 0.0))
	m_left_shoe_part = _ensure_box_part("LeftShoe", Vector3(0.22, 0.12, 0.28), Vector3(-0.13, 0.08, 0.04))
	m_right_shoe_part = _ensure_box_part("RightShoe", Vector3(0.22, 0.12, 0.28), Vector3(0.13, 0.08, 0.04))
	m_face_marker_part = _ensure_box_part("FaceMarker", Vector3(0.16, 0.055, 0.035), Vector3(0.0, 1.49, 0.175))
	m_debug_box_part = _ensure_box_part("DebugBox", Vector3(DEFAULT_BODY_RADIUS * 2.0, DEFAULT_BODY_HEIGHT, DEFAULT_BODY_RADIUS * 2.0), Vector3(0.0, DEFAULT_BODY_HEIGHT * 0.5, 0.0))


func _ensure_box_part(part_name: String, size: Vector3, local_position: Vector3) -> MeshInstance3D:
	var parent := m_visual_root if is_instance_valid(m_visual_root) else self
	var part := parent.get_node_or_null(part_name) as MeshInstance3D
	if part == null:
		part = MeshInstance3D.new()
		part.name = part_name
		parent.add_child(part)
		if Engine.is_editor_hint():
			part.owner = null

	var box_mesh := part.mesh as BoxMesh
	if box_mesh == null:
		box_mesh = BoxMesh.new()
		part.mesh = box_mesh
	box_mesh.size = size
	part.position = local_position
	return part


func _apply_configuration_colors() -> void:
	var selections: Dictionary = m_cached_configuration.get("selections", {})
	if typeof(selections) == TYPE_DICTIONARY:
		m_skin_color = _resolve_selection_color(selections, ["body/body", "head/heads"], m_skin_color)
		m_hair_color = _resolve_selection_color(selections, ["hair/"], m_hair_color)
		m_shirt_color = _resolve_selection_color(selections, ["torso/"], m_shirt_color)
		m_pants_color = _resolve_selection_color(selections, ["legs/"], m_pants_color)
		m_shoe_color = _resolve_selection_color(selections, ["feet/", "shoes"], m_shoe_color)

	_apply_material(m_body_part, m_skin_color)
	_apply_material(m_head_part, m_skin_color)
	_apply_material(m_hair_part, m_hair_color)
	_apply_material(m_torso_part, m_shirt_color)
	_apply_material(m_left_leg_part, m_pants_color)
	_apply_material(m_right_leg_part, m_pants_color)
	_apply_material(m_left_shoe_part, m_shoe_color)
	_apply_material(m_right_shoe_part, m_shoe_color)
	_update_face_marker()
	_sync_debug_box()


func _resolve_selection_color(selections: Dictionary, key_fragments: Array[String], fallback: Color) -> Color:
	for key_value in selections.keys():
		var key := String(key_value)
		for fragment in key_fragments:
			if key.find(fragment) < 0:
				continue
			return _color_for_variant(String(selections[key_value]), fallback)
	return fallback


func _color_for_variant(variant: String, fallback: Color) -> Color:
	var normalized_variant := variant.to_lower().replace("_", "").replace("-", "").replace(" ", "")
	for key in PALETTE.keys():
		var normalized_key := String(key).to_lower().replace("_", "").replace("-", "").replace(" ", "")
		if normalized_variant == normalized_key:
			return PALETTE[key]
	return fallback


func _update_face_marker() -> void:
	if !is_instance_valid(m_face_marker_part):
		return

	var face_color := Color(0.08, 0.07, 0.06, 1.0)
	match int(facial_mood):
		int(FacialMoodEnum.SMILE):
			face_color = Color(0.18, 0.10, 0.05, 1.0)
		int(FacialMoodEnum.BLUSH):
			face_color = Color(0.85, 0.34, 0.42, 1.0)
		int(FacialMoodEnum.ANGRY):
			face_color = Color(0.58, 0.08, 0.06, 1.0)
		int(FacialMoodEnum.SAD):
			face_color = Color(0.13, 0.25, 0.58, 1.0)
		int(FacialMoodEnum.SHOCK):
			face_color = Color(0.95, 0.78, 0.18, 1.0)
		_:
			face_color = Color(0.08, 0.07, 0.06, 1.0)

	m_face_marker_part.visible = facial_action != FacialActionEnum.BLINK
	_apply_material(m_face_marker_part, face_color)


func _sync_debug_box() -> void:
	if !is_instance_valid(m_debug_box_part):
		return
	m_debug_box_part.visible = draw_bounding_box
	var debug_color := Color(0.2, 0.75, 1.0, 0.18)
	_apply_material(m_debug_box_part, debug_color, true)


func _apply_material(part: MeshInstance3D, color: Color, transparent: bool = false) -> void:
	if !is_instance_valid(part):
		return

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	if transparent or color.a < 0.99:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	part.material_override = material
