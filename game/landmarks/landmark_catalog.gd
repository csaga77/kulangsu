@tool
class_name LandmarkCatalog
extends RefCounted

const DEFINITIONS := [
	preload("res://game/landmarks/definitions/piano_ferry.tres"),
	preload("res://game/landmarks/definitions/trinity_church.tres"),
	preload("res://game/landmarks/definitions/bi_shan_tunnel.tres"),
	preload("res://game/landmarks/definitions/long_shan_tunnel.tres"),
	preload("res://game/landmarks/definitions/bagua_tower.tres"),
	preload("res://game/landmarks/definitions/festival_stage.tres"),
]


static func all_definitions() -> Array[LandmarkDefinition]:
	var definitions: Array[LandmarkDefinition] = []
	for definition_value in DEFINITIONS:
		var definition := definition_value as LandmarkDefinition
		if definition != null:
			definitions.append(definition)
	return definitions


static func world_definitions() -> Array[LandmarkDefinition]:
	var definitions: Array[LandmarkDefinition] = []
	for definition in all_definitions():
		if definition.include_in_world_navigation:
			definitions.append(definition)
	return definitions


static func get_definition(landmark_id: StringName) -> LandmarkDefinition:
	for definition in all_definitions():
		if definition.id == landmark_id:
			return definition
	return null


static func get_definition_by_display_name(display_name: String) -> LandmarkDefinition:
	var normalized_name := display_name.strip_edges()
	for definition in all_definitions():
		if definition.display_name == normalized_name:
			return definition
	return null


static func landmark_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for definition in all_definitions():
		ids.append(String(definition.id))
	return ids


static func world_display_names() -> PackedStringArray:
	var names := PackedStringArray()
	for definition in world_definitions():
		names.append(definition.display_name)
	return names


static func build_progress(profile_id: StringName = LandmarkProgressProfile.DEFAULT_PROFILE_ID) -> Dictionary:
	var progress: Dictionary = {}
	for definition in all_definitions():
		progress[String(definition.id)] = definition.build_progress(profile_id)
	return progress


static func default_resume_definition() -> LandmarkDefinition:
	for definition in all_definitions():
		if definition.is_default_resume_anchor:
			return definition
	return null


static func default_resume_display_name() -> String:
	var definition := default_resume_definition()
	return definition.display_name if definition != null else ""


static func audio_cue_ids() -> PackedStringArray:
	var cue_ids := PackedStringArray()
	for definition in all_definitions():
		var cue_id := String(definition.audio_cue_id)
		if !cue_id.is_empty():
			cue_ids.append(cue_id)
	return cue_ids


static func get_audio_cue(cue_id: StringName) -> AudioStream:
	for definition in all_definitions():
		if definition.audio_cue_id == cue_id:
			return definition.audio_cue
	return null


static func validate() -> PackedStringArray:
	var warnings := PackedStringArray()
	var definitions := all_definitions()
	var landmark_ids_seen: Dictionary = {}
	var display_names_seen: Dictionary = {}
	var cue_ids_seen: Dictionary = {}
	var default_resume_count := 0
	for index in definitions.size():
		var definition := definitions[index]
		var path := "landmarks[%d]" % index
		warnings.append_array(definition.validate(path))

		var landmark_id := String(definition.id)
		if landmark_ids_seen.has(landmark_id):
			warnings.append("%s duplicates landmark id '%s'." % [path, landmark_id])
		landmark_ids_seen[landmark_id] = true

		if display_names_seen.has(definition.display_name):
			warnings.append("%s duplicates display name '%s'." % [path, definition.display_name])
		display_names_seen[definition.display_name] = true

		var cue_id := String(definition.audio_cue_id)
		if cue_ids_seen.has(cue_id):
			warnings.append("%s duplicates audio cue id '%s'." % [path, cue_id])
		cue_ids_seen[cue_id] = true

		if definition.is_default_resume_anchor:
			default_resume_count += 1
	if default_resume_count != 1:
		warnings.append("Landmark catalog requires exactly one default resume anchor.")
	return warnings
