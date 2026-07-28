@tool
class_name HumanBody3D
extends CharacterBody3D

enum LocomotionMode {
	IDLE,
	WALK,
	RUN,
	AIRBORNE,
	TRAVERSAL_JUMP,
	LADDER,
	RECOVERY,
}

signal global_position_changed()
signal configuration_changed(cfg: Dictionary)
signal locomotion_mode_changed(mode: LocomotionMode)
signal traversal_jump_started()
signal landed()
signal recovery_started()
signal recovery_finished()
signal ladder_started()
signal ladder_finished()

const DEFAULT_WALK_SPEED := 4.0
const DEFAULT_RUN_SPEED := 7.5
# Retained cosmetic adapter values. Production input uses request_jump(), which
# owns physical traversal. jump() remains compatible for previews and legacy probes.
const JUMP_DURATION := 0.55
const JUMP_HEIGHT := 0.48
const GRAVITY := 16.0
const MAX_FALL_SPEED := 12.0
const DEFAULT_BODY_HEIGHT := 1.72
const DEFAULT_BODY_RADIUS := 0.28
const RIGID_BODY_PUSH_INPUT_DOT_THRESHOLD := 0.05
const RIGID_BODY_PUSH_SPEED_FACTOR := 0.35
const RIGID_BODY_PUSH_MAX_EFFECTIVE_MASS := 1.0
const RIGID_BODY_PUSH_MAX_IMPULSE := 1.2
const MIN_RIGID_BODY_PUSH_SPEED_DELTA := 0.002
const TRAVERSAL_FLOOR_SNAP_LENGTH := 0.12
const BaseController3DScript = preload("res://characters/control/base_controller_3d.gd")
const CharacterMotionIntent3DScript = preload(
	"res://characters/control/character_motion_intent_3d.gd"
)
const CharacterAnimationProfile3DScript = preload(
	"res://characters/actions/character_animation_profile_3d.gd"
)
const CharacterActionController3DScript = preload(
	"res://characters/actions/character_action_controller_3d.gd"
)
const PlayerRecoveryController3DScript = preload(
	"res://characters/control/player_recovery_controller_3d.gd"
)
# Default character model. Alternate models (boy.glb, female.glb) live alongside
# it in assets/characters and can be assigned through character_model_scene.
const CharacterModelScene: PackedScene = preload("res://assets/characters/male.glb")
const DEFAULT_CHARACTER_MODEL_HEIGHT := 0.998

@export var draw_bounding_box := false:
	set(value):
		if draw_bounding_box == value:
			return
		draw_bounding_box = value
		_sync_debug_box()

# Draws the character model's skeleton as bone lines for rig debugging.
# Updated every frame so it tracks animation.
@export var draw_skeleton_bones := false:
	set(value):
		if draw_skeleton_bones == value:
			return
		draw_skeleton_bones = value
		_sync_skeleton_debug()

@export var skeleton_debug_color := Color(0.1, 1.0, 0.45, 1.0):
	set(value):
		skeleton_debug_color = value
		if is_instance_valid(m_skeleton_debug_material):
			m_skeleton_debug_material.albedo_color = value
		if draw_skeleton_bones:
			_update_skeleton_debug()

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

@export_group("3D Navigation")
@export_range(0.0, 5.0, 0.05) var grounding_speed := 1.6
@export_range(0.0, 30.0, 0.1) var gravity := GRAVITY
@export_range(0.0, 30.0, 0.1) var maximum_fall_speed := MAX_FALL_SPEED

@export_group("Traversal Jump")
@export_range(0.0, 12.0, 0.05) var jump_takeoff_velocity := 4.80
@export_range(0.0, 12.0, 0.05) var jump_release_velocity := 2.00
@export_range(0.0, 12.0, 0.05) var jump_horizontal_speed_cap := 4.50
@export_range(0.0, 1.0, 0.01) var jump_buffer_seconds := 0.16
@export_range(0.0, 1.0, 0.01) var jump_coyote_seconds := 0.18
@export_range(0.0, 1.0, 0.01) var jump_ceiling_clearance := 0.20
@export_range(0.0, 20.0, 0.1) var air_control_acceleration := 6.00
@export_range(0.0, 5.0, 0.05) var air_control_max_delta := 1.00
@export_range(0.0, 1.0, 0.01) var landing_control_delay := 0.10

@export_group("Recovery")
@export_range(0.0, 2.0, 0.01) var recovery_stable_seconds := 0.25
@export_range(0.0, 20.0, 0.1) var recovery_drop_distance := 4.00
@export_range(0.0, 10.0, 0.1) var unsupported_recovery_seconds := 2.50
@export_range(0.0, 1.0, 0.01) var recovery_settle_seconds := 0.15

