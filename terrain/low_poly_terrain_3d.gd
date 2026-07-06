@tool
class_name LowPolyTerrain3D
extends Node3D

const GENERATED_META := &"low_poly_terrain_generated"
const LowPolyArtStyle3DScript = preload("res://terrain/low_poly_art_style_3d.gd")
const WATER_SHADER := preload("res://resources/materials/water_3d.gdshader")

@export var rebuild: bool = false:
	set(value):
		if !value:
			return
		_request_rebuild()

@export_file_path("*.png") var mask_file: String = "res://design/gulangyu_map_mini_export.png":
	set(new_mask_file):
		if mask_file == new_mask_file:
			return
		mask_file = new_mask_file
		_request_rebuild()

@export_file_path("*.png") var heightmap_file: String = "res://design/gulangyu_height_map_mini_export.png":
	set(new_heightmap_file):
		if heightmap_file == new_heightmap_file:
			return
		heightmap_file = new_heightmap_file

@export var generation_profile: TerrainGenerationProfile:
	set(new_profile):
		if generation_profile == new_profile:
			return
		generation_profile = new_profile
		_request_rebuild()

@export var art_style: LowPolyArtStyle3DScript:
	set(new_style):
		if art_style == new_style:
			return
		art_style = new_style
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

@export var smooth_land_surface := true:
	set(new_smooth_land_surface):
		if smooth_land_surface == new_smooth_land_surface:
			return
		smooth_land_surface = new_smooth_land_surface
		_request_rebuild()

@export_range(0, 4, 1) var height_smoothing_passes := 1:
	set(new_passes):
		var clamped_passes := clampi(new_passes, 0, 4)
		if height_smoothing_passes == clamped_passes:
			return
		height_smoothing_passes = clamped_passes
		_request_rebuild()

@export var heightmap_expands_land_to_source := true:
	set(new_expands_land):
		if heightmap_expands_land_to_source == new_expands_land:
			return
		heightmap_expands_land_to_source = new_expands_land

@export_range(-4.0, 4.0, 0.01) var heightmap_min_offset := 0.0:
	set(new_offset):
		if is_equal_approx(heightmap_min_offset, new_offset):
			return
		heightmap_min_offset = new_offset

@export_range(-10.0, 10.0, 0.01) var heightmap_max_offset := 0.0:
	set(new_offset):
		if is_equal_approx(heightmap_max_offset, new_offset):
			return
		heightmap_max_offset = new_offset

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

# Terrain palette and water tuning (land_color, shoreline_color, street_color,
# building_footprint_color, water_color, water_deep_color, water_surface_layer_color,
# water_shoreline_color, water_highlight_color, water_wave_depth, water_wave_frequency,
# water_shoreline_band_ratio, water_shoreline_lift, water_surface_layer_lift) now live
# only on LowPolyArtStyle3D. Assign `art_style` to override them; otherwise a built-in
# default style is used. See _effective_style().

@export_range(0, 4, 1) var water_land_overlap_cells := 1:
	set(new_overlap_cells):
		var clamped_overlap := clampi(new_overlap_cells, 0, 4)
		if water_land_overlap_cells == clamped_overlap:
			return
		water_land_overlap_cells = clamped_overlap
		_request_rebuild()

@export var generate_collision := true:
	set(new_generate_collision):
		if generate_collision == new_generate_collision:
			return
		generate_collision = new_generate_collision
		_request_rebuild()

@export var build_on_ready := true
@export var print_summary := true

@export_group("Wind")
## Horizontal direction the water waves travel, in degrees. Drive this from
## weather (e.g. WeatherManager wind_angle_degrees) via set_wind(); the
## prototype stays decoupled from the weather system.
@export_range(0.0, 360.0, 1.0) var wind_angle_degrees := 72.0:
	set(value):
		wind_angle_degrees = wrapf(value, 0.0, 360.0)
		_apply_wind_to_water()
## Normalized wind strength: 0 = near-calm ripple, 1 = full choppy seas. Map a
## raw weather wind speed into 0..1 before passing it in.
@export_range(0.0, 1.0, 0.01) var wind_strength := 0.5:
	set(value):
		wind_strength = clampf(value, 0.0, 1.0)
		_apply_wind_to_water()

