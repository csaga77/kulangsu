@tool
extends Node3D

const BuildingEditor3DScript = preload("res://addons/low_poly_building_editor/building_editor_3d.gd")
const ProceduralWall3DScript = preload("res://addons/low_poly_building_editor/procedural_wall_3d.gd")
const ProceduralFloor3DScript = preload("res://addons/low_poly_building_editor/procedural_floor_3d.gd")
const ProceduralPillar3DScript = preload("res://addons/low_poly_building_editor/procedural_pillar_3d.gd")
const ProceduralRoof3DScript = preload("res://addons/low_poly_building_editor/procedural_roof_3d.gd")
const BuildingOpening3DScript = preload("res://addons/low_poly_building_editor/building_opening_3d.gd")
const WallSegment3DScript = preload("res://addons/low_poly_building_editor/wall_segment_3d.gd")

var m_failures: Array[String] = []


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	call_deferred("_run_smoke_checks")


func _run_smoke_checks() -> void:
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
	_validate_floor_node(coordinator)
	_validate_pillar_node(coordinator)
	_validate_roof_node(coordinator)
	_validate_merge_detection(coordinator)
	_validate_intersection_merge()
	_validate_add_wall_joint()
	_validate_joint_endpoint_drag()
	_validate_joint_disconnect_connect()
	_validate_mitered_joint()
	_validate_miter_draw_direction_invariance()
	_validate_connected_wall_top_caps()
	_validate_multi_wall_joint_fill()
	_validate_enclosed_wall_loop_caps()

	for failure in m_failures:
		push_error(failure)
	if m_failures.is_empty():
		print("PASS: LowPolyBuildingEditor3D smoke test")
	get_tree().quit(0 if m_failures.is_empty() else 1)


func _validate_wall_mesh(wall: ProceduralWall3DScript) -> void:
	if wall.mesh == null:
		m_failures.append("ProceduralWall3D did not generate a mesh")
		return
	if wall.mesh.get_surface_count() <= 0:
		m_failures.append("ProceduralWall3D mesh has no surfaces")
		return
	var arrays := wall.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if vertices.is_empty():
		m_failures.append("ProceduralWall3D mesh has no vertices")
	if normals.size() != vertices.size():
		m_failures.append("ProceduralWall3D mesh is missing per-vertex normal data")
	if colors.size() != vertices.size():
		m_failures.append("ProceduralWall3D mesh is missing per-vertex color data")
	if !normals.is_empty() and normals[0].dot(Vector3.BACK) < 0.999:
		m_failures.append("ProceduralWall3D primary outside face normal is inverted")
	if indices.size() >= 3 and !normals.is_empty():
		var a := vertices[indices[0]]
		var b := vertices[indices[1]]
		var c := vertices[indices[2]]
		var winding_normal := (b - a).cross(c - a).normalized()
		if winding_normal.dot(normals[indices[0]]) > -0.999:
			m_failures.append("ProceduralWall3D triangle winding does not match Godot BoxMesh convention")
	if wall.get_node_or_null("WallCollision") == null:
		m_failures.append("ProceduralWall3D did not generate collision for editor raycasts")


func _validate_opening_rules(wall: ProceduralWall3DScript) -> void:
	var overlapping_center := Vector2(2.0, 1.1)
	var open_center := Vector2(3.35, 1.1)
	if wall.can_place_opening(overlapping_center, Vector2(0.8, 0.8)):
		m_failures.append("ProceduralWall3D allowed an overlapping window opening")
	if !wall.can_place_opening(open_center, Vector2(0.6, 0.8)):
		m_failures.append("ProceduralWall3D rejected a valid non-overlapping opening")


