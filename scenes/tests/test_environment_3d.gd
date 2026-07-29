@tool
extends Node3D

const BaseController3DScript = preload(
	"res://characters/control/base_controller_3d.gd"
)
const AppStateScript = preload("res://game/app_state.gd")
const StorySaveRepositoryScript = preload(
	"res://game/app_state/story_save_repository.gd"
)
const StoryInteractionCoordinatorScript = preload(
	"res://game/world/story_interaction_coordinator.gd"
)
const WorldActionCoordinatorScript = preload(
	"res://game/world/world_action_coordinator_3d.gd"
)

const ACTION_TEST_SAVE_PATH := "user://test_environment_3d_actions.save"
const MINIMUM_BUILDING_CLEARANCE := 3.0
const MINIMUM_FIXTURE_CLEARANCE := 2.0
const GROUND_SURFACE_Y := 0.0
const INSTRUCTION_TEXT := (
	"Environment Test • Milestone C fixtures are south of the tower: "
	+ "carry left, sit center, push/pull right\n"
	+ "WASD / arrows move • Shift walks • Space jumps • R interacts • "
	+ "Right-drag rotates • Mouse wheel zooms\n"
	+ "Esc cancels an active action; press Esc again to exit"
)

@export var building_scene: PackedScene = preload(
	"res://architecture/bagua_tower/bagua_tower_stylized_3d.tscn"
):
	set(value):
		building_scene = value
		_queue_building_refresh()

@export var building_transform := Transform3D.IDENTITY:
	set(value):
		building_transform = value
		_queue_building_refresh()

@export var player_spawn := Vector3(0.0, 0.08, -7.0):
	set(value):
		player_spawn = value
		if is_instance_valid(m_player):
			m_player.global_position = player_spawn

@onready var m_building_container: Node3D = $BuildingContainer
@onready var m_player: CharacterBody3D = $Player
@onready var m_camera: Camera3D = $Camera3D
@onready var m_camera_controller: Node = $Camera3DController
@onready var m_action_fixtures: Node3D = $MilestoneCActionFixtures
@onready var m_instructions_label: Label = $Instructions/Panel/Label

var m_building_instance: Node3D = null
var m_building_refresh_queued := false
var m_test_repository: StorySaveRepository = null
var m_app_state: AppStateService = null
var m_story_coordinator: StoryInteractionCoordinator = null
var m_action_coordinator: WorldActionCoordinator3D = null


func _ready() -> void:
	_rebuild_building()
	m_player.global_position = player_spawn
	m_camera.current = true
	if Engine.is_editor_hint():
		return
	# Run after Camera3DController so the test keeps its orbit/zoom behavior but
	# does not move the entire frame vertically when the player jumps.
	process_priority = 1
	call_deferred("_initialize_runtime_fixture")


func _process(_delta: float) -> void:
	_lock_camera_vertical_follow()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if (
			is_instance_valid(m_action_coordinator)
			and m_action_coordinator.has_active_action()
		):
			# PlayerController3D forwards this same input on the next physics
			# tick, where seat exit-clearance queries can safely access space.
			get_viewport().set_input_as_handled()
			return
		get_tree().quit()
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	if is_instance_valid(m_action_coordinator):
		m_action_coordinator.cancel_active_action(&"scene_unload")
	if m_test_repository != null:
		m_test_repository.clear()


func _initialize_runtime_fixture() -> void:
	m_test_repository = StorySaveRepositoryScript.new(ACTION_TEST_SAVE_PATH)
	m_test_repository.clear()
	m_app_state = AppStateScript.new(m_test_repository)
	m_app_state.name = "FixtureAppState"
	add_child(m_app_state)
	m_app_state.start_free_walk()

	m_story_coordinator = StoryInteractionCoordinatorScript.new()
	m_story_coordinator.name = "StoryInteractionCoordinator"
	add_child(m_story_coordinator)
	m_story_coordinator.configure(self, m_player, m_app_state)

	m_action_coordinator = WorldActionCoordinatorScript.new()
	m_action_coordinator.name = "WorldActionCoordinator3D"
	add_child(m_action_coordinator)
	m_action_coordinator.configure(
		self,
		m_player,
		m_app_state,
		m_story_coordinator
	)
	m_action_coordinator.semantic_completion_requested.connect(
		_on_semantic_completion_requested
	)
	m_app_state.state_committed.connect(_on_fixture_state_committed)
	_refresh_instruction_hint()
	m_camera_controller.call_deferred("snap_to_target")
	# Exercise automatic contextual selection for multiple physics ticks before
	# checking the harness so physics-space timing regressions surface in its log.
	await get_tree().physics_frame
	await get_tree().physics_frame
	_run_smoke_check()


