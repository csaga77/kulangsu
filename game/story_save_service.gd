class_name StorySaveService
extends RefCounted

const STORY_AUTOSAVE_VERSION := 1
const STORY_AUTOSAVE_PATH := "user://story_autosave.save"
const STORY_SEASON_PHASES_SCRIPT := preload("res://game/story_season_phases.gd")
const STORY_TIME_SERVICE_SCRIPT := preload("res://game/story_time_service.gd")

var m_story_autosave_path := STORY_AUTOSAVE_PATH


func set_story_autosave_path(path: String) -> void:
	m_story_autosave_path = path.strip_edges()
	if m_story_autosave_path.is_empty():
		m_story_autosave_path = STORY_AUTOSAVE_PATH


func clear_story_autosave() -> void:
	if FileAccess.file_exists(m_story_autosave_path):
		DirAccess.remove_absolute(m_story_autosave_path)


func save_story_autosave(payload: Dictionary) -> bool:
	var file := FileAccess.open(m_story_autosave_path, FileAccess.WRITE)
	if file == null:
		return false

	file.store_var(payload.duplicate(true), false)
	file.flush()
	return true


func load_story_autosave(defaults: Dictionary) -> Dictionary:
	if !FileAccess.file_exists(m_story_autosave_path):
		return {}

	var file := FileAccess.open(m_story_autosave_path, FileAccess.READ)
	if file == null:
		return {}

	var payload: Variant = file.get_var(false)
	if !(payload is Dictionary):
		return {}
	return normalize_story_autosave_payload(payload, defaults)


func normalize_story_autosave_payload(payload: Dictionary, defaults: Dictionary) -> Dictionary:
	if int(payload.get("version", 0)) > STORY_AUTOSAVE_VERSION:
		return {}

	var normalized_mode := String(payload.get("mode", defaults.get("mode", "Story")))
	if normalized_mode == "Postgame" or normalized_mode != "Story":
		normalized_mode = "Story"

	var normalized_phase := String(
		payload.get(
			"season_phase",
			defaults.get("season_phase", STORY_SEASON_PHASES_SCRIPT.DEFAULT_PHASE)
		)
	)
	if normalized_phase == "postgame":
		normalized_phase = STORY_SEASON_PHASES_SCRIPT.DEFAULT_RESUME_PHASE

	var default_location := String(defaults.get("location", ""))
	var default_resume_location := String(defaults.get("story_resume_location", default_location))
	return {
		"version": STORY_AUTOSAVE_VERSION,
		"saved_at_unix": int(payload.get("saved_at_unix", 0)),
		"mode": normalized_mode,
		"chapter": String(payload.get("chapter", defaults.get("chapter", "Arrival"))),
		"season_phase": normalized_phase,
		"story_time": STORY_TIME_SERVICE_SCRIPT.normalize_time_state(
			payload.get("story_time", defaults.get("story_time", {}))
		),
		"location": String(payload.get("location", default_location)),
		"objective": String(payload.get("objective", defaults.get("objective", ""))),
		"journal_unlocked": bool(
			payload.get("journal_unlocked", defaults.get("journal_unlocked", true))
		),
		"melody_progress": _dictionary_or_default(
			payload.get("melody_progress", {}),
			defaults.get("melody_progress", {})
		),
		"landmark_progress": _merge_known_dictionary_entries(
			payload.get("landmark_progress", {}),
			defaults.get("landmark_progress", {})
		),
		"route_progress": _dictionary_or_default(
			payload.get("route_progress", {}),
			defaults.get("route_progress", {})
		),
		"story_flags": _dictionary_or_default(
			payload.get("story_flags", {}),
			defaults.get("story_flags", {})
		),
		"available_lead_ids": payload.get(
			"available_lead_ids",
			defaults.get("available_lead_ids", [])
		),
		"active_lead_id": String(
			payload.get("active_lead_id", defaults.get("active_lead_id", ""))
		),
		"endgame_state": _dictionary_or_default(
			payload.get("endgame_state", {}),
			defaults.get("endgame_state", {})
		),
		"manual_pinned_lead_id": String(
			payload.get(
				"manual_pinned_lead_id",
				defaults.get("manual_pinned_lead_id", "")
			)
		),
		"open_shortcuts": payload.get("open_shortcuts", defaults.get("open_shortcuts", [])),
		"resident_profiles": _merge_known_dictionary_entries(
			payload.get("resident_profiles", {}),
			defaults.get("resident_profiles", {})
		),
		"resident_routine_overrides": _normalize_dictionary_values(
			payload.get("resident_routine_overrides", {})
		),
		"player_profile": _dictionary_or_default(
			payload.get("player_profile", {}),
			defaults.get("player_profile", {})
		),
		"equipped_player_costume_id": String(
			payload.get(
				"equipped_player_costume_id",
				defaults.get("equipped_player_costume_id", "")
			)
		),
		"ending_summary": _merge_dictionary(
			payload.get("ending_summary", {}),
			defaults.get("ending_summary", {})
		),
		"story_resume_anchor_id": String(
			payload.get(
				"story_resume_anchor_id",
				defaults.get("story_resume_anchor_id", default_location)
			)
		),
		"story_resume_location": String(
			payload.get(
				"story_resume_location",
				payload.get("location", default_resume_location)
			)
		),
		"fragments_found": int(
			payload.get("fragments_found", defaults.get("fragments_found", 0))
		),
		"fragments_total": int(
			payload.get("fragments_total", defaults.get("fragments_total", 4))
		),
	}