func _validate_door_opening_rules(wall: ProceduralWall3DScript) -> void:
	var door_center := Vector2(0.8, 1.05)
	var door_size := Vector2(0.9, 2.1)
	if wall.can_place_opening(door_center, door_size, 0.03, null, 0):
		m_failures.append("ProceduralWall3D allowed a floor-touching door without base-edge allowance")
	if !wall.can_place_opening(door_center, door_size, 0.03, null, 0, true):
		m_failures.append("ProceduralWall3D rejected a valid floor-touching door opening")

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
	var wall := ProceduralWall3DScript.new() as ProceduralWall3DScript
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
	opening.set_meta(ProceduralWall3DScript.SEGMENT_INDEX_META, 1)
	wall.rebuild_wall_mesh()

	var old_position := opening.position
	if !wall.move_segment_endpoint(1, 1, Vector3(3.0, 0.0, 2.0)):
		m_failures.append("ProceduralWall3D could not move an opening-bearing segment endpoint")
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
		m_failures.append("ProceduralWall3D did not preserve elevated wall base endpoints")
	if absf(elevated.position.y - base_y) > 0.001:
		m_failures.append("ProceduralWall3D did not place wall transform at elevated base height")


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
		m_failures.append("ProceduralFloor3D did not generate a mesh")
		return
	if floor.mesh.get_surface_count() <= 0:
		m_failures.append("ProceduralFloor3D mesh has no surfaces")
		return

	var size := floor.get_floor_size()
	if absf(size.x - 3.0) > 0.001 or absf(size.y - 2.0) > 0.001:
		m_failures.append("ProceduralFloor3D returned the wrong footprint size: %s" % str(size))
	if floor.position.distance_to(Vector3(0.0, top_y, 12.0)) > 0.001:
		m_failures.append("ProceduralFloor3D did not place its transform at the floor top corner")

	var arrays := floor.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if vertices.is_empty():
		m_failures.append("ProceduralFloor3D mesh has no vertices")
	if normals.size() != vertices.size():
		m_failures.append("ProceduralFloor3D mesh is missing per-vertex normal data")
	if colors.size() != vertices.size():
		m_failures.append("ProceduralFloor3D mesh is missing per-vertex color data")
	if !normals.is_empty() and normals[0].dot(Vector3.UP) < 0.999:
		m_failures.append("ProceduralFloor3D top face normal is not upward")
	if indices.size() >= 3 and !normals.is_empty():
		var a := vertices[indices[0]]
		var b := vertices[indices[1]]
		var c := vertices[indices[2]]
		var winding_normal := (b - a).cross(c - a).normalized()
		if winding_normal.dot(normals[indices[0]]) > -0.999:
			m_failures.append("ProceduralFloor3D triangle winding does not match Godot BoxMesh convention")
	var min_y := INF
	var max_y := -INF
	for vertex in vertices:
		min_y = minf(min_y, vertex.y)
		max_y = maxf(max_y, vertex.y)
	if absf(max_y) > 0.001 or absf(min_y + 0.18) > 0.001:
		m_failures.append("ProceduralFloor3D did not extend thickness downward from the top surface")
	if floor.get_node_or_null("FloorCollision") == null:
		m_failures.append("ProceduralFloor3D did not generate collision for placed floors")

	floor.set_floor_corners(Vector3(1.0, top_y, 12.5), Vector3(4.5, top_y, 15.0))
	var edited_size := floor.get_floor_size()
	if absf(edited_size.x - 3.5) > 0.001 or absf(edited_size.y - 2.5) > 0.001:
		m_failures.append("ProceduralFloor3D did not resize from edited corners: %s" % str(edited_size))
	if floor.position.distance_to(Vector3(1.0, top_y, 12.5)) > 0.001:
		m_failures.append("ProceduralFloor3D did not move transform after edited corners")


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
		m_failures.append("ProceduralPillar3D did not generate a mesh")
		return
	if pillar.mesh.get_surface_count() <= 0:
		m_failures.append("ProceduralPillar3D mesh has no surfaces")
		return
	if pillar.position.distance_to(Vector3(6.0, base_y, 12.0)) > 0.001:
		m_failures.append("ProceduralPillar3D did not place its transform at the base point")

	var arrays := pillar.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if vertices.size() != pillar.side_count * 10:
		m_failures.append("ProceduralPillar3D generated the wrong low-poly vertex count")
	if normals.size() != vertices.size():
		m_failures.append("ProceduralPillar3D mesh is missing per-vertex normal data")
	if colors.size() != vertices.size():
		m_failures.append("ProceduralPillar3D mesh is missing per-vertex color data")
	if !_has_normal_near(normals, Vector3.UP):
		m_failures.append("ProceduralPillar3D mesh is missing top normals")
	if !_has_normal_near(normals, Vector3.DOWN):
		m_failures.append("ProceduralPillar3D mesh is missing bottom normals")
	if !_has_horizontal_pillar_normal(normals):
		m_failures.append("ProceduralPillar3D mesh is missing side normals")
	if indices.size() >= 3 and !normals.is_empty():
		var a := vertices[indices[0]]
		var b := vertices[indices[1]]
		var c := vertices[indices[2]]
		var winding_normal := (b - a).cross(c - a).normalized()
		if winding_normal.dot(normals[indices[0]]) > -0.999:
			m_failures.append("ProceduralPillar3D triangle winding does not match Godot BoxMesh convention")
	if pillar.get_node_or_null("PillarCollision") == null:
		m_failures.append("ProceduralPillar3D did not generate collision for placed pillars")

	pillar.set_pillar_base_and_radius(Vector3(7.0, base_y, 13.0), 0.5)
	if pillar.position.distance_to(Vector3(7.0, base_y, 13.0)) > 0.001:
		m_failures.append("ProceduralPillar3D did not move transform after edited base point")
	if absf(pillar.pillar_radius - 0.5) > 0.001:
		m_failures.append("ProceduralPillar3D did not resize edited radius")

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
		m_failures.append("ProceduralPillar3D did not store square style")
	if _mesh_vertex_count(square) != 40:
		m_failures.append("ProceduralPillar3D square style did not force four low-poly sides")

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
		m_failures.append("ProceduralPillar3D octagonal style did not force eight low-poly sides")

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
		m_failures.append("ProceduralPillar3D tapered style did not narrow the top radius")

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
		m_failures.append("ProceduralPillar3D did not store custom upper radius")
	if _pillar_max_radius_at_y(custom_radii, 2.4) >= _pillar_max_radius_at_y(custom_radii, 0.0):
		m_failures.append("ProceduralPillar3D custom upper radius did not narrow the top")
	if absf(_pillar_max_radius_at_y(custom_radii, 2.4) - 0.18) > 0.001:
		m_failures.append("ProceduralPillar3D custom upper radius did not generate the requested top radius")

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
		m_failures.append("ProceduralPillar3D rimmed style did not add expected rim geometry")
	if _pillar_max_radius_at_y(rimmed, 0.0) <= rimmed.pillar_radius:
		m_failures.append("ProceduralPillar3D lower rim did not expand the base radius")
	if _pillar_max_radius_at_y(rimmed, 2.4) <= rimmed.pillar_radius:
		m_failures.append("ProceduralPillar3D upper rim did not expand the top radius")
	if rimmed.get_outer_radius() <= rimmed.pillar_radius:
		m_failures.append("ProceduralPillar3D outer radius did not include rim outsets")
	var rim_collision_shape := rimmed.get_node_or_null("PillarCollision/CollisionShape3D") as CollisionShape3D
	var rim_collision: CylinderShape3D = null
	if rim_collision_shape != null:
		rim_collision = rim_collision_shape.shape as CylinderShape3D
	if rim_collision == null or rim_collision.radius + 0.001 < rimmed.get_outer_radius():
		m_failures.append("ProceduralPillar3D rimmed collision did not cover the outer rim")