@export_group("Character Model")
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
@export var animation_profile: CharacterAnimationProfile3DScript = (
	CharacterAnimationProfile3DScript.new()
)
@export var action_controller: CharacterActionController3DScript = (
	CharacterActionController3DScript.new()
)
@export var recovery_controller: PlayerRecoveryController3DScript = (
	PlayerRecoveryController3DScript.new()
)

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
# Legacy visual-only jump state used only by jump().
var m_is_currently_jumping := false
var m_jump_timer := 0.0
var m_pending_motion_intent: CharacterMotionIntent3DScript = (
	CharacterMotionIntent3DScript.new()
)
var m_locomotion_mode: LocomotionMode = LocomotionMode.IDLE
var m_physical_jump_active := false
var m_jump_buffer_remaining := 0.0
var m_jump_buffer_pending := false
var m_time_since_grounded := INF
var m_jump_takeoff_horizontal_velocity := Vector3.ZERO
# A wall touched during one jump stays blocked until landing. Reapplying input
# must not turn a rejected obstacle into an implicit wall climb.
var m_airborne_wall_normal := Vector3.ZERO
var m_landing_timer := 0.0
var m_recovery_timer := 0.0
var m_ladder_mount_transform := Transform3D.IDENTITY
var m_ladder_axis := Vector3.UP
var m_ladder_distance := 0.0
var m_last_animation_phase := -1
var m_action_transition_timer := 0.0
var m_action_transition_phase := -1

var m_visual_root: Node3D = null
var m_debug_box_part: MeshInstance3D = null
var m_collision_shape: CollisionShape3D = null
var m_character_model: Node3D = null
var m_model_animation_player: AnimationPlayer = null
var m_skeleton_debug_part: MeshInstance3D = null
var m_skeleton_debug_material: StandardMaterial3D = null


func _ready() -> void:
	floor_snap_length = TRAVERSAL_FLOOR_SNAP_LENGTH
	_ensure_collision_shape()
	_ensure_visual_nodes()
	if animation_profile == null:
		animation_profile = CharacterAnimationProfile3DScript.new()
	if action_controller == null:
		action_controller = CharacterActionController3DScript.new()
	action_controller.setup(self)
	if recovery_controller == null:
		recovery_controller = PlayerRecoveryController3DScript.new()
	recovery_controller.setup(self)
	_update_state()
	_sync_debug_box()
	m_has_ready = true
	m_last_global_position = global_position
	recovery_controller.set_safe_transform(global_transform)
	_setup_controller()


func _notification(what: int) -> void:
	if (
		what == NOTIFICATION_PAUSED
		and is_inside_tree()
		and !Engine.is_editor_hint()
	):
		_settle_transient_state()


func _exit_tree() -> void:
	_settle_transient_state()
	if action_controller != null:
		action_controller.teardown()
	if recovery_controller != null:
		recovery_controller.teardown()
	_teardown_controller()


func get_configuration() -> Dictionary:
	return m_cached_configuration.duplicate(true)


func set_configuration(new_configuration: Dictionary) -> void:
	if m_cached_configuration == new_configuration:
		return
	m_cached_configuration = new_configuration.duplicate(true)
	configuration_changed.emit(get_configuration())


func move(direction_vector: Vector3) -> void:
	var movement_speed := run_speed if is_running else walk_speed
	move_with_speed(direction_vector, movement_speed)


## Compatibility adapter for manually driven probes and older controllers.
## Production controllers use submit_motion_intent(), which is consumed once by
## this actor's _physics_process. A controller-less probe is integrated immediately
## so existing focused collision fixtures retain one step per explicit call.
func move_with_speed(direction_vector: Vector3, movement_speed: float) -> void:
	var flat_direction := Vector3(direction_vector.x, 0.0, direction_vector.z)
	if flat_direction.length_squared() > 0.000001:
		flat_direction = flat_direction.normalized()
	var intent := CharacterMotionIntent3DScript.new(flat_direction, movement_speed)
	if controller != null:
		submit_motion_intent(intent)
		# Preserve the adapter's immediate velocity observability without performing
		# a second physics integration.
		velocity.x = flat_direction.x * movement_speed
		velocity.z = flat_direction.z * movement_speed
		return
	_integrate_motion_intent(intent, get_physics_process_delta_time())


func submit_motion_intent(intent: CharacterMotionIntent3DScript) -> void:
	if intent == null:
		m_pending_motion_intent = CharacterMotionIntent3DScript.new()
		return
	m_pending_motion_intent = CharacterMotionIntent3DScript.new(
		intent.direction,
		intent.movement_speed
	)
	if (
		!is_airborne()
		and !is_on_ladder()
		and !is_recovering()
	):
		velocity.x = m_pending_motion_intent.direction.x * m_pending_motion_intent.movement_speed
		velocity.z = m_pending_motion_intent.direction.z * m_pending_motion_intent.movement_speed


func _apply_rigid_body_pushes(horizontal_direction: Vector3, movement_speed: float) -> void:
	if movement_speed <= 0.0:
		return
	var flat_direction := Vector3(horizontal_direction.x, 0.0, horizontal_direction.z)
	if flat_direction.length_squared() <= 0.000001:
		return
	flat_direction = flat_direction.normalized()
	for collision_index in range(get_slide_collision_count()):
		var collision := get_slide_collision(collision_index)
		if collision == null:
			continue
		var rigid_body := collision.get_collider() as RigidBody3D
		if rigid_body == null or rigid_body.freeze:
			continue
		var normal := collision.get_normal()
		var flat_normal := Vector3(normal.x, 0.0, normal.z)
		if flat_normal.length_squared() <= 0.000001:
			continue
		flat_normal = flat_normal.normalized()
		var push_alignment := flat_direction.dot(-flat_normal)
		if push_alignment <= RIGID_BODY_PUSH_INPUT_DOT_THRESHOLD:
			continue
		var current_speed := rigid_body.linear_velocity.dot(flat_direction)
		var target_speed_delta := maxf(movement_speed - current_speed, 0.0)
		if target_speed_delta <= MIN_RIGID_BODY_PUSH_SPEED_DELTA:
			continue
		var effective_mass := minf(maxf(rigid_body.mass, 0.01), RIGID_BODY_PUSH_MAX_EFFECTIVE_MASS)
		var impulse_strength := minf(
			effective_mass * target_speed_delta * RIGID_BODY_PUSH_SPEED_FACTOR * push_alignment,
			RIGID_BODY_PUSH_MAX_IMPULSE
		)
		rigid_body.apply_central_impulse(flat_direction * impulse_strength)


