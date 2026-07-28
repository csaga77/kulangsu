class_name CarryableObject3D
extends CharacterActionTarget3D

## Typed, story-free light/medium carryable. The object owns pickup clearance,
## actor-socket attachment, carried-envelope motion validation, authored placement,
## and deterministic reset. Story meaning remains the inherited semantic signal.

enum CarryWeight {
	LIGHT,
	MEDIUM,
	HEAVY,
}

signal carry_blocked_changed(blocked: bool)
signal placed(target: CarryPlacementTarget3D)

const CARRY_ACTION_MODE := 1
const PICKUP_RANGE := 1.10
const PICKUP_VERTICAL_DELTA := 0.65
const PICKUP_SWEEP_RADIUS := 0.05
const LIGHT_MOVEMENT_SPEED := 3.20
const LIGHT_TURN_RATE_DEGREES := 180.0
const LIGHT_SOCKET_FORWARD := 0.45
const LIGHT_SOCKET_HEIGHT := 1.05
const LIGHT_MAXIMUM_BOUNDS := Vector3(0.55, 0.55, 0.55)
const MEDIUM_MOVEMENT_SPEED := 2.40
const MEDIUM_TURN_RATE_DEGREES := 120.0
const MEDIUM_SOCKET_FORWARD := 0.50
const MEDIUM_SOCKET_HEIGHT := 0.90
const MEDIUM_MAXIMUM_BOUNDS := Vector3(0.75, 0.55, 0.55)
const WORLD_SWEEP_MARGIN := 0.08
const DOORWAY_WIDTH_MARGIN := 0.20
const DOORWAY_HEIGHT_MARGIN := 0.15
const PLACEMENT_SUPPORT_SLOPE_DEGREES := 10.0
const PLACEMENT_SUPPORT_COVERAGE := 0.80
const PLACEMENT_SUPPORT_SAMPLE_COUNT := 5
const PLACEMENT_SUPPORT_PROBE_UP := 0.04
const PLACEMENT_SUPPORT_PROBE_DOWN := 0.12
const MOTION_CLEARANCE_SAFE_FRACTION := 0.999
const OUT_OF_BOUNDS_DROP_DISTANCE := 2.00
const OUT_OF_BOUNDS_MARGIN := 0.50
const OUT_OF_BOUNDS_DURATION := 0.25

@export var carry_weight := CarryWeight.LIGHT
@export var carried_bounds := Vector3(0.50, 0.35, 0.30)
@export var pickup_handle_path: NodePath
@export var socket_rotation_degrees := Vector3.ZERO
@export_flags_3d_physics var clearance_collision_mask := 1
@export var reset_half_extents := Vector3(6.0, 3.0, 6.0)
@export var reset_when_out_of_bounds := true

var m_held_actor: CharacterBody3D = null
var m_last_safe_transform := Transform3D.IDENTITY
var m_authored_origin_transform := Transform3D.IDENTITY
var m_has_authored_origin := false
var m_is_placed := false
var m_blocked := false
var m_action_transition_guard := false
var m_out_of_bounds_elapsed := 0.0
var m_collision_shapes: Array[CollisionShape3D] = []
var m_collision_shape_enabled_states: Array[bool] = []


func _init() -> void:
	action_id = &"carry"
	action_label = "Pick up"
	interaction_range = PICKUP_RANGE
	max_vertical_delta = PICKUP_VERTICAL_DELTA
	sustained_action = true


func _ready() -> void:
	if !m_has_authored_origin:
		m_authored_origin_transform = global_transform
		m_last_safe_transform = global_transform
		m_has_authored_origin = true
	set_physics_process(reset_when_out_of_bounds)


func _exit_tree() -> void:
	if is_instance_valid(m_held_actor):
		cancel_action(m_held_actor, &"scene_unload")
	super._exit_tree()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED and is_instance_valid(m_held_actor):
		cancel_action(m_held_actor, &"pause")


func get_pickup_handle() -> Node3D:
	if !pickup_handle_path.is_empty():
		var handle := get_node_or_null(pickup_handle_path) as Node3D
		if is_instance_valid(handle):
			return handle
	return self


func get_action_anchor() -> Node3D:
	return get_pickup_handle()


