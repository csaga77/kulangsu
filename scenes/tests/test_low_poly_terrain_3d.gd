@tool
extends Node3D

const TEST_HEIGHTMAP_PATH := "user://low_poly_terrain_3d_heightmap_smoke.png"
const TERRAIN_KIND_WATER := 0

@onready var m_terrain: Node3D = $LowPolyTerrain3D
@onready var m_camera: Camera3D = $Camera3D
@onready var m_sun: DirectionalLight3D = $Sun


func _ready() -> void:
	_configure_heightmap_smoke(true)

	if is_instance_valid(m_camera):
		m_camera.look_at(Vector3.ZERO, Vector3.UP)
	if is_instance_valid(m_sun):
		m_sun.look_at(Vector3(-20.0, -18.0, -8.0), Vector3.UP)

	if Engine.is_editor_hint():
		return

	call_deferred("_run_smoke_checks")


func _configure_heightmap_smoke(expands_land_to_source: bool) -> void:
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
	m_terrain.set("heightmap_expands_land_to_source", expands_land_to_source)
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
		_validate_heightmap_source_expansion(failures)
		_configure_heightmap_smoke(false)
		_validate_water_rendering(failures)

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


func _validate_heightmap_source_expansion(failures: Array[String]) -> void:
	if !m_terrain.has_method("get_source_size"):
		failures.append("LowPolyTerrain3D is missing get_source_size")
		return
	if !m_terrain.has_method("get_sample_cell_kind"):
		failures.append("LowPolyTerrain3D is missing get_sample_cell_kind")
		return

	var source_size := Vector2i(m_terrain.call("get_source_size"))
	if source_size != Vector2i(32, 32):
		failures.append("heightmap-expanded terrain did not use the heightmap dimensions as its source size")

	if m_terrain.get_node_or_null("WaterMesh") != null:
		failures.append("heightmap-expanded terrain should not generate mask-clipped water")

	var sample_stride := maxi(int(m_terrain.get("sample_stride")), 1)
	var grid_size := Vector2i(
		ceili(float(source_size.x) / float(sample_stride)),
		ceili(float(source_size.y) / float(sample_stride))
	)
	var sample_cells: Array[Vector2i] = [
		Vector2i.ZERO,
		Vector2i(grid_size.x - 1, 0),
		Vector2i(0, grid_size.y - 1),
		Vector2i(grid_size.x - 1, grid_size.y - 1),
	]
	for sample_cell in sample_cells:
		var kind := int(m_terrain.call("get_sample_cell_kind", sample_cell))
		if kind == TERRAIN_KIND_WATER:
			failures.append("heightmap-expanded terrain left source cell %s as water" % sample_cell)


func _validate_water_rendering(failures: Array[String]) -> void:
	var water_mesh := m_terrain.get_node_or_null("WaterMesh") as MeshInstance3D
	if water_mesh == null:
		failures.append("LowPolyTerrain3D did not generate WaterMesh")
		return
	if water_mesh.mesh == null:
		failures.append("LowPolyTerrain3D WaterMesh is missing mesh data")
		return

	if !_mesh_has_vertex_colors(water_mesh.mesh):
		failures.append("LowPolyTerrain3D WaterMesh is missing low-poly vertex colors")

	var height_range := _get_mesh_height_range(water_mesh.mesh)
	if height_range.y - height_range.x <= 0.005:
		failures.append("LowPolyTerrain3D WaterMesh did not create faceted water height variation")

	var surface_layer_mesh := m_terrain.get_node_or_null("WaterSurfaceLayerMesh") as MeshInstance3D
	if surface_layer_mesh == null:
		failures.append("LowPolyTerrain3D did not generate WaterSurfaceLayerMesh")
	elif surface_layer_mesh.mesh == null:
		failures.append("LowPolyTerrain3D WaterSurfaceLayerMesh is missing mesh data")
	else:
		_validate_surface_layer(surface_layer_mesh, failures)

	var shoreline_mesh := m_terrain.get_node_or_null("WaterShorelineMesh") as MeshInstance3D
	if shoreline_mesh == null:
		failures.append("LowPolyTerrain3D did not generate WaterShorelineMesh")
	elif shoreline_mesh.mesh == null:
		failures.append("LowPolyTerrain3D WaterShorelineMesh is missing mesh data")


func _validate_surface_layer(surface_layer_mesh: MeshInstance3D, failures: Array[String]) -> void:
	var material := surface_layer_mesh.material_override as StandardMaterial3D
	if material == null:
		failures.append("LowPolyTerrain3D WaterSurfaceLayerMesh is missing its material")
	elif material.albedo_color.a >= 0.99:
		failures.append("LowPolyTerrain3D WaterSurfaceLayerMesh should be semi-transparent")

	var height_range := _get_mesh_height_range(surface_layer_mesh.mesh)
	var water_height := float(m_terrain.get("water_height"))
	if height_range.x <= water_height:
		failures.append("LowPolyTerrain3D WaterSurfaceLayerMesh was not lifted above water height")


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


func _mesh_has_vertex_colors(mesh: Mesh) -> bool:
	for surface_index in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface_index)
		var colors_value: Variant = arrays[Mesh.ARRAY_COLOR]
		if colors_value is PackedColorArray and colors_value.size() > 0:
			return true
	return false
