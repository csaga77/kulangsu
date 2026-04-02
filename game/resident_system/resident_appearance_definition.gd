@tool
class_name ResidentAppearanceDefinition
extends Resource

@export var body_type := ""
@export var body_type_index := 0
@export var selections: Dictionary = {}


func is_empty() -> bool:
	return body_type.is_empty() and selections.is_empty()


func to_configuration() -> Dictionary:
	if is_empty():
		return {}

	return {
		"body_type": body_type,
		"body_type_index": body_type_index,
		"selections": selections.duplicate(true),
	}