func _validate_roof_node(coordinator: BuildingEditor3DScript) -> void:
	var base_y := 3.0
	var roof := coordinator.create_roof_node(
		Vector3(12.0, base_y, 12.0),
		Vector3(16.0, base_y, 15.0),
		"gable",
		0.9,
		0.16,
		0.25,
		Color(0.50, 0.34, 0.25, 1.0)
	)
	coordinator.add_child(roof)
	if roof.mesh == null:
		m_failures.append("ProceduralRoof3D did not generate a mesh")
		return
	if roof.mesh.get_surface_count() <= 0:
		m_failures.append("ProceduralRoof3D mesh has no surfaces")
		return
	if roof.position.distance_to(Vector3(12.0, base_y, 12.0)) > 0.001:
		m_failures.append("ProceduralRoof3D did not place its transform at the minimum footprint corner")

	var arrays := roof.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if vertices.size() != 48:
		m_failures.append("ProceduralRoof3D gable style generated the wrong low-poly vertex count")
	if normals.size() != vertices.size():
		m_failures.append("ProceduralRoof3D mesh is missing per-vertex normal data")
	if colors.size() != vertices.size():
		m_failures.append("ProceduralRoof3D mesh is missing per-vertex color data")
	if !_has_roof_upward_normal(normals):
		m_failures.append("ProceduralRoof3D mesh is missing upward roof normals")
	if !_has_roof_downward_normal(normals):
		m_failures.append("ProceduralRoof3D mesh is missing underside normals")
	if !_has_horizontal_pillar_normal(normals):
		m_failures.append("ProceduralRoof3D mesh is missing fascia normals")
	if indices.size() >= 3 and !normals.is_empty():
		var a := vertices[indices[0]]
		var b := vertices[indices[1]]
		var c := vertices[indices[2]]
		var winding_normal := (b - a).cross(c - a).normalized()
		if winding_normal.dot(normals[indices[0]]) > -0.999:
			m_failures.append("ProceduralRoof3D triangle winding does not match Godot BoxMesh convention")
	if roof.get_node_or_null("RoofCollision") == null:
		m_failures.append("ProceduralRoof3D did not generate collision for placed roofs")
	if roof.get_roof_bounds_min().distance_to(Vector3(-0.25, -0.16, -0.25)) > 0.001:
		m_failures.append("ProceduralRoof3D bounds did not include overhang and thickness")
	if roof.get_roof_bounds_max().distance_to(Vector3(4.25, 0.9, 3.25)) > 0.001:
		m_failures.append("ProceduralRoof3D bounds did not include overhang and roof rise")

	roof.set_roof_corners(Vector3(13.0, base_y, 12.5), Vector3(17.0, base_y, 16.0))
	if roof.position.distance_to(Vector3(13.0, base_y, 12.5)) > 0.001:
		m_failures.append("ProceduralRoof3D did not move transform after edited corners")
	if roof.get_roof_size().distance_to(Vector2(4.0, 3.5)) > 0.001:
		m_failures.append("ProceduralRoof3D did not resize edited footprint")
	var old_roof_center := roof.get_roof_center_point()
	roof.set_roof_rotation_around_center(90.0)
	if absf(angle_difference(deg_to_rad(roof.roof_rotation_degrees), deg_to_rad(90.0))) > deg_to_rad(0.5):
		m_failures.append("ProceduralRoof3D did not store edited roof rotation")
	if roof.get_roof_center_point().distance_to(old_roof_center) > 0.001:
		m_failures.append("ProceduralRoof3D did not preserve footprint center when rotating")
	if roof.transform.basis.is_equal_approx(Basis.IDENTITY):
		m_failures.append("ProceduralRoof3D did not apply rotation to its transform")

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
		m_failures.append("ProceduralRoof3D did not store flat style")
	if _mesh_vertex_count(flat) != 28:
		m_failures.append("ProceduralRoof3D flat style generated the wrong vertex count")
	var flat_arrays := flat.mesh.surface_get_arrays(0)
	var flat_normals: PackedVector3Array = flat_arrays[Mesh.ARRAY_NORMAL]
	if !_has_normal_near(flat_normals, Vector3.UP):
		m_failures.append("ProceduralRoof3D flat style is missing a flat top normal")

	var shed := coordinator.create_roof_node(
		Vector3(22.0, base_y, 12.0),
		Vector3(25.0, base_y, 14.0),
		"shed",
		0.75,
		0.12,
		0.1,
		Color(0.50, 0.34, 0.25, 1.0)
	)
	coordinator.add_child(shed)
	if _mesh_vertex_count(shed) != 28:
		m_failures.append("ProceduralRoof3D shed style generated the wrong vertex count")
	if !_has_roof_sloped_normal(shed):
		m_failures.append("ProceduralRoof3D shed style is missing sloped roof normals")

	var hip := coordinator.create_roof_node(
		Vector3(26.0, base_y, 12.0),
		Vector3(29.0, base_y, 15.0),
		"hip",
		0.9,
		0.12,
		0.15,
		Color(0.50, 0.34, 0.25, 1.0)
	)
	coordinator.add_child(hip)
	if _mesh_vertex_count(hip) != 40:
		m_failures.append("ProceduralRoof3D hip style generated the wrong vertex count")
	if !_has_roof_sloped_normal(hip):
		m_failures.append("ProceduralRoof3D hip style is missing sloped roof normals")

	var merge_color := Color(0.42, 0.30, 0.22, 1.0)
	var merge_target := coordinator.create_roof_node(
		Vector3(30.0, base_y, 12.0),
		Vector3(34.0, base_y, 15.0),
		"gable",
		0.9,
		0.16,
		0.25,
		merge_color
	)
	coordinator.add_child(merge_target)
	var merge := coordinator.find_roof_merge_target(
		Vector3(33.0, base_y, 14.0),
		Vector3(36.0, base_y, 17.0),
		"gable",
		0.9,
		0.16,
		0.25,
		merge_color,
		0.0
	)
	if merge.is_empty():
		m_failures.append("ProceduralRoof3D did not detect an intersecting roof merge target")
	else:
		if merge["roof"] != merge_target:
			m_failures.append("ProceduralRoof3D merge target selected the wrong roof")
		if Vector3(merge["start"]).distance_to(Vector3(30.0, base_y, 12.0)) > 0.001:
			m_failures.append("ProceduralRoof3D merge did not preserve the minimum footprint corner")
		if Vector3(merge["end"]).distance_to(Vector3(36.0, base_y, 17.0)) > 0.001:
			m_failures.append("ProceduralRoof3D merge did not expand to the maximum footprint corner")

	var mismatch := coordinator.find_roof_merge_target(
		Vector3(33.0, base_y, 14.0),
		Vector3(36.0, base_y, 17.0),
		"hip",
		0.9,
		0.16,
		0.25,
		merge_color,
		0.0
	)
	if !mismatch.is_empty():
		m_failures.append("ProceduralRoof3D merged roofs with different styles")
	var rotation_mismatch := coordinator.find_roof_merge_target(
		Vector3(33.0, base_y, 14.0),
		Vector3(36.0, base_y, 17.0),
		"gable",
		0.9,
		0.16,
		0.25,
		merge_color,
		90.0
	)
	if !rotation_mismatch.is_empty():
		m_failures.append("ProceduralRoof3D merged roofs with different rotations")

	var rotated_merge_target := coordinator.create_roof_node(
		Vector3(40.0, base_y, 12.0),
		Vector3(44.0, base_y, 15.0),
		"gable",
		0.9,
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
		0.9,
		0.16,
		0.25,
		merge_color,
		90.0
	)
	if rotated_merge.is_empty():
		m_failures.append("ProceduralRoof3D did not detect an intersecting rotated roof merge target")
	else:
		if rotated_merge["roof"] != rotated_merge_target:
			m_failures.append("ProceduralRoof3D rotated merge target selected the wrong roof")
		if absf(angle_difference(deg_to_rad(float(rotated_merge["rotation_degrees"])), deg_to_rad(90.0))) > deg_to_rad(0.5):
			m_failures.append("ProceduralRoof3D rotated merge did not preserve roof rotation")


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
		m_failures.append("ProceduralWall3D did not keep the split absorbed crossing segments")
	if survivor.mesh == null or survivor.mesh.get_surface_count() <= 0:
		m_failures.append("Multi-segment ProceduralWall3D did not generate a merged mesh")
		return
	if survivor.get_node_or_null("WallCollision") == null:
		m_failures.append("Multi-segment ProceduralWall3D did not generate collision")

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


