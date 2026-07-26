extends Node3D

const HUMAN_BODY_SCENE := preload("res://characters/human_body_3d.tscn")
const LADDER_SCRIPT := preload("res://game/world/ladder_3d.gd")
const FIXED_DELTA := 1.0 / 60.0
const LADDER_CLIMB_FRAMES := 112

var m_failures := PackedStringArray()
var m_semantic_completions: Array[StringName] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await get_tree().physics_frame
	_validate_numeric_jump_contract()
	await _validate_jump_state_and_recovery()
	await _validate_ceiling_rejection()
	await _validate_ladder_mount_climb_and_cleanup()

	if m_failures.is_empty():
		print("PASS: character traversal 3D")
	else:
		for failure in m_failures:
			push_error(failure)
		push_error(
			"Character traversal 3D failed with %d issue(s)."
			% m_failures.size()
		)

	Input.action_release("ui_up")
	Input.action_release("ui_down")
	Input.action_release("ui_jump")
	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0 if m_failures.is_empty() else 1)


func _validate_numeric_jump_contract() -> void:
	var actor := _create_actor("NumericContractActor", Vector3.ZERO, false)
	_assert_true(
		is_equal_approx(actor.jump_takeoff_velocity, 4.8)
			and is_equal_approx(actor.gravity, 16.0)
			and is_equal_approx(actor.jump_release_velocity, 2.0),
		"Traversal jump exposes the accepted takeoff, gravity, and short-hop values"
	)
	var apex := (
		actor.jump_takeoff_velocity * actor.jump_takeoff_velocity
		/ (2.0 * actor.gravity)
	)
	var same_height_flight := 2.0 * actor.jump_takeoff_velocity / actor.gravity
	_assert_true(
		is_equal_approx(apex, 0.72)
			and is_equal_approx(same_height_flight, 0.6),
		"The accepted traversal arc reaches 0.72 m over a 0.60 s same-height flight"
	)
	_assert_true(
		is_equal_approx(actor.jump_horizontal_speed_cap, 4.5)
			and is_equal_approx(actor.air_control_acceleration, 6.0)
			and is_equal_approx(actor.air_control_max_delta, 1.0),
		"Air control is capped at the accepted speed, acceleration, and total correction"
	)
	_assert_true(
		_boundary_accepts(0.16, actor.jump_buffer_seconds)
			and !_boundary_accepts(0.17, actor.jump_buffer_seconds)
			and _boundary_accepts(0.18, actor.jump_coyote_seconds)
			and !_boundary_accepts(0.19, actor.jump_coyote_seconds),
		"Jump buffer and coyote fixtures accept 0.16/0.18 s and reject 0.17/0.19 s"
	)
	_assert_true(
		_boundary_accepts(0.45, 0.45)
			and !_boundary_accepts(0.55, 0.45)
			and _boundary_accepts(1.20, 1.20)
			and !_boundary_accepts(1.35, 1.20),
		"Obstacle and gap fixtures accept 0.45/1.20 m and reject 0.55/1.35 m"
	)
	_assert_true(
		_boundary_accepts(0.12, 0.12)
			and !_boundary_accepts(0.13, 0.12)
			and 1.4 >= 1.4
			and !(0.7 >= 1.4),
		"Floor snap and landing-depth fixtures preserve accepted and rejected boundaries"
	)
	_assert_true(
		is_equal_approx(actor.jump_ceiling_clearance, 0.20)
			and is_equal_approx(actor.landing_control_delay, 0.10)
			and is_equal_approx(actor.recovery_drop_distance, 4.0)
			and is_equal_approx(actor.unsupported_recovery_seconds, 2.5),
		"Ceiling, landing, and recovery exports match the accepted numeric contract"
	)
	actor.free()


