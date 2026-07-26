extends Node3D

const HUMAN_BODY_SCENE := preload("res://characters/human_body_3d.tscn")
const ACTION_TARGET_SCRIPT := preload("res://game/world/character_action_target_3d.gd")
const WORLD_COORDINATOR_SCRIPT := preload("res://game/world/world_action_coordinator_3d.gd")
const STORY_COORDINATOR_SCRIPT := preload(
	"res://game/world/story_interaction_coordinator.gd"
)
const TEST_SAVE_PATH := "user://character_action_state_3d_test.save"

var m_failures := PackedStringArray()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await get_tree().process_frame
	await _test_mode_compatibility_and_arbitration()
	await _test_cancel_recovery_and_cleanup()
	await _test_semantic_mode_boundary()

	if m_failures.is_empty():
		print("PASS: character action state 3D")
	else:
		for failure in m_failures:
			push_error(failure)
		push_error(
			"Character action state 3D failed with %d issue(s)."
			% m_failures.size()
		)

	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0 if m_failures.is_empty() else 1)


func _test_mode_compatibility_and_arbitration() -> void:
	var fixture := await _create_action_fixture(null)
	var actor: HumanBody3D = fixture.actor
	var coordinator = fixture.coordinator
	var world: Node3D = fixture.world

	_assert_true(
		actor.is_free_locomotion()
			and !actor.is_airborne()
			and !actor.is_recovering()
			and !actor.is_on_ladder(),
		"The action fixture starts in free grounded locomotion"
	)

	var farther_priority = _add_target(
		world,
		"FartherPriorityTarget",
		Vector3(1.15, 0.0, 0.0),
		10
	)
	var nearer_lower_priority = _add_target(
		world,
		"NearerLowerPriorityTarget",
		Vector3(0.5, 0.0, 0.55),
		20
	)
	await get_tree().process_frame
	coordinator.refresh_targets()
	coordinator.update_selection()
	_assert_true(
		coordinator.get_selected_target() == farther_priority,
		"Context arbitration ranks authored priority before distance"
	)

	farther_priority.action_enabled = false
	var facing_target = _add_target(
		world,
		"FacingTarget",
		Vector3(1.0, 0.0, 0.0),
		20
	)
	await get_tree().process_frame
	coordinator.refresh_targets()
	coordinator.update_selection()
	_assert_true(
		coordinator.get_selected_target() == facing_target,
		"Equal-priority arbitration ranks facing before distance"
	)

	facing_target.action_enabled = false
	coordinator.update_selection()
	_assert_true(
		coordinator.get_selected_target() == nearer_lower_priority,
		"Disabled physical targets are excluded without stealing context"
	)

	actor.begin_ladder(Transform3D(Basis.IDENTITY, actor.global_position), Vector3.UP)
	coordinator.update_selection()
	_assert_true(
		!nearer_lower_priority.is_action_available(actor),
		"Sustained world actions reject while ladder locomotion is active"
	)
	actor.cancel_ladder(Transform3D(Basis.IDENTITY, Vector3.ZERO))
	_assert_true(
		actor.is_free_locomotion(),
		"Ladder cancellation restores the free locomotion layer"
	)

	var boundary_target = _add_target(
		world,
		"BoundaryTarget",
		actor.position + Vector3(1.5, 0.0, 0.0),
		30,
		false
	)
	boundary_target.interaction_range = 1.5
	boundary_target.facing_tolerance_degrees = 60.0
	boundary_target.set("max_vertical_delta", 1.0)
	_assert_true(
		boundary_target.is_action_available(actor),
		"Physical target accepts the exact 1.50 m contextual range boundary"
	)
	boundary_target.position = actor.position + Vector3(1.51, 0.0, 0.0)
	_assert_true(
		!boundary_target.is_action_available(actor),
		"Physical target rejects 1.51 m contextual range"
	)
	boundary_target.position = actor.position + Vector3(0.5, 1.0, 0.0)
	_assert_true(
		boundary_target.is_action_available(actor),
		"Physical target accepts the exact 1.00 m vertical boundary"
	)
	boundary_target.position = actor.position + Vector3(0.5, 1.01, 0.0)
	_assert_true(
		!boundary_target.is_action_available(actor),
		"Physical target rejects 1.01 m vertical separation"
	)
	boundary_target.position = actor.position + Vector3(
		cos(deg_to_rad(60.0)),
		0.0,
		sin(deg_to_rad(60.0))
	)
	_assert_true(
		boundary_target.is_action_available(actor),
		"Physical target accepts the exact 60 degree facing boundary"
	)
	boundary_target.position = actor.position + Vector3(
		cos(deg_to_rad(61.0)),
		0.0,
		sin(deg_to_rad(61.0))
	)
	_assert_true(
		!boundary_target.is_action_available(actor),
		"Physical target rejects a 61 degree facing error"
	)

	fixture.root.queue_free()
	await get_tree().process_frame


