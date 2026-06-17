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
const STEP_FLOOR_PROBE_MARGIN := 0.08
const STEP_FLOOR_SIDE_PROBE_SCALE := 0.72
const STEP_FLOOR_FORWARD_FAR_SCALE := 2.0
const STEP_FLOOR_CAST_MARGIN := 0.16
const MIN_STEP_FLOOR_ADJUSTMENT := 0.002
const MIN_STEP_BLOCKED_PROGRESS_RATIO := 0.35
const MAX_STEP_LATERAL_DRIFT_RATIO := 0.1
const PLACEMENT_QUERY_FLOOR_CLEARANCE := 0.01
const FLOOR_SAMPLE_MISSING := -INF
const BaseController3DScript = preload("res://characters/control/base_controller_3d.gd")
const ProceduralLowPolyCharacterRigScript = preload("res://characters/procedural_low_poly_character_rig.gd")
const CharacterModelScene: PackedScene = preload("res://assets/characters/3d_cartoon_boy_figure.glb")
const DEFAULT_CHARACTER_MODEL_HEIGHT := 0.998

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

@export_range(0.8, 3.0, 0.01) var body_height := DEFAULT_BODY_HEIGHT:
	set(value):
		var clamped_height := maxf(value, 0.8)
		if is_equal_approx(body_height, clamped_height):
			return
		body_height = clamped_height
		_sync_body_profile()

@export_range(0.12, 1.0, 0.01) var body_radius := DEFAULT_BODY_RADIUS:
	set(value):
		var clamped_radius := maxf(value, 0.12)
		if is_equal_approx(body_radius, clamped_radius):
			return
		body_radius = clamped_radius
		_sync_body_profile()

@export_group("Movement Polish")
@export_range(0.0, 0.2, 0.005) var walk_bob_height := 0.035
@export_range(0.0, 0.28, 0.005) var run_bob_height := 0.065
@export_range(0.1, 10.0, 0.1) var walk_animation_cadence := 3.2
@export_range(0.1, 12.0, 0.1) var run_animation_cadence := 5.2
@export_range(0.0, 35.0, 0.5) var leg_swing_degrees := 13.0
@export var contact_shadow_enabled := true:
	set(value):
		if contact_shadow_enabled == value:
			return
		contact_shadow_enabled = value
		_sync_contact_shadow()
@export_range(0.0, 1.5, 0.01) var contact_shadow_radius := 0.38:
	set(value):
		contact_shadow_radius = maxf(value, 0.0)
		_sync_contact_shadow()

@export_group("3D Navigation")
@export_range(0.0, 1.0, 0.01) var max_step_height := 0.72
@export_range(0.0, 2.0, 0.01) var floor_snap_distance := 0.72:
	set(value):
		floor_snap_distance = maxf(value, 0.0)
		floor_snap_length = floor_snap_distance
@export_range(0.0, 5.0, 0.05) var grounding_speed := 1.6

@export_group("Procedural Low Poly")
@export var use_procedural_rig := false:
	set(value):
		if use_procedural_rig == value:
			return
		use_procedural_rig = value
		_sync_procedural_rig()

@export var procedural_seed := "kulangsu_player":
	set(value):
		var normalized_seed := value
		if normalized_seed.is_empty():
			normalized_seed = "kulangsu_player"
		if procedural_seed == normalized_seed:
			return
		procedural_seed = normalized_seed
		_sync_procedural_rig()

@export_group("Character Model")
@export var use_character_model := true:
	set(value):
		if use_character_model == value:
			return
		use_character_model = value
		_sync_character_model()
		_sync_procedural_rig()

@export var character_model_scene: PackedScene = CharacterModelScene:
	set(value):
		if character_model_scene == value:
			return
		character_model_scene = value
		_rebuild_character_model()

@export_range(0.1, 4.0, 0.001) var character_model_height := DEFAULT_CHARACTER_MODEL_HEIGHT:
	set(value):
		character_model_height = maxf(value, 0.1)
		_sync_character_model()

# The GLB faces along the X axis in its own space; -90° about Y turns it to the rig's +Z forward.
@export_range(-180.0, 180.0, 1.0) var character_model_yaw_offset := -90.0:
	set(value):
		character_model_yaw_offset = value
		_sync_character_model()

