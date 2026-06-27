@tool
extends Node3D

const BuildingEditor3DScript = preload("res://addons/low_poly_building_editor/building_editor_3d.gd")
const Wall3DScript = preload("res://addons/low_poly_building_editor/wall_3d.gd")
const Floor3DScript = preload("res://addons/low_poly_building_editor/floor_3d.gd")
const Stairs3DScript = preload("res://addons/low_poly_building_editor/stairs_3d.gd")
const Pillar3DScript = preload("res://addons/low_poly_building_editor/pillar_3d.gd")
const Roof3DScript = preload("res://addons/low_poly_building_editor/roof_3d.gd")
const BuildingOpening3DScript = preload("res://addons/low_poly_building_editor/building_opening_3d.gd")
const WallSegment3DScript = preload("res://addons/low_poly_building_editor/wall_segment_3d.gd")
const HUMAN_BODY_3D_SCENE := preload("res://characters/human_body_3d.tscn")
const TEST_ROOF_ANGLE_DEGREES := 40.0
const TEST_ROOF_ALT_ANGLE_DEGREES := 30.0
const WALL_COLLISION_TEST_ORIGIN := Vector3(24.0, 0.0, 36.0)
const WALL_COLLISION_PROBE_SPEED := 4.0
const WALL_COLLISION_PROBE_FRAMES := 90
const WALL_COLLISION_MAX_TRAVEL := 1.85
const WALL_COLLISION_MAX_NORMAL_Y := 0.75
const WALL_COLLISION_SLIDE_FRAMES := 56
const WALL_COLLISION_SLIDE_MIN_TOTAL_PARALLEL_TRAVEL := 1.6
const WALL_COLLISION_SLIDE_MIN_CONTACT_PARALLEL_TRAVEL := 0.45
const STAIRS_SIDE_COLLISION_TEST_ORIGIN := Vector3(36.0, 0.0, 36.0)
const STAIRS_SIDE_COLLISION_PROBE_SPEED := 4.0
const STAIRS_SIDE_COLLISION_PROBE_FRAMES := 90
const STAIRS_SIDE_COLLISION_MAX_TRAVEL := 1.25
const STAIRS_SIDE_COLLISION_MAX_CLIMB := 0.2
const STAIRS_SIDE_COLLISION_MAX_NORMAL_Y := 0.75
const STAIRS_FRONT_CLIMB_PROBE_FRAMES := 100
const STAIRS_FRONT_CLIMB_MIN_TRAVEL := 3.0
const STAIRS_FRONT_CLIMB_MIN_HEIGHT := 0.9
const STAIRS_SIDE_EXIT_PROBE_FRAMES := 45
const STAIRS_SIDE_EXIT_MIN_TRAVEL := 1.8

var m_failures: Array[String] = []


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	call_deferred("_run_smoke_checks")


func _run_smoke_checks() -> void:
	_validate_empty_wall_segments()
	var coordinator := BuildingEditor3DScript.new() as BuildingEditor3DScript
	coordinator.name = "BuildingEditor3D"
	add_child(coordinator)
	coordinator.grid_step = 0.5

	var wall := coordinator.create_wall_node(
		Vector3.ZERO,
		Vector3(4.0, 0.0, 0.0),
		2.4,
		0.22,
		Color(0.78, 0.68, 0.54, 1.0)
	)
	coordinator.add_child(wall)

	var opening := BuildingOpening3DScript.new() as BuildingOpening3DScript
	opening.name = "WindowOpening"
	opening.opening_width = 1.0
	opening.opening_height = 1.0
	opening.position = Vector3(2.0, 1.1, 0.12)
	wall.add_child(opening)
	wall.rebuild_wall_mesh()

	_validate_wall_mesh(wall)
	_validate_opening_rules(wall)
	_validate_door_opening_rules(wall)
	_validate_window_style_visuals()
	_validate_opening_follows_wall_segment()
	_validate_snapping(coordinator)
	_validate_wall_base_height(coordinator)
	_validate_room_node(coordinator)
	_validate_floor_node(coordinator)
	_validate_stairs_node(coordinator)
	_validate_pillar_node(coordinator)
	_validate_roof_node(coordinator)
	_validate_merge_detection(coordinator)
	_validate_intersection_merge()
	_validate_wall_instance_intersection_clipping()
	_validate_roof_wall_clipping()
	_validate_add_wall_joint()
	_validate_joint_endpoint_drag()
	_validate_joint_disconnect_connect()
	_validate_mitered_joint()
	_validate_miter_draw_direction_invariance()
	_validate_connected_wall_top_caps()
	_validate_multi_wall_joint_fill()
	_validate_enclosed_wall_loop_caps()
	_validate_overlapping_room_wall_clipping()
	_validate_collinear_overlap_opening_propagation()
	await _validate_wall_collision_blocks_character(coordinator)
	await _validate_stairs_side_collision_blocks_character(coordinator)

	for failure in m_failures:
		push_error(failure)
	if m_failures.is_empty():
		print("PASS: LowPolyBuildingEditor3D smoke test")
	get_tree().quit(0 if m_failures.is_empty() else 1)


func _validate_empty_wall_segments() -> void:
	var wall := Wall3DScript.new() as Wall3DScript
	wall.name = "EmptyWall"
	wall.build_on_ready = false
	add_child(wall)
	wall.rebuild_wall_mesh()
	if wall.get_segment_count() != 0 or !wall.segments.is_empty():
		m_failures.append("Wall3D did not allow an empty canonical segments array")
	if wall.mesh != null or wall.get_node_or_null("WallCollision") != null:
		m_failures.append("Wall3D generated geometry for an empty segments array")
	var has_exported_segments := false
	var has_exported_extra_segments := false
	for property in wall.get_property_list():
		var property_name := String(property.get("name", ""))
		var usage := int(property.get("usage", 0))
		if property_name == "segments" and (usage & PROPERTY_USAGE_EDITOR) != 0:
			has_exported_segments = true
		if property_name == "extra_segments" and (usage & PROPERTY_USAGE_EDITOR) != 0:
			has_exported_extra_segments = true
	if !has_exported_segments:
		m_failures.append("Wall3D segments property is not exported in the inspector")
	if has_exported_extra_segments:
		m_failures.append("Wall3D still exports the legacy Extra Segments property")
	var authored_segment := WallSegment3DScript.new() as WallSegment3D
	authored_segment.start_point = Vector3.ZERO
	authored_segment.end_point = Vector3(4.0, 0.0, 0.0)
	authored_segment.height = 3.1
	authored_segment.thickness = 0.35
	authored_segment.color = Color(0.24, 0.52, 0.74, 1.0)
	var authored_segments: Array[WallSegment3D] = [authored_segment]
	wall.segments = authored_segments
	var split_geometry := wall.split_segment_geometry(0, Vector3(2.0, 0.0, 0.0), 0.1)
	wall.set_wall_geometry(
		Vector3(split_geometry["start"]),
		Vector3(split_geometry["end"]),
		split_geometry["segments"]
	)
	if wall.get_segment_count() != 2:
		m_failures.append("Wall3D canonical segments did not retain a split wall")
	for segment_index in range(wall.get_segment_count()):
		var segment := wall.get_segment(segment_index)
		if (
			!is_equal_approx(segment.height, 3.1)
			or !is_equal_approx(segment.thickness, 0.35)
			or segment.color != authored_segment.color
		):
			m_failures.append("Wall3D geometry edit lost per-segment authored properties")


func _validate_wall_mesh(wall: Wall3DScript) -> void:
	if wall.mesh == null:
		m_failures.append("Wall3D did not generate a mesh")
		return
	if wall.mesh.get_surface_count() <= 0:
		m_failures.append("Wall3D mesh has no surfaces")
		return
	var arrays := wall.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if vertices.is_empty():
		m_failures.append("Wall3D mesh has no vertices")
	if normals.size() != vertices.size():
		m_failures.append("Wall3D mesh is missing per-vertex normal data")
	if colors.size() != vertices.size():
		m_failures.append("Wall3D mesh is missing per-vertex color data")
	if !normals.is_empty() and normals[0].dot(Vector3.BACK) < 0.999:
		m_failures.append("Wall3D primary outside face normal is inverted")
	if indices.size() >= 3 and !normals.is_empty():
		var a := vertices[indices[0]]
		var b := vertices[indices[1]]
		var c := vertices[indices[2]]
		var winding_normal := (b - a).cross(c - a).normalized()
		if winding_normal.dot(normals[indices[0]]) > -0.999:
			m_failures.append("Wall3D triangle winding does not match Godot BoxMesh convention")
	if wall.get_node_or_null("WallCollision") == null:
		m_failures.append("Wall3D did not generate collision for editor raycasts")


func _validate_room_node(coordinator: BuildingEditor3DScript) -> void:
	var room := coordinator.create_room_node(
		Vector3(8.0, 0.5, 8.0),
		Vector3(12.0, 0.5, 11.0),
		2.8,
		0.3,
		Color(0.62, 0.54, 0.44, 1.0)
	)
	coordinator.add_child(room)
	if !room.name.begins_with("Room3D"):
		m_failures.append("BuildingEditor3D did not give an enclosed room a room name")
	if room.get_segment_count() != 4:
		m_failures.append("BuildingEditor3D room did not create four wall spans")
	if room.segments.size() != 4:
		m_failures.append("BuildingEditor3D room did not store every span in Wall3D.segments")
	var expected_corners: Array[Vector3] = [
		Vector3(8.0, 0.5, 8.0),
		Vector3(12.0, 0.5, 8.0),
		Vector3(12.0, 0.5, 11.0),
		Vector3(8.0, 0.5, 11.0),
	]
	for corner in expected_corners:
		if room.count_connected_endpoints(corner, 0.001) != 2:
			m_failures.append("BuildingEditor3D room walls are not enclosed at %s" % corner)
	for segment_index in range(room.get_segment_count()):
		var segment := room.get_segment(segment_index)
		if !is_equal_approx(segment.height, 2.8):
			m_failures.append("BuildingEditor3D room wall lost its configured height")
		if !is_equal_approx(segment.thickness, 0.3):
			m_failures.append("BuildingEditor3D room wall lost its configured thickness")
	if room.mesh == null:
		m_failures.append("BuildingEditor3D room did not generate a wall mesh")
	if room.get_node_or_null("WallCollision") == null:
		m_failures.append("BuildingEditor3D room did not generate wall collision")
	if !room.is_rectangular_loop():
		m_failures.append("Wall3D did not recognize a generated room as a rectangular loop")
	var room_opening := BuildingOpening3DScript.new() as BuildingOpening3DScript
	room_opening.name = "RoomResizeWindow"
	room_opening.opening_width = 0.8
	room_opening.opening_height = 0.8
	room_opening.position = room.get_segment_local_frame(1) * Vector3(1.5, 1.1, 0.185)
	room_opening.set_meta(Wall3DScript.SEGMENT_INDEX_META, 1)
	room.add_child(room_opening)
	room.rebuild_wall_mesh()
	var old_opening_parent_position := room.transform * room_opening.position
	if !room.move_rectangular_loop_side(1, Vector3(1.0, 0.0, 1.0)):
		m_failures.append("Wall3D could not resize a rectangular room from one wall")
	else:
		var expected_resized_corners: Array[Vector3] = [
			Vector3(8.0, 0.5, 8.0),
			Vector3(13.0, 0.5, 8.0),
			Vector3(13.0, 0.5, 11.0),
			Vector3(8.0, 0.5, 11.0),
		]
		for corner in expected_resized_corners:
			if room.count_connected_endpoints(corner, 0.001) != 2:
				m_failures.append("Room side resize did not preserve corner connection at %s" % corner)
		if room.count_connected_endpoints(Vector3(12.0, 0.5, 8.0), 0.001) != 0:
			m_failures.append("Room side resize moved along the selected wall instead of only perpendicular to it")
		var opening_parent_position := room.transform * room_opening.position
		if opening_parent_position.distance_to(old_opening_parent_position + Vector3.RIGHT) > 0.001:
			m_failures.append("Room side resize did not preserve the opening anchor on the moved wall")


func _validate_opening_rules(wall: Wall3DScript) -> void:
	var overlapping_center := Vector2(2.0, 1.1)
	var open_center := Vector2(3.35, 1.1)
	if wall.can_place_opening(overlapping_center, Vector2(0.8, 0.8)):
		m_failures.append("Wall3D allowed an overlapping window opening")
	if !wall.can_place_opening(open_center, Vector2(0.6, 0.8)):
		m_failures.append("Wall3D rejected a valid non-overlapping opening")


func _validate_door_opening_rules(wall: Wall3DScript) -> void:
	var door_center := Vector2(0.8, 1.05)
	var door_size := Vector2(0.9, 2.1)
	if wall.can_place_opening(door_center, door_size, 0.03, null, 0):
		m_failures.append("Wall3D allowed a floor-touching door without base-edge allowance")
	if !wall.can_place_opening(door_center, door_size, 0.03, null, 0, true):
		m_failures.append("Wall3D rejected a valid floor-touching door opening")

	var door := BuildingOpening3DScript.new() as BuildingOpening3DScript
	door.name = "DoubleDoorOpening"
	door.opening_width = 1.6
	door.opening_height = 2.1
	door.show_bottom_frame = false
	door.door_panel_count = 2
	add_child(door)
	if door.get_node_or_null("BottomFrame") != null:
		m_failures.append("BuildingOpening3D generated a bottom frame for a door frame")
	if door.get_node_or_null("LeftDoorPanel") == null or door.get_node_or_null("RightDoorPanel") == null:
		m_failures.append("BuildingOpening3D did not generate double door panels")


func _validate_window_style_visuals() -> void:
	var double_window := BuildingOpening3DScript.new() as BuildingOpening3DScript
	double_window.name = "DoubleWindowOpening"
	double_window.opening_width = 1.8
	double_window.opening_height = 1.0
	double_window.window_pane_count = 2
	add_child(double_window)
	if double_window.get_node_or_null("BottomFrame") == null:
		m_failures.append("BuildingOpening3D did not keep bottom frame for a window")
	if (
		double_window.get_node_or_null("LeftWindowPane") == null
		or double_window.get_node_or_null("RightWindowPane") == null
	):
		m_failures.append("BuildingOpening3D did not generate double window panes")

	var window_frame := BuildingOpening3DScript.new() as BuildingOpening3DScript
	window_frame.name = "WindowFrameOpening"
	window_frame.window_pane_count = 0
	add_child(window_frame)
	if window_frame.get_node_or_null("WindowPane") != null:
		m_failures.append("BuildingOpening3D generated panes for a frame-only window")


func _validate_opening_follows_wall_segment() -> void:
	var wall := Wall3DScript.new() as Wall3DScript
	wall.name = "OpeningFollowWall"
	wall.build_on_ready = false
	wall.start_point = Vector3.ZERO
	wall.end_point = Vector3(4.0, 0.0, 0.0)
	wall.wall_height = 2.4
	wall.wall_thickness = 0.22
	wall.wall_color = Color(0.78, 0.68, 0.54, 1.0)
	add_child(wall)

	var branch := WallSegment3DScript.new()
	branch.start_point = Vector3(2.0, 0.0, 0.0)
	branch.end_point = Vector3(2.0, 0.0, 2.0)
	branch.height = wall.wall_height
	branch.thickness = wall.wall_thickness
	branch.color = wall.wall_color
	var extras: Array[WallSegment3DScript] = [branch]
	wall.extra_segments = extras

	var opening := BuildingOpening3DScript.new() as BuildingOpening3DScript
	opening.name = "FollowingOpening"
	opening.opening_width = 0.5
	opening.opening_height = 0.5
	var opening_anchor := Vector3(1.0, 1.1, wall.wall_thickness * 0.5 + 0.035)
	var old_frame := wall.get_segment_local_frame(1)
	wall.add_child(opening)
	opening.transform = Transform3D(old_frame.basis, old_frame * opening_anchor)
	opening.set_meta(Wall3DScript.SEGMENT_INDEX_META, 1)
	wall.rebuild_wall_mesh()

	var old_position := opening.position
	if !wall.move_segment_endpoint(1, 1, Vector3(3.0, 0.0, 2.0)):
		m_failures.append("Wall3D could not move an opening-bearing segment endpoint")
		return
	var new_frame := wall.get_segment_local_frame(1)
	var local_after := new_frame.affine_inverse() * opening.position
	if local_after.distance_to(opening_anchor) > 0.001:
		m_failures.append("Window opening did not preserve its segment-local anchor after wall edit")
	var expected_position := new_frame * opening_anchor
	if opening.position.distance_to(expected_position) > 0.001:
		m_failures.append("Window opening did not follow the edited wall segment")
	if opening.position.distance_to(old_position) <= 0.001:
		m_failures.append("Window opening stayed in its old wall-local position after segment rotation")
	if wall.get_opening_segment_index(opening) != 1:
		m_failures.append("Window opening lost its segment assignment after wall edit")


func _validate_snapping(coordinator: BuildingEditor3DScript) -> void:
	var snapped: Vector3 = coordinator.snap_local_position(Vector3(0.26, 0.0, 0.74))
	if snapped != Vector3(0.5, 0.0, 0.5):
		m_failures.append("BuildingEditor3D grid snapping returned %s" % str(snapped))
	var constrained: Vector3 = coordinator.constrain_wall_end(Vector3.ZERO, Vector3(1.1, 0.0, 0.8))
	if !is_equal_approx(absf(constrained.x), absf(constrained.z)):
		m_failures.append("BuildingEditor3D did not constrain diagonal drawing to 45 degrees")


func _validate_wall_base_height(coordinator: BuildingEditor3DScript) -> void:
	var base_y := 1.25
	var elevated := coordinator.create_wall_node(
		Vector3(0.0, base_y, 8.0),
		Vector3(4.0, base_y, 8.0),
		2.4,
		0.22,
		Color(0.78, 0.68, 0.54, 1.0)
	)
	coordinator.add_child(elevated)
	if absf(elevated.start_point.y - base_y) > 0.001 or absf(elevated.end_point.y - base_y) > 0.001:
		m_failures.append("Wall3D did not preserve elevated wall base endpoints")
	if absf(elevated.position.y - base_y) > 0.001:
		m_failures.append("Wall3D did not place wall transform at elevated base height")