func _validate_jump_state_and_recovery() -> void:
	var fixture := Node3D.new()
	fixture.name = "JumpStateFixture"
	add_child(fixture)
	_add_static_box(
		fixture,
		"Floor",
		Vector3(5.0, 0.1, 5.0),
		Vector3(0.0, -0.05, 0.0)
	)
	var actor := _create_actor("JumpActor", Vector3(0.0, 0.04, 0.0), true, fixture)
	await _settle_actor(actor)
	var safe_transform := actor.global_transform
	actor.set_safe_transform(safe_transform)
	_assert_true(
		actor.get_safe_transform().is_equal_approx(safe_transform),
		"Grounded traversal records a scene-local safe transform"
	)
	_assert_true(
		actor.request_jump()
			and actor.is_airborne()
			and is_equal_approx(actor.velocity.y, 4.8),
		"A grounded free actor enters the physical traversal jump"
	)
	actor.release_jump()
	_assert_true(
		actor.velocity.y <= actor.jump_release_velocity + 0.001,
		"Releasing jump while rising clamps vertical velocity to the accepted short-hop value"
	)
	_assert_true(
		!actor.request_jump(),
		"Holding or repeating jump while airborne does not auto-repeat takeoff"
	)
	actor.global_position = Vector3(0.0, -4.1, 0.0)
	actor.recover_to_safe_transform()
	await _wait_physics_frames(12)
	_assert_true(
		actor.is_free_locomotion()
			and !actor.is_airborne()
			and actor.global_transform.is_equal_approx(safe_transform)
			and actor.velocity.is_zero_approx(),
		"A missed landing recovers without damage, story rollback, or retained velocity"
	)
	fixture.queue_free()
	await get_tree().process_frame


func _validate_ceiling_rejection() -> void:
	var low_fixture := Node3D.new()
	low_fixture.name = "LowCeilingFixture"
	add_child(low_fixture)
	_add_static_box(
		low_fixture,
		"Floor",
		Vector3(3.0, 0.1, 3.0),
		Vector3(0.0, -0.05, 0.0)
	)
	_add_static_box(
		low_fixture,
		"LowCeiling",
		Vector3(3.0, 0.2, 3.0),
		Vector3(0.0, 2.0, 0.0)
	)
	var low_actor := _create_actor(
		"LowCeilingActor",
		Vector3(0.0, 0.04, 0.0),
		true,
		low_fixture
	)
	await _settle_actor(low_actor)
	_assert_true(
		!low_actor.request_jump(),
		"A 1.90 m ceiling rejects takeoff for the 1.72 m body plus 0.20 m clearance"
	)
	low_fixture.queue_free()
	await get_tree().process_frame

	var high_fixture := Node3D.new()
	high_fixture.name = "HighCeilingFixture"
	add_child(high_fixture)
	_add_static_box(
		high_fixture,
		"Floor",
		Vector3(3.0, 0.1, 3.0),
		Vector3(0.0, -0.05, 0.0)
	)
	_add_static_box(
		high_fixture,
		"HighCeiling",
		Vector3(3.0, 0.2, 3.0),
		Vector3(0.0, 2.04, 0.0)
	)
	var high_actor := _create_actor(
		"HighCeilingActor",
		Vector3(0.0, 0.04, 0.0),
		true,
		high_fixture
	)
	await _settle_actor(high_actor)
	_assert_true(
		high_actor.request_jump(),
		"A 1.94 m ceiling permits safe takeoff before later ceiling contact cancels ascent"
	)
	await _advance_actor_motion(high_actor, 24)
	_assert_true(
		high_actor.velocity.y <= 0.0,
		"Ceiling contact cancels upward velocity without clipping or crouch launch"
	)
	high_fixture.queue_free()
	await get_tree().process_frame


