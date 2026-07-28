@tool
class_name PushPullObject3D
extends CharacterActionTarget3D

## Deterministic deliberate push/pull target.
##
## The movable body is projected onto one authored straight path. HumanBody3D
## remains the only actor motion integrator; this target constrains its intent,
## shape-tests the combined move, and advances the object by the actor's actual
## along-axis progress after that integration.

signal blocked_state_changed(blocked: bool)
signal object_reset(reason: StringName)

const CharacterActionController3DScript = preload(
	"res://characters/actions/character_action_controller_3d.gd"
)
const CharacterMotionIntent3DScript = preload(
	"res://characters/control/character_motion_intent_3d.gd"
)

const PUSH_SPEED := 1.25
const PULL_SPEED := 1.00
const MAXIMUM_PATH_LENGTH := 4.00
const HARD_ENDPOINT_STOP := 0.10
const GOAL_TOLERANCE := 0.10
const HANDLE_RANGE := 1.10
const ACTOR_ANCHOR_POSITION_TOLERANCE := 0.12
const ACTOR_ANCHOR_ANGLE_TOLERANCE := 10.0
const CROSS_AXIS_TOLERANCE := 0.05
const SWEEP_MARGIN := 0.08
const BLOCKED_PROGRESS_THRESHOLD := 0.02
const BLOCKED_DURATION := 0.20
const OUT_OF_BOUNDS_DISTANCE := 0.50
const OUT_OF_BOUNDS_DURATION := 0.25
const DROP_RESET_DISTANCE := 2.00
const REQUIRED_PATH_BLOCK_DURATION := 2.00
const RESET_CLEARANCE := 0.10
const SHAPE_PROBE_LIFT := 0.002
const MOTION_EPSILON := 0.0001
const INPUT_AXIS_THRESHOLD := 0.50

@export_group("Authored Path")
@export var path_start_path: NodePath
@export var path_end_path: NodePath
@export var goal_path: NodePath
@export var movable_body_path: NodePath
@export var movable_collision_shape_path: NodePath
@export var handle_path: NodePath
@export var actor_anchor_path: NodePath
@export var required_path_area_path: NodePath
@export var auto_complete_at_goal := true
@export var required_path_protection_enabled := true

var m_initial_body_transform := Transform3D.IDENTITY
var m_initial_coordinate := 0.0
var m_last_valid_coordinate := 0.0
var m_push_axis := Vector3.RIGHT
var m_active_signed_input := 0.0
var m_pending_coordinate_delta := 0.0
var m_actor_position_before_motion := Vector3.ZERO
var m_motion_frame_active := false
var m_progress_window_elapsed := 0.0
var m_progress_window_distance := 0.0
var m_blocked := false
var m_at_hard_stop := false
var m_out_of_bounds_elapsed := 0.0
var m_required_path_block_elapsed := 0.0
var m_goal_completed := false
var m_semantic_completion_emitted := false
var m_actor_state_transition := false


func _init() -> void:
	action_id = &"push_pull"
	action_label = "Move hymn chest"
	interaction_range = HANDLE_RANGE
	facing_tolerance_degrees = ACTOR_ANCHOR_ANGLE_TOLERANCE
	sustained_action = true


func _ready() -> void:
	sustained_action = true
	var body := get_movable_body()
	if is_instance_valid(body):
		m_initial_body_transform = body.global_transform
	m_initial_coordinate = _clamp_to_hard_bounds(get_path_coordinate())
	m_last_valid_coordinate = m_initial_coordinate
	_set_path_coordinate(m_initial_coordinate)
	set_physics_process(!Engine.is_editor_hint())
	update_configuration_warnings()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_monitor_object_recovery(maxf(delta, 0.0))


func get_action_anchor() -> Node3D:
	var handle := get_node_or_null(handle_path) as Node3D
	if is_instance_valid(handle):
		return handle
	return super.get_action_anchor()