# Auto-plant the model's lowest point at the foot origin; this nudge lifts/lowers it further.
@export var character_model_auto_ground := true:
	set(value):
		character_model_auto_ground = value
		_sync_character_model()

@export_range(-0.5, 0.5, 0.001) var character_model_y_offset := 0.0:
	set(value):
		character_model_y_offset = value
		_sync_character_model()

@export var model_idle_animation := "idle"
@export var model_walk_animation := "walk"
@export var model_run_animation := "run"

@export_group("Face")
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
var m_motion_phase := 0.0
var m_last_step_direction := Vector3.ZERO
var m_step_snap_grounded := false

var m_visual_root: Node3D = null
var m_body_part: MeshInstance3D = null
var m_head_part: MeshInstance3D = null
var m_hair_part: MeshInstance3D = null
var m_torso_part: MeshInstance3D = null
var m_left_arm_part: MeshInstance3D = null
var m_right_arm_part: MeshInstance3D = null
var m_left_leg_part: MeshInstance3D = null
var m_right_leg_part: MeshInstance3D = null
var m_left_shoe_part: MeshInstance3D = null
var m_right_shoe_part: MeshInstance3D = null
var m_face_marker_part: MeshInstance3D = null
var m_direction_marker_part: MeshInstance3D = null
var m_contact_shadow_part: MeshInstance3D = null
var m_debug_box_part: MeshInstance3D = null
var m_collision_shape: CollisionShape3D = null
var m_procedural_rig: Node3D = null
var m_character_model: Node3D = null
var m_model_animation_player: AnimationPlayer = null

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
	floor_snap_length = floor_snap_distance
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
	var grounded_before_move := is_grounded()
	if grounded_before_move and !m_is_currently_jumping:
		velocity.y = -grounding_speed
	var can_reacquire_floor := !m_is_currently_jumping and (grounded_before_move or velocity.y <= 0.0)
	var start_position := global_position
	var horizontal_motion := Vector3(velocity.x, 0.0, velocity.z) * get_physics_process_delta_time()
	var step_direction := Vector3.ZERO
	if horizontal_motion.length_squared() > 0.000001:
		step_direction = horizontal_motion.normalized()
		m_last_step_direction = step_direction
	elif velocity.y < -MIN_STEP_FLOOR_ADJUSTMENT and m_last_step_direction.length_squared() > 0.000001:
		step_direction = m_last_step_direction
	move_and_slide()
	m_step_snap_grounded = is_on_floor()
	if can_reacquire_floor and step_direction.length_squared() > 0.000001:
		if _snap_to_walkable_step_floor(start_position, horizontal_motion, step_direction):
			m_step_snap_grounded = true


