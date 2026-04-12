# @tool is required so that catalog data (melody_catalog, player_costume_catalog,
# etc.) remains available when the scene-owned service is loaded in the editor.
# Scene-mutating or signal-dependent logic still stays out of edit-time, but
# heavier resident runtime state is initialized lazily so catalog issues have a
# smaller blast radius during startup and editor loads.
@tool
class_name AppStateService
extends Node

const RESIDENT_CATALOG_SCRIPT := preload("res://game/resident_catalog.gd")
const MELODY_CATALOG_SCRIPT := preload("res://game/melody_catalog.gd")
const PLAYER_APPEARANCE_CATALOG_SCRIPT := preload("res://game/player_appearance_catalog.gd")
const PLAYER_COSTUME_CATALOG_SCRIPT := preload("res://game/player_costume_catalog.gd")
const JOURNAL_BUILDER_SCRIPT := preload("res://game/journal_builder.gd")
const PLAYER_PROFILE_SERVICE_SCRIPT := preload("res://game/player_profile_service.gd")
const STORY_SAVE_SERVICE_SCRIPT := preload("res://game/story_save_service.gd")
const STORY_ROUTE_GRAPH_SCRIPT := preload("res://game/story_route_graph.gd")
const LANDMARK_PROGRESSION_SCRIPT := preload("res://game/landmark_progression.gd")
const AUDIO_SETTINGS_SERVICE_SCRIPT := preload("res://game/audio_settings_service.gd")
const RESIDENT_INTERACTION_SERVICE_SCRIPT := preload("res://game/resident_interaction_service.gd")
const STORY_AUTOSAVE_PATH := "user://story_autosave.save"
const APP_STATE_GROUP := &"app_state_service"
const SHORTCUT_DEFINITIONS := {
	"bi_shan_crossing": {
		"display_name": "Bi Shan Tunnel Route",
		"summary": "The Bi Shan tunnel now reads as a dependable passage between the island's north and south approaches.",
	},
}

signal mode_changed(mode: String)
signal chapter_changed(chapter: String)
signal location_changed(location: String)
signal objective_changed(objective: String)
signal hint_changed(hint: String)
signal save_status_changed(status: String)
signal fragments_changed(found: int, total: int)
signal melody_progress_changed(melody_id: String, melody: Dictionary)
signal melody_hint_shown(text: String)
signal melody_prompt_requested(request: Dictionary)
signal landmark_audio_cue_requested(cue_id: String, context: Dictionary)
signal landmarks_changed(landmarks: PackedStringArray)
signal residents_changed(residents: PackedStringArray)
signal resident_profile_changed(resident_id: String, resident: Dictionary)
signal player_profile_changed(profile: Dictionary)
signal player_costume_changed(costume_id: String, costume: Dictionary)
signal player_costumes_changed(unlocked_ids: PackedStringArray, equipped_costume_id: String)
signal player_appearance_changed(profile: Dictionary, appearance_config: Dictionary)
signal summary_changed(summary: Dictionary)
signal landmark_progress_changed(landmark_id: String, progress: Dictionary)
signal story_milestone(milestone_id: String, context: Dictionary)
signal season_phase_changed(phase_id: String)
signal route_progress_changed(route_id: String, progress: Dictionary)
signal active_leads_changed(active_lead_id: String, available_lead_ids: PackedStringArray)
signal endgame_state_changed(endgame_state: Dictionary)
signal save_metadata_changed(metadata: Dictionary)
signal master_volume_changed(volume_percent: float)
signal music_volume_changed(volume_percent: float)
signal prompt_volume_changed(volume_percent: float)
signal dialogue_text_speed_changed(speed_percent: float, characters_per_second: float)

var mode := "Title"
var chapter := "Arrival"
var season_phase := "summer_1"
var location := "Piano Ferry"
var objective := "Find out why the island feels quiet today."
var hint := "R Inspect   J Journal   Esc Pause"
var save_status := "Autosave: ready when story begins"
var journal_unlocked := true
var fragments_found := 0
var fragments_total := 4
var melody_catalog: Dictionary = MELODY_CATALOG_SCRIPT.build_catalog()
var melody_progress: Dictionary = _default_melody_progress()
var landmarks: PackedStringArray = _default_landmarks()
var open_shortcuts: PackedStringArray = PackedStringArray()
var residents: PackedStringArray = PackedStringArray()
var resident_definitions: Dictionary = {}
var resident_profiles: Dictionary = {}
var player_profile: Dictionary = PLAYER_APPEARANCE_CATALOG_SCRIPT.default_profile()
var player_costume_catalog: Dictionary = PLAYER_COSTUME_CATALOG_SCRIPT.build_catalog()
var unlocked_player_costume_ids: PackedStringArray = PLAYER_COSTUME_CATALOG_SCRIPT.build_unlocked_costume_ids(
	mode,
	fragments_found,
	fragments_total,
	{}
)
var equipped_player_costume_id := PLAYER_COSTUME_CATALOG_SCRIPT.default_costume_id()
var landmark_progress: Dictionary = _default_landmark_progress()
var route_progress: Dictionary = {}
var story_flags: Dictionary = {}
var available_lead_ids: PackedStringArray = PackedStringArray()
var active_lead_id := ""
var endgame_state := STORY_ROUTE_GRAPH_SCRIPT.default_endgame_state()
var _manual_pinned_lead_id := ""
var ending_summary := {
	"fragments": "4 / 4",
	"residents": "0",
	"collectibles": "Not tracked in this build",
	"playtime": "a brief evening on Kulangsu",
}
var story_save_metadata := _default_story_save_metadata()
var story_resume_anchor_id := "Piano Ferry"
var story_resume_location := "Piano Ferry"
var _story_autosave_path := STORY_AUTOSAVE_PATH
var m_player_profile_service: RefCounted = null
var m_story_save_service: RefCounted = null
var m_landmark_progression: RefCounted = null
var m_story_route_graph: RefCounted = null
var m_audio_settings_service: RefCounted = null
var m_resident_interaction_service: RefCounted = null