func is_action_available(actor: CharacterBody3D) -> bool:
	if carry_weight == CarryWeight.HEAVY or m_is_placed:
		return false
	if (
		!_has_accepted_bounds()
		or !action_enabled
		or !is_instance_valid(actor)
		or (
			has_reserved_actor()
			and get_reserved_actor() != actor
		)
		or (
			!_actor_is_free(actor)
			and get_reserved_actor() != actor
		)
		or get_action_distance(actor) > PICKUP_RANGE + 0.00001
		or get_vertical_delta(actor) > PICKUP_VERTICAL_DELTA + 0.00001
		or !is_within_facing_gate(actor)
	):
		return false
	return _has_clear_pickup_sweep(actor)


func begin_action(actor: CharacterBody3D) -> bool:
	if m_action_transition_guard:
		return actor == get_reserved_actor()
	if !is_action_available(actor) or !super.begin_action(actor):
		return false
	m_action_transition_guard = true
	var actor_accepted := (
		actor.has_method("begin_sustained_action")
		and bool(actor.call("begin_sustained_action", CARRY_ACTION_MODE, self))
	)
	m_action_transition_guard = false
	if !actor_accepted:
		super.cancel_action(actor, &"actor_rejected")
		return false
	m_held_actor = actor
	m_last_safe_transform = global_transform
	_cache_and_disable_collision()
	_sync_to_actor_socket(actor)
	return true


func cancel_action(
	actor: CharacterBody3D,
	reason: StringName = &"cancel"
) -> void:
	if m_action_transition_guard or actor != get_reserved_actor():
		return
	m_action_transition_guard = true
	_restore_last_safe_transform()
	m_held_actor = null
	if actor.has_method("cancel_sustained_action"):
		actor.call("cancel_sustained_action", self)
	m_action_transition_guard = false
	super.cancel_action(actor, reason)


func complete_action(
	actor: CharacterBody3D,
	context: Dictionary = {}
) -> void:
	if m_action_transition_guard or actor != get_reserved_actor():
		return
	m_action_transition_guard = true
	m_held_actor = null
	if actor.has_method("complete_sustained_action"):
		actor.call("complete_sustained_action", self)
	m_action_transition_guard = false
	super.complete_action(actor, context)


func request_active_context_action(actor: CharacterBody3D) -> bool:
	if actor != m_held_actor or actor != get_reserved_actor():
		return false
	var placement_target := find_best_placement_target(actor)
	if !is_instance_valid(placement_target):
		return false
	return place_on_target(actor, placement_target)


func constrain_motion_intent(
	actor: CharacterBody3D,
	intent: Object,
	delta: float
) -> Object:
	if actor != m_held_actor or !is_instance_valid(intent):
		return intent
	var desired_direction := _read_intent_direction(intent)
	var constrained_direction := _turn_toward_intent(
		actor,
		desired_direction,
		delta
	)
	var movement_speed := get_forced_movement_speed()
	if constrained_direction.is_zero_approx():
		movement_speed = 0.0
	intent.set("direction", constrained_direction)
	intent.set("movement_speed", movement_speed)
	if "is_running" in actor:
		actor.set("is_running", false)
	if !is_carried_motion_clear(
		actor,
		constrained_direction,
		movement_speed * maxf(delta, 0.0)
	):
		intent.set("direction", Vector3.ZERO)
		intent.set("movement_speed", 0.0)
		_set_blocked(true)
	else:
		_set_blocked(false)
	return intent


func before_actor_motion(
	actor: CharacterBody3D,
	intent: Object = null,
	delta: float = 0.0
) -> void:
	if actor != m_held_actor:
		return
	_sync_to_actor_socket(actor)
	if !is_instance_valid(intent):
		return
	var direction := _read_intent_direction(intent)
	var movement_speed := _read_intent_speed(intent)
	if !is_carried_motion_clear(
		actor,
		direction,
		movement_speed * maxf(delta, 0.0)
	):
		intent.set("direction", Vector3.ZERO)
		intent.set("movement_speed", 0.0)
		_set_blocked(true)


func after_actor_motion(
	actor: CharacterBody3D,
	_intent: Object = null,
	_delta: float = 0.0
) -> void:
	if actor == m_held_actor:
		_sync_to_actor_socket(actor)


