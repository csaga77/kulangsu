@tool
extends Node3D

const BuildingEditor3DScript = preload("res://addons/low_poly_building_editor/building_editor_3d.gd")
const ProceduralWall3DScript = preload("res://addons/low_poly_building_editor/procedural_wall_3d.gd")
const BuildingOpening3DScript = preload("res://addons/low_poly_building_editor/building_opening_3d.gd")

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
