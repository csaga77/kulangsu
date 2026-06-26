@tool
extends Node3D

const HUMAN_BODY_3D_SCENE := preload("res://characters/human_body_3d.tscn")
const REQUIRED_COLLISION_ITEMS := [
	"Primitive_Floor",
	"Primitive_Stairs",
	"Primitive_Wall",
]
# Spawn just above the Floor3D surface (y=0) so the body settles onto it on the
# first physics frame instead of dropping in from height.
const PLAYER_START := Vector3(0.0, 0.1, -11.0)
const PROBE_START := Vector3(5.25, 0.1, -10.0)
const PROBE_DIRECTION := Vector3.RIGHT
const PROBE_SPEED := 4.0
const PROBE_FRAMES := 90
const PROBE_GROUNDING_VELOCITY := -0.5
const MAX_BLOCKED_TRAVEL := 1.85
const MAX_VERTICAL_DRIFT := 0.15
const MAX_WALL_NORMAL_Y := 0.75
const STAIR_PROBE_START := Vector3(5.5, 0.1, 1.0)
const STAIR_RISER_TOUCH_START := Vector3(5.5, 0.1, 1.72)
const STAIR_UP_DIRECTION := Vector3.BACK
const STAIR_DOWN_DIRECTION := Vector3.FORWARD
const STAIR_PROBE_SPEEDS: Array[float] = [2.4, 4.0, 7.5]
const STAIR_ASCEND_TARGET_PROGRESS := 6.6
const STAIR_TRAVERSAL_FRAME_MARGIN := 20
const STAIR_MAX_TRAVERSAL_FRAMES := 220
const STAIR_RISER_TOUCH_FRAMES := 50
const STAIR_SETTLE_FRAMES := 8
const MIN_STAIR_CLIMB_HEIGHT := 2.0
const MIN_STAIR_HORIZONTAL_TRAVEL := 2.0
const MIN_STAIR_RISER_TOUCH_CLIMB_HEIGHT := 0.35
const MIN_STAIR_RISER_TOUCH_TRAVEL := 0.8
const MAX_STAIR_RETURN_HEIGHT := 0.35
const STAIR_PROBE_GROUNDING_VELOCITY := -2.0
const MAX_STAIR_UP_FRAME_DROP := 0.20
const MIN_STAIR_DOWN_GROUNDED_RATIO := 0.65
const MAX_STAIR_DOWN_UNGROUNDED_RUN := 8
const MAX_STAIR_DESCENT_DIP := 0.25
const MAX_STAIR_FRAME_DROP := 0.8
const STAIR_REVERSAL_CYCLES := 8
const STAIR_REVERSAL_SIDE_BIAS := 0.18
const MIN_STAIR_REVERSAL_CLIMB_HEIGHT := 1.8
const STAIR_JUMP_CYCLES := 4
const STAIR_JUMP_FRAMES := 40
const MAX_STAIR_JUMP_FLOOR_GAP := 0.12
const MAX_STAIR_JUMP_FRAME_DROP := 0.25
const RIGID_PUSH_TEST_ORIGIN := Vector3(-24.0, 0.0, -8.0)
const RIGID_PUSH_BALL_RADIUS := 0.4
const RIGID_PUSH_BALL_MASS := 0.2
const RIGID_PUSH_PROBE_START := Vector3(-1.45, 0.1, 0.0)
const RIGID_PUSH_PROBE_SPEED := 4.0
const RIGID_PUSH_FRAMES := 50
const MIN_RIGID_PUSH_TRAVEL := 0.45
const FLOOR_SAMPLE_MISSING := -INF

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
	await _validate_character_building_collision(failures)
	await _validate_character_pushes_rigid_body(failures)
	await _validate_character_stair_navigation(failures)
	await _validate_character_climbs_from_riser_contact(failures)
	await _validate_character_stair_reversal_stability(failures)
	await _validate_character_stair_jump_stability(failures)

	_reset_player()
	if failures.is_empty():
		print("PASS: Building tile character collision smoke test")
	else:
		for failure in failures:
			push_error(failure)

	get_tree().quit(0 if failures.is_empty() else 1)


func _reset_player() -> void:
	if !is_instance_valid(m_player):
		return
	m_player.global_position = PLAYER_START
	m_player.velocity = Vector3.ZERO
	m_player.set_direction_vector(Vector3.FORWARD)
	m_player.is_walking = false
	m_player.is_running = false


