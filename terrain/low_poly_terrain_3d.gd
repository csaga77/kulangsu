@tool
class_name LowPolyTerrain3D
extends Node3D

const GENERATED_META := &"low_poly_terrain_generated"

enum TerrainCellKind {
	WATER,
	LAND,
	STREET,
	BUILDING,
}

@export var rebuild: bool = false:
	set(value):
		if !value:
			return
		call_deferred("_rebuild_from_source")

@export_file_path("*.png") var mask_file: String = "res://design/gulangyu_map_mini_export.png":
	set(new_mask_file):
		if mask_file == new_mask_file:
			return
		mask_file = new_mask_file
		_request_rebuild()

@export var generation_profile: TerrainGenerationProfile:
	set(new_profile):
		if generation_profile == new_profile:
			return
		generation_profile = new_profile
		_request_rebuild()

@export_range(1, 32, 1) var sample_stride := 4:
	set(new_stride):
		var clamped_stride := maxi(new_stride, 1)
		if sample_stride == clamped_stride:
			return
		sample_stride = clamped_stride
		_request_rebuild()

@export_range(0.1, 10.0, 0.1) var cell_size := 1.0:
	set(new_cell_size):
		var clamped_size := maxf(new_cell_size, 0.1)
		if is_equal_approx(cell_size, clamped_size):
			return
		cell_size = clamped_size
		_request_rebuild()

@export_range(0.0, 4.0, 0.01) var water_height := 0.0:
	set(new_height):
		if is_equal_approx(water_height, new_height):
			return
		water_height = new_height
		_request_rebuild()

@export_range(0.0, 4.0, 0.01) var land_height := 0.22:
	set(new_height):
		if is_equal_approx(land_height, new_height):
			return
		land_height = new_height
		_request_rebuild()

@export_range(0.0, 1.0, 0.01) var street_lift := 0.02:
	set(new_lift):
		if is_equal_approx(street_lift, new_lift):
			return
		street_lift = new_lift
		_request_rebuild()

@export_range(0.0, 2.0, 0.01) var building_footprint_lift := 0.09:
	set(new_lift):
		if is_equal_approx(building_footprint_lift, new_lift):
			return
		building_footprint_lift = new_lift
		_request_rebuild()

@export var land_color := Color(0.48, 0.71, 0.47, 1.0):
	set(new_color):
		if land_color == new_color:
			return
		land_color = new_color
		_request_rebuild()

@export var shoreline_color := Color(0.32, 0.47, 0.32, 1.0):
	set(new_color):
		if shoreline_color == new_color:
			return
		shoreline_color = new_color
		_request_rebuild()

@export var street_color := Color(0.80, 0.74, 0.62, 1.0):
	set(new_color):
		if street_color == new_color:
			return
		street_color = new_color
		_request_rebuild()

@export var building_footprint_color := Color(0.72, 0.52, 0.38, 1.0):
	set(new_color):
		if building_footprint_color == new_color:
			return
		building_footprint_color = new_color
		_request_rebuild()

@export var water_color := Color(0.42, 0.68, 0.83, 0.78):
	set(new_color):
		if water_color == new_color:
			return
		water_color = new_color
		_request_rebuild()

@export var generate_collision := true:
	set(new_generate_collision):
		if generate_collision == new_generate_collision:
			return
		generate_collision = new_generate_collision
		_request_rebuild()

@export var build_on_ready := true
@export var print_summary := true

var m_is_ready := false
var m_rebuild_queued := false


func _ready() -> void:
	m_is_ready = true
	if build_on_ready:
		_rebuild_from_source()


func _request_rebuild() -> void:
	if !m_is_ready:
		return
	if m_rebuild_queued:
		return
	m_rebuild_queued = true
	call_deferred("_rebuild_from_source")


func _rebuild_from_source() -> void:
	m_rebuild_queued = false
	_clear_generated_children()

	if mask_file.is_empty():
		push_warning("LowPolyTerrain3D requires a mask_file.")
		return

	var profile := _get_generation_profile()
	if profile == null:
		return

	var image := Image.new()
	var load_error := image.load(mask_file)
	if load_error != OK:
		push_error("LowPolyTerrain3D failed to load mask image: %s (err=%d)" % [mask_file, load_error])
		return

	if image.is_compressed():
		image.decompress()
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)

	var grid := _build_sample_grid(image, profile)
	_build_meshes_from_grid(grid, image.get_width(), image.get_height())


func _get_generation_profile() -> TerrainGenerationProfile:
	var profile := generation_profile
	if profile == null:
		profile = TerrainGenerationProfile.create_default_profile()
	profile.ensure_defaults()
	if !profile.is_valid_profile():
		return null
	return profile


func _build_sample_grid(image: Image, profile: TerrainGenerationProfile) -> Array[Array]:
	var grid: Array[Array] = []
	var width := image.get_width()
	var height := image.get_height()
	var grid_width := ceili(float(width) / float(sample_stride))
	var grid_height := ceili(float(height) / float(sample_stride))

	for grid_y in range(grid_height):
		var row: Array[TerrainCellKind] = []
		var start_y := grid_y * sample_stride
		for grid_x in range(grid_width):
			var start_x := grid_x * sample_stride
			row.append(_classify_sample_block(image, profile, start_x, start_y))
		grid.append(row)

	return grid