func _init() -> void:
	m_player_profile_service = PLAYER_PROFILE_SERVICE_SCRIPT.new(
		self,
		PLAYER_APPEARANCE_CATALOG_SCRIPT,
		PLAYER_COSTUME_CATALOG_SCRIPT,
		player_costume_catalog,
		mode,
		fragments_found,
		fragments_total,
		resident_profiles
	)
	m_story_save_service = STORY_SAVE_SERVICE_SCRIPT.new(self)
	m_story_save_service.set_story_autosave_path(_story_autosave_path)
	m_landmark_progression = LANDMARK_PROGRESSION_SCRIPT.new(self)
	m_story_route_graph = STORY_ROUTE_GRAPH_SCRIPT.new(self)
	m_audio_settings_service = AUDIO_SETTINGS_SERVICE_SCRIPT.new(self)
	m_resident_interaction_service = RESIDENT_INTERACTION_SERVICE_SCRIPT.new(self)
	story_flags = m_story_route_graph.build_default_story_flags()
	route_progress = m_story_route_graph.build_story_state("new_game").get("route_progress", {}).duplicate(true)


func _enter_tree() -> void:
	add_to_group(APP_STATE_GROUP)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_apply_runtime_settings()
	refresh_story_autosave_metadata()


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


func get_open_shortcuts() -> PackedStringArray:
	return PackedStringArray(open_shortcuts)


func set_open_shortcuts(new_shortcuts: Variant) -> void:
	var normalized := PackedStringArray()
	for shortcut_id in _normalize_string_array(new_shortcuts):
		if SHORTCUT_DEFINITIONS.has(shortcut_id) and normalized.find(shortcut_id) < 0:
			normalized.append(shortcut_id)

	if open_shortcuts == normalized:
		return

	open_shortcuts = normalized


func unlock_shortcut(shortcut_id: String) -> bool:
	var normalized_id := shortcut_id.strip_edges()
	if normalized_id.is_empty() or !SHORTCUT_DEFINITIONS.has(normalized_id):
		return false
	if open_shortcuts.find(normalized_id) >= 0:
		return false

	var next_shortcuts := get_open_shortcuts()
	next_shortcuts.append(normalized_id)
	set_open_shortcuts(next_shortcuts)
	return true


func has_story_autosave() -> bool:
	return bool(story_save_metadata.get("exists", false))


func get_story_save_metadata() -> Dictionary:
	return story_save_metadata.duplicate(true)


func get_story_resume_anchor_id() -> String:
	return story_resume_anchor_id


func get_story_resume_location() -> String:
	return story_resume_location


func set_story_resume_checkpoint(anchor_id: String, location_label: String = "") -> void:
	var normalized_anchor := anchor_id.strip_edges()
	if normalized_anchor.is_empty():
		return

	var normalized_location := location_label.strip_edges()
	if normalized_location.is_empty():
		normalized_location = normalized_anchor

	if story_resume_anchor_id == normalized_anchor and story_resume_location == normalized_location:
		return

	story_resume_anchor_id = normalized_anchor
	story_resume_location = normalized_location

	if _is_story_persistable_mode():
		save_story_autosave()


func override_story_autosave_path_for_tests(path: String) -> void:
	_story_autosave_path = _resolve_story_autosave_test_path(path)
	if _story_autosave_path.is_empty():
		_story_autosave_path = STORY_AUTOSAVE_PATH
	m_story_save_service.set_story_autosave_path(_story_autosave_path)
	refresh_story_autosave_metadata()


func clear_story_autosave() -> void:
	m_story_save_service.clear_story_autosave()


func clear_story_autosave_for_tests() -> void:
	clear_story_autosave()


func _resolve_story_autosave_test_path(path: String) -> String:
	var normalized_path := path.strip_edges()
	if normalized_path.is_empty():
		return STORY_AUTOSAVE_PATH
	if !normalized_path.begins_with("user://"):
		return normalized_path

	var file_name := normalized_path.get_file()
	if file_name.is_empty():
		file_name = "story_autosave_test.save"
	var test_dir := ProjectSettings.globalize_path("res://.godot_test_saves")
	DirAccess.make_dir_recursive_absolute(test_dir)
	return test_dir.path_join(file_name)


func _apply_runtime_settings() -> void:
	if m_audio_settings_service == null:
		return
	m_audio_settings_service.apply_runtime_settings()


func refresh_story_autosave_metadata() -> void:
	m_story_save_service.refresh_story_autosave_metadata()


func save_story_autosave(status_text: String = "") -> bool:
	return m_story_save_service.save_story_autosave(status_text)