func jump() -> void:
	if m_is_currently_jumping:
		return
	# Grounded movement keeps a small downward velocity so the capsule stays planted.
	# Clear it at takeoff so the stable capsule does not pull the visual jump downward.
	if is_grounded():
		velocity.y = 0.0
	m_is_currently_jumping = true
	m_jump_timer = 0.0
	_update_state()


## Requests the production physical jump. The request starts immediately during
## coyote time or queues for the accepted pre-landing buffer.
func request_jump() -> bool:
	if !is_action_free() or !is_free_locomotion() or m_is_currently_jumping:
		return false
	m_jump_buffer_remaining = jump_buffer_seconds
	m_jump_buffer_pending = true
	return _try_start_physical_jump()


func release_jump() -> void:
	if (
		m_physical_jump_active
		and velocity.y > jump_release_velocity
		and velocity.y > 0.0
	):
		velocity.y = jump_release_velocity


func get_jump_buffer_remaining() -> float:
	return m_jump_buffer_remaining


func get_coyote_remaining() -> float:
	return maxf(jump_coyote_seconds - m_time_since_grounded, 0.0)


func is_grounded() -> bool:
	return (
		!m_is_currently_jumping
		and !is_airborne()
		and m_locomotion_mode != LocomotionMode.LADDER
		and m_locomotion_mode != LocomotionMode.RECOVERY
		and is_on_floor()
	)


func get_locomotion_mode() -> LocomotionMode:
	return m_locomotion_mode


func get_locomotion_state() -> LocomotionMode:
	return get_locomotion_mode()


func is_free_locomotion() -> bool:
	return m_locomotion_mode in [
		LocomotionMode.IDLE,
		LocomotionMode.WALK,
		LocomotionMode.RUN,
		LocomotionMode.AIRBORNE,
		LocomotionMode.TRAVERSAL_JUMP,
	]


func is_airborne() -> bool:
	return m_locomotion_mode in [
		LocomotionMode.AIRBORNE,
		LocomotionMode.TRAVERSAL_JUMP,
	]


func is_recovering() -> bool:
	return m_locomotion_mode == LocomotionMode.RECOVERY


func is_on_ladder() -> bool:
	return m_locomotion_mode == LocomotionMode.LADDER


func get_action_mode() -> int:
	if action_controller == null:
		return CharacterActionController3DScript.ActionMode.FREE
	return int(action_controller.get_action_mode())


func is_action_free() -> bool:
	return action_controller == null or action_controller.is_free()


func get_active_action_target() -> Object:
	if action_controller == null:
		return null
	return action_controller.get_active_target()


## Reserves one sustained posture after a world target has accepted the actor.
## Target hooks are deliberately skipped here because the target already owns its
## physical begin lifecycle.
func begin_sustained_action(action_mode: int, target: Object) -> bool:
	if action_controller == null:
		action_controller = CharacterActionController3DScript.new()
		action_controller.setup(self)
	if !action_controller.begin_action(action_mode, target, false):
		return false
	match action_mode:
		CharacterActionController3DScript.ActionMode.SIT:
			_begin_action_animation_transition(
				CharacterAnimationProfile3DScript.Phase.SIT_ENTER,
				animation_profile.sit_entry_seconds
			)
		CharacterActionController3DScript.ActionMode.CARRY:
			_sync_model_animation(true)
		CharacterActionController3DScript.ActionMode.PUSH:
			_play_animation_phase(
				CharacterAnimationProfile3DScript.Phase.PUSH,
				true
			)
		CharacterActionController3DScript.ActionMode.PULL:
			_play_animation_phase(
				CharacterAnimationProfile3DScript.Phase.PULL,
				true
			)
	return true


func cancel_sustained_action(target: Object = null) -> bool:
	if action_controller == null or action_controller.is_free():
		return false
	if target != null and action_controller.get_active_target() != target:
		return false
	var previous_mode := action_controller.get_action_mode()
	if !action_controller.cancel_active_action(false):
		return false
	_play_action_exit_transition(previous_mode)
	return true


func complete_sustained_action(target: Object = null) -> bool:
	if action_controller == null or action_controller.is_free():
		return false
	if target != null and action_controller.get_active_target() != target:
		return false
	var previous_mode := action_controller.get_action_mode()
	if !action_controller.complete_active_action(false):
		return false
	_play_action_exit_transition(previous_mode)
	return true


