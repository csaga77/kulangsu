@tool
class_name LowPolyTerrainMeshBuilder
extends RefCounted

## Turns a coarse LowPolyTerrainCell grid into low-poly mesh geometry plus collision
## faces. This is the "cell grid -> meshes" half of the low-poly 3D terrain pipeline;
## LowPolyTerrainSampler owns the "images -> cell grid" half, and LowPolyTerrain3D owns
## exports, lifecycle, materials, wind, and the public node-level queries.
##
## Configure the scalar fields plus `water_rendering` to match the owning terrain node,
## then call build(). The corner/surface-height helpers are also reused by the node's
## surface-height queries so mesh geometry and placement queries never diverge.

const HEIGHT_EPSILON := 0.001
const CORNER_NW := 0
const CORNER_NE := 1
const CORNER_SE := 2
const CORNER_SW := 3

var cell_size := 1.0
var water_height := 0.0
var land_height := 0.22
var smooth_land_surface := true
var building_footprint_lift := 0.09
var water_land_overlap_cells := 1
var water_rendering: WaterRendering = null


## Build all low-poly mesh geometry and collision faces for the sampled grid. The
## returned MeshBuildResult holds one MeshBuildState per material pass plus the
## accumulated collision faces and per-kind cell counts; the node turns these into
## MeshInstance3D children with materials.
func build(
	grid: Array[Array],
	source_width: int,
	source_height: int,
	heightmap_defines_water_area: bool
) -> MeshBuildResult:
	var result := MeshBuildResult.new()
	if grid.is_empty():
		return result

	var grid_height := grid.size()
	var grid_width := grid[0].size()
	var origin_offset := _get_grid_origin_offset(Vector2i(grid_width, grid_height))

	var rendering := water_rendering
	if rendering == null:
		rendering = WaterRendering.new()
	var water_render_grid := _build_water_render_grid(grid)

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
					result.water_cells += 1
					if cell.height < water_height - HEIGHT_EPSILON:
						var seabed_corner_heights := _get_cell_corner_heights(grid, x, y, cell.height, true)
						_append_terrain_surface_cell(
							result.land,
							min_x,
							max_x,
							min_z,
							max_z,
							seabed_corner_heights
						)
				LowPolyTerrainCell.Kind.STREET:
					# The mask kind remains input for centerline extraction, but visible
					# roads are owned by Street3D. Render only their supporting land here.
					result.street_cells += 1
					result.land_cells += 1
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
						result.land,
						result.shoreline,
						result.collision_faces,
						!heightmap_defines_water_area
					)
				LowPolyTerrainCell.Kind.BUILDING:
					result.building_cells += 1
					result.land_cells += 1
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
						result.land,
						result.shoreline,
						result.collision_faces,
						!heightmap_defines_water_area
					)
					_append_inset_surface_quad(
						result.building,
						min_x,
						max_x,
						min_z,
						max_z,
						building_corner_heights,
						building_footprint_lift,
						0.14
					)
				_:
					result.land_cells += 1
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
						result.land,
						result.shoreline,
						result.collision_faces,
						!heightmap_defines_water_area
					)

			if _is_water_render_cell(water_render_grid, x, y):
				result.water_render_cells += 1
				_append_water_cell(
					grid,
					water_render_grid,
					x,
					y,
					min_x,
					max_x,
					min_z,
					max_z,
					result.water,
					result.water_shoreline,
					rendering
				)
				_append_water_surface_layer(
					result.water_surface_layer,
					min_x,
					max_x,
					min_z,
					max_z,
					rendering
				)

	return result


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
	land_builder: MeshBuildState,
	shoreline_builder: MeshBuildState,
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
	builder: MeshBuildState,
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


func _append_top_quad(builder: MeshBuildState, min_x: float, max_x: float, min_z: float, max_z: float, height: float) -> void:
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
	water_builder: MeshBuildState,
	water_shoreline_builder: MeshBuildState,
	rendering: WaterRendering
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
	builder: MeshBuildState,
	min_x: float,
	max_x: float,
	min_z: float,
	max_z: float,
	rendering: WaterRendering
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
	builder: MeshBuildState,
	rendering: WaterRendering
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
	builder: MeshBuildState,
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
	builder: MeshBuildState,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	color: Color
) -> void:
	_append_colored_surface_triangle(builder, a, b, c, color)
	_append_colored_surface_triangle(builder, a, c, d, color)


func _append_inset_surface_quad(
	builder: MeshBuildState,
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


func _append_surface_quad(builder: MeshBuildState, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_append_surface_triangle(builder, a, b, c)
	_append_surface_triangle(builder, a, c, d)


func _append_surface_triangle(builder: MeshBuildState, a: Vector3, b: Vector3, c: Vector3) -> void:
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


func _append_colored_surface_triangle(builder: MeshBuildState, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
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
	builder: MeshBuildState,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	normal: Vector3
) -> void:
	_append_quad(builder, a, b, c, d, normal)


func _append_quad(
	builder: MeshBuildState,
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


## Surface height at a fractional position inside a sampled cell. Shared by mesh
## building and the node's public placement queries so geometry and placement agree.
func get_cell_surface_height(
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
	rendering: WaterRendering
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


## Per-material-pass vertex/normal/color/index buffers accumulated during build().
## The node turns each populated MeshBuildState into an ArrayMesh MeshInstance3D.
class MeshBuildState:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()


## Resolved water palette and wave tuning consumed by the water passes. The node
## populates this from the active LowPolyArtStyle3D before calling build().
class WaterRendering:
	var base_color := Color(0.42, 0.68, 0.83, 0.46)
	var deep_color := Color(0.24, 0.48, 0.67, 0.54)
	var surface_layer_color := Color(0.72, 0.90, 0.96, 0.24)
	var shoreline_color := Color(0.95, 0.98, 1.0, 0.85)
	var highlight_color := Color(0.86, 0.96, 0.98, 0.40)
	var material_alpha := 0.54
	var wave_depth := 0.35
	var wave_frequency := 0.9
	var wave_speed := 1.5
	var shoreline_band_ratio := 0.30
	var shoreline_lift := 0.040
	var surface_layer_lift := 0.050


## Output of build(): one MeshBuildState per material pass plus accumulated collision
## faces and per-kind cell counts for the node summary log.
class MeshBuildResult:
	var land := MeshBuildState.new()
	var shoreline := MeshBuildState.new()
	var water := MeshBuildState.new()
	var water_surface_layer := MeshBuildState.new()
	var water_shoreline := MeshBuildState.new()
	var building := MeshBuildState.new()
	var collision_faces := PackedVector3Array()
	var land_cells := 0
	var street_cells := 0
	var building_cells := 0
	var water_cells := 0
	var water_render_cells := 0
