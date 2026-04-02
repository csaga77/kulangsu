@tool
class_name ResidentBeatConditionsDefinition
extends Resource

@export var required_landmark_states: Dictionary = {}
@export var required_melody_states: Dictionary = {}
@export var fragments_found_min: int = -1
@export var trust_min: int = -1
@export var required_chapter: String = ""
@export var required_mode: String = ""
@export var required_known_resident_ids: PackedStringArray = PackedStringArray()
@export var extra_conditions: Dictionary = {}


func is_empty() -> bool:
	return required_landmark_states.is_empty() \
		and required_melody_states.is_empty() \
		and fragments_found_min < 0 \
		and trust_min < 0 \
		and required_chapter.is_empty() \
		and required_mode.is_empty() \
		and required_known_resident_ids.is_empty() \
		and extra_conditions.is_empty()


func to_dictionary() -> Dictionary:
	var conditions := extra_conditions.duplicate(true)

	if !required_landmark_states.is_empty():
		conditions["landmark_state"] = required_landmark_states.duplicate(true)
	if !required_melody_states.is_empty():
		conditions["melody_state"] = required_melody_states.duplicate(true)
	if fragments_found_min >= 0:
		conditions["fragments_found_min"] = fragments_found_min
	if trust_min >= 0:
		conditions["trust_min"] = trust_min
	if !required_chapter.is_empty():
		conditions["chapter"] = required_chapter
	if !required_mode.is_empty():
		conditions["mode"] = required_mode
	if !required_known_resident_ids.is_empty():
		var known_ids: Array[String] = []
		for resident_id in required_known_resident_ids:
			known_ids.append(String(resident_id))
		conditions["resident_known"] = known_ids

	return conditions