func get_action_anchor_transform(_actor: CharacterBody3D = null) -> Transform3D:
	var handle := get_action_anchor()
	return handle.global_transform if is_instance_valid(handle) else global_transform


func get_action_distance(actor: CharacterBody3D) -> float:
	if !is_instance_valid(actor):
		return INF
	var delta := get_action_anchor_transform(actor).origin - actor.global_position
	delta.y = 0.0
	return delta.length()


func get_facing_alignment(actor: CharacterBody3D) -> float:
	if !is_instance_valid(actor):
		return -1.0
	return clampf(_resolve_actor_forward(actor).dot(_get_push_axis()), -1.0, 1.0)


func is_action_available(actor: CharacterBody3D) -> bool:
	if !action_enabled or m_goal_completed or !is_instance_valid(actor):
		return false
	if has_reserved_actor() and get_reserved_actor() != actor:
		return false
	if !_actor_is_free(actor) and get_reserved_actor() != actor:
		return false
	if actor.has_method("is_grounded") and !bool(actor.call("is_grounded")):
		return false
	if get_action_distance(actor) > HANDLE_RANGE + MOTION_EPSILON:
		return false
	if get_vertical_delta(actor) > max_vertical_delta + MOTION_EPSILON:
		return false
	if get_actor_anchor_error(actor) > (
		ACTOR_ANCHOR_POSITION_TOLERANCE + MOTION_EPSILON
	):
		return false
	if get_actor_facing_error_degrees(actor) > (
		ACTOR_ANCHOR_ANGLE_TOLERANCE + MOTION_EPSILON
	):
		return false
	if get_path_length() <= HARD_ENDPOINT_STOP * 2.0:
		return false
	return _has_entry_motion_clearance(actor)


func begin_action(actor: CharacterBody3D) -> bool:
	if m_actor_state_transition:
		return actor == get_reserved_actor()
	if !is_action_available(actor):
		return false
	if !super.begin_action(actor):
		return false

	m_push_axis = _resolve_authored_push_axis()
	m_last_valid_coordinate = _clamp_to_hard_bounds(get_path_coordinate())
	_set_path_coordinate(m_last_valid_coordinate)
	_align_actor_to_anchor(actor)
	_clear_transient_motion()
	if !_begin_actor_sustained_action(actor):
		super.cancel_action(actor, &"actor_mode_rejected")
		return false
	return true


func cancel_action(actor: CharacterBody3D, reason: StringName = &"cancel") -> void:
	if m_actor_state_transition or actor != get_reserved_actor():
		return
	_set_path_coordinate(m_last_valid_coordinate)
	if reason not in [&"recovery", &"scene_unload"]:
		_align_actor_to_anchor(actor)
	_cancel_actor_sustained_action(actor)
	_clear_transient_motion()
	super.cancel_action(actor, reason)


func complete_action(actor: CharacterBody3D, context: Dictionary = {}) -> void:
	if m_actor_state_transition or actor != get_reserved_actor():
		return
	_set_path_coordinate(m_last_valid_coordinate)
	_complete_actor_sustained_action(actor)
	_clear_transient_motion()
	var completion_context := context.duplicate(true)
	completion_context["coordinate"] = m_last_valid_coordinate
	completion_context["path_length"] = get_path_length()
	completion_context["mode"] = (
		"pull" if get_animation_action_mode() == (
			CharacterActionController3DScript.ActionMode.PULL
		) else "push"
	)
	if m_semantic_completion_emitted:
		var saved_semantic_id := semantic_completion_id
		semantic_completion_id = &""
		super.complete_action(actor, completion_context)
		semantic_completion_id = saved_semantic_id
	else:
		m_semantic_completion_emitted = !semantic_completion_id.is_empty()
		super.complete_action(actor, completion_context)
	m_goal_completed = true


