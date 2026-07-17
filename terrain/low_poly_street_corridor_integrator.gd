@tool
class_name LowPolyStreetCorridorIntegrator
extends RefCounted

const EPSILON := 0.00001


## Shapes the already-sampled terrain grid beneath generic published street
## corridors. Corridors are world-space dictionaries; the integrator converts
## them into the terrain's local grid frame and never imports Street3D.
func apply(
	grid: Array[Array],
	terrain: Node3D,
	corridors: Array[Dictionary],
	cell_size: float,
	origin_offset: Vector3,
	feather_width: float,
	shape_water_cells := false
) -> Dictionary:
	var stats := {
		"corridor_count": corridors.size(),
		"core_cells": 0,
		"feather_cells": 0,
		"water_cells_skipped": 0,
	}
	if grid.is_empty() or terrain == null or corridors.is_empty():
		return stats
	var local_corridors := _local_corridors(terrain, corridors)
	if local_corridors.is_empty():
		return stats
	var feather := maxf(feather_width, 0.0)
	var grid_size := Vector2i(grid[0].size(), grid.size())
	var spatial_index := _build_segment_spatial_index(
		local_corridors, grid_size, cell_size, origin_offset, feather
	)
	var segments: Array[Dictionary] = spatial_index["segments"]
	var buckets: Dictionary = spatial_index["buckets"]
	for y in range(grid.size()):
		for x in range(grid[y].size()):
			var cell := grid[y][x] as LowPolyTerrainCell
			if cell == null:
				continue
			var candidate_segments: PackedInt32Array = buckets.get(
				y * grid_size.x + x, PackedInt32Array()
			)
			if candidate_segments.is_empty():
				continue
			var point := Vector2(
				origin_offset.x + (float(x) + 0.5) * cell_size,
				origin_offset.z + (float(y) + 0.5) * cell_size
			)
			var influence := _strongest_influence(
				point, local_corridors, segments, candidate_segments, feather
			)
			if influence.is_empty():
				continue
			if cell.kind == LowPolyTerrainCell.Kind.WATER and !shape_water_cells:
				stats["water_cells_skipped"] = int(stats["water_cells_skipped"]) + 1
				continue
			var weight := float(influence["weight"])
			var target_height := float(influence["profile_height"]) - float(influence["bed_depth"])
			cell.height = lerpf(cell.height, target_height, weight)
			if bool(influence["inside_core"]):
				cell.kind = LowPolyTerrainCell.Kind.LAND
				stats["core_cells"] = int(stats["core_cells"]) + 1
			else:
				stats["feather_cells"] = int(stats["feather_cells"]) + 1
	return stats


