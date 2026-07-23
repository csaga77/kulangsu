class_name StorySaveCodec
extends RefCounted

const SAVE_VERSION := 2
const STORY_SEASON_PHASES := preload("res://game/story_season_phases.gd")
const STORY_TIME_SERVICE := preload("res://game/story_time_service.gd")
const STORY_ROUTE_GRAPH := preload("res://game/story_route_graph.gd")
const STORY_MOMENT_LEDGER := preload("res://game/story_moment_ledger.gd")
const PLAYER_APPEARANCE_CATALOG := preload("res://game/player_appearance_catalog.gd")
const PLAYER_COSTUME_CATALOG := preload("res://game/player_costume_catalog.gd")


func encode(snapshot: AppStateSnapshot, saved_at_unix: int = 0) -> Dictionary:
	var timestamp := saved_at_unix
	if timestamp <= 0:
		timestamp = int(Time.get_unix_time_from_system())
	return {
		"version": SAVE_VERSION,
		"saved_at_unix": timestamp,
		"mode_id": String(AppStateSnapshot.MODE_STORY),
		"season_phase": snapshot.season_phase,
		"story_day": snapshot.story_day,
		"world_hour": snapshot.world_hour,
		"location": snapshot.location,
		"objective": snapshot.objective,
		"journal_unlocked": snapshot.journal_unlocked,
		"open_shortcuts": PackedStringArray(snapshot.open_shortcuts),
		"melody_progress": snapshot.melody_progress.duplicate(true),
		"landmark_progress": snapshot.landmark_progress.duplicate(true),
		"story_flags": snapshot.story_flags.duplicate(true),
		"endgame_state": snapshot.endgame_state.duplicate(true),
		"manual_pinned_lead_id": snapshot.manual_pinned_lead_id,
		"resident_profiles": snapshot.resident_profiles.duplicate(true),
		"resident_routine_overrides": snapshot.resident_routine_overrides.duplicate(true),
		"player_profile": snapshot.player_profile.duplicate(true),
		"equipped_player_costume_id": snapshot.equipped_player_costume_id,
		"story_resume_anchor_id": snapshot.story_resume_anchor_id,
		"story_resume_location": snapshot.story_resume_location,
	}


func decode(payload: Dictionary, defaults: AppStateSnapshot) -> Dictionary:
	if payload.is_empty():
		return {}
	var source_version := int(payload.get("version", 1))
	if source_version <= 0 or source_version > SAVE_VERSION:
		return {}
	var snapshot := defaults.duplicate_state()
	if source_version == 1:
		_decode_v1(payload, snapshot)
	else:
		_decode_v2(payload, snapshot)
	_normalize_decoded_snapshot(snapshot)
	return {
		"snapshot": snapshot,
		"source_version": source_version,
		"saved_at_unix": int(payload.get("saved_at_unix", 0)),
	}


func build_metadata(payload: Dictionary, snapshot: AppStateSnapshot) -> Dictionary:
	var fragment_counts := _fragment_counts(snapshot.melody_progress)
	var resume_location := snapshot.story_resume_location
	if resume_location.is_empty():
		resume_location = snapshot.location
	return {
		"exists": true,
		"mode": AppStateSnapshot.mode_display_name(snapshot.mode_id),
		"chapter": snapshot.season_phase,
		"location": snapshot.location,
		"fragments_text": "%d / %d" % [fragment_counts.x, fragment_counts.y],
		"resume_anchor_id": snapshot.story_resume_anchor_id,
		"resume_location": resume_location,
		"saved_at_unix": int(payload.get("saved_at_unix", 0)),
	}


func _decode_v2(payload: Dictionary, snapshot: AppStateSnapshot) -> void:
	snapshot.mode_id = AppStateSnapshot.MODE_STORY
	snapshot.season_phase = String(payload.get("season_phase", snapshot.season_phase))
	snapshot.story_day = int(payload.get("story_day", snapshot.story_day))
	snapshot.world_hour = float(payload.get("world_hour", snapshot.world_hour))
	_apply_common_payload(payload, snapshot)


func _decode_v1(payload: Dictionary, snapshot: AppStateSnapshot) -> void:
	# V1 used display labels and serialized several projections. Only canonical
	# fields cross the migration boundary; route/lead/chapter/time/summary values
	# are deliberately recomputed by the store.
	snapshot.mode_id = AppStateSnapshot.MODE_STORY
	snapshot.season_phase = String(payload.get("season_phase", snapshot.season_phase))
	var story_time_value: Variant = payload.get("story_time", {})
	if story_time_value is Dictionary:
		snapshot.story_day = int(story_time_value.get("story_day", snapshot.story_day))
		snapshot.world_hour = float(story_time_value.get("world_hour", snapshot.world_hour))
	_apply_common_payload(payload, snapshot)


