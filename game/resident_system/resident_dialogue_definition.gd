@tool
class_name ResidentDialogueDefinition
extends Resource

@export var ambient_lines: PackedStringArray = PackedStringArray()
@export var dialogue_beats: Array = []
@export var conditional_beats: Array = []


func set_ambient_lines_from_array(lines: Array) -> void:
	var normalized := PackedStringArray()
	for line_value in lines:
		normalized.append(String(line_value))
	ambient_lines = normalized


func build_ambient_lines() -> Array:
	var lines: Array = []
	for line in ambient_lines:
		lines.append(String(line))
	return lines


func to_dictionary() -> Dictionary:
	return {
		"ambient_lines": build_ambient_lines(),
		"dialogue_beats": dialogue_beats.duplicate(true),
		"conditional_beats": conditional_beats.duplicate(true),
	}
