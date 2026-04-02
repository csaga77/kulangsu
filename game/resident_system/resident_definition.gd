@tool
class_name ResidentDefinition
extends Resource

@export var id := ""
@export var display_name := ""
@export_multiline var landmark := ""
@export_multiline var role := ""
@export_multiline var routine_note := ""
@export_multiline var melody_hint := ""
@export var appearance: Resource
@export var dialogue: Resource
@export var routine: Resource


func build_appearance_config() -> Dictionary:
	if appearance == null:
		return {}
	return appearance.to_configuration()


func get_spawn_config() -> Dictionary:
	if routine == null:
		return {}
	return routine.get_spawn_config()


func get_movement_config() -> Dictionary:
	if routine == null:
		return {}
	return routine.get_movement_config()


func get_behavior_config() -> Dictionary:
	if routine == null:
		return {}
	return routine.get_behavior_config()


func to_runtime_profile() -> Dictionary:
	var dialogue_data = {}
	if dialogue != null:
		dialogue_data = dialogue.to_dictionary()
	return {
		"display_name": display_name,
		"landmark": landmark,
		"role": role,
		"routine_note": routine_note,
		"melody_hint": melody_hint,
		"ambient_lines": dialogue_data.get("ambient_lines", []),
		"dialogue_beats": dialogue_data.get("dialogue_beats", []).duplicate(true),
		"conditional_beats": dialogue_data.get("conditional_beats", []).duplicate(true),
		"appearance": build_appearance_config(),
		"spawn": get_spawn_config(),
		"movement": get_movement_config(),
		"behavior": get_behavior_config(),
		"known": false,
		"trust": 0,
		"conversation_index": 0,
		"quest_state": "available",
		"current_step": "Not introduced yet.",
	}
