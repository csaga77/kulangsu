extends Node3D

## Carry-only portion of the canonical object-action fixture. Milestone C
## consolidation adds the independently implemented push/pull coverage here.

const CARRYABLE_SCRIPT := preload("res://game/world/carryable_object_3d.gd")
const PLACEMENT_TARGET_SCRIPT := preload(
	"res://game/world/carry_placement_target_3d.gd"
)
const MOTION_INTENT_SCRIPT := preload(
	"res://characters/control/character_motion_intent_3d.gd"
)
const PIANO_FERRY_CARRY_SCENE := preload(
	"res://architecture/piano_ferry/piano_ferry_carry_action_3d.tscn"
)
const FIXED_DELTA := 1.0 / 60.0
const POSITION_EPSILON := 0.001

var m_failures := PackedStringArray()


class CarryActorProbe:
	extends CharacterBody3D

	var body_height := 1.72
	var body_radius := 0.28
	var is_running := true
	var m_action_mode := 0
	var m_active_target: Object = null
	var m_forward := Vector3.BACK
	var m_grounded := true
	var m_free_locomotion := true

	func begin_sustained_action(mode: int, target: Object) -> bool:
		if mode == 0 or m_action_mode != 0 or !m_grounded or !m_free_locomotion:
			return false
		m_action_mode = mode
		m_active_target = target
		if is_instance_valid(target) and target.has_method("begin_action"):
			target.call("begin_action", self)
		return true

	func cancel_sustained_action(target: Object = null) -> bool:
		if m_action_mode == 0:
			return false
		if is_instance_valid(target) and target != m_active_target:
			return false
		var previous_target := m_active_target
		m_action_mode = 0
		m_active_target = null
		if (
			is_instance_valid(previous_target)
			and previous_target.has_method("cancel_action")
		):
			previous_target.call("cancel_action", self, &"actor_cancel")
		return true

	func complete_sustained_action(target: Object = null) -> bool:
		if m_action_mode == 0:
			return false
		if is_instance_valid(target) and target != m_active_target:
			return false
		var previous_target := m_active_target
		m_action_mode = 0
		m_active_target = null
		if (
			is_instance_valid(previous_target)
			and previous_target.has_method("complete_action")
		):
			previous_target.call("complete_action", self)
		return true

	func get_action_mode() -> int:
		return m_action_mode

	func is_action_free() -> bool:
		return m_action_mode == 0

	func is_grounded() -> bool:
		return m_grounded

	func is_free_locomotion() -> bool:
		return m_free_locomotion

	func is_recovering() -> bool:
		return false

	func is_on_ladder() -> bool:
		return false

	func get_direction_vector() -> Vector3:
		return m_forward

	func set_direction_vector(direction: Vector3) -> void:
		var flat_direction := Vector3(direction.x, 0.0, direction.z)
		if !flat_direction.is_zero_approx():
			m_forward = flat_direction.normalized()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await get_tree().physics_frame
	await _validate_pickup_boundaries_and_rejections()
	await _validate_light_and_medium_attachment_and_motion()
	await _validate_doorway_clearance()
	await _validate_placement_boundaries_and_completion()
	await _validate_cancel_recovery_pause_and_unload_cleanup()
	await _validate_piano_ferry_production_slice()

	if m_failures.is_empty():
		print("PASS: character object actions 3D (carry)")
	else:
		for failure in m_failures:
			push_error(failure)
		push_error(
			"Character object actions 3D carry coverage failed with %d issue(s)."
			% m_failures.size()
		)

	await get_tree().create_timer(0.1).timeout
	get_tree().quit(0 if m_failures.is_empty() else 1)