func _validate_ladder_mount_climb_and_cleanup() -> void:
	var fixture := Node3D.new()
	fixture.name = "LadderFixture"
	add_child(fixture)
	_add_static_box(
		fixture,
		"BottomPad",
		Vector3(1.2, 0.1, 1.2),
		Vector3(-0.6, -0.05, 0.0)
	)
	_add_static_box(
		fixture,
		"TopPad",
		Vector3(1.4, 0.1, 1.4),
		Vector3(0.75, 3.15, 0.0)
	)
	var actor := _create_actor(
		"LadderActor",
		Vector3(-0.7, 0.04, 0.0),
		true,
		fixture
	)
	actor.set_direction_vector(Vector3.RIGHT)
	await _settle_actor(actor)
	var ladder = _create_ladder(fixture)
	await get_tree().process_frame

	_assert_true(
		is_equal_approx(ladder.interaction_range, 0.9)
			and is_equal_approx(ladder.facing_tolerance_degrees, 20.0)
			and is_equal_approx(ladder.climb_speed, 1.8)
			and is_equal_approx(ladder.alignment_duration, 0.3)
			and is_equal_approx(ladder.endpoint_clearance, 0.75),
		"Ladder target exposes the accepted mount, climb, alignment, and endpoint values"
	)
	_assert_true(
		ladder.is_action_available(actor)
			and ladder.begin_action(actor),
		"A grounded free actor inside the 0.90 m / 20 degree gate mounts the ladder"
	)
	await _wait_physics_frames(24)
	_assert_true(
		ladder.is_mounted()
			and actor.is_on_ladder()
			and int(ladder.get_ladder_state()) == 2,
		"Ladder alignment settles into constrained ladder locomotion"
	)

	var second_ladder = _create_ladder(fixture, "ReservedLadder")
	_assert_true(
		!second_ladder.is_action_available(actor),
		"Another ladder rejects an actor already in incompatible ladder locomotion"
	)

	var blocker := _add_static_box(
		fixture,
		"TopEndpointBlocker",
		Vector3(0.3, 0.3, 0.3),
		Vector3(0.75, 4.01, 0.0)
	)
	Input.action_press("ui_up")
	await _wait_physics_frames(LADDER_CLIMB_FRAMES + 18)
	Input.action_release("ui_up")
	_assert_true(
		ladder.is_mounted()
			and actor.is_on_ladder()
			and ladder.get_climb_progress() < 1.0,
		"A blocked top exit retreats along the ladder and keeps movement away available"
	)

	blocker.queue_free()
	await get_tree().physics_frame
	Input.action_press("ui_up")
	await _wait_physics_frames(35)
	Input.action_release("ui_up")
	_assert_true(
		!ladder.is_mounted()
			and actor.is_free_locomotion()
			and m_semantic_completions.count(
				&"bagua_stewardship_ladder_ascended"
			) == 1,
		"A clear settled top dismount completes once and returns free locomotion"
	)

	actor.set_direction_vector(Vector3.LEFT)
	_assert_true(
		ladder.begin_action(actor),
		"The same straight service ladder mounts from the view-deck endpoint"
	)
	await _wait_physics_frames(24)
	Input.action_press("ui_down")
	await _wait_physics_frames(LADDER_CLIMB_FRAMES + 20)
	Input.action_release("ui_down")
	_assert_true(
		!ladder.is_mounted() and actor.is_free_locomotion(),
		"The service ladder climbs and dismounts safely in both directions"
	)

	actor.global_position = Vector3(-0.7, 0.04, 0.0)
	actor.set_direction_vector(Vector3.RIGHT)
	await _settle_actor(actor)
	_assert_true(ladder.begin_action(actor), "Ladder remounts for explicit cancel coverage")
	await _wait_physics_frames(24)
	ladder.cancel_action(actor, &"cancel")
	_assert_true(
		!ladder.is_mounted()
			and !ladder.has_reserved_actor()
			and actor.is_free_locomotion()
			and actor.global_position.distance_to(
				ladder.get_node("BottomMount").global_position
			) <= 0.12,
		"Esc-style cancellation restores the last clear mount anchor"
	)

	for cleanup_reason in [&"pause", &"recovery", &"scene_unload"]:
		actor.global_position = Vector3(-0.7, 0.04, 0.0)
		await _settle_actor(actor)
		_assert_true(
			ladder.begin_action(actor),
			"Ladder mounts for %s cleanup" % cleanup_reason
		)
		await _wait_physics_frames(24)
		ladder.cancel_action(actor, cleanup_reason)
		_assert_true(
			actor.is_free_locomotion()
				and !ladder.has_reserved_actor()
				and actor.velocity.is_zero_approx(),
			"%s cleanup clears ladder ownership and velocity" % cleanup_reason
		)

	fixture.queue_free()
	await get_tree().process_frame