func _snap_to_walkable_step_floor(
	start_position: Vector3,
	horizontal_motion: Vector3,
	horizontal_direction: Vector3
) -> bool:
	if max_step_height <= 0.0 and floor_snap_distance <= 0.0:
		return false

	horizontal_direction = Vector3(horizontal_direction.x, 0.0, horizontal_direction.z)
	if horizontal_direction.length_squared() <= 0.000001:
		return false
	horizontal_direction = horizontal_direction.normalized()

	var reference_y := maxf(start_position.y, global_position.y)
	var snap_position := global_position
	var floor_y := _find_walkable_step_floor_y(snap_position, horizontal_direction, reference_y)
	var requested_distance := horizontal_motion.length()
	var actual_motion := Vector3(
		global_position.x - start_position.x,
		0.0,
		global_position.z - start_position.z
	)
	var actual_forward_distance := actual_motion.dot(horizontal_direction)
	var actual_lateral_motion := actual_motion - (horizontal_direction * actual_forward_distance)
	var target_position_blocked := false
	var target_position := Vector3(
		start_position.x + horizontal_motion.x,
		global_position.y,
		start_position.z + horizontal_motion.z
	)
	var target_floor_y := NAN
	if requested_distance > 0.0:
		target_floor_y = _find_walkable_step_floor_y(target_position, horizontal_direction, reference_y)

	if !is_nan(target_floor_y):
		var should_use_target_position := is_nan(floor_y)
		should_use_target_position = should_use_target_position or absf(target_floor_y - floor_y) > MIN_STEP_FLOOR_ADJUSTMENT
		should_use_target_position = should_use_target_position or actual_forward_distance < requested_distance * MIN_STEP_BLOCKED_PROGRESS_RATIO
		should_use_target_position = should_use_target_position or actual_lateral_motion.length() > requested_distance * MAX_STEP_LATERAL_DRIFT_RATIO
		if should_use_target_position:
			var target_floor_delta_from_start := target_floor_y - start_position.y
			if (
				target_floor_delta_from_start <= max_step_height + MIN_STEP_FLOOR_ADJUSTMENT
				and target_floor_delta_from_start >= -(floor_snap_distance + MIN_STEP_FLOOR_ADJUSTMENT)
			):
				var target_snap_position := Vector3(target_position.x, target_floor_y, target_position.z)
				if _can_place_body_at(target_snap_position):
					snap_position = target_snap_position
					floor_y = target_floor_y
				else:
					target_position_blocked = true

	if is_nan(floor_y) and requested_distance > 0.0 and actual_forward_distance < requested_distance * MIN_STEP_BLOCKED_PROGRESS_RATIO:
		target_floor_y = _find_walkable_step_floor_y(target_position, horizontal_direction, reference_y)
		if !is_nan(target_floor_y):
			var target_snap_position := Vector3(target_position.x, target_floor_y, target_position.z)
			if _can_place_body_at(target_snap_position):
				snap_position = target_snap_position
				floor_y = target_floor_y
			else:
				target_position_blocked = true

	if target_position_blocked and actual_forward_distance < requested_distance * MIN_STEP_BLOCKED_PROGRESS_RATIO:
		return false

	if is_nan(floor_y):
		var start_floor_y := _find_walkable_step_floor_y(start_position, horizontal_direction, reference_y)
		if !is_nan(start_floor_y):
			var would_drop_to_older_floor := (
				requested_distance > MIN_STEP_FLOOR_ADJUSTMENT
				and actual_forward_distance >= requested_distance * MIN_STEP_BLOCKED_PROGRESS_RATIO
				and start_floor_y < start_position.y - MIN_STEP_FLOOR_ADJUSTMENT
			)
			if !would_drop_to_older_floor:
				var start_snap_position := Vector3(start_position.x, start_floor_y, start_position.z)
				if _can_place_body_at(start_snap_position):
					global_position = start_snap_position
					velocity.x = 0.0
					velocity.z = 0.0
					velocity.y = minf(velocity.y, 0.0)
					_refresh_floor_state_after_manual_snap()
					return true
		return false

	var floor_delta_from_start := floor_y - start_position.y
	if floor_delta_from_start > max_step_height + MIN_STEP_FLOOR_ADJUSTMENT:
		return false
	if floor_delta_from_start < -(floor_snap_distance + MIN_STEP_FLOOR_ADJUSTMENT):
		return false

	var vertical_adjustment := floor_y - global_position.y
	var horizontal_adjustment := Vector3(
		snap_position.x - global_position.x,
		0.0,
		snap_position.z - global_position.z
	)
	if (
		absf(vertical_adjustment) <= MIN_STEP_FLOOR_ADJUSTMENT
		and horizontal_adjustment.length_squared() <= 0.000001
	):
		return false

	var final_snap_position := Vector3(snap_position.x, floor_y, snap_position.z)
	if !_can_place_body_at(final_snap_position):
		return false

	global_position = final_snap_position
	if vertical_adjustment > 0.0:
		velocity.y = 0.0
	else:
		velocity.y = minf(velocity.y, 0.0)
	_refresh_floor_state_after_manual_snap()
	return true


func _refresh_floor_state_after_manual_snap() -> void:
	if floor_snap_length <= 0.0 or m_is_currently_jumping:
		return
	apply_floor_snap()