func _validate_pickup_boundaries_and_rejections() -> void:
	var fixture := Node3D.new()
	fixture.name = "PickupBoundaries"
	add_child(fixture)
	var actor := _create_actor(fixture)
	var carryable := _create_carryable(
		fixture,
		"PickupProbe",
		Vector3(0.0, 0.0, 1.10),
		Vector3(0.50, 0.50, 0.50)
	)
	carryable.get_pickup_handle().position.y = 0.65
	await get_tree().physics_frame
	_assert_true(
		carryable.is_action_available(actor),
		"Pickup accepts the exact 1.10 m range and 0.65 m vertical boundary"
	)
	carryable.position.z = 1.11
	_assert_true(
		!carryable.is_action_available(actor),
		"Pickup rejects an otherwise identical object at 1.11 m"
	)
	carryable.position.z = 1.10
	carryable.get_pickup_handle().position.y = 0.66
	_assert_true(
		!carryable.is_action_available(actor),
		"Pickup rejects an otherwise identical handle at 0.66 m vertical delta"
	)
	carryable.get_pickup_handle().position.y = 0.65
	var wall := _add_static_box(
		fixture,
		"PickupOccluder",
		Vector3(0.50, 0.40, 0.10),
		Vector3(0.0, 0.65, 0.55)
	)
	await get_tree().physics_frame
	_assert_true(
		!carryable.is_action_available(actor),
		"A 0.10 m occluding wall blocks the pickup shape sweep"
	)
	wall.queue_free()
	await get_tree().physics_frame
	carryable.carry_weight = CarryableObject3D.CarryWeight.HEAVY
	_assert_true(
		!carryable.is_action_available(actor),
		"Heavy objects are never accepted by the carry action"
	)
	fixture.queue_free()
	await get_tree().process_frame


func _validate_light_and_medium_attachment_and_motion() -> void:
	var fixture := Node3D.new()
	fixture.name = "AttachmentAndMotion"
	add_child(fixture)
	var actor := _create_actor(fixture)
	var light := _create_carryable(
		fixture,
		"LightCarry",
		Vector3(0.0, 0.15, 0.80),
		Vector3(0.50, 0.35, 0.30)
	)
	var light_origin := light.global_transform
	await get_tree().physics_frame
	_assert_true(
		light.begin_action(actor),
		"A light object begins one sustained carry action"
	)
	_assert_vector_approx(
		light.global_position,
		Vector3(0.0, 1.05, 0.45),
		"The light object attaches at the accepted 0.45 m forward / 1.05 m socket"
	)
	var light_collision := light.get_node(
		"StaticBody3D/CollisionShape3D"
	) as CollisionShape3D
	_assert_true(
		light_collision.disabled,
		"The held object's ordinary world collision is disabled at the socket"
	)
	var light_intent := MOTION_INTENT_SCRIPT.new(Vector3.RIGHT, 7.5)
	light.constrain_motion_intent(actor, light_intent, FIXED_DELTA)
	_assert_approx(
		light_intent.movement_speed,
		3.20,
		"The light carry forces the accepted 3.20 m/s walk speed"
	)
	_assert_true(
		rad_to_deg(Vector3.BACK.angle_to(light_intent.direction))
		<= 3.001,
		"The light carry turn changes by at most 180 degrees per second"
	)
	_assert_true(!actor.is_running, "Carry forces walk presentation instead of run")
	light.cancel_action(actor)
	_assert_transform_approx(
		light.global_transform,
		light_origin,
		"Light carry cancel restores the previous authored transform"
	)
	_assert_true(
		actor.is_action_free() and !light_collision.disabled,
		"Light carry cancel clears action ownership and restores collision"
	)
	light.queue_free()
	await get_tree().physics_frame

	var medium := _create_carryable(
		fixture,
		"MediumCarry",
		Vector3(0.0, 0.275, 0.80),
		Vector3(0.75, 0.55, 0.55)
	)
	medium.carry_weight = CarryableObject3D.CarryWeight.MEDIUM
	actor.m_forward = Vector3.BACK
	await get_tree().physics_frame
	_assert_true(
		medium.begin_action(actor),
		"A maximum-bounds medium case begins a sustained carry action"
	)
	_assert_vector_approx(
		medium.global_position,
		Vector3(0.0, 0.90, 0.50),
		"The medium object attaches at the accepted 0.50 m forward / 0.90 m socket"
	)
	var medium_intent := MOTION_INTENT_SCRIPT.new(Vector3.RIGHT, 7.5)
	medium.constrain_motion_intent(actor, medium_intent, FIXED_DELTA)
	_assert_approx(
		medium_intent.movement_speed,
		2.40,
		"The medium carry forces the accepted 2.40 m/s walk speed"
	)
	_assert_true(
		rad_to_deg(Vector3.BACK.angle_to(medium_intent.direction))
		<= 2.001,
		"The medium carry turn changes by at most 120 degrees per second"
	)
	medium.cancel_action(actor)
	medium.carried_bounds = Vector3(0.76, 0.55, 0.55)
	_assert_true(
		!medium.is_action_available(actor),
		"A medium object exceeding its 0.75 m maximum axis is rejected"
	)
	fixture.queue_free()
	await get_tree().process_frame