func _apply_common_payload(payload: Dictionary, snapshot: AppStateSnapshot) -> void:
	snapshot.location = String(payload.get("location", snapshot.location))
	snapshot.objective = String(payload.get("objective", snapshot.objective))
	snapshot.journal_unlocked = bool(payload.get("journal_unlocked", snapshot.journal_unlocked))
	snapshot.open_shortcuts = _normalize_string_array(
		payload.get("open_shortcuts", snapshot.open_shortcuts)
	)
	snapshot.melody_progress = _dictionary_or_default(
		payload.get("melody_progress", {}),
		snapshot.melody_progress
	)
	snapshot.landmark_progress = _merge_known_dictionary_entries(
		payload.get("landmark_progress", {}),
		snapshot.landmark_progress
	)
	snapshot.story_flags = _dictionary_or_default(
		payload.get("story_flags", {}),
		snapshot.story_flags
	)
	snapshot.endgame_state = _dictionary_or_default(
		payload.get("endgame_state", {}),
		snapshot.endgame_state
	)
	snapshot.manual_pinned_lead_id = String(
		payload.get("manual_pinned_lead_id", snapshot.manual_pinned_lead_id)
	)
	snapshot.resident_profiles = _merge_known_dictionary_entries(
		payload.get("resident_profiles", {}),
		snapshot.resident_profiles
	)
	snapshot.resident_routine_overrides = _normalize_dictionary_values(
		payload.get("resident_routine_overrides", {})
	)
	snapshot.player_profile = _dictionary_or_default(
		payload.get("player_profile", {}),
		snapshot.player_profile
	)
	snapshot.equipped_player_costume_id = String(
		payload.get("equipped_player_costume_id", snapshot.equipped_player_costume_id)
	)
	snapshot.story_resume_anchor_id = String(
		payload.get("story_resume_anchor_id", snapshot.story_resume_anchor_id)
	)
	snapshot.story_resume_location = String(
		payload.get(
			"story_resume_location",
			payload.get("location", snapshot.story_resume_location)
		)
	)


func _normalize_decoded_snapshot(snapshot: AppStateSnapshot) -> void:
	snapshot.mode_id = AppStateSnapshot.MODE_STORY
	if snapshot.season_phase == "postgame":
		snapshot.season_phase = STORY_SEASON_PHASES.DEFAULT_RESUME_PHASE
	if !STORY_SEASON_PHASES.runtime_phase_ids().has(snapshot.season_phase):
		snapshot.season_phase = STORY_SEASON_PHASES.DEFAULT_PHASE
	var normalized_time := STORY_TIME_SERVICE.normalize_time_state({
		"story_day": snapshot.story_day,
		"world_hour": snapshot.world_hour,
	})
	snapshot.story_day = int(normalized_time.get("story_day", 1))
	snapshot.world_hour = float(normalized_time.get("world_hour", 8.0))
	snapshot.player_profile = PLAYER_APPEARANCE_CATALOG.normalize_profile(
		snapshot.player_profile
	)
	var costume_catalog := PLAYER_COSTUME_CATALOG.build_catalog()
	if !costume_catalog.has(snapshot.equipped_player_costume_id):
		snapshot.equipped_player_costume_id = PLAYER_COSTUME_CATALOG.default_costume_id()
	var route_graph := STORY_ROUTE_GRAPH.new(null)
	snapshot.story_flags = route_graph.normalize_story_flags(snapshot.story_flags)
	snapshot.story_flags = STORY_MOMENT_LEDGER.normalize_story_flags(snapshot.story_flags)
	var event_definitions := STORY_ROUTE_GRAPH.build_event_definitions()
	if (
		!snapshot.manual_pinned_lead_id.is_empty()
		and !event_definitions.has(snapshot.manual_pinned_lead_id)
	):
		snapshot.manual_pinned_lead_id = ""
	snapshot.endgame_state = route_graph.normalize_endgame_state(
		snapshot.endgame_state
	)
	var resume_phase := String(snapshot.endgame_state.get("resume_phase_id", ""))
	if !resume_phase.is_empty() and !STORY_SEASON_PHASES.runtime_phase_ids().has(resume_phase):
		snapshot.endgame_state["resume_phase_id"] = STORY_SEASON_PHASES.DEFAULT_RESUME_PHASE


func _dictionary_or_default(value: Variant, default_value: Dictionary) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return default_value.duplicate(true)


func _merge_known_dictionary_entries(value: Variant, default_value: Dictionary) -> Dictionary:
	var normalized := default_value.duplicate(true)
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


func _normalize_string_array(value: Variant) -> PackedStringArray:
	var output := PackedStringArray()
	if value is PackedStringArray or value is Array:
		for entry in value:
			var normalized := String(entry).strip_edges()
			if !normalized.is_empty() and output.find(normalized) < 0:
				output.append(normalized)
	return output


func _fragment_counts(progress: Dictionary) -> Vector2i:
	var found := 0
	var total := 0
	for melody_value in progress.values():
		if !(melody_value is Dictionary):
			continue
		found += int(melody_value.get("fragments_found", 0))
		total += int(melody_value.get("fragments_total", 0))
	return Vector2i(found, total)