func _validate_wall_collision_blocks_character(coordinator: BuildingEditor3DScript) -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "WallCollisionProbeFloor"
	floor_body.set_meta(&"test_generated", true)
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(8.0, 0.1, 8.0)
	floor_shape.shape = floor_box
	floor_shape.position = WALL_COLLISION_TEST_ORIGIN + Vector3(0.0, -0.05, 0.0)
	floor_body.add_child(floor_shape)
	add_child(floor_body)

	var wall := coordinator.create_wall_node(
		WALL_COLLISION_TEST_ORIGIN + Vector3(2.0, 0.0, -2.0),
		WALL_COLLISION_TEST_ORIGIN + Vector3(2.0, 0.0, 2.0),
		2.4,
		0.22,
		Color(0.78, 0.68, 0.54, 1.0)
	)
	coordinator.add_child(wall)

	var collision_body := wall.get_node_or_null("WallCollision") as StaticBody3D
	if collision_body == null:
		m_failures.append("Wall3D did not generate solid collision for the character")
		floor_body.queue_free()
		return
	var collision_shape := collision_body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape == null or !(collision_shape.shape is BoxShape3D):
		m_failures.append("Wall3D solid character collision did not use a box blocker")
		floor_body.queue_free()
		return

	var probe := HUMAN_BODY_3D_SCENE.instantiate() as HumanBody3D
	if probe == null:
		m_failures.append("Wall3D character collision probe could not instantiate HumanBody3D")
		floor_body.queue_free()
		return
	probe.name = "WallCollisionHumanBody3DProbe"
	probe.visible = false
	probe.body_radius = 0.28
	probe.body_height = 1.72
	add_child(probe)
	await get_tree().physics_frame

	probe.global_position = WALL_COLLISION_TEST_ORIGIN + Vector3(0.0, 0.1, 0.0)
	probe.velocity = Vector3.ZERO
	for i in range(8):
		probe.velocity.y = -0.5
		probe.move_with_speed(Vector3.ZERO, 0.0)
		await get_tree().physics_frame

	var start_position := probe.global_position
	var saw_wall_collision := false
	for i in range(WALL_COLLISION_PROBE_FRAMES):
		probe.velocity.y = -0.5
		probe.move_with_speed(Vector3.RIGHT, WALL_COLLISION_PROBE_SPEED)
		for collision_index in range(probe.get_slide_collision_count()):
			var collision := probe.get_slide_collision(collision_index)
			if absf(collision.get_normal().y) <= WALL_COLLISION_MAX_NORMAL_Y:
				saw_wall_collision = true
		await get_tree().physics_frame

	var probe_travel := start_position.distance_to(probe.global_position)
	if probe_travel > WALL_COLLISION_MAX_TRAVEL:
		m_failures.append("HumanBody3D moved through solid Wall3D collision by %.2f units" % probe_travel)
	if !saw_wall_collision:
		m_failures.append("HumanBody3D did not report a slide collision against Wall3D")

	probe.global_position = WALL_COLLISION_TEST_ORIGIN + Vector3(0.0, 0.1, -1.5)
	probe.velocity = Vector3.ZERO
	await get_tree().physics_frame
	for i in range(8):
		probe.velocity.y = -0.5
		probe.move_with_speed(Vector3.ZERO, 0.0)
		await get_tree().physics_frame

	var slide_start_position := probe.global_position
	var slide_direction := Vector3(1.0, 0.0, 1.0).normalized()
	var saw_slide_wall_collision := false
	var first_slide_contact_z := slide_start_position.z
	var max_parallel_after_contact := 0.0
	for i in range(WALL_COLLISION_SLIDE_FRAMES):
		probe.velocity.y = -0.5
		probe.move_with_speed(slide_direction, WALL_COLLISION_PROBE_SPEED)
		var frame_saw_wall_collision := false
		for collision_index in range(probe.get_slide_collision_count()):
			var collision := probe.get_slide_collision(collision_index)
			if absf(collision.get_normal().y) <= WALL_COLLISION_MAX_NORMAL_Y:
				frame_saw_wall_collision = true
		if frame_saw_wall_collision:
			if !saw_slide_wall_collision:
				first_slide_contact_z = probe.global_position.z
			saw_slide_wall_collision = true
		if saw_slide_wall_collision:
			max_parallel_after_contact = maxf(
				max_parallel_after_contact,
				probe.global_position.z - first_slide_contact_z
			)
		await get_tree().physics_frame

	var slide_parallel_travel := probe.global_position.z - slide_start_position.z
	var slide_blocked_x := WALL_COLLISION_TEST_ORIGIN.x + WALL_COLLISION_MAX_TRAVEL
	if probe.global_position.x > slide_blocked_x:
		m_failures.append("HumanBody3D moved through Wall3D while sliding along it")
	if !saw_slide_wall_collision:
		m_failures.append("HumanBody3D did not report a diagonal slide collision against Wall3D")
	if slide_parallel_travel < WALL_COLLISION_SLIDE_MIN_TOTAL_PARALLEL_TRAVEL:
		m_failures.append("HumanBody3D only moved %.2f units parallel to Wall3D while sliding" % slide_parallel_travel)
	if max_parallel_after_contact < WALL_COLLISION_SLIDE_MIN_CONTACT_PARALLEL_TRAVEL:
		m_failures.append(
			"HumanBody3D only moved %.2f units parallel to Wall3D after contact"
			% max_parallel_after_contact
		)

	probe.queue_free()
	floor_body.queue_free()


func _validate_floor_node(coordinator: BuildingEditor3DScript) -> void:
	var top_y := 1.25
	var floor := coordinator.create_floor_node(
		Vector3(0.0, top_y, 12.0),
		Vector3(3.0, top_y, 14.0),
		0.18,
		Color(0.46, 0.40, 0.32, 1.0)
	)
	coordinator.add_child(floor)
	if floor.mesh == null:
		m_failures.append("Floor3D did not generate a mesh")
		return
	if floor.mesh.get_surface_count() <= 0:
		m_failures.append("Floor3D mesh has no surfaces")
		return

	var size := floor.get_floor_size()
	if absf(size.x - 3.0) > 0.001 or absf(size.y - 2.0) > 0.001:
		m_failures.append("Floor3D returned the wrong footprint size: %s" % str(size))
	if floor.position.distance_to(Vector3(0.0, top_y, 12.0)) > 0.001:
		m_failures.append("Floor3D did not place its transform at the floor top corner")

	var arrays := floor.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if vertices.is_empty():
		m_failures.append("Floor3D mesh has no vertices")
	if normals.size() != vertices.size():
		m_failures.append("Floor3D mesh is missing per-vertex normal data")
	if colors.size() != vertices.size():
		m_failures.append("Floor3D mesh is missing per-vertex color data")
	if !normals.is_empty() and normals[0].dot(Vector3.UP) < 0.999:
		m_failures.append("Floor3D top face normal is not upward")
	if indices.size() >= 3 and !normals.is_empty():
		var a := vertices[indices[0]]
		var b := vertices[indices[1]]
		var c := vertices[indices[2]]
		var winding_normal := (b - a).cross(c - a).normalized()
		if winding_normal.dot(normals[indices[0]]) > -0.999:
			m_failures.append("Floor3D triangle winding does not match Godot BoxMesh convention")
	var min_y := INF
	var max_y := -INF
	for vertex in vertices:
		min_y = minf(min_y, vertex.y)
		max_y = maxf(max_y, vertex.y)
	if absf(max_y) > 0.001 or absf(min_y + 0.18) > 0.001:
		m_failures.append("Floor3D did not extend thickness downward from the top surface")
	if floor.get_node_or_null("FloorCollision") == null:
		m_failures.append("Floor3D did not generate collision for placed floors")

	var floor_holes: Array[Rect2] = [Rect2(Vector2(1.0, 0.5), Vector2(1.0, 0.75))]
	if !floor.can_add_floor_hole_rect(floor_holes[0]):
		m_failures.append("Floor3D rejected a valid interior floor hole")
	floor.set_floor_holes(floor_holes)
	if floor.get_floor_holes().size() != 1:
		m_failures.append("Floor3D did not store a valid floor hole")
	var holed_mesh := floor.mesh as ArrayMesh
	if _has_horizontal_face_covering_plan_point(holed_mesh, Vector2(1.5, 0.9), 0.0):
		m_failures.append("Floor3D kept a top face over a floor hole")
	if !_has_horizontal_face_covering_plan_point(holed_mesh, Vector2(0.5, 0.3), 0.0):
		m_failures.append("Floor3D removed solid top floor geometry outside the hole")
	if !_has_mesh_vertex_with_normal_near(holed_mesh, Vector3(1.0, 0.0, 0.5), Vector3.RIGHT, 0.001):
		m_failures.append("Floor3D hole is missing its inner left side face")
	if !_has_mesh_vertex_with_normal_near(holed_mesh, Vector3(2.0, 0.0, 0.5), Vector3.LEFT, 0.001):
		m_failures.append("Floor3D hole is missing its inner right side face")
	var intersecting_hole := Rect2(Vector2(1.5, 0.75), Vector2(1.0, 0.75))
	if !floor.can_add_floor_hole_rect(intersecting_hole):
		m_failures.append("Floor3D rejected an intersecting mergeable floor hole")
	floor.set_floor_holes([floor_holes[0], intersecting_hole])
	var merged_holes := floor.get_floor_holes()
	if merged_holes.size() != 3:
		m_failures.append("Floor3D did not preserve merged floor hole shape")
	else:
		if !_has_rect_near(merged_holes, Rect2(Vector2(1.0, 0.5), Vector2(1.0, 0.25))):
			m_failures.append("Floor3D merged floor hole lost the lower-left run")
		if !_has_rect_near(merged_holes, Rect2(Vector2(1.0, 0.75), Vector2(1.5, 0.5))):
			m_failures.append("Floor3D merged floor hole lost the shared middle run")
		if !_has_rect_near(merged_holes, Rect2(Vector2(1.5, 1.25), Vector2(1.0, 0.25))):
			m_failures.append("Floor3D merged floor hole lost the upper-right run")
	var merged_mesh := floor.mesh as ArrayMesh
	if !_has_horizontal_face_covering_plan_point(merged_mesh, Vector2(2.25, 0.6), 0.0):
		m_failures.append("Floor3D overcut a solid corner while merging floor holes")
	if !_has_horizontal_face_covering_plan_point(merged_mesh, Vector2(1.25, 1.4), 0.0):
		m_failures.append("Floor3D overcut the opposite solid corner while merging floor holes")
	if _has_horizontal_face_covering_plan_point(merged_mesh, Vector2(2.25, 1.4), 0.0):
		m_failures.append("Floor3D kept a top face over a merged floor hole")
	if !_has_mesh_vertex_with_normal_near(merged_mesh, Vector3(2.5, 0.0, 0.75), Vector3.LEFT, 0.001):
		m_failures.append("Floor3D merged hole is missing its outer right side face")
	if (
		_has_vertical_face_covering_plan_edge_point(merged_mesh, Vector2(1.25, 0.75), Vector3.FORWARD)
		or _has_vertical_face_covering_plan_edge_point(merged_mesh, Vector2(1.25, 0.75), Vector3.BACK)
	):
		m_failures.append("Floor3D kept an internal side face between merged floor holes")
	if floor.can_add_floor_hole_rect(Rect2(Vector2(0.0, 0.5), Vector2(0.5, 0.5))):
		m_failures.append("Floor3D allowed a hole touching the outer floor edge")
	if !floor.floor_holes_fit_size(floor.get_floor_size()):
		m_failures.append("Floor3D reported its valid stored hole as outside the floor")
	if floor.floor_holes_fit_size(Vector2(1.5, 1.0)):
		m_failures.append("Floor3D did not detect a resize that would invalidate a stored hole")

	floor.set_floor_corners(Vector3(1.0, top_y, 12.5), Vector3(4.5, top_y, 15.0))
	var edited_size := floor.get_floor_size()
	if absf(edited_size.x - 3.5) > 0.001 or absf(edited_size.y - 2.5) > 0.001:
		m_failures.append("Floor3D did not resize from edited corners: %s" % str(edited_size))
	if floor.position.distance_to(Vector3(1.0, top_y, 12.5)) > 0.001:
		m_failures.append("Floor3D did not move transform after edited corners")


func _validate_stairs_node(coordinator: BuildingEditor3DScript) -> void:
	var base_y := 0.75
	var stairs := coordinator.create_stairs_node(
		Vector3(0.0, base_y, 16.0),
		Vector3(3.0, base_y, 20.0),
		1.2,
		4,
		0.16,
		Color(0.52, 0.46, 0.38, 1.0)
	)
	coordinator.add_child(stairs)
	if stairs.mesh == null:
		m_failures.append("Stairs3D did not generate a mesh")
		return
	if stairs.mesh.get_surface_count() <= 0:
		m_failures.append("Stairs3D mesh has no surfaces")
		return

	var size := stairs.get_stair_size()
	if absf(size.x - 3.0) > 0.001 or absf(size.y - 4.0) > 0.001:
		m_failures.append("Stairs3D returned the wrong footprint size: %s" % str(size))
	if stairs.position.distance_to(Vector3(0.0, base_y, 16.0)) > 0.001:
		m_failures.append("Stairs3D did not place its transform at the lower footprint corner")
	if absf(stairs.get_step_rise() - 0.3) > 0.001:
		m_failures.append("Stairs3D calculated the wrong step rise")
	if absf(stairs.get_step_run() - 1.0) > 0.001:
		m_failures.append("Stairs3D calculated the wrong step run")

	var arrays := stairs.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if vertices.is_empty():
		m_failures.append("Stairs3D mesh has no vertices")
	if normals.size() != vertices.size():
		m_failures.append("Stairs3D mesh is missing per-vertex normal data")
	if colors.size() != vertices.size():
		m_failures.append("Stairs3D mesh is missing per-vertex color data")
	if _mesh_vertex_count(stairs) != 66:
		m_failures.append("Stairs3D generated the wrong stepped vertex count")
	if !_has_normal_near(normals, Vector3.UP):
		m_failures.append("Stairs3D mesh is missing tread normals")
	if !_has_normal_near(normals, Vector3.FORWARD):
		m_failures.append("Stairs3D mesh is missing riser normals")
	if !_has_normal_near(normals, Vector3.LEFT) or !_has_normal_near(normals, Vector3.RIGHT):
		m_failures.append("Stairs3D mesh is missing side normals")
	if !_has_mesh_vertex_y_near(stairs, 1.2, 0.001):
		m_failures.append("Stairs3D mesh did not reach the configured stair height")
	if !_has_mesh_vertex_y_near(stairs, -0.16, 0.001):
		m_failures.append("Stairs3D mesh did not extend underside thickness downward")
	if indices.size() >= 3 and !normals.is_empty():
		var a := vertices[indices[0]]
		var b := vertices[indices[1]]
		var c := vertices[indices[2]]
		var winding_normal := (b - a).cross(c - a).normalized()
		if winding_normal.dot(normals[indices[0]]) > -0.999:
			m_failures.append("Stairs3D triangle winding does not match Godot BoxMesh convention")
	if stairs.get_node_or_null("StairsCollision") == null:
		m_failures.append("Stairs3D did not generate collision for placed stairs")
	if !_has_box_collision_shape(stairs, "StairsCollision/%s" % Stairs3DScript.LEFT_SIDE_COLLISION_SHAPE_NAME):
		m_failures.append("Stairs3D did not generate left side-wall collision")
	if !_has_box_collision_shape(stairs, "StairsCollision/%s" % Stairs3DScript.RIGHT_SIDE_COLLISION_SHAPE_NAME):
		m_failures.append("Stairs3D did not generate right side-wall collision")
	if !_has_box_collision_shape(stairs, "StairsCollision/%s_4" % Stairs3DScript.LEFT_SIDE_COLLISION_SHAPE_NAME):
		m_failures.append("Stairs3D did not generate stepped left side-wall collision")
	if !_has_box_collision_shape(stairs, "StairsCollision/%s_4" % Stairs3DScript.RIGHT_SIDE_COLLISION_SHAPE_NAME):
		m_failures.append("Stairs3D did not generate stepped right side-wall collision")
	var first_side_box := _box_collision_shape(
		stairs,
		"StairsCollision/%s" % Stairs3DScript.LEFT_SIDE_COLLISION_SHAPE_NAME
	)
	var first_left_side_shape := _collision_shape(
		stairs,
		"StairsCollision/%s" % Stairs3DScript.LEFT_SIDE_COLLISION_SHAPE_NAME
	)
	var first_right_side_box := _box_collision_shape(
		stairs,
		"StairsCollision/%s" % Stairs3DScript.RIGHT_SIDE_COLLISION_SHAPE_NAME
	)
	var first_right_side_shape := _collision_shape(
		stairs,
		"StairsCollision/%s" % Stairs3DScript.RIGHT_SIDE_COLLISION_SHAPE_NAME
	)
	var last_side_box := _box_collision_shape(
		stairs,
		"StairsCollision/%s_4" % Stairs3DScript.LEFT_SIDE_COLLISION_SHAPE_NAME
	)
	if first_side_box != null:
		var expected_first_side_height := stairs.get_step_rise() + maxf(stairs.stair_thickness, 0.0)
		if absf(first_side_box.size.y - expected_first_side_height) > 0.001:
			m_failures.append("Stairs3D first side-wall collision does not follow first step height")
		if absf(first_side_box.size.z - stairs.get_step_run()) > 0.001:
			m_failures.append("Stairs3D first side-wall collision does not follow first step run")
	if first_side_box != null and first_left_side_shape != null:
		var left_side_outer_x := first_left_side_shape.position.x - first_side_box.size.x * 0.5
		if absf(left_side_outer_x) > 0.001:
			m_failures.append("Stairs3D left side-wall collision extends outside the stair footprint")
	if first_right_side_box != null and first_right_side_shape != null:
		var right_side_outer_x := first_right_side_shape.position.x + first_right_side_box.size.x * 0.5
		if absf(right_side_outer_x - size.x) > 0.001:
			m_failures.append("Stairs3D right side-wall collision extends outside the stair footprint")
	if last_side_box != null:
		var expected_last_side_height := maxf(stairs.stair_height, 0.05) + maxf(stairs.stair_thickness, 0.0)
		if absf(last_side_box.size.y - expected_last_side_height) > 0.001:
			m_failures.append("Stairs3D final side-wall collision does not follow top step height")
		if absf(last_side_box.size.z - stairs.get_step_run()) > 0.001:
			m_failures.append("Stairs3D final side-wall collision does not follow final step run")

	stairs.set_stair_corners(Vector3(1.0, base_y, 16.5), Vector3(4.5, base_y, 21.0))
	var edited_size := stairs.get_stair_size()
	if absf(edited_size.x - 3.5) > 0.001 or absf(edited_size.y - 4.5) > 0.001:
		m_failures.append("Stairs3D did not resize from edited corners: %s" % str(edited_size))
	if stairs.position.distance_to(Vector3(1.0, base_y, 16.5)) > 0.001:
		m_failures.append("Stairs3D did not move transform after edited corners")
	var old_stair_center := stairs.get_stair_center_point()
	stairs.set_stair_rotation_around_center(90.0)
	if absf(angle_difference(deg_to_rad(stairs.stair_rotation_degrees), deg_to_rad(90.0))) > deg_to_rad(0.5):
		m_failures.append("Stairs3D did not store edited stair rotation")
	if stairs.get_stair_center_point().distance_to(old_stair_center) > 0.001:
		m_failures.append("Stairs3D did not preserve footprint center when rotating")
	if stairs.transform.basis.is_equal_approx(Basis.IDENTITY):
		m_failures.append("Stairs3D did not apply rotation to its transform")