func get_active_hint() -> String:
	if !is_instance_valid(m_held_actor):
		return "Esc Reset"
	var target := find_best_placement_target(m_held_actor)
	if is_instance_valid(target):
		return "R %s · Esc Reset" % target.get_placement_label()
	if m_blocked:
		return "Path blocked · Esc Reset"
	return "Carry · Esc Reset"


func get_forced_movement_speed() -> float:
	return (
		LIGHT_MOVEMENT_SPEED
		if carry_weight == CarryWeight.LIGHT
		else MEDIUM_MOVEMENT_SPEED
	)


func get_turn_rate_degrees() -> float:
	return (
		LIGHT_TURN_RATE_DEGREES
		if carry_weight == CarryWeight.LIGHT
		else MEDIUM_TURN_RATE_DEGREES
	)


func get_socket_forward_offset() -> float:
	return (
		LIGHT_SOCKET_FORWARD
		if carry_weight == CarryWeight.LIGHT
		else MEDIUM_SOCKET_FORWARD
	)


func get_socket_height() -> float:
	return (
		LIGHT_SOCKET_HEIGHT
		if carry_weight == CarryWeight.LIGHT
		else MEDIUM_SOCKET_HEIGHT
	)


func get_carry_socket_transform(actor: CharacterBody3D) -> Transform3D:
	var actor_forward := _resolve_actor_forward(actor)
	var right := Vector3.UP.cross(actor_forward).normalized()
	var socket_basis := Basis(right, Vector3.UP, actor_forward).orthonormalized()
	socket_basis *= Basis.from_euler(
		Vector3(
			deg_to_rad(socket_rotation_degrees.x),
			deg_to_rad(socket_rotation_degrees.y),
			deg_to_rad(socket_rotation_degrees.z)
		)
	)
	var socket_origin := (
		actor.global_position
		+ actor_forward * get_socket_forward_offset()
		+ Vector3.UP * get_socket_height()
	)
	return Transform3D(socket_basis, socket_origin)


func is_carried_motion_clear(
	actor: CharacterBody3D,
	direction: Vector3,
	distance: float
) -> bool:
	if !is_instance_valid(actor) or direction.is_zero_approx() or distance <= 0.0:
		return true
	var world := actor.get_world_3d()
	if world == null or world.direct_space_state == null:
		return true
	var envelope := _build_combined_envelope(actor)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = envelope.shape
	query.transform = envelope.transform
	query.motion = direction.normalized() * distance
	query.collision_mask = _resolve_collision_mask(actor)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = _build_query_exclusions(actor)
	var clearance := world.direct_space_state.cast_motion(query)
	return (
		!clearance.is_empty()
		and float(clearance[0]) >= MOTION_CLEARANCE_SAFE_FRACTION
	)


func find_best_placement_target(
	actor: CharacterBody3D
) -> CarryPlacementTarget3D:
	if !is_instance_valid(actor) or get_tree() == null:
		return null
	var best_target: CarryPlacementTarget3D = null
	var best_priority := 2147483647
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(
		CarryPlacementTarget3D.PLACEMENT_TARGET_GROUP
	):
		var target := node as CarryPlacementTarget3D
		if (
			target == null
			or !target.accepts_action(action_id)
			or !is_placement_valid(actor, target)
		):
			continue
		var target_priority := target.get_placement_priority()
		var target_distance := actor.global_position.distance_to(
			target.get_placement_transform().origin
		)
		if (
			target_priority < best_priority
			or (
				target_priority == best_priority
				and target_distance < best_distance
			)
		):
			best_target = target
			best_priority = target_priority
			best_distance = target_distance
	return best_target


func is_placement_valid(
	actor: CharacterBody3D,
	target: CarryPlacementTarget3D
) -> bool:
	if (
		actor != m_held_actor
		or !is_instance_valid(target)
		or !target.accepts_action(action_id)
		or !target.is_reachable(actor, get_carry_socket_transform(actor))
		or !target.has_accepted_authored_tolerances()
	):
		return false
	var placement_transform := target.get_placement_transform()
	if !_is_placement_shape_clear(actor, placement_transform):
		return false
	if !target.require_support:
		return true
	var support := _measure_support(actor, placement_transform, target)
	return (
		float(support.coverage) + 0.00001 >= PLACEMENT_SUPPORT_COVERAGE
		and float(support.maximum_slope_degrees)
		<= PLACEMENT_SUPPORT_SLOPE_DEGREES + 0.00001
	)


