@tool
extends Node3D

const BuildingEditor3DScript = preload("res://addons/low_poly_building_editor/building_editor_3d.gd")
const ProceduralWall3DScript = preload("res://addons/low_poly_building_editor/procedural_wall_3d.gd")
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
	_validate_snapping(coordinator)
	_validate_merge_detection(coordinator)
	_validate_intersection_merge()

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


func _validate_snapping(coordinator: BuildingEditor3DScript) -> void:
	var snapped: Vector3 = coordinator.snap_local_position(Vector3(0.26, 0.0, 0.74))
	if snapped != Vector3(0.5, 0.0, 0.5):
		m_failures.append("BuildingEditor3D grid snapping returned %s" % str(snapped))
	var constrained: Vector3 = coordinator.constrain_wall_end(Vector3.ZERO, Vector3(1.1, 0.0, 0.8))
	if !is_equal_approx(absf(constrained.x), absf(constrained.z)):
		m_failures.append("BuildingEditor3D did not constrain diagonal drawing to 45 degrees")


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
