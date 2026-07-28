extends Node3D

const HUMAN_BODY_SCENE := preload("res://characters/human_body_3d.tscn")
const PUSH_PULL_SCENE := preload(
	"res://architecture/trinity_church/trinity_push_pull_action_3d.tscn"
)
const CharacterActionController3DScript = preload(
	"res://characters/actions/character_action_controller_3d.gd"
)
const CharacterMotionIntent3DScript = preload(
	"res://characters/control/character_motion_intent_3d.gd"
)

const FIXED_DELTA := 1.0 / 60.0

var m_failures := PackedStringArray()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await get_tree().process_frame
	await _validate_authored_contract_and_alignment()
	await _validate_push_pull_speed_release_and_bounds()
	await _validate_blockage_without_impulse_buildup()
	await _validate_reset_recovery_and_required_path_protection()
	await _validate_goal_completion_and_cleanup()

	if m_failures.is_empty():
		print("PASS: character push/pull 3D")
	else:
		for failure in m_failures:
			push_error(failure)
		push_error(
			"Character push/pull 3D failed with %d issue(s)."
			% m_failures.size()
		)
	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0 if m_failures.is_empty() else 1)


func _validate_authored_contract_and_alignment() -> void:
	var fixture := await _create_fixture()
	var target: PushPullObject3D = fixture.target
	var actor: HumanBody3D = fixture.actor
	var collision_shape := target.get_node(
		"HymnChest/CollisionShape3D"
	) as CollisionShape3D
	var chest_shape := collision_shape.shape as BoxShape3D
	_assert_true(
		is_equal_approx(target.get_path_length(), 3.0)
			and is_equal_approx(target.get_goal_coordinate(), 2.5)
			and chest_shape != null
			and chest_shape.size.is_equal_approx(Vector3(0.8, 0.65, 0.55))
			and target.semantic_completion_id == &"trinity_hymn_chest_aligned",
		"The Trinity child scene authors the 0.80 x 0.55 x 0.65 m chest, "
			+ "3.00 m axis, 2.50 m goal, and exact semantic id"
	)

	var anchor := target.get_actor_anchor_transform()
	var push_axis := target.get_path_axis()
	var lateral_axis := Vector3.UP.cross(push_axis).normalized()
	actor.global_position = anchor.origin + lateral_axis * 0.12
	actor.set_direction_vector(push_axis)
	await _settle_actor(actor)
	_assert_true(
		target.is_action_available(actor),
		"An actor at exactly 0.12 m anchor error passes push/pull alignment"
	)
	actor.global_position = anchor.origin + lateral_axis * 0.13
	_assert_true(
		!target.is_action_available(actor),
		"An actor at 0.13 m anchor error is rejected"
	)

	actor.global_position = anchor.origin
	actor.set_direction_vector(push_axis.rotated(Vector3.UP, deg_to_rad(10.0)))
	await _settle_actor(actor)
	_assert_true(
		target.is_action_available(actor),
		"An actor at exactly 10 degrees passes push/pull facing alignment"
	)
	actor.set_direction_vector(push_axis.rotated(Vector3.UP, deg_to_rad(11.0)))
	_assert_true(
		!target.is_action_available(actor),
		"An actor at 11 degrees is rejected"
	)

	actor.global_position = anchor.origin
	actor.set_direction_vector(push_axis)
	await _settle_actor(actor)
	_assert_true(
		target.get_action_distance(actor) <= 1.10
			and target.begin_action(actor)
			and target.has_reserved_actor()
			and actor.get_action_mode() == (
				CharacterActionController3DScript.ActionMode.PUSH
			)
			and target.get_actor_anchor_error(actor) <= 0.001
			and target.get_actor_facing_error_degrees(actor) <= 0.01,
		"Entry inside the 1.10 m handle gate reserves one sustained action "
			+ "and aligns the actor exactly"
	)
	target.cancel_action(actor, &"cancel")
	fixture.root.queue_free()
	await get_tree().process_frame


