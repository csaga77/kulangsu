@tool
class_name ResidentDefinition
extends Resource

@export var id: String = ""
@export var include_in_catalog: bool = true
@export var sort_order: int = 0
@export var display_name: String = ""
@export_multiline var landmark: String = ""
@export_multiline var role: String = ""
@export_multiline var routine_note: String = ""
@export_multiline var melody_hint: String = ""
@export var appearance: ResidentAppearanceDefinition
@export var dialogue: ResidentDialogueDefinition
@export var routine: ResidentRoutineDefinition


func should_include_in_catalog() -> bool:
	return include_in_catalog


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
	var dialogue_data: Dictionary = {}
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