func _has_box_collision_shape(root: Node, path: String) -> bool:
	return _box_collision_shape(root, path) != null


func _box_collision_shape(root: Node, path: String) -> BoxShape3D:
	var collision_shape := _collision_shape(root, path)
	if collision_shape == null:
		return null
	return collision_shape.shape as BoxShape3D


func _collision_shape(root: Node, path: String) -> CollisionShape3D:
	return root.get_node_or_null(path) as CollisionShape3D


func _validate_stairs_side_collision_blocks_character(coordinator: BuildingEditor3DScript) -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "StairsSideCollisionProbeFloor"
	floor_body.set_meta(&"test_generated", true)
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(8.0, 0.1, 8.0)
	floor_shape.shape = floor_box
	floor_shape.position = STAIRS_SIDE_COLLISION_TEST_ORIGIN + Vector3(2.5, -0.05, 0.0)
	floor_body.add_child(floor_shape)
	add_child(floor_body)

	var stairs := coordinator.create_stairs_node(
		STAIRS_SIDE_COLLISION_TEST_ORIGIN + Vector3(2.0, 0.0, -2.0),
		STAIRS_SIDE_COLLISION_TEST_ORIGIN + Vector3(5.0, 0.0, 2.0),
		1.2,
		4,
		0.16,
		Color(0.52, 0.46, 0.38, 1.0)
	)
	coordinator.add_child(stairs)

	var probe := HUMAN_BODY_3D_SCENE.instantiate() as HumanBody3D
	if probe == null:
		m_failures.append("Stairs3D side collision probe could not instantiate HumanBody3D")
		floor_body.queue_free()
		stairs.queue_free()
		return
	probe.name = "StairsSideCollisionHumanBody3DProbe"
	probe.visible = false
	probe.body_radius = 0.28
	probe.body_height = 1.72
	add_child(probe)
	await get_tree().physics_frame

	probe.global_position = STAIRS_SIDE_COLLISION_TEST_ORIGIN + Vector3(0.6, 0.1, 0.0)
	probe.velocity = Vector3.ZERO
	for i in range(8):
		probe.velocity.y = -0.5
		probe.move_with_speed(Vector3.ZERO, 0.0)
		await get_tree().physics_frame

	var start_position := probe.global_position
	var saw_side_collision := false
	for i in range(STAIRS_SIDE_COLLISION_PROBE_FRAMES):
		probe.velocity.y = -0.5
		probe.move_with_speed(Vector3.RIGHT, STAIRS_SIDE_COLLISION_PROBE_SPEED)
		for collision_index in range(probe.get_slide_collision_count()):
			var collision := probe.get_slide_collision(collision_index)
			if absf(collision.get_normal().y) <= STAIRS_SIDE_COLLISION_MAX_NORMAL_Y:
				saw_side_collision = true
		await get_tree().physics_frame

	var side_travel := probe.global_position.x - start_position.x
	var side_climb := probe.global_position.y - start_position.y
	if side_travel > STAIRS_SIDE_COLLISION_MAX_TRAVEL:
		m_failures.append("HumanBody3D moved %.2f units into Stairs3D side wall" % side_travel)
	if side_climb > STAIRS_SIDE_COLLISION_MAX_CLIMB:
		m_failures.append("HumanBody3D climbed %.2f units onto stairs from the side" % side_climb)
	if !saw_side_collision:
		m_failures.append("HumanBody3D did not report side-wall collision against Stairs3D")

	probe.queue_free()

	var climb_probe := HUMAN_BODY_3D_SCENE.instantiate() as HumanBody3D
	if climb_probe == null:
		m_failures.append("Stairs3D front climb probe could not instantiate HumanBody3D")
		floor_body.queue_free()
		stairs.queue_free()
		return
	climb_probe.name = "StairsFrontClimbHumanBody3DProbe"
	climb_probe.visible = false
	climb_probe.body_radius = 0.28
	climb_probe.body_height = 1.72
	add_child(climb_probe)
	await get_tree().physics_frame

	climb_probe.global_position = STAIRS_SIDE_COLLISION_TEST_ORIGIN + Vector3(3.5, 0.1, -2.7)
	climb_probe.velocity = Vector3.ZERO
	for i in range(8):
		climb_probe.velocity.y = -0.5
		climb_probe.move_with_speed(Vector3.ZERO, 0.0)
		await get_tree().physics_frame

	var climb_start_position := climb_probe.global_position
	for i in range(STAIRS_FRONT_CLIMB_PROBE_FRAMES):
		climb_probe.velocity.y = -0.5
		climb_probe.move_with_speed(Vector3.BACK, STAIRS_SIDE_COLLISION_PROBE_SPEED)
		await get_tree().physics_frame

	var front_travel := climb_probe.global_position.z - climb_start_position.z
	var front_climb := climb_probe.global_position.y - climb_start_position.y
	if front_travel < STAIRS_FRONT_CLIMB_MIN_TRAVEL:
		m_failures.append("HumanBody3D only advanced %.2f units up Stairs3D from the front" % front_travel)
	if front_climb < STAIRS_FRONT_CLIMB_MIN_HEIGHT:
		m_failures.append("HumanBody3D only climbed %.2f units up Stairs3D from the front" % front_climb)

	climb_probe.queue_free()

	var exit_probe := HUMAN_BODY_3D_SCENE.instantiate() as HumanBody3D
	if exit_probe == null:
		m_failures.append("Stairs3D side exit probe could not instantiate HumanBody3D")
		floor_body.queue_free()
		stairs.queue_free()
		return
	exit_probe.name = "StairsSideExitHumanBody3DProbe"
	exit_probe.visible = false
	exit_probe.body_radius = 0.28
	exit_probe.body_height = 1.72
	add_child(exit_probe)
	await get_tree().physics_frame

	exit_probe.global_position = STAIRS_SIDE_COLLISION_TEST_ORIGIN + Vector3(3.5, 1.22, 1.5)
	exit_probe.velocity = Vector3.ZERO
	for i in range(10):
		exit_probe.velocity.y = -0.5
		exit_probe.move_with_speed(Vector3.ZERO, 0.0)
		await get_tree().physics_frame

	var exit_start_position := exit_probe.global_position
	exit_probe.jump()
	for i in range(STAIRS_SIDE_EXIT_PROBE_FRAMES):
		exit_probe.move_with_speed(Vector3.LEFT, STAIRS_SIDE_COLLISION_PROBE_SPEED)
		await get_tree().physics_frame

	var side_exit_travel := exit_start_position.x - exit_probe.global_position.x
	if side_exit_travel < STAIRS_SIDE_EXIT_MIN_TRAVEL:
		m_failures.append("HumanBody3D only moved %.2f units when jumping off Stairs3D side" % side_exit_travel)

	exit_probe.queue_free()
	floor_body.queue_free()
	stairs.queue_free()


func _validate_pillar_node(coordinator: BuildingEditor3DScript) -> void:
	var base_y := 0.75
	var pillar := coordinator.create_pillar_node(
		Vector3(6.0, base_y, 12.0),
		0.35,
		2.8,
		6,
		"round",
		Color(0.70, 0.64, 0.52, 1.0)
	)
	coordinator.add_child(pillar)
	if pillar.mesh == null:
		m_failures.append("Pillar3D did not generate a mesh")
		return
	if pillar.mesh.get_surface_count() <= 0:
		m_failures.append("Pillar3D mesh has no surfaces")
		return
	if pillar.position.distance_to(Vector3(6.0, base_y, 12.0)) > 0.001:
		m_failures.append("Pillar3D did not place its transform at the base point")

	var arrays := pillar.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if vertices.size() != pillar.side_count * 10:
		m_failures.append("Pillar3D generated the wrong low-poly vertex count")
	if normals.size() != vertices.size():
		m_failures.append("Pillar3D mesh is missing per-vertex normal data")
	if colors.size() != vertices.size():
		m_failures.append("Pillar3D mesh is missing per-vertex color data")
	if !_has_normal_near(normals, Vector3.UP):
		m_failures.append("Pillar3D mesh is missing top normals")
	if !_has_normal_near(normals, Vector3.DOWN):
		m_failures.append("Pillar3D mesh is missing bottom normals")
	if !_has_horizontal_pillar_normal(normals):
		m_failures.append("Pillar3D mesh is missing side normals")
	if indices.size() >= 3 and !normals.is_empty():
		var a := vertices[indices[0]]
		var b := vertices[indices[1]]
		var c := vertices[indices[2]]
		var winding_normal := (b - a).cross(c - a).normalized()
		if winding_normal.dot(normals[indices[0]]) > -0.999:
			m_failures.append("Pillar3D triangle winding does not match Godot BoxMesh convention")
	if pillar.get_node_or_null("PillarCollision") == null:
		m_failures.append("Pillar3D did not generate collision for placed pillars")

	pillar.set_pillar_base_and_radius(Vector3(7.0, base_y, 13.0), 0.5)
	if pillar.position.distance_to(Vector3(7.0, base_y, 13.0)) > 0.001:
		m_failures.append("Pillar3D did not move transform after edited base point")
	if absf(pillar.pillar_radius - 0.5) > 0.001:
		m_failures.append("Pillar3D did not resize edited radius")

	var square := coordinator.create_pillar_node(
		Vector3(8.0, base_y, 12.0),
		0.4,
		2.4,
		12,
		"square",
		Color(0.70, 0.64, 0.52, 1.0)
	)
	coordinator.add_child(square)
	if square.get_pillar_style() != "square":
		m_failures.append("Pillar3D did not store square style")
	if _mesh_vertex_count(square) != 40:
		m_failures.append("Pillar3D square style did not force four low-poly sides")

	var octagonal := coordinator.create_pillar_node(
		Vector3(9.0, base_y, 12.0),
		0.4,
		2.4,
		5,
		"octagonal",
		Color(0.70, 0.64, 0.52, 1.0)
	)
	coordinator.add_child(octagonal)
	if _mesh_vertex_count(octagonal) != 80:
		m_failures.append("Pillar3D octagonal style did not force eight low-poly sides")

	var tapered := coordinator.create_pillar_node(
		Vector3(10.0, base_y, 12.0),
		0.5,
		2.4,
		8,
		"tapered",
		Color(0.70, 0.64, 0.52, 1.0)
	)
	coordinator.add_child(tapered)
	if _pillar_max_radius_at_y(tapered, 2.4) >= _pillar_max_radius_at_y(tapered, 0.0):
		m_failures.append("Pillar3D tapered style did not narrow the top radius")

	var custom_radii := coordinator.create_pillar_node(
		Vector3(10.5, base_y, 12.0),
		0.45,
		2.4,
		8,
		"round",
		Color(0.70, 0.64, 0.52, 1.0),
		0.0,
		0.0,
		0.0,
		0.0,
		0.18
	)
	coordinator.add_child(custom_radii)
	if absf(custom_radii.upper_radius - 0.18) > 0.001:
		m_failures.append("Pillar3D did not store custom upper radius")
	if _pillar_max_radius_at_y(custom_radii, 2.4) >= _pillar_max_radius_at_y(custom_radii, 0.0):
		m_failures.append("Pillar3D custom upper radius did not narrow the top")
	if absf(_pillar_max_radius_at_y(custom_radii, 2.4) - 0.18) > 0.001:
		m_failures.append("Pillar3D custom upper radius did not generate the requested top radius")

	var rimmed := coordinator.create_pillar_node(
		Vector3(11.0, base_y, 12.0),
		0.35,
		2.4,
		8,
		"round",
		Color(0.70, 0.64, 0.52, 1.0),
		0.16,
		0.08,
		0.20,
		0.10
	)
	coordinator.add_child(rimmed)
	if _mesh_vertex_count(rimmed) != rimmed.side_count * 26:
		m_failures.append("Pillar3D rimmed style did not add expected rim geometry")
	if _pillar_max_radius_at_y(rimmed, 0.0) <= rimmed.pillar_radius:
		m_failures.append("Pillar3D lower rim did not expand the base radius")
	if _pillar_max_radius_at_y(rimmed, 2.4) <= rimmed.pillar_radius:
		m_failures.append("Pillar3D upper rim did not expand the top radius")
	if rimmed.get_outer_radius() <= rimmed.pillar_radius:
		m_failures.append("Pillar3D outer radius did not include rim outsets")
	var rim_collision_shape := rimmed.get_node_or_null("PillarCollision/CollisionShape3D") as CollisionShape3D
	var rim_collision: CylinderShape3D = null
	if rim_collision_shape != null:
		rim_collision = rim_collision_shape.shape as CylinderShape3D
	if rim_collision == null or rim_collision.radius + 0.001 < rimmed.get_outer_radius():
		m_failures.append("Pillar3D rimmed collision did not cover the outer rim")


