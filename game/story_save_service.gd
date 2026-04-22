class_name StorySaveService
extends RefCounted

const STORY_AUTOSAVE_VERSION := 1
const STORY_AUTOSAVE_PATH := "user://story_autosave.save"
const STORY_SEASON_PHASES_SCRIPT := preload("res://game/story_season_phases.gd")

var m_owner: Node = null
var m_story_autosave_path := STORY_AUTOSAVE_PATH


func _init(owner: Node) -> void:
	m_owner = owner


func set_story_autosave_path(path: String) -> void:
	m_story_autosave_path = path.strip_edges()
	if m_story_autosave_path.is_empty():
		m_story_autosave_path = STORY_AUTOSAVE_PATH


func clear_story_autosave() -> void:
	if FileAccess.file_exists(m_story_autosave_path):
		DirAccess.remove_absolute(m_story_autosave_path)
	refresh_story_autosave_metadata()


func refresh_story_autosave_metadata() -> void:
	var next_metadata: Dictionary = m_owner._default_story_save_metadata()
	var payload: Dictionary = _read_story_autosave_payload()
	if !payload.is_empty():
		next_metadata = _build_story_save_metadata_from_payload(payload)

	m_owner.story_save_metadata = next_metadata
	m_owner._emit_save_metadata_changed(m_owner.get_story_save_metadata())


func save_story_autosave(status_text: String = "") -> bool:
	if !m_owner._is_story_persistable_mode():
		return false

	var file := FileAccess.open(m_story_autosave_path, FileAccess.WRITE)
	if file == null:
		if !status_text.is_empty():
			m_owner.set_save_status(status_text)
		return false

	file.store_var(_build_story_autosave_payload(), false)
	file.flush()
	refresh_story_autosave_metadata()

	if !status_text.is_empty():
		m_owner.set_save_status(status_text)

	return true


func load_story_autosave() -> bool:
	var payload := _read_story_autosave_payload()
	if payload.is_empty():
		return false

	return _apply_story_autosave_payload(payload)


func configure_new_game() -> void:
	var story_state: Dictionary = m_owner.m_story_route_graph.build_story_state("new_game") \
		if m_owner.m_story_route_graph != null else {}
	m_owner.set_mode("Story")
	m_owner._apply_story_route_state_bundle(story_state)
	m_owner.set_location("Piano Ferry")
	m_owner.set_objective("Find out why the island feels quiet today.")
	m_owner.set_journal_unlocked(false)
	m_owner.set_hint(m_owner.build_input_hint("R Inspect"))
	m_owner.set_save_status("Autosave: story start saved")
	m_owner.set_landmarks(m_owner._default_landmarks())
	m_owner.set_open_shortcuts(PackedStringArray())
	m_owner.clear_resident_routine_overrides()
	m_owner.set_resident_profiles(m_owner._default_resident_profiles())
	m_owner.set_melody_progress(m_owner._build_story_melody_progress("new_game"))
	m_owner.set_all_landmark_progress(m_owner._build_landmark_progress("new_game"))
	m_owner.refresh_story_routes()
	m_owner._sync_story_route_dependent_landmarks()
	m_owner.story_resume_anchor_id = "Piano Ferry"
	m_owner.story_resume_location = "Piano Ferry"
	m_owner.set_summary({
		"fragments": "0 / 4",
		"residents": "0",
		"collectibles": "Not tracked in this build",
		"playtime": "a brief evening on Kulangsu",
	})
	save_story_autosave()


func configure_continue() -> bool:
	if !load_story_autosave():
		m_owner.set_save_status("Continue is unavailable until a story autosave exists.")
		return false

	m_owner.set_hint(m_owner.build_input_hint("R Inspect"))
	var resume_label: String = m_owner.story_resume_location
	if resume_label.is_empty():
		resume_label = m_owner.location
	m_owner.set_save_status("Autosave: resumed at %s" % resume_label)
	return true


func configure_free_walk() -> void:
	var story_state: Dictionary = m_owner.m_story_route_graph.build_story_state("free_walk") \
		if m_owner.m_story_route_graph != null else {}
	m_owner.set_mode("Free Walk")
	m_owner._apply_story_route_state_bundle(story_state)
	m_owner.set_chapter("Free Walk")
	m_owner.set_location("Piano Ferry")
	m_owner.set_objective("Wander the island and learn how the first district wants to be introduced.")
	m_owner.set_journal_unlocked(true)
	m_owner.set_hint(m_owner.build_input_hint("R Inspect"))
	m_owner.set_save_status("Free Walk: sandbox ready")
	m_owner.set_landmarks(m_owner._default_landmarks())
	m_owner.set_open_shortcuts(PackedStringArray())
	m_owner.clear_resident_routine_overrides()
	m_owner.set_resident_profiles(m_owner._default_resident_profiles())
	m_owner.set_melody_progress(m_owner._build_story_melody_progress("free_walk"))
	m_owner.set_all_landmark_progress(m_owner._build_landmark_progress("free_walk"))
	for resident_id in m_owner.RESIDENT_CATALOG_SCRIPT.resident_order():
		m_owner._seed_resident_progress(
			resident_id,
			1,
			1,
			"introduced",
			"Sandbox resident notes are available in free walk."
		)
	m_owner._update_summary_counts()


