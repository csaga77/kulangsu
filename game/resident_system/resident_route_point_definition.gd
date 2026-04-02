@tool
class_name ResidentRoutePointDefinition
extends Resource

@export var anchor_id := ""
@export var offset := Vector2.ZERO
@export var wait_min_sec := -1.0
@export var wait_max_sec := -1.0
@export var allow_collision_bypass := false


func to_dictionary() -> Dictionary:
	if anchor_id.is_empty():
		return {}

	var point := {
		"anchor_id": anchor_id,
		"offset": offset,
	}
	if wait_min_sec >= 0.0:
		point["wait_min_sec"] = wait_min_sec
	if wait_max_sec >= 0.0:
		point["wait_max_sec"] = wait_max_sec
	if allow_collision_bypass:
		point["allow_collision_bypass"] = true
	return point