func _validate_roof_node(coordinator: BuildingEditor3DScript) -> void:
	var base_y := 3.0
	var roof := coordinator.create_roof_node(
		Vector3(12.0, base_y, 12.0),
		Vector3(16.0, base_y, 15.0),
		"gable",
		TEST_ROOF_ANGLE_DEGREES,
		0.16,
		0.25,
		Color(0.50, 0.34, 0.25, 1.0)
	)
	coordinator.add_child(roof)
	if roof.mesh == null:
		m_failures.append("Roof3D did not generate a mesh")
		return
	if roof.mesh.get_surface_count() <= 0:
		m_failures.append("Roof3D mesh has no surfaces")
		return
	if roof.position.distance_to(Vector3(12.0, base_y, 12.0)) > 0.001:
		m_failures.append("Roof3D did not place its transform at the minimum footprint corner")

	var arrays := roof.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if vertices.size() != 48:
		m_failures.append("Roof3D gable style generated the wrong low-poly vertex count")
	if normals.size() != vertices.size():
		m_failures.append("Roof3D mesh is missing per-vertex normal data")
	if colors.size() != vertices.size():
		m_failures.append("Roof3D mesh is missing per-vertex color data")
	if !_has_roof_upward_normal(normals):
		m_failures.append("Roof3D mesh is missing upward roof normals")
	if !_has_roof_downward_normal(normals):
		m_failures.append("Roof3D mesh is missing underside normals")
	if !_roof_underside_normals_are_down(roof):
		m_failures.append("Roof3D underside triangle normals are inverted")
	if !_has_horizontal_pillar_normal(normals):
		m_failures.append("Roof3D mesh is missing fascia normals")
	if indices.size() >= 3 and !normals.is_empty():
		var a := vertices[indices[0]]
		var b := vertices[indices[1]]
		var c := vertices[indices[2]]
		var winding_normal := (b - a).cross(c - a).normalized()
		if winding_normal.dot(normals[indices[0]]) > -0.999:
			m_failures.append("Roof3D triangle winding does not match Godot BoxMesh convention")
	if roof.get_node_or_null("RoofCollision") == null:
		m_failures.append("Roof3D did not generate collision for placed roofs")
	if roof.get_node_or_null(Roof3DScript.TRIANGLE_WIREFRAME_NODE_NAME) != null:
		m_failures.append("Roof3D generated a triangle wireframe when debug was disabled")
	roof.debug_show_triangle_wireframe = true
	roof.rebuild_roof_mesh()
	if !_roof_wireframe_matches_triangle_indices(roof):
		m_failures.append("Roof3D debug triangle wireframe did not match generated triangles")
	roof.debug_show_triangle_wireframe = false
	roof.rebuild_roof_mesh()
	if roof.get_node_or_null(Roof3DScript.TRIANGLE_WIREFRAME_NODE_NAME) != null:
		m_failures.append("Roof3D did not clear debug triangle wireframe when disabled")
	if roof.get_roof_bounds_min().distance_to(Vector3(-0.25, -0.16, -0.25)) > 0.001:
		m_failures.append("Roof3D bounds did not include overhang and thickness")
	var expected_roof_ridge_height := Roof3DScript.gable_height_for_angle_degrees(
		roof.get_roof_size().y,
		roof.roof_overhang,
		roof.get_roof_angle_degrees()
	)
	if roof.get_roof_bounds_max().distance_to(Vector3(4.25, expected_roof_ridge_height, 3.25)) > 0.001:
		m_failures.append("Roof3D bounds did not include overhang and gable ridge height")
	roof.roof_thickness = 0.38
	roof.rebuild_roof_mesh()
	if absf(roof.get_roof_bounds_min().y + 0.38) > 0.001:
		m_failures.append("Roof3D bounds did not react to roof thickness changes")
	if !_has_mesh_vertex_y_near(roof, -0.38, 0.001):
		m_failures.append("Roof3D mesh did not react to roof thickness changes")
	roof.roof_thickness = 0.16
	roof.rebuild_roof_mesh()

	roof.set_roof_corners(Vector3(13.0, base_y, 12.5), Vector3(17.0, base_y, 16.0))
	if roof.position.distance_to(Vector3(13.0, base_y, 12.5)) > 0.001:
		m_failures.append("Roof3D did not move transform after edited corners")
	if roof.get_roof_size().distance_to(Vector2(4.0, 3.5)) > 0.001:
		m_failures.append("Roof3D did not resize edited footprint")
	var old_roof_center := roof.get_roof_center_point()
	roof.set_roof_rotation_around_center(90.0)
	if absf(angle_difference(deg_to_rad(roof.roof_rotation_degrees), deg_to_rad(90.0))) > deg_to_rad(0.5):
		m_failures.append("Roof3D did not store edited roof rotation")
	if roof.get_roof_center_point().distance_to(old_roof_center) > 0.001:
		m_failures.append("Roof3D did not preserve footprint center when rotating")
	if roof.transform.basis.is_equal_approx(Basis.IDENTITY):
		m_failures.append("Roof3D did not apply rotation to its transform")

	var drawn_base_start := Vector3(18.0, base_y, 16.0)
	var drawn_base_end := Vector3(21.0, base_y, 20.0)
	var drawn_base_points := Roof3DScript.roof_corners_from_base_points(
		drawn_base_start,
		drawn_base_end,
		45.0
	)
	var drawn_base_roof := coordinator.create_roof_node(
		Vector3(drawn_base_points["start"]),
		Vector3(drawn_base_points["end"]),
		"gable",
		TEST_ROOF_ANGLE_DEGREES,
		0.12,
		0.2,
		Color(0.50, 0.34, 0.25, 1.0),
		45.0
	)
	coordinator.add_child(drawn_base_roof)
	if !_roof_base_has_corner_near(drawn_base_roof, drawn_base_start):
		m_failures.append("Roof3D rotated draw base did not preserve the first draw point")
	if !_roof_base_has_corner_near(drawn_base_roof, drawn_base_end):
		m_failures.append("Roof3D rotated draw base did not preserve the current draw point")

	var flat := coordinator.create_roof_node(
		Vector3(18.0, base_y, 12.0),
		Vector3(21.0, base_y, 14.0),
		"flat",
		1.0,
		0.14,
		0.0,
		Color(0.50, 0.34, 0.25, 1.0)
	)
	coordinator.add_child(flat)
	if flat.get_roof_style() != "flat":
		m_failures.append("Roof3D did not store flat style")
	if _mesh_vertex_count(flat) != 28:
		m_failures.append("Roof3D flat style generated the wrong vertex count")
	var flat_arrays := flat.mesh.surface_get_arrays(0)
	var flat_normals: PackedVector3Array = flat_arrays[Mesh.ARRAY_NORMAL]
	if !_has_normal_near(flat_normals, Vector3.UP):
		m_failures.append("Roof3D flat style is missing a flat top normal")

	var shed := coordinator.create_roof_node(
		Vector3(22.0, base_y, 12.0),
		Vector3(25.0, base_y, 14.0),
		"shed",
		TEST_ROOF_ALT_ANGLE_DEGREES,
		0.12,
		0.1,
		Color(0.50, 0.34, 0.25, 1.0)
	)
	coordinator.add_child(shed)
	if _mesh_vertex_count(shed) != 28:
		m_failures.append("Roof3D shed style generated the wrong vertex count")
	if !_has_roof_sloped_normal(shed):
		m_failures.append("Roof3D shed style is missing sloped roof normals")
	var expected_shed_height := Roof3DScript.shed_height_for_angle_degrees(
		shed.get_roof_size().y,
		shed.roof_overhang,
		shed.get_roof_angle_degrees()
	)
	if !_has_mesh_vertex_y_near(shed, expected_shed_height, 0.001):
		m_failures.append("Roof3D shed style did not calculate height from angle degrees")

	var hip := coordinator.create_roof_node(
		Vector3(26.0, base_y, 12.0),
		Vector3(31.0, base_y, 15.0),
		"hip",
		TEST_ROOF_ALT_ANGLE_DEGREES,
		0.12,
		0.15,
		Color(0.50, 0.34, 0.25, 1.0)
	)
	coordinator.add_child(hip)
	if _mesh_vertex_count(hip) != 52:
		m_failures.append("Roof3D hip style generated the wrong vertex count")
	if !_has_roof_sloped_normal(hip):
		m_failures.append("Roof3D hip style is missing sloped roof normals")
	var expected_hip_height := Roof3DScript.hip_height_for_angle_degrees(
		hip.get_roof_size(),
		hip.roof_overhang,
		hip.get_roof_angle_degrees()
	)
	if !_has_mesh_vertex_y_near(hip, expected_hip_height, 0.001):
		m_failures.append("Roof3D hip style did not calculate height from angle degrees")
	var hip_ridge_points := Roof3DScript.hip_roof_ridge_points_for_size(
		hip.get_roof_size(),
		hip.roof_overhang,
		hip.get_roof_angle_degrees()
	)
	if hip_ridge_points.size() != 2:
		m_failures.append("Roof3D hip style did not report a ridge line")
	else:
		if absf(hip_ridge_points[0].y - hip_ridge_points[1].y) > 0.001:
			m_failures.append("Roof3D hip ridge is not horizontal")
		if hip_ridge_points[0].distance_to(hip_ridge_points[1]) <= 0.001:
			m_failures.append("Roof3D rectangular hip roof collapsed to one apex")
		if !_has_mesh_vertex_near(hip.mesh as ArrayMesh, hip_ridge_points[0], 0.001):
			m_failures.append("Roof3D hip mesh is missing the first ridge endpoint")
		if !_has_mesh_vertex_near(hip.mesh as ArrayMesh, hip_ridge_points[1], 0.001):
			m_failures.append("Roof3D hip mesh is missing the second ridge endpoint")
	var hip_faces := Roof3DScript.roof_top_faces_for_style(
		"hip",
		hip.get_roof_size(),
		hip.roof_overhang,
		hip.get_roof_angle_degrees()
	)
	var triangular_hip_faces := 0
	var trapezoid_hip_faces := 0
	for hip_face in hip_faces:
		var hip_face_vertices := PackedVector3Array(hip_face["vertices"])
		if hip_face_vertices.size() == 3:
			triangular_hip_faces += 1
		elif hip_face_vertices.size() == 4:
			trapezoid_hip_faces += 1
		var hip_face_angle := _roof_face_angle_degrees(PackedVector3Array(hip_face["plane"]))
		if absf(hip_face_angle - TEST_ROOF_ALT_ANGLE_DEGREES) > 0.01:
			m_failures.append("Roof3D hip face angle changed from configured degrees")
	if triangular_hip_faces != 2 or trapezoid_hip_faces != 2:
		m_failures.append("Roof3D hip style did not generate two triangular and two trapezoid faces")

	var half_hip := coordinator.create_roof_node(
		Vector3(46.0, base_y, 12.0),
		Vector3(51.0, base_y, 15.0),
		"hip",
		TEST_ROOF_ALT_ANGLE_DEGREES,
		0.12,
		0.15,
		Color(0.50, 0.34, 0.25, 1.0),
		0.0,
		false,
		0.4
	)
	coordinator.add_child(half_hip)
	if _mesh_vertex_count(half_hip) != 100:
		m_failures.append("Roof3D half-hip style generated the wrong vertex count")
	if !_roof_surface_normals_are_not_down(half_hip):
		m_failures.append("Roof3D half-hip visible surface normals point downward")
	var plain_half_hip_ridge := Roof3DScript.hip_roof_ridge_points_for_size(
		half_hip.get_roof_size(),
		half_hip.roof_overhang,
		half_hip.get_roof_angle_degrees()
	)
	var clipped_half_hip_ridge := Roof3DScript.hip_roof_ridge_points_for_size(
		half_hip.get_roof_size(),
		half_hip.roof_overhang,
		half_hip.get_roof_angle_degrees(),
		half_hip.hip_gable_height
	)
	if clipped_half_hip_ridge.size() != 2:
		m_failures.append("Roof3D half-hip style did not report a ridge line")
	else:
		if clipped_half_hip_ridge[0].x >= plain_half_hip_ridge[0].x:
			m_failures.append("Roof3D half-hip did not extend the ridge start")
		if clipped_half_hip_ridge[1].x <= plain_half_hip_ridge[1].x:
			m_failures.append("Roof3D half-hip did not extend the ridge end")
		if !_has_mesh_vertex_near(half_hip.mesh as ArrayMesh, clipped_half_hip_ridge[0], 0.001):
			m_failures.append("Roof3D half-hip mesh is missing the first extended ridge endpoint")
		if !_has_mesh_vertex_near(half_hip.mesh as ArrayMesh, clipped_half_hip_ridge[1], 0.001):
			m_failures.append("Roof3D half-hip mesh is missing the second extended ridge endpoint")
	var half_hip_height := Roof3DScript.hip_height_for_angle_degrees(
		half_hip.get_roof_size(),
		half_hip.roof_overhang,
		half_hip.get_roof_angle_degrees()
	)
	var half_hip_extension := half_hip.hip_gable_height / tan(deg_to_rad(half_hip.get_roof_angle_degrees()))
	var half_hip_center_z := half_hip.get_roof_size().y * 0.5
	var half_hip_gable_base := Vector3(
		clipped_half_hip_ridge[0].x,
		half_hip_height - half_hip.hip_gable_height,
		half_hip_center_z - half_hip_extension
	)
	if !_has_mesh_vertex_near(half_hip.mesh as ArrayMesh, half_hip_gable_base, 0.001):
		m_failures.append("Roof3D half-hip mesh is missing the clipped gable base")
	if absf(half_hip.get_roof_height_at_local_render_point(Vector2(clipped_half_hip_ridge[0].x, half_hip_center_z)) - half_hip_height) > 0.001:
		m_failures.append("Roof3D half-hip ridge height changed from the hip peak")
	if absf(half_hip.get_roof_height_at_local_render_point(Vector2(half_hip_gable_base.x, half_hip_gable_base.z)) - half_hip_gable_base.y) > 0.001:
		m_failures.append("Roof3D half-hip clipped gable base does not follow configured drop")
	var half_hip_faces := Roof3DScript.roof_top_faces_for_style(
		"hip",
		half_hip.get_roof_size(),
		half_hip.roof_overhang,
		half_hip.get_roof_angle_degrees(),
		half_hip.hip_gable_height
	)
	var half_hip_sloped_faces := 0
	var half_hip_vertical_faces := 0
	for half_hip_face in half_hip_faces:
		var half_hip_face_angle := _roof_face_angle_degrees(PackedVector3Array(half_hip_face["plane"]))
		if half_hip_face_angle > 89.0:
			half_hip_vertical_faces += 1
		else:
			half_hip_sloped_faces += 1
			if absf(half_hip_face_angle - TEST_ROOF_ALT_ANGLE_DEGREES) > 0.01:
				m_failures.append("Roof3D half-hip sloped face angle changed from configured degrees")
	if half_hip_sloped_faces != 4 or half_hip_vertical_faces != 2:
		m_failures.append("Roof3D half-hip did not generate four sloped faces and two clipped gables")

	var angle_roof := coordinator.create_roof_node(
		Vector3(40.0, base_y, 16.0),
		Vector3(44.0, base_y, 19.0),
		"gable",
		TEST_ROOF_ANGLE_DEGREES,
		0.12,
		0.25,
		Color(0.50, 0.34, 0.25, 1.0)
	)
	coordinator.add_child(angle_roof)
	var original_angle_degrees := angle_roof.get_roof_angle_degrees()
	var preserved_angle_covers: Array[Rect2] = []
	angle_roof.set_roof_corners_rotation_height_and_covers(
		angle_roof.start_point,
		angle_roof.start_point + Vector3(4.0, 0.0, 6.0),
		angle_roof.roof_rotation_degrees,
		angle_roof.roof_height,
		preserved_angle_covers
	)
	var expected_resized_ridge_height := Roof3DScript.gable_height_for_angle_degrees(
		angle_roof.get_roof_size().y,
		angle_roof.roof_overhang,
		original_angle_degrees
	)
	if absf(angle_roof.get_roof_angle_degrees() - original_angle_degrees) > 0.001:
		m_failures.append("Roof3D gable angle changed after depth-preserving resize")
	if !is_equal_approx(angle_roof.roof_height, original_angle_degrees):
		m_failures.append("Roof3D did not keep the stored gable angle")
	if !_has_mesh_vertex_y_near(angle_roof, expected_resized_ridge_height, 0.001):
		m_failures.append("Roof3D did not recalculate gable ridge height from angle degrees")

	var merge_color := Color(0.42, 0.30, 0.22, 1.0)
	var merge_target := coordinator.create_roof_node(
		Vector3(30.0, base_y, 12.0),
		Vector3(34.0, base_y, 15.0),
		"gable",
		TEST_ROOF_ANGLE_DEGREES,
		0.16,
		0.25,
		merge_color
	)
	coordinator.add_child(merge_target)
	var merge_candidate_start := Vector3(33.0, base_y, 13.0)
	var merge_candidate_end := Vector3(36.0, base_y, 17.0)
	var merge := coordinator.find_roof_merge_target(
		merge_candidate_start,
		merge_candidate_end,
		"gable",
		TEST_ROOF_ANGLE_DEGREES,
		0.16,
		0.25,
		merge_color,
		0.0
	)
	if merge.is_empty():
		m_failures.append("Roof3D did not detect an intersecting roof merge target")
	else:
		var covered_rects: Array[Rect2] = []
		for rect in merge["covered_rects"]:
			covered_rects.append(rect)
		var typed_covered_polygons: Array[PackedVector2Array] = []
		for polygon in merge["covered_polygons"]:
			typed_covered_polygons.append(PackedVector2Array(polygon))
		var covered_polygons: Array = merge["covered_polygons"]
		var expected_overlap := Rect2(Vector2(-0.25, -0.25), Vector2(1.5, 2.5))
		var covered_overlap_area := _covered_polygon_area(covered_polygons)
		if covered_overlap_area <= 0.001:
			m_failures.append("Roof3D merge cover did not include any expected under-roof area")
		if covered_overlap_area >= expected_overlap.get_area() - 0.001:
			m_failures.append("Roof3D merge cover removed the whole overlap instead of only the under-roof area")
		if covered_polygons.is_empty():
			m_failures.append("Roof3D merge cover did not report polygon regions")
		if covered_polygons.size() > 8 or _polygon_vertex_count(covered_polygons) > 48:
			m_failures.append(
				"Roof3D merge cover created too many small polygon pieces: %d polygons, %d vertices"
				% [covered_polygons.size(), _polygon_vertex_count(covered_polygons)]
			)
		if !_cover_polygons_sample_under_other_roof(
			covered_polygons,
			merge_candidate_start,
			merge_candidate_end,
			"gable",
			TEST_ROOF_ANGLE_DEGREES,
			0.25,
			0.0,
			coordinator.get_roof_nodes()
		):
			m_failures.append("Roof3D merge cover removed sampled roof surface above another roof")
		var clipped_merge_roof := coordinator.create_roof_node(
			merge_candidate_start,
			merge_candidate_end,
			"gable",
			TEST_ROOF_ANGLE_DEGREES,
			0.42,
			0.25,
			merge_color
		)
		clipped_merge_roof.set_covered_regions(covered_rects, typed_covered_polygons)
		if !_has_internal_roof_fascia_facing_cover(clipped_merge_roof, typed_covered_polygons):
			m_failures.append("Roof3D clipped roof intersection-cut normals point the wrong way")
		if !_roof_underside_normals_are_down(clipped_merge_roof):
			m_failures.append("Roof3D clipped roof underside normals are inverted")
		if !_has_mesh_vertex_y_near(clipped_merge_roof, -0.42, 0.001):
			m_failures.append("Roof3D clipped roof mesh did not use configured thickness")
		clipped_merge_roof.free()

	var angle_merge := coordinator.find_roof_merge_target(
		Vector3(33.0, base_y, 13.0),
		Vector3(36.0, base_y, 17.0),
		"gable",
		merge_target.get_roof_angle_degrees(),
		0.16,
		0.25,
		merge_color,
		0.0
	)
	if angle_merge.is_empty():
		m_failures.append("Roof3D did not clip gables with matching angle")
	var angle_mismatch := coordinator.find_roof_merge_target(
		Vector3(33.0, base_y, 13.0),
		Vector3(36.0, base_y, 17.0),
		"gable",
		TEST_ROOF_ALT_ANGLE_DEGREES,
		0.16,
		0.25,
		merge_color,
		0.0
	)
	if angle_mismatch.is_empty():
		m_failures.append("Roof3D did not clip gables with different angles")

	var clipped := coordinator.create_roof_node(
		Vector3(37.0, base_y, 12.0),
		Vector3(40.0, base_y, 15.0),
		"flat",
		0.0,
		0.12,
		0.0,
		merge_color
	)
	var clipped_covers: Array[Rect2] = [Rect2(Vector2(1.0, 1.0), Vector2(1.0, 1.0))]
	clipped.set_covered_rects(clipped_covers)
	coordinator.add_child(clipped)
	if clipped.get_covered_rects().size() != 1:
		m_failures.append("Roof3D did not store covered roof footprint areas")
	if clipped.get_visible_footprint_rects().size() != 4:
		m_failures.append("Roof3D did not report the visible clipped footprint pieces")
	if _mesh_vertex_count(clipped) <= 28:
		m_failures.append("Roof3D did not split clipped roof geometry into visible pieces")

	var clipped_gable := coordinator.create_roof_node(
		Vector3(37.0, base_y, 16.0),
		Vector3(41.0, base_y, 20.0),
		"gable",
		TEST_ROOF_ANGLE_DEGREES,
		0.12,
		0.2,
		merge_color
	)
	var clipped_gable_covers: Array[Rect2] = [Rect2(Vector2.ZERO, Vector2(1.0, 1.0))]
	clipped_gable.set_covered_rects(clipped_gable_covers)
	coordinator.add_child(clipped_gable)
	if !_has_roof_sloped_normal(clipped_gable):
		m_failures.append("Roof3D clipped gable lost its sloped roof normals")
	var clipped_gable_ridge_height := Roof3DScript.gable_height_for_angle_degrees(
		clipped_gable.get_roof_size().y,
		clipped_gable.roof_overhang,
		clipped_gable.get_roof_angle_degrees()
	)
	if !_has_mesh_vertex_y_near(clipped_gable, clipped_gable_ridge_height, 0.001):
		m_failures.append("Roof3D clipped gable lost its ridge-height vertices")

	var mismatch := coordinator.find_roof_merge_target(
		Vector3(33.0, base_y, 14.0),
		Vector3(36.0, base_y, 17.0),
		"hip",
		TEST_ROOF_ANGLE_DEGREES,
		0.16,
		0.25,
		merge_color,
		0.0
	)
	if mismatch.is_empty():
		m_failures.append("Roof3D did not clip roofs with different styles")
	var rotation_mismatch := coordinator.find_roof_merge_target(
		Vector3(33.0, base_y, 14.0),
		Vector3(36.0, base_y, 17.0),
		"gable",
		TEST_ROOF_ANGLE_DEGREES,
		0.16,
		0.25,
		merge_color,
		90.0
	)
	if rotation_mismatch.is_empty():
		m_failures.append("Roof3D did not clip roofs with different rotations")
	else:
		var rotation_polygons: Array = rotation_mismatch["covered_polygons"]
		if rotation_polygons.is_empty():
			m_failures.append("Roof3D rotated intersection did not report polygon cover regions")
		if !_cover_polygons_have_non_axis_edge(rotation_polygons):
			m_failures.append("Roof3D rotated intersection kept a zigzag axis-aligned cover edge")
		if rotation_polygons.size() > 8 or _polygon_vertex_count(rotation_polygons) > 48:
			m_failures.append(
				"Roof3D rotated intersection created too many small polygon pieces: %d polygons, %d vertices"
				% [rotation_polygons.size(), _polygon_vertex_count(rotation_polygons)]
			)
	var near_rotation_mismatch := coordinator.find_roof_merge_target(
		Vector3(33.0, base_y, 14.0),
		Vector3(36.0, base_y, 17.0),
		"gable",
		TEST_ROOF_ANGLE_DEGREES,
		0.16,
		0.25,
		merge_color,
		0.25
	)
	if near_rotation_mismatch.is_empty():
		m_failures.append("Roof3D did not clip roofs with near-but-not-equal rotations")

	var rotated_merge_target := coordinator.create_roof_node(
		Vector3(40.0, base_y, 12.0),
		Vector3(44.0, base_y, 15.0),
		"gable",
		TEST_ROOF_ANGLE_DEGREES,
		0.16,
		0.25,
		merge_color,
		90.0
	)
	coordinator.add_child(rotated_merge_target)
	var rotated_basis := Basis(Vector3.UP, deg_to_rad(90.0))
	var rotated_new_start := rotated_merge_target.get_roof_anchor_point() + rotated_basis * Vector3(1.0, 0.0, 1.0)
	var rotated_merge := coordinator.find_roof_merge_target(
		rotated_new_start,
		rotated_new_start + Vector3(4.0, 0.0, 3.0),
		"gable",
		TEST_ROOF_ANGLE_DEGREES,
		0.16,
		0.25,
		merge_color,
		90.0
	)
	if rotated_merge.is_empty():
		m_failures.append("Roof3D did not detect an intersecting rotated roof merge target")
	else:
		if rotated_merge["roof"] != rotated_merge_target:
			m_failures.append("Roof3D rotated merge target selected the wrong roof")
		if absf(angle_difference(deg_to_rad(float(rotated_merge["rotation_degrees"])), deg_to_rad(90.0))) > deg_to_rad(0.5):
			m_failures.append("Roof3D rotated merge did not preserve roof rotation")
		var rotated_covers: Array = rotated_merge["covered_rects"]
		if rotated_covers.is_empty():
			m_failures.append("Roof3D rotated merge did not report covered roof geometry")

	var full_cover_target := coordinator.create_roof_node(
		Vector3(50.0, base_y, 20.0),
		Vector3(54.0, base_y, 24.0),
		"flat",
		0.0,
		0.12,
		0.2,
		merge_color
	)
	coordinator.add_child(full_cover_target)
	var full_cover := coordinator.find_roof_merge_target(
		Vector3(50.0, base_y, 20.0),
		Vector3(54.0, base_y, 24.0),
		"flat",
		0.0,
		0.12,
		0.2,
		merge_color,
		0.0
	)
	if full_cover.is_empty():
		m_failures.append("Roof3D did not detect fully covered matching roof geometry")
	else:
		var full_cover_rects: Array[Rect2] = []
		var full_cover_polygons: Array[PackedVector2Array] = []
		var full_cover_values: Array = full_cover["covered_rects"]
		for rect in full_cover_values:
			full_cover_rects.append(rect)
		var full_cover_polygon_values: Array = full_cover["covered_polygons"]
		for polygon in full_cover_polygon_values:
			full_cover_polygons.append(PackedVector2Array(polygon))
		if coordinator.roof_has_visible_cover_area(
			Vector3(50.0, base_y, 20.0),
			Vector3(54.0, base_y, 24.0),
			0.2,
			full_cover_rects,
			full_cover_polygons
		):
			m_failures.append("Roof3D treated fully covered roof geometry as visible")
		var duplicate_full_cover := coordinator.create_roof_node(
			Vector3(50.0, base_y, 20.0),
			Vector3(54.0, base_y, 24.0),
			"flat",
			0.0,
			0.12,
			0.2,
			merge_color
		)
		duplicate_full_cover.set_covered_regions(full_cover_rects, full_cover_polygons)
		if duplicate_full_cover.has_visible_roof_geometry():
			m_failures.append("Roof3D generated visible mesh for a fully covered roof")
		duplicate_full_cover.free()

	var touch_target := coordinator.create_roof_node(
		Vector3(50.0, base_y, 12.0),
		Vector3(54.0, base_y, 15.0),
		"gable",
		TEST_ROOF_ANGLE_DEGREES,
		0.16,
		0.25,
		merge_color
	)
	coordinator.add_child(touch_target)
	var touch_merge := coordinator.find_roof_merge_target(
		Vector3(54.0, base_y, 12.0),
		Vector3(58.0, base_y, 15.0),
		"gable",
		TEST_ROOF_ANGLE_DEGREES,
		0.16,
		0.25,
		merge_color,
		0.0
	)
	if touch_merge.is_empty():
		m_failures.append("Roof3D did not merge touching roof overhang geometry")
	else:
		var touch_values: Array = touch_merge["covered_rects"]
		var touch_cover: Rect2 = touch_values[0]
		if absf(touch_cover.position.x + 0.25) > 0.001 or absf(touch_cover.size.x - 0.5) > 0.001:
			m_failures.append("Roof3D touching overhang cover has the wrong X range")

	var gap_merge := coordinator.find_roof_merge_target(
		Vector3(54.3, base_y, 12.0),
		Vector3(58.3, base_y, 15.0),
		"gable",
		TEST_ROOF_ANGLE_DEGREES,
		0.16,
		0.25,
		merge_color,
		0.0
	)
	if gap_merge.is_empty():
		m_failures.append("Roof3D did not merge separated but overlapping roof overhang geometry")
	else:
		var gap_values: Array = gap_merge["covered_rects"]
		var gap_cover: Rect2 = gap_values[0]
		if absf(gap_cover.position.x + 0.25) > 0.001 or absf(gap_cover.size.x - 0.2) > 0.001:
			m_failures.append("Roof3D separated overhang cover has the wrong X range")

	var stale_covering := coordinator.create_roof_node(
		Vector3(60.0, base_y, 12.0),
		Vector3(64.0, base_y, 15.0),
		"gable",
		TEST_ROOF_ANGLE_DEGREES,
		0.16,
		0.25,
		merge_color
	)
	coordinator.add_child(stale_covering)
	var stale_clipped := coordinator.create_roof_node(
		Vector3(63.0, base_y, 14.0),
		Vector3(66.0, base_y, 17.0),
		"gable",
		TEST_ROOF_ANGLE_DEGREES,
		0.16,
		0.25,
		merge_color
	)
	var stale_cover_regions := coordinator.compute_roof_cover_regions(
		stale_clipped.start_point,
		stale_clipped.end_point,
		stale_clipped.get_roof_style(),
		stale_clipped.roof_height,
		stale_clipped.roof_thickness,
		stale_clipped.roof_overhang,
		stale_clipped.roof_color,
		stale_clipped.roof_rotation_degrees
	)
	var stale_rects: Array[Rect2] = []
	for rect in stale_cover_regions.get("covered_rects", []):
		stale_rects.append(rect)
	var stale_polygons: Array[PackedVector2Array] = []
	for polygon in stale_cover_regions.get("covered_polygons", []):
		stale_polygons.append(PackedVector2Array(polygon))
	stale_clipped.set_covered_regions(stale_rects, stale_polygons)
	coordinator.add_child(stale_clipped)
	if stale_clipped.get_covered_rects().is_empty():
		m_failures.append("Roof3D stale-cover setup did not create an initial clip")
	stale_covering.set_roof_corners(Vector3(70.0, base_y, 12.0), Vector3(74.0, base_y, 15.0))
	coordinator.refresh_roof_covered_rects()
	if !stale_clipped.get_covered_rects().is_empty():
		m_failures.append("Roof3D did not clear stale roof covers after refresh")


