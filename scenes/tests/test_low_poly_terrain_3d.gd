@tool
extends Node3D

const TEST_HEIGHTMAP_PATH := "user://low_poly_terrain_3d_heightmap_smoke.png"

@onready var m_terrain: Node3D = $LowPolyTerrain3D
@onready var m_camera: Camera3D = $Camera3D
@onready var m_sun: DirectionalLight3D = $Sun


func _ready() -> void:
	_configure_heightmap_smoke()

	if is_instance_valid(m_camera):
		m_camera.look_at(Vector3.ZERO, Vector3.UP)
	if is_instance_valid(m_sun):
		m_sun.look_at(Vector3(-20.0, -18.0, -8.0), Vector3.UP)

	if Engine.is_editor_hint():
		return

	call_deferred("_run_smoke_checks")


func _configure_heightmap_smoke() -> void:
	if Engine.is_editor_hint():
		return
	if !is_instance_valid(m_terrain):
		return

	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var gradient := float(x + y) / float(image.get_width() + image.get_height() - 2)
			image.set_pixel(x, y, Color(gradient, gradient, gradient, 1.0))

	var save_error := image.save_png(TEST_HEIGHTMAP_PATH)
	if save_error != OK:
		push_error("failed to write low-poly terrain smoke heightmap")
		return

	m_terrain.set("heightmap_file", TEST_HEIGHTMAP_PATH)
	m_terrain.set("heightmap_min_offset", 0.0)
	m_terrain.set("heightmap_max_offset", 0.42)
	if m_terrain.has_method("rebuild_from_source"):
		m_terrain.call("rebuild_from_source")


func _run_smoke_checks() -> void:
	var failures: Array[String] = []
	if !is_instance_valid(m_terrain):
		failures.append("missing LowPolyTerrain3D")
	else:
		_validate_heightmap_terrain(failures)

	if failures.is_empty():
		print("PASS: LowPolyTerrain3D heightmap smoke test")
	else:
		for failure in failures:
			push_error(failure)


func _validate_heightmap_terrain(failures: Array[String]) -> void:
	var land_mesh := m_terrain.get_node_or_null("LandMesh") as MeshInstance3D
	if land_mesh == null:
		failures.append("LowPolyTerrain3D did not generate LandMesh")
		return
	if land_mesh.mesh == null:
		failures.append("LowPolyTerrain3D LandMesh is missing mesh data")
		return

	var height_range := _get_mesh_height_range(land_mesh.mesh)
	if height_range.y - height_range.x <= 0.05:
		failures.append("heightmap did not create visible terrain height variation")

	if !_mesh_has_sloped_triangles(land_mesh.mesh):
		failures.append("smooth terrain mesh did not create sloped land facets")

	if !m_terrain.has_method("get_sample_cell_height"):
		failures.append("LowPolyTerrain3D is missing get_sample_cell_height")
		return

	var center_height := float(m_terrain.call("get_sample_cell_height", Vector2i(64, 64)))
	var base_land_height := float(m_terrain.get("land_height"))
	if center_height <= base_land_height:
		failures.append("sample cell height did not include heightmap offset")


func _get_mesh_height_range(mesh: Mesh) -> Vector2:
	var min_height := INF
	var max_height := -INF
	for surface_index in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			min_height = minf(min_height, vertex.y)
			max_height = maxf(max_height, vertex.y)
	if min_height == INF:
		return Vector2.ZERO
	return Vector2(min_height, max_height)


func _mesh_has_sloped_triangles(mesh: Mesh) -> bool:
	for surface_index in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for index in range(0, indices.size(), 3):
			var a := vertices[indices[index]]
			var b := vertices[indices[index + 1]]
			var c := vertices[indices[index + 2]]
			var min_height := minf(a.y, minf(b.y, c.y))
			var max_height := maxf(a.y, maxf(b.y, c.y))
			if max_height - min_height > 0.001:
				return true
	return false