func load_story_autosave() -> bool:
	return m_story_save_service.load_story_autosave()


func get_master_volume_percent() -> float:
	return m_audio_settings_service.get_master_volume_percent()


func set_master_volume_percent(new_percent: float) -> void:
	m_audio_settings_service.set_master_volume_percent(new_percent)


func get_music_volume_percent() -> float:
	return m_audio_settings_service.get_music_volume_percent()


func set_music_volume_percent(new_percent: float) -> void:
	m_audio_settings_service.set_music_volume_percent(new_percent)


func get_prompt_volume_percent() -> float:
	return m_audio_settings_service.get_prompt_volume_percent()


func set_prompt_volume_percent(new_percent: float) -> void:
	m_audio_settings_service.set_prompt_volume_percent(new_percent)


func get_dialogue_text_speed_percent() -> float:
	return m_audio_settings_service.get_dialogue_text_speed_percent()


func set_dialogue_text_speed_percent(new_percent: float) -> void:
	m_audio_settings_service.set_dialogue_text_speed_percent(new_percent)


func get_dialogue_text_characters_per_second() -> float:
	return m_audio_settings_service.get_dialogue_text_characters_per_second()


func get_prompt_volume_db(base_volume_db: float = 0.0) -> float:
	return m_audio_settings_service.get_prompt_volume_db(base_volume_db)


func set_mode(new_mode: String) -> void:
	if mode == new_mode:
		return
	mode = new_mode
	mode_changed.emit(mode)
	_refresh_player_costumes()


func set_chapter(new_chapter: String) -> void:
	if chapter == new_chapter:
		return
	chapter = new_chapter
	chapter_changed.emit(chapter)


func set_season_phase(new_phase: String) -> void:
	var normalized_phase := new_phase.strip_edges()
	if normalized_phase.is_empty():
		normalized_phase = "summer_1"
	if season_phase == normalized_phase:
		if mode == "Story" and chapter != get_season_phase_display_name():
			set_chapter(get_season_phase_display_name())
		return
	season_phase = normalized_phase
	season_phase_changed.emit(season_phase)
	if mode == "Story":
		set_chapter(get_season_phase_display_name())
	_update_summary_counts()


func get_season_phase_display_name() -> String:
	return STORY_ROUTE_GRAPH_SCRIPT.phase_display_name(season_phase)


func set_location(new_location: String) -> void:
	if location == new_location:
		return
	location = new_location
	location_changed.emit(location)


func set_objective(new_objective: String) -> void:
	if objective == new_objective:
		return
	objective = new_objective
	objective_changed.emit(objective)


func set_hint(new_hint: String) -> void:
	if hint == new_hint:
		return
	hint = new_hint
	hint_changed.emit(hint)


func set_save_status(new_status: String) -> void:
	if save_status == new_status:
		return
	save_status = new_status
	save_status_changed.emit(save_status)


func set_journal_unlocked(unlocked: bool) -> void:
	journal_unlocked = unlocked


func is_journal_unlocked() -> bool:
	return journal_unlocked


func build_input_hint(primary_action: String = "R Inspect") -> String:
	var parts: PackedStringArray = PackedStringArray()
	if !primary_action.is_empty():
		parts.append(primary_action)
	if journal_unlocked:
		parts.append("J Journal")
	parts.append("Esc Pause")
	return "   ".join(parts)


func set_fragments(found: int, total: int = fragments_total) -> void:
	found = maxi(found, 0)
	total = maxi(total, 0)
	if fragments_found == found and fragments_total == total:
		return
	fragments_found = found
	fragments_total = total
	fragments_changed.emit(fragments_found, fragments_total)
	_refresh_player_costumes()
	_update_summary_counts()


func set_melody_progress(new_progress: Dictionary) -> void:
	melody_progress = _normalize_melody_progress(new_progress)
	for melody_id in get_melody_ids():
		melody_progress_changed.emit(melody_id, get_melody_state(melody_id))
	_sync_fragment_summary_from_melodies()


func set_landmarks(new_landmarks: PackedStringArray) -> void:
	landmarks = new_landmarks
	landmarks_changed.emit(landmarks)


func set_residents(new_residents: PackedStringArray) -> void:
	residents = new_residents
	residents_changed.emit(residents)


func set_resident_profiles(new_profiles: Dictionary) -> void:
	resident_profiles = new_profiles.duplicate(true)
	_sync_known_residents()
	for resident_id in RESIDENT_CATALOG_SCRIPT.resident_order():
		resident_profile_changed.emit(resident_id, get_resident_profile(resident_id))
	_refresh_player_costumes()


func set_summary(summary: Dictionary) -> void:
	ending_summary = summary.duplicate(true)
	_update_summary_counts()


func set_story_flags(new_flags: Dictionary) -> void:
	if m_story_route_graph == null:
		story_flags = new_flags.duplicate(true)
		return
	story_flags = m_story_route_graph.normalize_story_flags(new_flags)
	if mode == "Story":
		refresh_story_routes()


func set_story_flag(flag_id: String, value: Variant = true) -> void:
	var normalized_flag := flag_id.strip_edges()
	if normalized_flag.is_empty():
		return
	if story_flags.get(normalized_flag, null) == value:
		return
	story_flags[normalized_flag] = value


func get_story_flag(flag_id: String, default_value: Variant = false) -> Variant:
	return story_flags.get(flag_id, default_value)