func _on_semantic_completion_requested(
	event_id: StringName,
	context: Dictionary
) -> void:
	m_app_state.notify_story_world_event(String(event_id), context)


func _on_fixture_state_committed(_changes: AppStateChangeSet) -> void:
	_refresh_instruction_hint()


func _refresh_instruction_hint() -> void:
	if !is_instance_valid(m_instructions_label):
		return
	var hint := ""
	if is_instance_valid(m_app_state):
		hint = m_app_state.get_projection().hint.strip_edges()
	m_instructions_label.text = (
		INSTRUCTION_TEXT if hint.is_empty() else "%s\n%s" % [INSTRUCTION_TEXT, hint]
	)


func _queue_building_refresh() -> void:
	if !is_inside_tree() or m_building_refresh_queued:
		return
	m_building_refresh_queued = true
	call_deferred("_rebuild_building")


func _rebuild_building() -> void:
	m_building_refresh_queued = false
	if !is_instance_valid(m_building_container):
		return
	for child in m_building_container.get_children():
		m_building_container.remove_child(child)
		child.queue_free()
	m_building_instance = null
	if building_scene == null:
		return
	var instance := building_scene.instantiate() as Node3D
	if instance == null:
		push_error("Environment fixture root must inherit Node3D.")
		return
	instance.name = "BuildingUnderTest"
	instance.transform = building_transform
	m_building_container.add_child(instance)
	m_building_instance = instance


func _lock_camera_vertical_follow() -> void:
	if Engine.is_editor_hint():
		return
	if (
		!is_instance_valid(m_player)
		or !is_instance_valid(m_camera)
		or !is_instance_valid(m_camera_controller)
	):
		return
	var follow_offset: Vector3 = m_camera_controller.get("follow_offset")
	var look_at_offset: Vector3 = m_camera_controller.get("look_at_offset")
	var camera_position := m_camera.global_position
	camera_position.y = player_spawn.y + follow_offset.y
	m_camera.global_position = camera_position
	var look_at_position := m_player.global_position
	look_at_position.y = player_spawn.y
	m_camera.look_at(look_at_position + look_at_offset, Vector3.UP)


func _run_smoke_check() -> void:
	var failures: Array[String] = []
	if !is_instance_valid(m_building_instance):
		failures.append("missing building under test")
	if !is_instance_valid(m_player):
		failures.append("missing HumanBody3D player")
	elif !(m_player.get("controller") is BaseController3DScript):
		failures.append("player is missing PlayerController3D")
	if !is_instance_valid(m_camera) or !m_camera.current:
		failures.append("environment test camera is not active")
	if $Ground/StaticBody3D/CollisionShape3D.shape == null:
		failures.append("environment test ground is missing collision")
	_check_milestone_c_action_fixtures(failures)

	if failures.is_empty():
		print(
			"PASS: Environment test scene (%s)"
			% building_scene.resource_path
		)
		if DisplayServer.get_name() == "headless":
			get_tree().quit(0)
		return
	for failure in failures:
		push_error(failure)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1)