## Begins ladder locomotion at an authored mount transform. Ladder target selection,
## endpoint clearance, and StoryEvent meaning remain world-owned.
func begin_ladder(
	mount_transform: Transform3D,
	climb_axis: Vector3 = Vector3.UP
) -> bool:
	if !is_action_free() or !is_grounded() or !is_free_locomotion():
		return false
	var normalized_axis := climb_axis.normalized()
	if normalized_axis.is_zero_approx():
		return false
	m_ladder_mount_transform = mount_transform
	m_ladder_axis = normalized_axis
	m_ladder_distance = 0.0
	global_transform = mount_transform
	velocity = Vector3.ZERO
	m_physical_jump_active = false
	m_jump_buffer_remaining = 0.0
	m_jump_buffer_pending = false
	m_airborne_wall_normal = Vector3.ZERO
	_set_locomotion_mode(LocomotionMode.LADDER)
	_play_animation_phase(
		CharacterAnimationProfile3DScript.Phase.LADDER_MOUNT,
		true
	)
	ladder_started.emit()
	return true


## Applies signed ladder intent while constraining the actor to the authored axis.
func apply_ladder_motion(
	signed_input: float,
	delta: float,
	climb_speed: float = 1.80
) -> void:
	if !is_on_ladder():
		return
	_play_animation_phase(
		CharacterAnimationProfile3DScript.Phase.LADDER_CLIMB
	)
	m_ladder_distance += signed_input * maxf(climb_speed, 0.0) * maxf(delta, 0.0)
	var ladder_transform := m_ladder_mount_transform
	ladder_transform.origin = (
		m_ladder_mount_transform.origin + m_ladder_axis * m_ladder_distance
	)
	global_transform = ladder_transform
	velocity = Vector3.ZERO


## Applies a ladder-owned path correction without performing another physics
## integration. This keeps the actor's internal ladder distance synchronized with
## blocked-endpoint retreat and other authored constraint corrections.
func constrain_ladder_position(target_position: Vector3) -> void:
	if !is_on_ladder():
		return
	m_ladder_distance = (
		target_position - m_ladder_mount_transform.origin
	).dot(m_ladder_axis)
	var ladder_transform := m_ladder_mount_transform
	ladder_transform.origin = (
		m_ladder_mount_transform.origin + m_ladder_axis * m_ladder_distance
	)
	global_transform = ladder_transform
	velocity = Vector3.ZERO


## Compatibility target-position form used by the world coordinator. The target is
## projected onto the ladder axis so no free XZ drift can enter actor state.
func move_on_ladder(target_position: Vector3, climb_speed: float = 1.80) -> void:
	if !is_on_ladder():
		return
	_play_animation_phase(
		CharacterAnimationProfile3DScript.Phase.LADDER_CLIMB
	)
	var target_distance := (
		target_position - m_ladder_mount_transform.origin
	).dot(m_ladder_axis)
	m_ladder_distance = move_toward(
		m_ladder_distance,
		target_distance,
		maxf(climb_speed, 0.0) * get_physics_process_delta_time()
	)
	var ladder_transform := m_ladder_mount_transform
	ladder_transform.origin = (
		m_ladder_mount_transform.origin + m_ladder_axis * m_ladder_distance
	)
	global_transform = ladder_transform
	velocity = Vector3.ZERO


func finish_ladder(exit_transform: Transform3D) -> void:
	if !is_on_ladder():
		return
	_play_animation_phase(
		CharacterAnimationProfile3DScript.Phase.LADDER_DISMOUNT,
		true
	)
	global_transform = exit_transform
	velocity = Vector3.ZERO
	_set_locomotion_mode(LocomotionMode.IDLE)
	set_safe_transform(exit_transform)
	ladder_finished.emit()


func cancel_ladder(mount_transform: Transform3D) -> void:
	if !is_on_ladder():
		return
	_play_animation_phase(
		CharacterAnimationProfile3DScript.Phase.LADDER_DISMOUNT,
		true
	)
	global_transform = mount_transform
	velocity = Vector3.ZERO
	_set_locomotion_mode(LocomotionMode.IDLE)
	set_safe_transform(mount_transform)
	ladder_finished.emit()


func set_safe_transform(safe_transform: Transform3D) -> void:
	if recovery_controller == null:
		recovery_controller = PlayerRecoveryController3DScript.new()
		recovery_controller.setup(self)
	recovery_controller.set_safe_transform(safe_transform)


func get_safe_transform() -> Transform3D:
	if recovery_controller == null:
		return global_transform
	return recovery_controller.get_safe_transform()


func has_safe_transform() -> bool:
	return recovery_controller != null and recovery_controller.has_safe_transform()


func recover_to_transform(safe_transform: Transform3D) -> void:
	set_safe_transform(safe_transform)
	_begin_recovery(safe_transform)


func recover_to_safe_transform() -> void:
	if has_safe_transform():
		_begin_recovery(get_safe_transform())


func settle_for_pause() -> void:
	_settle_transient_state()


func cleanup_for_unload() -> void:
	_settle_transient_state()


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
	if is_instance_valid(m_model_animation_player):
		return m_model_animation_player.current_animation
	return ""


func _process(delta: float) -> void:
	_process_jump(delta)
	if draw_skeleton_bones:
		_update_skeleton_debug()
	if !m_last_global_position.is_equal_approx(global_position):
		m_last_global_position = global_position
		global_position_changed.emit()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_advance_transient_timers(delta)
	m_pending_motion_intent = CharacterMotionIntent3DScript.new()
	_process_controller(delta)
	if controller == null:
		return
	if is_on_ladder() or is_recovering():
		velocity = Vector3.ZERO
		return
	var action_intent := _constrain_sustained_action_intent(
		m_pending_motion_intent,
		delta
	)
	_call_active_action_motion_hook(
		&"before_actor_motion",
		action_intent,
		delta
	)
	_integrate_motion_intent(action_intent, delta)
	_call_active_action_motion_hook(
		&"after_actor_motion",
		action_intent,
		delta
	)