func place_on_target(
	actor: CharacterBody3D,
	target: CarryPlacementTarget3D
) -> bool:
	if !is_placement_valid(actor, target):
		return false
	global_transform = target.get_placement_transform()
	m_last_safe_transform = global_transform
	m_is_placed = true
	action_enabled = false
	_restore_collision()
	placed.emit(target)
	complete_action(
		actor,
		{
			"placement_id": String(target.placement_id),
			"carry_weight": _get_weight_name(),
		}
	)
	return true


func reset_to_last_safe_transform() -> void:
	_restore_last_safe_transform()


func reset_to_authored_origin() -> void:
	if !m_has_authored_origin:
		return
	global_transform = m_authored_origin_transform
	m_last_safe_transform = m_authored_origin_transform
	m_is_placed = false
	action_enabled = true
	m_out_of_bounds_elapsed = 0.0
	_restore_collision()


func is_carried() -> bool:
	return is_instance_valid(m_held_actor)


func is_placed() -> bool:
	return m_is_placed


func is_blocked() -> bool:
	return m_blocked


func _physics_process(delta: float) -> void:
	if (
		!reset_when_out_of_bounds
		or is_carried()
		or !m_has_authored_origin
	):
		m_out_of_bounds_elapsed = 0.0
		return
	var offset := global_position - m_authored_origin_transform.origin
	var outside_bounds := (
		global_position.y
		< m_authored_origin_transform.origin.y - OUT_OF_BOUNDS_DROP_DISTANCE
		or absf(offset.x) > reset_half_extents.x + OUT_OF_BOUNDS_MARGIN
		or absf(offset.z) > reset_half_extents.z + OUT_OF_BOUNDS_MARGIN
	)
	if !outside_bounds:
		m_out_of_bounds_elapsed = 0.0
		return
	m_out_of_bounds_elapsed += maxf(delta, 0.0)
	if (
		global_position.y
		< m_authored_origin_transform.origin.y - OUT_OF_BOUNDS_DROP_DISTANCE
		or m_out_of_bounds_elapsed + 0.00001 >= OUT_OF_BOUNDS_DURATION
	):
		_restore_last_safe_transform()
		m_out_of_bounds_elapsed = 0.0


func _has_accepted_bounds() -> bool:
	var dimensions := carried_bounds.abs()
	var maximum := (
		LIGHT_MAXIMUM_BOUNDS
		if carry_weight == CarryWeight.LIGHT
		else MEDIUM_MAXIMUM_BOUNDS
	)
	if carry_weight == CarryWeight.HEAVY:
		return false
	return (
		dimensions.x <= maximum.x + 0.00001
		and dimensions.y <= maximum.y + 0.00001
		and dimensions.z <= maximum.z + 0.00001
		and dimensions.x > 0.0
		and dimensions.y > 0.0
		and dimensions.z > 0.0
	)


func _has_clear_pickup_sweep(actor: CharacterBody3D) -> bool:
	var handle_position := get_pickup_handle().global_position
	var sweep_start := actor.global_position + Vector3.UP * minf(
		maxf(handle_position.y - actor.global_position.y, 0.15),
		1.10
	)
	var motion := handle_position - sweep_start
	if motion.length_squared() <= 0.000001:
		return true
	var world := actor.get_world_3d()
	if world == null or world.direct_space_state == null:
		return true
	var sweep_shape := SphereShape3D.new()
	sweep_shape.radius = PICKUP_SWEEP_RADIUS
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sweep_shape
	query.transform = Transform3D(Basis.IDENTITY, sweep_start)
	query.motion = motion
	query.collision_mask = _resolve_collision_mask(actor)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = _build_query_exclusions(actor)
	var clearance := world.direct_space_state.cast_motion(query)
	return (
		!clearance.is_empty()
		and float(clearance[0]) >= MOTION_CLEARANCE_SAFE_FRACTION
	)