func _validate_merge_detection(coordinator: BuildingEditor3DScript) -> void:
	var merge: Dictionary = coordinator.find_merge_target(Vector3(2.0, 0.0, 0.0), Vector3(6.0, 0.0, 0.0), 0.22, 2.4)
	if merge.is_empty():
		m_failures.append("BuildingEditor3D did not find an overlapping collinear merge target")
		return
	var merged_end := Vector3(merge["end"])
	if merged_end.distance_to(Vector3(6.0, 0.0, 0.0)) > 0.001:
		m_failures.append("BuildingEditor3D merge target did not extend to the outer end point")

	var height_mismatch: Dictionary = coordinator.find_merge_target(
		Vector3(2.0, 0.0, 0.0),
		Vector3(6.0, 0.0, 0.0),
		0.22,
		3.0
	)
	if !height_mismatch.is_empty():
		m_failures.append("BuildingEditor3D merged walls with mismatched heights")

	var base_mismatch: Dictionary = coordinator.find_merge_target(
		Vector3(2.0, 1.25, 0.0),
		Vector3(6.0, 1.25, 0.0),
		0.22,
		2.4
	)
	if !base_mismatch.is_empty():
		m_failures.append("BuildingEditor3D merged walls with mismatched base heights")

	var preview := coordinator.create_wall_node(
		Vector3(8.0, 0.0, 0.0),
		Vector3(10.0, 0.0, 0.0),
		2.4,
		0.22,
		Color.WHITE
	)
	preview.name = "WallPreview"
	coordinator.add_child(preview)
	var ignored_merge: Dictionary = coordinator.find_merge_target(
		Vector3(8.0, 0.0, 0.0),
		Vector3(10.0, 0.0, 0.0),
		0.22,
		2.4,
		preview
	)
	coordinator.remove_child(preview)
	preview.queue_free()
	if !ignored_merge.is_empty():
		m_failures.append("BuildingEditor3D treated the active wall preview as a merge target")


func _validate_intersection_merge() -> void:
	var coordinator := BuildingEditor3DScript.new() as BuildingEditor3DScript
	coordinator.name = "MergeCoordinator"
	coordinator.position = Vector3(0.0, 0.0, 40.0)
	add_child(coordinator)
	coordinator.grid_step = 0.5

	var wall_color := Color(0.78, 0.68, 0.54, 1.0)
	var survivor := coordinator.create_wall_node(
		Vector3(-2.0, 0.0, 0.0), Vector3(2.0, 0.0, 0.0), 2.4, 0.22, wall_color
	)
	coordinator.add_child(survivor)

	var crossing_hits: Array = coordinator.find_intersecting_walls(
		Vector3(0.0, 0.0, -2.0), Vector3(0.0, 0.0, 2.0), 0.22
	)
	if crossing_hits.size() != 1 or crossing_hits[0] != survivor:
		m_failures.append("BuildingEditor3D did not detect a crossing wall span as intersecting")
	var far_hits: Array = coordinator.find_intersecting_walls(
		Vector3(10.0, 0.0, 0.0), Vector3(14.0, 0.0, 0.0), 0.22
	)
	if !far_hits.is_empty():
		m_failures.append("BuildingEditor3D flagged a distant wall span as intersecting")

	var crossing := WallSegment3DScript.new()
	crossing.start_point = Vector3(0.0, 0.0, -2.0)
	crossing.end_point = Vector3(0.0, 0.0, 2.0)
	crossing.thickness = 0.22
	crossing.height = 2.4
	crossing.color = wall_color
	var split_source: Array[WallSegment3DScript] = [survivor.get_segment(0), crossing]
	var split_segments := WallSegment3DScript.split_at_intersections(split_source, 0.125)
	if split_segments.size() != 4:
		m_failures.append("WallSegment3D did not split a crossing into four editable spans")
	if _endpoint_count(split_segments, Vector3.ZERO) != 4:
		m_failures.append("WallSegment3D did not create shared endpoints at the crossing point")
	if _endpoint_count_for_axis(split_segments, Vector3.ZERO, Vector2.RIGHT) != 2:
		m_failures.append("WallSegment3D did not add endpoints to the intersected horizontal segment")
	if _endpoint_count_for_axis(split_segments, Vector3.ZERO, Vector2.DOWN) != 2:
		m_failures.append("WallSegment3D did not add endpoints to the crossing vertical segment")
	var split_primary := split_segments[0]
	var split_extras: Array[WallSegment3DScript] = []
	for split_index in range(1, split_segments.size()):
		split_extras.append(split_segments[split_index])
	survivor.set_wall_endpoints(split_primary.start_point, split_primary.end_point)
	survivor.extra_segments = split_extras
	survivor.rebuild_wall_mesh()

	if survivor.get_segment_count() != 4:
		m_failures.append("Wall3D did not keep the split absorbed crossing segments")
	if survivor.mesh == null or survivor.mesh.get_surface_count() <= 0:
		m_failures.append("Multi-segment Wall3D did not generate a merged mesh")
		return
	if survivor.get_node_or_null("WallCollision") == null:
		m_failures.append("Multi-segment Wall3D did not generate collision")

	var top_area := _up_facing_area(survivor.mesh as ArrayMesh, 2.4)
	var expected_area := 4.0 * 0.22 + 4.0 * 0.22 - 0.22 * 0.22
	if absf(top_area - expected_area) > 0.05:
		m_failures.append(
			"Merged wall top cap area %.4f deviates from expected %.4f" % [top_area, expected_area]
		)

	var collinear_segments: Array[WallSegment3DScript] = []
	var span_a := WallSegment3DScript.new()
	span_a.start_point = Vector3.ZERO
	span_a.end_point = Vector3(4.0, 0.0, 0.0)
	collinear_segments.append(span_a)
	var span_b := WallSegment3DScript.new()
	span_b.start_point = Vector3(2.0, 0.0, 0.0)
	span_b.end_point = Vector3(6.0, 0.0, 0.0)
	WallSegment3DScript.merge_into(collinear_segments, span_b, 0.125)
	if collinear_segments.size() != 1:
		m_failures.append("WallSegment3D.merge_into did not extend a collinear overlapping span")
	elif collinear_segments[0].end_point.distance_to(Vector3(6.0, 0.0, 0.0)) > 0.001:
		m_failures.append("WallSegment3D.merge_into did not extend to the outer end point")

	var opening_frame: Transform3D = survivor.get_segment_local_frame(1)
	var opening := BuildingOpening3DScript.new() as BuildingOpening3DScript
	opening.name = "MergedSegmentOpening"
	opening.opening_width = 1.0
	opening.opening_height = 1.0
	opening.position = opening_frame * Vector3(1.0, 1.1, 0.145)
	survivor.add_child(opening)
	survivor.rebuild_wall_mesh()

	if survivor.can_place_opening(Vector2(1.0, 1.1), Vector2(0.8, 0.8), 0.03, null, 1):
		m_failures.append("Multi-segment wall allowed an overlapping opening on an extra segment")
	if !survivor.can_place_opening(Vector2(1.8, 1.1), Vector2(0.25, 0.8), 0.03, null, 1):
		m_failures.append("Multi-segment wall rejected a valid opening on an extra segment")

	# Openings sitting on the primary span's face near the junction must stay
	# assigned to the primary span, not the crossing segment whose centerline
	# they happen to be close to (wall-local junction is at x = 2).
	var junction_opening := BuildingOpening3DScript.new() as BuildingOpening3DScript
	junction_opening.name = "JunctionOpening"
	junction_opening.opening_width = 0.6
	junction_opening.opening_height = 0.6
	junction_opening.position = Vector3(2.05, 1.1, 0.145)
	survivor.add_child(junction_opening)
	if survivor.get_opening_segment_index(junction_opening) != 0:
		m_failures.append("Opening near a junction was assigned to the crossing segment")
	survivor.remove_child(junction_opening)
	junction_opening.free()

	# A window straddling the junction would be blocked by the crossing
	# segment's solid mass, so placement must be rejected.
	if survivor.can_place_opening(Vector2(2.0, 1.1), Vector2(0.8, 0.8), 0.03, null, 0):
		m_failures.append("Opening straddling a junction was not rejected")
	if !survivor.can_place_opening(Vector2(0.8, 1.1), Vector2(0.6, 0.8), 0.03, null, 0):
		m_failures.append("Valid primary-span opening away from the junction was rejected")


func _validate_wall_instance_intersection_clipping() -> void:
	var coordinator := BuildingEditor3DScript.new() as BuildingEditor3DScript
	coordinator.name = "WallClipCoordinator"
	coordinator.position = Vector3(0.0, 0.0, 48.0)
	add_child(coordinator)
	coordinator.grid_step = 0.5

	var wall_color := Color(0.78, 0.68, 0.54, 1.0)
	var horizontal := coordinator.create_wall_node(
		Vector3(-2.0, 0.0, 0.0), Vector3(2.0, 0.0, 0.0), 2.4, 0.22, wall_color
	)
	coordinator.add_child(horizontal)
	var vertical := coordinator.create_wall_node(
		Vector3(0.0, 0.0, -2.0), Vector3(0.0, 0.0, 2.0), 2.4, 0.22, wall_color
	)
	coordinator.add_child(vertical)
	coordinator.refresh_wall_intersection_clips()

	if horizontal.get_parent() != coordinator or vertical.get_parent() != coordinator:
		m_failures.append("Intersecting wall clipping removed a wall instance")
	if horizontal.get_segment_count() != 1 or vertical.get_segment_count() != 1:
		m_failures.append("Intersecting wall clipping absorbed segments into a wall instance")
	if horizontal.get_intersection_clip_segment_count() != 1:
		m_failures.append("Horizontal wall did not receive the crossing wall as geometry-only clip data")
	if vertical.get_intersection_clip_segment_count() != 1:
		m_failures.append("Vertical wall did not receive the crossing wall as geometry-only clip data")
	if horizontal.mesh == null or vertical.mesh == null:
		m_failures.append("Geometry-only intersecting wall clipping did not generate both meshes")
		return

	var total_top_area := (
		_up_facing_area(horizontal.mesh as ArrayMesh, horizontal.wall_height)
		+ _up_facing_area(vertical.mesh as ArrayMesh, vertical.wall_height)
	)
	var expected_top_area := 4.0 * 0.22 + 4.0 * 0.22 - 0.22 * 0.22
	if absf(total_top_area - expected_top_area) > 0.02:
		m_failures.append(
			"Separate intersecting wall top caps %.4f deviate from clipped expected %.4f"
			% [total_top_area, expected_top_area]
		)
	if horizontal.can_place_opening(Vector2(2.0, 1.1), Vector2(0.4, 0.6), 0.03, null, 0):
		m_failures.append("Separate intersecting wall allowed an opening through sibling wall geometry")
	if !horizontal.can_place_opening(Vector2(0.6, 1.1), Vector2(0.3, 0.6), 0.03, null, 0):
		m_failures.append("Separate intersecting wall rejected an opening away from sibling geometry")