func _find_walkable_step_floor_y(
	body_position: Vector3,
	horizontal_direction: Vector3,
	reference_y: float
) -> float:
	var side_direction := Vector3(-horizontal_direction.z, 0.0, horizontal_direction.x)
	var forward_reach := body_radius + STEP_FLOOR_PROBE_MARGIN
	var side_reach := body_radius * STEP_FLOOR_SIDE_PROBE_SCALE
	var cast_top_y := reference_y + max_step_height + STEP_FLOOR_CAST_MARGIN
	var cast_bottom_y := reference_y - floor_snap_distance - STEP_FLOOR_CAST_MARGIN
	var min_floor_normal_y := cos(floor_max_angle)

	var center_floor_y := _sample_walkable_floor_y(
		body_position,
		cast_top_y,
		cast_bottom_y,
		min_floor_normal_y
	)
	var side_floor_y := maxf(
		_sample_walkable_floor_y(
			body_position + (side_direction * side_reach),
			cast_top_y,
			cast_bottom_y,
			min_floor_normal_y
		),
		_sample_walkable_floor_y(
			body_position - (side_direction * side_reach),
			cast_top_y,
			cast_bottom_y,
			min_floor_normal_y
		)
	)

	var body_support_y := maxf(center_floor_y, side_floor_y)
	var forward_near_floor_y := _sample_walkable_floor_y(
		body_position + (horizontal_direction * forward_reach),
		cast_top_y,
		cast_bottom_y,
		min_floor_normal_y
	)
	var forward_far_floor_y := _sample_walkable_floor_y(
		body_position + (horizontal_direction * forward_reach * STEP_FLOOR_FORWARD_FAR_SCALE),
		cast_top_y,
		cast_bottom_y,
		min_floor_normal_y
	)
	var forward_floor_y := _resolve_forward_step_floor_y(
		forward_near_floor_y,
		forward_far_floor_y,
		body_support_y
	)
	if body_support_y == FLOOR_SAMPLE_MISSING:
		if forward_floor_y == FLOOR_SAMPLE_MISSING:
			return NAN
		return forward_floor_y

	if forward_floor_y > body_support_y + MIN_STEP_FLOOR_ADJUSTMENT:
		return forward_floor_y

	if center_floor_y < body_support_y - MIN_STEP_FLOOR_ADJUSTMENT:
		if forward_floor_y < body_support_y - MIN_STEP_FLOOR_ADJUSTMENT:
			return center_floor_y
		return body_support_y

	return body_support_y


func _sample_walkable_floor_y(
	sample_position: Vector3,
	cast_top_y: float,
	cast_bottom_y: float,
	min_floor_normal_y: float
) -> float:
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(sample_position.x, cast_top_y, sample_position.z),
		Vector3(sample_position.x, cast_bottom_y, sample_position.z)
	)
	query.exclude = [get_rid()]
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return FLOOR_SAMPLE_MISSING

	var hit_normal: Vector3 = hit.get("normal", Vector3.ZERO)
	if hit_normal.y < min_floor_normal_y:
		return FLOOR_SAMPLE_MISSING

	var hit_position: Vector3 = hit.get("position", Vector3.ZERO)
	return hit_position.y


func _resolve_forward_step_floor_y(near_floor_y: float, far_floor_y: float, body_support_y: float) -> float:
	if near_floor_y == FLOOR_SAMPLE_MISSING:
		return far_floor_y
	if far_floor_y == FLOOR_SAMPLE_MISSING:
		return near_floor_y
	if body_support_y == FLOOR_SAMPLE_MISSING:
		return maxf(near_floor_y, far_floor_y)

	if near_floor_y > body_support_y + MIN_STEP_FLOOR_ADJUSTMENT:
		return near_floor_y
	if far_floor_y < body_support_y - MIN_STEP_FLOOR_ADJUSTMENT:
		return far_floor_y
	if near_floor_y < body_support_y - MIN_STEP_FLOOR_ADJUSTMENT:
		return far_floor_y
	return maxf(near_floor_y, far_floor_y)


func _can_place_body_at(candidate_position: Vector3) -> bool:
	var candidate_transform := global_transform
	candidate_transform.origin = candidate_position
	if !is_inside_tree():
		return !test_move(candidate_transform, Vector3.ZERO)
	if !is_instance_valid(m_collision_shape):
		return !test_move(candidate_transform, Vector3.ZERO)
	if m_collision_shape.disabled or m_collision_shape.shape == null:
		return !test_move(candidate_transform, Vector3.ZERO)

	var world := get_world_3d()
	if world == null:
		return !test_move(candidate_transform, Vector3.ZERO)

	candidate_transform.origin.y += PLACEMENT_QUERY_FLOOR_CLEARANCE
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = m_collision_shape.shape
	query.transform = candidate_transform * m_collision_shape.transform
	query.collision_mask = collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [get_rid()]

	var overlaps: Array[Dictionary] = world.direct_space_state.intersect_shape(query, 1)
	return overlaps.is_empty()