var m_is_ready := false
var m_rebuild_queued := false
var m_sample_grid: Array[Array] = []
var m_source_size := Vector2i.ZERO
var m_heightmap_defines_water_area := false
var m_default_style: LowPolyArtStyle3DScript = null
var m_water_materials: Array[ShaderMaterial] = []
var m_mesh_builder: LowPolyTerrainMeshBuilder = null
var last_rebuild_duration_ms := 0.0


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


func rebuild_from_source() -> void:
	_rebuild_from_source()


func get_sample_cell_height(sample_cell: Vector2i) -> float:
	if m_sample_grid.is_empty():
		return land_height

	var grid_size := Vector2i(m_sample_grid[0].size(), m_sample_grid.size())
	var clamped_cell := Vector2i(
		clampi(sample_cell.x, 0, grid_size.x - 1),
		clampi(sample_cell.y, 0, grid_size.y - 1)
	)
	var cell := m_sample_grid[clamped_cell.y][clamped_cell.x] as LowPolyTerrainCell
	if cell == null:
		return land_height
	var builder := _ensure_mesh_builder()
	if cell.kind == LowPolyTerrainCell.Kind.WATER:
		if !m_heightmap_defines_water_area:
			return water_height
		return builder.get_cell_surface_height(
			m_sample_grid,
			clamped_cell.x,
			clamped_cell.y,
			cell.height,
			0.5,
			0.5,
			true
		)
	return builder.get_cell_surface_height(
		m_sample_grid,
		clamped_cell.x,
		clamped_cell.y,
		cell.height,
		0.5,
		0.5,
		m_heightmap_defines_water_area
	)


func get_sample_cell_kind(sample_cell: Vector2i) -> LowPolyTerrainCell.Kind:
	if m_sample_grid.is_empty():
		return LowPolyTerrainCell.Kind.WATER

	var grid_size := Vector2i(m_sample_grid[0].size(), m_sample_grid.size())
	var clamped_cell := Vector2i(
		clampi(sample_cell.x, 0, grid_size.x - 1),
		clampi(sample_cell.y, 0, grid_size.y - 1)
	)
	var cell := m_sample_grid[clamped_cell.y][clamped_cell.x] as LowPolyTerrainCell
	if cell == null:
		return LowPolyTerrainCell.Kind.WATER
	return cell.kind


func get_world_surface_height(world_position: Vector3) -> float:
	if m_sample_grid.is_empty():
		return land_height

	var grid_size := Vector2i(m_sample_grid[0].size(), m_sample_grid.size())
	var origin_offset := _get_grid_origin_offset(grid_size)
	var grid_position := Vector2(
		(world_position.x - origin_offset.x) / cell_size,
		(world_position.z - origin_offset.z) / cell_size
	)
	var sample_cell := Vector2i(
		clampi(floori(grid_position.x), 0, grid_size.x - 1),
		clampi(floori(grid_position.y), 0, grid_size.y - 1)
	)
	var local_x := clampf(grid_position.x - float(sample_cell.x), 0.0, 1.0)
	var local_z := clampf(grid_position.y - float(sample_cell.y), 0.0, 1.0)
	var cell := m_sample_grid[sample_cell.y][sample_cell.x] as LowPolyTerrainCell
	if cell == null:
		return land_height
	var builder := _ensure_mesh_builder()
	if cell.kind == LowPolyTerrainCell.Kind.WATER:
		if !m_heightmap_defines_water_area:
			return water_height
		return builder.get_cell_surface_height(
			m_sample_grid,
			sample_cell.x,
			sample_cell.y,
			cell.height,
			local_x,
			local_z,
			true
		)
	return builder.get_cell_surface_height(
		m_sample_grid,
		sample_cell.x,
		sample_cell.y,
		cell.height,
		local_x,
		local_z,
		m_heightmap_defines_water_area
	)


func get_world_water_surface_height(world_position: Vector3) -> float:
	# Visible top surface for placement: the flat water plane over water cells (in
	# both mask-clipped and heightmap-expanded modes) and the land surface
	# elsewhere. Unlike get_world_surface_height, this never returns the submerged
	# seabed elevation, so callers can rest actors, boats, or hotspots on the water
	# plane instead of sinking them to the seabed.
	if m_sample_grid.is_empty():
		return water_height

	var grid_size := Vector2i(m_sample_grid[0].size(), m_sample_grid.size())
	var origin_offset := _get_grid_origin_offset(grid_size)
	var grid_position := Vector2(
		(world_position.x - origin_offset.x) / cell_size,
		(world_position.z - origin_offset.z) / cell_size
	)
	var sample_cell := Vector2i(
		clampi(floori(grid_position.x), 0, grid_size.x - 1),
		clampi(floori(grid_position.y), 0, grid_size.y - 1)
	)
	var cell := m_sample_grid[sample_cell.y][sample_cell.x] as LowPolyTerrainCell
	if cell == null or cell.kind == LowPolyTerrainCell.Kind.WATER:
		return water_height
	return get_world_surface_height(world_position)