## Compatibility helper retained for focused callers. It goes through the same
## single integration path as all other motion.
func _apply_passive_vertical_motion(delta: float) -> void:
	_integrate_motion_intent(CharacterMotionIntent3DScript.new(), delta)


func _integrate_motion_intent(
	intent: CharacterMotionIntent3DScript,
	delta: float
) -> void:
	if is_on_ladder() or is_recovering():
		velocity = Vector3.ZERO
		return
	var safe_intent := intent
	if safe_intent == null:
		safe_intent = CharacterMotionIntent3DScript.new()
	var flat_direction := safe_intent.direction
	var movement_speed := safe_intent.movement_speed
	var was_on_floor := is_on_floor()

	if m_physical_jump_active or !was_on_floor:
		_apply_air_control(flat_direction, movement_speed, delta)
	else:
		velocity.x = flat_direction.x * movement_speed
		velocity.z = flat_direction.z * movement_speed

	if m_is_currently_jumping:
		# Legacy cosmetic adapter keeps the capsule planted.
		if was_on_floor:
			velocity.y = -grounding_speed
	elif m_physical_jump_active or !was_on_floor:
		velocity.y = maxf(
			velocity.y - gravity * delta,
			-maximum_fall_speed
		)
	else:
		velocity.y = -grounding_speed

	move_and_slide()
	_apply_rigid_body_pushes(flat_direction, movement_speed)

	if (m_physical_jump_active or !was_on_floor) and is_on_wall():
		var wall_normal := get_wall_normal()
		m_airborne_wall_normal = Vector3(
			wall_normal.x,
			0.0,
			wall_normal.z
		).normalized()
	if is_on_ceiling() and velocity.y > 0.0:
		velocity.y = 0.0
		m_physical_jump_active = false
		_set_locomotion_mode(LocomotionMode.AIRBORNE)

	_update_locomotion_after_motion(was_on_floor, safe_intent)
	_update_recovery_tracking(delta)


func _apply_air_control(
	requested_direction: Vector3,
	requested_speed: float,
	delta: float
) -> void:
	var desired_speed := minf(requested_speed, jump_horizontal_speed_cap)
	var desired_velocity := requested_direction * desired_speed
	var current_horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var candidate := current_horizontal.move_toward(
		desired_velocity,
		air_control_acceleration * maxf(delta, 0.0)
	)
	if !m_airborne_wall_normal.is_zero_approx():
		var into_wall := -m_airborne_wall_normal
		candidate -= into_wall * maxf(candidate.dot(into_wall), 0.0)
	var takeoff_delta := candidate - m_jump_takeoff_horizontal_velocity
	if takeoff_delta.length() > air_control_max_delta:
		candidate = (
			m_jump_takeoff_horizontal_velocity
			+ takeoff_delta.normalized() * air_control_max_delta
		)
	if candidate.length() > jump_horizontal_speed_cap:
		candidate = candidate.normalized() * jump_horizontal_speed_cap
	velocity.x = candidate.x
	velocity.z = candidate.z


func _update_locomotion_after_motion(
	was_on_floor: bool,
	intent: CharacterMotionIntent3DScript
) -> void:
	var now_on_floor := is_on_floor()
	if now_on_floor:
		m_time_since_grounded = 0.0
		m_airborne_wall_normal = Vector3.ZERO
		if !was_on_floor:
			m_physical_jump_active = false
			m_landing_timer = landing_control_delay
			landed.emit()
			_play_animation_phase(
				CharacterAnimationProfile3DScript.Phase.LAND,
				true
			)
		_set_ground_locomotion_mode(intent)
		if m_jump_buffer_pending:
			_try_start_physical_jump()
		return

	m_time_since_grounded += get_physics_process_delta_time()
	if was_on_floor and !m_physical_jump_active:
		var ledge_velocity := Vector3(velocity.x, 0.0, velocity.z)
		if ledge_velocity.length() > jump_horizontal_speed_cap:
			ledge_velocity = ledge_velocity.normalized() * jump_horizontal_speed_cap
		m_jump_takeoff_horizontal_velocity = ledge_velocity
		velocity.x = ledge_velocity.x
		velocity.z = ledge_velocity.z
	if m_physical_jump_active and velocity.y > 0.0:
		_set_locomotion_mode(LocomotionMode.TRAVERSAL_JUMP)
	else:
		m_physical_jump_active = false
		_set_locomotion_mode(LocomotionMode.AIRBORNE)


func _set_ground_locomotion_mode(intent: CharacterMotionIntent3DScript) -> void:
	if intent != null and intent.is_moving():
		_set_locomotion_mode(
			LocomotionMode.RUN if is_running else LocomotionMode.WALK
		)
	else:
		_set_locomotion_mode(LocomotionMode.IDLE)