func _build_combined_envelope(actor: CharacterBody3D) -> Dictionary:
	var actor_radius := _read_actor_float(actor, &"body_radius", 0.28)
	var actor_height := _read_actor_float(actor, &"body_height", 1.72)
	var dimensions := carried_bounds.abs()
	var forward_offset := get_socket_forward_offset()
	var envelope_width := (
		maxf(actor_radius * 2.0, dimensions.x) + DOORWAY_WIDTH_MARGIN
	)
	var envelope_height := (
		maxf(
			actor_height,
			get_socket_height() + dimensions.y * 0.5
		)
		+ DOORWAY_HEIGHT_MARGIN
	)
	var rear_extent := actor_radius
	var front_extent := forward_offset + dimensions.z * 0.5
	var envelope_depth := rear_extent + front_extent
	var actor_forward := _resolve_actor_forward(actor)
	var right := Vector3.UP.cross(actor_forward).normalized()
	var envelope_basis := Basis(
		right,
		Vector3.UP,
		actor_forward
	).orthonormalized()
	var envelope_center := (
		actor.global_position
		+ actor_forward * ((front_extent - rear_extent) * 0.5)
		+ Vector3.UP * (envelope_height * 0.5 + 0.01)
	)
	var envelope_shape := BoxShape3D.new()
	envelope_shape.size = Vector3(
		envelope_width,
		envelope_height,
		envelope_depth
	)
	return {
		"shape": envelope_shape,
		"transform": Transform3D(envelope_basis, envelope_center),
	}


func _is_placement_shape_clear(
	actor: CharacterBody3D,
	placement_transform: Transform3D
) -> bool:
	var world := actor.get_world_3d()
	if world == null or world.direct_space_state == null:
		return true
	var placement_shape := BoxShape3D.new()
	placement_shape.size = carried_bounds.abs()
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = placement_shape
	# Lift the clearance probe by the accepted margin so the authored supporting
	# surface is not treated as an obstacle. A tiny epsilon avoids contact jitter
	# at an exactly flush shelf while retaining the full horizontal margin.
	query.transform = placement_transform.translated(
		Vector3.UP * (WORLD_SWEEP_MARGIN + 0.001)
	)
	query.margin = WORLD_SWEEP_MARGIN
	query.collision_mask = _resolve_collision_mask(actor)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = _build_query_exclusions(actor)
	return world.direct_space_state.intersect_shape(query, 1).is_empty()


func _measure_support(
	actor: CharacterBody3D,
	placement_transform: Transform3D,
	target: CarryPlacementTarget3D
) -> Dictionary:
	if target.authored_support_coverage >= 0.0:
		return {
			"coverage": target.authored_support_coverage,
			"maximum_slope_degrees": maxf(
				target.authored_support_slope_degrees,
				0.0
			),
		}
	var world := actor.get_world_3d()
	if world == null or world.direct_space_state == null:
		return {
			"coverage": 1.0,
			"maximum_slope_degrees": maxf(
				target.authored_support_slope_degrees,
				0.0
			),
		}
	var dimensions := carried_bounds.abs()
	var right := placement_transform.basis.x.normalized()
	var forward := placement_transform.basis.z.normalized()
	var bottom_center := (
		placement_transform.origin
		- placement_transform.basis.y.normalized() * dimensions.y * 0.5
	)
	var supported_samples := 0
	var maximum_slope := 0.0
	var total_samples := (
		PLACEMENT_SUPPORT_SAMPLE_COUNT * PLACEMENT_SUPPORT_SAMPLE_COUNT
	)
	for x_index in range(PLACEMENT_SUPPORT_SAMPLE_COUNT):
		for z_index in range(PLACEMENT_SUPPORT_SAMPLE_COUNT):
			var x_fraction := (
				float(x_index) / float(PLACEMENT_SUPPORT_SAMPLE_COUNT - 1)
				- 0.5
			)
			var z_fraction := (
				float(z_index) / float(PLACEMENT_SUPPORT_SAMPLE_COUNT - 1)
				- 0.5
			)
			var sample_position := (
				bottom_center
				+ right * x_fraction * dimensions.x * 0.96
				+ forward * z_fraction * dimensions.z * 0.96
			)
			var ray := PhysicsRayQueryParameters3D.create(
				sample_position + Vector3.UP * PLACEMENT_SUPPORT_PROBE_UP,
				sample_position - Vector3.UP * PLACEMENT_SUPPORT_PROBE_DOWN
			)
			ray.collision_mask = _resolve_collision_mask(actor)
			ray.collide_with_areas = false
			ray.collide_with_bodies = true
			ray.exclude = _build_query_exclusions(actor)
			var hit := world.direct_space_state.intersect_ray(ray)
			if hit.is_empty():
				continue
			supported_samples += 1
			var normal := hit.get("normal", Vector3.UP) as Vector3
			maximum_slope = maxf(
				maximum_slope,
				rad_to_deg(normal.angle_to(Vector3.UP))
			)
	if target.authored_support_slope_degrees >= 0.0:
		maximum_slope = target.authored_support_slope_degrees
	return {
		"coverage": float(supported_samples) / float(total_samples),
		"maximum_slope_degrees": maximum_slope,
	}


