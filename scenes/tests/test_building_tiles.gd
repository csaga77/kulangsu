@tool
extends Node3D

const HUMAN_BODY_3D_SCENE := preload("res://characters/human_body_3d.tscn")
const REQUIRED_COLLISION_ITEMS := [
	"Primitive_Floor",
	"Primitive_Stairs",
	"Primitive_Wall",
]
const PLAYER_START := Vector3(0.0, 1.0, -11.0)
const PROBE_START := Vector3(1.5, 1.0, -10.0)
const PROBE_DIRECTION := Vector3.RIGHT
const PROBE_SPEED := 4.0
const PROBE_FRAMES := 90
const PROBE_GROUNDING_VELOCITY := -0.5
const MAX_BLOCKED_TRAVEL := 3.0
const MAX_VERTICAL_DRIFT := 0.15
const MAX_WALL_NORMAL_Y := 0.75
const STAIR_PROBE_START := Vector3(0.0, 1.0, -13.5)
const STAIR_PROBE_SPEEDS: Array[float] = [2.4, 4.0, 7.5]
const STAIR_UP_FRAMES := 70
const STAIR_DOWN_FRAMES := 75
const STAIR_SETTLE_FRAMES := 8
const MIN_STAIR_CLIMB_HEIGHT := 2.0
const MIN_STAIR_HORIZONTAL_TRAVEL := 2.0
const MAX_STAIR_RETURN_HEIGHT := 0.35
const STAIR_PROBE_GROUNDING_VELOCITY := -2.0
const MIN_STAIR_DOWN_FLOOR_FRAMES := 50
const MAX_STAIR_DOWN_UNGROUNDED_RUN := 8
const MAX_STAIR_DESCENT_DIP := 0.25
const MAX_STAIR_FRAME_DROP := 0.8

@onready var m_grid: GridMap = $GridMap
@onready var m_player: HumanBody3D = $human_body_3d
@onready var m_camera: Camera3D = $Camera3D
@onready var m_camera_controller: Node = $Camera3DController


func _ready() -> void:
	_reset_player()
	if is_instance_valid(m_camera):
		m_camera.current = true

	if Engine.is_editor_hint():
		return

	if is_instance_valid(m_camera_controller) and m_camera_controller.has_method("snap_to_target"):
		m_camera_controller.call_deferred("snap_to_target")

	call_deferred("_run_smoke_checks")


func _run_smoke_checks() -> void:
	var failures: Array[String] = []
	_validate_scene_nodes(failures)
	_validate_mesh_library_collision(failures)
	await _validate_character_building_collision(failures)
	await _validate_character_stair_navigation(failures)

	_reset_player()
	if failures.is_empty():
		print("PASS: Building tile character collision smoke test")
	else:
		for failure in failures:
			push_error(failure)


func _reset_player() -> void:
	if !is_instance_valid(m_player):
		return
	m_player.global_position = PLAYER_START
	m_player.velocity = Vector3.ZERO
	m_player.set_direction_vector(Vector3.FORWARD)
	m_player.is_walking = false
	m_player.is_running = false


func _validate_scene_nodes(failures: Array[String]) -> void:
	if !is_instance_valid(m_grid):
		failures.append("missing GridMap")
	if !is_instance_valid(m_player):
		failures.append("missing HumanBody3D player")
	if !is_instance_valid(m_camera):
		failures.append("missing Camera3D")
	if !is_instance_valid(m_camera_controller):
		failures.append("missing Camera3DController")
	elif m_camera_controller.get("target_node") != m_player:
		failures.append("Camera3DController is not following HumanBody3D")


func _validate_mesh_library_collision(failures: Array[String]) -> void:
	if !is_instance_valid(m_grid):
		return

	var library := m_grid.mesh_library
	if library == null:
		failures.append("GridMap is missing a MeshLibrary")
		return

	for item_name in REQUIRED_COLLISION_ITEMS:
		var item_id := library.find_item_by_name(item_name)
		if item_id < 0:
			failures.append("MeshLibrary is missing %s" % item_name)
			continue
		if library.get_item_shapes(item_id).is_empty():
			failures.append("%s has no MeshLibrary collision shapes" % item_name)


func _validate_character_building_collision(failures: Array[String]) -> void:
	if !is_instance_valid(m_grid):
		return

	var probe := HUMAN_BODY_3D_SCENE.instantiate() as HumanBody3D
	if probe == null:
		failures.append("failed to instantiate HumanBody3D probe")
		return

	probe.name = "CharacterCollisionProbe"
	probe.visible = false
	probe.body_radius = 0.28
	probe.body_height = 1.72
	add_child(probe)

	await get_tree().physics_frame
	probe.global_position = PROBE_START
	probe.velocity = Vector3.ZERO
	for i in range(8):
		probe.velocity.y = PROBE_GROUNDING_VELOCITY
		probe.move_with_speed(Vector3.ZERO, 0.0)
		await get_tree().physics_frame

	var start_position := probe.global_position
	var started_on_floor := probe.is_on_floor()
	var saw_wall_collision := false
	for i in range(PROBE_FRAMES):
		probe.velocity.y = PROBE_GROUNDING_VELOCITY
		probe.move_with_speed(PROBE_DIRECTION, PROBE_SPEED)
		for collision_index in range(probe.get_slide_collision_count()):
			var collision := probe.get_slide_collision(collision_index)
			if absf(collision.get_normal().y) <= MAX_WALL_NORMAL_Y:
				saw_wall_collision = true
		await get_tree().physics_frame

	var probe_travel := start_position.distance_to(probe.global_position)
	if probe_travel > MAX_BLOCKED_TRAVEL:
		failures.append(
			"HumanBody3D probe moved %.2f units instead of stopping at the building wall" % probe_travel
		)
	if !started_on_floor:
		failures.append("HumanBody3D probe did not collide with the GridMap floor")
	if absf(probe.global_position.y - start_position.y) > MAX_VERTICAL_DRIFT:
		failures.append("HumanBody3D probe drifted vertically while testing the wall")
	if !saw_wall_collision:
		failures.append("HumanBody3D probe did not report a slide collision against the building")

	probe.queue_free()


