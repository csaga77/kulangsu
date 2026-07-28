extends Node3D

const HUMAN_BODY_SCENE := preload("res://characters/human_body_3d.tscn")
const SEAT_SCRIPT := preload("res://game/world/seat_3d.gd")
const PIANO_FERRY_SEAT_SCENE := preload(
	"res://architecture/piano_ferry/piano_ferry_seat_action_3d.tscn"
)

class NoExitSeat3D:
	extends "res://game/world/seat_3d.gd"

	func find_clear_exit_transform(_actor: CharacterBody3D) -> Transform3D:
		return Transform3D.IDENTITY


var m_failures := PackedStringArray()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await get_tree().process_frame
	await _test_entry_occupancy_listening_and_exit()
	await _test_cleanup_and_recovery_fallback()

	if m_failures.is_empty():
		print("PASS: character sit 3D")
	else:
		for failure in m_failures:
			push_error(failure)
		push_error(
			"Character sit 3D failed with %d issue(s)."
			% m_failures.size()
		)

	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0 if m_failures.is_empty() else 1)


func _test_entry_occupancy_listening_and_exit() -> void:
	var fixture_root := Node3D.new()
	fixture_root.name = "SitFixture"
	add_child(fixture_root)
	_add_static_floor(fixture_root, Vector3.ZERO, Vector3(12.0, 0.1, 12.0))

	var production_action := PIANO_FERRY_SEAT_SCENE.instantiate() as Node3D
	production_action.name = "ProductionSeatAction"
	fixture_root.add_child(production_action)
	var seat: Variant = production_action.get_node("Seat")
	seat.listening_duration = 0.10

	var camera := Camera3D.new()
	camera.name = "CameraContinuityProbe"
	camera.global_transform = Transform3D(
		Basis.from_euler(Vector3(-0.35, 0.7, 0.0)),
		Vector3(2.0, 3.2, 4.0)
	)
	fixture_root.add_child(camera)
	var camera_transform := camera.global_transform

	var actor := await _add_actor(
		fixture_root,
		seat.get_seat_transform().origin + Vector3.RIGHT * 1.10
	)
	actor.set_direction_vector(Vector3.LEFT)
	_assert_true(
		seat.is_action_available(actor),
		"Seat accepts the exact 1.10 m entry boundary"
	)
	actor.global_position = (
		seat.get_seat_transform().origin + Vector3.RIGHT * 1.11
	)
	_assert_true(
		!seat.is_action_available(actor),
		"Seat rejects the 1.11 m entry boundary"
	)
	actor.global_position = (
		seat.get_seat_transform().origin + Vector3.RIGHT * 1.10
	)

	var entry_blocker := _add_blocker(
		fixture_root,
		seat.get_seat_transform().origin + Vector3.UP * 1.2,
		Vector3(0.2, 0.2, 0.2)
	)
	await get_tree().physics_frame
	_assert_true(
		!seat.is_action_available(actor),
		"Occupied capsule clearance rejects an intruding seat blocker"
	)
	entry_blocker.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_assert_true(
		seat.is_action_available(actor),
		"Seat becomes available after occupied capsule clearance is restored"
	)

	var completion_ids: Array[StringName] = []
	var completion_contexts: Array[Dictionary] = []
	seat.semantic_completion_requested.connect(
		func(event_id: StringName, context: Dictionary) -> void:
			completion_ids.append(event_id)
			completion_contexts.append(context.duplicate(true))
	)
	var alignment_start := actor.global_transform
	_assert_true(
		seat.begin_action(actor)
			and seat.get_seat_state() == SEAT_SCRIPT.SeatState.ALIGNING
			and seat.is_occupied()
			and actor.get_action_mode() == SEAT_SCRIPT.SIT_ACTION_MODE,
		"Sit entry reserves the seat and starts its alignment"
	)

	var competing_actor := await _add_actor(
		fixture_root,
		seat.get_seat_transform().origin + Vector3.RIGHT
	)
	competing_actor.set_direction_vector(Vector3.LEFT)
	_assert_true(
		!seat.is_action_available(competing_actor),
		"Seat occupancy rejects a second actor"
	)
	competing_actor.queue_free()
	await get_tree().physics_frame

	await _wait_physics_frames(10)
	_assert_true(
		seat.get_seat_state() == SEAT_SCRIPT.SeatState.ALIGNING
			and actor.global_position.distance_to(alignment_start.origin) > 0.01
			and actor.global_position.distance_to(
				seat.get_seat_transform().origin
			) > 0.01,
		"Seat alignment remains in progress before the accepted 0.35 s duration"
	)
	await _wait_physics_frames(13)
	_assert_true(
		seat.get_seat_state() == SEAT_SCRIPT.SeatState.SEATED
			and actor.global_transform.is_equal_approx(
				seat.get_seat_transform()
			),
		"Seat alignment settles exactly on the authored anchor after 0.35 s"
	)
	_assert_true(
		camera.global_transform.is_equal_approx(camera_transform),
		"Sitting leaves camera ownership and orbit continuity untouched"
	)

	var motion_intent := CharacterMotionIntent3D.new(Vector3.RIGHT, 7.5)
	var constrained_intent: CharacterMotionIntent3D = seat.constrain_motion_intent(
		actor,
		motion_intent,
		1.0 / 60.0
	)
	_assert_true(
		constrained_intent != null
			and !constrained_intent.is_moving()
			and actor.velocity.is_zero_approx(),
		"Sitting locks movement intent without disabling camera control"
	)

	await _wait_physics_frames(12)
	_assert_true(
		completion_ids == [&"harbor_sea_melody_listened"]
			and completion_contexts.size() == 1
			and is_equal_approx(
				float(completion_contexts[0].get("listening_duration", -1.0)),
				seat.listening_duration
			),
		"Authored listening duration publishes the exact semantic id once"
	)

	var candidates: Array[Transform3D] = seat.get_exit_search_candidates()
	var candidate_contract_ok: bool = candidates.size() == 25
	if candidate_contract_ok:
		candidate_contract_ok = (
			is_equal_approx(
				candidates[0].origin.distance_to(
					seat.get_seat_transform().origin
				),
				SEAT_SCRIPT.PRIMARY_EXIT_DISTANCE
			)
			and _ring_has_radius(candidates, 1, 8, 0.75, seat)
			and _ring_has_radius(candidates, 9, 16, 1.00, seat)
			and _ring_has_radius(candidates, 17, 24, 1.25, seat)
		)
	_assert_true(
		candidate_contract_ok,
		"Exit search uses primary 0.90 m then eight directions at 0.75/1.00/1.25 m"
	)

	var primary_exit: Transform3D = seat.get_primary_exit_transform()
	var selected_exit: Transform3D = seat.find_clear_exit_transform(actor)
	_assert_true(
		selected_exit != Transform3D.IDENTITY
			and !selected_exit.is_equal_approx(primary_exit),
		"Production blocker rejects the primary exit and selects a clear radial fallback"
	)
	_assert_true(
		seat.request_active_context_action(actor)
			and seat.get_seat_state() == SEAT_SCRIPT.SeatState.EXITING,
		"Active R input starts an immediate seat exit"
	)
	await _wait_physics_frames(20)
	_assert_true(
		seat.get_seat_state() == SEAT_SCRIPT.SeatState.IDLE
			and !seat.is_occupied()
			and actor.is_action_free()
			and actor.global_transform.is_equal_approx(selected_exit),
		"R exit settles at the first clear fallback after the 0.30 s exit blend"
	)

	await _place_actor_for_entry(actor, seat, 0.85)
	seat.entry_alignment_duration = 0.0
	_assert_true(
		seat.begin_action(actor),
		"Seat can be entered again after occupancy release"
	)
	await get_tree().physics_frame
	seat.cancel_action(actor, &"cancel")
	_assert_true(
		seat.get_seat_state() == SEAT_SCRIPT.SeatState.EXITING,
		"Esc cancellation starts the same immediate exit path"
	)
	await _wait_physics_frames(20)
	_assert_true(
		!seat.is_occupied()
			and completion_ids.size() == 1,
		"Esc releases occupancy without duplicating listening completion"
	)

	actor.queue_free()
	fixture_root.queue_free()
	await get_tree().process_frame


