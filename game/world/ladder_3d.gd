class_name Ladder3D
extends CharacterActionTarget3D

## Straight, two-way authored ladder runtime. Ladder state remains scene-local;
## only a settled top dismount can request an optional semantic completion.

enum LadderState {
	IDLE,
	ALIGNING,
	CLIMBING,
}

const EXIT_FLOOR_PROBE_LIFT := 0.04
const EXIT_CLEARANCE_SAFE_FRACTION := 0.999

@export var bottom_mount_path: NodePath
@export var top_mount_path: NodePath
@export var bottom_exit_path: NodePath
@export var top_exit_path: NodePath
@export_range(0.1, 5.0, 0.05) var climb_speed := 1.8
@export_range(0.0, 2.0, 0.01) var alignment_duration := 0.3
@export_range(0.1, 2.0, 0.05) var endpoint_clearance := 0.75
@export_range(0.05, 1.0, 0.05) var blocked_retreat_distance := 0.3

var m_state := LadderState.IDLE
var m_alignment_elapsed := 0.0
var m_alignment_start := Transform3D.IDENTITY
var m_mount_transform := Transform3D.IDENTITY


func _init() -> void:
	interaction_range = 0.9
	facing_tolerance_degrees = 20.0


func _ready() -> void:
	sustained_action = true
	set_physics_process(false)


func get_action_anchor_transform(actor: CharacterBody3D = null) -> Transform3D:
	if !is_instance_valid(actor):
		return _get_bottom_mount_transform()
	var bottom := _get_bottom_mount_transform()
	var top := _get_top_mount_transform()
	if _flat_distance(actor.global_position, top.origin) < _flat_distance(
		actor.global_position,
		bottom.origin
	):
		return top
	return bottom


func is_action_available(actor: CharacterBody3D) -> bool:
	if !action_enabled or !is_instance_valid(actor):
		return false
	if has_reserved_actor() and get_reserved_actor() != actor:
		return false
	if !_actor_is_free(actor) and get_reserved_actor() != actor:
		return false
	var mount_transform := get_action_anchor_transform(actor)
	if _flat_distance(actor.global_position, mount_transform.origin) > interaction_range:
		return false
	if absf(actor.global_position.y - mount_transform.origin.y) > max_vertical_delta:
		return false
	return (
		_facing_alignment_to_transform(actor, mount_transform) + FACING_ALIGNMENT_EPSILON
		>= cos(deg_to_rad(facing_tolerance_degrees))
	)


func begin_action(actor: CharacterBody3D) -> bool:
	if !is_action_available(actor):
		return false
	var mounting_from_top := _nearest_mount_is_top(actor)
	m_mount_transform = (
		_get_top_mount_transform() if mounting_from_top else _get_bottom_mount_transform()
	)
	var alignment_start := actor.global_transform
	if !super.begin_action(actor):
		return false
	if !_begin_actor_ladder(actor, m_mount_transform):
		super.cancel_action(actor, &"mount_rejected")
		return false
	m_state = LadderState.ALIGNING
	m_alignment_elapsed = 0.0
	m_alignment_start = alignment_start
	# HumanBody3D may snap to the authored mount while entering ladder mode.
	# Ladder3D owns the accepted 0.30-second alignment, so restore the entry
	# transform and blend deterministically while the actor is movement-locked.
	actor.global_transform = alignment_start
	set_physics_process(true)
	return true


func cancel_action(actor: CharacterBody3D, reason: StringName = &"cancel") -> void:
	if actor != get_reserved_actor():
		return
	set_physics_process(false)
	m_state = LadderState.IDLE
	_cancel_actor_ladder(actor, m_mount_transform)
	super.cancel_action(actor, reason)


func get_active_hint() -> String:
	if m_state == LadderState.ALIGNING:
		return "Esc Return to ladder mount"
	return "W/S Climb · Esc Return to mount"


func get_ladder_state() -> LadderState:
	return m_state


func is_mounted() -> bool:
	return m_state != LadderState.IDLE and has_reserved_actor()


func get_climb_progress() -> float:
	var actor := get_reserved_actor()
	if !is_instance_valid(actor):
		return 0.0
	var bottom := _get_bottom_mount_transform().origin
	var top := _get_top_mount_transform().origin
	var axis_delta := top - bottom
	var ladder_length := axis_delta.length()
	if ladder_length <= 0.001:
		return 0.0
	return clampf((actor.global_position - bottom).dot(axis_delta / ladder_length) / ladder_length, 0.0, 1.0)