func get_story_flags() -> Dictionary:
	return story_flags.duplicate(true)


func get_route_progress(route_id: String) -> Dictionary:
	if !route_progress.has(route_id):
		return {}
	return route_progress[route_id].duplicate(true)


func set_route_progress(route_id: String, progress: Dictionary) -> void:
	if route_id.is_empty():
		return
	route_progress[route_id] = progress.duplicate(true)
	route_progress_changed.emit(route_id, get_route_progress(route_id))


func set_all_route_progress(new_progress: Dictionary) -> void:
	var route_definitions := STORY_ROUTE_GRAPH_SCRIPT.build_route_definitions()
	route_progress = {}
	for route_id in route_definitions.keys():
		route_progress[route_id] = new_progress.get(route_id, {}).duplicate(true)
		route_progress_changed.emit(route_id, get_route_progress(route_id))


func set_active_leads(new_active_lead_id: String, new_available_lead_ids: Variant) -> void:
	var normalized_available := PackedStringArray()
	for lead_id in _normalize_string_array(new_available_lead_ids):
		if normalized_available.find(lead_id) < 0:
			normalized_available.append(lead_id)

	var normalized_active := new_active_lead_id.strip_edges()
	if !normalized_active.is_empty() and normalized_available.find(normalized_active) < 0:
		normalized_active = ""

	if active_lead_id == normalized_active and available_lead_ids == normalized_available:
		return

	active_lead_id = normalized_active
	available_lead_ids = normalized_available
	active_leads_changed.emit(active_lead_id, PackedStringArray(available_lead_ids))


func get_available_lead_ids() -> PackedStringArray:
	return PackedStringArray(available_lead_ids)


func get_active_lead_id() -> String:
	return active_lead_id


func get_story_route_definition(route_id: String) -> Dictionary:
	if m_story_route_graph == null:
		return {}
	return m_story_route_graph.get_route_definition(route_id)


func get_story_event_definition(event_id: String) -> Dictionary:
	if m_story_route_graph == null:
		return {}
	return m_story_route_graph.get_event_definition(event_id)


func get_active_lead_text() -> String:
	if m_story_route_graph == null:
		return objective
	var lead_text := String(m_story_route_graph.get_active_lead_text())
	if lead_text.is_empty():
		return objective
	return lead_text


func pin_story_lead(lead_id: String) -> void:
	if m_story_route_graph == null:
		return
	m_story_route_graph.pin_story_lead(lead_id)


func cycle_story_lead(direction: int) -> void:
	if m_story_route_graph == null:
		return
	m_story_route_graph.cycle_story_lead(direction)


func clear_manual_story_lead() -> void:
	if m_story_route_graph == null:
		return
	m_story_route_graph.clear_manual_pinned_lead()


func refresh_story_routes() -> void:
	if m_story_route_graph == null:
		return
	m_story_route_graph.refresh_story_state()


func resolve_story_event(event_id: String) -> bool:
	if m_story_route_graph == null:
		return false
	var changed: bool = m_story_route_graph.resolve_story_event(event_id)
	if changed:
		_sync_story_route_dependent_landmarks(event_id)
		_autosave_story_progress()
	return changed


func set_endgame_state(new_endgame_state: Dictionary) -> void:
	if m_story_route_graph == null:
		endgame_state = new_endgame_state.duplicate(true)
	else:
		endgame_state = m_story_route_graph.normalize_endgame_state(new_endgame_state)
	endgame_state_changed.emit(endgame_state.duplicate(true))
	_update_summary_counts()


func apply_ending_choice(choice_id: String) -> void:
	var normalized_choice := choice_id.strip_edges().to_lower()
	if normalized_choice.is_empty():
		return
	set_story_flag("ending_choice", normalized_choice)
	if m_story_route_graph != null:
		var next_endgame_state := endgame_state.duplicate(true)
		next_endgame_state["ending_tone_tags"] = m_story_route_graph.build_ending_tone_tags(normalized_choice)
		set_endgame_state(next_endgame_state)
	ending_summary["ending_choice"] = normalized_choice
	_autosave_story_progress()


func get_endgame_behavior() -> String:
	return String(endgame_state.get("ending_behavior", ""))


func can_continue_after_endgame() -> bool:
	return bool(endgame_state.get("active", false)) and get_endgame_behavior() == "continue_story"


func continue_story_after_endgame() -> bool:
	if !can_continue_after_endgame():
		return false

	var previous_endgame_state := endgame_state.duplicate(true)
	var trigger_event_id := String(previous_endgame_state.get("trigger_event_id", ""))
	var resume_phase_id := String(previous_endgame_state.get("resume_phase_id", "spring_festival"))
	if resume_phase_id.is_empty() or resume_phase_id == "endgame":
		resume_phase_id = "spring_festival"

	set_endgame_state(STORY_ROUTE_GRAPH_SCRIPT.default_endgame_state())
	set_season_phase(resume_phase_id)

	if trigger_event_id == "harbor_festival_performed":
		var melody_state := get_melody_state("festival_melody")
		if !melody_state.is_empty() and bool(melody_state.get("performed", false)):
			melody_state["state"] = "resonant"
			melody_state["next_lead"] = "Wander the island and listen to what the restored melody leaves behind."
			set_melody_progress({"festival_melody": melody_state})
		set_objective("Wander the island and listen to what the restored melody leaves behind.")
		set_save_status("The festival fades, but the island keeps the melody.")

	refresh_story_routes()
	_autosave_story_progress()
	return true