func _try_start_physical_jump() -> bool:
	if !is_free_locomotion() or m_physical_jump_active:
		return false
	var has_floor_forgiveness := (
		is_on_floor() or m_time_since_grounded <= jump_coyote_seconds
	)
	if !has_floor_forgiveness:
		return false
	if !_has_jump_clearance():
		if is_on_floor():
			m_jump_buffer_remaining = 0.0
			m_jump_buffer_pending = false
		return false
	m_jump_buffer_remaining = 0.0
	m_jump_buffer_pending = false
	m_is_currently_jumping = false
	m_jump_timer = 0.0
	_apply_visual_offset()

	var initial_horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if m_pending_motion_intent != null and m_pending_motion_intent.is_moving():
		initial_horizontal = (
			m_pending_motion_intent.direction
			* minf(
				m_pending_motion_intent.movement_speed,
				jump_horizontal_speed_cap
			)
		)
	if initial_horizontal.length() > jump_horizontal_speed_cap:
		initial_horizontal = initial_horizontal.normalized() * jump_horizontal_speed_cap
	m_jump_takeoff_horizontal_velocity = initial_horizontal
	m_airborne_wall_normal = Vector3.ZERO
	velocity.x = initial_horizontal.x
	velocity.z = initial_horizontal.z
	velocity.y = jump_takeoff_velocity
	m_physical_jump_active = true
	_set_locomotion_mode(LocomotionMode.TRAVERSAL_JUMP)
	traversal_jump_started.emit()
	return true


func _has_jump_clearance() -> bool:
	if jump_ceiling_clearance <= 0.0:
		return true
	return !test_move(global_transform, Vector3.UP * jump_ceiling_clearance)


func _advance_transient_timers(delta: float) -> void:
	if m_jump_buffer_pending:
		m_jump_buffer_remaining -= maxf(delta, 0.0)
		# Zero remains an inclusive boundary until the landing integration runs.
		if m_jump_buffer_remaining < -0.00001:
			m_jump_buffer_remaining = 0.0
			m_jump_buffer_pending = false
		else:
			m_jump_buffer_remaining = maxf(m_jump_buffer_remaining, 0.0)
	m_landing_timer = maxf(m_landing_timer - delta, 0.0)
	if m_action_transition_timer > 0.0:
		m_action_transition_timer = maxf(
			m_action_transition_timer - maxf(delta, 0.0),
			0.0
		)
		if is_zero_approx(m_action_transition_timer):
			m_action_transition_phase = -1
			_sync_model_animation(true)
	if !is_recovering():
		return
	m_recovery_timer = maxf(m_recovery_timer - delta, 0.0)
	if m_recovery_timer > 0.0:
		return
	_set_locomotion_mode(LocomotionMode.IDLE)
	recovery_finished.emit()


func _update_recovery_tracking(delta: float) -> void:
	if recovery_controller == null or is_recovering():
		return
	recovery_controller.stable_seconds = recovery_stable_seconds
	recovery_controller.drop_distance = recovery_drop_distance
	recovery_controller.unsupported_seconds = unsupported_recovery_seconds
	if recovery_controller.update_after_motion(
		delta,
		is_on_floor(),
		is_free_locomotion(),
		velocity.y
	):
		recover_to_safe_transform()


func _begin_recovery(target_transform: Transform3D) -> void:
	var was_on_ladder := is_on_ladder()
	if action_controller != null:
		action_controller.cleanup()
	global_transform = target_transform
	velocity = Vector3.ZERO
	m_physical_jump_active = false
	m_is_currently_jumping = false
	m_jump_timer = 0.0
	m_jump_buffer_remaining = 0.0
	m_jump_buffer_pending = false
	m_airborne_wall_normal = Vector3.ZERO
	m_ladder_distance = 0.0
	if recovery_controller != null:
		recovery_controller.reset_transient_tracking()
	m_recovery_timer = recovery_settle_seconds
	_apply_visual_offset()
	_set_locomotion_mode(LocomotionMode.RECOVERY)
	if was_on_ladder:
		ladder_finished.emit()
	recovery_started.emit()


func _set_locomotion_mode(mode: LocomotionMode) -> void:
	if m_locomotion_mode == mode:
		return
	m_locomotion_mode = mode
	locomotion_mode_changed.emit(mode)
	_sync_model_animation(true)


func _settle_transient_state() -> void:
	var was_on_ladder := is_on_ladder()
	if action_controller != null:
		action_controller.cleanup()
	if is_on_ladder():
		global_transform = m_ladder_mount_transform
	elif is_airborne() or is_recovering():
		if has_safe_transform():
			global_transform = get_safe_transform()
	velocity = Vector3.ZERO
	m_physical_jump_active = false
	m_is_currently_jumping = false
	m_jump_timer = 0.0
	m_jump_buffer_remaining = 0.0
	m_jump_buffer_pending = false
	m_airborne_wall_normal = Vector3.ZERO
	m_recovery_timer = 0.0
	m_action_transition_timer = 0.0
	m_action_transition_phase = -1
	m_ladder_distance = 0.0
	if recovery_controller != null:
		recovery_controller.reset_transient_tracking()
	_apply_visual_offset()
	_set_locomotion_mode(LocomotionMode.IDLE)
	if was_on_ladder:
		ladder_finished.emit()


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
	_sync_model_animation()


func _get_jump_offset_y() -> float:
	if !m_is_currently_jumping:
		return 0.0
	var t := clampf(m_jump_timer / JUMP_DURATION, 0.0, 1.0)
	var parabola := 1.0 - pow(2.0 * t - 1.0, 2.0)
	return JUMP_HEIGHT * parabola


func _apply_visual_offset() -> void:
	var jump_y := _get_jump_offset_y()
	if is_instance_valid(m_visual_root):
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
	_sync_collision_shape()


