extends Node3D

const HUMAN_BODY_SCENE := preload("res://characters/human_body_3d.tscn")
const LADDER_SCRIPT := preload("res://game/world/ladder_3d.gd")
const MOTION_INTENT_SCRIPT := preload(
	"res://characters/control/character_motion_intent_3d.gd"
)
const FIXED_DELTA := 1.0 / 60.0
const LADDER_CLIMB_FRAMES := 112
const MOTION_EPSILON := 0.015

var m_failures := PackedStringArray()
var m_semantic_completions: Array[StringName] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await get_tree().physics_frame
	await _validate_jump_buffer_boundaries()
	await _validate_coyote_boundaries()
	await _validate_air_control_boundaries()
	await _validate_obstacle_boundaries()
	await _validate_gap_boundaries()
	await _validate_floor_snap_boundaries()
	await _validate_landing_depth_boundaries()
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


func _validate_jump_buffer_boundaries() -> void:
	var fixture := Node3D.new()
	fixture.name = "JumpBufferFixture"
	add_child(fixture)
	_add_static_box(
		fixture,
		"LandingFloor",
		Vector3(3.0, 0.1, 3.0),
		Vector3(0.0, -0.05, 0.0)
	)
	var accepted_actor := _create_actor(
		"AcceptedBufferActor",
		Vector3(0.0, 0.4, 0.0),
		true,
		fixture
	)
	await get_tree().physics_frame
	accepted_actor.move_with_speed(Vector3.ZERO, 0.0)
	_assert_true(
		!accepted_actor.request_jump(),
		"A pre-landing press queues while the actor is physically airborne"
	)
	accepted_actor._advance_transient_timers(0.16)
	_force_physical_landing(accepted_actor)
	_assert_true(
		accepted_actor.is_airborne()
			and accepted_actor.velocity.y > 4.0
			and accepted_actor.get_jump_buffer_remaining() <= MOTION_EPSILON,
		"A press exactly 0.16 s before physical landing starts one buffered jump"
	)

	var rejected_actor := _create_actor(
		"RejectedBufferActor",
		Vector3(0.0, 0.4, 1.0),
		true,
		fixture
	)
	await get_tree().physics_frame
	rejected_actor.move_with_speed(Vector3.ZERO, 0.0)
	_assert_true(
		!rejected_actor.request_jump(),
		"The rejected buffer probe also starts from an airborne queued press"
	)
	rejected_actor._advance_transient_timers(0.17)
	_force_physical_landing(rejected_actor)
	_assert_true(
		rejected_actor.is_on_floor()
			and rejected_actor.velocity.y <= 0.0
			and !rejected_actor.is_airborne(),
		"A press 0.17 s before physical landing expires without a jump"
	)
	fixture.queue_free()
	await get_tree().process_frame


func _validate_coyote_boundaries() -> void:
	var fixture := Node3D.new()
	fixture.name = "CoyoteFixture"
	add_child(fixture)
	_add_static_box(
		fixture,
		"SharpEdgePlatform",
		Vector3(2.0, 0.1, 4.0),
		Vector3(-1.0, -0.05, 0.0)
	)
	var accepted_actor := _create_actor(
		"AcceptedCoyoteActor",
		Vector3(-0.65, 0.04, -1.0),
		true,
		fixture
	)
	await _settle_actor(accepted_actor)
	await _drive_actor_off_edge(accepted_actor)
	# 60 Hz frames are wider than the 0.01 s boundary pair. The actor first
	# leaves real collision geometry, then the exact request age is injected.
	accepted_actor.set("m_time_since_grounded", 0.18)
	_assert_true(
		!accepted_actor.is_on_floor()
			and accepted_actor.request_jump()
			and accepted_actor.velocity.y > 4.0,
		"A jump requested 0.18 s after physical edge departure uses coyote time"
	)

	var rejected_actor := _create_actor(
		"RejectedCoyoteActor",
		Vector3(-0.65, 0.04, 1.0),
		true,
		fixture
	)
	await _settle_actor(rejected_actor)
	await _drive_actor_off_edge(rejected_actor)
	rejected_actor.set("m_time_since_grounded", 0.19)
	_assert_true(
		!rejected_actor.is_on_floor()
			and !rejected_actor.request_jump()
			and rejected_actor.velocity.y <= 0.0,
		"A jump requested 0.19 s after physical edge departure is rejected"
	)
	fixture.queue_free()
	await get_tree().process_frame