func _validate_roof_wall_clipping() -> void:
	var coordinator := BuildingEditor3DScript.new() as BuildingEditor3DScript
	coordinator.name = "RoofWallClipCoordinator"
	coordinator.position = Vector3(0.0, 0.0, 56.0)
	add_child(coordinator)

	var wall_color := Color(0.78, 0.68, 0.54, 1.0)
	var wall := coordinator.create_wall_node(
		Vector3(0.0, 0.0, 0.2),
		Vector3(4.0, 0.0, 0.2),
		4.0,
		0.22,
		wall_color
	)
	coordinator.add_child(wall)
	var roof := coordinator.create_roof_node(
		Vector3(0.0, 2.4, 0.0),
		Vector3(4.0, 2.4, 4.0),
		"gable",
		45.0,
		0.20,
		0.0,
		Color(0.50, 0.34, 0.25, 1.0)
	)
	coordinator.add_child(roof)
	coordinator.refresh_building_geometry_clips()

	if wall.get_roof_clip_surface_count() != 1:
		m_failures.append("Wall3D did not receive roof underside clip data")
	if _wall_has_vertex_above_roof_underside(wall, roof, 0.025):
		m_failures.append("Wall3D kept geometry above the intersecting roof underside")
	if wall.get_node_or_null("WallCollision") == null:
		m_failures.append("Roof-clipped Wall3D lost generated collision")

	roof.set_roof_corners(Vector3(8.0, 2.4, 0.0), Vector3(12.0, 2.4, 4.0))
	coordinator.refresh_building_geometry_clips()
	if wall.get_roof_clip_surface_count() != 0:
		m_failures.append("Wall3D kept stale roof clip data after roof moved away")
	if !_has_mesh_vertex_y_near(wall, 4.0, 0.001):
		m_failures.append("Wall3D did not restore full height after roof clip cleared")

	var eave_wall := coordinator.create_wall_node(
		Vector3(0.0, 0.0, 0.0),
		Vector3(4.0, 0.0, 0.0),
		2.8,
		0.22,
		wall_color
	)
	coordinator.add_child(eave_wall)
	var eave_roof := coordinator.create_roof_node(
		Vector3(0.0, 2.4, 0.0),
		Vector3(4.0, 2.4, 4.0),
		"gable",
		45.0,
		0.20,
		0.20,
		Color(0.50, 0.34, 0.25, 1.0)
	)
	coordinator.add_child(eave_roof)
	coordinator.refresh_building_geometry_clips()
	if eave_wall.get_roof_clip_surface_count() != 1:
		m_failures.append("Wall3D did not receive roof clip data for an eave-line wall")
	if _wall_has_vertex_above_roof_underside(eave_wall, eave_roof, 0.025):
		m_failures.append("Wall3D kept eave-line geometry above the roof underside")


func _validate_add_wall_joint() -> void:
	var wall := Wall3DScript.new() as Wall3DScript
	wall.name = "AddJointWall"
	wall.build_on_ready = false
	wall.start_point = Vector3.ZERO
	wall.end_point = Vector3(4.0, 0.0, 0.0)
	wall.wall_height = 2.4
	wall.wall_thickness = 0.22
	wall.wall_color = Color(0.78, 0.68, 0.54, 1.0)
	add_child(wall)

	var opening := BuildingOpening3DScript.new() as BuildingOpening3DScript
	opening.name = "JointSplitOpening"
	opening.opening_width = 0.5
	opening.opening_height = 0.5
	opening.position = Vector3(3.0, 1.1, wall.wall_thickness * 0.5 + 0.035)
	opening.set_meta(Wall3DScript.SEGMENT_INDEX_META, 0)
	wall.add_child(opening)
	wall.rebuild_wall_mesh()

	var old_opening_position := opening.global_position
	if !wall.split_segment_at_point(0, Vector3(2.0, 0.0, 0.0), 0.1):
		m_failures.append("Wall3D could not add a joint to a wall span")
		return
	if wall.get_segment_count() != 2:
		m_failures.append("Wall3D joint insertion did not split the wall into two segments")
	if wall.count_connected_endpoints(Vector3(2.0, 0.0, 0.0), 0.03) != 2:
		m_failures.append("Wall3D joint insertion did not create a shared endpoint")
	if opening.global_position.distance_to(old_opening_position) > 0.001:
		m_failures.append("Wall3D joint insertion moved an existing window opening")
	if wall.get_opening_segment_index(opening) != 1:
		m_failures.append("Wall3D joint insertion did not reassign opening to split segment")

	var moved_joint := Vector3(2.0, 0.0, 1.0)
	var moved_count := wall.move_connected_endpoint(Vector3(2.0, 0.0, 0.0), moved_joint, 0.03)
	if moved_count != 2:
		m_failures.append("Wall3D added joint moved %d endpoints instead of 2" % moved_count)
	if wall.count_connected_endpoints(moved_joint, 0.03) != 2:
		m_failures.append("Wall3D added joint did not stay editable after dragging")

	var touching_segments: Array[WallSegment3DScript] = []
	var first := WallSegment3DScript.new()
	first.start_point = Vector3.ZERO
	first.end_point = Vector3(2.0, 0.0, 0.0)
	touching_segments.append(first)
	var second := WallSegment3DScript.new()
	second.start_point = Vector3(2.0, 0.0, 0.0)
	second.end_point = Vector3(4.0, 0.0, 0.0)
	WallSegment3DScript.merge_into(touching_segments, second, 0.125, false)
	if touching_segments.size() != 2:
		m_failures.append("WallSegment3D collapsed an intentional end-to-end joint")


func _validate_mitered_joint() -> void:
	var corner := Wall3DScript.new() as Wall3DScript
	corner.name = "MiteredCorner"
	corner.build_on_ready = false
	corner.start_point = Vector3.ZERO
	corner.end_point = Vector3(2.0, 0.0, 0.0)
	corner.wall_height = 2.4
	corner.wall_thickness = 0.22
	corner.wall_color = Color(0.78, 0.68, 0.54, 1.0)
	add_child(corner)

	var extra := WallSegment3DScript.new()
	extra.start_point = Vector3.ZERO
	extra.end_point = Vector3(0.0, 0.0, 2.0)
	extra.height = corner.wall_height
	extra.thickness = corner.wall_thickness
	extra.color = corner.wall_color
	var extras: Array[WallSegment3DScript] = [extra]
	corner.extra_segments = extras
	corner.rebuild_wall_mesh()

	if corner.mesh == null or corner.mesh.get_surface_count() <= 0:
		m_failures.append("Mitered wall joint did not generate a mesh")
		return
	var half_thickness := corner.wall_thickness * 0.5
	var start_start_plus_intersection := Vector3(
		half_thickness,
		corner.wall_height,
		half_thickness
	)
	var start_start_minus_intersection := Vector3(
		-half_thickness,
		corner.wall_height,
		-half_thickness
	)
	if !_has_mesh_vertex_near(
		corner.mesh as ArrayMesh,
		start_start_plus_intersection,
		0.004
	):
		m_failures.append("Mitered wall joint did not create the plus-side miter corner")
	if !_has_mesh_vertex_near(
		corner.mesh as ArrayMesh,
		start_start_minus_intersection,
		0.004
	):
		m_failures.append("Mitered wall joint did not create the minus-side miter corner")
	if !_has_mesh_vertex_with_normal_near(
		corner.mesh as ArrayMesh,
		start_start_plus_intersection,
		Vector3.BACK,
		0.004
	):
		m_failures.append("Mitered wall side did not extend to the plus-side intersection")
	if !_has_mesh_vertex_with_normal_near(
		corner.mesh as ArrayMesh,
		start_start_minus_intersection,
		Vector3.FORWARD,
		0.004
	):
		m_failures.append("Mitered wall side did not extend to the minus-side intersection")
	if !_has_mesh_vertex_with_normal_near(
		corner.mesh as ArrayMesh,
		start_start_plus_intersection,
		Vector3.RIGHT,
		0.004
	):
		m_failures.append("Mitered partner side did not extend to the plus-side intersection")
	if !_has_mesh_vertex_with_normal_near(
		corner.mesh as ArrayMesh,
		start_start_minus_intersection,
		Vector3.LEFT,
		0.004
	):
		m_failures.append("Mitered partner side did not extend to the minus-side intersection")
	if _has_diagonal_wall_normal(corner.mesh as ArrayMesh):
		m_failures.append("Mitered wall joint generated an unwanted diagonal joint cap")

	var end_start_corner := Wall3DScript.new() as Wall3DScript
	end_start_corner.name = "MiteredEndStartCorner"
	end_start_corner.build_on_ready = false
	end_start_corner.start_point = Vector3(-2.0, 0.0, 0.0)
	end_start_corner.end_point = Vector3.ZERO
	end_start_corner.wall_height = 2.4
	end_start_corner.wall_thickness = 0.22
	end_start_corner.wall_color = Color(0.78, 0.68, 0.54, 1.0)
	add_child(end_start_corner)

	var end_start_extra := WallSegment3DScript.new()
	end_start_extra.start_point = Vector3.ZERO
	end_start_extra.end_point = Vector3(0.0, 0.0, 2.0)
	end_start_extra.height = end_start_corner.wall_height
	end_start_extra.thickness = end_start_corner.wall_thickness
	end_start_extra.color = end_start_corner.wall_color
	var end_start_extras: Array[WallSegment3DScript] = [end_start_extra]
	end_start_corner.extra_segments = end_start_extras
	end_start_corner.rebuild_wall_mesh()

	if end_start_corner.mesh == null or end_start_corner.mesh.get_surface_count() <= 0:
		m_failures.append("End-start mitered wall joint did not generate a mesh")
		return
	var end_start_primary_plus_intersection := Vector3(
		2.0 - half_thickness,
		end_start_corner.wall_height,
		half_thickness
	)
	var end_start_primary_minus_intersection := Vector3(
		2.0 + half_thickness,
		end_start_corner.wall_height,
		-half_thickness
	)
	if !_has_mesh_vertex_with_normal_near(
		end_start_corner.mesh as ArrayMesh,
		end_start_primary_plus_intersection,
		Vector3.BACK,
		0.004
	):
		m_failures.append("End-start primary side did not extend to the plus-side miter point")
	if !_has_mesh_vertex_with_normal_near(
		end_start_corner.mesh as ArrayMesh,
		end_start_primary_minus_intersection,
		Vector3.FORWARD,
		0.004
	):
		m_failures.append("End-start primary side did not extend to the minus-side miter point")
	if !_has_mesh_vertex_with_normal_near(
		end_start_corner.mesh as ArrayMesh,
		end_start_primary_plus_intersection,
		Vector3.LEFT,
		0.004
	):
		m_failures.append("End-start partner side did not extend to the plus-side miter point")
	if !_has_mesh_vertex_with_normal_near(
		end_start_corner.mesh as ArrayMesh,
		end_start_primary_minus_intersection,
		Vector3.RIGHT,
		0.004
	):
		m_failures.append("End-start partner side did not extend to the minus-side miter point")


func _validate_miter_draw_direction_invariance() -> void:
	var cases := [
		{
			"name": "ForwardCorner",
			"primary_start": Vector3.ZERO,
			"primary_end": Vector3(2.0, 0.0, 0.0),
			"partner_start": Vector3.ZERO,
			"partner_end": Vector3(0.0, 0.0, 2.0),
		},
		{
			"name": "ReversedPrimaryCorner",
			"primary_start": Vector3(2.0, 0.0, 0.0),
			"primary_end": Vector3.ZERO,
			"partner_start": Vector3.ZERO,
			"partner_end": Vector3(0.0, 0.0, 2.0),
		},
		{
			"name": "ReversedPartnerCorner",
			"primary_start": Vector3.ZERO,
			"primary_end": Vector3(2.0, 0.0, 0.0),
			"partner_start": Vector3(0.0, 0.0, 2.0),
			"partner_end": Vector3.ZERO,
		},
		{
			"name": "ReversedBothCorner",
			"primary_start": Vector3(2.0, 0.0, 0.0),
			"primary_end": Vector3.ZERO,
			"partner_start": Vector3(0.0, 0.0, 2.0),
			"partner_end": Vector3.ZERO,
		},
	]
	for case_data in cases:
		var case_name := String(case_data["name"])
		var primary_start: Vector3 = case_data["primary_start"]
		var primary_end: Vector3 = case_data["primary_end"]
		var partner_start: Vector3 = case_data["partner_start"]
		var partner_end: Vector3 = case_data["partner_end"]
		var corner := _create_miter_test_wall(
			case_name,
			primary_start,
			primary_end,
			partner_start,
			partner_end
		)
		if corner.mesh == null or corner.mesh.get_surface_count() <= 0:
			m_failures.append("%s did not generate a mesh" % case_name)
			continue
		var half_thickness := corner.wall_thickness * 0.5
		var expected_a := Vector3(half_thickness, corner.wall_height, half_thickness)
		var expected_b := Vector3(-half_thickness, corner.wall_height, -half_thickness)
		if !_has_world_mesh_vertex_near(corner, expected_a, 0.004):
			m_failures.append("%s missed the draw-direction-invariant first miter point" % case_name)
		if !_has_world_mesh_vertex_near(corner, expected_b, 0.004):
			m_failures.append("%s missed the draw-direction-invariant second miter point" % case_name)
		if _has_world_diagonal_wall_normal(corner):
			m_failures.append("%s generated a direction-dependent diagonal joint cap" % case_name)
		var boundary_edge_count := _world_boundary_edge_count(corner)
		if boundary_edge_count > 0:
			m_failures.append("%s left %d open miter boundary edges" % [case_name, boundary_edge_count])


func _create_miter_test_wall(
	wall_name: String,
	primary_start: Vector3,
	primary_end: Vector3,
	partner_start: Vector3,
	partner_end: Vector3
) -> Wall3DScript:
	var corner := Wall3DScript.new() as Wall3DScript
	corner.name = wall_name
	corner.build_on_ready = false
	corner.start_point = primary_start
	corner.end_point = primary_end
	corner.wall_height = 2.4
	corner.wall_thickness = 0.22
	corner.wall_color = Color(0.78, 0.68, 0.54, 1.0)
	add_child(corner)

	var extra := WallSegment3DScript.new()
	extra.start_point = partner_start
	extra.end_point = partner_end
	extra.height = corner.wall_height
	extra.thickness = corner.wall_thickness
	extra.color = corner.wall_color
	var extras: Array[WallSegment3DScript] = [extra]
	corner.extra_segments = extras
	corner.rebuild_wall_mesh()
	return corner


func _validate_joint_endpoint_drag() -> void:
	var wall := Wall3DScript.new() as Wall3DScript
	wall.name = "JointDragWall"
	wall.build_on_ready = false
	wall.start_point = Vector3.ZERO
	wall.end_point = Vector3(2.0, 0.0, 0.0)
	wall.wall_height = 2.4
	wall.wall_thickness = 0.22
	wall.wall_color = Color(0.78, 0.68, 0.54, 1.0)
	add_child(wall)

	var north := WallSegment3DScript.new()
	north.start_point = Vector3.ZERO
	north.end_point = Vector3(0.0, 0.0, 2.0)
	north.height = wall.wall_height
	north.thickness = wall.wall_thickness
	north.color = wall.wall_color
	var west := WallSegment3DScript.new()
	west.start_point = Vector3.ZERO
	west.end_point = Vector3(-2.0, 0.0, 0.0)
	west.height = wall.wall_height
	west.thickness = wall.wall_thickness
	west.color = wall.wall_color
	var isolated := WallSegment3DScript.new()
	isolated.start_point = Vector3(4.0, 0.0, 0.0)
	isolated.end_point = Vector3(6.0, 0.0, 0.0)
	isolated.height = wall.wall_height
	isolated.thickness = wall.wall_thickness
	isolated.color = wall.wall_color
	var extras: Array[WallSegment3DScript] = [north, west, isolated]
	wall.extra_segments = extras

	var moved_joint := Vector3(1.0, 0.0, 1.0)
	var moved_count := wall.move_connected_endpoint(Vector3.ZERO, moved_joint, 0.03)
	if moved_count != 3:
		m_failures.append("Wall3D joint drag moved %d endpoints instead of 3" % moved_count)
	if wall.count_connected_endpoints(moved_joint, 0.03) != 3:
		m_failures.append("Wall3D joint drag did not preserve a shared editable endpoint")
	if wall.start_point.distance_to(moved_joint) > 0.001:
		m_failures.append("Wall3D joint drag did not move the primary endpoint")
	if wall.extra_segments[0].start_point.distance_to(moved_joint) > 0.001:
		m_failures.append("Wall3D joint drag did not move the first connected segment")
	if wall.extra_segments[1].start_point.distance_to(moved_joint) > 0.001:
		m_failures.append("Wall3D joint drag did not move the second connected segment")
	if wall.end_point.distance_to(Vector3(2.0, 0.0, 0.0)) > 0.001:
		m_failures.append("Wall3D joint drag moved an unconnected primary endpoint")
	if wall.extra_segments[2].start_point.distance_to(Vector3(4.0, 0.0, 0.0)) > 0.001:
		m_failures.append("Wall3D joint drag moved an unrelated segment endpoint")


