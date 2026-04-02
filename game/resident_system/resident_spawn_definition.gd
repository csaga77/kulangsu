@tool
class_name ResidentSpawnDefinition
extends Resource

@export var anchor_id: String = ""
@export var offset: Vector2 = Vector2.ZERO
@export var direction: float = 0.0
@export var mood: int = 1
@export var interaction_radius: float = 72.0


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