func _validate_air_control_boundaries() -> void:
	var fixture := Node3D.new()
	fixture.name = "AirControlFixture"
	add_child(fixture)
	_add_static_box(
		fixture,
		"TakeoffFloor",
		Vector3(6.0, 0.1, 6.0),
		Vector3.ZERO - Vector3(0.0, 0.05, 0.0)
	)
	var capped_actor := _create_actor(
		"CappedTakeoffActor",
		Vector3(-1.5, 0.04, 0.0),
		true,
		fixture
	)
	await _settle_actor(capped_actor)
	capped_actor.velocity.x = 7.5
	_assert_true(capped_actor.request_jump(), "The speed-cap probe starts a physical jump")
	var capped_horizontal := Vector2(
		capped_actor.velocity.x,
		capped_actor.velocity.z
	).length()
	_assert_true(
		is_equal_approx(capped_horizontal, 4.5),
		"Physical takeoff caps horizontal speed at 4.50 m/s"
	)

	var steering_actor := _create_actor(
		"SteeringActor",
		Vector3(1.5, 0.04, 0.0),
		true,
		fixture
	)
	await _settle_actor(steering_actor)
	_assert_true(steering_actor.request_jump(), "The steering probe starts from rest")
	steering_actor.move_with_speed(Vector3.RIGHT, 4.5)
	var first_step_speed := Vector2(
		steering_actor.velocity.x,
		steering_actor.velocity.z
	).length()
	_assert_true(
		absf(first_step_speed - 6.0 * FIXED_DELTA) <= 0.001,
		"One airborne physics step applies 6.00 m/s² steering acceleration"
	)
	for frame in range(20):
		steering_actor.move_with_speed(Vector3.RIGHT, 4.5)
	_assert_true(
		Vector2(
			steering_actor.velocity.x,
			steering_actor.velocity.z
		).length() <= 1.0 + 0.001,
		"Repeated airborne steering cannot exceed 1.00 m/s total takeoff correction"
	)
	fixture.queue_free()
	await get_tree().process_frame


func _validate_obstacle_boundaries() -> void:
	var accepted := await _run_obstacle_fixture(0.45, "AcceptedObstacle")
	_assert_true(
		bool(accepted.get("started", false))
			and bool(accepted.get("cleared", false))
			and float(accepted.get("maximum_foot_height", 0.0)) > 0.45,
		"A physical full-press jump clears the authored 0.45 m obstacle"
	)
	var rejected := await _run_obstacle_fixture(0.55, "RejectedObstacle")
	_assert_true(
		bool(rejected.get("started", false))
			and !bool(rejected.get("cleared", true))
			and float(rejected.get("maximum_x", INF)) < 0.62,
		"A 0.55 m obstacle physically blocks the same jump without mantling"
	)


func _validate_gap_boundaries() -> void:
	var accepted := await _run_gap_fixture(1.20, 2.40, 1.40, "AcceptedGap")
	_assert_true(
		bool(accepted.get("started", false))
			and bool(accepted.get("landed_far_side", false)),
		"A tuned physical traversal jump crosses the required 1.20 m clear span"
	)
	var rejected := await _run_gap_fixture(1.35, 2.40, 1.40, "RejectedGap")
	_assert_true(
		bool(rejected.get("started", false))
			and !bool(rejected.get("landed_far_side", true)),
		"The same jump rejects the explicitly non-required 1.35 m span"
	)


func _validate_floor_snap_boundaries() -> void:
	var accepted := await _run_floor_snap_fixture(0.12, "AcceptedFloorSnap")
	_assert_true(
		bool(accepted.get("stayed_grounded", false))
			and absf(float(accepted.get("final_y", INF)) + 0.12) <= 0.02,
		"A 0.12 m downward step remains physically floor-snapped"
	)
	var rejected := await _run_floor_snap_fixture(0.13, "RejectedFloorSnap")
	_assert_true(
		!bool(rejected.get("stayed_grounded", true)),
		"A 0.13 m downward step leaves the floor-snap envelope"
	)