func _validate_joint_disconnect_connect() -> void:
	var wall := Wall3DScript.new() as Wall3DScript
	wall.name = "JointConnectWall"
	wall.build_on_ready = false
	wall.start_point = Vector3.ZERO
	wall.end_point = Vector3(2.0, 0.0, 0.0)
	wall.wall_height = 2.4
	wall.wall_thickness = 0.22
	wall.wall_color = Color(0.78, 0.68, 0.54, 1.0)
	add_child(wall)

	var north := WallSegment3DScript.new()
	north.start_point = Vector3.ZERO
	north.end_point = Vector3(0.0, 0.0, 2.0)
	north.height = wall.wall_height
	north.thickness = wall.wall_thickness
	north.color = wall.wall_color
	var west := WallSegment3DScript.new()
	west.start_point = Vector3.ZERO
	west.end_point = Vector3(-2.0, 0.0, 0.0)
	west.height = wall.wall_height
	west.thickness = wall.wall_thickness
	west.color = wall.wall_color
	var extras: Array[WallSegment3DScript] = [north, west]
	wall.extra_segments = extras

	var detached := Vector3(1.0, 0.0, 1.0)
	if !wall.move_segment_endpoint(1, 0, detached):
		m_failures.append("Wall3D could not detach a single endpoint from a joint")
	if wall.count_connected_endpoints(Vector3.ZERO, 0.03) != 2:
		m_failures.append("Wall3D detach did not leave the other joint endpoints connected")
	if wall.count_connected_endpoints(detached, 0.03) != 1:
		m_failures.append("Wall3D detach did not isolate the moved endpoint")
	if wall.extra_segments[1].start_point.distance_to(Vector3.ZERO) > 0.001:
		m_failures.append("Wall3D detach moved a different connected endpoint")

	if !wall.move_segment_endpoint(1, 0, Vector3.ZERO):
		m_failures.append("Wall3D could not reconnect a single endpoint to a joint")
	if wall.count_connected_endpoints(Vector3.ZERO, 0.03) != 3:
		m_failures.append("Wall3D reconnect did not restore the shared joint")


func _validate_connected_wall_top_caps() -> void:
	var wall := Wall3DScript.new() as Wall3DScript
	wall.name = "ConnectedTopCaps"
	wall.build_on_ready = false
	wall.start_point = Vector3.ZERO
	wall.end_point = Vector3(0.5, 0.0, 0.0)
	wall.wall_height = 2.4
	wall.wall_thickness = 0.22
	wall.wall_color = Color(0.78, 0.68, 0.54, 1.0)
	add_child(wall)

	var start_partner := WallSegment3DScript.new()
	start_partner.start_point = Vector3.ZERO
	start_partner.end_point = Vector3(0.0, 0.0, -1.5)
	start_partner.height = wall.wall_height
	start_partner.thickness = wall.wall_thickness
	start_partner.color = wall.wall_color
	var end_partner := WallSegment3DScript.new()
	end_partner.start_point = Vector3(0.5, 0.0, 0.0)
	end_partner.end_point = Vector3(0.5, 0.0, 1.5)
	end_partner.height = wall.wall_height
	end_partner.thickness = wall.wall_thickness
	end_partner.color = wall.wall_color
	var extras: Array[WallSegment3DScript] = [start_partner, end_partner]
	wall.extra_segments = extras
	wall.rebuild_wall_mesh()

	if wall.mesh == null or wall.mesh.get_surface_count() <= 0:
		m_failures.append("Connected top-cap wall did not generate a mesh")
		return
	var mesh := wall.mesh as ArrayMesh
	if !_has_horizontal_face_covering_plan_point(mesh, Vector2(0.25, 0.0), wall.wall_height):
		m_failures.append("Connected short wall span lost its top face")
	if !_has_horizontal_face_covering_plan_point(mesh, Vector2(0.0, -0.75), wall.wall_height):
		m_failures.append("Connected start partner wall lost its top face")
	if !_has_horizontal_face_covering_plan_point(mesh, Vector2(0.5, 0.75), wall.wall_height):
		m_failures.append("Connected end partner wall lost its top face")


func _validate_multi_wall_joint_fill() -> void:
	var joint := Wall3DScript.new() as Wall3DScript
	joint.name = "ThreeWallJoint"
	joint.build_on_ready = false
	joint.start_point = Vector3.ZERO
	joint.end_point = Vector3(2.0, 0.0, 0.0)
	joint.wall_height = 2.4
	joint.wall_thickness = 0.22
	joint.wall_color = Color(0.78, 0.68, 0.54, 1.0)
	add_child(joint)

	var north := WallSegment3DScript.new()
	north.start_point = Vector3.ZERO
	north.end_point = Vector3(0.0, 0.0, 2.0)
	north.height = joint.wall_height
	north.thickness = joint.wall_thickness
	north.color = joint.wall_color
	var west := WallSegment3DScript.new()
	west.start_point = Vector3.ZERO
	west.end_point = Vector3(-2.0, 0.0, 0.0)
	west.height = joint.wall_height
	west.thickness = joint.wall_thickness
	west.color = joint.wall_color
	var extras: Array[WallSegment3DScript] = [north, west]
	joint.extra_segments = extras
	joint.rebuild_wall_mesh()

	if joint.mesh == null or joint.mesh.get_surface_count() <= 0:
		m_failures.append("Three-wall mitered joint did not generate a mesh")
		return
	var half_thickness := joint.wall_thickness * 0.5
	if !_has_horizontal_face_covering_plan_point(
		joint.mesh as ArrayMesh,
		Vector2(-half_thickness * 0.5, 0.0),
		joint.wall_height
	):
		m_failures.append("Three-wall joint did not fill the central join top")
	if !_has_horizontal_face_covering_plan_point(
		joint.mesh as ArrayMesh,
		Vector2(half_thickness * 0.5, -half_thickness * 0.5),
		joint.wall_height
	):
		m_failures.append("Three-wall joint did not fill the continuous wall side of the join")
	if !_has_horizontal_face_covering_plan_point(
		joint.mesh as ArrayMesh,
		Vector2(0.0, half_thickness * 0.5),
		joint.wall_height
	):
		m_failures.append("Three-wall joint did not fill the branch wall side of the join")
	if _has_diagonal_wall_normal(joint.mesh as ArrayMesh):
		m_failures.append("Three-wall joint generated internal vertical cap geometry")


func _validate_enclosed_wall_loop_caps() -> void:
	var loop := Wall3DScript.new() as Wall3DScript
	loop.name = "EnclosedWallLoop"
	loop.build_on_ready = false
	loop.start_point = Vector3.ZERO
	loop.end_point = Vector3(2.0, 0.0, 0.0)
	loop.wall_height = 2.4
	loop.wall_thickness = 0.22
	loop.wall_color = Color(0.78, 0.68, 0.54, 1.0)
	add_child(loop)

	var east := WallSegment3DScript.new()
	east.start_point = Vector3(2.0, 0.0, 0.0)
	east.end_point = Vector3(2.0, 0.0, 2.0)
	east.height = loop.wall_height
	east.thickness = loop.wall_thickness
	east.color = loop.wall_color
	var north := WallSegment3DScript.new()
	north.start_point = Vector3(2.0, 0.0, 2.0)
	north.end_point = Vector3(0.0, 0.0, 2.0)
	north.height = loop.wall_height
	north.thickness = loop.wall_thickness
	north.color = loop.wall_color
	var west := WallSegment3DScript.new()
	west.start_point = Vector3(0.0, 0.0, 2.0)
	west.end_point = Vector3.ZERO
	west.height = loop.wall_height
	west.thickness = loop.wall_thickness
	west.color = loop.wall_color
	var extras: Array[WallSegment3DScript] = [east, north, west]
	loop.extra_segments = extras
	loop.rebuild_wall_mesh()

	if loop.mesh == null or loop.mesh.get_surface_count() <= 0:
		m_failures.append("Enclosed wall loop did not generate a mesh")
		return
	var mesh := loop.mesh as ArrayMesh
	if !_has_horizontal_face_covering_plan_point(mesh, Vector2(1.0, -loop.wall_thickness * 0.25), loop.wall_height):
		m_failures.append("Enclosed wall loop lost the south wall top cap")
	if _has_horizontal_face_covering_plan_point(mesh, Vector2(1.0, 1.0), loop.wall_height):
		m_failures.append("Enclosed wall loop filled the room interior instead of keeping only walls")


func _validate_overlapping_room_wall_clipping() -> void:
	var coordinator := BuildingEditor3DScript.new() as BuildingEditor3DScript
	coordinator.name = "OverlappingRoomCoordinator"
	coordinator.position = Vector3(0.0, 0.0, 72.0)
	add_child(coordinator)
	var wall_color := Color(0.78, 0.68, 0.54, 1.0)
	var first_room := coordinator.create_room_node(
		Vector3.ZERO,
		Vector3(6.0, 0.0, 4.0),
		2.4,
		0.22,
		wall_color
	)
	coordinator.add_child(first_room)
	var second_room := coordinator.create_room_node(
		Vector3(3.0, 0.0, 4.0),
		Vector3(8.0, 0.0, 8.0),
		2.4,
		0.22,
		wall_color
	)
	coordinator.add_child(second_room)
	coordinator.refresh_wall_intersection_clips()

	var shared_wall_point := Vector3(4.5, 0.0, 4.0)
	var first_local := first_room.transform.affine_inverse() * shared_wall_point
	var second_local := second_room.transform.affine_inverse() * shared_wall_point
	if !_has_horizontal_face_covering_plan_point(
		first_room.mesh as ArrayMesh,
		Vector2(first_local.x, first_local.z),
		first_room.wall_height
	):
		m_failures.append("Earlier room lost the shared overlapping wall geometry")
	if _has_horizontal_face_covering_plan_point(
		second_room.mesh as ArrayMesh,
		Vector2(second_local.x, second_local.z),
		second_room.wall_height
	):
		m_failures.append("Later room kept duplicate geometry along the shared overlapping wall")
	if !coordinator.can_place_wall_opening(
		first_room,
		2,
		Vector2(1.5, 1.1),
		Vector2(0.8, 0.8)
	):
		m_failures.append("BuildingEditor3D rejected an opening on the first room's shared wall")
	if !coordinator.can_place_wall_opening(
		second_room,
		0,
		Vector2(1.5, 1.1),
		Vector2(0.8, 0.8)
	):
		m_failures.append("BuildingEditor3D blocked an opening on the clipped collinear shared wall")
	if !coordinator.can_place_wall_opening(
		first_room,
		0,
		Vector2(2.0, 1.1),
		Vector2(0.8, 0.8)
	):
		m_failures.append("BuildingEditor3D rejected an opening on a non-overlapping room wall")
	coordinator.merge_intersecting = false
	coordinator.refresh_wall_intersection_clips()
	if !coordinator.can_place_wall_opening(
		first_room,
		2,
		Vector2(1.5, 1.1),
		Vector2(0.8, 0.8)
	):
		m_failures.append("Shared room wall rejected an opening after generic intersection clipping was disabled")
	if _has_horizontal_face_covering_plan_point(
		second_room.mesh as ArrayMesh,
		Vector2(second_local.x, second_local.z),
		second_room.wall_height
	):
		m_failures.append("Shared room wall duplicate returned when generic intersection clipping was disabled")


func _up_facing_area(array_mesh: ArrayMesh, expected_height: float) -> float:
	if array_mesh == null or array_mesh.get_surface_count() <= 0:
		return 0.0
	var arrays := array_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var area := 0.0
	for triangle_start in range(0, indices.size(), 3):
		var i0 := indices[triangle_start]
		var i1 := indices[triangle_start + 1]
		var i2 := indices[triangle_start + 2]
		if normals[i0].dot(Vector3.UP) < 0.9:
			continue
		if absf(vertices[i0].y - expected_height) > 0.01:
			continue
		var a := vertices[i0]
		var b := vertices[i1]
		var c := vertices[i2]
		area += ((b - a).cross(c - a)).length() * 0.5
	return area


func _has_mesh_vertex_near(array_mesh: ArrayMesh, expected: Vector3, tolerance: float) -> bool:
	if array_mesh == null or array_mesh.get_surface_count() <= 0:
		return false
	var arrays := array_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for vertex in vertices:
		if vertex.distance_to(expected) <= tolerance:
			return true
	return false


func _has_world_mesh_vertex_near(
	wall: Wall3DScript,
	expected: Vector3,
	tolerance: float
) -> bool:
	if wall.mesh == null or wall.mesh.get_surface_count() <= 0:
		return false
	var arrays := wall.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for vertex in vertices:
		var world_vertex := wall.global_transform * vertex
		if world_vertex.distance_to(expected) <= tolerance:
			return true
	return false


func _has_mesh_vertex_with_normal_near(
	array_mesh: ArrayMesh,
	expected: Vector3,
	expected_normal: Vector3,
	tolerance: float
) -> bool:
	if array_mesh == null or array_mesh.get_surface_count() <= 0:
		return false
	var arrays := array_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for index in range(vertices.size()):
		if vertices[index].distance_to(expected) > tolerance:
			continue
		if normals[index].dot(expected_normal) > 0.98:
			return true
	return false


func _has_rect_near(rects: Array[Rect2], expected: Rect2) -> bool:
	for rect in rects:
		if rect.position.distance_to(expected.position) > 0.001:
			continue
		if rect.size.distance_to(expected.size) <= 0.001:
			return true
	return false


func _has_vertical_face_covering_plan_edge_point(
	array_mesh: ArrayMesh,
	point: Vector2,
	expected_normal: Vector3
) -> bool:
	if array_mesh == null or array_mesh.get_surface_count() <= 0:
		return false
	var arrays := array_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for triangle_start in range(0, indices.size(), 3):
		var i0 := indices[triangle_start]
		var i1 := indices[triangle_start + 1]
		var i2 := indices[triangle_start + 2]
		if normals[i0].dot(expected_normal) < 0.98:
			continue
		var a := vertices[i0]
		var b := vertices[i1]
		var c := vertices[i2]
		if absf(expected_normal.x) > 0.9:
			if (
				absf(a.x - point.x) > 0.001
				or absf(b.x - point.x) > 0.001
				or absf(c.x - point.x) > 0.001
			):
				continue
			if _triangle_range_contains(a.z, b.z, c.z, point.y) and _triangle_range_spans_y(a, b, c):
				return true
		elif absf(expected_normal.z) > 0.9:
			if (
				absf(a.z - point.y) > 0.001
				or absf(b.z - point.y) > 0.001
				or absf(c.z - point.y) > 0.001
			):
				continue
			if _triangle_range_contains(a.x, b.x, c.x, point.x) and _triangle_range_spans_y(a, b, c):
				return true
	return false


func _triangle_range_contains(a: float, b: float, c: float, value: float) -> bool:
	return value >= minf(a, minf(b, c)) - 0.001 and value <= maxf(a, maxf(b, c)) + 0.001


func _triangle_range_spans_y(a: Vector3, b: Vector3, c: Vector3) -> bool:
	var min_y := minf(a.y, minf(b.y, c.y))
	var max_y := maxf(a.y, maxf(b.y, c.y))
	return min_y < -0.01 and max_y > -0.001


func _has_normal_near(normals: PackedVector3Array, expected_normal: Vector3) -> bool:
	for normal in normals:
		if normal.dot(expected_normal) > 0.98:
			return true
	return false


func _has_roof_upward_normal(normals: PackedVector3Array) -> bool:
	for normal in normals:
		if normal.y > 0.45:
			return true
	return false


func _has_roof_downward_normal(normals: PackedVector3Array) -> bool:
	for normal in normals:
		if normal.y < -0.45:
			return true
	return false


func _roof_face_angle_degrees(plane_points: PackedVector3Array) -> float:
	if plane_points.size() < 3:
		return -1.0
	var normal := (plane_points[1] - plane_points[0]).cross(plane_points[2] - plane_points[0]).normalized()
	return rad_to_deg(acos(clampf(absf(normal.y), 0.0, 1.0)))


func _mesh_vertex_count(mesh_instance: MeshInstance3D) -> int:
	if mesh_instance == null or mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() <= 0:
		return 0
	var arrays := mesh_instance.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	return vertices.size()


func _has_mesh_vertex_y_near(mesh_instance: MeshInstance3D, expected_y: float, tolerance: float) -> bool:
	if mesh_instance == null or mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() <= 0:
		return false
	var arrays := mesh_instance.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for vertex in vertices:
		if absf(vertex.y - expected_y) <= tolerance:
			return true
	return false


func _wall_has_vertex_above_roof_underside(
	wall: Wall3DScript,
	roof: Roof3DScript,
	tolerance: float
) -> bool:
	if wall == null or roof == null:
		return false
	if wall.mesh == null or wall.mesh.get_surface_count() <= 0:
		return false
	var arrays := wall.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var roof_basis := Basis(Vector3.UP, deg_to_rad(roof.roof_rotation_degrees))
	var roof_inverse := roof_basis.inverse()
	var roof_anchor := roof.get_roof_anchor_point()
	var roof_rect := roof.get_roof_render_rect()
	for vertex in vertices:
		var parent_point := wall.transform * vertex
		var roof_local := roof_inverse * (parent_point - roof_anchor)
		var roof_plan := Vector2(roof_local.x, roof_local.z)
		if !_rect_contains_point_with_tolerance(roof_rect, roof_plan, 0.001):
			continue
		var underside_y := (
			roof.start_point.y
			+ roof.get_roof_height_at_local_render_point(roof_plan)
			- roof.roof_thickness
		)
		if parent_point.y > underside_y + tolerance:
			return true
	return false


func _rect_contains_point_with_tolerance(rect: Rect2, point: Vector2, tolerance: float) -> bool:
	var rect_max := rect.position + rect.size
	return (
		point.x >= rect.position.x - tolerance
		and point.y >= rect.position.y - tolerance
		and point.x <= rect_max.x + tolerance
		and point.y <= rect_max.y + tolerance
	)


func _roof_wireframe_matches_triangle_indices(roof: Roof3DScript) -> bool:
	if roof == null or roof.mesh == null or roof.mesh.get_surface_count() <= 0:
		return false
	var wireframe := roof.get_node_or_null(Roof3DScript.TRIANGLE_WIREFRAME_NODE_NAME) as MeshInstance3D
	if wireframe == null or wireframe.mesh == null or wireframe.mesh.get_surface_count() <= 0:
		return false
	var roof_arrays := roof.mesh.surface_get_arrays(0)
	var roof_indices: PackedInt32Array = roof_arrays[Mesh.ARRAY_INDEX]
	var wire_arrays := wireframe.mesh.surface_get_arrays(0)
	var line_vertices: PackedVector3Array = wire_arrays[Mesh.ARRAY_VERTEX]
	return line_vertices.size() == roof_indices.size() * 2


