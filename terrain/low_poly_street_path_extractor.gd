@tool
class_name LowPolyStreetPathExtractor
extends RefCounted

## Converts sampled STREET cells into deterministic centerline polylines. The
## thinning pass removes the width introduced when a source line touches more
## than one sample block; graph tracing then preserves bends and junctions.

const NEIGHBOR_OFFSETS := [
	Vector2i(0, -1),
	Vector2i(1, -1),
	Vector2i(1, 0),
	Vector2i(1, 1),
	Vector2i(0, 1),
	Vector2i(-1, 1),
	Vector2i(-1, 0),
	Vector2i(-1, -1),
]


func extract(
	grid: Array[Array],
	cell_size: float,
	origin_offset: Vector3,
	minimum_path_cells := 2,
	maximum_paths := 256,
	simplify_tolerance_cells := 0.35
) -> Dictionary:
	var result := {
		"paths": [] as Array[PackedVector3Array],
		"street_cell_count": 0,
		"skeleton_cell_count": 0,
		"discarded_path_count": 0,
		"truncated_path_count": 0,
	}
	if grid.is_empty() or grid[0].is_empty():
		return result
	var bitmap := _build_street_bitmap(grid)
	result["street_cell_count"] = _count_pixels(bitmap)
	if int(result["street_cell_count"]) == 0:
		return result
	_thin(bitmap)
	result["skeleton_cell_count"] = _count_pixels(bitmap)
	var cell_paths := _trace_paths(bitmap)
	cell_paths.sort_custom(_sort_cell_paths)
	var paths: Array[PackedVector3Array] = []
	var minimum_cells := maxi(minimum_path_cells, 2)
	var path_limit := maxi(maximum_paths, 1)
	for cell_path: Array[Vector2i] in cell_paths:
		if cell_path.size() < minimum_cells:
			result["discarded_path_count"] = int(result["discarded_path_count"]) + 1
			continue
		if paths.size() >= path_limit:
			result["truncated_path_count"] = int(result["truncated_path_count"]) + 1
			continue
		var simplified := _simplify_path(cell_path, maxf(simplify_tolerance_cells, 0.0))
		if simplified.size() < 2:
			result["discarded_path_count"] = int(result["discarded_path_count"]) + 1
			continue
		paths.append(_to_terrain_path(simplified, grid, cell_size, origin_offset))
	result["paths"] = paths
	return result


func _build_street_bitmap(grid: Array[Array]) -> Array[PackedByteArray]:
	var bitmap: Array[PackedByteArray] = []
	for row_value: Array in grid:
		var row := PackedByteArray()
		row.resize(row_value.size())
		for x in range(row_value.size()):
			var cell := row_value[x] as LowPolyTerrainCell
			row[x] = 1 if cell != null and cell.kind == LowPolyTerrainCell.Kind.STREET else 0
		bitmap.append(row)
	return bitmap


func _thin(bitmap: Array[PackedByteArray]) -> void:
	if bitmap.size() < 3 or bitmap[0].size() < 3:
		return
	var changed := true
	while changed:
		changed = _thin_subiteration(bitmap, true)
		changed = _thin_subiteration(bitmap, false) or changed


func _thin_subiteration(bitmap: Array[PackedByteArray], first_pass: bool) -> bool:
	var removals: Array[Vector2i] = []
	for y in range(1, bitmap.size() - 1):
		for x in range(1, bitmap[y].size() - 1):
			if bitmap[y][x] == 0:
				continue
			var neighbors := PackedByteArray()
			for offset: Vector2i in NEIGHBOR_OFFSETS:
				neighbors.append(bitmap[y + offset.y][x + offset.x])
			var neighbor_count := 0
			var transitions := 0
			for index in range(neighbors.size()):
				neighbor_count += int(neighbors[index])
				if neighbors[index] == 0 and neighbors[(index + 1) % neighbors.size()] != 0:
					transitions += 1
			if neighbor_count < 2 or neighbor_count > 6 or transitions != 1:
				continue
			var north := int(neighbors[0])
			var east := int(neighbors[2])
			var south := int(neighbors[4])
			var west := int(neighbors[6])
			if first_pass:
				if north * east * south != 0 or east * south * west != 0:
					continue
			else:
				if north * east * west != 0 or north * south * west != 0:
					continue
			removals.append(Vector2i(x, y))
	for point: Vector2i in removals:
		bitmap[point.y][point.x] = 0
	return !removals.is_empty()


func _trace_paths(bitmap: Array[PackedByteArray]) -> Array[Array]:
	var paths: Array[Array] = []
	var visited_edges: Dictionary = {}
	var graph_points: Array[Vector2i] = []
	for y in range(bitmap.size()):
		for x in range(bitmap[y].size()):
			if bitmap[y][x] != 0:
				graph_points.append(Vector2i(x, y))
	graph_points.sort_custom(_sort_points)

	# Start at endpoints and junctions so every branch becomes its own editable
	# multipoint Street3D path.
	for point: Vector2i in graph_points:
		var neighbors := _graph_neighbors(bitmap, point)
		if neighbors.size() == 2:
			continue
		for neighbor: Vector2i in neighbors:
			if visited_edges.has(_edge_key(point, neighbor)):
				continue
			paths.append(_trace_edge_chain(bitmap, point, neighbor, visited_edges))

	# Closed loops have no endpoint or junction, so trace any remaining edge.
	for point: Vector2i in graph_points:
		for neighbor: Vector2i in _graph_neighbors(bitmap, point):
			if visited_edges.has(_edge_key(point, neighbor)):
				continue
			paths.append(_trace_edge_chain(bitmap, point, neighbor, visited_edges))
	return paths


