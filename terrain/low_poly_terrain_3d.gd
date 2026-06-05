@tool
class_name LowPolyTerrain3D
extends Node3D

const GENERATED_META := &"low_poly_terrain_generated"
const LowPolyArtStyle3DScript = preload("res://terrain/low_poly_art_style_3d.gd")
const HEIGHT_EPSILON := 0.001
const CORNER_NW := 0
const CORNER_NE := 1
const CORNER_SE := 2
const CORNER_SW := 3

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

@export var water_color: Color = Color(0.42, 0.68, 0.83, 0.46):
	set(new_color):
		if water_color == new_color:
			return
		water_color = new_color
		_request_rebuild()

@export var water_deep_color: Color = Color(0.24, 0.48, 0.67, 0.54):
	set(new_color):
		if water_deep_color == new_color:
			return
		water_deep_color = new_color
		_request_rebuild()

@export var water_surface_layer_color: Color = Color(0.72, 0.90, 0.96, 0.24):
	set(new_color):
		if water_surface_layer_color == new_color:
			return
		water_surface_layer_color = new_color
		_request_rebuild()

@export var water_shoreline_color: Color = Color(0.60, 0.83, 0.88, 0.50):
	set(new_color):
		if water_shoreline_color == new_color:
			return
		water_shoreline_color = new_color
		_request_rebuild()

@export var water_highlight_color: Color = Color(0.86, 0.96, 0.98, 0.40):
	set(new_color):
		if water_highlight_color == new_color:
			return
		water_highlight_color = new_color
		_request_rebuild()

@export_range(0.0, 0.2, 0.005) var water_wave_depth: float = 0.045:
	set(new_depth):
		var clamped_depth := maxf(new_depth, 0.0)
		if is_equal_approx(water_wave_depth, clamped_depth):
			return
		water_wave_depth = clamped_depth
		_request_rebuild()

@export_range(0.05, 4.0, 0.05) var water_wave_frequency: float = 0.48:
	set(new_frequency):
		var clamped_frequency := maxf(new_frequency, 0.05)
		if is_equal_approx(water_wave_frequency, clamped_frequency):
			return
		water_wave_frequency = clamped_frequency
		_request_rebuild()

@export_range(0.0, 0.45, 0.01) var water_shoreline_band_ratio: float = 0.18:
	set(new_ratio):
		var clamped_ratio := clampf(new_ratio, 0.0, 0.45)
		if is_equal_approx(water_shoreline_band_ratio, clamped_ratio):
			return
		water_shoreline_band_ratio = clamped_ratio
		_request_rebuild()

@export_range(0.0, 0.05, 0.001) var water_shoreline_lift: float = 0.006:
	set(new_lift):
		var clamped_lift := maxf(new_lift, 0.0)
		if is_equal_approx(water_shoreline_lift, clamped_lift):
			return
		water_shoreline_lift = clamped_lift
		_request_rebuild()

@export_range(0.0, 0.05, 0.001) var water_surface_layer_lift: float = 0.003:
	set(new_lift):
		var clamped_lift := maxf(new_lift, 0.0)
		if is_equal_approx(water_surface_layer_lift, clamped_lift):
			return
		water_surface_layer_lift = clamped_lift
		_request_rebuild()

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

var m_is_ready := false
var m_rebuild_queued := false
var m_sample_grid: Array[Array] = []
var m_source_size := Vector2i.ZERO
var m_heightmap_defines_water_area := false


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
	var cell := m_sample_grid[clamped_cell.y][clamped_cell.x] as _TerrainCell
	if cell == null:
		return land_height
	if cell.kind == TerrainCellKind.WATER:
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