func jump() -> void:
	if m_is_currently_jumping:
		return
	m_is_currently_jumping = true
	m_step_snap_grounded = false
	m_jump_timer = 0.0
	_update_state()


func is_grounded() -> bool:
	return !m_is_currently_jumping and (is_on_floor() or m_step_snap_grounded)


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
		Vector3(-body_radius, 0.0, -body_radius),
		Vector3(body_radius * 2.0, body_height, body_radius * 2.0)
	)


func get_bounding_box() -> AABB:
	var local_box := get_local_bounding_box()
	local_box.position += global_position
	return local_box


func get_local_ground_rect() -> Rect2:
	return Rect2(
		Vector2(-body_radius, -body_radius),
		Vector2(body_radius * 2.0, body_radius * 2.0)
	)


func get_ground_rect() -> Rect2:
	var rect := get_local_ground_rect()
	rect.position += get_flat_position()
	return rect


func get_current_animation_name() -> String:
	return m_current_animation_name


func _process(delta: float) -> void:
	_process_jump(delta)
	_process_visual_motion(delta)
	if !m_last_global_position.is_equal_approx(global_position):
		m_last_global_position = global_position
		global_position_changed.emit()


func _physics_process(delta: float) -> void:
	_process_controller(delta)


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
	_sync_model_animation()


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
	m_visual_root.position = Vector3(0.0, jump_y + _get_motion_bob_y(), 0.0)


func _process_visual_motion(delta: float) -> void:
	if is_walking:
		var cadence := run_animation_cadence if is_running else walk_animation_cadence
		m_motion_phase = fposmod(m_motion_phase + delta * TAU * cadence, TAU)
	else:
		m_motion_phase = 0.0

	_apply_visual_offset()
	_sync_limb_motion()
	if use_procedural_rig and is_instance_valid(m_procedural_rig) and m_procedural_rig.has_method("process_motion"):
		m_procedural_rig.call("process_motion", delta, is_walking, is_running, m_is_currently_jumping)


func _get_motion_bob_y() -> float:
	if !is_walking:
		return 0.0
	var bob_height := run_bob_height if is_running else walk_bob_height
	return (sin((m_motion_phase * 2.0) - (PI * 0.5)) + 1.0) * 0.5 * bob_height


func _sync_limb_motion() -> void:
	var swing := 0.0
	if is_walking:
		swing = sin(m_motion_phase) * deg_to_rad(leg_swing_degrees)

	_set_part_rotation_x(m_left_leg_part, swing)
	_set_part_rotation_x(m_right_leg_part, -swing)
	_set_part_rotation_x(m_left_shoe_part, swing * 0.65)
	_set_part_rotation_x(m_right_shoe_part, -swing * 0.65)
	_set_part_rotation_x(m_left_arm_part, -swing * 0.55)
	_set_part_rotation_x(m_right_arm_part, swing * 0.55)


func _set_part_rotation_x(part: MeshInstance3D, rotation_x: float) -> void:
	if !is_instance_valid(part):
		return
	part.rotation.x = rotation_x


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
	_sync_collision_shape()