func _default_landmarks() -> PackedStringArray:
	return PackedStringArray([
		"Piano Ferry",
		"Trinity Church",
		"Bi Shan Tunnel",
		"Long Shan Tunnel",
		"Bagua Tower",
	])


func _default_resident_profiles() -> Dictionary:
	_ensure_resident_definitions()
	var profiles: Dictionary = {}
	for resident_id in RESIDENT_CATALOG_SCRIPT.resident_order():
		var definition = resident_definitions.get(resident_id)
		if definition == null:
			continue
		profiles[resident_id] = definition.to_runtime_profile()
	return profiles


func _default_melody_progress() -> Dictionary:
	var progress := {}

	for melody_id in MELODY_CATALOG_SCRIPT.ordered_ids():
		var melody_definition: Dictionary = melody_catalog.get(melody_id, {})
		progress[melody_id] = {
			"state": "unknown",
			"fragments_found": 0,
			"fragments_total": int(melody_definition.get("fragment_total", 0)),
			"known_sources": [],
			"next_lead": String(melody_definition.get("unlock_condition", "")),
			"performed": false,
		}

	return progress


func get_resident_ids() -> PackedStringArray:
	return PackedStringArray(RESIDENT_CATALOG_SCRIPT.resident_order())


func get_melody_ids() -> PackedStringArray:
	return MELODY_CATALOG_SCRIPT.ordered_ids()


func get_melody_definition(melody_id: String) -> Dictionary:
	if !melody_catalog.has(melody_id):
		return {}
	return melody_catalog[melody_id].duplicate(true)


func get_melody_state(melody_id: String) -> Dictionary:
	if !melody_progress.has(melody_id):
		return {}
	return melody_progress[melody_id].duplicate(true)


func can_practice_melody(melody_id: String) -> bool:
	var melody_state := get_melody_state(melody_id)
	if melody_state.is_empty():
		return false

	var melody_stage := String(melody_state.get("state", "unknown"))
	if melody_stage not in ["reconstructed", "performed", "resonant"]:
		return false

	return m_landmark_progression.build_melody_prompt_segments(melody_id).size() >= 2


func can_perform_melody(melody_id: String) -> bool:
	if melody_id == "festival_melody":
		if get_landmark_state("festival_stage") != "available":
			return false
		return can_practice_melody(melody_id)
	return false


func request_melody_practice(melody_id: String) -> void:
	m_landmark_progression.request_melody_prompt(melody_id, "practice")


func complete_prompt_request(request: Dictionary) -> void:
	m_landmark_progression.complete_prompt_request(request)


func complete_melody_practice(melody_id: String) -> void:
	m_landmark_progression.complete_melody_practice(melody_id)


func complete_melody_performance(melody_id: String) -> void:
	m_landmark_progression.complete_melody_performance(melody_id)


func get_resident_profile(resident_id: String) -> Dictionary:
	_ensure_resident_profiles()
	if !resident_profiles.has(resident_id):
		return {}
	return resident_profiles[resident_id].duplicate(true)


func get_resident_definition(resident_id: String):
	_ensure_resident_definitions()
	return resident_definitions.get(resident_id)


func get_resident_display_name(resident_id: String) -> String:
	_ensure_resident_profiles()
	var definition = get_resident_definition(resident_id)
	if definition != null and !definition.display_name.is_empty():
		return definition.display_name
	var resident: Dictionary = resident_profiles.get(resident_id, {})
	return String(resident.get("display_name", "Resident"))


func get_resident_landmark(resident_id: String) -> String:
	_ensure_resident_profiles()
	var definition = get_resident_definition(resident_id)
	if definition != null and !definition.landmark.is_empty():
		return definition.landmark
	var resident: Dictionary = resident_profiles.get(resident_id, {})
	return String(resident.get("landmark", "Unknown District"))


func get_resident_appearance_config(resident_id: String) -> Dictionary:
	_ensure_resident_profiles()
	var definition = get_resident_definition(resident_id)
	if definition != null:
		var definition_appearance = definition.build_appearance_config()
		if !definition_appearance.is_empty():
			return definition_appearance

	var resident: Dictionary = resident_profiles.get(resident_id, {})
	var appearance: Dictionary = resident.get("appearance", {})
	return appearance.duplicate(true)


func get_resident_spawn_config(resident_id: String) -> Dictionary:
	_ensure_resident_profiles()
	var definition = get_resident_definition(resident_id)
	if definition != null:
		var definition_spawn = definition.get_spawn_config()
		if !definition_spawn.is_empty():
			return definition_spawn

	var resident: Dictionary = resident_profiles.get(resident_id, {})
	var spawn: Dictionary = resident.get("spawn", {})
	return spawn.duplicate(true)


func get_resident_movement_config(resident_id: String) -> Dictionary:
	_ensure_resident_profiles()
	var definition = get_resident_definition(resident_id)
	if definition != null:
		var definition_movement = definition.get_movement_config()
		if !definition_movement.is_empty():
			return definition_movement

	var resident: Dictionary = resident_profiles.get(resident_id, {})
	var movement: Dictionary = resident.get("movement", {})
	return movement.duplicate(true)


