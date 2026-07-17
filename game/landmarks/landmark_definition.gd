@tool
class_name LandmarkDefinition
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var include_in_world_navigation: bool = true
@export var world_node_path: NodePath
@export var isometric_position: Vector2 = Vector2.ZERO
@export var is_default_resume_anchor: bool = false
@export var audio_cue_id: StringName = &""
@export var audio_cue: AudioStream
@export var progress_profiles: Array[LandmarkProgressProfile] = []


func build_progress(profile_id: StringName = LandmarkProgressProfile.DEFAULT_PROFILE_ID) -> Dictionary:
	var fallback: LandmarkProgressProfile = null
	for profile in progress_profiles:
		if profile == null:
			continue
		if profile.profile_id == profile_id:
			return profile.build_progress()
		if profile.profile_id == LandmarkProgressProfile.DEFAULT_PROFILE_ID:
			fallback = profile
	if fallback != null:
		return fallback.build_progress()
	return {"state": "locked"}


func validate(path: String = "landmark") -> PackedStringArray:
	var warnings := PackedStringArray()
	if String(id).strip_edges().is_empty():
		warnings.append("%s.id must not be empty." % path)
	if display_name.strip_edges().is_empty():
		warnings.append("%s.display_name must not be empty." % path)
	if include_in_world_navigation and world_node_path.is_empty():
		warnings.append("%s.world_node_path is required for a world landmark." % path)
	if String(audio_cue_id).strip_edges().is_empty():
		warnings.append("%s.audio_cue_id must not be empty." % path)
	if audio_cue == null:
		warnings.append("%s.audio_cue must be assigned." % path)

	var profile_ids: Dictionary = {}
	for index in progress_profiles.size():
		var profile := progress_profiles[index]
		var profile_path := "%s.progress_profiles[%d]" % [path, index]
		if profile == null:
			warnings.append("%s must not be null." % profile_path)
			continue
		warnings.append_array(profile.validate(profile_path))
		var normalized_profile_id := String(profile.profile_id).strip_edges()
		if profile_ids.has(normalized_profile_id):
			warnings.append("%s duplicates profile_id '%s'." % [profile_path, normalized_profile_id])
		profile_ids[normalized_profile_id] = true
	if !profile_ids.has(String(LandmarkProgressProfile.DEFAULT_PROFILE_ID)):
		warnings.append("%s requires a default progress profile." % path)
	return warnings
