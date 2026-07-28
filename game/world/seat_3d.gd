class_name Seat3D
extends CharacterActionTarget3D

## Authored sitting target with deterministic occupancy, alignment, listening,
## exit-search, and cleanup behavior. The seat never owns camera or story state.

signal seat_alignment_completed(actor: CharacterBody3D)
signal seat_exit_started(actor: CharacterBody3D, reason: StringName)
signal seat_vacated(actor: CharacterBody3D, reason: StringName)
signal listening_completed(event_id: StringName, context: Dictionary)

enum SeatState {
	IDLE,
	ALIGNING,
	SEATED,
	EXITING,
}

const SIT_ACTION_MODE := 4
const ENTRY_RANGE := 1.10
const ENTRY_GATE_EPSILON := 0.00001
const ENTRY_ALIGNMENT_DURATION := 0.35
const EXIT_ALIGNMENT_DURATION := 0.30
const PRIMARY_EXIT_DISTANCE := 0.90
const OCCUPIED_CAPSULE_MARGIN := 0.10
const CAPSULE_FLOOR_LIFT := 0.01
const EXIT_SUPPORT_PROBE_UP := 0.15
const EXIT_SUPPORT_PROBE_DOWN := 0.35
const EXIT_SUPPORT_MINIMUM_NORMAL_Y := 0.70
const EXIT_RADII: Array[float] = [0.75, 1.00, 1.25]
const EXIT_DIRECTION_COUNT := 8
const TRANSFORM_EPSILON := 0.000001

@export var seat_anchor_path: NodePath
@export var primary_exit_path: NodePath
@export_range(0.0, 1.0, 0.01) var entry_alignment_duration := (
	ENTRY_ALIGNMENT_DURATION
)
@export_range(0.0, 1.0, 0.01) var exit_alignment_duration := (
	EXIT_ALIGNMENT_DURATION
)
@export_range(0.0, 30.0, 0.05) var listening_duration := 4.0
@export_range(0.0, 0.5, 0.01) var occupied_capsule_margin := (
	OCCUPIED_CAPSULE_MARGIN
)

var m_state := SeatState.IDLE
var m_occupant: CharacterBody3D = null
var m_alignment_elapsed := 0.0
var m_alignment_start := Transform3D.IDENTITY
var m_alignment_target := Transform3D.IDENTITY
var m_exit_reason: StringName = &"exit"
var m_listening_elapsed := 0.0
var m_semantic_completion_published := false
var m_notifying_actor := false
var m_has_session_transforms := false
var m_session_seat_transform := Transform3D.IDENTITY
var m_session_primary_exit_transform := Transform3D.IDENTITY


func _init() -> void:
	action_id = &"sit"
	action_label = "Sit"
	interaction_range = ENTRY_RANGE
	sustained_action = true


func _ready() -> void:
	sustained_action = true
	set_physics_process(false)


func get_action_anchor() -> Node3D:
	return get_seat_anchor()


func get_seat_anchor() -> Node3D:
	if !seat_anchor_path.is_empty():
		var anchor := get_node_or_null(seat_anchor_path) as Node3D
		if is_instance_valid(anchor):
			return anchor
	return self


func get_seat_transform() -> Transform3D:
	var anchor := get_seat_anchor()
	if is_instance_valid(anchor) and anchor.is_inside_tree():
		return anchor.global_transform
	if m_has_session_transforms:
		return m_session_seat_transform
	return global_transform if is_inside_tree() else Transform3D.IDENTITY


func get_primary_exit_transform() -> Transform3D:
	if !primary_exit_path.is_empty():
		var anchor := get_node_or_null(primary_exit_path) as Node3D
		if is_instance_valid(anchor) and anchor.is_inside_tree():
			return anchor.global_transform
	if m_has_session_transforms and !is_inside_tree():
		return m_session_primary_exit_transform
	return get_seat_transform().translated_local(
		Vector3.BACK * PRIMARY_EXIT_DISTANCE
	)


func get_seat_state() -> SeatState:
	return m_state


func is_occupied() -> bool:
	return is_instance_valid(m_occupant)


func get_occupant() -> CharacterBody3D:
	return m_occupant


func has_published_listening_completion() -> bool:
	return m_semantic_completion_published


func get_listening_elapsed() -> float:
	return m_listening_elapsed


func is_action_available(actor: CharacterBody3D) -> bool:
	if !action_enabled or !is_instance_valid(actor):
		return false
	if is_occupied() and m_occupant != actor:
		return false
	if (
		actor.has_method("is_grounded")
		and !bool(actor.call("is_grounded"))
		and m_occupant != actor
	):
		return false
	if has_reserved_actor() and get_reserved_actor() != actor:
		return false
	if get_action_distance(actor) > interaction_range + ENTRY_GATE_EPSILON:
		return false
	if get_vertical_delta(actor) > max_vertical_delta + ENTRY_GATE_EPSILON:
		return false
	if !is_within_facing_gate(actor):
		return false
	if !_actor_is_free(actor) and get_reserved_actor() != actor:
		return false
	if m_occupant == actor:
		return true
	return _is_capsule_clear_at(actor, get_seat_transform())