func _validate_scene_nodes(failures: Array[String]) -> void:
	if !is_instance_valid(m_player):
		failures.append("missing HumanBody3D player")
	if !is_instance_valid(m_camera):
		failures.append("missing Camera3D")
	if !is_instance_valid(m_camera_controller):
		failures.append("missing Camera3DController")
	elif m_camera_controller.get("target_node") != m_player:
		failures.append("Camera3DController is not following HumanBody3D")


func _validate_character_building_collision(failures: Array[String]) -> void:

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
	var started_on_floor := _is_probe_grounded(probe)
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
	if absf(probe.global_position.y - start_position.y) > MAX_VERTICAL_DRIFT:
		failures.append("HumanBody3D probe drifted vertically while testing the wall")
	if !saw_wall_collision:
		failures.append("HumanBody3D probe did not report a slide collision against the building")

	probe.queue_free()


func _validate_character_pushes_rigid_body(failures: Array[String]) -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "RigidPushProbeFloor"
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(7.0, 0.1, 4.0)
	floor_shape.shape = floor_box
	floor_shape.position = RIGID_PUSH_TEST_ORIGIN + Vector3(0.0, -0.05, 0.0)
	floor_body.add_child(floor_shape)
	add_child(floor_body)

	var ball := RigidBody3D.new()
	ball.name = "RigidPushProbeBall"
	ball.mass = RIGID_PUSH_BALL_MASS
	ball.gravity_scale = 0.0
	ball.can_sleep = false
	ball.position = RIGID_PUSH_TEST_ORIGIN + Vector3(0.0, RIGID_PUSH_BALL_RADIUS, 0.0)
	var ball_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = RIGID_PUSH_BALL_RADIUS
	ball_shape.shape = sphere
	ball.add_child(ball_shape)
	add_child(ball)

	var probe := HUMAN_BODY_3D_SCENE.instantiate() as HumanBody3D
	if probe == null:
		failures.append("failed to instantiate HumanBody3D rigid push probe")
		floor_body.queue_free()
		ball.queue_free()
		return

	probe.name = "CharacterRigidPushProbe"
	probe.visible = false
	probe.body_radius = 0.28
	probe.body_height = 1.72
	add_child(probe)

	await get_tree().physics_frame
	probe.global_position = RIGID_PUSH_TEST_ORIGIN + RIGID_PUSH_PROBE_START
	probe.velocity = Vector3.ZERO
	for i in range(8):
		probe.velocity.y = PROBE_GROUNDING_VELOCITY
		probe.move_with_speed(Vector3.ZERO, 0.0)
		await get_tree().physics_frame

	var ball_start_x := ball.global_position.x
	var saw_ball_collision := false
	for i in range(RIGID_PUSH_FRAMES):
		probe.velocity.y = PROBE_GROUNDING_VELOCITY
		probe.move_with_speed(Vector3.RIGHT, RIGID_PUSH_PROBE_SPEED)
		for collision_index in range(probe.get_slide_collision_count()):
			var collision := probe.get_slide_collision(collision_index)
			if collision != null and collision.get_collider() == ball:
				saw_ball_collision = true
		await get_tree().physics_frame

	var ball_travel := ball.global_position.x - ball_start_x
	if !saw_ball_collision:
		failures.append("HumanBody3D rigid push probe did not collide with the ball")
	if ball_travel < MIN_RIGID_PUSH_TRAVEL:
		failures.append("HumanBody3D pushed a RigidBody3D ball only %.2f units" % ball_travel)

	probe.queue_free()
	ball.queue_free()
	floor_body.queue_free()


