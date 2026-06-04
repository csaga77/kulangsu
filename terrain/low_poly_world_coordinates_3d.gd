@tool
class_name LowPolyWorldCoordinates3D
extends Resource

@export_file_path("*.png") var mask_file := "res://design/gulangyu_map_mini_export.png":
	set(new_mask_file):
		if mask_file == new_mask_file:
			return
		mask_file = new_mask_file
		m_cached_source_size = Vector2i.ZERO

@export_range(1, 32, 1) var sample_stride := 4:
	set(new_stride):
		sample_stride = maxi(new_stride, 1)

@export_range(0.1, 10.0, 0.1) var cell_size := 1.0:
	set(new_cell_size):
		cell_size = maxf(new_cell_size, 0.1)

@export var isometric_tile_size := Vector2(64.0, 32.0):
	set(new_tile_size):
		isometric_tile_size = Vector2(maxf(new_tile_size.x, 0.001), maxf(new_tile_size.y, 0.001))

@export var source_size := Vector2i.ZERO:
	set(new_source_size):
		source_size = Vector2i(maxi(new_source_size.x, 0), maxi(new_source_size.y, 0))
		m_cached_source_size = Vector2i.ZERO

var m_cached_source_size := Vector2i.ZERO


func configure_from_terrain(terrain: Node) -> void:
	if !is_instance_valid(terrain):
		return

	var terrain_mask_file: Variant = terrain.get("mask_file")
	if terrain_mask_file is String:
		mask_file = terrain_mask_file

	var terrain_sample_stride: Variant = terrain.get("sample_stride")
	if terrain_sample_stride is int:
		sample_stride = terrain_sample_stride

	var terrain_cell_size: Variant = terrain.get("cell_size")
	if terrain_cell_size is float or terrain_cell_size is int:
		cell_size = float(terrain_cell_size)

	source_size = Vector2i.ZERO


func resolve_source_size() -> Vector2i:
	if source_size.x > 0 and source_size.y > 0:
		return source_size
	if m_cached_source_size.x > 0 and m_cached_source_size.y > 0:
		return m_cached_source_size
	if mask_file.is_empty():
		push_warning("LowPolyWorldCoordinates3D requires a mask_file.")
		return Vector2i.ZERO

	var image := Image.new()
	var load_error := image.load(mask_file)
	if load_error != OK:
		push_error("LowPolyWorldCoordinates3D failed to load mask image: %s (err=%d)" % [mask_file, load_error])
		return Vector2i.ZERO

	m_cached_source_size = image.get_size()
	return m_cached_source_size


func get_grid_size() -> Vector2i:
	var resolved_source_size := resolve_source_size()
	if resolved_source_size == Vector2i.ZERO:
		return Vector2i.ZERO

	return Vector2i(
		ceili(float(resolved_source_size.x) / float(sample_stride)),
		ceili(float(resolved_source_size.y) / float(sample_stride))
	)


func get_world_origin() -> Vector3:
	var grid_size := get_grid_size()
	return Vector3(
		-float(grid_size.x) * cell_size * 0.5,
		0.0,
		-float(grid_size.y) * cell_size * 0.5
	)


func mask_pixel_to_world_position(mask_pixel: Vector2, height: float = 0.0) -> Vector3:
	var origin := get_world_origin()
	return Vector3(
		origin.x + (mask_pixel.x / float(sample_stride)) * cell_size,
		height,
		origin.z + (mask_pixel.y / float(sample_stride)) * cell_size
	)


func world2d_to_world3d(position_2d: Vector2, elevation: float = 0.0) -> Vector3:
	return mask_pixel_to_world_position(position_2d, elevation)


func world_position_to_mask_pixel(world_position: Vector3) -> Vector2:
	var origin := get_world_origin()
	return Vector2(
		((world_position.x - origin.x) / cell_size) * float(sample_stride),
		((world_position.z - origin.z) / cell_size) * float(sample_stride)
	)


func world3d_to_world2d(world_position: Vector3) -> Vector2:
	return world_position_to_mask_pixel(world_position)


func isometric_position_to_mask_pixel(isometric_position: Vector2) -> Vector2:
	var half_tile_size := isometric_tile_size * 0.5
	var diagonal_x := isometric_position.x / half_tile_size.x
	var diagonal_y := isometric_position.y / half_tile_size.y
	return Vector2(
		(diagonal_y + diagonal_x) * 0.5,
		(diagonal_y - diagonal_x) * 0.5
	)


func mask_pixel_to_isometric_position(mask_pixel: Vector2) -> Vector2:
	var half_tile_size := isometric_tile_size * 0.5
	return Vector2(
		(mask_pixel.x - mask_pixel.y) * half_tile_size.x,
		(mask_pixel.x + mask_pixel.y) * half_tile_size.y
	)


func mask_pixel_to_sample_cell(mask_pixel: Vector2i) -> Vector2i:
	var grid_size := get_grid_size()
	if grid_size == Vector2i.ZERO:
		return Vector2i.ZERO

	return Vector2i(
		clampi(mask_pixel.x / sample_stride, 0, grid_size.x - 1),
		clampi(mask_pixel.y / sample_stride, 0, grid_size.y - 1)
	)


func sample_cell_to_world_center(sample_cell: Vector2i, height: float = 0.0) -> Vector3:
	var grid_size := get_grid_size()
	if grid_size == Vector2i.ZERO:
		return Vector3.ZERO

	var clamped_cell := Vector2i(
		clampi(sample_cell.x, 0, grid_size.x - 1),
		clampi(sample_cell.y, 0, grid_size.y - 1)
	)
	var origin := get_world_origin()
	return Vector3(
		origin.x + (float(clamped_cell.x) + 0.5) * cell_size,
		height,
		origin.z + (float(clamped_cell.y) + 0.5) * cell_size
	)


func world_position_to_sample_cell(world_position: Vector3) -> Vector2i:
	var mask_pixel := world_position_to_mask_pixel(world_position)
	return mask_pixel_to_sample_cell(Vector2i(floori(mask_pixel.x), floori(mask_pixel.y)))


func is_mask_pixel_inside(mask_pixel: Vector2) -> bool:
	var resolved_source_size := resolve_source_size()
	return (
		mask_pixel.x >= 0.0
		and mask_pixel.y >= 0.0
		and mask_pixel.x < float(resolved_source_size.x)
		and mask_pixel.y < float(resolved_source_size.y)
	)