func _physics_process(delta: float) -> void:
	var actor := get_reserved_actor()
	if !is_instance_valid(actor):
		_clear_orphaned_reservation()
		return
	match m_state:
		LadderState.ALIGNING:
			_process_alignment(actor, delta)
		LadderState.CLIMBING:
			_process_climb(actor, delta)


func _process_alignment(actor: CharacterBody3D, delta: float) -> void:
	m_alignment_elapsed += delta
	var blend := 1.0
	if alignment_duration > 0.0:
		blend = clampf(m_alignment_elapsed / alignment_duration, 0.0, 1.0)
	actor.global_transform = m_alignment_start.interpolate_with(m_mount_transform, blend)
	if blend < 1.0:
		return
	actor.global_transform = m_mount_transform
	m_state = LadderState.CLIMBING


func _process_climb(actor: CharacterBody3D, delta: float) -> void:
	var signed_input := _resolve_climb_input(actor)
	if is_zero_approx(signed_input):
		_apply_actor_ladder_motion(actor, 0.0, delta)
		return

	var bottom := _get_bottom_mount_transform()
	var top := _get_top_mount_transform()
	var axis_delta := top.origin - bottom.origin
	var ladder_length := axis_delta.length()
	if ladder_length <= 0.001:
		cancel_action(actor, &"invalid_path")
		return
	var climb_axis := axis_delta / ladder_length
	_apply_actor_ladder_motion(actor, signed_input, delta)
	var progress := clampf(
		(actor.global_position - bottom.origin).dot(climb_axis),
		0.0,
		ladder_length
	)
	var aligned_position := bottom.origin + climb_axis * progress
	_move_actor_to_ladder_position(actor, aligned_position)

	var reached_top := progress >= ladder_length - 0.001 and signed_input > 0.0
	var reached_bottom := progress <= 0.001 and signed_input < 0.0
	if reached_top:
		_try_dismount(actor, true, climb_axis)
	elif reached_bottom:
		_try_dismount(actor, false, climb_axis)


func _try_dismount(actor: CharacterBody3D, at_top: bool, climb_axis: Vector3) -> void:
	var exit_transform := _get_top_exit_transform() if at_top else _get_bottom_exit_transform()
	if !_is_exit_clear(actor, exit_transform):
		var retreat_direction := -climb_axis if at_top else climb_axis
		var retreat_position := actor.global_position + retreat_direction * blocked_retreat_distance
		var bottom_origin := _get_bottom_mount_transform().origin
		var top_origin := _get_top_mount_transform().origin
		var ladder_length := bottom_origin.distance_to(top_origin)
		var retreat_progress := clampf(
			(retreat_position - bottom_origin).dot(climb_axis),
			0.0,
			ladder_length
		)
		_move_actor_to_ladder_position(
			actor,
			bottom_origin + climb_axis * retreat_progress
		)
		return

	set_physics_process(false)
	m_state = LadderState.IDLE
	_finish_actor_ladder(actor, exit_transform)
	var completion_context := {
		"direction": "up" if at_top else "down",
		"settled_endpoint": "top" if at_top else "bottom",
	}
	if at_top:
		super.complete_action(actor, completion_context)
	else:
		var saved_semantic_id := semantic_completion_id
		semantic_completion_id = &""
		super.complete_action(actor, completion_context)
		semantic_completion_id = saved_semantic_id


func _begin_actor_ladder(actor: CharacterBody3D, mount_transform: Transform3D) -> bool:
	var climb_axis := _resolve_climb_axis()
	if actor.has_method("begin_ladder"):
		return bool(actor.call("begin_ladder", mount_transform, climb_axis))
	return true


func _apply_actor_ladder_motion(
	actor: CharacterBody3D,
	signed_input: float,
	delta: float
) -> void:
	if actor.has_method("apply_ladder_motion"):
		actor.call("apply_ladder_motion", signed_input, delta, climb_speed)
		return
	var target_position := actor.global_position + _resolve_climb_axis() * (
		signed_input * climb_speed * delta
	)
	if actor.has_method("move_on_ladder"):
		actor.call("move_on_ladder", target_position, climb_speed)
	else:
		actor.global_position = target_position