func _validate_character_stair_navigation(failures: Array[String]) -> void:

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
	var started_on_floor := _is_probe_grounded(probe)
	var max_up_y := start_position.y
	var max_up_frame_drop := 0.0
	var up_frame_count := 0
	var up_max_frames := _stair_frames_for_travel(STAIR_ASCEND_TARGET_PROGRESS, stair_probe_speed)
	for i in range(up_max_frames):
		var before_y := probe.global_position.y
		probe.velocity.y = STAIR_PROBE_GROUNDING_VELOCITY
		probe.move_with_speed(STAIR_UP_DIRECTION, stair_probe_speed)
		up_frame_count += 1
		max_up_frame_drop = maxf(max_up_frame_drop, before_y - probe.global_position.y)
		max_up_y = maxf(max_up_y, probe.global_position.y)
		var current_progress := (probe.global_position - start_position).dot(STAIR_UP_DIRECTION)
		var reached_top := (
			current_progress >= STAIR_ASCEND_TARGET_PROGRESS
			and max_up_y - start_position.y >= MIN_STAIR_CLIMB_HEIGHT
		)
		await get_tree().physics_frame
		if reached_top:
			break

	var top_position := probe.global_position
	var down_floor_frames := 0
	var longest_ungrounded_run := 0
	var ungrounded_run := 0
	var min_down_y := top_position.y
	var max_down_frame_drop := 0.0
	var stair_progress := (top_position - start_position).dot(STAIR_UP_DIRECTION)
	var down_frame_count := 0
	var down_max_frames := _stair_frames_for_travel(maxf(stair_progress, MIN_STAIR_HORIZONTAL_TRAVEL), stair_probe_speed)
	for i in range(down_max_frames):
		var before_y := probe.global_position.y
		probe.velocity.y = STAIR_PROBE_GROUNDING_VELOCITY
		probe.move_with_speed(STAIR_DOWN_DIRECTION, stair_probe_speed)
		down_frame_count += 1
		min_down_y = minf(min_down_y, probe.global_position.y)
		max_down_frame_drop = maxf(max_down_frame_drop, before_y - probe.global_position.y)
		if _is_probe_grounded(probe):
			down_floor_frames += 1
			ungrounded_run = 0
		else:
			ungrounded_run += 1
			longest_ungrounded_run = maxi(longest_ungrounded_run, ungrounded_run)
		var return_progress := (top_position - probe.global_position).dot(STAIR_UP_DIRECTION)
		var returned_to_landing := (
			return_progress >= stair_progress - probe.body_radius
			and probe.global_position.y <= start_position.y + MAX_STAIR_RETURN_HEIGHT
		)
		await get_tree().physics_frame
		if returned_to_landing:
			break

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
	if stair_progress < MIN_STAIR_HORIZONTAL_TRAVEL:
		_append_stair_failure(failures, stair_probe_speed, "did not advance up the stairs")
	if max_up_frame_drop > MAX_STAIR_UP_FRAME_DROP:
		_append_stair_failure(
			failures,
			stair_probe_speed,
			"snapped down %.2f units in one up-stair frame" % max_up_frame_drop
		)
	if top_position.y - final_position.y < MIN_STAIR_CLIMB_HEIGHT:
		_append_stair_failure(
			failures,
			stair_probe_speed,
			"did not descend after climbing the stairs (top %s, final %s, up frames %d, down frames %d)"
				% [top_position, final_position, up_frame_count, down_frame_count]
		)
	if absf(final_position.y - start_position.y) > MAX_STAIR_RETURN_HEIGHT:
		_append_stair_failure(
			failures,
			stair_probe_speed,
			"did not return to the lower landing height"
		)
	var min_down_floor_frames := floori(float(down_frame_count) * MIN_STAIR_DOWN_GROUNDED_RATIO)
	if down_floor_frames < min_down_floor_frames:
		_append_stair_failure(
			failures,
			stair_probe_speed,
			"was grounded for only %d of %d down-stair frames" % [down_floor_frames, down_frame_count]
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
	if !_is_probe_grounded(probe):
		_append_stair_failure(failures, stair_probe_speed, "did not settle on the lower landing")

	probe.queue_free()


func _validate_character_climbs_from_riser_contact(failures: Array[String]) -> void:
	var probe := HUMAN_BODY_3D_SCENE.instantiate() as HumanBody3D
	if probe == null:
		failures.append("HumanBody3D stair riser-contact probe failed to instantiate")
		return

	probe.name = "CharacterStairRiserContactProbe"
	probe.visible = false
	probe.body_radius = 0.28
	probe.body_height = 1.72
	add_child(probe)

	await get_tree().physics_frame
	probe.global_position = STAIR_RISER_TOUCH_START
	probe.velocity = Vector3.ZERO
	for i in range(STAIR_SETTLE_FRAMES):
		probe.velocity.y = STAIR_PROBE_GROUNDING_VELOCITY
		probe.move_with_speed(Vector3.ZERO, 0.0)
		await get_tree().physics_frame

	var start_position := probe.global_position
	var max_y := start_position.y
	for i in range(STAIR_RISER_TOUCH_FRAMES):
		probe.velocity.y = STAIR_PROBE_GROUNDING_VELOCITY
		probe.move_with_speed(STAIR_UP_DIRECTION, PROBE_SPEED)
		max_y = maxf(max_y, probe.global_position.y)
		await get_tree().physics_frame

	var stair_travel := (probe.global_position - start_position).dot(STAIR_UP_DIRECTION)
	var stair_climb := max_y - start_position.y
	if stair_travel < MIN_STAIR_RISER_TOUCH_TRAVEL:
		failures.append(
			"HumanBody3D stair riser-contact probe advanced only %.2f units" % stair_travel
		)
	if stair_climb < MIN_STAIR_RISER_TOUCH_CLIMB_HEIGHT:
		failures.append(
			"HumanBody3D stair riser-contact probe climbed only %.2f units" % stair_climb
		)

	probe.queue_free()


func _validate_character_stair_reversal_stability(failures: Array[String]) -> void:
	var probe := HUMAN_BODY_3D_SCENE.instantiate() as HumanBody3D
	if probe == null:
		failures.append("HumanBody3D stair reversal probe failed to instantiate")
		return

	probe.name = "CharacterStairReversalProbe"
	probe.visible = false
	probe.body_radius = 0.28
	probe.body_height = 1.72
	add_child(probe)

	await get_tree().physics_frame
	probe.global_position = STAIR_PROBE_START
	probe.velocity = Vector3.ZERO
	for i in range(STAIR_SETTLE_FRAMES):
		probe.velocity.y = STAIR_PROBE_GROUNDING_VELOCITY
		probe.move_with_speed(Vector3.ZERO, 0.0)
		await get_tree().physics_frame

	var lower_position := probe.global_position
	var max_frame_drop := 0.0
	var longest_ungrounded_run := 0
	for cycle in range(STAIR_REVERSAL_CYCLES):
		var side_bias := Vector3.LEFT if cycle % 2 == 0 else Vector3.RIGHT
		var up_direction := (STAIR_UP_DIRECTION + side_bias * STAIR_REVERSAL_SIDE_BIAS).normalized()
		var down_direction := (STAIR_DOWN_DIRECTION - side_bias * STAIR_REVERSAL_SIDE_BIAS).normalized()

		var climb_start_y := probe.global_position.y
		var max_y := climb_start_y
		for i in range(_stair_frames_for_travel(STAIR_ASCEND_TARGET_PROGRESS, HumanBody3D.DEFAULT_RUN_SPEED)):
			var before_y := probe.global_position.y
			probe.velocity.y = STAIR_PROBE_GROUNDING_VELOCITY
			probe.move_with_speed(up_direction, HumanBody3D.DEFAULT_RUN_SPEED)
			max_frame_drop = maxf(max_frame_drop, before_y - probe.global_position.y)
			max_y = maxf(max_y, probe.global_position.y)
			var climb_progress := (probe.global_position - lower_position).dot(STAIR_UP_DIRECTION)
			await get_tree().physics_frame
			if (
				climb_progress >= STAIR_ASCEND_TARGET_PROGRESS
				and max_y - climb_start_y >= MIN_STAIR_REVERSAL_CLIMB_HEIGHT
			):
				break

		if max_y - climb_start_y < MIN_STAIR_REVERSAL_CLIMB_HEIGHT:
			failures.append(
				"HumanBody3D stair reversal cycle %d climbed only %.2f units"
					% [cycle + 1, max_y - climb_start_y]
			)
			break

		var top_position := probe.global_position
		var ungrounded_run := 0
		for i in range(_stair_frames_for_travel(STAIR_ASCEND_TARGET_PROGRESS, HumanBody3D.DEFAULT_RUN_SPEED)):
			var before_y := probe.global_position.y
			probe.velocity.y = STAIR_PROBE_GROUNDING_VELOCITY
			probe.move_with_speed(down_direction, HumanBody3D.DEFAULT_RUN_SPEED)
			max_frame_drop = maxf(max_frame_drop, before_y - probe.global_position.y)
			if _is_probe_grounded(probe):
				ungrounded_run = 0
			else:
				ungrounded_run += 1
				longest_ungrounded_run = maxi(longest_ungrounded_run, ungrounded_run)
			var return_progress := (top_position - probe.global_position).dot(STAIR_UP_DIRECTION)
			await get_tree().physics_frame
			if (
				return_progress >= STAIR_ASCEND_TARGET_PROGRESS - probe.body_radius
				and probe.global_position.y <= lower_position.y + MAX_STAIR_RETURN_HEIGHT
			):
				break

	if max_frame_drop > MAX_STAIR_FRAME_DROP:
		failures.append(
			"HumanBody3D stair reversal probe dropped %.2f units in one frame" % max_frame_drop
		)
	if longest_ungrounded_run > MAX_STAIR_DOWN_UNGROUNDED_RUN:
		failures.append(
			"HumanBody3D stair reversal probe lost support for %d consecutive frames"
				% longest_ungrounded_run
		)
	if absf(probe.global_position.y - lower_position.y) > MAX_STAIR_RETURN_HEIGHT:
		failures.append("HumanBody3D stair reversal probe did not finish on the lower landing")

	probe.queue_free()


func _validate_character_stair_jump_stability(failures: Array[String]) -> void:
	var probe := HUMAN_BODY_3D_SCENE.instantiate() as HumanBody3D
	if probe == null:
		failures.append("HumanBody3D stair jump probe failed to instantiate")
		return

	probe.name = "CharacterStairJumpProbe"
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

	var up_max_frames := _stair_frames_for_travel(STAIR_ASCEND_TARGET_PROGRESS, PROBE_SPEED)
	var start_position := probe.global_position
	for i in range(up_max_frames):
		probe.velocity.y = STAIR_PROBE_GROUNDING_VELOCITY
		probe.move_with_speed(STAIR_UP_DIRECTION, PROBE_SPEED)
		var current_progress := (probe.global_position - start_position).dot(STAIR_UP_DIRECTION)
		await get_tree().physics_frame
		if current_progress >= STAIR_ASCEND_TARGET_PROGRESS:
			break

	var top_floor_y := _sample_probe_floor_y(probe)
	if top_floor_y == FLOOR_SAMPLE_MISSING:
		failures.append("HumanBody3D stair jump probe could not sample the top stair floor")
		probe.queue_free()
		return

	var max_floor_gap := 0.0
	var max_frame_drop := 0.0
	for cycle in range(STAIR_JUMP_CYCLES):
		probe.jump()
		for i in range(STAIR_JUMP_FRAMES):
			var before_y := probe.global_position.y
			probe.move_with_speed(Vector3.ZERO, 0.0)
			var floor_y := _sample_probe_floor_y(probe)
			if floor_y != FLOOR_SAMPLE_MISSING:
				max_floor_gap = maxf(max_floor_gap, absf(probe.global_position.y - floor_y))
			max_frame_drop = maxf(max_frame_drop, before_y - probe.global_position.y)
			await get_tree().physics_frame

	if max_floor_gap > MAX_STAIR_JUMP_FLOOR_GAP:
		failures.append(
			"HumanBody3D stair jump probe floated %.2f units away from the floor" % max_floor_gap
		)
	if max_frame_drop > MAX_STAIR_JUMP_FRAME_DROP:
		failures.append(
			"HumanBody3D stair jump probe snapped down %.2f units during repeated jumps" % max_frame_drop
		)
	if !_is_probe_grounded(probe):
		failures.append("HumanBody3D stair jump probe did not settle grounded after repeated jumps")

	probe.queue_free()


func _is_probe_grounded(probe: HumanBody3D) -> bool:
	if probe.has_method("is_grounded"):
		return bool(probe.call("is_grounded"))
	return probe.is_on_floor()


func _sample_probe_floor_y(probe: HumanBody3D) -> float:
	var query := PhysicsRayQueryParameters3D.create(
		probe.global_position + Vector3.UP,
		probe.global_position + (Vector3.DOWN * 3.0)
	)
	query.exclude = [probe.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return FLOOR_SAMPLE_MISSING
	var hit_normal: Vector3 = hit.get("normal", Vector3.ZERO)
	if hit_normal.y <= MAX_WALL_NORMAL_Y:
		return FLOOR_SAMPLE_MISSING
	var hit_position: Vector3 = hit.get("position", Vector3.ZERO)
	return hit_position.y


func _stair_frames_for_travel(travel_distance: float, movement_speed: float) -> int:
	var safe_speed := maxf(movement_speed, 0.001)
	var physics_fps := maxf(float(Engine.physics_ticks_per_second), 1.0)
	var travel_frames := ceili(maxf(travel_distance, 0.0) / safe_speed * physics_fps)
	return mini(travel_frames + STAIR_TRAVERSAL_FRAME_MARGIN, STAIR_MAX_TRAVERSAL_FRAMES)


func _append_stair_failure(failures: Array[String], stair_probe_speed: float, message: String) -> void:
	failures.append("HumanBody3D stair probe at %.1f speed %s" % [stair_probe_speed, message])
