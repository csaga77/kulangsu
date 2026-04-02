@tool
class_name ResidentConditionalBeatDefinition
extends ResidentDialogueBeatDefinition

@export var conditions: ResidentBeatConditionsDefinition
@export var priority: int = 0
@export var once: bool = false


func to_dictionary() -> Dictionary:
	var beat := super.to_dictionary()
	var condition_data := {}
	if conditions != null and conditions.has_method("to_dictionary"):
		condition_data = conditions.to_dictionary()
	if !condition_data.is_empty():
		beat["conditions"] = condition_data
	if priority != 0:
		beat["priority"] = priority
	if once:
		beat["once"] = true
	return beat