func get_resident_behavior_config(resident_id: String) -> Dictionary:
	_ensure_resident_profiles()
	var definition = get_resident_definition(resident_id)
	if definition != null:
		var definition_behavior = definition.get_behavior_config()
		if !definition_behavior.is_empty():
			return definition_behavior

	var resident: Dictionary = resident_profiles.get(resident_id, {})
	var behavior: Dictionary = resident.get("behavior", {})
	return behavior.duplicate(true)


func get_player_profile() -> Dictionary:
	return m_player_profile_service.get_player_profile()


func get_player_body_display_name() -> String:
	return m_player_profile_service.get_player_body_display_name()


func get_player_gender_display_name() -> String:
	return m_player_profile_service.get_player_gender_display_name()


func get_player_skin_display_name() -> String:
	return m_player_profile_service.get_player_skin_display_name()


func get_player_hair_style_display_name() -> String:
	return m_player_profile_service.get_player_hair_style_display_name()


func get_player_hair_color_display_name() -> String:
	return m_player_profile_service.get_player_hair_color_display_name()


func get_player_costume_ids() -> PackedStringArray:
	return m_player_profile_service.get_player_costume_ids()


func get_player_costume(costume_id: String) -> Dictionary:
	return m_player_profile_service.get_player_costume(costume_id)


func get_unlocked_player_costume_ids() -> PackedStringArray:
	return m_player_profile_service.get_unlocked_player_costume_ids()


func get_equipped_player_costume_id() -> String:
	return m_player_profile_service.get_equipped_player_costume_id()


func get_equipped_player_costume() -> Dictionary:
	return m_player_profile_service.get_equipped_player_costume()


func get_equipped_player_costume_display_name() -> String:
	return m_player_profile_service.get_equipped_player_costume_display_name()


func set_player_profile(new_profile: Dictionary) -> bool:
	return m_player_profile_service.set_player_profile(new_profile)


func cycle_player_body_frame(direction: int) -> void:
	m_player_profile_service.cycle_player_body_frame(direction)


func cycle_player_gender(direction: int) -> void:
	m_player_profile_service.cycle_player_gender(direction)


func cycle_player_skin_tone(direction: int) -> void:
	m_player_profile_service.cycle_player_skin_tone(direction)


func cycle_player_hair_style(direction: int) -> void:
	m_player_profile_service.cycle_player_hair_style(direction)


func cycle_player_hair_color(direction: int) -> void:
	m_player_profile_service.cycle_player_hair_color(direction)


func get_player_appearance_config() -> Dictionary:
	return m_player_profile_service.get_player_appearance_config()


func equip_player_costume(costume_id: String) -> bool:
	return m_player_profile_service.equip_player_costume(costume_id)


func cycle_player_costume(direction: int) -> void:
	m_player_profile_service.cycle_player_costume(direction)


func get_known_resident_names() -> PackedStringArray:
	return m_resident_interaction_service.get_known_resident_names()


func get_resident_ambient_line(resident_id: String) -> String:
	return m_resident_interaction_service.get_resident_ambient_line(resident_id)


func build_map_journal_text() -> String:
	return JOURNAL_BUILDER_SCRIPT.build_map_journal_text(self)


func build_resident_journal_text() -> String:
	return JOURNAL_BUILDER_SCRIPT.build_resident_journal_text(self)


func build_story_routes_journal_text() -> String:
	return JOURNAL_BUILDER_SCRIPT.build_story_routes_journal_text(self)


func build_melody_journal_text() -> String:
	return JOURNAL_BUILDER_SCRIPT.build_melody_journal_text(self)


func build_player_costume_journal_text() -> String:
	return JOURNAL_BUILDER_SCRIPT.build_player_costume_journal_text(self)


func build_player_setup_summary_text() -> String:
	return JOURNAL_BUILDER_SCRIPT.build_player_setup_summary_text(self)


func _apply_story_route_state_bundle(state: Dictionary) -> void:
	if m_story_route_graph == null:
		return
	story_flags = m_story_route_graph.normalize_story_flags(state.get("story_flags", {}))
	_manual_pinned_lead_id = String(state.get("manual_pinned_lead_id", ""))
	endgame_state = m_story_route_graph.normalize_endgame_state(state.get("endgame_state", {}))
	endgame_state_changed.emit(endgame_state.duplicate(true))
	set_season_phase(String(state.get("season_phase", "summer_1")))


func _is_story_persistable_mode(mode_id: String = mode) -> bool:
	return mode_id == "Story"


func _autosave_story_progress() -> void:
	if _is_story_persistable_mode():
		save_story_autosave()


func interact_with_resident(resident_id: String) -> Dictionary:
	return m_resident_interaction_service.interact_with_resident(resident_id)


func configure_new_game() -> void:
	m_story_save_service.configure_new_game()


func configure_continue() -> bool:
	return m_story_save_service.configure_continue()


func configure_free_walk() -> void:
	m_story_save_service.configure_free_walk()


func _apply_resident_beat(beat: Dictionary) -> void:
	m_resident_interaction_service._apply_resident_beat(beat)


func _sync_known_residents() -> void:
	m_resident_interaction_service._sync_known_residents()


