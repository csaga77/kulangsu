extends Node3D

const HUMAN_BODY_3D_SCENE := preload("res://characters/human_body_3d.tscn")
const SETTLE_FRAMES := 8
const GROUNDING_VELOCITY := -1.0
const WALL_PROBE_START := Vector3(-2.2, 0.08, 0.0)
const WALL_PROBE_FRAMES := 90
const WALL_MAX_X := -0.30
const WALL_MAX_VERTICAL_DRIFT := 0.15
const FALL_PROBE_START := Vector3(0.0, 2.4, -8.0)
const FALL_PROBE_FRAMES := 90
const FALL_MAX_REST_HEIGHT := 0.12
const RIGID_LANE_Z := 8.0
const RIGID_BALL_RADIUS := 0.4
const RIGID_PROBE_START := Vector3(-1.5, 0.08, RIGID_LANE_Z)
const RIGID_PROBE_FRAMES := 60
const RIGID_MIN_TRAVEL := 0.35
const STAIR_LANE_Z := 16.0
const STAIR_STEP_COUNT := 6
const STAIR_STEP_DEPTH := 0.55
const STAIR_STEP_HEIGHT := 0.18
const STAIR_WIDTH := 2.0
const STAIR_PROBE_START := Vector3(-1.2, 0.08, STAIR_LANE_Z)
const STAIR_UP_FRAMES := 125
const STAIR_DOWN_FRAMES := 140
const STAIR_MIN_CLIMB_HEIGHT := 0.85
const STAIR_MAX_RETURN_HEIGHT := 0.25
const STAIR_SIDE_START := Vector3(1.35, 0.08, STAIR_LANE_Z - 2.2)
const STAIR_SIDE_FRAMES := 90
const STAIR_SIDE_MAX_Z := STAIR_LANE_Z - (STAIR_WIDTH * 0.5) - 0.20
const STAIR_SIDE_MAX_HEIGHT := 0.20
const STAIR_SIDE_WALL_COLLISION_META := &"stairs_side_wall_collision"


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_build_collision_fixtures()
	call_deferred("_run_smoke_checks")


func _run_smoke_checks() -> void:
	await get_tree().physics_frame
	var failures: Array[String] = []
	await _validate_static_wall_blocking(failures)
	await _validate_gravity_and_landing(failures)
	await _validate_rigid_body_push(failures)
	await _validate_stair_front_and_side_traversal(failures)

	if failures.is_empty():
		print("PASS: HumanBody3D collision smoke test")
	else:
		for failure in failures:
			push_error(failure)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if failures.is_empty() else 1)


func _validate_static_wall_blocking(failures: Array[String]) -> void:
	var probe := _create_probe("WallProbe", WALL_PROBE_START)
	await _settle_probe(probe)
	var start_y := probe.global_position.y
	var saw_wall_collision := false
	for frame in range(WALL_PROBE_FRAMES):
		probe.velocity.y = GROUNDING_VELOCITY
		probe.move_with_speed(Vector3.RIGHT, 4.0)
		for collision_index in range(probe.get_slide_collision_count()):
			var collision := probe.get_slide_collision(collision_index)
			if collision != null and absf(collision.get_normal().y) < 0.75:
				saw_wall_collision = true
		await get_tree().physics_frame

	if probe.global_position.x > WALL_MAX_X:
		failures.append(
			"HumanBody3D crossed the static wall (x=%0.2f, max=%0.2f)"
			% [probe.global_position.x, WALL_MAX_X]
		)
	if absf(probe.global_position.y - start_y) > WALL_MAX_VERTICAL_DRIFT:
		failures.append("HumanBody3D drifted vertically while blocked by a wall")
	if !saw_wall_collision:
		failures.append("HumanBody3D did not report a static wall slide collision")
	probe.queue_free()


func _validate_gravity_and_landing(failures: Array[String]) -> void:
	var probe := _create_probe("FallProbe", FALL_PROBE_START)
	for frame in range(FALL_PROBE_FRAMES):
		probe.move_with_speed(Vector3.ZERO, 0.0)
		await get_tree().physics_frame

	if probe.global_position.y > FALL_MAX_REST_HEIGHT:
		failures.append(
			"HumanBody3D did not fall onto the floor (rest y=%0.2f)"
			% probe.global_position.y
		)
	if !probe.is_grounded():
		failures.append("HumanBody3D did not report grounded after falling")
	probe.queue_free()