func _local_corridors(terrain: Node3D, corridors: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var terrain_scale := terrain.global_transform.basis.get_scale()
	var horizontal_scale := maxf(maxf(absf(terrain_scale.x), absf(terrain_scale.z)), EPSILON)
	var vertical_scale := maxf(absf(terrain_scale.y), EPSILON)
	for corridor: Dictionary in corridors:
		var world_path: PackedVector3Array = corridor.get("path", PackedVector3Array())
		if world_path.size() < 2:
			continue
		var local_path := PackedVector3Array()
		for world_point in world_path:
			local_path.append(terrain.to_local(world_point))
		result.append({
			"path": local_path,
			"half_width": maxf(float(corridor.get("half_width", 0.0)) / horizontal_scale, 0.0),
			"bed_depth": maxf(float(corridor.get("bed_depth", 0.01)) / vertical_scale, 0.01),
		})
	return result


func _build_segment_spatial_index(
	local_corridors: Array[Dictionary],
	grid_size: Vector2i,
	cell_size: float,
	origin_offset: Vector3,
	feather_width: float
) -> Dictionary:
	var segments: Array[Dictionary] = []
	var buckets: Dictionary = {}
	if grid_size.x <= 0 or grid_size.y <= 0:
		return {"segments": segments, "buckets": buckets}
	var safe_cell_size := maxf(cell_size, EPSILON)
	for corridor_index in range(local_corridors.size()):
		var corridor: Dictionary = local_corridors[corridor_index]
		var path: PackedVector3Array = corridor["path"]
		var reach := float(corridor["half_width"]) + feather_width
		for path_index in range(path.size() - 1):
			var a := path[path_index]
			var b := path[path_index + 1]
			var a_plan := Vector2(a.x, a.z)
			var b_plan := Vector2(b.x, b.z)
			if a_plan.distance_squared_to(b_plan) <= EPSILON:
				continue
			var segment_index := segments.size()
			segments.append({
				"corridor_index": corridor_index,
				"a": a_plan,
				"b": b_plan,
				"a_height": a.y,
				"b_height": b.y,
			})
			var min_plan := Vector2(
				minf(a_plan.x, b_plan.x) - reach,
				minf(a_plan.y, b_plan.y) - reach
			)
			var max_plan := Vector2(
				maxf(a_plan.x, b_plan.x) + reach,
				maxf(a_plan.y, b_plan.y) + reach
			)
			var min_x := floori(
				(min_plan.x - origin_offset.x) / safe_cell_size - 0.5
			)
			var max_x := ceili(
				(max_plan.x - origin_offset.x) / safe_cell_size - 0.5
			)
			var min_y := floori(
				(min_plan.y - origin_offset.z) / safe_cell_size - 0.5
			)
			var max_y := ceili(
				(max_plan.y - origin_offset.z) / safe_cell_size - 0.5
			)
			if max_x < 0 or max_y < 0 or min_x >= grid_size.x or min_y >= grid_size.y:
				continue
			min_x = clampi(min_x, 0, grid_size.x - 1)
			max_x = clampi(max_x, 0, grid_size.x - 1)
			min_y = clampi(min_y, 0, grid_size.y - 1)
			max_y = clampi(max_y, 0, grid_size.y - 1)
			for y in range(min_y, max_y + 1):
				for x in range(min_x, max_x + 1):
					var bucket_key := y * grid_size.x + x
					var bucket: PackedInt32Array = buckets.get(
						bucket_key, PackedInt32Array()
					)
					bucket.append(segment_index)
					buckets[bucket_key] = bucket
	return {"segments": segments, "buckets": buckets}


func _strongest_influence(
	point: Vector2,
	corridors: Array[Dictionary],
	segments: Array[Dictionary],
	candidate_segments: PackedInt32Array,
	feather_width: float
) -> Dictionary:
	var closest_by_corridor: Dictionary = {}
	for segment_index: int in candidate_segments:
		var segment: Dictionary = segments[segment_index]
		var corridor_index := int(segment["corridor_index"])
		var closest := _closest_segment_profile(point, segment)
		var previous: Vector2 = closest_by_corridor.get(
			corridor_index, Vector2(INF, 0.0)
		)
		if closest.x >= previous.x:
			continue
		closest_by_corridor[corridor_index] = closest

	var best: Dictionary = {}
	var best_weight := 0.0
	for corridor_index: int in closest_by_corridor:
		var corridor: Dictionary = corridors[corridor_index]
		var closest: Vector2 = closest_by_corridor[corridor_index]
		var distance := closest.x
		var half_width := float(corridor["half_width"])
		var inside_core := distance <= half_width
		var weight := 1.0
		if !inside_core:
			if feather_width <= EPSILON or distance >= half_width + feather_width:
				continue
			weight = 1.0 - (distance - half_width) / feather_width
		if weight < best_weight:
			continue
		if is_equal_approx(weight, best_weight) and !best.is_empty():
			var candidate_height := closest.y - float(corridor["bed_depth"])
			var best_height := float(best["profile_height"]) - float(best["bed_depth"])
			if candidate_height >= best_height:
				continue
		best_weight = weight
		best = {
			"weight": weight,
			"inside_core": inside_core,
			"profile_height": closest.y,
			"bed_depth": float(corridor["bed_depth"]),
		}
	return best


func _closest_segment_profile(point: Vector2, segment: Dictionary) -> Vector2:
	var a: Vector2 = segment["a"]
	var b: Vector2 = segment["b"]
	var direction := b - a
	var length_squared := direction.length_squared()
	if length_squared <= EPSILON:
		return Vector2(INF, 0.0)
	var t := clampf((point - a).dot(direction) / length_squared, 0.0, 1.0)
	var closest := a + direction * t
	return Vector2(
		point.distance_to(closest),
		lerpf(float(segment["a_height"]), float(segment["b_height"]), t)
	)