func _validate_doorway_clearance() -> void:
	await _validate_one_doorway(
		CarryableObject3D.CarryWeight.LIGHT,
		Vector3(0.50, 0.35, 0.30),
		1.00,
		true,
		"Light carry passes the accepted 1.00 m doorway"
	)
	await _validate_one_doorway(
		CarryableObject3D.CarryWeight.LIGHT,
		Vector3(0.50, 0.35, 0.30),
		0.75,
		false,
		"Light carry rejects the 0.75 m doorway"
	)
	await _validate_one_doorway(
		CarryableObject3D.CarryWeight.MEDIUM,
		Vector3(0.75, 0.55, 0.55),
		1.10,
		true,
		"Medium carry passes the accepted 1.10 m doorway"
	)
	await _validate_one_doorway(
		CarryableObject3D.CarryWeight.MEDIUM,
		Vector3(0.75, 0.55, 0.55),
		0.94,
		false,
		"Medium carry rejects the 0.94 m doorway"
	)


func _validate_one_doorway(
	weight: CarryableObject3D.CarryWeight,
	bounds: Vector3,
	opening_width: float,
	expected_clear: bool,
	message: String
) -> void:
	var fixture := Node3D.new()
	fixture.name = "Doorway_%.2f" % opening_width
	add_child(fixture)
	var actor := _create_actor(fixture)
	var carryable := _create_carryable(
		fixture,
		"DoorCarry",
		Vector3(0.0, bounds.y * 0.5, 0.75),
		bounds
	)
	carryable.carry_weight = weight
	_add_door_frame(fixture, opening_width, 2.10 if weight == 0 else 2.15)
	await get_tree().physics_frame
	_assert_true(carryable.begin_action(actor), "%s begins from a valid pickup" % message)
	_assert_true(
		carryable.is_carried_motion_clear(
			actor,
			Vector3.BACK,
			1.80
		) == expected_clear,
		message
	)
	carryable.cancel_action(actor)
	fixture.queue_free()
	await get_tree().process_frame


