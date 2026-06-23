@tool
extends Node3D

const TEST_HEIGHTMAP_PATH := "user://low_poly_terrain_3d_heightmap_smoke.png"
const TEST_MASK_PATH := "user://low_poly_terrain_3d_mask_smoke.png"
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
	m_terrain.set("water_height", 0.18)
	m_terrain.set("land_height", 0.0)
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
		_configure_mask_clipped_smoke()
		_validate_mask_clipped_generation(failures)

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

	if m_terrain.get_node_or_null("WaterMesh") == null:
		failures.append("heightmap-expanded terrain did not generate heightmap-level water")
	if m_terrain.get_node_or_null("ShorelineMesh") != null:
		failures.append("heightmap-expanded terrain should continue land into seabed without vertical shoreline walls")

	var water_height := float(m_terrain.get("water_height"))
	var sample_stride := maxi(int(m_terrain.get("sample_stride")), 1)
	var grid_size := Vector2i(
		ceili(float(source_size.x) / float(sample_stride)),
		ceili(float(source_size.y) / float(sample_stride))
	)
	var low_sample := Vector2i.ZERO
	var high_sample := Vector2i(grid_size.x - 1, grid_size.y - 1)
	if int(m_terrain.call("get_sample_cell_kind", low_sample)) != TERRAIN_KIND_WATER:
		failures.append("heightmap-expanded terrain did not mark low heightmap samples as water")
	if int(m_terrain.call("get_sample_cell_kind", high_sample)) == TERRAIN_KIND_WATER:
		failures.append("heightmap-expanded terrain marked high heightmap samples as water")
	var low_sample_height := float(m_terrain.call("get_sample_cell_height", low_sample))
	if low_sample_height >= water_height - 0.005:
		failures.append("heightmap-expanded water samples should report land elevation below water level")

	if !m_terrain.has_method("get_sample_cell_water_surface_height"):
		failures.append("LowPolyTerrain3D is missing get_sample_cell_water_surface_height")
	else:
		var low_sample_water_surface := float(m_terrain.call("get_sample_cell_water_surface_height", low_sample))
		if !is_equal_approx(low_sample_water_surface, water_height):
			failures.append("water-surface query should report the flat water plane over water cells")

	var water_mesh := m_terrain.get_node_or_null("WaterMesh") as MeshInstance3D
	var shoreline_land_sample := _find_land_cell_adjacent_to_water(grid_size)
	if shoreline_land_sample == Vector2i(-1, -1):
		failures.append("heightmap-expanded terrain did not expose a shoreline land sample")
	elif water_mesh == null or water_mesh.mesh == null:
		failures.append("heightmap-expanded terrain did not generate WaterMesh for shoreline overlap checks")
	elif !_mesh_has_water_cell_corners(water_mesh.mesh, shoreline_land_sample, grid_size):
		failures.append("heightmap-expanded water did not overlap one adjacent shoreline land cell")

	var land_mesh := m_terrain.get_node_or_null("LandMesh") as MeshInstance3D
	if land_mesh == null or land_mesh.mesh == null:
		failures.append("heightmap-expanded terrain did not keep seabed terrain in LandMesh")
	else:
		var land_height_range := _get_mesh_height_range(land_mesh.mesh)
		if land_height_range.x >= water_height - 0.005:
			failures.append("heightmap-expanded terrain did not draw seabed below water level")
		if land_height_range.y <= water_height + 0.05:
			failures.append("heightmap-expanded terrain did not preserve dry land above water level")


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
	var water_height := float(m_terrain.get("water_height"))
	if absf(height_range.x - water_height) > 0.002 or absf(height_range.y - water_height) > 0.002:
		failures.append("LowPolyTerrain3D WaterMesh should be drawn flat at water height")

	var material := water_mesh.material_override as ShaderMaterial
	if material == null:
		failures.append("LowPolyTerrain3D WaterMesh is missing its animated shader material")
	elif float(material.get_shader_parameter(&"water_opacity")) >= 0.75:
		failures.append("LowPolyTerrain3D WaterMesh should be semi-transparent enough to reveal seabed")

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


func _configure_mask_clipped_smoke() -> void:
	if Engine.is_editor_hint():
		return
	if !is_instance_valid(m_terrain):
		return

	# Synthetic mask: transparent (water) 4-cell border ring around opaque white (land).
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var is_border := x < 4 or y < 4 or x >= 28 or y >= 28
			var alpha := 0.0 if is_border else 1.0
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))

	var save_error := image.save_png(TEST_MASK_PATH)
	if save_error != OK:
		push_error("failed to write low-poly terrain mask smoke image")
		return

	m_terrain.set("mask_file", TEST_MASK_PATH)
	m_terrain.set("heightmap_file", "")
	m_terrain.set("heightmap_expands_land_to_source", false)
	m_terrain.set("water_height", 0.0)
	m_terrain.set("land_height", 0.22)
	if m_terrain.has_method("rebuild_from_source"):
		m_terrain.call("rebuild_from_source")