func _test_cancel_recovery_and_cleanup() -> void:
	var fixture := await _create_action_fixture(null)
	var actor: HumanBody3D = fixture.actor
	var coordinator = fixture.coordinator
	var target = _add_target(
		fixture.world,
		"SustainedCareTarget",
		Vector3(0.8, 0.0, 0.0),
		5,
		true
	)
	var finish_reasons: Array[StringName] = []
	target.action_finished.connect(
		func(_finished_actor: Node, reason: StringName) -> void:
			finish_reasons.append(reason)
	)
	await get_tree().process_frame
	coordinator.refresh_targets()
	coordinator.update_selection()
	_assert_true(
		coordinator.request_context_action()
			and coordinator.has_active_action()
			and target.has_reserved_actor(),
		"Context input reserves exactly one sustained action target"
	)
	_assert_true(
		coordinator.cancel_active_action(&"cancel")
			and !coordinator.has_active_action()
			and !target.has_reserved_actor(),
		"Explicit cancel clears the active target before shell back behavior"
	)

	coordinator.update_selection()
	coordinator.request_context_action()
	var recovery_transform := Transform3D(
		Basis.from_euler(Vector3(0.0, 0.4, 0.0)),
		actor.global_position
	)
	coordinator.recover_active_action(recovery_transform)
	await _wait_physics_frames(12)
	_assert_true(
		!coordinator.has_active_action()
			and !target.has_reserved_actor()
			and actor.global_transform.is_equal_approx(recovery_transform),
		"Forced recovery cancels the action and restores the supplied safe transform"
	)

	coordinator.update_selection()
	coordinator.request_context_action()
	_assert_true(
		coordinator.cancel_active_action(&"pause")
			and finish_reasons.has(&"pause"),
		"Pause cleanup settles the sustained action deterministically"
	)
	coordinator.update_selection()
	coordinator.request_context_action()
	_assert_true(
		coordinator.cancel_active_action(&"scene_unload")
			and finish_reasons.has(&"scene_unload")
			and !target.has_reserved_actor(),
		"Scene-unload cleanup releases target ownership deterministically"
	)

	fixture.root.queue_free()
	await get_tree().process_frame