func _validate_add_wall_joint() -> void:
	var wall := ProceduralWall3DScript.new() as ProceduralWall3DScript
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
	opening.set_meta(ProceduralWall3DScript.SEGMENT_INDEX_META, 0)
	wall.add_child(opening)
	wall.rebuild_wall_mesh()

	var old_opening_position := opening.global_position
	if !wall.split_segment_at_point(0, Vector3(2.0, 0.0, 0.0), 0.1):
		m_failures.append("ProceduralWall3D could not add a joint to a wall span")
		return
	if wall.get_segment_count() != 2:
		m_failures.append("ProceduralWall3D joint insertion did not split the wall into two segments")
	if wall.count_connected_endpoints(Vector3(2.0, 0.0, 0.0), 0.03) != 2:
		m_failures.append("ProceduralWall3D joint insertion did not create a shared endpoint")
	if opening.global_position.distance_to(old_opening_position) > 0.001:
		m_failures.append("ProceduralWall3D joint insertion moved an existing window opening")
	if wall.get_opening_segment_index(opening) != 1:
		m_failures.append("ProceduralWall3D joint insertion did not reassign opening to split segment")

	var moved_joint := Vector3(2.0, 0.0, 1.0)
	var moved_count := wall.move_connected_endpoint(Vector3(2.0, 0.0, 0.0), moved_joint, 0.03)
	if moved_count != 2:
		m_failures.append("ProceduralWall3D added joint moved %d endpoints instead of 2" % moved_count)
	if wall.count_connected_endpoints(moved_joint, 0.03) != 2:
		m_failures.append("ProceduralWall3D added joint did not stay editable after dragging")

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
	var corner := ProceduralWall3DScript.new() as ProceduralWall3DScript
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

	var end_start_corner := ProceduralWall3DScript.new() as ProceduralWall3DScript
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
) -> ProceduralWall3DScript:
	var corner := ProceduralWall3DScript.new() as ProceduralWall3DScript
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
	var wall := ProceduralWall3DScript.new() as ProceduralWall3DScript
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
		m_failures.append("ProceduralWall3D joint drag moved %d endpoints instead of 3" % moved_count)
	if wall.count_connected_endpoints(moved_joint, 0.03) != 3:
		m_failures.append("ProceduralWall3D joint drag did not preserve a shared editable endpoint")
	if wall.start_point.distance_to(moved_joint) > 0.001:
		m_failures.append("ProceduralWall3D joint drag did not move the primary endpoint")
	if wall.extra_segments[0].start_point.distance_to(moved_joint) > 0.001:
		m_failures.append("ProceduralWall3D joint drag did not move the first connected segment")
	if wall.extra_segments[1].start_point.distance_to(moved_joint) > 0.001:
		m_failures.append("ProceduralWall3D joint drag did not move the second connected segment")
	if wall.end_point.distance_to(Vector3(2.0, 0.0, 0.0)) > 0.001:
		m_failures.append("ProceduralWall3D joint drag moved an unconnected primary endpoint")
	if wall.extra_segments[2].start_point.distance_to(Vector3(4.0, 0.0, 0.0)) > 0.001:
		m_failures.append("ProceduralWall3D joint drag moved an unrelated segment endpoint")