func _validate_landing_depth_boundaries() -> void:
	var accepted := await _run_gap_fixture(1.00, 4.0, 1.40, "AcceptedLandingDepth")
	_assert_true(
		bool(accepted.get("started", false))
			and bool(accepted.get("landed_far_side", false))
			and float(accepted.get("landing_x", -INF)) <= 2.40,
		"A 1.40 m-deep far pad physically accepts the required landing"
	)
	var rejected := await _run_gap_fixture(1.00, 4.0, 0.70, "RejectedLandingDepth")
	_assert_true(
		bool(rejected.get("started", false))
			and !bool(rejected.get("landed_far_side", true)),
		"A 0.70 m-deep far pad is physically overshot and is not accepted"
	)


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

	var actor_collision := actor.get_node("CollisionShape3D") as CollisionShape3D
	var actor_capsule := actor_collision.shape as CapsuleShape3D
	var actor_radius_before := actor_capsule.radius
	var actor_height_before := actor_capsule.height
	var endpoint_capsule := ladder._build_expanded_endpoint_shape(
		actor_capsule
	) as CapsuleShape3D
	_assert_true(
		endpoint_capsule != actor_capsule
			and is_equal_approx(
				endpoint_capsule.radius,
				actor_radius_before + 0.10
			)
			and is_equal_approx(
				endpoint_capsule.height,
				actor_height_before + 0.20
			)
			and is_equal_approx(actor_capsule.radius, actor_radius_before)
			and is_equal_approx(actor_capsule.height, actor_height_before),
		"Endpoint clearance duplicates and expands the capsule by 0.10 m radially "
			+ "and 0.20 m vertically without changing the actor shape"
	)
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
	var reached_blocked_endpoint := await _wait_for_ladder_blocked_endpoint(
		ladder,
		LADDER_CLIMB_FRAMES + 18
	)
	var blocked_position := actor.global_position
	await _wait_physics_frames(11)
	_assert_true(
		reached_blocked_endpoint
			and !bool(ladder.get("m_blocked_retreating"))
			and actor.global_position.distance_to(blocked_position) <= 0.001,
		"A blocked ladder endpoint holds position before 0.20 s of continuous contact"
	)
	await _wait_physics_frames(1)
	_assert_true(
		bool(ladder.get("m_blocked_retreating"))
			and actor.global_position.distance_to(blocked_position) <= 0.001,
		"At exactly 0.20 s the blocked retreat starts without teleporting the actor"
	)
	await _wait_physics_frames(6)
	var half_retreat_distance := actor.global_position.distance_to(blocked_position)
	_assert_true(
		absf(half_retreat_distance - 0.175) <= 0.01,
		"The blocked retreat covers half of 0.35 m after 0.10 s"
	)
	await _wait_physics_frames(6)
	Input.action_release("ui_up")
	var completed_retreat_distance := actor.global_position.distance_to(
		blocked_position
	)
	_assert_true(
		ladder.is_mounted()
			and actor.is_on_ladder()
			and absf(completed_retreat_distance - 0.35) <= 0.01
			and ladder.get_climb_progress() < 1.0,
		"A blocked top exit retreats exactly 0.35 m over 0.20 s and remains mounted"
	)
	var retreat_progress: float = float(ladder.get_climb_progress())
	Input.action_press("ui_down")
	await _wait_physics_frames(1)
	Input.action_release("ui_down")
	var away_progress: float = float(ladder.get_climb_progress())
	_assert_true(
		away_progress < retreat_progress,
		"A blocked endpoint accepts immediate movement away after retreat"
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


func _run_obstacle_fixture(
	obstacle_height: float,
	fixture_name: String
) -> Dictionary:
	var fixture := Node3D.new()
	fixture.name = fixture_name
	add_child(fixture)
	_add_static_box(
		fixture,
		"ApproachAndLanding",
		Vector3(6.0, 0.1, 2.0),
		Vector3(0.0, -0.05, 0.0)
	)
	_add_static_box(
		fixture,
		"Obstacle",
		Vector3(0.60, obstacle_height, 2.0),
		Vector3(0.30, obstacle_height * 0.5, 0.0)
	)
	var actor := _create_actor(
		"%sActor" % fixture_name,
		Vector3(-0.74, 0.04, 0.0),
		true,
		fixture
	)
	await _settle_actor(actor)
	actor.move_with_speed(Vector3.RIGHT, 4.5)
	var started := actor.request_jump()
	var maximum_x := actor.global_position.x
	var maximum_foot_height := actor.global_position.y
	var cleared := false
	var left_floor := false
	for frame in range(60):
		actor.move_with_speed(Vector3.RIGHT, 4.5)
		maximum_x = maxf(maximum_x, actor.global_position.x)
		maximum_foot_height = maxf(
			maximum_foot_height,
			actor.global_position.y
		)
		if !actor.is_on_floor():
			left_floor = true
		if actor.global_position.x > 0.65:
			cleared = true
		if left_floor and actor.is_on_floor():
			break
		await get_tree().physics_frame
	var result := {
		"started": started,
		"cleared": cleared,
		"maximum_x": maximum_x,
		"maximum_foot_height": maximum_foot_height,
	}
	fixture.queue_free()
	await get_tree().process_frame
	return result


func _run_gap_fixture(
	gap_width: float,
	takeoff_speed: float,
	landing_depth: float,
	fixture_name: String
) -> Dictionary:
	var fixture := Node3D.new()
	fixture.name = fixture_name
	add_child(fixture)
	_add_static_box(
		fixture,
		"Approach",
		Vector3(3.0, 0.1, 2.0),
		Vector3(-1.5, -0.05, 0.0)
	)
	_add_static_box(
		fixture,
		"FarPad",
		Vector3(landing_depth, 0.1, 2.0),
		Vector3(gap_width + landing_depth * 0.5, -0.05, 0.0)
	)
	var actor := _create_actor(
		"%sActor" % fixture_name,
		Vector3(-0.34, 0.04, 0.0),
		true,
		fixture
	)
	await _settle_actor(actor)
	actor.move_with_speed(Vector3.RIGHT, takeoff_speed)
	var started := actor.request_jump()
	var landed_far_side := false
	var landing_x := -INF
	var left_approach := false
	for frame in range(90):
		actor.move_with_speed(Vector3.RIGHT, takeoff_speed)
		if actor.global_position.x > 0.05:
			left_approach = true
		if (
			left_approach
			and actor.is_on_floor()
			and actor.global_position.x >= gap_width - MOTION_EPSILON
			and actor.global_position.x <= gap_width + landing_depth + MOTION_EPSILON
		):
			landed_far_side = true
			landing_x = actor.global_position.x
			break
		if actor.global_position.y < -1.0:
			break
		await get_tree().physics_frame
	var result := {
		"started": started,
		"landed_far_side": landed_far_side,
		"landing_x": landing_x,
		"final_position": actor.global_position,
	}
	fixture.queue_free()
	await get_tree().process_frame
	return result


func _run_floor_snap_fixture(
	drop_height: float,
	fixture_name: String
) -> Dictionary:
	var fixture := Node3D.new()
	fixture.name = fixture_name
	add_child(fixture)
	_add_static_box(
		fixture,
		"UpperFloor",
		Vector3(2.0, 0.1, 2.0),
		Vector3(-1.0, -0.05, 0.0)
	)
	_add_static_box(
		fixture,
		"LowerFloor",
		Vector3(2.0, 0.1, 2.0),
		Vector3(1.0, -drop_height - 0.05, 0.0)
	)
	var actor := _create_actor(
		"%sActor" % fixture_name,
		Vector3(-0.65, 0.04, 0.0),
		true,
		fixture
	)
	await _settle_actor(actor)
	actor.global_position = Vector3(0.40, 0.0, 0.0)
	actor.velocity = Vector3.ZERO
	actor.move_and_slide()
	actor.apply_floor_snap()
	var snapped_to_lower_floor := (
		actor.is_on_floor()
		and absf(actor.global_position.y + drop_height) <= 0.02
	)
	var result := {
		"crossed_edge": true,
		"stayed_grounded": snapped_to_lower_floor,
		"final_y": actor.global_position.y,
	}
	fixture.queue_free()
	await get_tree().process_frame
	return result


func _drive_actor_off_edge(actor: HumanBody3D) -> void:
	for frame in range(30):
		actor.move_with_speed(Vector3.RIGHT, 4.5)
		await get_tree().physics_frame
		if !actor.is_on_floor() and actor.global_position.x > 0.0:
			return
	_assert_true(false, "%s physically leaves the sharp platform edge" % actor.name)


func _force_physical_landing(actor: HumanBody3D) -> void:
	actor.global_position.y = 0.005
	actor.velocity = Vector3(0.0, -1.0, 0.0)
	var still_intent = MOTION_INTENT_SCRIPT.new(Vector3.ZERO, 0.0)
	actor._integrate_motion_intent(still_intent, FIXED_DELTA)


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


func _wait_for_ladder_blocked_endpoint(
	ladder: Node,
	max_frame_count: int
) -> bool:
	for frame in range(max_frame_count):
		await get_tree().physics_frame
		if int(ladder.get("m_blocked_endpoint")) == 1:
			return true
	return false


func _advance_actor_motion(actor: HumanBody3D, frame_count: int) -> void:
	for frame in range(frame_count):
		actor.move_with_speed(Vector3.ZERO, 0.0)
		await get_tree().physics_frame


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