func _validate_placement_boundaries_and_completion() -> void:
	var fixture := Node3D.new()
	fixture.name = "PlacementBoundaries"
	add_child(fixture)
	var actor := _create_actor(fixture)
	var carryable := _create_carryable(
		fixture,
		"PlacementCarry",
		Vector3(0.0, 0.15, 0.80),
		Vector3(0.50, 0.35, 0.30)
	)
	carryable.action_id = &"fixture_case"
	carryable.semantic_completion_id = &"piano_ferry_music_case_shelved"
	await get_tree().physics_frame
	_assert_true(carryable.begin_action(actor), "Placement fixture starts carrying")
	var target := _create_placement_target(
		fixture,
		"BoundaryTarget",
		Vector3(0.0, 1.05, 0.65),
		&"fixture_case"
	)
	target.require_support = true
	target.authored_support_coverage = 0.80
	target.authored_support_slope_degrees = 10.0
	await get_tree().physics_frame
	_assert_true(
		carryable.is_placement_valid(actor, target),
		"Placement accepts exact 0.65 m reach, 80% support, and 10 degree slope"
	)
	target.position.z = 1.35
	_assert_true(
		carryable.is_placement_valid(actor, target),
		"Placement accepts the exact 1.35 m maximum reach"
	)
	target.position.z = 1.36
	_assert_true(
		!carryable.is_placement_valid(actor, target),
		"Placement rejects a 1.36 m forward reach and keeps the object attached"
	)
	_assert_transform_approx(
		carryable.global_transform,
		carryable.get_carry_socket_transform(actor),
		"Invalid placement leaves the carried transform unchanged"
	)
	target.position = Vector3(0.0, 1.65, 1.00)
	_assert_true(
		carryable.is_placement_valid(actor, target),
		"Placement accepts the exact +0.60 m socket-height delta"
	)
	target.position.y = 1.66
	_assert_true(
		!carryable.is_placement_valid(actor, target),
		"Placement rejects a +0.61 m socket-height delta"
	)
	target.position = Vector3(0.0, 1.05, 1.00)
	target.authored_position_error = 0.10
	target.authored_yaw_error_degrees = 10.0
	_assert_true(
		carryable.is_placement_valid(actor, target),
		"Placement accepts exact 0.10 m position and 10 degree yaw tolerances"
	)
	target.authored_position_error = 0.11
	_assert_true(
		!carryable.is_placement_valid(actor, target),
		"Placement rejects 0.11 m final anchor error"
	)
	target.authored_position_error = 0.0
	target.authored_yaw_error_degrees = 11.0
	_assert_true(
		!carryable.is_placement_valid(actor, target),
		"Placement rejects 11 degree authored yaw error"
	)
	target.authored_yaw_error_degrees = 0.0
	target.authored_support_coverage = 0.79
	_assert_true(
		!carryable.is_placement_valid(actor, target),
		"Placement rejects 79% authored support"
	)
	target.authored_support_coverage = 0.80
	target.authored_support_slope_degrees = 11.0
	_assert_true(
		!carryable.is_placement_valid(actor, target),
		"Placement rejects an 11 degree support slope"
	)

	target.authored_support_slope_degrees = 0.0
	target.require_support = false
	var side_blocker := _add_side_clearance_blocker(
		fixture,
		"SevenCentimetreGap",
		target.global_position,
		0.07
	)
	await get_tree().physics_frame
	_assert_true(
		!carryable.is_placement_valid(actor, target),
		"The 0.08 m placement margin rejects a 0.07 m side gap"
	)
	side_blocker.queue_free()
	await get_tree().physics_frame
	side_blocker = _add_side_clearance_blocker(
		fixture,
		"NineCentimetreGap",
		target.global_position,
		0.09
	)
	await get_tree().physics_frame
	_assert_true(
		carryable.is_placement_valid(actor, target),
		"The 0.08 m placement margin accepts a 0.09 m side gap"
	)
	side_blocker.queue_free()
	await get_tree().physics_frame

	var completions: Array[StringName] = []
	carryable.semantic_completion_requested.connect(
		func(event_id: StringName, _context: Dictionary) -> void:
			completions.append(event_id)
	)
	target.position = Vector3(0.0, 0.95, 1.00)
	target.rotation.y = deg_to_rad(10.0)
	var authored_placement := target.global_transform
	_assert_true(
		carryable.request_active_context_action(actor),
		"Active contextual input applies one valid authored placement"
	)
	_assert_true(
		carryable.is_placed()
			and !carryable.is_carried()
			and actor.is_action_free(),
		"Placement detaches the object and restores the actor to free"
	)
	_assert_transform_approx(
		carryable.global_transform,
		authored_placement,
		"Placement applies the target's authored orientation without player rotation"
	)
	_assert_true(
		completions == [&"piano_ferry_music_case_shelved"],
		"Valid placement publishes the exact semantic completion once"
	)
	_assert_true(
		!carryable.request_active_context_action(actor)
			and completions.size() == 1,
		"Completed placement is idempotent"
	)
	fixture.queue_free()
	await get_tree().process_frame