func _check_milestone_c_action_fixtures(failures: Array[String]) -> void:
	if !is_instance_valid(m_action_fixtures):
		failures.append("environment test is missing Milestone C action fixtures")
		return
	if (
		!is_instance_valid(m_app_state)
		or !is_instance_valid(m_story_coordinator)
		or !is_instance_valid(m_action_coordinator)
		or !m_action_coordinator.is_configured()
	):
		failures.append("environment test did not configure contextual action input")
		return
	if (
		m_action_coordinator.is_processing()
		or !m_action_coordinator.is_physics_processing()
	):
		failures.append(
			"environment contextual action selection is not physics-tick driven"
		)

	var targets: Array[Node] = [
		m_action_fixtures.get_node_or_null("CarryFixture/MusicCase"),
		m_action_fixtures.get_node_or_null("SitFixture/Seat"),
		m_action_fixtures.get_node_or_null("PushPullFixture"),
	]
	var expected_semantic_ids := [
		"piano_ferry_music_case_shelved",
		"harbor_sea_melody_listened",
		"trinity_hymn_chest_aligned",
	]
	var configured_targets := m_action_coordinator.get_targets()
	for target_index in targets.size():
		var target := targets[target_index]
		if target == null:
			failures.append(
				"environment test is missing Milestone C action target %d"
				% target_index
			)
			continue
		if !configured_targets.has(target):
			failures.append(
				"environment test action target %s is not registered"
				% target.name
			)
		if String(target.get("semantic_completion_id")) != (
			expected_semantic_ids[target_index]
		):
			failures.append(
				"environment test action target %s has the wrong semantic id"
				% target.name
			)

	var building_bounds := _collect_visible_bounds(m_building_instance)
	if building_bounds.size == Vector3.ZERO:
		failures.append("building under test has no visible bounds")
		return
	var fixture_nodes: Array[Node3D] = [
		m_action_fixtures.get_node_or_null("CarryFixture") as Node3D,
		m_action_fixtures.get_node_or_null("SitFixture") as Node3D,
		m_action_fixtures.get_node_or_null("PushPullFixture") as Node3D,
	]
	var fixture_bounds: Array[AABB] = []
	for fixture in fixture_nodes:
		if fixture == null:
			continue
		var bounds := _collect_visible_bounds(fixture)
		fixture_bounds.append(bounds)
		if bounds.position.y < GROUND_SURFACE_Y - 0.001:
			failures.append(
				"environment action fixture %s extends below the ground"
				% fixture.name
			)
		var building_clearance := _flat_bounds_clearance(
			building_bounds,
			bounds
		)
		if building_clearance < MINIMUM_BUILDING_CLEARANCE:
			failures.append(
				(
					"environment action fixture %s is only %.2f m from "
					+ "the building"
				) % [fixture.name, building_clearance]
			)
	for first_index in fixture_bounds.size():
		for second_index in range(first_index + 1, fixture_bounds.size()):
			var fixture_clearance := _flat_bounds_clearance(
				fixture_bounds[first_index],
				fixture_bounds[second_index]
			)
			if fixture_clearance < MINIMUM_FIXTURE_CLEARANCE:
				failures.append(
					(
						"environment action fixtures %d and %d are only "
						+ "%.2f m apart"
					) % [first_index, second_index, fixture_clearance]
				)

	var carry_lane := m_action_fixtures.get_node_or_null(
		"CarryFixture/CarryLane/MeshInstance3D"
	) as VisualInstance3D
	if carry_lane == null:
		failures.append("environment carry fixture is missing its visible lane")
	else:
		var lane_bounds := carry_lane.global_transform * carry_lane.get_aabb()
		if lane_bounds.end.y <= GROUND_SURFACE_Y + 0.01:
			failures.append("environment carry lane is hidden by the ground")


func _collect_visible_bounds(root_node: Node) -> AABB:
	if root_node == null:
		return AABB()
	var result := AABB()
	var has_bounds := false
	var candidates: Array[Node] = [root_node]
	candidates.append_array(root_node.find_children("*", "VisualInstance3D", true, false))
	for candidate in candidates:
		var visual := candidate as VisualInstance3D
		if visual == null or !visual.is_visible_in_tree():
			continue
		var local_bounds := visual.get_aabb()
		if local_bounds.size == Vector3.ZERO:
			continue
		var world_bounds := visual.global_transform * local_bounds
		if has_bounds:
			result = result.merge(world_bounds)
		else:
			result = world_bounds
			has_bounds = true
	return result


func _flat_bounds_clearance(first: AABB, second: AABB) -> float:
	var x_gap := maxf(
		maxf(first.position.x - second.end.x, second.position.x - first.end.x),
		0.0
	)
	var z_gap := maxf(
		maxf(first.position.z - second.end.z, second.position.z - first.end.z),
		0.0
	)
	return Vector2(x_gap, z_gap).length()