func _validate_mask_clipped_generation(failures: Array[String]) -> void:
	var land_mesh := m_terrain.get_node_or_null("LandMesh") as MeshInstance3D
	if land_mesh == null or land_mesh.mesh == null:
		failures.append("mask-clipped terrain did not generate LandMesh")
	var water_mesh := m_terrain.get_node_or_null("WaterMesh") as MeshInstance3D
	if water_mesh == null or water_mesh.mesh == null:
		failures.append("mask-clipped terrain did not generate WaterMesh")
	var shoreline_mesh := m_terrain.get_node_or_null("ShorelineMesh") as MeshInstance3D
	if shoreline_mesh == null or shoreline_mesh.mesh == null:
		failures.append("mask-clipped terrain did not generate shoreline side walls")

	if !m_terrain.has_method("get_source_size") or !m_terrain.has_method("get_sample_cell_kind"):
		failures.append("LowPolyTerrain3D is missing source/kind query methods")
		return

	var source_size := Vector2i(m_terrain.call("get_source_size"))
	if source_size != Vector2i(32, 32):
		failures.append("mask-clipped terrain did not use the mask dimensions as its source size")

	var sample_stride := maxi(int(m_terrain.get("sample_stride")), 1)
	var grid_size := Vector2i(
		ceili(float(source_size.x) / float(sample_stride)),
		ceili(float(source_size.y) / float(sample_stride))
	)
	if int(m_terrain.call("get_sample_cell_kind", Vector2i.ZERO)) != TERRAIN_KIND_WATER:
		failures.append("mask-clipped terrain did not mark transparent border pixels as water")

	var center_cell := Vector2i(grid_size.x / 2, grid_size.y / 2)
	if int(m_terrain.call("get_sample_cell_kind", center_cell)) == TERRAIN_KIND_WATER:
		failures.append("mask-clipped terrain marked the opaque land interior as water")


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


func _find_land_cell_adjacent_to_water(grid_size: Vector2i) -> Vector2i:
	if !m_terrain.has_method("get_sample_cell_kind"):
		return Vector2i(-1, -1)

	var fallback_cell := Vector2i(-1, -1)
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var sample_cell := Vector2i(x, y)
			if int(m_terrain.call("get_sample_cell_kind", sample_cell)) == TERRAIN_KIND_WATER:
				continue
			var water_neighbors := _count_water_neighbors(sample_cell, grid_size)
			if water_neighbors <= 0:
				continue
			if fallback_cell == Vector2i(-1, -1):
				fallback_cell = sample_cell
			if water_neighbors == 1 and _has_cardinal_water_neighbor(sample_cell, grid_size):
				return sample_cell
	return fallback_cell


func _count_water_neighbors(sample_cell: Vector2i, grid_size: Vector2i) -> int:
	var water_neighbors := 0
	for y in range(sample_cell.y - 1, sample_cell.y + 2):
		for x in range(sample_cell.x - 1, sample_cell.x + 2):
			if x == sample_cell.x and y == sample_cell.y:
				continue
			if x < 0 or x >= grid_size.x or y < 0 or y >= grid_size.y:
				continue
			if int(m_terrain.call("get_sample_cell_kind", Vector2i(x, y))) == TERRAIN_KIND_WATER:
				water_neighbors += 1
	return water_neighbors


func _has_cardinal_water_neighbor(sample_cell: Vector2i, grid_size: Vector2i) -> bool:
	var neighbor_offsets: Array[Vector2i] = [
		Vector2i(0, -1),
		Vector2i(1, 0),
		Vector2i(0, 1),
		Vector2i(-1, 0),
	]
	for neighbor_offset in neighbor_offsets:
		var neighbor_cell := sample_cell + neighbor_offset
		if neighbor_cell.x < 0 or neighbor_cell.x >= grid_size.x or neighbor_cell.y < 0 or neighbor_cell.y >= grid_size.y:
			continue
		if int(m_terrain.call("get_sample_cell_kind", neighbor_cell)) == TERRAIN_KIND_WATER:
			return true
	return false


func _mesh_has_water_cell_corners(mesh: Mesh, sample_cell: Vector2i, grid_size: Vector2i) -> bool:
	var cell_size := float(m_terrain.get("cell_size"))
	var origin := Vector2(
		-float(grid_size.x) * cell_size * 0.5,
		-float(grid_size.y) * cell_size * 0.5
	)
	var min_x := origin.x + float(sample_cell.x) * cell_size
	var max_x := min_x + cell_size
	var min_z := origin.y + float(sample_cell.y) * cell_size
	var max_z := min_z + cell_size
	var corners: Array[Vector2] = [
		Vector2(min_x, min_z),
		Vector2(max_x, min_z),
		Vector2(max_x, max_z),
		Vector2(min_x, max_z),
	]
	var water_height := float(m_terrain.get("water_height"))
	for corner in corners:
		if !_mesh_has_vertex_at_water_corner(mesh, corner, water_height):
			return false
	return true


func _mesh_has_vertex_at_water_corner(mesh: Mesh, corner: Vector2, water_height: float) -> bool:
	for surface_index in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			if absf(vertex.x - corner.x) <= 0.002 and absf(vertex.z - corner.y) <= 0.002 and absf(vertex.y - water_height) <= 0.002:
				return true
	return false