func _classify_sample_block(
	image: Image,
	profile: TerrainGenerationProfile,
	start_x: int,
	start_y: int
) -> TerrainCellKind:
	var end_x := mini(start_x + sample_stride, image.get_width())
	var end_y := mini(start_y + sample_stride, image.get_height())
	var land_count := 0
	var street_count := 0
	var building_count := 0

	for y in range(start_y, end_y):
		for x in range(start_x, end_x):
			var pixel := image.get_pixel(x, y)
			if profile.is_water_pixel(pixel):
				continue

			var rule := profile.resolve_rule_for_pixel(pixel)
			if rule == null:
				continue

			land_count += 1
			if rule.paint_street:
				street_count += 1
			if rule.paint_building_mask:
				building_count += 1

	if land_count <= 0:
		return TerrainCellKind.WATER
	if street_count > 0:
		return TerrainCellKind.STREET
	if building_count > 0:
		return TerrainCellKind.BUILDING
	return TerrainCellKind.LAND


func _build_meshes_from_grid(grid: Array[Array], source_width: int, source_height: int) -> void:
	if grid.is_empty():
		return

	var grid_height := grid.size()
	var grid_width := grid[0].size()
	var origin_offset := Vector3(
		-float(grid_width) * cell_size * 0.5,
		0.0,
		-float(grid_height) * cell_size * 0.5
	)

	var land_builder := _MeshBuildState.new()
	var shoreline_builder := _MeshBuildState.new()
	var water_builder := _MeshBuildState.new()
	var street_builder := _MeshBuildState.new()
	var building_builder := _MeshBuildState.new()
	var collision_faces := PackedVector3Array()

	var land_cells := 0
	var street_cells := 0
	var building_cells := 0
	var water_cells := 0

	for y in range(grid_height):
		for x in range(grid_width):
			var kind: TerrainCellKind = grid[y][x]
			var min_x := origin_offset.x + float(x) * cell_size
			var max_x := min_x + cell_size
			var min_z := origin_offset.z + float(y) * cell_size
			var max_z := min_z + cell_size

			match kind:
				TerrainCellKind.WATER:
					water_cells += 1
					_append_top_quad(water_builder, min_x, max_x, min_z, max_z, water_height)
				TerrainCellKind.STREET:
					street_cells += 1
					land_cells += 1
					_append_land_cell(
						grid,
						x,
						y,
						min_x,
						max_x,
						min_z,
						max_z,
						land_builder,
						shoreline_builder,
						collision_faces
					)
					_append_inset_top_quad(street_builder, min_x, max_x, min_z, max_z, land_height + street_lift, 0.08)
				TerrainCellKind.BUILDING:
					building_cells += 1
					land_cells += 1
					_append_land_cell(
						grid,
						x,
						y,
						min_x,
						max_x,
						min_z,
						max_z,
						land_builder,
						shoreline_builder,
						collision_faces
					)
					_append_inset_top_quad(
						building_builder,
						min_x,
						max_x,
						min_z,
						max_z,
						land_height + building_footprint_lift,
						0.14
					)
				_:
					land_cells += 1
					_append_land_cell(
						grid,
						x,
						y,
						min_x,
						max_x,
						min_z,
						max_z,
						land_builder,
						shoreline_builder,
						collision_faces
					)

	_add_mesh_instance("WaterMesh", water_builder, _build_material("Low Poly Water", water_color, true))
	_add_mesh_instance("LandMesh", land_builder, _build_material("Low Poly Land", land_color, false))
	_add_mesh_instance("ShorelineMesh", shoreline_builder, _build_material("Low Poly Shoreline", shoreline_color, false))
	_add_mesh_instance("StreetMesh", street_builder, _build_material("Low Poly Streets", street_color, false))
	_add_mesh_instance(
		"BuildingFootprintMesh",
		building_builder,
		_build_material("Low Poly Building Footprints", building_footprint_color, false)
	)

	if generate_collision:
		_add_collision_body(collision_faces)

	if print_summary:
		print(
			"LowPolyTerrain3D: built %dx%d source mask into %dx%d sampled cells (%d land, %d street, %d building, %d water)."
			% [source_width, source_height, grid_width, grid_height, land_cells, street_cells, building_cells, water_cells]
		)