func _build_story_autosave_payload() -> Dictionary:
	return {
		"version": STORY_AUTOSAVE_VERSION,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"mode": m_owner.mode,
		"chapter": m_owner.chapter,
		"season_phase": m_owner.season_phase,
		"location": m_owner.location,
		"objective": m_owner.objective,
		"journal_unlocked": m_owner.journal_unlocked,
		"melody_progress": m_owner.melody_progress.duplicate(true),
		"landmark_progress": m_owner.landmark_progress.duplicate(true),
		"route_progress": m_owner.route_progress.duplicate(true),
		"story_flags": m_owner.get_story_flags(),
		"available_lead_ids": m_owner.get_available_lead_ids(),
		"active_lead_id": m_owner.get_active_lead_id(),
		"endgame_state": m_owner.endgame_state.duplicate(true),
		"manual_pinned_lead_id": m_owner._manual_pinned_lead_id,
		"open_shortcuts": m_owner.get_open_shortcuts(),
		"resident_profiles": m_owner.resident_profiles.duplicate(true),
		"resident_routine_overrides": m_owner.get_all_resident_routine_overrides(),
		"player_profile": m_owner.get_player_profile(),
		"equipped_player_costume_id": m_owner.get_equipped_player_costume_id(),
		"ending_summary": m_owner.ending_summary.duplicate(true),
		"story_resume_anchor_id": m_owner.story_resume_anchor_id,
		"story_resume_location": m_owner.story_resume_location,
		"fragments_found": m_owner.fragments_found,
		"fragments_total": m_owner.fragments_total,
	}


func _read_story_autosave_payload() -> Dictionary:
	if !FileAccess.file_exists(m_story_autosave_path):
		return {}

	var file := FileAccess.open(m_story_autosave_path, FileAccess.READ)
	if file == null:
		return {}

	var payload: Variant = file.get_var(false)
	if payload is Dictionary:
		return _normalize_story_autosave_payload(payload)

	return {}


func _normalize_story_autosave_payload(payload: Dictionary) -> Dictionary:
	if int(payload.get("version", 0)) > STORY_AUTOSAVE_VERSION:
		return {}

	var normalized_mode := String(payload.get("mode", "Story"))
	if normalized_mode == "Postgame":
		normalized_mode = "Story"
	elif !m_owner._is_story_persistable_mode(normalized_mode):
		normalized_mode = "Story"

	var normalized_phase := String(
		payload.get("season_phase", STORY_SEASON_PHASES_SCRIPT.DEFAULT_PHASE)
	)
	if normalized_phase == "postgame":
		normalized_phase = STORY_SEASON_PHASES_SCRIPT.DEFAULT_RESUME_PHASE

	return {
		"version": STORY_AUTOSAVE_VERSION,
		"saved_at_unix": int(payload.get("saved_at_unix", 0)),
		"mode": normalized_mode,
		"chapter": String(payload.get("chapter", "Arrival")),
		"season_phase": normalized_phase,
		"location": String(payload.get("location", "Piano Ferry")),
		"objective": String(payload.get("objective", "Find out why the island feels quiet today.")),
		"journal_unlocked": bool(payload.get("journal_unlocked", true)),
		"melody_progress": payload.get("melody_progress", {}),
		"landmark_progress": payload.get("landmark_progress", {}),
		"route_progress": payload.get("route_progress", {}),
		"story_flags": payload.get("story_flags", {}),
		"available_lead_ids": payload.get("available_lead_ids", []),
		"active_lead_id": String(payload.get("active_lead_id", "")),
		"endgame_state": payload.get("endgame_state", {}),
		"manual_pinned_lead_id": String(payload.get("manual_pinned_lead_id", "")),
		"open_shortcuts": payload.get("open_shortcuts", []),
		"resident_profiles": payload.get("resident_profiles", {}),
		"resident_routine_overrides": payload.get("resident_routine_overrides", {}),
		"player_profile": payload.get("player_profile", m_owner.PLAYER_APPEARANCE_CATALOG_SCRIPT.default_profile()),
		"equipped_player_costume_id": String(payload.get("equipped_player_costume_id", m_owner.PLAYER_COSTUME_CATALOG_SCRIPT.default_costume_id())),
		"ending_summary": payload.get("ending_summary", m_owner.ending_summary),
		"story_resume_anchor_id": String(payload.get("story_resume_anchor_id", "Piano Ferry")),
		"story_resume_location": String(payload.get("story_resume_location", payload.get("location", "Piano Ferry"))),
		"fragments_found": int(payload.get("fragments_found", 0)),
		"fragments_total": int(payload.get("fragments_total", 4)),
	}