## Active R releases at the last valid coordinate without completing.
func request_active_context_action(actor: CharacterBody3D) -> bool:
	if actor != get_reserved_actor():
		return false
	cancel_action(actor, &"release")
	return true


## Converts arbitrary controller intent into W/push or S/pull motion on the
## authored axis. Run/walk modifiers are deliberately ignored.
func constrain_motion_intent(
	actor: CharacterBody3D,
	intent: CharacterMotionIntent3DScript,
	delta: float
) -> CharacterMotionIntent3DScript:
	var stopped := CharacterMotionIntent3DScript.new()
	m_active_signed_input = 0.0
	m_pending_coordinate_delta = 0.0
	m_at_hard_stop = false
	if actor != get_reserved_actor() or intent == null or !intent.is_moving():
		return stopped

	var push_axis := _get_push_axis()
	var input_alignment := intent.direction.dot(push_axis)
	if absf(input_alignment) < INPUT_AXIS_THRESHOLD:
		return stopped
	var signed_input := 1.0 if input_alignment > 0.0 else -1.0
	var accepted_speed := PUSH_SPEED if signed_input > 0.0 else PULL_SPEED
	var path_axis := get_path_axis()
	var coordinate_sign := signf(push_axis.dot(path_axis)) * signed_input
	var coordinate := _clamp_to_hard_bounds(get_path_coordinate())
	var desired_coordinate_delta := (
		coordinate_sign * accepted_speed * maxf(delta, 0.0)
	)
	var target_coordinate := _clamp_to_hard_bounds(
		coordinate + desired_coordinate_delta
	)
	var bounded_coordinate_delta := target_coordinate - coordinate
	if absf(bounded_coordinate_delta) <= MOTION_EPSILON:
		m_active_signed_input = signed_input
		m_at_hard_stop = true
		_set_blocked(false)
		return stopped

	var world_motion := path_axis * bounded_coordinate_delta
	var clear_fraction := minf(
		_get_object_motion_clear_fraction(world_motion, SWEEP_MARGIN, actor),
		_get_actor_motion_clear_fraction(actor, world_motion, SWEEP_MARGIN)
	)
	clear_fraction = clampf(clear_fraction, 0.0, 1.0)
	if clear_fraction <= MOTION_EPSILON:
		m_active_signed_input = signed_input
		return stopped

	if m_blocked:
		_set_blocked(false)
	var clear_coordinate_delta := bounded_coordinate_delta * clear_fraction
	m_active_signed_input = signed_input
	m_pending_coordinate_delta = clear_coordinate_delta
	var constrained_speed := absf(clear_coordinate_delta) / maxf(delta, 0.000001)
	return CharacterMotionIntent3DScript.new(
		world_motion.normalized(),
		constrained_speed
	)


## Records the actor position immediately before HumanBody3D's one
## move_and_slide() integration.
func before_actor_motion(
	actor: CharacterBody3D,
	_intent: CharacterMotionIntent3DScript,
	_delta: float
) -> void:
	if actor != get_reserved_actor():
		m_motion_frame_active = false
		return
	m_actor_position_before_motion = actor.global_position
	m_motion_frame_active = true


## Advances the object only by the actor's actual progress, then projects both
## participants back onto the authored lane.
func after_actor_motion(
	actor: CharacterBody3D,
	_intent: CharacterMotionIntent3DScript,
	delta: float
) -> void:
	if actor != get_reserved_actor() or !m_motion_frame_active:
		return
	m_motion_frame_active = false
	var path_axis := get_path_axis()
	var actor_progress := (
		actor.global_position - m_actor_position_before_motion
	).dot(path_axis)
	var actual_coordinate_delta := _clamp_actual_progress(
		actor_progress,
		m_pending_coordinate_delta
	)
	var previous_coordinate := _clamp_to_hard_bounds(get_path_coordinate())
	var next_coordinate := _clamp_to_hard_bounds(
		previous_coordinate + actual_coordinate_delta
	)
	_set_path_coordinate(next_coordinate)
	_align_actor_to_anchor(actor)

	var actual_progress := absf(next_coordinate - previous_coordinate)
	if actual_progress > MOTION_EPSILON:
		m_last_valid_coordinate = next_coordinate
	_update_blocked_progress(delta, actual_progress)
	m_pending_coordinate_delta = 0.0
	if (
		auto_complete_at_goal
		and _has_goal()
		and absf(next_coordinate - get_goal_coordinate()) <= (
			GOAL_TOLERANCE + MOTION_EPSILON
		)
	):
		complete_action(actor, {
			"goal_coordinate": get_goal_coordinate(),
		})