func get_sample_cell_water_surface_height(sample_cell: Vector2i) -> float:
	# Sample-cell companion to get_world_water_surface_height: the water plane over
	# water cells, the land surface otherwise.
	if get_sample_cell_kind(sample_cell) == LowPolyTerrainCell.Kind.WATER:
		return water_height
	return get_sample_cell_height(sample_cell)


func get_source_size() -> Vector2i:
	return m_source_size


func _rebuild_from_source() -> void:
	var rebuild_started_usec := Time.get_ticks_usec()
	m_rebuild_queued = false
	_clear_generated_children()
	m_sample_grid.clear()
	m_source_size = Vector2i.ZERO
	m_heightmap_defines_water_area = false

	var profile := _get_generation_profile()
	if profile == null:
		return

	var heightmap_image := _load_heightmap_image()
	var mask_image := _load_mask_image()
	if mask_image == null and heightmap_image == null:
		push_warning("LowPolyTerrain3D requires a mask_file or heightmap_file.")
		return

	var source_size := _resolve_generation_source_size(mask_image, heightmap_image)
	if source_size == Vector2i.ZERO:
		push_warning("LowPolyTerrain3D could not resolve a terrain source size.")
		return

	var sampler := _build_sampler()
	var grid := sampler.build_grid(mask_image, profile, heightmap_image, source_size)
	var heightmap_defines_water_area := sampler.heightmap_fills_source_land(heightmap_image)
	m_sample_grid = grid
	m_source_size = source_size
	m_heightmap_defines_water_area = heightmap_defines_water_area
	_build_meshes_from_grid(grid, source_size.x, source_size.y, heightmap_defines_water_area)
	last_rebuild_duration_ms = float(Time.get_ticks_usec() - rebuild_started_usec) / 1000.0
	if print_summary:
		print("LowPolyTerrain3D: cold rebuild %.2f ms." % last_rebuild_duration_ms)


func _build_sampler() -> LowPolyTerrainSampler:
	var sampler := LowPolyTerrainSampler.new()
	sampler.sample_stride = sample_stride
	sampler.land_height = land_height
	sampler.water_height = water_height
	sampler.smooth_land_surface = smooth_land_surface
	sampler.height_smoothing_passes = height_smoothing_passes
	sampler.heightmap_min_offset = heightmap_min_offset
	sampler.heightmap_max_offset = heightmap_max_offset
	sampler.heightmap_expands_land_to_source = heightmap_expands_land_to_source
	return sampler


func _get_generation_profile() -> TerrainGenerationProfile:
	var profile := generation_profile
	if profile == null:
		profile = TerrainGenerationProfile.create_default_profile()
	profile.ensure_defaults()
	if !profile.is_valid_profile():
		return null
	return profile


func _load_mask_image() -> Image:
	if mask_file.is_empty():
		return null

	var image := Image.new()
	var load_error := image.load(mask_file)
	if load_error != OK:
		push_error("LowPolyTerrain3D failed to load mask image: %s (err=%d)" % [mask_file, load_error])
		return null

	if image.is_compressed():
		image.decompress()
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return image


func _load_heightmap_image() -> Image:
	if heightmap_file.is_empty():
		return null

	var image := Image.new()
	var load_error := image.load(heightmap_file)
	if load_error != OK:
		push_error("LowPolyTerrain3D failed to load heightmap image: %s (err=%d)" % [heightmap_file, load_error])
		return null

	if image.is_compressed():
		image.decompress()
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return image


func _resolve_generation_source_size(mask_image: Image, heightmap_image: Image) -> Vector2i:
	if heightmap_expands_land_to_source and heightmap_image != null:
		return heightmap_image.get_size()
	if mask_image != null:
		return mask_image.get_size()
	if heightmap_image != null:
		return heightmap_image.get_size()
	return Vector2i.ZERO