func _test_cleanup_and_recovery_fallback() -> void:
	var fixture_root := Node3D.new()
	fixture_root.name = "SitCleanupFixture"
	add_child(fixture_root)
	_add_static_floor(fixture_root, Vector3.ZERO, Vector3(14.0, 0.1, 14.0))

	var production_action := PIANO_FERRY_SEAT_SCENE.instantiate() as Node3D
	fixture_root.add_child(production_action)
	var seat: Variant = production_action.get_node("Seat")
	seat.entry_alignment_duration = 0.0
	var actor := await _add_actor(
		fixture_root,
		seat.get_seat_transform().origin + Vector3.BACK * 0.85
	)
	actor.set_direction_vector(Vector3.FORWARD)

	_assert_true(seat.begin_action(actor), "Seat enters for pause cleanup coverage")
	await get_tree().physics_frame
	seat.cancel_action(actor, &"pause")
	_assert_true(
		seat.get_seat_state() == SEAT_SCRIPT.SeatState.IDLE
			and !seat.is_occupied()
			and actor.is_action_free(),
		"Pause resolves a clear exit and releases occupancy synchronously"
	)

	await _place_actor_for_entry(actor, seat, 0.85)
	_assert_true(
		seat.begin_action(actor),
		"Seat enters for forced recovery cleanup coverage"
	)
	await get_tree().physics_frame
	var recovery_origin := actor.global_position
	seat.cancel_action(actor, &"recovery")
	_assert_true(
		!seat.is_occupied()
			and seat.get_seat_state() == SEAT_SCRIPT.SeatState.IDLE
			and actor.is_action_free()
			and actor.global_position.is_equal_approx(recovery_origin),
		"Forced recovery releases occupancy without overriding the player safe anchor"
	)

	await _place_actor_for_entry(actor, seat, 0.85)
	_assert_true(
		seat.begin_action(actor),
		"Seat enters for scene-unload cleanup coverage"
	)
	await get_tree().physics_frame
	production_action.queue_free()
	await get_tree().process_frame
	_assert_true(
		!is_instance_valid(production_action),
		"Scene unload settles the seat before local state teardown"
	)

	var no_exit_seat := NoExitSeat3D.new()
	no_exit_seat.name = "NoExitSeat"
	no_exit_seat.position = Vector3(3.0, 0.0, 0.0)
	no_exit_seat.entry_alignment_duration = 0.0
	fixture_root.add_child(no_exit_seat)
	await _place_actor_for_entry(actor, no_exit_seat, 0.85)
	var safe_transform := Transform3D(
		Basis.from_euler(Vector3(0.0, 0.25, 0.0)),
		Vector3(2.0, 0.0, -1.0)
	)
	actor.set_safe_transform(safe_transform)
	_assert_true(
		no_exit_seat.begin_action(actor),
		"Seat enters for no-clear-exit recovery coverage"
	)
	await get_tree().physics_frame
	_assert_true(
		no_exit_seat.request_active_context_action(actor)
			and !no_exit_seat.is_occupied()
			and actor.is_action_free()
			and actor.is_recovering()
			and actor.global_transform.is_equal_approx(safe_transform),
		"No clear exit releases occupancy and invokes player safe-anchor recovery"
	)

	no_exit_seat.queue_free()
	actor.queue_free()
	fixture_root.queue_free()
	await get_tree().process_frame