func get_sample_cell_kind(sample_cell: Vector2i) -> TerrainCellKind:
	if m_sample_grid.is_empty():
		return TerrainCellKind.WATER

	var grid_size := Vector2i(m_sample_grid[0].size(), m_sample_grid.size())
	var clamped_cell := Vector2i(
		clampi(sample_cell.x, 0, grid_size.x - 1),
		clampi(sample_cell.y, 0, grid_size.y - 1)
	)
	var cell := m_sample_grid[clamped_cell.y][clamped_cell.x] as _TerrainCell
	if cell == null:
		return TerrainCellKind.WATER
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
	var cell := m_sample_grid[sample_cell.y][sample_cell.x] as _TerrainCell
	if cell == null:
		return land_height
	if cell.kind == TerrainCellKind.WATER:
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

	var grid := _build_sample_grid(mask_image, profile, heightmap_image, source_size)
	var heightmap_defines_water_area := _heightmap_fills_source_land(heightmap_image)
	if smooth_land_surface:
		_smooth_sample_grid_heights(grid, height_smoothing_passes, heightmap_defines_water_area)
	if heightmap_defines_water_area:
		_apply_heightmap_water_level(grid)
	m_sample_grid = grid
	m_source_size = source_size
	m_heightmap_defines_water_area = heightmap_defines_water_area
	_build_meshes_from_grid(grid, source_size.x, source_size.y, heightmap_defines_water_area)


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
	return image


func _resolve_generation_source_size(mask_image: Image, heightmap_image: Image) -> Vector2i:
	if heightmap_expands_land_to_source and heightmap_image != null:
		return heightmap_image.get_size()
	if mask_image != null:
		return mask_image.get_size()
	if heightmap_image != null:
		return heightmap_image.get_size()
	return Vector2i.ZERO


func _heightmap_fills_source_land(heightmap_image: Image) -> bool:
	return heightmap_expands_land_to_source and heightmap_image != null


func _build_sample_grid(
	mask_image: Image,
	profile: TerrainGenerationProfile,
	heightmap_image: Image,
	source_size: Vector2i
) -> Array[Array]:
	var grid: Array[Array] = []
	var grid_width := ceili(float(source_size.x) / float(sample_stride))
	var grid_height := ceili(float(source_size.y) / float(sample_stride))
	var heightmap_fills_land := _heightmap_fills_source_land(heightmap_image)

	for grid_y in range(grid_height):
		var row: Array[_TerrainCell] = []
		var start_y := grid_y * sample_stride
		for grid_x in range(grid_width):
			var start_x := grid_x * sample_stride
			var kind := _classify_sample_block(mask_image, profile, source_size, start_x, start_y, heightmap_fills_land)
			var sample_height := land_height
			var end_x := mini(start_x + sample_stride, source_size.x)
			var end_y := mini(start_y + sample_stride, source_size.y)
			if kind != TerrainCellKind.WATER or heightmap_fills_land:
				sample_height += _sample_heightmap_offset(heightmap_image, source_size, start_x, start_y, end_x, end_y)
			row.append(_TerrainCell.new(kind, sample_height))
		grid.append(row)

	return grid


func _smooth_sample_grid_heights(grid: Array[Array], smoothing_passes: int, include_water_cells: bool) -> void:
	if grid.is_empty() or smoothing_passes <= 0:
		return

	var grid_height := grid.size()
	var grid_width := grid[0].size()

	for _pass_index in range(smoothing_passes):
		var smoothed_rows: Array[PackedFloat32Array] = []
		for y in range(grid_height):
			var smoothed_row := PackedFloat32Array()
			smoothed_row.resize(grid_width)
			for x in range(grid_width):
				var cell := grid[y][x] as _TerrainCell
				if cell == null or (cell.kind == TerrainCellKind.WATER and !include_water_cells):
					smoothed_row[x] = water_height
					continue

				var total_height := 0.0
				var sample_count := 0
				for sample_y in range(y - 1, y + 2):
					for sample_x in range(x - 1, x + 2):
						if _is_outside_grid(grid, sample_x, sample_y):
							continue
						var sample_cell := grid[sample_y][sample_x] as _TerrainCell
						if sample_cell == null or (sample_cell.kind == TerrainCellKind.WATER and !include_water_cells):
							continue
						total_height += sample_cell.height
						sample_count += 1

				if sample_count <= 0:
					smoothed_row[x] = cell.height
				else:
					smoothed_row[x] = total_height / float(sample_count)
			smoothed_rows.append(smoothed_row)

		for y in range(grid_height):
			for x in range(grid_width):
				var cell := grid[y][x] as _TerrainCell
				if cell == null or (cell.kind == TerrainCellKind.WATER and !include_water_cells):
					continue
				cell.height = smoothed_rows[y][x]