func _validate_push_pull_speed_release_and_bounds() -> void:
	var fixture := await _create_fixture()
	var target: PushPullObject3D = fixture.target
	var actor: HumanBody3D = fixture.actor
	target.auto_complete_at_goal = false
	_assert_true(target.begin_action(actor), "Push/pull begins for speed validation")

	var start_coordinate := target.get_path_coordinate()
	var push_intent := _drive_action(target, actor, target.get_path_axis(), 0.20)
	var pushed_coordinate := target.get_path_coordinate()
	_assert_true(
		is_equal_approx(push_intent.movement_speed, 1.25)
			and absf(pushed_coordinate - start_coordinate - 0.25) <= 0.001
			and target.get_animation_action_mode() == (
				CharacterActionController3DScript.ActionMode.PUSH
			),
		"Push intent moves at exactly 1.25 m/s with the PUSH animation mode"
	)

	var pull_intent := _drive_action(target, actor, -target.get_path_axis(), 0.25)
	_assert_true(
		is_equal_approx(pull_intent.movement_speed, 1.00)
			and absf(target.get_path_coordinate() - start_coordinate) <= 0.001
			and target.get_animation_action_mode() == (
				CharacterActionController3DScript.ActionMode.PULL
			)
			and target.get_cross_axis_error() <= 0.001,
		"Pull intent moves at exactly 1.00 m/s and never leaves the authored axis"
	)

	var release_coordinate := target.get_path_coordinate()
	_assert_true(
		target.request_active_context_action(actor)
			and !target.has_reserved_actor()
			and actor.is_action_free()
			and absf(target.get_path_coordinate() - release_coordinate) <= 0.001,
		"R-style release preserves the last valid coordinate and frees the actor"
	)
	await _place_actor_at_anchor(actor, target)
	_assert_true(
		target.begin_action(actor),
		"The released chest can be re-engaged without transient impulse"
	)

	_drive_action(target, actor, target.get_path_axis(), 4.0)
	var maximum_coordinate := target.get_path_coordinate()
	_drive_action(target, actor, target.get_path_axis(), 1.0)
	_assert_true(
		absf(maximum_coordinate - 2.90) <= 0.001
			and absf(target.get_path_coordinate() - maximum_coordinate) <= 0.001
			and target.get_active_hint().contains("endpoint"),
		"The 3.00 m path stops 0.10 m before its hard maximum with no drift"
	)

	_drive_action(target, actor, -target.get_path_axis(), 4.0)
	var minimum_coordinate := target.get_path_coordinate()
	_drive_action(target, actor, -target.get_path_axis(), 1.0)
	_assert_true(
		absf(minimum_coordinate - 0.10) <= 0.001
			and absf(target.get_path_coordinate() - minimum_coordinate) <= 0.001,
		"The authored path also stops 0.10 m before its hard minimum"
	)

	target.cancel_action(actor, &"cancel")
	fixture.root.queue_free()
	await get_tree().process_frame


func _validate_blockage_without_impulse_buildup() -> void:
	var fixture := await _create_fixture()
	var target: PushPullObject3D = fixture.target
	var actor: HumanBody3D = fixture.actor
	target.auto_complete_at_goal = false
	target.set_constrained_coordinate(0.60)
	await _place_actor_at_anchor(actor, target)
	var object_blocker := _add_static_box(
		fixture.world,
		"ObjectBlocker",
		Vector3(0.30, 1.0, 1.0),
		Vector3(1.235, 0.50, 0.0)
	)
	await get_tree().physics_frame
	_assert_true(
		target.begin_action(actor),
		"A chest with one clear retreat direction can still be engaged"
	)
	var blocked_coordinate := target.get_path_coordinate()
	for frame in range(13):
		_drive_action(target, actor, target.get_path_axis(), FIXED_DELTA)
	_assert_true(
		target.is_blocked()
			and absf(target.get_path_coordinate() - blocked_coordinate) <= 0.001
			and target.get_active_hint().begins_with("Blocked"),
		"Less than 0.02 m progress for 0.20 s reports object blockage "
			+ "without drift"
	)

	object_blocker.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame
	var resumed_intent := _drive_action(
		target,
		actor,
		target.get_path_axis(),
		FIXED_DELTA
	)
	var resumed_progress := target.get_path_coordinate() - blocked_coordinate
	_assert_true(
		!target.is_blocked()
			and is_equal_approx(resumed_intent.movement_speed, 1.25)
			and absf(resumed_progress - 1.25 * FIXED_DELTA) <= 0.001,
		"Removing the blocker resumes at the fixed speed with no accumulated impulse"
	)

	var actor_blocker_position := (
		actor.global_position + target.get_path_axis() * 0.45
	)
	var actor_blocker := _add_static_box(
		fixture.world,
		"ActorSideBlocker",
		Vector3(0.30, 1.2, 0.70),
		Vector3(
			actor_blocker_position.x,
			0.60,
			actor_blocker_position.z
		)
	)
	await get_tree().physics_frame
	var side_blocked_coordinate := target.get_path_coordinate()
	for frame in range(13):
		_drive_action(target, actor, target.get_path_axis(), FIXED_DELTA)
	_assert_true(
		target.is_blocked()
			and absf(
				target.get_path_coordinate() - side_blocked_coordinate
			) <= 0.001,
		"An actor-side blocker stops the aligned pair without moving the chest"
	)
	actor_blocker.queue_free()
	target.cancel_action(actor, &"cancel")
	fixture.root.queue_free()
	await get_tree().process_frame