func _validate_cancel_recovery_pause_and_unload_cleanup() -> void:
	var fixture := Node3D.new()
	fixture.name = "CarryCleanup"
	add_child(fixture)
	var actor := _create_actor(fixture)
	var carryable := _create_carryable(
		fixture,
		"CleanupCarry",
		Vector3(0.0, 0.15, 0.80),
		Vector3(0.50, 0.35, 0.30)
	)
	var safe_transform := carryable.global_transform
	await get_tree().physics_frame
	carryable.begin_action(actor)
	carryable.cancel_action(actor, &"recovery")
	_assert_true(
		actor.is_action_free()
			and carryable.global_transform.is_equal_approx(safe_transform),
		"Recovery cleanup restores the object and clears socket ownership"
	)

	carryable.begin_action(actor)
	carryable.notification(NOTIFICATION_PAUSED)
	_assert_true(
		actor.is_action_free()
			and carryable.global_transform.is_equal_approx(safe_transform),
		"Pause cleanup restores the object before releasing the action"
	)

	carryable.begin_action(actor)
	carryable.queue_free()
	await get_tree().process_frame
	_assert_true(
		actor.is_action_free(),
		"Scene unload clears actor carry state before the target leaves the tree"
	)

	var reset_probe := _create_carryable(
		fixture,
		"BoundsResetCarry",
		Vector3(0.0, 0.15, 0.80),
		Vector3(0.50, 0.35, 0.30)
	)
	var reset_transform := reset_probe.global_transform
	reset_probe.global_position.y -= 2.01
	reset_probe._physics_process(0.0)
	_assert_transform_approx(
		reset_probe.global_transform,
		reset_transform,
		"Object recovery restores a case dropped more than 2.00 m below origin"
	)
	fixture.queue_free()
	await get_tree().process_frame


func _validate_piano_ferry_production_slice() -> void:
	var production_slice := PIANO_FERRY_CARRY_SCENE.instantiate() as Node3D
	production_slice.name = "PianoFerryProductionFixture"
	add_child(production_slice)
	var actor := _create_actor(production_slice)
	actor.position = Vector3(0.0, 0.0, -2.80)
	var carryable := production_slice.get_node(
		"MusicCase"
	) as CarryableObject3D
	var placement_target := production_slice.get_node(
		"MusicCaseShelfPlacement"
	) as CarryPlacementTarget3D
	var standing_anchor := production_slice.get_node(
		"ShelfStandingAnchor"
	) as Marker3D
	var completions: Array[StringName] = []
	carryable.semantic_completion_requested.connect(
		func(event_id: StringName, _context: Dictionary) -> void:
			completions.append(event_id)
	)
	await get_tree().physics_frame
	_assert_true(
		carryable.begin_action(actor),
		"The authored Piano Ferry music case is available from its pickup anchor"
	)
	actor.position = Vector3(0.0, 0.0, -1.35)
	carryable.after_actor_motion(actor)
	_assert_true(
		carryable.is_carried_motion_clear(actor, Vector3.BACK, 1.50),
		"The authored case envelope passes the production 1.00 x 2.10 m doorway"
	)
	actor.position = Vector3(2.0, 0.0, -1.35)
	carryable.after_actor_motion(actor)
	_assert_true(
		!carryable.is_carried_motion_clear(actor, Vector3.BACK, 1.50),
		"The authored case envelope rejects the production 0.75 m validation frame"
	)
	actor.global_position = standing_anchor.global_position
	carryable.after_actor_motion(actor)
	_assert_true(
		carryable.is_placement_valid(actor, placement_target),
		"The production shelf socket is clear, supported, and exactly 1.00 m forward"
	)
	_assert_true(
		carryable.request_active_context_action(actor),
		"The production case places through the active contextual action"
	)
	_assert_true(
		completions == [&"piano_ferry_music_case_shelved"]
			and carryable.global_transform.is_equal_approx(
				placement_target.get_placement_transform()
			),
		"The production shelf applies its authored transform and exact semantic id once"
	)
	production_slice.queue_free()
	await get_tree().process_frame