func _trace_edge_chain(
	bitmap: Array[PackedByteArray],
	start: Vector2i,
	first: Vector2i,
	visited_edges: Dictionary
) -> Array[Vector2i]:
	var path: Array[Vector2i] = [start, first]
	visited_edges[_edge_key(start, first)] = true
	var previous := start
	var current := first
	while true:
		var neighbors := _graph_neighbors(bitmap, current)
		if neighbors.size() != 2:
			break
		var next_candidates: Array[Vector2i] = []
		for neighbor: Vector2i in neighbors:
			if neighbor != previous:
				next_candidates.append(neighbor)
		if next_candidates.is_empty():
			break
		var next := next_candidates[0]
		var key := _edge_key(current, next)
		if visited_edges.has(key):
			break
		visited_edges[key] = true
		path.append(next)
		previous = current
		current = next
	return path


func _graph_neighbors(bitmap: Array[PackedByteArray], point: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset: Vector2i in NEIGHBOR_OFFSETS:
		var neighbor := point + offset
		if !_pixel_is_set(bitmap, neighbor):
			continue
		# When an orthogonal route exists, do not also add its corner-cutting
		# diagonal. This keeps an L bend at degree two instead of making a tiny
		# three-edge junction.
		if offset.x != 0 and offset.y != 0:
			if (
				_pixel_is_set(bitmap, point + Vector2i(offset.x, 0))
				or _pixel_is_set(bitmap, point + Vector2i(0, offset.y))
			):
				continue
		result.append(neighbor)
	result.sort_custom(_sort_points)
	return result


func _simplify_path(path: Array[Vector2i], tolerance: float) -> Array[Vector2i]:
	if path.size() <= 2 or tolerance <= 0.0:
		return path.duplicate()
	var keep := PackedByteArray()
	keep.resize(path.size())
	keep[0] = 1
	keep[path.size() - 1] = 1
	_simplify_range(path, 0, path.size() - 1, tolerance, keep)
	var result: Array[Vector2i] = []
	for index in range(path.size()):
		if keep[index] != 0:
			result.append(path[index])
	return result


func _simplify_range(
	path: Array[Vector2i],
	start: int,
	end: int,
	tolerance: float,
	keep: PackedByteArray
) -> void:
	if end <= start + 1:
		return
	var a := Vector2(path[start])
	var b := Vector2(path[end])
	var maximum_distance := -1.0
	var maximum_index := -1
	for index in range(start + 1, end):
		var distance := _point_segment_distance(Vector2(path[index]), a, b)
		if distance > maximum_distance:
			maximum_distance = distance
			maximum_index = index
	if maximum_distance <= tolerance or maximum_index < 0:
		return
	keep[maximum_index] = 1
	_simplify_range(path, start, maximum_index, tolerance, keep)
	_simplify_range(path, maximum_index, end, tolerance, keep)


func _to_terrain_path(
	cell_path: Array[Vector2i],
	grid: Array[Array],
	cell_size: float,
	origin_offset: Vector3
) -> PackedVector3Array:
	var result := PackedVector3Array()
	for point: Vector2i in cell_path:
		var cell := grid[point.y][point.x] as LowPolyTerrainCell
		result.append(Vector3(
			origin_offset.x + (float(point.x) + 0.5) * cell_size,
			cell.height if cell != null else 0.0,
			origin_offset.z + (float(point.y) + 0.5) * cell_size
		))
	return result


func _pixel_is_set(bitmap: Array[PackedByteArray], point: Vector2i) -> bool:
	if point.y < 0 or point.y >= bitmap.size():
		return false
	if point.x < 0 or point.x >= bitmap[point.y].size():
		return false
	return bitmap[point.y][point.x] != 0


func _count_pixels(bitmap: Array[PackedByteArray]) -> int:
	var count := 0
	for row: PackedByteArray in bitmap:
		for value in row:
			count += int(value)
	return count


func _point_segment_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	var segment := b - a
	var length_squared := segment.length_squared()
	if length_squared <= 0.000001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(a + segment * t)


func _edge_key(a: Vector2i, b: Vector2i) -> String:
	if _point_precedes(b, a):
		var swap := a
		a = b
		b = swap
	return "%d,%d|%d,%d" % [a.x, a.y, b.x, b.y]


func _point_precedes(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y or (a.y == b.y and a.x < b.x)


func _sort_points(a: Vector2i, b: Vector2i) -> bool:
	return _point_precedes(a, b)


func _sort_cell_paths(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return a.size() > b.size()
	if a.is_empty() or b.is_empty():
		return false
	return _point_precedes(a[0], b[0])