func _apply_heightmap_water_level(grid: Array[Array]) -> void:
	for row in grid:
		for cell_value: Variant in row:
			var cell := cell_value as _TerrainCell
			if cell == null:
				continue
			if cell.height <= water_height + HEIGHT_EPSILON:
				cell.kind = TerrainCellKind.WATER
			elif cell.kind == TerrainCellKind.WATER:
				cell.kind = TerrainCellKind.LAND


func _classify_sample_block(
	image: Image,
	profile: TerrainGenerationProfile,
	source_size: Vector2i,
	start_x: int,
	start_y: int,
	fill_water_as_land: bool
) -> TerrainCellKind:
	if image == null:
		return TerrainCellKind.LAND if fill_water_as_land else TerrainCellKind.WATER

	var end_x := mini(start_x + sample_stride, source_size.x)
	var end_y := mini(start_y + sample_stride, source_size.y)
	var land_count := 0
	var street_count := 0
	var building_count := 0

	for y in range(start_y, end_y):
		for x in range(start_x, end_x):
			var pixel := _sample_image_at_source_pixel(image, source_size, x, y)
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

	if street_count > 0:
		return TerrainCellKind.STREET
	if building_count > 0:
		return TerrainCellKind.BUILDING
	if land_count > 0:
		return TerrainCellKind.LAND
	if fill_water_as_land:
		return TerrainCellKind.LAND
	return TerrainCellKind.WATER


func _sample_image_at_source_pixel(image: Image, source_size: Vector2i, source_x: int, source_y: int) -> Color:
	var image_width := image.get_width()
	var image_height := image.get_height()
	if image_width <= 0 or image_height <= 0 or source_size.x <= 0 or source_size.y <= 0:
		return Color.TRANSPARENT

	var image_x := clampi(floori((float(source_x) + 0.5) / float(source_size.x) * float(image_width)), 0, image_width - 1)
	var image_y := clampi(floori((float(source_y) + 0.5) / float(source_size.y) * float(image_height)), 0, image_height - 1)
	return image.get_pixel(image_x, image_y)