func _ensure_visual_nodes() -> void:
	m_visual_root = get_node_or_null("VisualRoot") as Node3D
	if m_visual_root == null:
		m_visual_root = Node3D.new()
		m_visual_root.name = "VisualRoot"
		add_child(m_visual_root)
		if Engine.is_editor_hint():
			m_visual_root.owner = null

	m_debug_box_part = _ensure_debug_box_part()
	_sync_body_profile()


func _ensure_debug_box_part() -> MeshInstance3D:
	var parent := m_visual_root if is_instance_valid(m_visual_root) else self
	var part := parent.get_node_or_null("DebugBox") as MeshInstance3D
	if part == null:
		part = MeshInstance3D.new()
		part.name = "DebugBox"
		part.mesh = BoxMesh.new()
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(part)
		if Engine.is_editor_hint():
			part.owner = null
	return part


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
		var model_parent := m_character_model.get_parent()
		if model_parent != null:
			model_parent.remove_child(m_character_model)
		m_character_model.queue_free()
		m_character_model = null
	m_model_animation_player = null
	m_last_animation_phase = -1
	# The skeleton debug draw lives under the model's skeleton and is freed with it.
	m_skeleton_debug_part = null
	if is_inside_tree():
		_sync_character_model()


func _sync_character_model() -> void:
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
	if is_instance_valid(m_model_animation_player) and animation_profile != null:
		animation_profile.idle_animation = model_idle_animation
		animation_profile.walk_animation = model_walk_animation
		animation_profile.run_animation = model_run_animation
		animation_profile.ensure_generated_fallbacks(
			m_model_animation_player,
			_find_skeleton(m_character_model)
		)
	_sync_model_animation()
	_sync_skeleton_debug()


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null


func _sync_skeleton_debug() -> void:
	var skeleton: Skeleton3D = null
	if is_instance_valid(m_character_model):
		skeleton = _find_skeleton(m_character_model)
	if skeleton == null or not draw_skeleton_bones:
		if is_instance_valid(m_skeleton_debug_part):
			m_skeleton_debug_part.visible = false
		return
	if not is_instance_valid(m_skeleton_debug_part) or m_skeleton_debug_part.get_parent() != skeleton:
		m_skeleton_debug_part = _ensure_skeleton_debug_part(skeleton)
	m_skeleton_debug_part.visible = true
	_update_skeleton_debug()


func _ensure_skeleton_debug_part(skeleton: Skeleton3D) -> MeshInstance3D:
	var part := skeleton.get_node_or_null("SkeletonDebug") as MeshInstance3D
	if part == null:
		part = MeshInstance3D.new()
		part.name = "SkeletonDebug"
		part.mesh = ImmediateMesh.new()
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		skeleton.add_child(part)
		if Engine.is_editor_hint():
			part.owner = null
	if m_skeleton_debug_material == null:
		m_skeleton_debug_material = StandardMaterial3D.new()
		m_skeleton_debug_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m_skeleton_debug_material.vertex_color_use_as_albedo = true
		m_skeleton_debug_material.no_depth_test = true
		m_skeleton_debug_material.albedo_color = skeleton_debug_color
	part.material_override = m_skeleton_debug_material
	return part


func _update_skeleton_debug() -> void:
	if not is_instance_valid(m_skeleton_debug_part):
		return
	var mesh := m_skeleton_debug_part.mesh as ImmediateMesh
	if mesh == null:
		return
	var skeleton := m_skeleton_debug_part.get_parent() as Skeleton3D
	if skeleton == null:
		return
	mesh.clear_surfaces()
	var bone_count := skeleton.get_bone_count()
	if bone_count <= 0:
		return
	# Bone poses are in skeleton-local space; the debug mesh is a child of the
	# skeleton with an identity transform, so they map directly to mesh vertices.
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for bone_index in range(bone_count):
		var parent_index := skeleton.get_bone_parent(bone_index)
		if parent_index < 0:
			continue
		var parent_origin := skeleton.get_bone_global_pose(parent_index).origin
		var child_origin := skeleton.get_bone_global_pose(bone_index).origin
		mesh.surface_set_color(skeleton_debug_color)
		mesh.surface_add_vertex(parent_origin)
		mesh.surface_set_color(skeleton_debug_color)
		mesh.surface_add_vertex(child_origin)
	mesh.surface_end()


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
		var to_root := inv_root * mesh_instance.global_transform
		# Measure the true lowest rendered vertex rather than MeshInstance3D.get_aabb().
		# Imported skinned meshes carry an AABB padded below the feet (headroom for
		# animation/culling); aligning that padded floor to the foot origin would seat
		# the bones above the ground and leave the character visibly hovering. The rest-
		# pose vertices give the real sole position, so the feet land on the floor.
		var mesh := mesh_instance.mesh
		var measured := false
		if mesh != null:
			for surface_index in range(mesh.get_surface_count()):
				var arrays := mesh.surface_get_arrays(surface_index)
				if arrays.size() <= Mesh.ARRAY_VERTEX:
					continue
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				for vertex in vertices:
					lowest = minf(lowest, (to_root * vertex).y)
					measured = true
		if not measured:
			# Fall back to the (possibly padded) AABB when vertex data is unavailable.
			var aabb := mesh_instance.get_aabb()
			for i in range(8):
				var corner := aabb.position + Vector3(
					aabb.size.x * float(i & 1),
					aabb.size.y * float((i >> 1) & 1),
					aabb.size.z * float((i >> 2) & 1))
				lowest = minf(lowest, (to_root * corner).y)
	if lowest == INF:
		lowest = 0.0
	m_character_model.position.y = character_model_y_offset - lowest