func _build_meshes_from_grid(
	grid: Array[Array],
	source_width: int,
	source_height: int,
	heightmap_defines_water_area: bool
) -> void:
	if grid.is_empty():
		return

	var grid_height := grid.size()
	var grid_width := grid[0].size()

	var builder := _configure_mesh_builder()
	var rendering := builder.water_rendering
	var result := builder.build(grid, source_width, source_height, heightmap_defines_water_area)

	# All three transparent water layers run the same wave shader so they
	# displace together; render_priority keeps a stable composite order (body <
	# foam < gloss) regardless of camera angle. Cache the materials so live wind
	# updates (set_wind) can retune them without rebuilding the meshes.
	m_water_materials.clear()
	var water_material := _build_water_material(
		"Low Poly Water", rendering, true, rendering.base_color, rendering.material_alpha
	)
	water_material.render_priority = 0
	m_water_materials.append(water_material)
	_add_mesh_instance("WaterMesh", result.water, water_material)
	var water_shoreline_material := _build_water_material(
		"Low Poly Water Shoreline", rendering, false, rendering.shoreline_color, 1.0
	)
	water_shoreline_material.render_priority = 1
	m_water_materials.append(water_shoreline_material)
	_add_mesh_instance("WaterShorelineMesh", result.water_shoreline, water_shoreline_material)
	var water_surface_layer_material := _build_water_material(
		"Low Poly Water Surface Layer", rendering, false, rendering.surface_layer_color, 1.0
	)
	water_surface_layer_material.render_priority = 2
	m_water_materials.append(water_surface_layer_material)
	_add_mesh_instance("WaterSurfaceLayerMesh", result.water_surface_layer, water_surface_layer_material)
	_add_mesh_instance("LandMesh", result.land, _build_material("Low Poly Land", _resolve_style_color(&"land_color"), false))
	_add_mesh_instance("ShorelineMesh", result.shoreline, _build_material("Low Poly Shoreline", _resolve_style_color(&"shoreline_color"), false))
	_add_mesh_instance("StreetMesh", result.street, _build_material("Low Poly Streets", _resolve_style_color(&"street_color"), false))
	_add_mesh_instance(
		"BuildingFootprintMesh",
		result.building,
		_build_material("Low Poly Building Footprints", _resolve_style_color(&"building_footprint_color"), false)
	)

	if generate_collision:
		_add_collision_body(result.collision_faces)

	if print_summary:
		print(
			"LowPolyTerrain3D: built %dx%d source into %dx%d sampled cells (%d land, %d street, %d building, %d water, %d water render)."
			% [source_width, source_height, grid_width, grid_height, result.land_cells, result.street_cells, result.building_cells, result.water_cells, result.water_render_cells]
		)


## Reuse a cached mesh builder configured with the geometry parameters the height
## queries depend on. _configure_mesh_builder adds the build-only fields.
func _ensure_mesh_builder() -> LowPolyTerrainMeshBuilder:
	if m_mesh_builder == null:
		m_mesh_builder = LowPolyTerrainMeshBuilder.new()
	m_mesh_builder.cell_size = cell_size
	m_mesh_builder.water_height = water_height
	m_mesh_builder.land_height = land_height
	m_mesh_builder.smooth_land_surface = smooth_land_surface
	return m_mesh_builder


func _configure_mesh_builder() -> LowPolyTerrainMeshBuilder:
	var builder := _ensure_mesh_builder()
	builder.street_lift = street_lift
	builder.building_footprint_lift = building_footprint_lift
	builder.water_land_overlap_cells = water_land_overlap_cells
	builder.water_rendering = _build_water_rendering()
	return builder


func _get_grid_origin_offset(grid_size: Vector2i) -> Vector3:
	return LowPolyWorldCoordinates3D.compute_world_origin(grid_size, cell_size)


func _add_mesh_instance(name_value: String, builder: LowPolyTerrainMeshBuilder.MeshBuildState, material: Material) -> void:
	if builder.vertices.is_empty():
		return

	var mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = builder.vertices
	arrays[Mesh.ARRAY_NORMAL] = builder.normals
	if builder.colors.size() == builder.vertices.size():
		arrays[Mesh.ARRAY_COLOR] = builder.colors
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