func _sample_heightmap_offset(
	heightmap_image: Image,
	source_size: Vector2i,
	start_x: int,
	start_y: int,
	end_x: int,
	end_y: int
) -> float:
	if heightmap_image == null:
		return 0.0

	var heightmap_width := heightmap_image.get_width()
	var heightmap_height := heightmap_image.get_height()
	if heightmap_width <= 0 or heightmap_height <= 0 or source_size.x <= 0 or source_size.y <= 0:
		return 0.0

	var center_x := (float(start_x) + float(end_x)) * 0.5
	var center_y := (float(start_y) + float(end_y)) * 0.5
	var sample_x := clampi(floori(center_x / float(source_size.x) * float(heightmap_width)), 0, heightmap_width - 1)
	var sample_y := clampi(floori(center_y / float(source_size.y) * float(heightmap_height)), 0, heightmap_height - 1)
	var pixel := heightmap_image.get_pixel(sample_x, sample_y)
	var normalized_height := pixel.r * 0.2126 + pixel.g * 0.7152 + pixel.b * 0.0722
	return lerpf(heightmap_min_offset, heightmap_max_offset, normalized_height)


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
			var cell := grid[y][x] as _TerrainCell
			if cell == null:
				continue
			var kind: TerrainCellKind = cell.kind
			var min_x := origin_offset.x + float(x) * cell_size
			var max_x := min_x + cell_size
			var min_z := origin_offset.z + float(y) * cell_size
			var max_z := min_z + cell_size

			match kind:
				TerrainCellKind.WATER:
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
				TerrainCellKind.STREET:
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
				TerrainCellKind.BUILDING:
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

	_add_mesh_instance("WaterMesh", water_builder, _build_water_material("Low Poly Water", water_rendering.material_alpha))
	_add_mesh_instance(
		"WaterSurfaceLayerMesh",
		water_surface_layer_builder,
		_build_material("Low Poly Water Surface Layer", water_rendering.surface_layer_color, true)
	)
	_add_mesh_instance(
		"WaterShorelineMesh",
		water_shoreline_builder,
		_build_material("Low Poly Water Shoreline", water_rendering.shoreline_color, true)
	)
	_add_mesh_instance("LandMesh", land_builder, _build_material("Low Poly Land", _resolve_style_color("land_color", land_color), false))
	_add_mesh_instance("ShorelineMesh", shoreline_builder, _build_material("Low Poly Shoreline", _resolve_style_color("shoreline_color", shoreline_color), false))
	_add_mesh_instance("StreetMesh", street_builder, _build_material("Low Poly Streets", _resolve_style_color("street_color", street_color), false))
	_add_mesh_instance(
		"BuildingFootprintMesh",
		building_builder,
		_build_material("Low Poly Building Footprints", _resolve_style_color("building_footprint_color", building_footprint_color), false)
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
			var cell := grid[y][x] as _TerrainCell
			if cell == null or cell.kind != TerrainCellKind.WATER:
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
	return Vector3(
		-float(grid_size.x) * cell_size * 0.5,
		0.0,
		-float(grid_size.y) * cell_size * 0.5
	)


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
			var cell := grid[y][x] as _TerrainCell
			if cell == null or (cell.kind == TerrainCellKind.WATER and !include_water_cells):
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
	var cell := grid[y][x] as _TerrainCell
	return cell == null or cell.kind == TerrainCellKind.WATER


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
	var cell := grid[y][x] as _TerrainCell
	return cell != null and cell.kind != TerrainCellKind.WATER


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
	var cell := grid[y][x] as _TerrainCell
	if cell == null:
		return water_height
	return cell.height


func _add_mesh_instance(name_value: String, builder: _MeshBuildState, material: StandardMaterial3D) -> void:
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


func _build_water_material(name_value: String, alpha: float) -> StandardMaterial3D:
	var material := _build_material(name_value, Color(1.0, 1.0, 1.0, alpha), true)
	material.vertex_color_use_as_albedo = true
	return material


func _build_water_rendering() -> _WaterRendering:
	var rendering := _WaterRendering.new()
	rendering.base_color = _resolve_style_color(&"water_color", water_color)
	rendering.deep_color = _resolve_style_color(&"water_deep_color", water_deep_color)
	rendering.surface_layer_color = _resolve_style_color(&"water_surface_layer_color", water_surface_layer_color)
	rendering.shoreline_color = _resolve_style_color(&"water_shoreline_color", water_shoreline_color)
	rendering.highlight_color = _resolve_style_color(&"water_highlight_color", water_highlight_color)
	rendering.material_alpha = clampf(maxf(rendering.base_color.a, rendering.deep_color.a), 0.0, 0.62)
	rendering.wave_depth = maxf(_resolve_style_float(&"water_wave_depth", water_wave_depth), 0.0)
	rendering.wave_frequency = maxf(_resolve_style_float(&"water_wave_frequency", water_wave_frequency), 0.05)
	rendering.shoreline_band_ratio = clampf(
		_resolve_style_float(&"water_shoreline_band_ratio", water_shoreline_band_ratio),
		0.0,
		0.45
	)
	rendering.shoreline_lift = maxf(_resolve_style_float(&"water_shoreline_lift", water_shoreline_lift), 0.0)
	rendering.surface_layer_lift = maxf(_resolve_style_float(&"water_surface_layer_lift", water_surface_layer_lift), 0.0)
	return rendering


func _resolve_style_color(property_name: StringName, fallback: Color) -> Color:
	if art_style == null:
		return fallback
	var value: Variant = art_style.get(property_name)
	if value is Color:
		return value
	return fallback


func _resolve_style_float(property_name: StringName, fallback: float) -> float:
	if art_style == null:
		return fallback
	var value: Variant = art_style.get(property_name)
	if value is float or value is int:
		return float(value)
	return fallback


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


class _TerrainCell:
	var kind: int
	var height: float

	func _init(cell_kind: int, cell_height: float) -> void:
		kind = cell_kind
		height = cell_height


class _WaterRendering:
	var base_color := Color(0.42, 0.68, 0.83, 0.46)
	var deep_color := Color(0.24, 0.48, 0.67, 0.54)
	var surface_layer_color := Color(0.72, 0.90, 0.96, 0.24)
	var shoreline_color := Color(0.60, 0.83, 0.88, 0.50)
	var highlight_color := Color(0.86, 0.96, 0.98, 0.40)
	var material_alpha := 0.54
	var wave_depth := 0.045
	var wave_frequency := 0.48
	var shoreline_band_ratio := 0.18
	var shoreline_lift := 0.006
	var surface_layer_lift := 0.003