func _test_semantic_mode_boundary() -> void:
	var repository := StorySaveRepository.new(TEST_SAVE_PATH)
	repository.clear()
	var app_state := AppStateService.new(repository)
	add_child(app_state)

	app_state.start_free_walk()
	app_state.apply_story_effects({
		"story_flags": {
			"preservation_tower_perspective": true,
		},
	})
	var free_walk_fixture := await _create_action_fixture(app_state)
	var free_walk_target = _add_target(
		free_walk_fixture.world,
		"FreeWalkSemanticTarget",
		Vector3(0.8, 0.0, 0.0),
		5,
		true,
		&"bagua_stewardship_jump_crossed"
	)
	await get_tree().process_frame
	free_walk_fixture.coordinator.refresh_targets()
	free_walk_fixture.coordinator.update_selection()
	free_walk_fixture.coordinator.request_context_action()
	free_walk_target.complete_action(free_walk_fixture.actor)
	_assert_true(
		!bool(app_state.get_snapshot().story_flags.get(
			"bagua_stewardship_jump_crossed",
			false
		)),
		"Physical completion routed through the coordinator is a Free Walk semantic no-op"
	)
	free_walk_fixture.root.queue_free()
	await get_tree().process_frame

	app_state.start_new_story()
	app_state.apply_story_effects({
		"story_flags": {
			"preservation_tower_perspective": true,
		},
	})
	var story_fixture := await _create_action_fixture(app_state)
	var story_target = _add_target(
		story_fixture.world,
		"StorySemanticTarget",
		Vector3(0.8, 0.0, 0.0),
		5,
		true,
		&"bagua_stewardship_jump_crossed"
	)
	await get_tree().process_frame
	story_fixture.coordinator.refresh_targets()
	story_fixture.coordinator.update_selection()
	story_fixture.coordinator.request_context_action()
	story_target.complete_action(story_fixture.actor)
	_assert_true(
		bool(app_state.get_snapshot().story_flags.get(
			"bagua_stewardship_jump_crossed",
			false
		)),
		"The same coordinator completion publishes once in eligible Story mode"
	)

	story_fixture.root.queue_free()
	await get_tree().process_frame
	app_state.queue_free()
	repository.clear()


func _create_action_fixture(app_state) -> Dictionary:
	var root := Node3D.new()
	root.name = "ActionFixture"
	add_child(root)
	var resolved_app_state = app_state
	if resolved_app_state == null:
		resolved_app_state = AppStateService.new(
			StorySaveRepository.new(TEST_SAVE_PATH)
		)
		resolved_app_state.name = "FixtureAppState"
		root.add_child(resolved_app_state)
		resolved_app_state.start_new_story()
	var world := Node3D.new()
	world.name = "WorldRoot"
	root.add_child(world)
	_add_static_floor(world)
	var actor := HUMAN_BODY_SCENE.instantiate() as HumanBody3D
	actor.name = "Actor"
	actor.character_model_scene = null
	actor.draw_skeleton_bones = false
	world.add_child(actor)
	actor.global_position = Vector3(0.0, 0.04, 0.0)
	actor.set_direction_vector(Vector3.RIGHT)
	await _settle_actor(actor)
	var story_coordinator = STORY_COORDINATOR_SCRIPT.new()
	story_coordinator.name = "StoryInteractionCoordinator"
	root.add_child(story_coordinator)
	story_coordinator.configure(world, actor, resolved_app_state)
	var coordinator = WORLD_COORDINATOR_SCRIPT.new()
	coordinator.name = "WorldActionCoordinator3D"
	root.add_child(coordinator)
	coordinator.configure(
		world,
		actor,
		resolved_app_state,
		story_coordinator
	)
	coordinator.semantic_completion_requested.connect(
		func(event_id: StringName, context: Dictionary) -> void:
			resolved_app_state.notify_story_world_event(
				String(event_id),
				context
			)
	)
	await get_tree().process_frame
	return {
		"root": root,
		"world": world,
		"actor": actor,
		"coordinator": coordinator,
		"story_coordinator": story_coordinator,
		"app_state": resolved_app_state,
	}


func _add_target(
	world: Node3D,
	target_name: String,
	position: Vector3,
	priority: int,
	sustained: bool = true,
	semantic_id: StringName = &""
):
	var target = ACTION_TARGET_SCRIPT.new()
	target.name = target_name
	target.position = position
	target.action_id = StringName(target_name.to_snake_case())
	target.action_label = target_name
	target.action_priority = priority
	target.interaction_range = 1.5
	target.facing_tolerance_degrees = 60.0
	target.sustained_action = sustained
	target.semantic_completion_id = semantic_id
	world.add_child(target)
	return target


func _add_static_floor(parent: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "Floor"
	body.position = Vector3(0.0, -0.05, 0.0)
	var collision_shape := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(6.0, 0.1, 6.0)
	collision_shape.shape = shape
	body.add_child(collision_shape)
	parent.add_child(body)


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
