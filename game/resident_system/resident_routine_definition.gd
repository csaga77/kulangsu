@tool
class_name ResidentRoutineDefinition
extends Resource

@export var spawn: ResidentSpawnDefinition
@export var movement: ResidentMovementDefinition
@export var behavior_preset: StringName = &""
@export var behavior_metadata: Dictionary = {}


func get_spawn_config() -> Dictionary:
	if spawn == null:
		return {}
	return spawn.to_dictionary()


func get_movement_config() -> Dictionary:
	if movement == null:
		return {}
	return movement.to_dictionary()


func get_behavior_config() -> Dictionary:
	var preset := String(behavior_preset)
	if preset.is_empty() and behavior_metadata.is_empty():
		return {}

	return {
		"preset": preset,
		"metadata": behavior_metadata.duplicate(true),
	}


func to_dictionary() -> Dictionary:
	return {
		"spawn": get_spawn_config(),
		"movement": get_movement_config(),
		"behavior": get_behavior_config(),
	}