func _validate_rigid_body_push(failures: Array[String]) -> void:
	var ball := RigidBody3D.new()
	ball.name = "PushBall"
	ball.mass = 0.2
	ball.gravity_scale = 0.0
	ball.can_sleep = false
	ball.position = Vector3(0.0, RIGID_BALL_RADIUS, RIGID_LANE_Z)
	var ball_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = RIGID_BALL_RADIUS
	ball_shape.shape = sphere
	ball.add_child(ball_shape)
	add_child(ball)

	var probe := _create_probe("RigidPushProbe", RIGID_PROBE_START)
	await _settle_probe(probe)
	var ball_start_x := ball.global_position.x
	var saw_ball_collision := false
	for frame in range(RIGID_PROBE_FRAMES):
		probe.velocity.y = GROUNDING_VELOCITY
		probe.move_with_speed(Vector3.RIGHT, 4.0)
		for collision_index in range(probe.get_slide_collision_count()):
			var collision := probe.get_slide_collision(collision_index)
			if collision != null and collision.get_collider() == ball:
				saw_ball_collision = true
		await get_tree().physics_frame

	var ball_travel := ball.global_position.x - ball_start_x
	if !saw_ball_collision:
		failures.append("HumanBody3D did not collide with the dynamic push target")
	if ball_travel < RIGID_MIN_TRAVEL:
		failures.append(
			"HumanBody3D pushed the rigid body only %0.2f units"
			% ball_travel
		)
	probe.queue_free()
	ball.queue_free()


func _validate_stair_front_and_side_traversal(failures: Array[String]) -> void:
	var probe := _create_probe("StairFrontProbe", STAIR_PROBE_START)
	await _settle_probe(probe)
	var start_y := probe.global_position.y
	var max_y := start_y
	for frame in range(STAIR_UP_FRAMES):
		probe.velocity.y = GROUNDING_VELOCITY
		probe.move_with_speed(Vector3.RIGHT, 2.4)
		max_y = maxf(max_y, probe.global_position.y)
		await get_tree().physics_frame

	if max_y - start_y < STAIR_MIN_CLIMB_HEIGHT:
		failures.append(
			"HumanBody3D climbed only %0.2f units from the front of the stairs"
			% (max_y - start_y)
		)

	for frame in range(STAIR_DOWN_FRAMES):
		probe.velocity.y = GROUNDING_VELOCITY
		probe.move_with_speed(Vector3.LEFT, 2.4)
		await get_tree().physics_frame
	if absf(probe.global_position.y - start_y) > STAIR_MAX_RETURN_HEIGHT:
		failures.append("HumanBody3D did not return to the lower landing after descending")
	probe.queue_free()

	var side_probe := _create_probe("StairSideProbe", STAIR_SIDE_START)
	await _settle_probe(side_probe)
	var max_side_y := side_probe.global_position.y
	var saw_side_wall_collision := false
	var saw_side_wall_flag := false
	var saw_side_wall_ahead := false
	var first_side_step_frame := -1
	var first_side_step_position := Vector3.ZERO
	var first_side_step_had_blocker_ahead := false
	for frame in range(STAIR_SIDE_FRAMES):
		var blocker_ahead := bool(side_probe.call("_has_stair_side_wall_ahead", Vector3.BACK))
		saw_side_wall_ahead = saw_side_wall_ahead or blocker_ahead
		side_probe.velocity.y = GROUNDING_VELOCITY
		side_probe.move_with_speed(Vector3.BACK, 2.4)
		max_side_y = maxf(max_side_y, side_probe.global_position.y)
		if first_side_step_frame < 0 and side_probe.global_position.y > STAIR_SIDE_MAX_HEIGHT:
			first_side_step_frame = frame
			first_side_step_position = side_probe.global_position
			first_side_step_had_blocker_ahead = blocker_ahead
		for collision_index in range(side_probe.get_slide_collision_count()):
			var collision := side_probe.get_slide_collision(collision_index)
			var collider := collision.get_collider() as Node
			if collider != null and String(collider.name).begins_with("StairSideWall"):
				saw_side_wall_collision = true
		var wall_flags := int(side_probe.call("_get_blocking_wall_contact_flags", Vector3.BACK))
		saw_side_wall_flag = saw_side_wall_flag or (wall_flags & 2) != 0
		await get_tree().physics_frame

	if !saw_side_wall_collision:
		failures.append("HumanBody3D did not collide with the generated stair side blocker")
	if !saw_side_wall_flag:
		failures.append("HumanBody3D did not classify the generated stair side blocker")
	if !saw_side_wall_ahead:
		failures.append("HumanBody3D did not detect the generated stair side blocker ahead")
	if side_probe.global_position.z > STAIR_SIDE_MAX_Z:
		failures.append(
			"HumanBody3D crossed the generated stair side blocker "
			+ "(position=%s, max z=%0.2f)" % [side_probe.global_position, STAIR_SIDE_MAX_Z]
		)
	if max_side_y > STAIR_SIDE_MAX_HEIGHT:
		failures.append(
			(
				"HumanBody3D stepped to y=%0.2f through the stair side blocker "
				+ "(first at frame %d, position=%s, blocker ahead=%s)"
			)
			% [
				max_side_y,
				first_side_step_frame,
				first_side_step_position,
				first_side_step_had_blocker_ahead,
			]
		)
	side_probe.queue_free()