func _add_actor(parent: Node3D, position: Vector3) -> HumanBody3D:
	var actor := HUMAN_BODY_SCENE.instantiate() as HumanBody3D
	actor.character_model_scene = null
	actor.draw_skeleton_bones = false
	parent.add_child(actor)
	actor.global_position = position + Vector3.UP * 0.04
	await _settle_actor(actor)
	return actor


func _place_actor_for_entry(
	actor: HumanBody3D,
	seat: Variant,
	distance: float
) -> void:
	actor.global_position = (
		seat.get_seat_transform().origin
		+ seat.get_seat_transform().basis.x.normalized() * distance
		+ Vector3.UP * 0.04
	)
	actor.set_direction_vector(-seat.get_seat_transform().basis.x.normalized())
	await _settle_actor(actor)


func _add_static_floor(
	parent: Node3D,
	position: Vector3,
	size: Vector3
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Floor"
	body.position = position - Vector3.UP * size.y * 0.5
	var collision_shape := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision_shape.shape = shape
	body.add_child(collision_shape)
	parent.add_child(body)
	return body


func _add_blocker(
	parent: Node3D,
	position: Vector3,
	size: Vector3
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "ClearanceBlocker"
	body.position = position
	var collision_shape := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision_shape.shape = shape
	body.add_child(collision_shape)
	parent.add_child(body)
	return body


func _ring_has_radius(
	candidates: Array[Transform3D],
	first_index: int,
	last_index: int,
	expected_radius: float,
	seat: Variant
) -> bool:
	for index in range(first_index, last_index + 1):
		if !is_equal_approx(
			candidates[index].origin.distance_to(
				seat.get_seat_transform().origin
			),
			expected_radius
		):
			return false
	return true


func _settle_actor(actor: HumanBody3D) -> void:
	await get_tree().physics_frame
	for _frame in range(8):
		actor.move_with_speed(Vector3.ZERO, 0.0)
		await get_tree().physics_frame


func _wait_physics_frames(frame_count: int) -> void:
	for _frame in range(frame_count):
		await get_tree().physics_frame


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	m_failures.append("%s." % label)