func _validate_reset_recovery_and_required_path_protection() -> void:
	var fixture := await _create_fixture()
	var target: PushPullObject3D = fixture.target
	var actor: HumanBody3D = fixture.actor
	target.auto_complete_at_goal = false
	actor.global_position = Vector3(0.0, 0.04, 1.5)
	await _settle_actor(actor)
	target.set_constrained_coordinate(1.50)
	await _wait_physics_frames(125)
	_assert_true(
		absf(target.get_path_coordinate() - 0.10) <= 0.001,
		"Blocking the required-path volume for 2.00 s resets the transient chest"
	)

	target.set_constrained_coordinate(1.50)
	var reset_position := (
		target.get_node("PathStart") as Node3D
	).global_position + target.get_path_axis() * 0.10
	var reset_blocker := _add_static_box(
		fixture.world,
		"ResetClearanceBlocker",
		Vector3(0.80, 0.65, 0.55),
		reset_position
	)
	await get_tree().physics_frame
	_assert_true(
		!target.reset_to_authored_origin(&"blocked_reset")
			and absf(target.get_path_coordinate() - 1.50) <= 0.001,
		"A reset is rejected when the authored shape lacks 0.10 m clearance"
	)
	reset_blocker.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame
	_assert_true(
		target.reset_to_authored_origin(&"clear_reset")
			and absf(target.get_path_coordinate() - 0.10) <= 0.001,
		"Removing the reset obstruction restores the authored coordinate"
	)

	await _place_actor_at_anchor(actor, target)
	_assert_true(target.begin_action(actor), "Push/pull begins for recovery cleanup")
	_drive_action(target, actor, target.get_path_axis(), 0.20)
	var last_valid := target.get_last_valid_coordinate()
	var body := target.get_movable_body()
	body.global_position += Vector3(0.0, 0.0, 0.04)
	_assert_true(
		target.recover_object(&"recovery")
			and !target.has_reserved_actor()
			and actor.is_action_free()
			and absf(target.get_path_coordinate() - last_valid) <= 0.001
			and target.get_cross_axis_error() <= 0.001,
		"Forced recovery snaps to the last clear coordinate and releases alignment"
	)

	actor.global_position = Vector3(0.0, 0.04, 1.5)
	await _settle_actor(actor)
	body.global_position += Vector3.DOWN * 2.01
	await get_tree().physics_frame
	_assert_true(
		absf(target.get_path_coordinate() - 0.10) <= 0.001
			and target.get_cross_axis_error() <= 0.001,
		"A 2.00 m object drop threshold restores the authored origin"
	)

	fixture.root.queue_free()
	await get_tree().process_frame


