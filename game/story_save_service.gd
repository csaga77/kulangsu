class_name StorySaveService
extends RefCounted

const STORY_AUTOSAVE_VERSION := 1
const STORY_AUTOSAVE_PATH := "user://story_autosave.save"

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
	var next_metadata := _default_story_save_metadata()
	var payload := _read_story_autosave_payload()
	if !payload.is_empty():
		next_metadata = _build_story_save_metadata_from_payload(payload)

	m_owner.story_save_metadata = next_metadata
	m_owner.save_metadata_changed.emit(m_owner.get_story_save_metadata())


func save_story_autosave(status_text: String = "") -> bool:
	if !_is_story_persistable_mode():
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


func _is_story_persistable_mode(mode_id: String = "") -> bool:
	var normalized_mode := mode_id
	if normalized_mode.is_empty():
		normalized_mode = m_owner.mode
	return normalized_mode in ["Story", "Postgame"]


func _build_story_autosave_payload() -> Dictionary:
	return {
		"version": STORY_AUTOSAVE_VERSION,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"mode": m_owner.mode,
		"chapter": m_owner.chapter,
		"location": m_owner.location,
		"objective": m_owner.objective,
		"journal_unlocked": m_owner.journal_unlocked,
		"melody_progress": m_owner.melody_progress.duplicate(true),
		"landmark_progress": m_owner.landmark_progress.duplicate(true),
		"open_shortcuts": m_owner.get_open_shortcuts(),
		"resident_profiles": m_owner.resident_profiles.duplicate(true),
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
	if !_is_story_persistable_mode(normalized_mode):
		normalized_mode = "Story"

	return {
		"version": STORY_AUTOSAVE_VERSION,
		"saved_at_unix": int(payload.get("saved_at_unix", 0)),
		"mode": normalized_mode,
		"chapter": String(payload.get("chapter", "Arrival")),
		"location": String(payload.get("location", "Piano Ferry")),
		"objective": String(payload.get("objective", "Find out why the island feels quiet today.")),
		"journal_unlocked": bool(payload.get("journal_unlocked", true)),
		"melody_progress": payload.get("melody_progress", {}),
		"landmark_progress": payload.get("landmark_progress", {}),
		"open_shortcuts": payload.get("open_shortcuts", []),
		"resident_profiles": payload.get("resident_profiles", {}),
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
		"chapter": String(payload.get("chapter", "")),
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
	m_owner.set_chapter(String(payload.get("chapter", "Arrival")))
	m_owner.set_location(String(payload.get("location", m_owner.story_resume_location)))
	m_owner.set_objective(String(payload.get("objective", m_owner.objective)))
	m_owner.set_journal_unlocked(bool(payload.get("journal_unlocked", true)))
	m_owner.set_hint(m_owner.build_input_hint("R Inspect"))
	m_owner.set_landmarks(m_owner._default_landmarks())
	m_owner.set_open_shortcuts(payload.get("open_shortcuts", []))
	m_owner.set_resident_profiles(_normalize_saved_resident_profiles(payload.get("resident_profiles", {})))
	m_owner.set_melody_progress(payload.get("melody_progress", {}))
	m_owner.set_all_landmark_progress(_normalize_saved_landmark_progress(payload.get("landmark_progress", {})))
	m_owner.set_summary(_normalize_saved_summary(payload.get("ending_summary", {})))
	m_owner.set_player_profile(payload.get("player_profile", m_owner.PLAYER_APPEARANCE_CATALOG_SCRIPT.default_profile()))

	var saved_costume_id := String(
		payload.get("equipped_player_costume_id", m_owner.PLAYER_COSTUME_CATALOG_SCRIPT.default_costume_id())
	)
	if !m_owner.equip_player_costume(saved_costume_id):
		m_owner.equip_player_costume(m_owner.PLAYER_COSTUME_CATALOG_SCRIPT.default_costume_id())

	m_owner._update_summary_counts()
	refresh_story_autosave_metadata()
	return true


func _default_story_save_metadata() -> Dictionary:
	return {
		"exists": false,
		"mode": "",
		"chapter": "",
		"location": "",
		"fragments_text": "0 / 4",
		"resume_anchor_id": "",
		"resume_location": "",
		"saved_at_unix": 0,
	}