func _move_actor_to_ladder_position(actor: CharacterBody3D, target_position: Vector3) -> void:
	if actor.has_method("apply_ladder_motion"):
		# apply_ladder_motion already performed the actor's one physics integration
		# for this tick. Projection back to the authored straight path is a
		# constraint correction, not a second movement integration.
		actor.global_position = target_position
	elif actor.has_method("move_on_ladder"):
		actor.call("move_on_ladder", target_position, climb_speed)
	else:
		actor.global_position = target_position


func _finish_actor_ladder(actor: CharacterBody3D, exit_transform: Transform3D) -> void:
	if actor.has_method("finish_ladder"):
		actor.call("finish_ladder", exit_transform)
	else:
		actor.global_transform = exit_transform


func _cancel_actor_ladder(actor: CharacterBody3D, mount_transform: Transform3D) -> void:
	if actor.has_method("cancel_ladder"):
		actor.call("cancel_ladder", mount_transform)
	else:
		actor.global_transform = mount_transform


func _resolve_climb_input(actor: CharacterBody3D) -> float:
	var controller_value: Variant = actor.get("controller")
	var controller := controller_value as Object
	if controller != null:
		for method_name in [
			"get_ladder_input",
			"get_vertical_action_input",
			"get_movement_input",
		]:
			if controller.has_method(method_name):
				var input_value: Variant = controller.call(method_name)
				if input_value is float or input_value is int:
					return clampf(float(input_value), -1.0, 1.0)
				if input_value is Vector2:
					return clampf(-(input_value as Vector2).y, -1.0, 1.0)
	return Input.get_axis("ui_down", "ui_up")


func _is_exit_clear(actor: CharacterBody3D, exit_transform: Transform3D) -> bool:
	var motion := exit_transform.origin - actor.global_position
	if motion.length() < endpoint_clearance:
		var fallback_direction := motion.normalized() if motion.length_squared() > 0.000001 else (
			exit_transform.basis.z.normalized()
		)
		motion = fallback_direction * endpoint_clearance

	var probe_transform := actor.global_transform
	probe_transform.origin += Vector3.UP * EXIT_FLOOR_PROBE_LIFT
	var collision_shape := actor.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape == null or collision_shape.shape == null:
		return !actor.test_move(probe_transform, motion)
	var world := actor.get_world_3d()
	if world == null or world.direct_space_state == null:
		return !actor.test_move(probe_transform, motion)

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collision_shape.shape
	query.transform = probe_transform * collision_shape.transform
	query.motion = motion
	query.collision_mask = actor.collision_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [actor.get_rid()]
	var clearance := world.direct_space_state.cast_motion(query)
	return !clearance.is_empty() and clearance[0] >= EXIT_CLEARANCE_SAFE_FRACTION


func _get_bottom_mount_transform() -> Transform3D:
	return _resolve_authored_transform(bottom_mount_path, global_transform)


func _get_top_mount_transform() -> Transform3D:
	var fallback := global_transform.translated_local(Vector3.UP * 3.2)
	return _resolve_authored_transform(top_mount_path, fallback)


func _get_bottom_exit_transform() -> Transform3D:
	return _resolve_authored_transform(bottom_exit_path, _get_bottom_mount_transform())


func _get_top_exit_transform() -> Transform3D:
	return _resolve_authored_transform(top_exit_path, _get_top_mount_transform())


func _resolve_authored_transform(path: NodePath, fallback: Transform3D) -> Transform3D:
	if !path.is_empty():
		var anchor := get_node_or_null(path) as Node3D
		if is_instance_valid(anchor):
			return anchor.global_transform
	return fallback


func _resolve_climb_axis() -> Vector3:
	var delta := _get_top_mount_transform().origin - _get_bottom_mount_transform().origin
	return delta.normalized() if delta.length_squared() > 0.000001 else Vector3.UP


func _nearest_mount_is_top(actor: CharacterBody3D) -> bool:
	return _flat_distance(actor.global_position, _get_top_mount_transform().origin) < _flat_distance(
		actor.global_position,
		_get_bottom_mount_transform().origin
	)


func _facing_alignment_to_transform(
	actor: CharacterBody3D,
	mount_transform: Transform3D
) -> float:
	var to_mount := mount_transform.origin - actor.global_position
	to_mount.y = 0.0
	if to_mount.length_squared() <= 0.000001:
		return 1.0
	return clampf(
		_resolve_actor_forward(actor).dot(to_mount.normalized()),
		-1.0,
		1.0
	)


func _clear_orphaned_reservation() -> void:
	set_physics_process(false)
	m_state = LadderState.IDLE
	m_reserved_actor = null


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
