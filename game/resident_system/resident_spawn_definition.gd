@tool
class_name ResidentSpawnDefinition
extends Resource

@export var anchor_id := ""
@export var offset := Vector2.ZERO
@export var direction := 0.0
@export var mood := 1
@export var interaction_radius := 72.0


func to_dictionary() -> Dictionary:
	if anchor_id.is_empty():
		return {}

	return {
		"anchor_id": anchor_id,
		"offset": offset,
		"direction": direction,
		"mood": mood,
		"interaction_radius": interaction_radius,
	}
