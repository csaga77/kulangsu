@tool
class_name LandmarkProgressProfile
extends Resource

const DEFAULT_PROFILE_ID := &"default"

@export var profile_id: StringName = DEFAULT_PROFILE_ID
# Landmark progress is intentionally heterogeneous: each landmark owns a small,
# validated state dictionary beyond the shared `state` field.
@export var progress: Dictionary = {"state": "locked"}


func build_progress() -> Dictionary:
	return progress.duplicate(true)


func validate(path: String = "progress_profile") -> PackedStringArray:
	var warnings := PackedStringArray()
	if String(profile_id).strip_edges().is_empty():
		warnings.append("%s.profile_id must not be empty." % path)
	var state_value: Variant = progress.get("state")
	if !(state_value is String) and !(state_value is StringName):
		warnings.append("%s.progress.state must be a String or StringName." % path)
	elif String(state_value).strip_edges().is_empty():
		warnings.append("%s.progress.state must not be empty." % path)
	return warnings