func _validate_joint_disconnect_connect() -> void:
	var wall := ProceduralWall3DScript.new() as ProceduralWall3DScript
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
		m_failures.append("ProceduralWall3D could not detach a single endpoint from a joint")
	if wall.count_connected_endpoints(Vector3.ZERO, 0.03) != 2:
		m_failures.append("ProceduralWall3D detach did not leave the other joint endpoints connected")
	if wall.count_connected_endpoints(detached, 0.03) != 1:
		m_failures.append("ProceduralWall3D detach did not isolate the moved endpoint")
	if wall.extra_segments[1].start_point.distance_to(Vector3.ZERO) > 0.001:
		m_failures.append("ProceduralWall3D detach moved a different connected endpoint")

	if !wall.move_segment_endpoint(1, 0, Vector3.ZERO):
		m_failures.append("ProceduralWall3D could not reconnect a single endpoint to a joint")
	if wall.count_connected_endpoints(Vector3.ZERO, 0.03) != 3:
		m_failures.append("ProceduralWall3D reconnect did not restore the shared joint")


func _validate_connected_wall_top_caps() -> void:
	var wall := ProceduralWall3DScript.new() as ProceduralWall3DScript
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
	var joint := ProceduralWall3DScript.new() as ProceduralWall3DScript
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
	var loop := ProceduralWall3DScript.new() as ProceduralWall3DScript
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
	wall: ProceduralWall3DScript,
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


func _mesh_vertex_count(mesh_instance: MeshInstance3D) -> int:
	if mesh_instance == null or mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() <= 0:
		return 0
	var arrays := mesh_instance.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	return vertices.size()


func _has_roof_sloped_normal(mesh_instance: MeshInstance3D) -> bool:
	if mesh_instance == null or mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() <= 0:
		return false
	var arrays := mesh_instance.mesh.surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for normal in normals:
		if normal.y > 0.25 and normal.y < 0.98:
			return true
	return false


func _pillar_max_radius_at_y(pillar: ProceduralPillar3DScript, expected_y: float) -> float:
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


func _has_world_diagonal_wall_normal(wall: ProceduralWall3DScript) -> bool:
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


func _world_boundary_edge_count(wall: ProceduralWall3DScript) -> int:
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