func begin_action(actor: CharacterBody3D) -> bool:
	# CharacterActionController3D may call the target hook while the outer seat
	# begin is registering the same sustained action.
	if m_notifying_actor and actor == m_occupant:
		return true
	if m_state != SeatState.IDLE or is_occupied():
		return false
	if !is_action_available(actor):
		return false

	var entry_start := actor.global_transform
	m_session_seat_transform = get_seat_transform()
	m_session_primary_exit_transform = get_primary_exit_transform()
	m_has_session_transforms = true
	if !super.begin_action(actor):
		m_has_session_transforms = false
		return false
	m_occupant = actor
	m_state = SeatState.ALIGNING
	m_alignment_elapsed = 0.0
	m_alignment_start = entry_start
	m_alignment_target = get_seat_transform()
	m_listening_elapsed = 0.0
	_lock_actor_motion(actor)
	set_physics_process(true)

	if !_begin_actor_sustained_action(actor):
		_release_occupant_immediately(actor, &"action_rejected", false)
		return false
	return true


## Active R input exits the seat instead of selecting a new contextual target.
func request_active_context_action(actor: CharacterBody3D) -> bool:
	if actor != m_occupant:
		return false
	return request_exit(actor, &"context_action")


## Movement remains locked while aligning, seated, or exiting. The world/actor
## integration calls this before its single motion integration.
func constrain_motion_intent(
	actor: CharacterBody3D,
	intent: CharacterMotionIntent3D,
	_delta: float
) -> CharacterMotionIntent3D:
	if actor != m_occupant:
		return intent
	var constrained_intent := intent
	if constrained_intent == null:
		constrained_intent = CharacterMotionIntent3D.new()
	constrained_intent.direction = Vector3.ZERO
	constrained_intent.movement_speed = 0.0
	return constrained_intent


func before_actor_motion(
	actor: CharacterBody3D,
	_intent: CharacterMotionIntent3D,
	_delta: float
) -> void:
	if actor == m_occupant:
		_lock_actor_motion(actor)


func after_actor_motion(
	actor: CharacterBody3D,
	_intent: CharacterMotionIntent3D,
	_delta: float
) -> void:
	if actor != m_occupant:
		return
	_lock_actor_motion(actor)
	if m_state == SeatState.SEATED:
		actor.global_transform = get_seat_transform()


func request_exit(
	actor: CharacterBody3D,
	reason: StringName = &"exit"
) -> bool:
	if actor != m_occupant or m_state == SeatState.EXITING:
		return false
	var exit_transform := find_clear_exit_transform(actor)
	if exit_transform == Transform3D.IDENTITY:
		_release_occupant_immediately(actor, &"recovery", false)
		if actor.has_method("recover_to_safe_transform"):
			actor.call("recover_to_safe_transform")
		return true
	_begin_exit(actor, exit_transform, reason)
	return true


func cancel_action(
	actor: CharacterBody3D,
	reason: StringName = &"cancel"
) -> void:
	if m_notifying_actor:
		return
	if actor != m_occupant:
		return
	# Automatic actor recovery/teardown clears CharacterActionController3D
	# before invoking the target hook. Do not start an exit blend that could pull
	# the actor away from its safe transform on the following recovery step.
	var actor_action_already_cleared := (
		actor.has_method("is_action_free")
		and bool(actor.call("is_action_free"))
	)
	if reason == &"recovery" or actor_action_already_cleared:
		_release_occupant_immediately(actor, reason, false)
		return

	var exit_transform := find_clear_exit_transform(actor)
	if exit_transform == Transform3D.IDENTITY:
		_release_occupant_immediately(actor, &"recovery", false)
		if actor.has_method("recover_to_safe_transform"):
			actor.call("recover_to_safe_transform")
		return

	if reason in [&"pause", &"scene_unload"]:
		actor.global_transform = exit_transform
		_release_occupant_immediately(actor, reason, true)
		return
	_begin_exit(actor, exit_transform, reason)


func complete_action(
	actor: CharacterBody3D,
	context: Dictionary = {}
) -> void:
	if m_notifying_actor or actor != m_occupant:
		return
	_publish_listening_completion(context)
	request_exit(actor, &"complete")