func get_active_hint() -> String:
	if m_blocked:
		return "Blocked · R/Esc Release"
	if m_at_hard_stop:
		return "Rail endpoint · R/Esc Release"
	return "W Push · S Pull · R/Esc Release"


func get_animation_action_mode() -> int:
	if m_active_signed_input < 0.0:
		return CharacterActionController3DScript.ActionMode.PULL
	return CharacterActionController3DScript.ActionMode.PUSH


func is_blocked() -> bool:
	return m_blocked


func is_goal_completed() -> bool:
	return m_goal_completed


func has_published_semantic_completion() -> bool:
	return m_semantic_completion_emitted


func get_movable_body() -> CollisionObject3D:
	return get_node_or_null(movable_body_path) as CollisionObject3D


func get_actor_anchor_transform() -> Transform3D:
	var anchor := get_node_or_null(actor_anchor_path) as Node3D
	if is_instance_valid(anchor):
		return anchor.global_transform
	var body := get_movable_body()
	return body.global_transform if is_instance_valid(body) else global_transform


func get_actor_anchor_error(actor: CharacterBody3D) -> float:
	if !is_instance_valid(actor):
		return INF
	return actor.global_position.distance_to(get_actor_anchor_transform().origin)


func get_actor_facing_error_degrees(actor: CharacterBody3D) -> float:
	if !is_instance_valid(actor):
		return INF
	var alignment := clampf(
		_resolve_actor_forward(actor).dot(_resolve_authored_push_axis()),
		-1.0,
		1.0
	)
	return rad_to_deg(acos(alignment))


func get_path_axis() -> Vector3:
	var delta := _get_path_end_position() - _get_path_start_position()
	if delta.length_squared() <= 0.000001:
		return Vector3.RIGHT
	return delta.normalized()


func get_path_length() -> float:
	return _get_path_start_position().distance_to(_get_path_end_position())


func get_path_coordinate() -> float:
	var body := get_movable_body()
	if !is_instance_valid(body):
		return 0.0
	return (
		body.global_position - _get_path_start_position()
	).dot(get_path_axis())


func get_goal_coordinate() -> float:
	var goal := get_node_or_null(goal_path) as Node3D
	if !is_instance_valid(goal):
		return _maximum_coordinate()
	return (
		goal.global_position - _get_path_start_position()
	).dot(get_path_axis())


func get_cross_axis_error() -> float:
	var body := get_movable_body()
	if !is_instance_valid(body):
		return INF
	var expected := (
		_get_path_start_position() + get_path_axis() * get_path_coordinate()
	)
	return body.global_position.distance_to(expected)


func get_last_valid_coordinate() -> float:
	return m_last_valid_coordinate


## Public recovery hook for a world recovery controller. Story state is untouched.
func recover_object(reason: StringName = &"recovery") -> bool:
	if has_reserved_actor():
		cancel_action(get_reserved_actor(), reason)
	_set_path_coordinate(m_last_valid_coordinate)
	return true