func _ensure_visual_nodes() -> void:
	m_visual_root = get_node_or_null("VisualRoot") as Node3D
	if m_visual_root == null:
		m_visual_root = Node3D.new()
		m_visual_root.name = "VisualRoot"
		add_child(m_visual_root)
		if Engine.is_editor_hint():
			m_visual_root.owner = null

	m_contact_shadow_part = _ensure_contact_shadow_part()
	m_body_part = _ensure_box_part("Body", Vector3(0.46, 0.58, 0.30), Vector3(0.0, 0.92, 0.0))
	m_torso_part = _ensure_box_part("Torso", Vector3(0.52, 0.42, 0.34), Vector3(0.0, 1.02, 0.0))
	m_head_part = _ensure_box_part("Head", Vector3(0.34, 0.34, 0.32), Vector3(0.0, 1.48, 0.0))
	m_hair_part = _ensure_box_part("Hair", Vector3(0.37, 0.15, 0.34), Vector3(0.0, 1.67, -0.01))
	m_left_arm_part = _ensure_box_part("LeftArm", Vector3(0.14, 0.50, 0.18), Vector3(-0.39, 0.92, 0.0))
	m_right_arm_part = _ensure_box_part("RightArm", Vector3(0.14, 0.50, 0.18), Vector3(0.39, 0.92, 0.0))
	m_left_leg_part = _ensure_box_part("LeftLeg", Vector3(0.18, 0.54, 0.20), Vector3(-0.13, 0.41, 0.0))
	m_right_leg_part = _ensure_box_part("RightLeg", Vector3(0.18, 0.54, 0.20), Vector3(0.13, 0.41, 0.0))
	m_left_shoe_part = _ensure_box_part("LeftShoe", Vector3(0.22, 0.12, 0.28), Vector3(-0.13, 0.08, 0.04))
	m_right_shoe_part = _ensure_box_part("RightShoe", Vector3(0.22, 0.12, 0.28), Vector3(0.13, 0.08, 0.04))
	m_face_marker_part = _ensure_box_part("FaceMarker", Vector3(0.20, 0.065, 0.04), Vector3(0.0, 1.49, 0.175))
	m_direction_marker_part = _ensure_box_part("DirectionMarker", Vector3(0.065, 0.16, 0.045), Vector3(0.0, 1.38, 0.178))
	m_debug_box_part = _ensure_box_part("DebugBox", Vector3(body_radius * 2.0, body_height, body_radius * 2.0), Vector3(0.0, body_height * 0.5, 0.0))
	m_procedural_rig = _ensure_procedural_rig()
	_sync_body_profile()


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


func _ensure_procedural_rig() -> Node3D:
	var parent := m_visual_root if is_instance_valid(m_visual_root) else self
	var rig := parent.get_node_or_null("ProceduralLowPolyCharacterRig") as Node3D
	if rig == null:
		rig = ProceduralLowPolyCharacterRigScript.new()
		rig.name = "ProceduralLowPolyCharacterRig"
		parent.add_child(rig)
		if Engine.is_editor_hint():
			rig.owner = null
	return rig


func _ensure_character_model() -> Node3D:
	var parent := m_visual_root if is_instance_valid(m_visual_root) else self
	var model := parent.get_node_or_null("CharacterModel") as Node3D
	if model == null:
		model = Node3D.new()
		model.name = "CharacterModel"
		parent.add_child(model)
		if Engine.is_editor_hint():
			model.owner = null
	if model.get_child_count() == 0 and character_model_scene != null:
		var instance := character_model_scene.instantiate()
		model.add_child(instance)
		if Engine.is_editor_hint():
			instance.owner = null
	return model


func _rebuild_character_model() -> void:
	if is_instance_valid(m_character_model):
		m_character_model.queue_free()
		m_character_model = null
	if is_inside_tree():
		_sync_character_model()


