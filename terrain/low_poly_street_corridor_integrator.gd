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
	for y in range(grid.size()):
		for x in range(grid[y].size()):
			var cell := grid[y][x] as LowPolyTerrainCell
			if cell == null:
				continue
			var point := Vector2(
				origin_offset.x + (float(x) + 0.5) * cell_size,
				origin_offset.z + (float(y) + 0.5) * cell_size
			)
			var influence := _strongest_influence(point, local_corridors, feather)
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


func _strongest_influence(
	point: Vector2,
	corridors: Array[Dictionary],
	feather_width: float
) -> Dictionary:
	var best: Dictionary = {}
	var best_weight := 0.0
	for corridor: Dictionary in corridors:
		var closest := _closest_profile_point(point, corridor["path"])
		if closest.is_empty():
			continue
		var distance := float(closest["distance"])
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
			var candidate_height := float(closest["height"]) - float(corridor["bed_depth"])
			var best_height := float(best["profile_height"]) - float(best["bed_depth"])
			if candidate_height >= best_height:
				continue
		best_weight = weight
		best = {
			"weight": weight,
			"inside_core": inside_core,
			"profile_height": float(closest["height"]),
			"bed_depth": float(corridor["bed_depth"]),
		}
	return best


func _closest_profile_point(point: Vector2, path: PackedVector3Array) -> Dictionary:
	var best_distance := INF
	var best_height := 0.0
	for index in range(path.size() - 1):
		var a := path[index]
		var b := path[index + 1]
		var a_plan := Vector2(a.x, a.z)
		var b_plan := Vector2(b.x, b.z)
		var segment := b_plan - a_plan
		var length_squared := segment.length_squared()
		if length_squared <= EPSILON:
			continue
		var t := clampf((point - a_plan).dot(segment) / length_squared, 0.0, 1.0)
		var closest := a_plan + segment * t
		var distance := point.distance_to(closest)
		if distance >= best_distance:
			continue
		best_distance = distance
		best_height = lerpf(a.y, b.y, t)
	if is_inf(best_distance):
		return {}
	return {"distance": best_distance, "height": best_height}