## Restores the transient object to its authored scene coordinate. The reset is
## rejected while the expanded authored shape would overlap another body.
func reset_to_authored_origin(reason: StringName = &"reset") -> bool:
	if !_is_coordinate_clear(m_initial_coordinate, RESET_CLEARANCE, null):
		return false
	if has_reserved_actor():
		cancel_action(get_reserved_actor(), reason)
	_set_path_coordinate(m_initial_coordinate)
	m_last_valid_coordinate = m_initial_coordinate
	m_goal_completed = false
	m_out_of_bounds_elapsed = 0.0
	m_required_path_block_elapsed = 0.0
	_clear_transient_motion()
	object_reset.emit(reason)
	return true


## Deterministic author/test setup helper. It preserves the path constraint and
## never changes semantic completion history.
func set_constrained_coordinate(coordinate: float) -> void:
	var accepted := _clamp_to_hard_bounds(coordinate)
	_set_path_coordinate(accepted)
	m_last_valid_coordinate = accepted
	m_goal_completed = false
	if has_reserved_actor():
		_align_actor_to_anchor(get_reserved_actor())


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if path_start_path.is_empty() or path_end_path.is_empty():
		warnings.append("Push/pull requires authored path start and end anchors.")
	var path_length := get_path_length()
	if path_length > MAXIMUM_PATH_LENGTH + MOTION_EPSILON:
		warnings.append("Push/pull paths must not exceed 4.00 m.")
	if path_length <= HARD_ENDPOINT_STOP * 2.0:
		warnings.append("Push/pull path is too short for the 0.10 m endpoint stops.")
	if movable_body_path.is_empty() or movable_collision_shape_path.is_empty():
		warnings.append("Push/pull requires a movable body and collision shape.")
	if handle_path.is_empty() or actor_anchor_path.is_empty():
		warnings.append("Push/pull requires authored handle and actor anchors.")
	if _has_goal():
		var goal_coordinate := get_goal_coordinate()
		if (
			goal_coordinate < _minimum_coordinate() - MOTION_EPSILON
			or goal_coordinate > _maximum_coordinate() + MOTION_EPSILON
		):
			warnings.append("Push/pull goal must lie inside the hard endpoint stops.")
	return warnings


func _begin_actor_sustained_action(actor: CharacterBody3D) -> bool:
	m_actor_state_transition = true
	var accepted := true
	if actor.has_method("begin_sustained_action"):
		accepted = bool(actor.call(
			"begin_sustained_action",
			CharacterActionController3DScript.ActionMode.PUSH,
			self
		))
	else:
		var action_controller_value: Variant = actor.get("action_controller")
		var actor_action_controller := action_controller_value as Object
		if (
			actor_action_controller != null
			and actor_action_controller.has_method("begin_action")
		):
			accepted = bool(actor_action_controller.call(
				"begin_action",
				CharacterActionController3DScript.ActionMode.PUSH,
				self
			))
	m_actor_state_transition = false
	return accepted


func _cancel_actor_sustained_action(actor: CharacterBody3D) -> void:
	m_actor_state_transition = true
	if actor.has_method("cancel_sustained_action"):
		actor.call("cancel_sustained_action", self)
	else:
		var action_controller_value: Variant = actor.get("action_controller")
		var actor_action_controller := action_controller_value as Object
		if (
			actor_action_controller != null
			and actor_action_controller.has_method("cancel_active_action")
		):
			actor_action_controller.call("cancel_active_action")
	m_actor_state_transition = false


func _complete_actor_sustained_action(actor: CharacterBody3D) -> void:
	m_actor_state_transition = true
	if actor.has_method("complete_sustained_action"):
		actor.call("complete_sustained_action", self)
	else:
		var action_controller_value: Variant = actor.get("action_controller")
		var actor_action_controller := action_controller_value as Object
		if (
			actor_action_controller != null
			and actor_action_controller.has_method("complete_active_action")
		):
			actor_action_controller.call("complete_active_action")
	m_actor_state_transition = false


func _get_push_axis() -> Vector3:
	if m_push_axis.length_squared() <= 0.000001:
		m_push_axis = _resolve_authored_push_axis()
	return m_push_axis.normalized()