func build_story_save_metadata(payload: Dictionary) -> Dictionary:
	var fragments_text := "%d / %d" % [
		int(payload.get("fragments_found", 0)),
		maxi(int(payload.get("fragments_total", 4)), 0),
	]
	var resume_location := String(
		payload.get("story_resume_location", payload.get("location", ""))
	)
	return {
		"exists": true,
		"mode": String(payload.get("mode", "Story")),
		"chapter": String(payload.get("chapter", "Arrival")),
		"location": String(payload.get("location", resume_location)),
		"fragments_text": fragments_text,
		"resume_anchor_id": String(payload.get("story_resume_anchor_id", "")),
		"resume_location": resume_location,
		"saved_at_unix": int(payload.get("saved_at_unix", 0)),
	}


func _dictionary_or_default(value: Variant, default_value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if default_value is Dictionary:
		return (default_value as Dictionary).duplicate(true)
	return {}


func _merge_dictionary(value: Variant, default_value: Variant) -> Dictionary:
	var normalized := _dictionary_or_default(default_value, {})
	if value is Dictionary:
		normalized.merge((value as Dictionary), true)
	if String(normalized.get("collectibles", "")) == "prototype":
		normalized["collectibles"] = "Not tracked in this build"
	return normalized


func _merge_known_dictionary_entries(value: Variant, default_value: Variant) -> Dictionary:
	var normalized := _dictionary_or_default(default_value, {})
	if !(value is Dictionary):
		return normalized

	for entry_id in (value as Dictionary).keys():
		if !normalized.has(entry_id):
			continue
		var incoming_entry: Variant = (value as Dictionary).get(entry_id)
		if !(incoming_entry is Dictionary):
			continue
		var merged_entry: Dictionary = normalized.get(entry_id, {}).duplicate(true)
		merged_entry.merge((incoming_entry as Dictionary), true)
		normalized[entry_id] = merged_entry
	return normalized


func _normalize_dictionary_values(value: Variant) -> Dictionary:
	var normalized: Dictionary = {}
	if !(value is Dictionary):
		return normalized
	for entry_id in (value as Dictionary).keys():
		var entry_value: Variant = (value as Dictionary).get(entry_id)
		var normalized_id := String(entry_id).strip_edges()
		if normalized_id.is_empty() or !(entry_value is Dictionary):
			continue
		normalized[normalized_id] = (entry_value as Dictionary).duplicate(true)
	return normalized