func _seed_resident_progress(
	resident_id: String,
	conversation_index: int,
	trust: int,
	quest_state: String,
	current_step: String
) -> void:
	m_resident_interaction_service._seed_resident_progress(
		resident_id,
		conversation_index,
		trust,
		quest_state,
		current_step
	)


func _count_helped_residents() -> int:
	return m_resident_interaction_service._count_helped_residents()


func _update_summary_counts() -> void:
	var summary := ending_summary.duplicate(true)
	summary["fragments"] = "%d / %d" % [fragments_found, fragments_total]
	summary["residents"] = str(_count_helped_residents())
	summary["season"] = get_season_phase_display_name()
	if m_story_route_graph != null:
		summary["routes"] = m_story_route_graph.build_route_completion_summary()
	summary["ending_trigger"] = String(endgame_state.get("trigger_event_id", ""))
	var ending_tone_tags := PackedStringArray(_normalize_string_array(endgame_state.get("ending_tone_tags", [])))
	summary["ending_tones"] = ", ".join(ending_tone_tags)
	ending_summary = summary
	summary_changed.emit(ending_summary)


func _build_story_melody_progress(state_id: String) -> Dictionary:
	match state_id:
		"new_game":
			return {
				"festival_melody": {
					"state": "heard",
					"fragments_found": 0,
					"known_sources": ["ferry_plaza"],
					"next_lead": "Listen to the harbor refrain around the ferry plaza before following the bells uphill.",
					"performed": false,
				},
			}
		"continue":
			return {
				"festival_melody": {
					"state": "heard",
					"fragments_found": 1,
					"known_sources": ["ferry_plaza", "church_bells"],
					"next_lead": "Follow either tunnel route and see how the church phrase changes under stone.",
					"performed": false,
				},
			}
		"free_walk":
			return {
				"festival_melody": {
					"state": "heard",
					"fragments_found": 0,
					"known_sources": ["ferry_plaza"],
					"next_lead": "Wander freely and use residents to sample how each district hears the island's missing tune.",
					"performed": false,
				},
			}
		_:
			return _default_melody_progress()


func _normalize_melody_progress(new_progress: Dictionary) -> Dictionary:
	var normalized := _default_melody_progress()

	for melody_id in get_melody_ids():
		var melody_definition: Dictionary = melody_catalog.get(melody_id, {})
		var current_state: Dictionary = normalized.get(melody_id, {}).duplicate(true)
		var incoming_state: Dictionary = new_progress.get(melody_id, {})

		current_state["state"] = String(incoming_state.get("state", current_state.get("state", "unknown")))
		current_state["fragments_total"] = maxi(
			int(incoming_state.get("fragments_total", current_state.get("fragments_total", int(melody_definition.get("fragment_total", 0))))),
			0
		)
		current_state["fragments_found"] = clampi(
			int(incoming_state.get("fragments_found", current_state.get("fragments_found", 0))),
			0,
			int(current_state.get("fragments_total", 0))
		)
		current_state["known_sources"] = _normalize_string_array(
			incoming_state.get("known_sources", current_state.get("known_sources", []))
		)
		current_state["next_lead"] = String(incoming_state.get("next_lead", current_state.get("next_lead", "")))
		current_state["performed"] = bool(incoming_state.get("performed", current_state.get("performed", false)))

		normalized[melody_id] = current_state

	return normalized


func _normalize_string_array(value: Variant) -> Array[String]:
	var output: Array[String] = []

	if value is PackedStringArray:
		for entry in value:
			output.append(String(entry))
		return output

	if value is Array:
		for entry in value:
			output.append(String(entry))

	return output


func _sync_fragment_summary_from_melodies() -> void:
	var total_found := 0
	var total_fragments := 0

	for melody_id in get_melody_ids():
		var melody_state: Dictionary = melody_progress.get(melody_id, {})
		total_found += int(melody_state.get("fragments_found", 0))
		total_fragments += int(melody_state.get("fragments_total", 0))

	set_fragments(total_found, total_fragments)


func _cycle_player_profile_option(profile_key: String, options: Array, direction: int) -> void:
	var next_profile := get_player_profile()
	var current_id := String(next_profile.get(profile_key, ""))
	next_profile[profile_key] = PLAYER_APPEARANCE_CATALOG_SCRIPT.cycle_option_id(options, current_id, direction)
	set_player_profile(next_profile)


func _emit_melody_hint_shown(text: String) -> void:
	melody_hint_shown.emit(text)


func _emit_melody_prompt_requested(request: Dictionary) -> void:
	melody_prompt_requested.emit(request)


func _emit_player_profile_changed(profile: Dictionary) -> void:
	player_profile_changed.emit(profile)


func _emit_player_costume_changed(costume_id: String, costume: Dictionary) -> void:
	player_costume_changed.emit(costume_id, costume)


func _emit_player_costumes_changed(unlocked_ids: PackedStringArray, equipped_costume_id: String) -> void:
	player_costumes_changed.emit(unlocked_ids, equipped_costume_id)


func _emit_save_metadata_changed(metadata: Dictionary) -> void:
	save_metadata_changed.emit(metadata)


func _emit_player_appearance_changed() -> void:
	player_appearance_changed.emit(get_player_profile(), get_player_appearance_config())


func _refresh_player_costumes() -> void:
	_ensure_resident_profiles()
	m_player_profile_service.refresh_player_costumes(
		mode,
		fragments_found,
		fragments_total,
		resident_profiles
	)