## Candidate order is part of the deterministic contract: authored primary exit,
## then eight outward directions at 0.75, 1.00, and 1.25 metres.
func get_exit_search_candidates() -> Array[Transform3D]:
	var candidates: Array[Transform3D] = [get_primary_exit_transform()]
	var seat_transform := get_seat_transform()
	for radius in EXIT_RADII:
		for direction_index in range(EXIT_DIRECTION_COUNT):
			var angle := TAU * float(direction_index) / float(EXIT_DIRECTION_COUNT)
			var candidate := seat_transform
			candidate.basis = seat_transform.basis.rotated(Vector3.UP, angle)
			candidate.origin = (
				seat_transform.origin
				+ candidate.basis.z.normalized() * radius
			)
			candidates.append(candidate)
	return candidates


func find_clear_exit_transform(actor: CharacterBody3D) -> Transform3D:
	if !is_instance_valid(actor):
		return Transform3D.IDENTITY
	for candidate in get_exit_search_candidates():
		if _is_exit_candidate_clear(actor, candidate):
			return candidate
	return Transform3D.IDENTITY


func get_active_hint() -> String:
	match m_state:
		SeatState.ALIGNING:
			return "R / Esc Stand"
		SeatState.SEATED:
			return "R / Esc Stand · Camera remains available"
		SeatState.EXITING:
			return "Standing…"
		_:
			return "R Sit"


func _physics_process(delta: float) -> void:
	var actor := m_occupant
	if !is_instance_valid(actor):
		_clear_orphaned_occupancy()
		return
	_lock_actor_motion(actor)
	match m_state:
		SeatState.ALIGNING:
			_process_alignment(actor, delta)
		SeatState.SEATED:
			_process_seated(actor, delta)
		SeatState.EXITING:
			_process_exit(actor, delta)


func _process_alignment(actor: CharacterBody3D, delta: float) -> void:
	m_alignment_elapsed += maxf(delta, 0.0)
	var blend := 1.0
	if entry_alignment_duration > 0.0:
		blend = clampf(
			m_alignment_elapsed / entry_alignment_duration,
			0.0,
			1.0
		)
	actor.global_transform = m_alignment_start.interpolate_with(
		m_alignment_target,
		blend
	)
	if blend < 1.0:
		return
	actor.global_transform = m_alignment_target
	m_state = SeatState.SEATED
	m_alignment_elapsed = 0.0
	seat_alignment_completed.emit(actor)


func _process_seated(actor: CharacterBody3D, delta: float) -> void:
	actor.global_transform = get_seat_transform()
	if m_semantic_completion_published:
		return
	m_listening_elapsed += maxf(delta, 0.0)
	if m_listening_elapsed + TRANSFORM_EPSILON < listening_duration:
		return
	_publish_listening_completion({
		"listening_duration": listening_duration,
		"seat_name": name,
	})


func _process_exit(actor: CharacterBody3D, delta: float) -> void:
	m_alignment_elapsed += maxf(delta, 0.0)
	var blend := 1.0
	if exit_alignment_duration > 0.0:
		blend = clampf(
			m_alignment_elapsed / exit_alignment_duration,
			0.0,
			1.0
		)
	actor.global_transform = m_alignment_start.interpolate_with(
		m_alignment_target,
		blend
	)
	if blend < 1.0:
		return
	actor.global_transform = m_alignment_target
	_release_occupant_immediately(actor, m_exit_reason, true)


func _begin_exit(
	actor: CharacterBody3D,
	exit_transform: Transform3D,
	reason: StringName
) -> void:
	m_state = SeatState.EXITING
	m_alignment_elapsed = 0.0
	m_alignment_start = actor.global_transform
	m_alignment_target = exit_transform
	m_exit_reason = reason
	_lock_actor_motion(actor)
	seat_exit_started.emit(actor, reason)


func _publish_listening_completion(extra_context: Dictionary = {}) -> void:
	if m_semantic_completion_published or semantic_completion_id.is_empty():
		return
	m_semantic_completion_published = true
	var context := extra_context.duplicate(true)
	context["action_id"] = String(action_id)
	context["listening_duration"] = listening_duration
	context["seat_name"] = name
	semantic_completion_requested.emit(semantic_completion_id, context)
	listening_completed.emit(semantic_completion_id, context.duplicate(true))


func _begin_actor_sustained_action(actor: CharacterBody3D) -> bool:
	if actor.has_method("begin_sustained_action"):
		m_notifying_actor = true
		var accepted := bool(actor.call(
			"begin_sustained_action",
			SIT_ACTION_MODE,
			self
		))
		m_notifying_actor = false
		return accepted
	var controller_value: Variant = actor.get("action_controller")
	var action_controller := controller_value as Object
	if action_controller == null or !action_controller.has_method("begin_action"):
		return true
	m_notifying_actor = true
	var fallback_accepted := bool(action_controller.call(
		"begin_action",
		SIT_ACTION_MODE,
		self
	))
	m_notifying_actor = false
	return fallback_accepted