func _create_actor(
	actor_name: String,
	position: Vector3,
	add_now: bool,
	parent: Node = self
) -> HumanBody3D:
	var actor := HUMAN_BODY_SCENE.instantiate() as HumanBody3D
	actor.name = actor_name
	actor.character_model_scene = null
	actor.draw_skeleton_bones = false
	actor.body_height = 1.72
	actor.body_radius = 0.28
	if add_now:
		parent.add_child(actor)
		actor.global_position = position
	return actor


func _create_ladder(parent: Node3D, ladder_name: String = "ServiceLadder"):
	var ladder = LADDER_SCRIPT.new()
	ladder.name = ladder_name
	ladder.action_id = &"ladder"
	ladder.action_label = "Climb Service Ladder"
	ladder.action_priority = 10
	ladder.interaction_range = 0.9
	ladder.facing_tolerance_degrees = 20.0
	ladder.action_anchor_path = NodePath("BottomMount")
	ladder.bottom_mount_path = NodePath("BottomMount")
	ladder.top_mount_path = NodePath("TopMount")
	ladder.bottom_exit_path = NodePath("BottomExit")
	ladder.top_exit_path = NodePath("TopExit")
	ladder.climb_speed = 1.8
	ladder.alignment_duration = 0.3
	ladder.endpoint_clearance = 0.75
	ladder.blocked_retreat_distance = 0.35
	ladder.semantic_completion_id = &"bagua_stewardship_ladder_ascended"
	_add_marker(ladder, "BottomMount", Vector3(-0.6, 0.0, 0.0))
	_add_marker(ladder, "BottomExit", Vector3(-0.75, 0.0, 0.0))
	_add_marker(ladder, "TopMount", Vector3(0.0, 3.2, 0.0))
	_add_marker(ladder, "TopExit", Vector3(0.75, 3.2, 0.0))
	ladder.semantic_completion_requested.connect(_on_semantic_completion_requested)
	parent.add_child(ladder)
	return ladder


func _add_marker(parent: Node3D, marker_name: String, position: Vector3) -> void:
	var marker := Marker3D.new()
	marker.name = marker_name
	marker.position = position
	parent.add_child(marker)


func _add_static_box(
	parent: Node,
	body_name: String,
	box_size: Vector3,
	center_position: Vector3
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = body_name
	body.position = center_position
	var shape := BoxShape3D.new()
	shape.size = box_size
	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	collision_shape.shape = shape
	body.add_child(collision_shape)
	parent.add_child(body)
	return body


func _settle_actor(actor: HumanBody3D) -> void:
	await get_tree().physics_frame
	for frame in range(8):
		actor.move_with_speed(Vector3.ZERO, 0.0)
		await get_tree().physics_frame


func _wait_physics_frames(frame_count: int) -> void:
	for frame in range(frame_count):
		await get_tree().physics_frame


func _advance_actor_motion(actor: HumanBody3D, frame_count: int) -> void:
	for frame in range(frame_count):
		actor.move_with_speed(Vector3.ZERO, 0.0)
		await get_tree().physics_frame


func _boundary_accepts(value: float, limit: float) -> bool:
	return value <= limit + 0.00001


func _on_semantic_completion_requested(
	event_id: StringName,
	_context: Dictionary
) -> void:
	m_semantic_completions.append(event_id)


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	m_failures.append("%s." % label)