func _validate_goal_completion_and_cleanup() -> void:
	var fixture := await _create_fixture()
	var target: PushPullObject3D = fixture.target
	var actor: HumanBody3D = fixture.actor
	var completions: Array[StringName] = []
	target.semantic_completion_requested.connect(
		func(event_id: StringName, _context: Dictionary) -> void:
			completions.append(event_id)
	)
	_assert_true(target.begin_action(actor), "Push/pull begins for goal completion")
	_drive_action(target, actor, target.get_path_axis(), 2.0)
	_assert_true(
		!target.has_reserved_actor()
			and actor.is_action_free()
			and target.is_goal_completed()
			and completions == [&"trinity_hymn_chest_aligned"],
		"Reaching the 2.50 m goal tolerance publishes the exact semantic once "
			+ "and releases"
	)

	await get_tree().physics_frame
	var reload_reset := target.reset_to_authored_origin(&"reload_reset")
	_assert_true(
		reload_reset,
		"Transient chest state can reset independently of semantic history"
	)
	await _place_actor_at_anchor(actor, target)
	_assert_true(target.begin_action(actor), "The reset chest can be moved again")
	_drive_action(target, actor, target.get_path_axis(), 2.0)
	_assert_true(
		completions.size() == 1,
		"Repeated physical completion on one scene instance is semantically idempotent"
	)

	await get_tree().physics_frame
	target.reset_to_authored_origin(&"pause_setup")
	await _place_actor_at_anchor(actor, target)
	_assert_true(target.begin_action(actor), "Push/pull begins for pause cleanup")
	_drive_action(target, actor, target.get_path_axis(), 0.20)
	var pause_coordinate := target.get_last_valid_coordinate()
	target.cancel_action(actor, &"pause")
	_assert_true(
		!target.has_reserved_actor()
			and actor.is_action_free()
			and absf(target.get_path_coordinate() - pause_coordinate) <= 0.001,
		"Pause cleanup snaps to the last valid coordinate and clears ownership"
	)

	await _place_actor_at_anchor(actor, target)
	_assert_true(target.begin_action(actor), "Push/pull begins for unload cleanup")
	target.cancel_action(actor, &"scene_unload")
	_assert_true(
		!target.has_reserved_actor() and actor.is_action_free(),
		"Scene-unload cleanup releases both target and actor state"
	)

	fixture.root.queue_free()
	await get_tree().process_frame


func _create_fixture() -> Dictionary:
	var root := Node3D.new()
	root.name = "PushPullFixture"
	add_child(root)
	var world := Node3D.new()
	world.name = "World"
	root.add_child(world)
	_add_static_box(
		world,
		"Floor",
		Vector3(8.0, 0.10, 4.0),
		Vector3(1.5, -0.05, 0.0)
	)
	var target := PUSH_PULL_SCENE.instantiate() as PushPullObject3D
	world.add_child(target)
	await get_tree().process_frame
	var actor := HUMAN_BODY_SCENE.instantiate() as HumanBody3D
	actor.name = "Actor"
	actor.character_model_scene = null
	actor.draw_skeleton_bones = false
	actor.body_height = 1.72
	actor.body_radius = 0.28
	world.add_child(actor)
	await _place_actor_at_anchor(actor, target)
	return {
		"root": root,
		"world": world,
		"target": target,
		"actor": actor,
	}


func _place_actor_at_anchor(
	actor: HumanBody3D,
	target: PushPullObject3D
) -> void:
	actor.global_position = target.get_actor_anchor_transform().origin
	actor.set_direction_vector(target.get_path_axis())
	await _settle_actor(actor)


func _drive_action(
	target: PushPullObject3D,
	actor: HumanBody3D,
	direction: Vector3,
	delta: float
) -> CharacterMotionIntent3D:
	var intent := CharacterMotionIntent3DScript.new(direction, 9.0)
	var constrained := target.constrain_motion_intent(actor, intent, delta)
	target.before_actor_motion(actor, constrained, delta)
	if constrained.is_moving():
		actor.global_position += (
			constrained.direction * constrained.movement_speed * delta
		)
	target.after_actor_motion(actor, constrained, delta)
	return constrained


func _add_static_box(
	parent: Node3D,
	node_name: String,
	size: Vector3,
	position: Vector3
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	var collision_shape := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
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


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	m_failures.append("%s." % label)