func _ensure_resident_definitions() -> void:
	if !resident_definitions.is_empty():
		return

	resident_definitions = RESIDENT_CATALOG_SCRIPT.build_definitions()


func _ensure_resident_profiles() -> void:
	if !resident_profiles.is_empty():
		return

	resident_profiles = _default_resident_profiles()


# ---------------------------------------------------------------------------
# Landmark Progress
# ---------------------------------------------------------------------------

func _default_landmark_progress() -> Dictionary:
	return {
		"piano_ferry": {"state": "locked", "harbor_clue_found": false},
		"trinity_church": {"state": "locked", "cues_collected": [], "chime_performed": false},
		"bi_shan_tunnel": {"state": "locked", "echoes_collected": []},
		"long_shan_tunnel": {"state": "locked", "checkpoints_collected": []},
		"bagua_tower": {"state": "locked", "synthesis_done": false},
		"festival_stage": {"state": "locked"},
	}


func _build_landmark_progress(state_id: String) -> Dictionary:
	match state_id:
		"new_game":
			return {
				"piano_ferry": {"state": "available", "harbor_clue_found": false},
				"trinity_church": {"state": "locked", "cues_collected": [], "chime_performed": false},
				"bi_shan_tunnel": {"state": "locked", "echoes_collected": []},
				"long_shan_tunnel": {"state": "locked", "checkpoints_collected": []},
				"bagua_tower": {"state": "locked", "synthesis_done": false},
				"festival_stage": {"state": "locked"},
			}
		"continue":
			return {
				"piano_ferry": {"state": "reward_collected", "harbor_clue_found": true},
				"trinity_church": {"state": "reward_collected", "cues_collected": ["steps", "garden", "yard"], "chime_performed": true},
				"bi_shan_tunnel": {"state": "available", "echoes_collected": []},
				"long_shan_tunnel": {"state": "available", "checkpoints_collected": []},
				"bagua_tower": {"state": "locked", "synthesis_done": false},
				"festival_stage": {"state": "locked"},
			}
		"free_walk":
			return {
				"piano_ferry": {"state": "introduced", "harbor_clue_found": false},
				"trinity_church": {"state": "available", "cues_collected": [], "chime_performed": false},
				"bi_shan_tunnel": {"state": "available", "echoes_collected": []},
				"long_shan_tunnel": {"state": "available", "checkpoints_collected": []},
				"bagua_tower": {"state": "available", "synthesis_done": false},
				"festival_stage": {"state": "locked"},
			}
		_:
			return _default_landmark_progress()


func get_landmark_progress(landmark_id: String) -> Dictionary:
	if !landmark_progress.has(landmark_id):
		return {}
	return landmark_progress[landmark_id].duplicate(true)


func get_landmark_state(landmark_id: String) -> String:
	return String(landmark_progress.get(landmark_id, {}).get("state", "locked"))


func set_landmark_progress(landmark_id: String, new_progress: Dictionary) -> void:
	if !landmark_progress.has(landmark_id):
		return
	landmark_progress[landmark_id] = new_progress.duplicate(true)
	landmark_progress_changed.emit(landmark_id, get_landmark_progress(landmark_id))


func set_all_landmark_progress(new_progress: Dictionary) -> void:
	for landmark_id in new_progress.keys():
		if landmark_progress.has(landmark_id):
			landmark_progress[landmark_id] = new_progress[landmark_id].duplicate(true)
			landmark_progress_changed.emit(landmark_id, get_landmark_progress(landmark_id))


func advance_landmark_state(landmark_id: String, new_state: String) -> void:
	var progress := get_landmark_progress(landmark_id)
	if progress.is_empty():
		return
	progress["state"] = new_state
	set_landmark_progress(landmark_id, progress)


func _request_landmark_audio_cue(
	cue_id: String,
	landmark_id: String,
	trigger_id: String,
	display_name: String
) -> void:
	if cue_id.is_empty():
		return
	landmark_audio_cue_requested.emit(cue_id, {
		"landmark_id": landmark_id,
		"trigger_id": trigger_id,
		"display_name": display_name,
	})


## Called when the player inspects a LandmarkTrigger in the world.
## Routes to the appropriate per-landmark collection handler.
## Returns true only when the caller should consume the trigger in the scene.
## melody_hint is optional flavour text shown to the player on collection.
func activate_landmark_trigger(landmark_id: String, trigger_id: String, display_name: String, melody_hint: String = "") -> bool:
	return m_landmark_progression.activate_landmark_trigger(
		landmark_id,
		trigger_id,
		display_name,
		melody_hint
	)


func _sync_story_route_dependent_landmarks(event_id: String = "") -> void:
	if m_landmark_progression == null:
		return
	if event_id.is_empty() or event_id == "spring_festival_resolved" or event_id == "melody_bagua_aligned":
		m_landmark_progression.sync_festival_stage_availability(event_id == "spring_festival_resolved")


func _emit_story_milestone(milestone_id: String, context: Dictionary = {}) -> void:
	story_milestone.emit(milestone_id, context.duplicate(true))


## Dispatch to the correct landmark resolution handler and emit a story
## milestone so ambient systems can react without coupling to internals.
func _resolve_landmark(landmark_id: String) -> void:
	m_landmark_progression.resolve_landmark(landmark_id)