func _resolve_authored_push_axis() -> Vector3:
	var path_axis := get_path_axis()
	var body := get_movable_body()
	var object_position := (
		body.global_position if is_instance_valid(body) else _get_path_start_position()
	)
	var to_object := object_position - get_actor_anchor_transform().origin
	to_object.y = 0.0
	if to_object.length_squared() <= 0.000001:
		return path_axis
	return path_axis * (1.0 if to_object.dot(path_axis) >= 0.0 else -1.0)


func _has_entry_motion_clearance(actor: CharacterBody3D) -> bool:
	var path_axis := get_path_axis()
	var push_axis := _resolve_authored_push_axis()
	var signed_inputs: Array[float] = [1.0, -1.0]
	for signed_input: float in signed_inputs:
		var world_motion: Vector3 = (
			push_axis * signed_input * BLOCKED_PROGRESS_THRESHOLD
		)
		var coordinate_delta: float = world_motion.dot(path_axis)
		var coordinate := _clamp_to_hard_bounds(get_path_coordinate())
		if absf(
			_clamp_to_hard_bounds(coordinate + coordinate_delta) - coordinate
		) <= MOTION_EPSILON:
			continue
		if (
			_get_object_motion_clear_fraction(world_motion, SWEEP_MARGIN, actor)
			> MOTION_EPSILON
			and _get_actor_motion_clear_fraction(
				actor,
				world_motion,
				SWEEP_MARGIN
			) > MOTION_EPSILON
		):
			return true
	return false


func _align_actor_to_anchor(actor: CharacterBody3D) -> void:
	if !is_instance_valid(actor):
		return
	var anchor_transform := get_actor_anchor_transform()
	var push_axis := _get_push_axis()
	var up := Vector3.UP
	var right := up.cross(push_axis).normalized()
	if right.length_squared() <= 0.000001:
		right = Vector3.RIGHT
	var basis := Basis(right, up, push_axis).orthonormalized()
	actor.global_transform = Transform3D(basis, anchor_transform.origin)
	if actor.has_method("set_direction_vector"):
		actor.call("set_direction_vector", push_axis)


func _clamp_actual_progress(actual: float, requested: float) -> float:
	if absf(requested) <= MOTION_EPSILON:
		return 0.0
	if signf(actual) != signf(requested):
		return 0.0
	return signf(requested) * minf(absf(actual), absf(requested))


func _update_blocked_progress(delta: float, actual_progress: float) -> void:
	if is_zero_approx(m_active_signed_input) or m_at_hard_stop:
		m_progress_window_elapsed = 0.0
		m_progress_window_distance = 0.0
		if m_at_hard_stop:
			_set_blocked(false)
		return
	m_progress_window_elapsed += maxf(delta, 0.0)
	m_progress_window_distance += actual_progress
	if (
		m_progress_window_distance + MOTION_EPSILON
		>= BLOCKED_PROGRESS_THRESHOLD
	):
		_set_blocked(false)
		m_progress_window_elapsed = 0.0
		m_progress_window_distance = 0.0
		return
	if m_progress_window_elapsed + MOTION_EPSILON < BLOCKED_DURATION:
		return
	_set_blocked(true)
	m_progress_window_elapsed = 0.0
	m_progress_window_distance = 0.0


func _set_blocked(blocked: bool) -> void:
	if m_blocked == blocked:
		return
	m_blocked = blocked
	blocked_state_changed.emit(blocked)


func _clear_transient_motion() -> void:
	m_active_signed_input = 0.0
	m_pending_coordinate_delta = 0.0
	m_motion_frame_active = false
	m_progress_window_elapsed = 0.0
	m_progress_window_distance = 0.0
	m_at_hard_stop = false
	_set_blocked(false)