func _create_actor(parent: Node3D) -> CarryActorProbe:
	var actor := CarryActorProbe.new()
	actor.name = "CarryActorProbe"
	actor.collision_layer = 1
	actor.collision_mask = 1
	parent.add_child(actor)
	return actor


func _create_carryable(
	parent: Node3D,
	node_name: String,
	position: Vector3,
	bounds: Vector3
) -> CarryableObject3D:
	var carryable := CARRYABLE_SCRIPT.new() as CarryableObject3D
	carryable.name = node_name
	carryable.position = position
	carryable.carried_bounds = bounds
	var handle := Marker3D.new()
	handle.name = "PickupHandle"
	carryable.add_child(handle)
	carryable.pickup_handle_path = NodePath("PickupHandle")
	var body := StaticBody3D.new()
	body.name = "StaticBody3D"
	body.collision_layer = 1
	body.collision_mask = 1
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = bounds
	collision.shape = shape
	body.add_child(collision)
	carryable.add_child(body)
	parent.add_child(carryable)
	return carryable


func _create_placement_target(
	parent: Node3D,
	node_name: String,
	position: Vector3,
	accepted_action_id: StringName
) -> CarryPlacementTarget3D:
	var target := PLACEMENT_TARGET_SCRIPT.new() as CarryPlacementTarget3D
	target.name = node_name
	target.position = position
	target.placement_id = StringName(node_name.to_snake_case())
	target.accepted_action_ids = [accepted_action_id]
	parent.add_child(target)
	return target


func _add_door_frame(
	parent: Node3D,
	opening_width: float,
	opening_height: float
) -> void:
	var post_width := 0.20
	var post_depth := 0.30
	var post_height := opening_height
	var x_offset := opening_width * 0.5 + post_width * 0.5
	_add_static_box(
		parent,
		"DoorPostLeft",
		Vector3(post_width, post_height, post_depth),
		Vector3(-x_offset, post_height * 0.5, 1.20)
	)
	_add_static_box(
		parent,
		"DoorPostRight",
		Vector3(post_width, post_height, post_depth),
		Vector3(x_offset, post_height * 0.5, 1.20)
	)
	_add_static_box(
		parent,
		"DoorLintel",
		Vector3(opening_width + post_width * 2.0, 0.20, post_depth),
		Vector3(0.0, opening_height + 0.10, 1.20)
	)


func _add_side_clearance_blocker(
	parent: Node3D,
	node_name: String,
	target_position: Vector3,
	clearance_gap: float
) -> StaticBody3D:
	var blocker_width := 0.10
	var object_half_width := 0.25
	var blocker_position := target_position + Vector3(
		object_half_width + clearance_gap + blocker_width * 0.5,
		0.0,
		0.0
	)
	return _add_static_box(
		parent,
		node_name,
		Vector3(blocker_width, 0.80, 0.80),
		blocker_position
	)


func _add_static_box(
	parent: Node3D,
	node_name: String,
	size: Vector3,
	position: Vector3
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	body.collision_layer = 1
	body.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	return body


func _assert_true(condition: bool, message: String) -> void:
	if !condition:
		m_failures.append(message)


func _assert_approx(actual: float, expected: float, message: String) -> void:
	if !is_equal_approx(actual, expected):
		m_failures.append("%s (expected %.3f, got %.3f)" % [
			message,
			expected,
			actual,
		])


func _assert_vector_approx(
	actual: Vector3,
	expected: Vector3,
	message: String
) -> void:
	if actual.distance_to(expected) > POSITION_EPSILON:
		m_failures.append("%s (expected %s, got %s)" % [
			message,
			expected,
			actual,
		])


func _assert_transform_approx(
	actual: Transform3D,
	expected: Transform3D,
	message: String
) -> void:
	if !actual.is_equal_approx(expected):
		m_failures.append(message)
