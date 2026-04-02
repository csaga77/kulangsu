@tool
class_name ResidentMovementDefinition
extends Resource

@export var route_points: Array[ResidentRoutePointDefinition] = []
@export var arrival_radius: float = 24.0
@export var wait_min_sec: float = 0.5
@export var wait_max_sec: float = 1.2
@export var ping_pong: bool = true


func is_empty() -> bool:
	return route_points.is_empty()


func build_route_points() -> Array:
	var points: Array = []
	for point in route_points:
		if point == null:
			continue
		var point_data = point.to_dictionary()
		if point_data.is_empty():
			continue
		points.append(point_data)
	return points


func to_dictionary() -> Dictionary:
	if is_empty():
		return {}

	return {
		"route_points": build_route_points(),
		"arrival_radius": arrival_radius,
		"wait_min_sec": wait_min_sec,
		"wait_max_sec": wait_max_sec,
		"ping_pong": ping_pong,
	}
