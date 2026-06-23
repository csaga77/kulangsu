@tool
class_name LowPolyTerrainSampler
extends RefCounted

## Samples the terrain mask plus optional grayscale heightmap into a coarse grid of
## LowPolyTerrainCell values. This is the "images -> cell grid" half of the low-poly 3D
## terrain pipeline; LowPolyTerrain3D owns the "cell grid -> meshes" half and the public
## surface-height queries.
##
## Configure the scalar fields to match the owning terrain node, then call build_grid().

const HEIGHT_EPSILON := 0.001

var sample_stride := 4
var land_height := 0.22
var water_height := 0.0
var smooth_land_surface := true
var height_smoothing_passes := 1
var heightmap_min_offset := 0.0
var heightmap_max_offset := 0.0
var heightmap_expands_land_to_source := true


func build_grid(
	mask_image: Image,
	profile: TerrainGenerationProfile,
	heightmap_image: Image,
	source_size: Vector2i
) -> Array[Array]:
	var grid := _build_sample_grid(mask_image, profile, heightmap_image, source_size)
	var heightmap_defines_water_area := heightmap_fills_source_land(heightmap_image)
	if smooth_land_surface:
		_smooth_sample_grid_heights(grid, height_smoothing_passes, heightmap_defines_water_area)
	if heightmap_defines_water_area:
		_apply_heightmap_water_level(grid)
	return grid


func heightmap_fills_source_land(heightmap_image: Image) -> bool:
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
	var heightmap_fills_land := heightmap_fills_source_land(heightmap_image)
	var mask_reader := LowPolyImagePixelReader.new(mask_image) if mask_image != null else null
	var heightmap_reader := LowPolyImagePixelReader.new(heightmap_image) if heightmap_image != null else null

	for grid_y in range(grid_height):
		var row: Array[LowPolyTerrainCell] = []
		var start_y := grid_y * sample_stride
		for grid_x in range(grid_width):
			var start_x := grid_x * sample_stride
			var kind := _classify_sample_block(mask_reader, profile, source_size, start_x, start_y, heightmap_fills_land)
			var sample_height := land_height
			var end_x := mini(start_x + sample_stride, source_size.x)
			var end_y := mini(start_y + sample_stride, source_size.y)
			if kind != LowPolyTerrainCell.Kind.WATER or heightmap_fills_land:
				sample_height += _sample_heightmap_offset(heightmap_reader, source_size, start_x, start_y, end_x, end_y)
			row.append(LowPolyTerrainCell.new(kind, sample_height))
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
				var cell := grid[y][x] as LowPolyTerrainCell
				if cell == null or (cell.kind == LowPolyTerrainCell.Kind.WATER and !include_water_cells):
					# Land-only smoothing skips water cells; their slot is never read back.
					continue

				var total_height := 0.0
				var sample_count := 0
				for sample_y in range(y - 1, y + 2):
					for sample_x in range(x - 1, x + 2):
						if _is_outside_grid(grid, sample_x, sample_y):
							continue
						var sample_cell := grid[sample_y][sample_x] as LowPolyTerrainCell
						if sample_cell == null or (sample_cell.kind == LowPolyTerrainCell.Kind.WATER and !include_water_cells):
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
				var cell := grid[y][x] as LowPolyTerrainCell
				if cell == null or (cell.kind == LowPolyTerrainCell.Kind.WATER and !include_water_cells):
					continue
				cell.height = smoothed_rows[y][x]


func _apply_heightmap_water_level(grid: Array[Array]) -> void:
	for row in grid:
		for cell_value: Variant in row:
			var cell := cell_value as LowPolyTerrainCell
			if cell == null:
				continue
			if cell.height <= water_height + HEIGHT_EPSILON:
				cell.kind = LowPolyTerrainCell.Kind.WATER
			elif cell.kind == LowPolyTerrainCell.Kind.WATER:
				cell.kind = LowPolyTerrainCell.Kind.LAND


func _classify_sample_block(
	mask_reader: LowPolyImagePixelReader,
	profile: TerrainGenerationProfile,
	source_size: Vector2i,
	start_x: int,
	start_y: int,
	fill_water_as_land: bool
) -> LowPolyTerrainCell.Kind:
	if mask_reader == null:
		return LowPolyTerrainCell.Kind.LAND if fill_water_as_land else LowPolyTerrainCell.Kind.WATER

	var end_x := mini(start_x + sample_stride, source_size.x)
	var end_y := mini(start_y + sample_stride, source_size.y)
	var land_count := 0
	var street_count := 0
	var building_count := 0

	for y in range(start_y, end_y):
		for x in range(start_x, end_x):
			var pixel := _sample_image_at_source_pixel(mask_reader, source_size, x, y)
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
		return LowPolyTerrainCell.Kind.STREET
	if building_count > 0:
		return LowPolyTerrainCell.Kind.BUILDING
	if land_count > 0:
		return LowPolyTerrainCell.Kind.LAND
	if fill_water_as_land:
		return LowPolyTerrainCell.Kind.LAND
	return LowPolyTerrainCell.Kind.WATER


func _sample_image_at_source_pixel(mask_reader: LowPolyImagePixelReader, source_size: Vector2i, source_x: int, source_y: int) -> Color:
	var image_width := mask_reader.width
	var image_height := mask_reader.height
	if image_width <= 0 or image_height <= 0 or source_size.x <= 0 or source_size.y <= 0:
		return Color.TRANSPARENT

	var image_x := clampi(floori((float(source_x) + 0.5) / float(source_size.x) * float(image_width)), 0, image_width - 1)
	var image_y := clampi(floori((float(source_y) + 0.5) / float(source_size.y) * float(image_height)), 0, image_height - 1)
	return mask_reader.get_pixel(image_x, image_y)


func _sample_heightmap_offset(
	heightmap_reader: LowPolyImagePixelReader,
	source_size: Vector2i,
	start_x: int,
	start_y: int,
	end_x: int,
	end_y: int
) -> float:
	if heightmap_reader == null:
		return 0.0

	var heightmap_width := heightmap_reader.width
	var heightmap_height := heightmap_reader.height
	if heightmap_width <= 0 or heightmap_height <= 0 or source_size.x <= 0 or source_size.y <= 0:
		return 0.0

	var center_x := (float(start_x) + float(end_x)) * 0.5
	var center_y := (float(start_y) + float(end_y)) * 0.5
	var sample_x := clampi(floori(center_x / float(source_size.x) * float(heightmap_width)), 0, heightmap_width - 1)
	var sample_y := clampi(floori(center_y / float(source_size.y) * float(heightmap_height)), 0, heightmap_height - 1)
	var pixel := heightmap_reader.get_pixel(sample_x, sample_y)
	var normalized_height := pixel.r * 0.2126 + pixel.g * 0.7152 + pixel.b * 0.0722
	return lerpf(heightmap_min_offset, heightmap_max_offset, normalized_height)


func _is_outside_grid(grid: Array[Array], x: int, y: int) -> bool:
	if y < 0 or y >= grid.size():
		return true
	return x < 0 or x >= grid[y].size()