func _sync_character_model() -> void:
	if not use_character_model:
		if is_instance_valid(m_character_model):
			m_character_model.visible = false
		_sync_legacy_visual_visibility()
		return
	if not is_instance_valid(m_character_model):
		if not is_instance_valid(m_visual_root):
			return
		m_character_model = _ensure_character_model()
	if not is_instance_valid(m_character_model):
		return
	m_character_model.visible = true
	var scale_factor := body_height / maxf(character_model_height, 0.01)
	m_character_model.scale = Vector3.ONE * scale_factor
	m_character_model.rotation.y = deg_to_rad(character_model_yaw_offset)
	m_character_model.position = Vector3.ZERO
	_align_model_feet()
	if not is_instance_valid(m_model_animation_player):
		m_model_animation_player = _find_animation_player(m_character_model)
	if is_instance_valid(m_procedural_rig):
		m_procedural_rig.visible = false
	_sync_legacy_visual_visibility()
	_sync_model_animation()


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _collect_mesh_instances(node: Node, into: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		into.append(node)
	for child in node.get_children():
		_collect_mesh_instances(child, into)


# Plant the model so its lowest rendered point sits at the foot origin (+ manual nudge).
func _align_model_feet() -> void:
	if not is_instance_valid(m_character_model):
		return
	if not character_model_auto_ground:
		m_character_model.position.y = character_model_y_offset
		return
	if not is_inside_tree() or not is_instance_valid(m_visual_root):
		return
	var meshes: Array[MeshInstance3D] = []
	_collect_mesh_instances(m_character_model, meshes)
	if meshes.is_empty():
		m_character_model.position.y = character_model_y_offset
		return
	var inv_root := m_visual_root.global_transform.affine_inverse()
	var lowest := INF
	for mesh_instance in meshes:
		var aabb := mesh_instance.get_aabb()
		var to_root := inv_root * mesh_instance.global_transform
		for i in range(8):
			var corner := aabb.position + Vector3(
				aabb.size.x * float(i & 1),
				aabb.size.y * float((i >> 1) & 1),
				aabb.size.z * float((i >> 2) & 1))
			lowest = minf(lowest, (to_root * corner).y)
	if lowest == INF:
		lowest = 0.0
	m_character_model.position.y = character_model_y_offset - lowest


func _sync_model_animation() -> void:
	if not use_character_model:
		return
	if not is_instance_valid(m_model_animation_player):
		return
	var target := _match_model_animation(_desired_model_animation())
	if target.is_empty():
		return
	var animation := m_model_animation_player.get_animation(target)
	if animation != null and animation.loop_mode == Animation.LOOP_NONE:
		animation.loop_mode = Animation.LOOP_LINEAR
	if m_model_animation_player.current_animation != target:
		m_model_animation_player.play(target, 0.15)


func _desired_model_animation() -> String:
	if is_walking and is_running:
		return model_run_animation
	if is_walking:
		return model_walk_animation
	return model_idle_animation


func _match_model_animation(animation_name: String) -> String:
	if animation_name.is_empty() or not is_instance_valid(m_model_animation_player):
		return ""
	if m_model_animation_player.has_animation(animation_name):
		return animation_name
	var lowered := animation_name.to_lower()
	for entry in m_model_animation_player.get_animation_list():
		var candidate := String(entry)
		var candidate_lower := candidate.to_lower()
		if candidate_lower == lowered or candidate_lower.ends_with("/" + lowered):
			return candidate
	return ""


func _ensure_contact_shadow_part() -> MeshInstance3D:
	var part := get_node_or_null("ContactShadow") as MeshInstance3D
	if part == null:
		part = MeshInstance3D.new()
		part.name = "ContactShadow"
		add_child(part)
		move_child(part, 0)
		if Engine.is_editor_hint():
			part.owner = null

	var cylinder_mesh := part.mesh as CylinderMesh
	if cylinder_mesh == null:
		cylinder_mesh = CylinderMesh.new()
		part.mesh = cylinder_mesh
	cylinder_mesh.radial_segments = 16
	cylinder_mesh.rings = 1
	_sync_contact_shadow()
	return part


func _sync_body_profile() -> void:
	_sync_collision_shape()
	_sync_visual_profile()
	_sync_debug_box()
	_sync_contact_shadow()
	_sync_procedural_rig()
	_sync_character_model()


func _sync_collision_shape() -> void:
	if !is_instance_valid(m_collision_shape):
		return
	var capsule := m_collision_shape.shape as CapsuleShape3D
	if capsule == null:
		return
	capsule.radius = body_radius
	capsule.height = body_height
	m_collision_shape.position = Vector3(0.0, body_height * 0.5, 0.0)


func _sync_visual_profile() -> void:
	if !is_instance_valid(m_visual_root):
		return

	_sync_box_part(m_body_part, Vector3(0.46, 0.58, 0.30), Vector3(0.0, 0.92, 0.0))
	_sync_box_part(m_torso_part, Vector3(0.52, 0.42, 0.34), Vector3(0.0, 1.02, 0.0))
	_sync_box_part(m_head_part, Vector3(0.34, 0.34, 0.32), Vector3(0.0, 1.48, 0.0))
	_sync_box_part(m_hair_part, Vector3(0.37, 0.15, 0.34), Vector3(0.0, 1.67, -0.01))
	_sync_box_part(m_left_arm_part, Vector3(0.14, 0.50, 0.18), Vector3(-0.39, 0.92, 0.0))
	_sync_box_part(m_right_arm_part, Vector3(0.14, 0.50, 0.18), Vector3(0.39, 0.92, 0.0))
	_sync_box_part(m_left_leg_part, Vector3(0.18, 0.54, 0.20), Vector3(-0.13, 0.41, 0.0))
	_sync_box_part(m_right_leg_part, Vector3(0.18, 0.54, 0.20), Vector3(0.13, 0.41, 0.0))
	_sync_box_part(m_left_shoe_part, Vector3(0.22, 0.12, 0.28), Vector3(-0.13, 0.08, 0.04))
	_sync_box_part(m_right_shoe_part, Vector3(0.22, 0.12, 0.28), Vector3(0.13, 0.08, 0.04))
	_sync_box_part(m_face_marker_part, Vector3(0.20, 0.065, 0.04), Vector3(0.0, 1.49, 0.175))
	_sync_box_part(m_direction_marker_part, Vector3(0.065, 0.16, 0.045), Vector3(0.0, 1.38, 0.178))
	_sync_legacy_visual_visibility()


func _sync_procedural_rig() -> void:
	if !is_instance_valid(m_procedural_rig):
		if !is_instance_valid(m_visual_root):
			return
		m_procedural_rig = _ensure_procedural_rig()
	if !is_instance_valid(m_procedural_rig):
		return

	m_procedural_rig.visible = use_procedural_rig and not use_character_model
	if m_procedural_rig.has_method("configure_from_seed"):
		m_procedural_rig.call("configure_from_seed", procedural_seed, body_height, body_radius)
	_sync_legacy_visual_visibility()


func _sync_legacy_visual_visibility() -> void:
	var legacy_visible := !use_procedural_rig and !use_character_model
	for part in [
		m_body_part,
		m_head_part,
		m_hair_part,
		m_torso_part,
		m_left_arm_part,
		m_right_arm_part,
		m_left_leg_part,
		m_right_leg_part,
		m_left_shoe_part,
		m_right_shoe_part,
		m_face_marker_part,
		m_direction_marker_part,
	]:
		if is_instance_valid(part):
			part.visible = legacy_visible


func _sync_box_part(part: MeshInstance3D, base_size: Vector3, base_position: Vector3) -> void:
	if !is_instance_valid(part):
		return
	var box_mesh := part.mesh as BoxMesh
	if box_mesh == null:
		return

	var height_scale := body_height / DEFAULT_BODY_HEIGHT
	var radius_scale := body_radius / DEFAULT_BODY_RADIUS
	box_mesh.size = Vector3(
		base_size.x * radius_scale,
		base_size.y * height_scale,
		base_size.z * radius_scale
	)
	part.position = Vector3(
		base_position.x * radius_scale,
		base_position.y * height_scale,
		base_position.z * radius_scale
	)


func _sync_contact_shadow() -> void:
	if !is_instance_valid(m_contact_shadow_part):
		return

	m_contact_shadow_part.visible = contact_shadow_enabled
	m_contact_shadow_part.position = Vector3(0.0, 0.012, 0.0)
	var cylinder_mesh := m_contact_shadow_part.mesh as CylinderMesh
	if cylinder_mesh != null:
		var radius := maxf(contact_shadow_radius, body_radius * 1.25)
		cylinder_mesh.top_radius = radius
		cylinder_mesh.bottom_radius = radius
		cylinder_mesh.height = 0.014

	_apply_material(m_contact_shadow_part, Color(0.07, 0.08, 0.09, 0.28), true)


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
	_apply_material(m_left_arm_part, m_shirt_color)
	_apply_material(m_right_arm_part, m_shirt_color)
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
	_apply_material(m_direction_marker_part, face_color)


func _sync_debug_box() -> void:
	if !is_instance_valid(m_debug_box_part):
		return
	m_debug_box_part.visible = draw_bounding_box
	var debug_color := Color(0.2, 0.75, 1.0, 0.18)
	var box_mesh := m_debug_box_part.mesh as BoxMesh
	if box_mesh != null:
		box_mesh.size = Vector3(body_radius * 2.0, body_height, body_radius * 2.0)
	m_debug_box_part.position = Vector3(0.0, body_height * 0.5, 0.0)
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