func _monitor_object_recovery(delta: float) -> void:
	var body := get_movable_body()
	if !is_instance_valid(body):
		return
	if body.global_position.y <= (
		m_initial_body_transform.origin.y - DROP_RESET_DISTANCE
	):
		reset_to_authored_origin(&"drop_recovery")
		return

	var raw_coordinate := get_path_coordinate()
	var cross_axis_error := get_cross_axis_error()
	var beyond_bounds := (
		raw_coordinate < _minimum_coordinate() - OUT_OF_BOUNDS_DISTANCE
		or raw_coordinate > _maximum_coordinate() + OUT_OF_BOUNDS_DISTANCE
		or cross_axis_error > OUT_OF_BOUNDS_DISTANCE
	)
	m_out_of_bounds_elapsed = (
		m_out_of_bounds_elapsed + delta if beyond_bounds else 0.0
	)
	if m_out_of_bounds_elapsed + MOTION_EPSILON >= OUT_OF_BOUNDS_DURATION:
		if reset_to_authored_origin(&"bounds_recovery"):
			return

	if !required_path_protection_enabled or !_object_blocks_required_path():
		m_required_path_block_elapsed = 0.0
		return
	m_required_path_block_elapsed += delta
	if (
		m_required_path_block_elapsed + MOTION_EPSILON
		>= REQUIRED_PATH_BLOCK_DURATION
	):
		reset_to_authored_origin(&"required_path_recovery")


func _object_blocks_required_path() -> bool:
	var area := get_node_or_null(required_path_area_path) as Area3D
	var body := get_movable_body()
	if !is_instance_valid(area) or !is_instance_valid(body):
		return false
	return area.overlaps_body(body)


func _get_object_motion_clear_fraction(
	motion: Vector3,
	margin: float,
	actor: CharacterBody3D
) -> float:
	var body := get_movable_body()
	var collision_shape := get_node_or_null(
		movable_collision_shape_path
	) as CollisionShape3D
	if (
		!is_instance_valid(body)
		or !is_instance_valid(collision_shape)
		or collision_shape.shape == null
	):
		return 1.0
	var query_transform := body.global_transform * collision_shape.transform
	var query_shape := _expanded_shape(collision_shape.shape, margin)
	if query_shape != collision_shape.shape:
		query_transform.origin += Vector3.UP * (margin + SHAPE_PROBE_LIFT)
	var excluded: Array[RID] = [body.get_rid()]
	if is_instance_valid(actor):
		excluded.append(actor.get_rid())
	return _cast_shape_motion(
		query_shape,
		query_transform,
		motion,
		body.collision_mask,
		excluded
	)


func _get_actor_motion_clear_fraction(
	actor: CharacterBody3D,
	motion: Vector3,
	margin: float
) -> float:
	if !is_instance_valid(actor):
		return 0.0
	var collision_shape := actor.get_node_or_null(
		"CollisionShape3D"
	) as CollisionShape3D
	if collision_shape == null or collision_shape.shape == null:
		return 0.0 if actor.test_move(actor.global_transform, motion) else 1.0
	var query_transform := actor.global_transform * collision_shape.transform
	var query_shape := _expanded_shape(collision_shape.shape, margin)
	if query_shape != collision_shape.shape:
		query_transform.origin += Vector3.UP * (margin + SHAPE_PROBE_LIFT)
	var excluded: Array[RID] = [actor.get_rid()]
	var body := get_movable_body()
	if is_instance_valid(body):
		excluded.append(body.get_rid())
	return _cast_shape_motion(
		query_shape,
		query_transform,
		motion,
		actor.collision_mask,
		excluded
	)