func _release_occupant_immediately(
	actor: CharacterBody3D,
	reason: StringName,
	record_safe_transform: bool
) -> void:
	set_physics_process(false)
	_lock_actor_motion(actor)
	if record_safe_transform and actor.has_method("set_safe_transform"):
		actor.call("set_safe_transform", actor.global_transform)

	m_notifying_actor = true
	if actor.has_method("cancel_sustained_action"):
		actor.call("cancel_sustained_action", self)
	else:
		var controller_value: Variant = actor.get("action_controller")
		var action_controller := controller_value as Object
		if (
			action_controller != null
			and action_controller.has_method("cancel_active_action")
		):
			action_controller.call("cancel_active_action")
	super.cancel_action(actor, reason)
	m_notifying_actor = false

	var released_actor := m_occupant
	m_occupant = null
	m_state = SeatState.IDLE
	m_alignment_elapsed = 0.0
	m_alignment_start = Transform3D.IDENTITY
	m_alignment_target = Transform3D.IDENTITY
	m_exit_reason = &"exit"
	m_listening_elapsed = 0.0
	m_has_session_transforms = false
	m_session_seat_transform = Transform3D.IDENTITY
	m_session_primary_exit_transform = Transform3D.IDENTITY
	if is_instance_valid(released_actor):
		seat_vacated.emit(released_actor, reason)


func _clear_orphaned_occupancy() -> void:
	set_physics_process(false)
	m_reserved_actor = null
	m_occupant = null
	m_state = SeatState.IDLE
	m_alignment_elapsed = 0.0
	m_listening_elapsed = 0.0
	m_has_session_transforms = false
	m_session_seat_transform = Transform3D.IDENTITY
	m_session_primary_exit_transform = Transform3D.IDENTITY


func _lock_actor_motion(actor: CharacterBody3D) -> void:
	actor.velocity = Vector3.ZERO
	actor.set("is_walking", false)
	actor.set("is_running", false)


func _is_exit_candidate_clear(
	actor: CharacterBody3D,
	candidate: Transform3D
) -> bool:
	return (
		_is_capsule_clear_at(actor, candidate)
		and _has_supported_exit_floor(actor, candidate.origin)
	)


func _is_capsule_clear_at(
	actor: CharacterBody3D,
	target_transform: Transform3D
) -> bool:
	var collision_shape := actor.get_node_or_null(
		"CollisionShape3D"
	) as CollisionShape3D
	if collision_shape == null or collision_shape.shape == null:
		var motion := target_transform.origin - actor.global_position
		return !actor.test_move(actor.global_transform, motion)

	var world := actor.get_world_3d()
	if world == null or world.direct_space_state == null:
		var fallback_motion := target_transform.origin - actor.global_position
		return !actor.test_move(actor.global_transform, fallback_motion)

	var query_shape := _build_expanded_capsule(collision_shape.shape)
	var query_transform := target_transform * collision_shape.transform
	if query_shape != collision_shape.shape:
		# Expansion adds equal head/foot clearance. Lift by the lower half so the
		# planted foot does not penetrate the support floor.
		query_transform.origin += Vector3.UP * (
			occupied_capsule_margin + CAPSULE_FLOOR_LIFT
		)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = query_shape
	query.transform = query_transform
	query.collision_mask = actor.collision_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [actor.get_rid()]
	return world.direct_space_state.intersect_shape(query, 8).is_empty()


func _build_expanded_capsule(source_shape: Shape3D) -> Shape3D:
	var capsule := source_shape as CapsuleShape3D
	if capsule == null or occupied_capsule_margin <= 0.0:
		return source_shape
	var expanded := capsule.duplicate() as CapsuleShape3D
	expanded.radius = capsule.radius + occupied_capsule_margin
	expanded.height = capsule.height + occupied_capsule_margin * 2.0
	return expanded


func _has_supported_exit_floor(
	actor: CharacterBody3D,
	exit_origin: Vector3
) -> bool:
	var world := actor.get_world_3d()
	if world == null or world.direct_space_state == null:
		return true
	var query := PhysicsRayQueryParameters3D.create(
		exit_origin + Vector3.UP * EXIT_SUPPORT_PROBE_UP,
		exit_origin - Vector3.UP * EXIT_SUPPORT_PROBE_DOWN,
		actor.collision_mask,
		[actor.get_rid()]
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var result := world.direct_space_state.intersect_ray(query)
	if result.is_empty():
		return false
	var normal_value: Variant = result.get("normal", Vector3.ZERO)
	return normal_value is Vector3 and (
		normal_value as Vector3
	).y >= EXIT_SUPPORT_MINIMUM_NORMAL_Y
