@tool
class_name ResidentDialogueDefinition
extends Resource

@export var ambient_lines: PackedStringArray = PackedStringArray()
@export var dialogue_beats: Array[ResidentDialogueBeatDefinition] = []
@export var conditional_beats: Array[ResidentConditionalBeatDefinition] = []


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


func build_dialogue_beats() -> Array:
	return _serialize_beats(dialogue_beats)


func build_conditional_beats() -> Array:
	return _serialize_beats(conditional_beats)


func to_dictionary() -> Dictionary:
	return {
		"ambient_lines": build_ambient_lines(),
		"dialogue_beats": build_dialogue_beats(),
		"conditional_beats": build_conditional_beats(),
	}


func _serialize_beats(source: Array) -> Array:
	var beats: Array = []
	for beat_value in source:
		if beat_value == null:
			continue
		if beat_value is Dictionary:
			beats.append((beat_value as Dictionary).duplicate(true))
			continue
		if beat_value is Resource and beat_value.has_method("to_dictionary"):
			var serialized = beat_value.to_dictionary()
			if serialized is Dictionary and !serialized.is_empty():
				beats.append(serialized)
	return beats
