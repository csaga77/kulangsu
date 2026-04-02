@tool
class_name ResidentDialogueBeatDefinition
extends Resource

@export_multiline var line: String = ""
@export_multiline var objective: String = ""
@export_multiline var journal_step: String = ""
@export_multiline var hint: String = ""
@export_multiline var chapter: String = ""
@export_multiline var quest_state: String = ""
@export var trust_delta: int = 0
@export_multiline var save_status: String = ""
@export var landmark_states: Dictionary = {}
@export var unlock_landmark: String = ""
@export var landmark_reward: String = ""
@export var gate: String = ""
@export_multiline var gate_fallback: String = ""
@export var extra_fields: Dictionary = {}


func to_dictionary() -> Dictionary:
	var beat := extra_fields.duplicate(true)

	if !line.is_empty():
		beat["line"] = line
	if !objective.is_empty():
		beat["objective"] = objective
	if !journal_step.is_empty():
		beat["journal_step"] = journal_step
	if !hint.is_empty():
		beat["hint"] = hint
	if !chapter.is_empty():
		beat["chapter"] = chapter
	if !quest_state.is_empty():
		beat["quest_state"] = quest_state
	if trust_delta != 0:
		beat["trust_delta"] = trust_delta
	if !save_status.is_empty():
		beat["save_status"] = save_status
	if !landmark_states.is_empty():
		beat["landmark_states"] = landmark_states.duplicate(true)
	if !unlock_landmark.is_empty():
		beat["unlock_landmark"] = unlock_landmark
	if !landmark_reward.is_empty():
		beat["landmark_reward"] = landmark_reward
	if !gate.is_empty():
		beat["gate"] = gate
	if !gate_fallback.is_empty():
		beat["gate_fallback"] = gate_fallback

	return beat