func _covered_polygon_area(polygons: Array) -> float:
	var area := 0.0
	for polygon_variant in polygons:
		area += absf(_polygon_area(_polygon_from_variant(polygon_variant)))
	return area


func _polygon_vertex_count(polygons: Array) -> int:
	var count := 0
	for polygon_variant in polygons:
		count += _polygon_from_variant(polygon_variant).size()
	return count


func _cover_polygons_have_non_axis_edge(polygons: Array) -> bool:
	for polygon_variant in polygons:
		var polygon := _polygon_from_variant(polygon_variant)
		for index in range(polygon.size()):
			var current := polygon[index]
			var next := polygon[(index + 1) % polygon.size()]
			var edge := next - current
			if absf(edge.x) > 0.01 and absf(edge.y) > 0.01:
				return true
	return false


func _cover_polygons_sample_under_other_roof(
	polygons: Array,
	candidate_start: Vector3,
	candidate_end: Vector3,
	candidate_style: String,
	candidate_angle_degrees: float,
	candidate_overhang: float,
	candidate_rotation_degrees: float,
	other_roofs: Array[Roof3DScript]
) -> bool:
	var candidate_size := Vector2(absf(candidate_end.x - candidate_start.x), absf(candidate_end.z - candidate_start.z))
	var candidate_anchor := Vector3(
		minf(candidate_start.x, candidate_end.x),
		candidate_start.y,
		minf(candidate_start.z, candidate_end.z)
	)
	var candidate_basis := Basis(Vector3.UP, deg_to_rad(candidate_rotation_degrees))
	for polygon_variant in polygons:
		var polygon := _polygon_from_variant(polygon_variant)
		for point in _polygon_sample_points(polygon):
			var candidate_height := Roof3DScript.roof_surface_height_for_style(
				candidate_style,
				candidate_size,
				candidate_overhang,
				candidate_angle_degrees,
				point
			)
			var parent_point := candidate_anchor + candidate_basis * Vector3(point.x, 0.0, point.y)
			if !_sample_is_under_any_roof(parent_point, candidate_start.y + candidate_height, other_roofs):
				return false
	return true


func _polygon_from_variant(value) -> PackedVector2Array:
	if value is PackedVector2Array:
		return PackedVector2Array(value)
	var polygon := PackedVector2Array()
	for point in value:
		polygon.append(Vector2(point))
	return polygon


func _polygon_area(polygon: PackedVector2Array) -> float:
	var area := 0.0
	for index in range(polygon.size()):
		var current := polygon[index]
		var next := polygon[(index + 1) % polygon.size()]
		area += current.x * next.y - next.x * current.y
	return area * 0.5


func _polygon_sample_points(polygon: PackedVector2Array) -> Array[Vector2]:
	var points: Array[Vector2] = []
	if polygon.is_empty():
		return points
	var centroid := Vector2.ZERO
	for index in range(polygon.size()):
		var current := polygon[index]
		var next := polygon[(index + 1) % polygon.size()]
		points.append(current)
		points.append((current + next) * 0.5)
		centroid += current
	points.append(centroid / float(polygon.size()))
	return points


func _sample_is_under_any_roof(
	parent_point: Vector3,
	candidate_top_y: float,
	other_roofs: Array[Roof3DScript]
) -> bool:
	for other_roof in other_roofs:
		var other_basis_inverse := Basis(Vector3.UP, deg_to_rad(other_roof.roof_rotation_degrees)).inverse()
		var other_local := other_basis_inverse * (parent_point - other_roof.get_roof_anchor_point())
		var other_point := Vector2(other_local.x, other_local.z)
		if !_rect_contains_point_inclusive(other_roof.get_roof_render_rect(), other_point):
			continue
		var other_height := other_roof.get_roof_height_at_local_render_point(other_point)
		if other_roof.start_point.y + other_height >= candidate_top_y - 0.01:
			return true
	return false


func _rect_contains_point_inclusive(rect: Rect2, point: Vector2) -> bool:
	var max_point := rect.position + rect.size
	return (
		point.x >= rect.position.x - 0.001
		and point.y >= rect.position.y - 0.001
		and point.x <= max_point.x + 0.001
		and point.y <= max_point.y + 0.001
	)


func _roof_underside_normals_are_down(roof: Roof3DScript) -> bool:
	if roof == null or roof.mesh == null or roof.mesh.get_surface_count() <= 0:
		return false
	var arrays := roof.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var found_underside := false
	for index in range(0, indices.size(), 3):
		var first := vertices[indices[index]]
		var second := vertices[indices[index + 1]]
		var third := vertices[indices[index + 2]]
		if (
			!_roof_vertex_is_on_underside(roof, first)
			or !_roof_vertex_is_on_underside(roof, second)
			or !_roof_vertex_is_on_underside(roof, third)
		):
			continue
		found_underside = true
		if normals[indices[index]].y >= -0.25:
			return false
	return found_underside


func _roof_surface_normals_are_not_down(roof: Roof3DScript) -> bool:
	if roof == null or roof.mesh == null or roof.mesh.get_surface_count() <= 0:
		return false
	var arrays := roof.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var found_surface := false
	for index in range(0, indices.size(), 3):
		var first := vertices[indices[index]]
		var second := vertices[indices[index + 1]]
		var third := vertices[indices[index + 2]]
		if (
			_roof_vertex_is_on_underside(roof, first)
			and _roof_vertex_is_on_underside(roof, second)
			and _roof_vertex_is_on_underside(roof, third)
		):
			continue
		found_surface = true
		if normals[indices[index]].y < -0.01:
			return false
	return found_surface


func _roof_vertex_is_on_underside(roof: Roof3DScript, vertex: Vector3) -> bool:
	var surface_height := roof.get_roof_height_at_local_render_point(Vector2(vertex.x, vertex.z))
	return absf(vertex.y - (surface_height - roof.roof_thickness)) <= 0.002


func _has_internal_roof_fascia_facing_cover(
	roof: Roof3DScript,
	cover_polygons: Array[PackedVector2Array]
) -> bool:
	if roof == null or roof.mesh == null or roof.mesh.get_surface_count() <= 0:
		return false
	var arrays := roof.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var render_rect := roof.get_roof_render_rect()
	for index in range(vertices.size()):
		var normal := normals[index]
		if absf(normal.y) > 0.05:
			continue
		var point := Vector2(vertices[index].x, vertices[index].z)
		if !_point_on_rect_boundary(render_rect, point):
			var normal_2d := Vector2(normal.x, normal.z)
			if normal_2d.length_squared() <= 0.0001:
				continue
			var outward_sample := point + normal_2d.normalized() * 0.03
			if _point_is_inside_any_polygon(outward_sample, cover_polygons):
				return true
	return false


func _point_is_inside_any_polygon(point: Vector2, polygons: Array[PackedVector2Array]) -> bool:
	for polygon in polygons:
		if _point_is_inside_polygon(point, polygon):
			return true
	return false


func _point_is_inside_polygon(point: Vector2, polygon: PackedVector2Array) -> bool:
	var inside := false
	var previous_index := polygon.size() - 1
	for current_index in range(polygon.size()):
		var current := polygon[current_index]
		var previous := polygon[previous_index]
		var denominator := previous.y - current.y
		var crosses := false
		if absf(denominator) > 0.000001:
			crosses = (
				(current.y > point.y) != (previous.y > point.y)
				and point.x < (previous.x - current.x) * (point.y - current.y) / denominator + current.x
			)
		if crosses:
			inside = !inside
		previous_index = current_index
	return inside


func _point_on_rect_boundary(rect: Rect2, point: Vector2) -> bool:
	if !_rect_contains_point_inclusive(rect, point):
		return false
	var max_point := rect.position + rect.size
	return (
		absf(point.x - rect.position.x) <= 0.001
		or absf(point.x - max_point.x) <= 0.001
		or absf(point.y - rect.position.y) <= 0.001
		or absf(point.y - max_point.y) <= 0.001
	)


func _has_roof_sloped_normal(mesh_instance: MeshInstance3D) -> bool:
	if mesh_instance == null or mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() <= 0:
		return false
	var arrays := mesh_instance.mesh.surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for normal in normals:
		if normal.y > 0.25 and normal.y < 0.98:
			return true
	return false


func _roof_base_has_corner_near(roof: Roof3DScript, expected_corner: Vector3) -> bool:
	var basis := Basis(Vector3.UP, deg_to_rad(roof.roof_rotation_degrees))
	var size := roof.get_roof_size()
	var anchor := roof.get_roof_anchor_point()
	var corners := [
		anchor,
		anchor + basis * Vector3(size.x, 0.0, 0.0),
		anchor + basis * Vector3(size.x, 0.0, size.y),
		anchor + basis * Vector3(0.0, 0.0, size.y),
	]
	for corner in corners:
		if Vector3(corner).distance_to(expected_corner) <= 0.001:
			return true
	return false


func _pillar_max_radius_at_y(pillar: Pillar3DScript, expected_y: float) -> float:
	if pillar.mesh == null or pillar.mesh.get_surface_count() <= 0:
		return 0.0
	var arrays := pillar.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var max_radius := 0.0
	for vertex in vertices:
		if absf(vertex.y - expected_y) > 0.001:
			continue
		max_radius = maxf(max_radius, Vector2(vertex.x, vertex.z).length())
	return max_radius


func _has_horizontal_pillar_normal(normals: PackedVector3Array) -> bool:
	for normal in normals:
		if absf(normal.y) > 0.01:
			continue
		if normal.length_squared() > 0.98:
			return true
	return false


func _has_diagonal_wall_normal(array_mesh: ArrayMesh) -> bool:
	if array_mesh == null or array_mesh.get_surface_count() <= 0:
		return false
	var arrays := array_mesh.surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for normal in normals:
		if absf(normal.y) > 0.01:
			continue
		if maxf(absf(normal.dot(Vector3.RIGHT)), absf(normal.dot(Vector3.BACK))) < 0.98:
			return true
	return false


func _has_world_diagonal_wall_normal(wall: Wall3DScript) -> bool:
	if wall.mesh == null or wall.mesh.get_surface_count() <= 0:
		return false
	var arrays := wall.mesh.surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for normal in normals:
		var world_normal := (wall.global_transform.basis * normal).normalized()
		if absf(world_normal.y) > 0.01:
			continue
		if maxf(absf(world_normal.dot(Vector3.RIGHT)), absf(world_normal.dot(Vector3.BACK))) < 0.98:
			return true
	return false


func _world_boundary_edge_count(wall: Wall3DScript) -> int:
	if wall.mesh == null or wall.mesh.get_surface_count() <= 0:
		return 0
	var arrays := wall.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var edge_counts := {}
	for triangle_start in range(0, indices.size(), 3):
		var a := wall.global_transform * vertices[indices[triangle_start]]
		var b := wall.global_transform * vertices[indices[triangle_start + 1]]
		var c := wall.global_transform * vertices[indices[triangle_start + 2]]
		_add_edge_count(edge_counts, a, b)
		_add_edge_count(edge_counts, b, c)
		_add_edge_count(edge_counts, c, a)
	var open_count := 0
	for key in edge_counts.keys():
		if int(edge_counts[key]) != 2:
			open_count += 1
	return open_count


func _add_edge_count(edge_counts: Dictionary, a: Vector3, b: Vector3) -> void:
	var a_key := _vertex_key(a)
	var b_key := _vertex_key(b)
	var edge_key := "%s|%s" % [a_key, b_key] if a_key < b_key else "%s|%s" % [b_key, a_key]
	edge_counts[edge_key] = int(edge_counts.get(edge_key, 0)) + 1


func _vertex_key(vertex: Vector3) -> String:
	return "%d,%d,%d" % [
		int(round(vertex.x * 1000.0)),
		int(round(vertex.y * 1000.0)),
		int(round(vertex.z * 1000.0)),
	]


func _validate_collinear_overlap_opening_propagation() -> void:
	var coordinator := BuildingEditor3DScript.new() as BuildingEditor3DScript
	coordinator.name = "CollinearOpeningCoordinator"
	coordinator.position = Vector3(0.0, 0.0, 96.0)
	add_child(coordinator)
	var wall_color := Color(0.78, 0.68, 0.54, 1.0)
	# Earlier scene-order wall owns the shared span; later wall is clipped there.
	var owner_wall := coordinator.create_wall_node(
		Vector3.ZERO, Vector3(6.0, 0.0, 0.0), 2.4, 0.22, wall_color
	)
	coordinator.add_child(owner_wall)
	var clipped_wall := coordinator.create_wall_node(
		Vector3(3.0, 0.0, 0.0), Vector3(9.0, 0.0, 0.0), 2.4, 0.22, wall_color
	)
	coordinator.add_child(clipped_wall)
	coordinator.refresh_wall_intersection_clips()

	# Placement is allowed on the clipped (later) wall along the collinear overlap.
	if !coordinator.can_place_wall_opening(
		clipped_wall, 0, Vector2(1.5, 1.1), Vector2(0.8, 0.8)
	):
		m_failures.append("Opening placement blocked on the clipped collinear wall overlap")

	# Door authored on the clipped (later) wall, inside the overlap (world x ~ 4.5).
	var door := BuildingOpening3DScript.new() as BuildingOpening3DScript
	door.name = "OverlapDoor"
	door.opening_width = 0.9
	door.opening_height = 2.1
	door.position = Vector3(1.5, 1.05, 0.22 * 0.5 + 0.035)
	door.set_meta(Wall3DScript.SEGMENT_INDEX_META, 0)
	clipped_wall.add_child(door)
	clipped_wall.rebuild_wall_mesh()
	coordinator.refresh_wall_intersection_clips()

	# The owner wall must now carry the propagated opening on its shared segment.
	var owner_local_door_x := 4.5
	var owner_rects := owner_wall.get_render_opening_rects(0)
	var found_propagated := false
	for rect in owner_rects:
		if rect.position.x <= owner_local_door_x and rect.end.x >= owner_local_door_x:
			found_propagated = true
			break
	if !found_propagated:
		m_failures.append("Owner wall did not receive the collinear sibling's door opening")

	# And the owner's rendered mesh must show a cut: a reveal/jamb face (normal
	# along the wall axis) at the door edges within the overlap, not just the
	# segment end caps at x=0 and x=6.
	var door_point := coordinator.to_global(Vector3(4.5, 1.0, 0.0))
	var owner_local := owner_wall.to_local(door_point)
	if !_has_axis_reveal_face(
		owner_wall.mesh as ArrayMesh, owner_local.x, 0.6, 2.0
	):
		m_failures.append("Owner wall mesh was not cut within the propagated door frame")


## True when the mesh has a near-vertical face whose normal runs along the wall
## X axis (a door/window jamb reveal) located near `target_x` and below the
## given height band, ignoring the wall's end caps far from the door.
func _has_axis_reveal_face(
	array_mesh: ArrayMesh,
	target_x: float,
	min_height: float,
	max_height: float
) -> bool:
	if array_mesh == null or array_mesh.get_surface_count() <= 0:
		return false
	var arrays := array_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for triangle_start in range(0, indices.size(), 3):
		var i0 := indices[triangle_start]
		var i1 := indices[triangle_start + 1]
		var i2 := indices[triangle_start + 2]
		if absf(normals[i0].x) < 0.9:
			continue
		var mean_x := (vertices[i0].x + vertices[i1].x + vertices[i2].x) / 3.0
		# The two jambs sit ~half the door width either side of centre; the wall
		# end caps (x=0 and x=6) stay well outside this band.
		if absf(mean_x - target_x) > 0.7:
			continue
		var mean_y := (vertices[i0].y + vertices[i1].y + vertices[i2].y) / 3.0
		if mean_y < min_height or mean_y > max_height:
			continue
		return true
	return false


func _has_horizontal_face_covering_plan_point(
	array_mesh: ArrayMesh,
	point: Vector2,
	expected_height: float
) -> bool:
	if array_mesh == null or array_mesh.get_surface_count() <= 0:
		return false
	var arrays := array_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for triangle_start in range(0, indices.size(), 3):
		var i0 := indices[triangle_start]
		var i1 := indices[triangle_start + 1]
		var i2 := indices[triangle_start + 2]
		if normals[i0].dot(Vector3.UP) < 0.9:
			continue
		if absf(vertices[i0].y - expected_height) > 0.01:
			continue
		var a := Vector2(vertices[i0].x, vertices[i0].z)
		var b := Vector2(vertices[i1].x, vertices[i1].z)
		var c := Vector2(vertices[i2].x, vertices[i2].z)
		if _plan_triangle_contains_point(a, b, c, point):
			return true
	return false


func _plan_triangle_contains_point(a: Vector2, b: Vector2, c: Vector2, point: Vector2) -> bool:
	var area := absf((b - a).cross(c - a))
	if area <= 0.000001:
		return false
	var area_a := absf((b - point).cross(c - point))
	var area_b := absf((point - a).cross(c - a))
	var area_c := absf((b - a).cross(point - a))
	return absf(area - area_a - area_b - area_c) <= 0.0005


func _endpoint_count(segments: Array, point: Vector3) -> int:
	var count := 0
	for segment in segments:
		var typed_segment := segment as WallSegment3DScript
		if typed_segment == null:
			continue
		if typed_segment.start_point.distance_to(point) <= 0.001:
			count += 1
		if typed_segment.end_point.distance_to(point) <= 0.001:
			count += 1
	return count


func _endpoint_count_for_axis(segments: Array, point: Vector3, axis: Vector2) -> int:
	var count := 0
	var normalized_axis := axis.normalized()
	for segment in segments:
		var typed_segment := segment as WallSegment3DScript
		if typed_segment == null:
			continue
		var segment_axis := Vector2(
			typed_segment.end_point.x - typed_segment.start_point.x,
			typed_segment.end_point.z - typed_segment.start_point.z
		).normalized()
		if absf(segment_axis.dot(normalized_axis)) < 0.999:
			continue
		if typed_segment.start_point.distance_to(point) <= 0.001:
			count += 1
		if typed_segment.end_point.distance_to(point) <= 0.001:
			count += 1
	return count