func _sync_model_animation(force_restart := false) -> void:
	if not is_instance_valid(m_model_animation_player):
		return
	var phase := _desired_animation_phase()
	_play_animation_phase(phase, force_restart)


func _play_animation_phase(
	phase: int,
	force_restart := false
) -> void:
	if !is_instance_valid(m_model_animation_player):
		return
	if animation_profile == null:
		animation_profile = CharacterAnimationProfile3DScript.new()
	animation_profile.idle_animation = model_idle_animation
	animation_profile.walk_animation = model_walk_animation
	animation_profile.run_animation = model_run_animation
	var target := _match_model_animation(animation_profile.get_animation_name(phase))
	if target.is_empty():
		return
	var animation := m_model_animation_player.get_animation(target)
	if animation != null:
		animation.loop_mode = (
			Animation.LOOP_LINEAR
			if animation_profile.should_loop(phase)
			else Animation.LOOP_NONE
		)
	if force_restart or m_model_animation_player.current_animation != target:
		m_model_animation_player.play(
			target,
			animation_profile.get_blend_seconds(phase)
		)
		if animation_profile.should_seek_neutral_sample(phase):
			m_model_animation_player.seek(0.0, true)
	m_last_animation_phase = int(phase)


func _desired_animation_phase() -> int:
	if m_action_transition_phase >= 0 and m_action_transition_timer > 0.0:
		return m_action_transition_phase
	match m_locomotion_mode:
		LocomotionMode.RECOVERY:
			return CharacterAnimationProfile3DScript.Phase.RECOVERY
		LocomotionMode.LADDER:
			return CharacterAnimationProfile3DScript.Phase.LADDER_CLIMB
		LocomotionMode.TRAVERSAL_JUMP, LocomotionMode.AIRBORNE:
			return CharacterAnimationProfile3DScript.Phase.AIR
	match get_action_mode():
		CharacterActionController3DScript.ActionMode.CARRY:
			return (
				CharacterAnimationProfile3DScript.Phase.CARRY_WALK
				if is_walking
				else CharacterAnimationProfile3DScript.Phase.CARRY_IDLE
			)
		CharacterActionController3DScript.ActionMode.PUSH:
			return CharacterAnimationProfile3DScript.Phase.PUSH
		CharacterActionController3DScript.ActionMode.PULL:
			return CharacterAnimationProfile3DScript.Phase.PULL
		CharacterActionController3DScript.ActionMode.SIT:
			return CharacterAnimationProfile3DScript.Phase.SIT_IDLE
	if m_landing_timer > 0.0:
		if !is_walking:
			return CharacterAnimationProfile3DScript.Phase.LAND
	if is_walking and is_running:
		return CharacterAnimationProfile3DScript.Phase.RUN
	if is_walking:
		return CharacterAnimationProfile3DScript.Phase.WALK
	return CharacterAnimationProfile3DScript.Phase.IDLE


func _constrain_sustained_action_intent(
	intent: CharacterMotionIntent3DScript,
	delta: float
) -> CharacterMotionIntent3DScript:
	if is_action_free():
		return intent
	var target := get_active_action_target()
	if is_instance_valid(target) and target.has_method(
		"constrain_motion_intent"
	):
		var constrained: Variant = target.call(
			"constrain_motion_intent",
			self,
			intent,
			delta
		)
		if constrained is CharacterMotionIntent3DScript:
			return constrained as CharacterMotionIntent3DScript
	match get_action_mode():
		CharacterActionController3DScript.ActionMode.CARRY:
			return CharacterMotionIntent3DScript.new(
				intent.direction,
				minf(intent.movement_speed, 3.2)
			)
		_:
			return CharacterMotionIntent3DScript.new()


func _call_active_action_motion_hook(
	method_name: StringName,
	intent: CharacterMotionIntent3DScript,
	delta: float
) -> void:
	var target := get_active_action_target()
	if !is_instance_valid(target) or !target.has_method(method_name):
		return
	target.call(method_name, self, intent, delta)


func _begin_action_animation_transition(phase: int, duration: float) -> void:
	m_action_transition_phase = phase
	m_action_transition_timer = maxf(duration, 0.0)
	_play_animation_phase(phase, true)
	if is_zero_approx(m_action_transition_timer):
		m_action_transition_phase = -1


func _play_action_exit_transition(previous_mode: int) -> void:
	match previous_mode:
		CharacterActionController3DScript.ActionMode.CARRY:
			_begin_action_animation_transition(
				CharacterAnimationProfile3DScript.Phase.CARRY_PLACE,
				animation_profile.carry_release_seconds
			)
		CharacterActionController3DScript.ActionMode.SIT:
			_begin_action_animation_transition(
				CharacterAnimationProfile3DScript.Phase.SIT_EXIT,
				animation_profile.sit_exit_seconds
			)
		_:
			m_action_transition_timer = 0.0
			m_action_transition_phase = -1
			_sync_model_animation(true)


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


func _sync_body_profile() -> void:
	_sync_collision_shape()
	_sync_debug_box()
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