func _create_probe(probe_name: String, position: Vector3) -> HumanBody3D:
	var probe := HUMAN_BODY_3D_SCENE.instantiate() as HumanBody3D
	probe.name = probe_name
	probe.visible = false
	probe.draw_skeleton_bones = false
	probe.character_model_scene = null
	probe.body_height = 1.72
	probe.body_radius = 0.28
	add_child(probe)
	probe.global_position = position
	return probe


func _settle_probe(probe: HumanBody3D) -> void:
	await get_tree().physics_frame
	for frame in range(SETTLE_FRAMES):
		probe.velocity.y = GROUNDING_VELOCITY
		probe.move_with_speed(Vector3.ZERO, 0.0)
		await get_tree().physics_frame


func _build_collision_fixtures() -> void:
	_add_static_box("WallLaneFloor", Vector3(8.0, 0.10, 4.0), Vector3(0.0, -0.05, 0.0))
	_add_static_box("StaticWall", Vector3(0.20, 2.0, 3.5), Vector3(0.0, 1.0, 0.0))
	_add_static_box("FallLaneFloor", Vector3(5.0, 0.10, 4.0), Vector3(0.0, -0.05, -8.0))
	_add_static_box("RigidLaneFloor", Vector3(8.0, 0.10, 4.0), Vector3(0.0, -0.05, RIGID_LANE_Z))
	_build_stair_fixture()


func _build_stair_fixture() -> void:
	_add_static_box(
		"StairLowerLanding",
		Vector3(4.0, 0.10, 4.0),
		Vector3(-2.0, -0.05, STAIR_LANE_Z)
	)
	for step_index in range(STAIR_STEP_COUNT):
		var top_height := float(step_index + 1) * STAIR_STEP_HEIGHT
		var center_x := (float(step_index) + 0.5) * STAIR_STEP_DEPTH
		_add_static_box(
			"StairStep%d" % (step_index + 1),
			Vector3(STAIR_STEP_DEPTH, top_height, STAIR_WIDTH),
			Vector3(center_x, top_height * 0.5, STAIR_LANE_Z)
		)

	var top_height := float(STAIR_STEP_COUNT) * STAIR_STEP_HEIGHT
	var stair_length := float(STAIR_STEP_COUNT) * STAIR_STEP_DEPTH
	_add_static_box(
		"StairSideApproachFloor",
		Vector3(stair_length, 0.10, 4.0),
		Vector3(stair_length * 0.5, -0.05, STAIR_LANE_Z - 3.0)
	)
	_add_static_box(
		"StairTopLanding",
		Vector3(3.0, 0.10, 4.0),
		Vector3(stair_length + 1.5, top_height - 0.05, STAIR_LANE_Z)
	)
	for side_sign in [-1.0, 1.0]:
		_add_static_box(
			"StairSideWall%s" % ("Left" if side_sign < 0.0 else "Right"),
			Vector3(stair_length, top_height + 0.8, 0.12),
			Vector3(
				stair_length * 0.5,
				(top_height + 0.8) * 0.5,
				STAIR_LANE_Z + side_sign * (STAIR_WIDTH * 0.5 + 0.06)
			),
			true
		)


func _add_static_box(
	body_name: String,
	box_size: Vector3,
	center_position: Vector3,
	is_stair_side_wall := false
) -> void:
	var body := StaticBody3D.new()
	body.name = body_name
	body.position = center_position
	var shape := BoxShape3D.new()
	shape.size = box_size
	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	collision_shape.shape = shape
	if is_stair_side_wall:
		collision_shape.set_meta(STAIR_SIDE_WALL_COLLISION_META, true)
	body.add_child(collision_shape)
	add_child(body)