func _build_story_save_metadata_from_payload(payload: Dictionary) -> Dictionary:
	var fragments_text := "%d / %d" % [
		int(payload.get("fragments_found", 0)),
		maxi(int(payload.get("fragments_total", 4)), 0),
	]
	var resume_location := String(payload.get("story_resume_location", payload.get("location", "")))

	return {
		"exists": true,
		"mode": String(payload.get("mode", "Story")),
		"chapter": String(
			payload.get(
				"chapter",
				m_owner.STORY_ROUTE_GRAPH_SCRIPT.phase_display_name(
					String(payload.get("season_phase", STORY_SEASON_PHASES_SCRIPT.DEFAULT_PHASE))
				)
			)
		),
		"location": String(payload.get("location", resume_location)),
		"fragments_text": fragments_text,
		"resume_anchor_id": String(payload.get("story_resume_anchor_id", "")),
		"resume_location": resume_location,
		"saved_at_unix": int(payload.get("saved_at_unix", 0)),
	}


func _normalize_saved_resident_profiles(saved_profiles: Dictionary) -> Dictionary:
	var normalized: Dictionary = m_owner._default_resident_profiles()

	for resident_id in saved_profiles.keys():
		if !normalized.has(resident_id):
			continue
		var merged_profile: Dictionary = normalized[resident_id].duplicate(true)
		var saved_profile: Variant = saved_profiles.get(resident_id, {})
		if saved_profile is Dictionary:
			merged_profile.merge(saved_profile, true)
			normalized[resident_id] = merged_profile

	return normalized


func _normalize_saved_landmark_progress(saved_progress: Dictionary) -> Dictionary:
	var normalized: Dictionary = m_owner._default_landmark_progress()

	for landmark_id in saved_progress.keys():
		if !normalized.has(landmark_id):
			continue
		var merged_progress: Dictionary = normalized[landmark_id].duplicate(true)
		var incoming_progress: Variant = saved_progress.get(landmark_id, {})
		if incoming_progress is Dictionary:
			merged_progress.merge(incoming_progress, true)
			normalized[landmark_id] = merged_progress

	return normalized


func _normalize_saved_summary(saved_summary: Variant) -> Dictionary:
	var normalized: Dictionary = m_owner.ending_summary.duplicate(true)
	if saved_summary is Dictionary:
		normalized.merge(saved_summary, true)
	if String(normalized.get("collectibles", "")) == "prototype":
		normalized["collectibles"] = "Not tracked in this build"
	return normalized


func _apply_story_autosave_payload(payload: Dictionary) -> bool:
	if payload.is_empty():
		return false

	m_owner.story_resume_anchor_id = String(payload.get("story_resume_anchor_id", "Piano Ferry"))
	if m_owner.story_resume_anchor_id.is_empty():
		m_owner.story_resume_anchor_id = "Piano Ferry"
	m_owner.story_resume_location = String(payload.get("story_resume_location", payload.get("location", "Piano Ferry")))
	if m_owner.story_resume_location.is_empty():
		m_owner.story_resume_location = "Piano Ferry"

	m_owner.set_mode(String(payload.get("mode", "Story")))
	m_owner._apply_story_route_state_bundle(payload)
	m_owner.set_location(String(payload.get("location", m_owner.story_resume_location)))
	m_owner.set_objective(String(payload.get("objective", m_owner.objective)))
	m_owner.set_journal_unlocked(bool(payload.get("journal_unlocked", true)))
	m_owner.set_hint(m_owner.build_input_hint("R Inspect"))
	m_owner.set_landmarks(m_owner._default_landmarks())
	m_owner.set_open_shortcuts(payload.get("open_shortcuts", []))
	m_owner.set_resident_profiles(_normalize_saved_resident_profiles(payload.get("resident_profiles", {})))
	m_owner.set_resident_routine_overrides(
		_normalize_saved_resident_routine_overrides(payload.get("resident_routine_overrides", {}))
	)
	m_owner.set_melody_progress(payload.get("melody_progress", {}))
	m_owner.set_all_landmark_progress(_normalize_saved_landmark_progress(payload.get("landmark_progress", {})))
	m_owner.set_summary(_normalize_saved_summary(payload.get("ending_summary", {})))
	m_owner.set_player_profile(payload.get("player_profile", m_owner.PLAYER_APPEARANCE_CATALOG_SCRIPT.default_profile()))
	m_owner.refresh_story_routes()
	m_owner._sync_story_route_dependent_landmarks()

	var saved_costume_id := String(
		payload.get("equipped_player_costume_id", m_owner.PLAYER_COSTUME_CATALOG_SCRIPT.default_costume_id())
	)
	if !m_owner.equip_player_costume(saved_costume_id):
		m_owner.equip_player_costume(m_owner.PLAYER_COSTUME_CATALOG_SCRIPT.default_costume_id())

	m_owner._update_summary_counts()
	refresh_story_autosave_metadata()
	return true


func _normalize_saved_resident_routine_overrides(saved_overrides: Variant) -> Dictionary:
	var normalized: Dictionary = {}
	if !(saved_overrides is Dictionary):
		return normalized

	for resident_id in (saved_overrides as Dictionary).keys():
		var override_value = (saved_overrides as Dictionary).get(resident_id)
		if !(override_value is Dictionary):
			continue
		var resident_key := String(resident_id).strip_edges()
		if resident_key.is_empty():
			continue
		normalized[resident_key] = (override_value as Dictionary).duplicate(true)

	return normalized