func _validate_character_stair_navigation(failures: Array[String]) -> void:
	if !is_instance_valid(m_grid):
		return

	for stair_probe_speed in STAIR_PROBE_SPEEDS:
		await _validate_character_stair_navigation_at_speed(failures, stair_probe_speed)


func _validate_character_stair_navigation_at_speed(
	failures: Array[String],
	stair_probe_speed: float
) -> void:
	var probe := HUMAN_BODY_3D_SCENE.instantiate() as HumanBody3D
	if probe == null:
		_append_stair_failure(failures, stair_probe_speed, "failed to instantiate")
		return

	probe.name = "CharacterStairProbe%.1f" % stair_probe_speed
	probe.visible = false
	probe.body_radius = 0.28
	probe.body_height = 1.72
	add_child(probe)

	await get_tree().physics_frame
	probe.global_position = STAIR_PROBE_START
	probe.velocity = Vector3.ZERO
	for i in range(8):
		probe.velocity.y = STAIR_PROBE_GROUNDING_VELOCITY
		probe.move_with_speed(Vector3.ZERO, 0.0)
		await get_tree().physics_frame

	var start_position := probe.global_position
	var started_on_floor := probe.is_on_floor()
	var max_up_y := start_position.y
	for i in range(STAIR_UP_FRAMES):
		probe.velocity.y = STAIR_PROBE_GROUNDING_VELOCITY
		probe.move_with_speed(Vector3.FORWARD, stair_probe_speed)
		max_up_y = maxf(max_up_y, probe.global_position.y)
		await get_tree().physics_frame

	var top_position := probe.global_position
	var down_floor_frames := 0
	var longest_ungrounded_run := 0
	var ungrounded_run := 0
	var min_down_y := top_position.y
	var max_down_frame_drop := 0.0
	for i in range(STAIR_DOWN_FRAMES):
		var before_y := probe.global_position.y
		probe.velocity.y = STAIR_PROBE_GROUNDING_VELOCITY
		probe.move_with_speed(Vector3.BACK, stair_probe_speed)
		min_down_y = minf(min_down_y, probe.global_position.y)
		max_down_frame_drop = maxf(max_down_frame_drop, before_y - probe.global_position.y)
		if probe.is_on_floor():
			down_floor_frames += 1
			ungrounded_run = 0
		else:
			ungrounded_run += 1
			longest_ungrounded_run = maxi(longest_ungrounded_run, ungrounded_run)
		await get_tree().physics_frame

	for i in range(STAIR_SETTLE_FRAMES):
		probe.velocity.y = STAIR_PROBE_GROUNDING_VELOCITY
		probe.move_with_speed(Vector3.ZERO, 0.0)
		await get_tree().physics_frame

	var final_position := probe.global_position
	if !started_on_floor:
		_append_stair_failure(failures, stair_probe_speed, "did not start on the lower landing")
	if max_up_y - start_position.y < MIN_STAIR_CLIMB_HEIGHT:
		_append_stair_failure(
			failures,
			stair_probe_speed,
			"only climbed %.2f units" % (max_up_y - start_position.y)
		)
	if start_position.z - top_position.z < MIN_STAIR_HORIZONTAL_TRAVEL:
		_append_stair_failure(failures, stair_probe_speed, "did not advance up the stairs")
	if top_position.y - final_position.y < MIN_STAIR_CLIMB_HEIGHT:
		_append_stair_failure(
			failures,
			stair_probe_speed,
			"did not descend after climbing the stairs"
		)
	if absf(final_position.y - start_position.y) > MAX_STAIR_RETURN_HEIGHT:
		_append_stair_failure(
			failures,
			stair_probe_speed,
			"did not return to the lower landing height"
		)
	if down_floor_frames < MIN_STAIR_DOWN_FLOOR_FRAMES:
		_append_stair_failure(
			failures,
			stair_probe_speed,
			"was grounded for only %d down-stair frames" % down_floor_frames
		)
	if longest_ungrounded_run > MAX_STAIR_DOWN_UNGROUNDED_RUN:
		_append_stair_failure(
			failures,
			stair_probe_speed,
			"lost stair support for %d consecutive frames" % longest_ungrounded_run
		)
	if start_position.y - min_down_y > MAX_STAIR_DESCENT_DIP:
		_append_stair_failure(
			failures,
			stair_probe_speed,
			"dipped below the lower landing while descending"
		)
	if max_down_frame_drop > MAX_STAIR_FRAME_DROP:
		_append_stair_failure(
			failures,
			stair_probe_speed,
			"dropped %.2f units in one down-stair frame" % max_down_frame_drop
		)
	if !probe.is_on_floor():
		_append_stair_failure(failures, stair_probe_speed, "did not settle on the lower landing")

	probe.queue_free()


func _append_stair_failure(failures: Array[String], stair_probe_speed: float, message: String) -> void:
	failures.append("HumanBody3D stair probe at %.1f speed %s" % [stair_probe_speed, message])