func _is_coordinate_clear(
	coordinate: float,
	margin: float,
	actor: CharacterBody3D
) -> bool:
	var body := get_movable_body()
	var collision_shape := get_node_or_null(
		movable_collision_shape_path
	) as CollisionShape3D
	if (
		!is_instance_valid(body)
		or !is_instance_valid(collision_shape)
		or collision_shape.shape == null
	):
		return true
	var target_transform := body.global_transform
	target_transform.origin = (
		_get_path_start_position() + get_path_axis() * coordinate
	)
	var query_transform := target_transform * collision_shape.transform
	var query_shape := _expanded_shape(collision_shape.shape, margin)
	if query_shape != collision_shape.shape:
		query_transform.origin += Vector3.UP * (margin + SHAPE_PROBE_LIFT)
	var world := get_world_3d()
	if world == null or world.direct_space_state == null:
		return true
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = query_shape
	query.transform = query_transform
	query.collision_mask = body.collision_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [body.get_rid()]
	if is_instance_valid(actor):
		query.exclude.append(actor.get_rid())
	return world.direct_space_state.intersect_shape(query, 1).is_empty()


func _cast_shape_motion(
	shape: Shape3D,
	transform: Transform3D,
	motion: Vector3,
	collision_mask: int,
	excluded: Array[RID]
) -> float:
	if motion.length_squared() <= 0.000001:
		return 1.0
	var world := get_world_3d()
	if world == null or world.direct_space_state == null:
		return 1.0
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = transform
	query.motion = motion
	query.collision_mask = collision_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = excluded
	var destination_query := PhysicsShapeQueryParameters3D.new()
	destination_query.shape = shape
	destination_query.transform = transform.translated(motion)
	destination_query.collision_mask = collision_mask
	destination_query.collide_with_areas = false
	destination_query.collide_with_bodies = true
	destination_query.exclude = excluded
	if !world.direct_space_state.intersect_shape(destination_query, 1).is_empty():
		return 0.0
	var result := world.direct_space_state.cast_motion(query)
	if result.is_empty():
		return 0.0
	return clampf(float(result[0]), 0.0, 1.0)


func _expanded_shape(source: Shape3D, margin: float) -> Shape3D:
	if margin <= 0.0:
		return source
	var box := source as BoxShape3D
	if box != null:
		var expanded_box := box.duplicate() as BoxShape3D
		expanded_box.size = box.size + Vector3.ONE * margin * 2.0
		return expanded_box
	var capsule := source as CapsuleShape3D
	if capsule != null:
		var expanded_capsule := capsule.duplicate() as CapsuleShape3D
		expanded_capsule.radius = capsule.radius + margin
		expanded_capsule.height = capsule.height + margin * 2.0
		return expanded_capsule
	var sphere := source as SphereShape3D
	if sphere != null:
		var expanded_sphere := sphere.duplicate() as SphereShape3D
		expanded_sphere.radius = sphere.radius + margin
		return expanded_sphere
	return source


func _set_path_coordinate(coordinate: float) -> void:
	var body := get_movable_body()
	if !is_instance_valid(body):
		return
	var constrained := _clamp_to_hard_bounds(coordinate)
	var body_transform := body.global_transform
	body_transform.basis = m_initial_body_transform.basis
	body_transform.origin = (
		_get_path_start_position() + get_path_axis() * constrained
	)
	body.global_transform = body_transform


func _clamp_to_hard_bounds(coordinate: float) -> float:
	return clampf(coordinate, _minimum_coordinate(), _maximum_coordinate())


func _minimum_coordinate() -> float:
	return HARD_ENDPOINT_STOP


func _maximum_coordinate() -> float:
	return maxf(get_path_length() - HARD_ENDPOINT_STOP, HARD_ENDPOINT_STOP)


func _has_goal() -> bool:
	return !goal_path.is_empty() and is_instance_valid(
		get_node_or_null(goal_path) as Node3D
	)


func _get_path_start_position() -> Vector3:
	var anchor := get_node_or_null(path_start_path) as Node3D
	return anchor.global_position if is_instance_valid(anchor) else global_position


func _get_path_end_position() -> Vector3:
	var anchor := get_node_or_null(path_end_path) as Node3D
	if is_instance_valid(anchor):
		return anchor.global_position
	return global_position + global_basis.x * 3.0