func _cache_and_disable_collision() -> void:
	m_collision_shapes.clear()
	m_collision_shape_enabled_states.clear()
	for node in find_children("*", "CollisionShape3D", true, false):
		var collision_shape := node as CollisionShape3D
		if collision_shape == null:
			continue
		m_collision_shapes.append(collision_shape)
		m_collision_shape_enabled_states.append(!collision_shape.disabled)
		collision_shape.disabled = true


func _restore_collision() -> void:
	for index in range(m_collision_shapes.size()):
		var collision_shape := m_collision_shapes[index]
		if !is_instance_valid(collision_shape):
			continue
		collision_shape.disabled = !m_collision_shape_enabled_states[index]
	m_collision_shapes.clear()
	m_collision_shape_enabled_states.clear()


func _restore_last_safe_transform() -> void:
	global_transform = m_last_safe_transform
	_restore_collision()
	_set_blocked(false)


func _sync_to_actor_socket(actor: CharacterBody3D) -> void:
	global_transform = get_carry_socket_transform(actor)


func _turn_toward_intent(
	actor: CharacterBody3D,
	desired_direction: Vector3,
	delta: float
) -> Vector3:
	var desired := Vector3(
		desired_direction.x,
		0.0,
		desired_direction.z
	)
	if desired.length_squared() <= 0.000001:
		return Vector3.ZERO
	desired = desired.normalized()
	var current := _resolve_actor_forward(actor)
	var signed_angle := current.signed_angle_to(desired, Vector3.UP)
	var maximum_turn := deg_to_rad(get_turn_rate_degrees()) * maxf(delta, 0.0)
	var constrained := current.rotated(
		Vector3.UP,
		clampf(signed_angle, -maximum_turn, maximum_turn)
	).normalized()
	if actor.has_method("set_direction_vector"):
		actor.call("set_direction_vector", constrained)
	return constrained


func _resolve_actor_forward(actor: CharacterBody3D) -> Vector3:
	if actor.has_method("get_direction_vector"):
		var direction_value: Variant = actor.call("get_direction_vector")
		if direction_value is Vector3:
			var authored_direction := direction_value as Vector3
			authored_direction.y = 0.0
			if authored_direction.length_squared() > 0.000001:
				return authored_direction.normalized()
	var fallback := actor.global_basis.z
	fallback.y = 0.0
	if fallback.length_squared() <= 0.000001:
		return Vector3.FORWARD
	return fallback.normalized()


func _build_query_exclusions(actor: CharacterBody3D) -> Array[RID]:
	var exclusions: Array[RID] = [actor.get_rid()]
	for node in find_children("*", "CollisionObject3D", true, false):
		var collision_object := node as CollisionObject3D
		if collision_object != null:
			exclusions.append(collision_object.get_rid())
	return exclusions


func _resolve_collision_mask(actor: CharacterBody3D) -> int:
	if clearance_collision_mask != 0:
		return clearance_collision_mask
	return actor.collision_mask


func _read_actor_float(
	actor: CharacterBody3D,
	property_name: StringName,
	fallback: float
) -> float:
	var value: Variant = actor.get(property_name)
	if value is float or value is int:
		return float(value)
	return fallback


func _read_intent_direction(intent: Object) -> Vector3:
	var value: Variant = intent.get("direction")
	return value as Vector3 if value is Vector3 else Vector3.ZERO


func _read_intent_speed(intent: Object) -> float:
	var value: Variant = intent.get("movement_speed")
	return maxf(float(value), 0.0) if value is float or value is int else 0.0


func _set_blocked(blocked: bool) -> void:
	if m_blocked == blocked:
		return
	m_blocked = blocked
	carry_blocked_changed.emit(m_blocked)


func _get_weight_name() -> String:
	match carry_weight:
		CarryWeight.LIGHT:
			return "light"
		CarryWeight.MEDIUM:
			return "medium"
	return "heavy"
