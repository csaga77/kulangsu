@tool
class_name LowPolyTerrain3D
extends Node3D

const GENERATED_META := &"low_poly_terrain_generated"
const LowPolyArtStyle3DScript = preload("res://terrain/low_poly_art_style_3d.gd")
const WATER_SHADER := preload("res://resources/materials/water_3d.gdshader")
const HEIGHT_EPSILON := 0.001
const CORNER_NW := 0
const CORNER_NE := 1
const CORNER_SE := 2
const CORNER_SW := 3

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
	if cell.kind == LowPolyTerrainCell.Kind.WATER:
		if !m_heightmap_defines_water_area:
			return water_height
		return _get_cell_surface_height(
			m_sample_grid,
			clamped_cell.x,
			clamped_cell.y,
			cell.height,
			0.5,
			0.5,
			true
		)
	return _get_cell_surface_height(
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
	if cell.kind == LowPolyTerrainCell.Kind.WATER:
		if !m_heightmap_defines_water_area:
			return water_height
		return _get_cell_surface_height(
			m_sample_grid,
			sample_cell.x,
			sample_cell.y,
			cell.height,
			local_x,
			local_z,
			true
		)
	return _get_cell_surface_height(
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
	var origin_offset := _get_grid_origin_offset(Vector2i(grid_width, grid_height))

	var land_builder := _MeshBuildState.new()
	var shoreline_builder := _MeshBuildState.new()
	var water_builder := _MeshBuildState.new()
	var water_surface_layer_builder := _MeshBuildState.new()
	var water_shoreline_builder := _MeshBuildState.new()
	var street_builder := _MeshBuildState.new()
	var building_builder := _MeshBuildState.new()
	var collision_faces := PackedVector3Array()
	var water_rendering := _build_water_rendering()
	var water_render_grid := _build_water_render_grid(grid)

	var land_cells := 0
	var street_cells := 0
	var building_cells := 0
	var water_cells := 0
	var water_render_cells := 0

	for y in range(grid_height):
		for x in range(grid_width):
			var cell := grid[y][x] as LowPolyTerrainCell
			if cell == null:
				continue
			var kind: LowPolyTerrainCell.Kind = cell.kind
			var min_x := origin_offset.x + float(x) * cell_size
			var max_x := min_x + cell_size
			var min_z := origin_offset.z + float(y) * cell_size
			var max_z := min_z + cell_size

			match kind:
				LowPolyTerrainCell.Kind.WATER:
					water_cells += 1
					if cell.height < water_height - HEIGHT_EPSILON:
						var seabed_corner_heights := _get_cell_corner_heights(grid, x, y, cell.height, true)
						_append_terrain_surface_cell(
							land_builder,
							min_x,
							max_x,
							min_z,
							max_z,
							seabed_corner_heights
						)
				LowPolyTerrainCell.Kind.STREET:
					street_cells += 1
					land_cells += 1
					var street_corner_heights := _get_cell_corner_heights(
						grid,
						x,
						y,
						cell.height,
						heightmap_defines_water_area
					)
					_append_land_cell(
						grid,
						x,
						y,
						min_x,
						max_x,
						min_z,
						max_z,
						cell.height,
						street_corner_heights,
						land_builder,
						shoreline_builder,
						collision_faces,
						!heightmap_defines_water_area
					)
					_append_inset_surface_quad(street_builder, min_x, max_x, min_z, max_z, street_corner_heights, street_lift, 0.08)
				LowPolyTerrainCell.Kind.BUILDING:
					building_cells += 1
					land_cells += 1
					var building_corner_heights := _get_cell_corner_heights(
						grid,
						x,
						y,
						cell.height,
						heightmap_defines_water_area
					)
					_append_land_cell(
						grid,
						x,
						y,
						min_x,
						max_x,
						min_z,
						max_z,
						cell.height,
						building_corner_heights,
						land_builder,
						shoreline_builder,
						collision_faces,
						!heightmap_defines_water_area
					)
					_append_inset_surface_quad(
						building_builder,
						min_x,
						max_x,
						min_z,
						max_z,
						building_corner_heights,
						building_footprint_lift,
						0.14
					)
				_:
					land_cells += 1
					var land_corner_heights := _get_cell_corner_heights(
						grid,
						x,
						y,
						cell.height,
						heightmap_defines_water_area
					)
					_append_land_cell(
						grid,
						x,
						y,
						min_x,
						max_x,
						min_z,
						max_z,
						cell.height,
						land_corner_heights,
						land_builder,
						shoreline_builder,
						collision_faces,
						!heightmap_defines_water_area
					)

			if _is_water_render_cell(water_render_grid, x, y):
				water_render_cells += 1
				_append_water_cell(
					grid,
					water_render_grid,
					x,
					y,
					min_x,
					max_x,
					min_z,
					max_z,
					water_builder,
					water_shoreline_builder,
					water_rendering
				)
				_append_water_surface_layer(
					water_surface_layer_builder,
					min_x,
					max_x,
					min_z,
					max_z,
					water_rendering
				)

	# All three transparent water layers run the same wave shader so they
	# displace together; render_priority keeps a stable composite order (body <
	# foam < gloss) regardless of camera angle. Cache the materials so live wind
	# updates (set_wind) can retune them without rebuilding the meshes.
	m_water_materials.clear()
	var water_material := _build_water_material(
		"Low Poly Water", water_rendering, true, water_rendering.base_color, water_rendering.material_alpha
	)
	water_material.render_priority = 0
	m_water_materials.append(water_material)
	_add_mesh_instance("WaterMesh", water_builder, water_material)
	var water_shoreline_material := _build_water_material(
		"Low Poly Water Shoreline", water_rendering, false, water_rendering.shoreline_color, 1.0
	)
	water_shoreline_material.render_priority = 1
	m_water_materials.append(water_shoreline_material)
	_add_mesh_instance("WaterShorelineMesh", water_shoreline_builder, water_shoreline_material)
	var water_surface_layer_material := _build_water_material(
		"Low Poly Water Surface Layer", water_rendering, false, water_rendering.surface_layer_color, 1.0
	)
	water_surface_layer_material.render_priority = 2
	m_water_materials.append(water_surface_layer_material)
	_add_mesh_instance("WaterSurfaceLayerMesh", water_surface_layer_builder, water_surface_layer_material)
	_add_mesh_instance("LandMesh", land_builder, _build_material("Low Poly Land", _resolve_style_color(&"land_color"), false))
	_add_mesh_instance("ShorelineMesh", shoreline_builder, _build_material("Low Poly Shoreline", _resolve_style_color(&"shoreline_color"), false))
	_add_mesh_instance("StreetMesh", street_builder, _build_material("Low Poly Streets", _resolve_style_color(&"street_color"), false))
	_add_mesh_instance(
		"BuildingFootprintMesh",
		building_builder,
		_build_material("Low Poly Building Footprints", _resolve_style_color(&"building_footprint_color"), false)
	)

	if generate_collision:
		_add_collision_body(collision_faces)

	if print_summary:
		print(
			"LowPolyTerrain3D: built %dx%d source into %dx%d sampled cells (%d land, %d street, %d building, %d water, %d water render)."
			% [source_width, source_height, grid_width, grid_height, land_cells, street_cells, building_cells, water_cells, water_render_cells]
		)


func _build_water_render_grid(grid: Array[Array]) -> Array[PackedByteArray]:
	var render_grid: Array[PackedByteArray] = []
	if grid.is_empty():
		return render_grid

	var grid_height := grid.size()
	var grid_width := grid[0].size()
	for _y in range(grid_height):
		var row := PackedByteArray()
		row.resize(grid_width)
		render_grid.append(row)

	var overlap_cells := maxi(water_land_overlap_cells, 0)
	for y in range(grid_height):
		for x in range(grid_width):
			var cell := grid[y][x] as LowPolyTerrainCell
			if cell == null or cell.kind != LowPolyTerrainCell.Kind.WATER:
				continue
			var min_y := maxi(y - overlap_cells, 0)
			var max_y := mini(y + overlap_cells, grid_height - 1)
			var min_x := maxi(x - overlap_cells, 0)
			var max_x := mini(x + overlap_cells, grid_width - 1)
			for render_y in range(min_y, max_y + 1):
				for render_x in range(min_x, max_x + 1):
					if _is_land_cell(grid, render_x, render_y) or (render_x == x and render_y == y):
						var render_row := render_grid[render_y]
						render_row[render_x] = 1
						render_grid[render_y] = render_row

	return render_grid


func _get_grid_origin_offset(grid_size: Vector2i) -> Vector3:
	return LowPolyWorldCoordinates3D.compute_world_origin(grid_size, cell_size)


func _append_land_cell(
	grid: Array[Array],
	x: int,
	y: int,
	min_x: float,
	max_x: float,
	min_z: float,
	max_z: float,
	cell_height: float,
	corner_heights: PackedFloat32Array,
	land_builder: _MeshBuildState,
	shoreline_builder: _MeshBuildState,
	collision_faces: PackedVector3Array,
	draw_shoreline_sides: bool
) -> void:
	var vertices := _get_surface_cell_vertices(min_x, max_x, min_z, max_z, corner_heights)
	var a := vertices[CORNER_NW]
	var b := vertices[CORNER_NE]
	var c := vertices[CORNER_SE]
	var d := vertices[CORNER_SW]
	_append_surface_quad(land_builder, a, b, c, d)
	_append_collision_quad(collision_faces, a, b, c, d)

	if !draw_shoreline_sides:
		return

	if _is_water_or_outside(grid, x, y - 1):
		_append_side_quad(
			shoreline_builder,
			Vector3(max_x, corner_heights[CORNER_NE], min_z),
			Vector3(min_x, corner_heights[CORNER_NW], min_z),
			Vector3(min_x, water_height, min_z),
			Vector3(max_x, water_height, min_z),
			Vector3(0.0, 0.0, -1.0)
		)
	elif !smooth_land_surface:
		var north_height := _get_cell_height(grid, x, y - 1)
		if north_height < cell_height - HEIGHT_EPSILON:
			_append_side_quad(
				shoreline_builder,
				Vector3(max_x, cell_height, min_z),
				Vector3(min_x, cell_height, min_z),
				Vector3(min_x, north_height, min_z),
				Vector3(max_x, north_height, min_z),
				Vector3(0.0, 0.0, -1.0)
			)
	if _is_water_or_outside(grid, x + 1, y):
		_append_side_quad(
			shoreline_builder,
			Vector3(max_x, corner_heights[CORNER_SE], max_z),
			Vector3(max_x, corner_heights[CORNER_NE], min_z),
			Vector3(max_x, water_height, min_z),
			Vector3(max_x, water_height, max_z),
			Vector3(1.0, 0.0, 0.0)
		)
	elif !smooth_land_surface:
		var east_height := _get_cell_height(grid, x + 1, y)
		if east_height < cell_height - HEIGHT_EPSILON:
			_append_side_quad(
				shoreline_builder,
				Vector3(max_x, cell_height, max_z),
				Vector3(max_x, cell_height, min_z),
				Vector3(max_x, east_height, min_z),
				Vector3(max_x, east_height, max_z),
				Vector3(1.0, 0.0, 0.0)
			)
	if _is_water_or_outside(grid, x, y + 1):
		_append_side_quad(
			shoreline_builder,
			Vector3(min_x, corner_heights[CORNER_SW], max_z),
			Vector3(max_x, corner_heights[CORNER_SE], max_z),
			Vector3(max_x, water_height, max_z),
			Vector3(min_x, water_height, max_z),
			Vector3(0.0, 0.0, 1.0)
		)
	elif !smooth_land_surface:
		var south_height := _get_cell_height(grid, x, y + 1)
		if south_height < cell_height - HEIGHT_EPSILON:
			_append_side_quad(
				shoreline_builder,
				Vector3(min_x, cell_height, max_z),
				Vector3(max_x, cell_height, max_z),
				Vector3(max_x, south_height, max_z),
				Vector3(min_x, south_height, max_z),
				Vector3(0.0, 0.0, 1.0)
			)
	if _is_water_or_outside(grid, x - 1, y):
		_append_side_quad(
			shoreline_builder,
			Vector3(min_x, corner_heights[CORNER_NW], min_z),
			Vector3(min_x, corner_heights[CORNER_SW], max_z),
			Vector3(min_x, water_height, max_z),
			Vector3(min_x, water_height, min_z),
			Vector3(-1.0, 0.0, 0.0)
		)
	elif !smooth_land_surface:
		var west_height := _get_cell_height(grid, x - 1, y)
		if west_height < cell_height - HEIGHT_EPSILON:
			_append_side_quad(
				shoreline_builder,
				Vector3(min_x, cell_height, min_z),
				Vector3(min_x, cell_height, max_z),
				Vector3(min_x, west_height, max_z),
				Vector3(min_x, west_height, min_z),
				Vector3(-1.0, 0.0, 0.0)
			)


func _append_terrain_surface_cell(
	builder: _MeshBuildState,
	min_x: float,
	max_x: float,
	min_z: float,
	max_z: float,
	corner_heights: PackedFloat32Array
) -> void:
	var vertices := _get_surface_cell_vertices(min_x, max_x, min_z, max_z, corner_heights)
	_append_surface_quad(
		builder,
		vertices[CORNER_NW],
		vertices[CORNER_NE],
		vertices[CORNER_SE],
		vertices[CORNER_SW]
	)


func _get_surface_cell_vertices(
	min_x: float,
	max_x: float,
	min_z: float,
	max_z: float,
	corner_heights: PackedFloat32Array
) -> PackedVector3Array:
	return PackedVector3Array([
		Vector3(min_x, corner_heights[CORNER_NW], min_z),
		Vector3(max_x, corner_heights[CORNER_NE], min_z),
		Vector3(max_x, corner_heights[CORNER_SE], max_z),
		Vector3(min_x, corner_heights[CORNER_SW], max_z),
	])


func _append_top_quad(builder: _MeshBuildState, min_x: float, max_x: float, min_z: float, max_z: float, height: float) -> void:
	_append_quad(
		builder,
		Vector3(min_x, height, min_z),
		Vector3(max_x, height, min_z),
		Vector3(max_x, height, max_z),
		Vector3(min_x, height, max_z),
		Vector3.UP
	)


func _append_water_cell(
	grid: Array[Array],
	water_render_grid: Array[PackedByteArray],
	x: int,
	y: int,
	min_x: float,
	max_x: float,
	min_z: float,
	max_z: float,
	water_builder: _MeshBuildState,
	water_shoreline_builder: _MeshBuildState,
	rendering: _WaterRendering
) -> void:
	var a := Vector3(min_x, water_height, min_z)
	var b := Vector3(max_x, water_height, min_z)
	var c := Vector3(max_x, water_height, max_z)
	var d := Vector3(min_x, water_height, max_z)
	var shoreline_factor := _get_water_shoreline_factor(grid, water_render_grid, x, y)
	_append_colored_surface_triangle(water_builder, a, b, c, _get_water_face_color(x, y, 0, shoreline_factor, rendering))
	_append_colored_surface_triangle(water_builder, a, c, d, _get_water_face_color(x, y, 1, shoreline_factor, rendering))
	_append_water_shoreline_bands(
		grid,
		water_render_grid,
		x,
		y,
		min_x,
		max_x,
		min_z,
		max_z,
		water_shoreline_builder,
		rendering
	)


func _append_water_surface_layer(
	builder: _MeshBuildState,
	min_x: float,
	max_x: float,
	min_z: float,
	max_z: float,
	rendering: _WaterRendering
) -> void:
	if rendering.surface_layer_color.a <= 0.0:
		return
	_append_top_quad(builder, min_x, max_x, min_z, max_z, water_height + rendering.surface_layer_lift)


func _append_water_shoreline_bands(
	grid: Array[Array],
	water_render_grid: Array[PackedByteArray],
	x: int,
	y: int,
	min_x: float,
	max_x: float,
	min_z: float,
	max_z: float,
	builder: _MeshBuildState,
	rendering: _WaterRendering
) -> void:
	if rendering.shoreline_band_ratio <= 0.0:
		return

	var band_width := (max_x - min_x) * rendering.shoreline_band_ratio
	var band_height := water_height + rendering.shoreline_lift
	if _is_visible_water_shoreline_edge(grid, water_render_grid, x, y - 1):
		_append_colored_top_quad(
			builder,
			min_x,
			max_x,
			min_z,
			min_z + band_width,
			band_height,
			rendering.shoreline_color
		)
	if _is_visible_water_shoreline_edge(grid, water_render_grid, x + 1, y):
		_append_colored_top_quad(
			builder,
			max_x - band_width,
			max_x,
			min_z,
			max_z,
			band_height,
			rendering.shoreline_color
		)
	if _is_visible_water_shoreline_edge(grid, water_render_grid, x, y + 1):
		_append_colored_top_quad(
			builder,
			min_x,
			max_x,
			max_z - band_width,
			max_z,
			band_height,
			rendering.shoreline_color
		)
	if _is_visible_water_shoreline_edge(grid, water_render_grid, x - 1, y):
		_append_colored_top_quad(
			builder,
			min_x,
			min_x + band_width,
			min_z,
			max_z,
			band_height,
			rendering.shoreline_color
		)


func _append_colored_top_quad(
	builder: _MeshBuildState,
	min_x: float,
	max_x: float,
	min_z: float,
	max_z: float,
	height: float,
	color: Color
) -> void:
	_append_colored_surface_quad(
		builder,
		Vector3(min_x, height, min_z),
		Vector3(max_x, height, min_z),
		Vector3(max_x, height, max_z),
		Vector3(min_x, height, max_z),
		color
	)


func _append_colored_surface_quad(
	builder: _MeshBuildState,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	color: Color
) -> void:
	_append_colored_surface_triangle(builder, a, b, c, color)
	_append_colored_surface_triangle(builder, a, c, d, color)


func _append_inset_surface_quad(
	builder: _MeshBuildState,
	min_x: float,
	max_x: float,
	min_z: float,
	max_z: float,
	corner_heights: PackedFloat32Array,
	lift: float,
	inset_ratio: float
) -> void:
	var inset_x := (max_x - min_x) * inset_ratio
	var inset_z := (max_z - min_z) * inset_ratio
	var min_t := inset_ratio
	var max_t := 1.0 - inset_ratio
	var a := Vector3(
		min_x + inset_x,
		_interpolate_quad_height(corner_heights, min_t, min_t) + lift,
		min_z + inset_z
	)
	var b := Vector3(
		max_x - inset_x,
		_interpolate_quad_height(corner_heights, max_t, min_t) + lift,
		min_z + inset_z
	)
	var c := Vector3(
		max_x - inset_x,
		_interpolate_quad_height(corner_heights, max_t, max_t) + lift,
		max_z - inset_z
	)
	var d := Vector3(
		min_x + inset_x,
		_interpolate_quad_height(corner_heights, min_t, max_t) + lift,
		max_z - inset_z
	)
	_append_surface_quad(builder, a, b, c, d)


func _append_surface_quad(builder: _MeshBuildState, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_append_surface_triangle(builder, a, b, c)
	_append_surface_triangle(builder, a, c, d)


func _append_surface_triangle(builder: _MeshBuildState, a: Vector3, b: Vector3, c: Vector3) -> void:
	var start_index := builder.vertices.size()
	var normal := _calculate_surface_normal(a, b, c)
	builder.vertices.append(a)
	builder.vertices.append(b)
	builder.vertices.append(c)
	for i in range(3):
		builder.normals.append(normal)
	builder.indices.append(start_index)
	builder.indices.append(start_index + 1)
	builder.indices.append(start_index + 2)


func _append_colored_surface_triangle(builder: _MeshBuildState, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var start_index := builder.vertices.size()
	var normal := _calculate_surface_normal(a, b, c)
	builder.vertices.append(a)
	builder.vertices.append(b)
	builder.vertices.append(c)
	for i in range(3):
		builder.normals.append(normal)
		builder.colors.append(color)
	builder.indices.append(start_index)
	builder.indices.append(start_index + 1)
	builder.indices.append(start_index + 2)


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


func _get_cell_corner_heights(
	grid: Array[Array],
	x: int,
	y: int,
	fallback_height: float,
	include_water_cells := false
) -> PackedFloat32Array:
	if !smooth_land_surface:
		return PackedFloat32Array([fallback_height, fallback_height, fallback_height, fallback_height])

	return PackedFloat32Array([
		_get_corner_height(grid, x, y, fallback_height, include_water_cells),
		_get_corner_height(grid, x + 1, y, fallback_height, include_water_cells),
		_get_corner_height(grid, x + 1, y + 1, fallback_height, include_water_cells),
		_get_corner_height(grid, x, y + 1, fallback_height, include_water_cells),
	])


func _get_corner_height(
	grid: Array[Array],
	corner_x: int,
	corner_y: int,
	fallback_height: float,
	include_water_cells: bool
) -> float:
	var total_height := 0.0
	var sample_count := 0
	for y in range(corner_y - 1, corner_y + 1):
		for x in range(corner_x - 1, corner_x + 1):
			if _is_outside_grid(grid, x, y):
				continue
			var cell := grid[y][x] as LowPolyTerrainCell
			if cell == null or (cell.kind == LowPolyTerrainCell.Kind.WATER and !include_water_cells):
				continue
			total_height += cell.height
			sample_count += 1

	if sample_count <= 0:
		return fallback_height
	return total_height / float(sample_count)


func _get_cell_surface_height(
	grid: Array[Array],
	x: int,
	y: int,
	fallback_height: float,
	local_x: float,
	local_z: float,
	include_water_cells := false
) -> float:
	var corner_heights := _get_cell_corner_heights(grid, x, y, fallback_height, include_water_cells)
	return _interpolate_quad_height(corner_heights, local_x, local_z)


func _interpolate_quad_height(corner_heights: PackedFloat32Array, local_x: float, local_z: float) -> float:
	var north_height := lerpf(corner_heights[CORNER_NW], corner_heights[CORNER_NE], local_x)
	var south_height := lerpf(corner_heights[CORNER_SW], corner_heights[CORNER_SE], local_x)
	return lerpf(north_height, south_height, local_z)


func _calculate_surface_normal(a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var normal := (c - a).cross(b - a)
	if normal.length_squared() <= 0.000001:
		return Vector3.UP
	normal = normal.normalized()
	if normal.y < 0.0:
		return -normal
	return normal


func _is_outside_grid(grid: Array[Array], x: int, y: int) -> bool:
	if y < 0 or y >= grid.size():
		return true
	return x < 0 or x >= grid[y].size()


func _is_water_or_outside(grid: Array[Array], x: int, y: int) -> bool:
	if _is_outside_grid(grid, x, y):
		return true
	var cell := grid[y][x] as LowPolyTerrainCell
	return cell == null or cell.kind == LowPolyTerrainCell.Kind.WATER


func _is_water_render_cell(water_render_grid: Array[PackedByteArray], x: int, y: int) -> bool:
	if y < 0 or y >= water_render_grid.size():
		return false
	if x < 0 or x >= water_render_grid[y].size():
		return false
	return water_render_grid[y][x] != 0


func _is_land_cell(grid: Array[Array], x: int, y: int) -> bool:
	if y < 0 or y >= grid.size():
		return false
	if x < 0 or x >= grid[y].size():
		return false
	var cell := grid[y][x] as LowPolyTerrainCell
	return cell != null and cell.kind != LowPolyTerrainCell.Kind.WATER


func _is_visible_water_shoreline_edge(
	grid: Array[Array],
	water_render_grid: Array[PackedByteArray],
	x: int,
	y: int
) -> bool:
	return _is_land_cell(grid, x, y) and !_is_water_render_cell(water_render_grid, x, y)


func _get_water_shoreline_factor(
	grid: Array[Array],
	water_render_grid: Array[PackedByteArray],
	x: int,
	y: int
) -> float:
	var shoreline_weight := 0.0
	for sample_y in range(y - 1, y + 2):
		for sample_x in range(x - 1, x + 2):
			if sample_x == x and sample_y == y:
				continue
			if !_is_visible_water_shoreline_edge(grid, water_render_grid, sample_x, sample_y):
				continue
			var is_cardinal := sample_x == x or sample_y == y
			shoreline_weight += 2.0 if is_cardinal else 1.0
	return clampf(shoreline_weight / 6.0, 0.0, 1.0)


func _get_water_face_color(
	x: int,
	y: int,
	triangle_index: int,
	shoreline_factor: float,
	rendering: _WaterRendering
) -> Color:
	var base_blend := clampf(0.48 + shoreline_factor * 0.36, 0.0, 1.0)
	var color := rendering.deep_color.lerp(rendering.base_color, base_blend)
	color = color.lerp(rendering.shoreline_color, shoreline_factor * 0.28)

	var shimmer := _stable_water_noise(x, y, triangle_index, rendering.wave_frequency)
	var shimmer_strength := clampf(0.06 + rendering.wave_depth * 2.0, 0.06, 0.22)
	var highlight_strength := clampf((shimmer - 0.62) / 0.38, 0.0, 1.0) * shimmer_strength
	color = color.lerp(rendering.highlight_color, highlight_strength)
	return color


func _stable_water_noise(x: int, y: int, salt: int, frequency: float) -> float:
	var seed := float(x) * 12.9898 * frequency + float(y) * 78.233 * frequency + float(salt) * 37.719
	var value := sin(seed) * 43758.5453
	return value - floorf(value)


func _get_cell_height(grid: Array[Array], x: int, y: int) -> float:
	if _is_water_or_outside(grid, x, y):
		return water_height
	var cell := grid[y][x] as LowPolyTerrainCell
	if cell == null:
		return water_height
	return cell.height


func _add_mesh_instance(name_value: String, builder: _MeshBuildState, material: Material) -> void:
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
	rendering: _WaterRendering,
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


func _build_water_rendering() -> _WaterRendering:
	var rendering := _WaterRendering.new()
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


class _MeshBuildState:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()


class _WaterRendering:
	var base_color := Color(0.42, 0.68, 0.83, 0.46)
	var deep_color := Color(0.24, 0.48, 0.67, 0.54)
	var surface_layer_color := Color(0.72, 0.90, 0.96, 0.24)
	var shoreline_color := Color(0.60, 0.83, 0.88, 0.50)
	var highlight_color := Color(0.86, 0.96, 0.98, 0.40)
	var material_alpha := 0.54
	var wave_depth := 0.35
	var wave_frequency := 0.9
	var wave_speed := 1.5
	var shoreline_band_ratio := 0.18
	var shoreline_lift := 0.006
	var surface_layer_lift := 0.003