func _build_water_material(
	name_value: String,
	rendering: LowPolyTerrainMeshBuilder.WaterRendering,
	use_vertex_color: bool,
	base_color: Color,
	opacity: float
) -> ShaderMaterial:
	# Animated low-poly water with real wave-geometry displacement
	# (resources/materials/water_3d.gdshader). All three water layers share this
	# shader and the same world-space waves so they rise and fall together.
	var material := ShaderMaterial.new()
	material.resource_name = name_value
	material.shader = WATER_SHADER
	material.set_shader_parameter(&"use_vertex_color", use_vertex_color)
	material.set_shader_parameter(&"base_color", base_color)
	material.set_shader_parameter(&"water_opacity", opacity)
	material.set_shader_parameter(&"wave_depth", rendering.wave_depth)
	material.set_shader_parameter(&"wave_frequency", rendering.wave_frequency)
	material.set_shader_parameter(&"wave_speed", rendering.wave_speed)
	material.set_shader_parameter(&"highlight_color", rendering.highlight_color)
	material.set_shader_parameter(&"highlight_strength", clampf(0.14 + rendering.wave_depth * 0.3, 0.1, 0.4))
	material.set_shader_parameter(&"wind_dir", _wind_direction())
	material.set_shader_parameter(&"wind_strength", wind_strength)
	return material


## Set the water wind live without rebuilding meshes. wind_angle is in degrees
## (horizontal wave travel direction); normalized_strength is 0..1. Intended to
## be driven by weather (e.g. map WeatherManager wind to these), keeping this
## prototype decoupled from the weather system.
func set_wind(wind_angle: float, normalized_strength: float) -> void:
	# Assigning the exported properties runs their setters, which retune the
	# cached water materials via _apply_wind_to_water().
	wind_angle_degrees = wind_angle
	wind_strength = normalized_strength


func _wind_direction() -> Vector2:
	var radians := deg_to_rad(wind_angle_degrees)
	return Vector2(cos(radians), sin(radians))


func _apply_wind_to_water() -> void:
	var direction := _wind_direction()
	for material in m_water_materials:
		if material == null:
			continue
		material.set_shader_parameter(&"wind_dir", direction)
		material.set_shader_parameter(&"wind_strength", wind_strength)


func _build_water_rendering() -> LowPolyTerrainMeshBuilder.WaterRendering:
	var rendering := LowPolyTerrainMeshBuilder.WaterRendering.new()
	rendering.base_color = _resolve_style_color(&"water_color")
	rendering.deep_color = _resolve_style_color(&"water_deep_color")
	rendering.surface_layer_color = _resolve_style_color(&"water_surface_layer_color")
	rendering.shoreline_color = _resolve_style_color(&"water_shoreline_color")
	rendering.highlight_color = _resolve_style_color(&"water_highlight_color")
	rendering.material_alpha = clampf(maxf(rendering.base_color.a, rendering.deep_color.a), 0.0, 0.62)
	rendering.wave_depth = maxf(_resolve_style_float(&"water_wave_depth"), 0.0)
	rendering.wave_frequency = maxf(_resolve_style_float(&"water_wave_frequency"), 0.05)
	rendering.wave_speed = maxf(_resolve_style_float(&"water_wave_speed"), 0.0)
	rendering.shoreline_band_ratio = clampf(
		_resolve_style_float(&"water_shoreline_band_ratio"),
		0.0,
		0.45
	)
	rendering.shoreline_lift = maxf(_resolve_style_float(&"water_shoreline_lift"), 0.0)
	rendering.surface_layer_lift = maxf(_resolve_style_float(&"water_surface_layer_lift"), 0.0)
	return rendering


func _effective_style() -> LowPolyArtStyle3DScript:
	if art_style != null:
		return art_style
	if m_default_style == null:
		m_default_style = LowPolyArtStyle3DScript.new()
	return m_default_style


func _resolve_style_color(property_name: StringName) -> Color:
	var value: Variant = _effective_style().get(property_name)
	if value is Color:
		return value
	return Color.MAGENTA


func _resolve_style_float(property_name: StringName) -> float:
	var value: Variant = _effective_style().get(property_name)
	if value is float or value is int:
		return float(value)
	return 0.0


func _clear_generated_children() -> void:
	for child in get_children():
		if !child.has_meta(GENERATED_META):
			continue
		remove_child(child)
		child.queue_free()