func _append_land_cell(
	grid: Array[Array],
	x: int,
	y: int,
	min_x: float,
	max_x: float,
	min_z: float,
	max_z: float,
	land_builder: _MeshBuildState,
	shoreline_builder: _MeshBuildState,
	collision_faces: PackedVector3Array
) -> void:
	var a := Vector3(min_x, land_height, min_z)
	var b := Vector3(max_x, land_height, min_z)
	var c := Vector3(max_x, land_height, max_z)
	var d := Vector3(min_x, land_height, max_z)
	_append_quad(land_builder, a, b, c, d, Vector3.UP)
	_append_collision_quad(collision_faces, a, b, c, d)

	if _is_water_or_outside(grid, x, y - 1):
		_append_side_quad(
			shoreline_builder,
			Vector3(max_x, land_height, min_z),
			Vector3(min_x, land_height, min_z),
			Vector3(min_x, water_height, min_z),
			Vector3(max_x, water_height, min_z),
			Vector3(0.0, 0.0, -1.0)
		)
	if _is_water_or_outside(grid, x + 1, y):
		_append_side_quad(
			shoreline_builder,
			Vector3(max_x, land_height, max_z),
			Vector3(max_x, land_height, min_z),
			Vector3(max_x, water_height, min_z),
			Vector3(max_x, water_height, max_z),
			Vector3(1.0, 0.0, 0.0)
		)
	if _is_water_or_outside(grid, x, y + 1):
		_append_side_quad(
			shoreline_builder,
			Vector3(min_x, land_height, max_z),
			Vector3(max_x, land_height, max_z),
			Vector3(max_x, water_height, max_z),
			Vector3(min_x, water_height, max_z),
			Vector3(0.0, 0.0, 1.0)
		)
	if _is_water_or_outside(grid, x - 1, y):
		_append_side_quad(
			shoreline_builder,
			Vector3(min_x, land_height, min_z),
			Vector3(min_x, land_height, max_z),
			Vector3(min_x, water_height, max_z),
			Vector3(min_x, water_height, min_z),
			Vector3(-1.0, 0.0, 0.0)
		)


func _append_top_quad(builder: _MeshBuildState, min_x: float, max_x: float, min_z: float, max_z: float, height: float) -> void:
	_append_quad(
		builder,
		Vector3(min_x, height, min_z),
		Vector3(max_x, height, min_z),
		Vector3(max_x, height, max_z),
		Vector3(min_x, height, max_z),
		Vector3.UP
	)


func _append_inset_top_quad(
	builder: _MeshBuildState,
	min_x: float,
	max_x: float,
	min_z: float,
	max_z: float,
	height: float,
	inset_ratio: float
) -> void:
	var inset_x := (max_x - min_x) * inset_ratio
	var inset_z := (max_z - min_z) * inset_ratio
	_append_top_quad(builder, min_x + inset_x, max_x - inset_x, min_z + inset_z, max_z - inset_z, height)


func _append_side_quad(
	builder: _MeshBuildState,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	normal: Vector3
) -> void:
	_append_quad(builder, a, b, c, d, normal)


func _append_quad(
	builder: _MeshBuildState,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	normal: Vector3
) -> void:
	var start_index := builder.vertices.size()
	builder.vertices.append(a)
	builder.vertices.append(b)
	builder.vertices.append(c)
	builder.vertices.append(d)
	for i in range(4):
		builder.normals.append(normal)
	builder.indices.append(start_index)
	builder.indices.append(start_index + 1)
	builder.indices.append(start_index + 2)
	builder.indices.append(start_index)
	builder.indices.append(start_index + 2)
	builder.indices.append(start_index + 3)


func _append_collision_quad(faces: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	faces.append(a)
	faces.append(b)
	faces.append(c)
	faces.append(a)
	faces.append(c)
	faces.append(d)


func _is_water_or_outside(grid: Array[Array], x: int, y: int) -> bool:
	if y < 0 or y >= grid.size():
		return true
	if x < 0 or x >= grid[y].size():
		return true
	return grid[y][x] == TerrainCellKind.WATER


func _add_mesh_instance(name_value: String, builder: _MeshBuildState, material: StandardMaterial3D) -> void:
	if builder.vertices.is_empty():
		return

	var mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = builder.vertices
	arrays[Mesh.ARRAY_NORMAL] = builder.normals
	arrays[Mesh.ARRAY_INDEX] = builder.indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var instance := MeshInstance3D.new()
	instance.name = name_value
	instance.mesh = mesh
	instance.material_override = material
	instance.set_meta(GENERATED_META, true)
	add_child(instance)
	if Engine.is_editor_hint():
		instance.owner = null


func _add_collision_body(collision_faces: PackedVector3Array) -> void:
	if collision_faces.is_empty():
		return

	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(collision_faces)

	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	collision_shape.shape = shape

	var body := StaticBody3D.new()
	body.name = "TerrainCollision"
	body.set_meta(GENERATED_META, true)
	body.add_child(collision_shape)
	add_child(body)
	if Engine.is_editor_hint():
		body.owner = null
		collision_shape.owner = null


func _build_material(name_value: String, color: Color, transparent: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = name_value
	material.albedo_color = color
	material.roughness = 0.92
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if transparent or color.a < 0.99:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _clear_generated_children() -> void:
	for child in get_children():
		if !child.has_meta(GENERATED_META):
			continue
		remove_child(child)
		child.free()


class _MeshBuildState:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
