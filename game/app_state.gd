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
const STORY_AUTOSAVE_VERSION := 1
const STORY_AUTOSAVE_PATH := "user://story_autosave.save"
const APP_STATE_GROUP := &"app_state_service"
const MASTER_BUS_NAME := &"Master"
const BGM_BUS_NAME := &"BGM"
const DEFAULT_MASTER_VOLUME_PERCENT := 100.0
const DEFAULT_MUSIC_VOLUME_PERCENT := 100.0
const DEFAULT_PROMPT_VOLUME_PERCENT := 100.0
const DEFAULT_DIALOGUE_TEXT_SPEED_PERCENT := 100.0
const DEFAULT_DIALOGUE_TEXT_CHARACTERS_PER_SECOND := 120.0
const MIN_DIALOGUE_TEXT_SPEED_PERCENT := 25.0
const MAX_DIALOGUE_TEXT_SPEED_PERCENT := 200.0
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
var master_volume_percent := DEFAULT_MASTER_VOLUME_PERCENT
var music_volume_percent := DEFAULT_MUSIC_VOLUME_PERCENT
var prompt_volume_percent := DEFAULT_PROMPT_VOLUME_PERCENT
var dialogue_text_speed_percent := DEFAULT_DIALOGUE_TEXT_SPEED_PERCENT
var story_save_metadata := _default_story_save_metadata()
var story_resume_anchor_id := "Piano Ferry"
var story_resume_location := "Piano Ferry"
var _story_autosave_path := STORY_AUTOSAVE_PATH
var m_player_profile_service: RefCounted = null
var m_story_save_service: RefCounted = null
var m_landmark_progression: RefCounted = null
var m_story_route_graph: RefCounted = null


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
	_apply_bus_volume(MASTER_BUS_NAME, master_volume_percent)
	_apply_bus_volume(BGM_BUS_NAME, music_volume_percent)


func _apply_bus_volume(bus_name: StringName, volume_percent: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return

	AudioServer.set_bus_volume_db(bus_index, _scale_db_from_percent(volume_percent))


func _scale_db_from_percent(volume_percent: float, base_volume_db: float = 0.0) -> float:
	var normalized_volume := maxf(volume_percent / 100.0, 0.0)
	if normalized_volume <= 0.0001:
		return -80.0
	return base_volume_db + linear_to_db(normalized_volume)


func refresh_story_autosave_metadata() -> void:
	m_story_save_service.refresh_story_autosave_metadata()


func save_story_autosave(status_text: String = "") -> bool:
	return m_story_save_service.save_story_autosave(status_text)


func load_story_autosave() -> bool:
	return m_story_save_service.load_story_autosave()


func get_master_volume_percent() -> float:
	return master_volume_percent


func set_master_volume_percent(new_percent: float) -> void:
	var normalized_percent := clampf(new_percent, 0.0, 100.0)
	if is_equal_approx(master_volume_percent, normalized_percent):
		return

	master_volume_percent = normalized_percent
	_apply_bus_volume(MASTER_BUS_NAME, master_volume_percent)
	master_volume_changed.emit(master_volume_percent)


func get_music_volume_percent() -> float:
	return music_volume_percent


func set_music_volume_percent(new_percent: float) -> void:
	var normalized_percent := clampf(new_percent, 0.0, 100.0)
	if is_equal_approx(music_volume_percent, normalized_percent):
		return

	music_volume_percent = normalized_percent
	_apply_bus_volume(BGM_BUS_NAME, music_volume_percent)
	music_volume_changed.emit(music_volume_percent)


func get_prompt_volume_percent() -> float:
	return prompt_volume_percent


func set_prompt_volume_percent(new_percent: float) -> void:
	var normalized_percent := clampf(new_percent, 0.0, 100.0)
	if is_equal_approx(prompt_volume_percent, normalized_percent):
		return

	prompt_volume_percent = normalized_percent
	prompt_volume_changed.emit(prompt_volume_percent)


func get_dialogue_text_speed_percent() -> float:
	return dialogue_text_speed_percent


func set_dialogue_text_speed_percent(new_percent: float) -> void:
	var normalized_percent := clampf(
		new_percent,
		MIN_DIALOGUE_TEXT_SPEED_PERCENT,
		MAX_DIALOGUE_TEXT_SPEED_PERCENT
	)
	if is_equal_approx(dialogue_text_speed_percent, normalized_percent):
		return

	dialogue_text_speed_percent = normalized_percent
	dialogue_text_speed_changed.emit(
		dialogue_text_speed_percent,
		get_dialogue_text_characters_per_second()
	)


func get_dialogue_text_characters_per_second() -> float:
	return DEFAULT_DIALOGUE_TEXT_CHARACTERS_PER_SECOND * (dialogue_text_speed_percent / 100.0)


func get_prompt_volume_db(base_volume_db: float = 0.0) -> float:
	return _scale_db_from_percent(prompt_volume_percent, base_volume_db)


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
		if mode in ["Story", "Postgame"] and chapter != get_season_phase_display_name():
			set_chapter(get_season_phase_display_name())
		return
	season_phase = normalized_phase
	season_phase_changed.emit(season_phase)
	if mode in ["Story", "Postgame"]:
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
	if mode in ["Story", "Postgame"]:
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
	_ensure_resident_profiles()
	var names := PackedStringArray()
	for resident_id in RESIDENT_CATALOG_SCRIPT.resident_order():
		var resident: Dictionary = resident_profiles.get(resident_id, {})
		if resident.get("known", false):
			names.append(String(resident.get("display_name", resident_id)))
	return names


func get_resident_ambient_line(resident_id: String) -> String:
	_ensure_resident_profiles()
	var resident: Dictionary = resident_profiles.get(resident_id, {})
	if resident.is_empty():
		return ""

	var ambient_lines: Array = resident.get("ambient_lines", [])
	if ambient_lines.is_empty():
		return ""

	var conversation_index := clampi(
		int(resident.get("conversation_index", 0)),
		0,
		ambient_lines.size() - 1
	)
	return String(ambient_lines[conversation_index])


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
	return mode_id in ["Story", "Postgame"]


func _build_story_autosave_payload() -> Dictionary:
	return {
		"version": STORY_AUTOSAVE_VERSION,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"mode": mode,
		"chapter": chapter,
		"season_phase": season_phase,
		"location": location,
		"objective": objective,
		"journal_unlocked": journal_unlocked,
		"melody_progress": melody_progress.duplicate(true),
		"landmark_progress": landmark_progress.duplicate(true),
		"route_progress": route_progress.duplicate(true),
		"story_flags": get_story_flags(),
		"available_lead_ids": get_available_lead_ids(),
		"active_lead_id": get_active_lead_id(),
		"endgame_state": endgame_state.duplicate(true),
		"manual_pinned_lead_id": _manual_pinned_lead_id,
		"open_shortcuts": get_open_shortcuts(),
		"resident_profiles": resident_profiles.duplicate(true),
		"player_profile": player_profile.duplicate(true),
		"equipped_player_costume_id": equipped_player_costume_id,
		"ending_summary": ending_summary.duplicate(true),
		"story_resume_anchor_id": story_resume_anchor_id,
		"story_resume_location": story_resume_location,
		"fragments_found": fragments_found,
		"fragments_total": fragments_total,
	}


func _read_story_autosave_payload() -> Dictionary:
	if !FileAccess.file_exists(_story_autosave_path):
		return {}

	var file := FileAccess.open(_story_autosave_path, FileAccess.READ)
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
		"season_phase": String(payload.get("season_phase", "summer_1")),
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
		"player_profile": payload.get("player_profile", PLAYER_APPEARANCE_CATALOG_SCRIPT.default_profile()),
		"equipped_player_costume_id": String(payload.get("equipped_player_costume_id", PLAYER_COSTUME_CATALOG_SCRIPT.default_costume_id())),
		"ending_summary": payload.get("ending_summary", ending_summary),
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
		"chapter": String(payload.get("chapter", STORY_ROUTE_GRAPH_SCRIPT.phase_display_name(String(payload.get("season_phase", "summer_1"))))),
		"location": String(payload.get("location", resume_location)),
		"fragments_text": fragments_text,
		"resume_anchor_id": String(payload.get("story_resume_anchor_id", "")),
		"resume_location": resume_location,
		"saved_at_unix": int(payload.get("saved_at_unix", 0)),
	}


func _normalize_saved_resident_profiles(saved_profiles: Dictionary) -> Dictionary:
	var normalized := _default_resident_profiles()

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
	var normalized := _default_landmark_progress()

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
	var normalized := ending_summary.duplicate(true)
	if saved_summary is Dictionary:
		normalized.merge(saved_summary, true)
	if String(normalized.get("collectibles", "")) == "prototype":
		normalized["collectibles"] = "Not tracked in this build"
	return normalized


func _apply_story_autosave_payload(payload: Dictionary) -> bool:
	if payload.is_empty():
		return false

	story_resume_anchor_id = String(payload.get("story_resume_anchor_id", "Piano Ferry"))
	if story_resume_anchor_id.is_empty():
		story_resume_anchor_id = "Piano Ferry"
	story_resume_location = String(payload.get("story_resume_location", payload.get("location", "Piano Ferry")))
	if story_resume_location.is_empty():
		story_resume_location = "Piano Ferry"

	set_mode(String(payload.get("mode", "Story")))
	_apply_story_route_state_bundle(payload)
	set_location(String(payload.get("location", story_resume_location)))
	set_objective(String(payload.get("objective", objective)))
	set_journal_unlocked(bool(payload.get("journal_unlocked", true)))
	set_hint(build_input_hint("R Inspect"))
	set_landmarks(_default_landmarks())
	set_open_shortcuts(payload.get("open_shortcuts", []))
	set_resident_profiles(_normalize_saved_resident_profiles(payload.get("resident_profiles", {})))
	set_melody_progress(payload.get("melody_progress", {}))
	set_all_landmark_progress(_normalize_saved_landmark_progress(payload.get("landmark_progress", {})))
	set_summary(_normalize_saved_summary(payload.get("ending_summary", {})))
	set_player_profile(payload.get("player_profile", PLAYER_APPEARANCE_CATALOG_SCRIPT.default_profile()))
	refresh_story_routes()

	var saved_costume_id := String(
		payload.get("equipped_player_costume_id", PLAYER_COSTUME_CATALOG_SCRIPT.default_costume_id())
	)
	if !equip_player_costume(saved_costume_id):
		equip_player_costume(PLAYER_COSTUME_CATALOG_SCRIPT.default_costume_id())

	_update_summary_counts()
	refresh_story_autosave_metadata()
	return true


func _autosave_story_progress() -> void:
	if _is_story_persistable_mode():
		save_story_autosave()


func interact_with_resident(resident_id: String) -> Dictionary:
	_ensure_resident_profiles()
	if !resident_profiles.has(resident_id):
		return {}

	var resident: Dictionary = resident_profiles[resident_id].duplicate(true)
	var dialogue_beats: Array = resident.get("dialogue_beats", [])
	var resident_was_known := bool(resident.get("known", false))

	resident["known"] = true

	# --- Conditional beats: check priority-sorted context-sensitive lines first.
	var conditional_beat := _pick_conditional_beat(resident_id, resident)
	if !conditional_beat.is_empty():
		var fired: Array = _normalize_string_array(resident.get("_fired_conditional_beats", []))
		var beat_key := String(conditional_beat.get("_beat_key", ""))
		var is_new_conditional := !beat_key.is_empty() and fired.find(beat_key) < 0
		if is_new_conditional:
			fired.append(beat_key)
			resident["_fired_conditional_beats"] = fired

		var old_cond_trust := int(resident.get("trust", 0))
		resident["trust"] = clampi(
			old_cond_trust + int(conditional_beat.get("trust_delta", 0)),
			0,
			RESIDENT_CATALOG_SCRIPT.max_trust()
		)
		var cond_journal := String(conditional_beat.get("journal_step", ""))
		if !cond_journal.is_empty():
			resident["current_step"] = cond_journal

		resident_profiles[resident_id] = resident
		_sync_known_residents()
		# Only fire side-effects on the first application of this conditional
		# beat, matching the is_new_beat guard used by the linear spine.
		if is_new_conditional:
			_apply_resident_beat(conditional_beat)
			_emit_trust_milestone_if_max(resident_id, old_cond_trust, int(resident.get("trust", 0)))
			_autosave_story_progress()
		elif !resident_was_known:
			_autosave_story_progress()
		_refresh_player_costumes()
		resident_profile_changed.emit(resident_id, get_resident_profile(resident_id))
		# Strip the internal tracking key before returning to callers.
		var result := conditional_beat.duplicate(true)
		result.erase("_beat_key")
		return result

	# --- Linear beat spine: fall back to conversation_index progression.
	if dialogue_beats.is_empty():
		resident_profiles[resident_id] = resident
		_sync_known_residents()
		if !resident_was_known:
			_autosave_story_progress()
		_refresh_player_costumes()
		resident_profile_changed.emit(resident_id, get_resident_profile(resident_id))
		return {}

	var beat_index := clampi(
		int(resident.get("conversation_index", 0)),
		0,
		dialogue_beats.size() - 1
	)
	var beat: Dictionary = dialogue_beats[beat_index]

	# If the beat has a gate condition that is not yet satisfied, return a
	# fallback line without advancing the conversation or applying effects.
	if !_check_beat_gate(beat):
		resident_profiles[resident_id] = resident  # persist known = true
		_sync_known_residents()
		if !resident_was_known:
			_autosave_story_progress()
		_refresh_player_costumes()
		resident_profile_changed.emit(resident_id, get_resident_profile(resident_id))
		var fallback := String(beat.get("gate_fallback", ""))
		return {"line": fallback}

	# Track whether this is a new beat vs. a repeat of the last beat.
	var is_new_beat := beat_index < dialogue_beats.size() - 1 \
		or int(resident.get("_last_applied_beat", -1)) != beat_index

	var old_trust := int(resident.get("trust", 0))
	resident["trust"] = clampi(
		old_trust + int(beat.get("trust_delta", 0)),
		0,
		RESIDENT_CATALOG_SCRIPT.max_trust()
	)
	resident["quest_state"] = String(beat.get("quest_state", resident.get("quest_state", "available")))
	resident["current_step"] = String(beat.get("journal_step", beat.get("objective", "Stay in touch.")))

	if beat_index < dialogue_beats.size() - 1:
		resident["conversation_index"] = beat_index + 1

	# Remember which beat was last applied so we don't re-fire side effects.
	resident["_last_applied_beat"] = beat_index

	resident_profiles[resident_id] = resident
	_sync_known_residents()
	# Only fire side-effects (landmark rewards, unlocks, state changes) on first
	# application of a beat. Repeat interactions with the same final beat return
	# the dialogue line but skip _apply_resident_beat to prevent duplicate awards.
	if is_new_beat:
		_apply_resident_beat(beat)
		_autosave_story_progress()
	elif !resident_was_known:
		_autosave_story_progress()
	_emit_trust_milestone_if_max(resident_id, old_trust, int(resident.get("trust", 0)))
	_refresh_player_costumes()
	resident_profile_changed.emit(resident_id, get_resident_profile(resident_id))
	return beat.duplicate(true)


func configure_new_game() -> void:
	var story_state: Dictionary = m_story_route_graph.build_story_state("new_game") if m_story_route_graph != null else {}
	set_mode("Story")
	_apply_story_route_state_bundle(story_state)
	set_location("Piano Ferry")
	set_objective("Find out why the island feels quiet today.")
	set_journal_unlocked(false)
	set_hint(build_input_hint("R Inspect"))
	set_save_status("Autosave: story start saved")
	set_landmarks(_default_landmarks())
	set_open_shortcuts(PackedStringArray())
	set_resident_profiles(_default_resident_profiles())
	set_melody_progress(_build_story_melody_progress("new_game"))
	set_all_landmark_progress(_build_landmark_progress("new_game"))
	refresh_story_routes()
	story_resume_anchor_id = "Piano Ferry"
	story_resume_location = "Piano Ferry"
	set_summary({
		"fragments": "0 / 4",
		"residents": "0",
		"collectibles": "Not tracked in this build",
		"playtime": "a brief evening on Kulangsu",
	})
	save_story_autosave()


func configure_continue() -> bool:
	if !load_story_autosave():
		set_save_status("Continue is unavailable until a story autosave exists.")
		return false

	set_hint(build_input_hint("R Inspect"))
	var resume_label := story_resume_location
	if resume_label.is_empty():
		resume_label = location
	set_save_status("Autosave: resumed at %s" % resume_label)
	return true


func configure_free_walk() -> void:
	var story_state: Dictionary = m_story_route_graph.build_story_state("free_walk") if m_story_route_graph != null else {}
	set_mode("Free Walk")
	_apply_story_route_state_bundle(story_state)
	set_chapter("Free Walk")
	set_location("Piano Ferry")
	set_objective("Wander the island and learn how the first district wants to be introduced.")
	set_journal_unlocked(true)
	set_hint(build_input_hint("R Inspect"))
	set_save_status("Free Walk: sandbox ready")
	set_landmarks(_default_landmarks())
	set_open_shortcuts(PackedStringArray())
	set_resident_profiles(_default_resident_profiles())
	set_melody_progress(_build_story_melody_progress("free_walk"))
	set_all_landmark_progress(_build_landmark_progress("free_walk"))
	for resident_id in RESIDENT_CATALOG_SCRIPT.resident_order():
		_seed_resident_progress(resident_id, 1, 1, "introduced", "Sandbox resident notes are available in free walk.")
	_update_summary_counts()


func configure_postgame() -> void:
	set_mode("Postgame")
	set_season_phase("postgame")
	set_location("Ferry Plaza")
	set_objective("Wander the island after the ending and listen for what changed.")
	set_journal_unlocked(true)
	set_hint(build_input_hint("R Inspect"))
	set_save_status("Postgame checkpoint saved — the island now carries the story you chose to stay with.")
	if bool(get_melody_state("festival_melody").get("performed", false)):
		var melody_state := get_melody_state("festival_melody")
		melody_state["state"] = "resonant"
		melody_state["next_lead"] = "Wander the island and listen to what the restored melody leaves behind."
		set_melody_progress({"festival_melody": melody_state})
		if get_landmark_state("festival_stage") != "reward_collected":
			advance_landmark_state("festival_stage", "reward_collected")
	_manual_pinned_lead_id = ""
	endgame_state = STORY_ROUTE_GRAPH_SCRIPT.default_endgame_state()
	endgame_state_changed.emit(endgame_state.duplicate(true))
	refresh_story_routes()
	story_resume_anchor_id = "Piano Ferry"
	story_resume_location = "Ferry Plaza"
	_update_summary_counts()
	save_story_autosave()


func _apply_resident_beat(beat: Dictionary) -> void:
	var new_objective := String(beat.get("objective", ""))
	if !new_objective.is_empty():
		set_objective(new_objective)

	var new_hint := String(beat.get("hint", ""))
	if !new_hint.is_empty():
		set_hint(new_hint)

	var new_phase := String(beat.get("season_phase", ""))
	if !new_phase.is_empty():
		set_season_phase(new_phase)

	var new_chapter := String(beat.get("chapter", ""))
	if !new_chapter.is_empty() and mode not in ["Story", "Postgame"]:
		set_chapter(new_chapter)

	var new_status := String(beat.get("save_status", ""))
	if !new_status.is_empty():
		set_save_status(new_status)

	_update_summary_counts()

	# Unlock a landmark if this beat triggers one.
	var unlock_landmark := String(beat.get("unlock_landmark", ""))
	if !unlock_landmark.is_empty():
		advance_landmark_state(unlock_landmark, "available")

	# Apply a set of landmark state overrides if this beat carries them.
	var landmark_states = beat.get("landmark_states", {})
	if landmark_states is Dictionary:
		for lm_id in landmark_states.keys():
			advance_landmark_state(String(lm_id), String(landmark_states[lm_id]))

	# Apply a landmark reward if this beat resolves one.
	var landmark_reward := String(beat.get("landmark_reward", ""))
	if !landmark_reward.is_empty():
		_resolve_landmark(landmark_reward)

	var beat_story_flags = beat.get("story_flags", {})
	if beat_story_flags is Dictionary:
		for flag_id in beat_story_flags.keys():
			set_story_flag(String(flag_id), beat_story_flags[flag_id])

	var story_event := String(beat.get("story_event", ""))
	if !story_event.is_empty():
		resolve_story_event(story_event)

	var pin_lead_id := String(beat.get("pin_lead_id", ""))
	if !pin_lead_id.is_empty():
		pin_story_lead(pin_lead_id)

	refresh_story_routes()


func _sync_known_residents() -> void:
	set_residents(get_known_resident_names())
	_update_summary_counts()


func _seed_resident_progress(
	resident_id: String,
	conversation_index: int,
	trust: int,
	quest_state: String,
	current_step: String
) -> void:
	if !resident_profiles.has(resident_id):
		return

	var resident: Dictionary = resident_profiles[resident_id].duplicate(true)
	var dialogue_beats: Array = resident.get("dialogue_beats", [])

	resident["known"] = true
	resident["trust"] = clampi(trust, 0, RESIDENT_CATALOG_SCRIPT.max_trust())
	resident["quest_state"] = quest_state
	resident["current_step"] = current_step

	if dialogue_beats.is_empty():
		resident["conversation_index"] = 0
	else:
		resident["conversation_index"] = clampi(conversation_index, 0, dialogue_beats.size() - 1)

	resident_profiles[resident_id] = resident
	_sync_known_residents()
	_refresh_player_costumes()
	resident_profile_changed.emit(resident_id, get_resident_profile(resident_id))


func _count_helped_residents() -> int:
	_ensure_resident_profiles()
	var count := 0
	for resident_id in RESIDENT_CATALOG_SCRIPT.resident_order():
		var resident: Dictionary = resident_profiles.get(resident_id, {})
		if int(resident.get("trust", 0)) > 0:
			count += 1
	return count


func _update_summary_counts() -> void:
	var summary := ending_summary.duplicate(true)
	summary["fragments"] = "%d / %d" % [fragments_found, fragments_total]
	summary["residents"] = str(_count_helped_residents())
	summary["season"] = get_season_phase_display_name()
	if m_story_route_graph != null:
		summary["routes"] = m_story_route_graph.build_route_completion_summary()
	var ending_trigger := String(endgame_state.get("trigger_event_id", ""))
	if ending_trigger.is_empty() and mode == "Postgame":
		ending_trigger = String(summary.get("ending_trigger", ""))
	summary["ending_trigger"] = ending_trigger
	var ending_tone_tags := PackedStringArray(_normalize_string_array(endgame_state.get("ending_tone_tags", [])))
	if ending_tone_tags.is_empty() and mode == "Postgame":
		summary["ending_tones"] = String(summary.get("ending_tones", ""))
	else:
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
		"postgame":
			return {
				"festival_melody": {
					"state": "resonant",
					"fragments_found": 4,
					"known_sources": ["ferry_plaza", "church_bells", "bi_shan_echo", "long_shan_route", "tower_chamber"],
					"next_lead": "Listen to how the island answers now that the festival melody has returned.",
					"performed": true,
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
		"postgame":
			return {
				"piano_ferry": {"state": "reward_collected", "harbor_clue_found": true},
				"trinity_church": {"state": "reward_collected", "cues_collected": ["steps", "garden", "yard"], "chime_performed": true},
				"bi_shan_tunnel": {"state": "reward_collected", "echoes_collected": ["echo_a", "echo_b", "echo_c"]},
				"long_shan_tunnel": {"state": "reward_collected", "checkpoints_collected": ["light_pocket_south", "light_pocket_north"]},
				"bagua_tower": {"state": "reward_collected", "synthesis_done": true},
				"festival_stage": {"state": "reward_collected"},
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


func _progress_has_string_entry(progress: Dictionary, progress_key: String, entry_id: String) -> bool:
	return _normalize_string_array(progress.get(progress_key, [])).find(entry_id) >= 0


func _request_melody_prompt(
	melody_id: String,
	prompt_mode: String,
	completion_kind: String = "",
	request_overrides: Dictionary = {}
) -> void:
	m_landmark_progression.request_melody_prompt(
		melody_id,
		prompt_mode,
		completion_kind,
		request_overrides
	)


func _request_trinity_chime_prompt() -> void:
	m_landmark_progression.request_trinity_chime_prompt()


func _request_bi_shan_chamber_prompt() -> void:
	m_landmark_progression.request_bi_shan_chamber_prompt()


func _request_long_shan_route_prompt() -> void:
	m_landmark_progression.request_long_shan_route_prompt()


func _build_melody_prompt_segments(melody_id: String) -> Array[Dictionary]:
	return m_landmark_progression.build_melody_prompt_segments(melody_id)


func _collect_piano_ferry_harbor_clue() -> void:
	var progress := get_landmark_progress("piano_ferry")
	if progress.is_empty():
		return

	progress["harbor_clue_found"] = true
	progress["state"] = "resolved"
	set_landmark_progress("piano_ferry", progress)


## Collect one Trinity Church choir cue. Returns true when all three are in.
## Advances the landmark to in_progress once at least one cue is collected.
func _collect_trinity_church_cue(cue_id: String) -> bool:
	var progress := get_landmark_progress("trinity_church")
	if progress.is_empty():
		return false

	var cues: Array[String] = []
	for entry in progress.get("cues_collected", []):
		cues.append(String(entry))

	if cues.find(cue_id) >= 0:
		return cues.size() >= 3  # already collected this one

	cues.append(cue_id)
	progress["cues_collected"] = cues

	var current_state := String(progress.get("state", "locked"))
	if current_state == "available" or current_state == "introduced":
		progress["state"] = "in_progress"

	set_landmark_progress("trinity_church", progress)
	return cues.size() >= 3


func _complete_trinity_church_chime() -> void:
	m_landmark_progression.complete_trinity_church_chime()


func _complete_bi_shan_chamber() -> void:
	m_landmark_progression.complete_bi_shan_chamber()


## Collect one Bi Shan Tunnel echo marker. Returns true when all three are in.
## Advances the landmark to in_progress on first echo collected.
func _collect_bi_shan_echo(echo_id: String) -> bool:
	var progress := get_landmark_progress("bi_shan_tunnel")
	if progress.is_empty():
		return false

	var echoes: Array[String] = []
	for entry in progress.get("echoes_collected", []):
		echoes.append(String(entry))

	if echoes.find(echo_id) >= 0:
		return echoes.size() >= 3  # already collected this one

	echoes.append(echo_id)
	progress["echoes_collected"] = echoes

	var current_state := String(progress.get("state", "locked"))
	if current_state == "available" or current_state == "introduced":
		progress["state"] = "in_progress"

	set_landmark_progress("bi_shan_tunnel", progress)
	return echoes.size() >= 3


## Collect one Long Shan lit-pocket checkpoint. Returns true when both route
## checkpoints have been reached and the exit can open the route-settling prompt.
func _collect_long_shan_checkpoint(checkpoint_id: String) -> bool:
	var progress := get_landmark_progress("long_shan_tunnel")
	if progress.is_empty():
		return false

	var checkpoints: Array[String] = []
	for entry in progress.get("checkpoints_collected", []):
		checkpoints.append(String(entry))

	if checkpoints.find(checkpoint_id) >= 0:
		return checkpoints.size() >= 2

	checkpoints.append(checkpoint_id)
	progress["checkpoints_collected"] = checkpoints
	set_landmark_progress("long_shan_tunnel", progress)
	return checkpoints.size() >= 2


func _complete_long_shan_route() -> void:
	m_landmark_progression.complete_long_shan_route()


## Award the Bi Shan Tunnel melody fragment and advance melody state.
## Called when the player settles the mural chamber prompt after tracing all echoes.
func _resolve_bi_shan_tunnel() -> void:
	m_landmark_progression.resolve_bi_shan_tunnel()


## Award the Long Shan Tunnel melody fragment and advance melody state.
## Called when the player settles the exit-route prompt after both lit pockets.
func _resolve_long_shan_tunnel() -> void:
	m_landmark_progression.resolve_long_shan_tunnel()


## Called when the synthesis chamber trigger fires at the top of Bagua Tower.
## Marks synthesis as done, which gates tower_keeper's final resolved beat.
func _resolve_bagua_tower_synthesis() -> void:
	m_landmark_progression.resolve_bagua_tower_synthesis()


## Award the final Bagua Tower melody fragment and complete the island melody.
## Called when tower_keeper's final dialogue beat fires with "landmark_reward": "bagua_tower".
func _resolve_bagua_tower() -> void:
	m_landmark_progression.resolve_bagua_tower()


## Gate check: returns false if a beat's prerequisite condition is not met.
## The conversation does not advance and a fallback line is shown instead.
func _check_beat_gate(beat: Dictionary) -> bool:
	var gate := String(beat.get("gate", ""))
	if gate.is_empty():
		return true
	match gate:
		"piano_ferry_harbor_clue":
			var ferry_progress := get_landmark_progress("piano_ferry")
			return bool(ferry_progress.get("harbor_clue_found", false))
		"first_fragment_restored":
			return fragments_found >= 1
		"trinity_church_cues":
			var progress := get_landmark_progress("trinity_church")
			var cues: Array = progress.get("cues_collected", [])
			return cues.size() >= 3
		"trinity_church_chime":
			var progress := get_landmark_progress("trinity_church")
			return bool(progress.get("chime_performed", false))
		"long_shan_exit_reached":
			return get_landmark_state("long_shan_tunnel") == "reward_collected"
		"bagua_synthesis_done":
			var progress := get_landmark_progress("bagua_tower")
			return bool(progress.get("synthesis_done", false))
		"bagua_tower_available":
			return get_landmark_state("bagua_tower") != "locked"
		"three_fragments_restored":
			return fragments_found >= 3
		_:
			if story_flags.has(gate):
				return bool(story_flags.get(gate, false))
	return true


# ---------------------------------------------------------------------------
# Conditional Beat Evaluation
# ---------------------------------------------------------------------------

## Pick the highest-priority conditional beat whose conditions are all satisfied
## and that has not already fired (if marked once). Returns an empty Dictionary
## when no conditional beat matches, signalling the caller to fall through to
## the linear dialogue_beats spine.
func _pick_conditional_beat(resident_id: String, resident: Dictionary) -> Dictionary:
	var conditional_beats: Array = resident.get("conditional_beats", [])
	if conditional_beats.is_empty():
		return {}

	var fired: Array[String] = _normalize_string_array(resident.get("_fired_conditional_beats", []))

	var best_beat: Dictionary = {}
	var best_priority := -1

	for i in conditional_beats.size():
		var cbeat: Dictionary = conditional_beats[i]

		# Build a stable key from the array index for once-tracking.
		var beat_key := "cond_%d" % i
		cbeat["_beat_key"] = beat_key

		if bool(cbeat.get("once", false)) and fired.find(beat_key) >= 0:
			continue

		var conditions: Dictionary = cbeat.get("conditions", {})
		if !_check_conditional_conditions(conditions, resident):
			continue

		var priority := int(cbeat.get("priority", 0))
		if priority > best_priority:
			best_priority = priority
			best_beat = cbeat

	return best_beat


## Evaluate all condition keys in a conditional beat's conditions dictionary.
## Returns true only when every condition is satisfied.
func _check_conditional_conditions(conditions: Dictionary, resident: Dictionary) -> bool:
	for key in conditions.keys():
		match key:
			"landmark_state":
				var required: Dictionary = conditions[key]
				for lm_id in required.keys():
					if get_landmark_state(String(lm_id)) != String(required[lm_id]):
						return false
			"melody_state":
				var required: Dictionary = conditions[key]
				for mel_id in required.keys():
					var mel := get_melody_state(String(mel_id))
					if String(mel.get("state", "unknown")) != String(required[mel_id]):
						return false
			"fragments_found_min":
				if fragments_found < int(conditions[key]):
					return false
			"trust_min":
				if int(resident.get("trust", 0)) < int(conditions[key]):
					return false
			"chapter":
				if chapter != String(conditions[key]):
					return false
			"season_phase":
				var expected_phase: Variant = conditions[key]
				if expected_phase is Array or expected_phase is PackedStringArray:
					var allowed_phases := _normalize_string_array(expected_phase)
					if allowed_phases.find(season_phase) < 0:
						return false
				elif season_phase != String(expected_phase):
					return false
			"mode":
				if mode != String(conditions[key]):
					return false
			"resident_known":
				var required_known: Array = conditions[key] if conditions[key] is Array else []
				for rid in required_known:
					var other: Dictionary = resident_profiles.get(String(rid), {})
					if !bool(other.get("known", false)):
						return false
			"story_flag_all":
				for flag_id_value in conditions[key]:
					if !bool(get_story_flag(String(flag_id_value), false)):
						return false
			"story_flag_any":
				var any_found := false
				for flag_id_value in conditions[key]:
					if bool(get_story_flag(String(flag_id_value), false)):
						any_found = true
						break
				if !any_found:
					return false
			"route_state":
				var required_routes: Dictionary = conditions[key]
				for route_id in required_routes.keys():
					if String(get_route_progress(String(route_id)).get("state", "idle")) != String(required_routes[route_id]):
						return false
			"route_score_min":
				var minimum_scores: Dictionary = conditions[key]
				for route_id in minimum_scores.keys():
					if int(get_route_progress(String(route_id)).get("completion_score", 0)) < int(minimum_scores[route_id]):
						return false
			"endgame_active":
				if bool(endgame_state.get("active", false)) != bool(conditions[key]):
					return false
	return true


## Emit a resident_trust_max milestone the first time a resident reaches max trust.
func _emit_trust_milestone_if_max(resident_id: String, old_trust: int, new_trust: int) -> void:
	if new_trust >= RESIDENT_CATALOG_SCRIPT.max_trust() and old_trust < RESIDENT_CATALOG_SCRIPT.max_trust():
		_emit_story_milestone("resident_trust_max", {"resident_id": resident_id})


func _emit_story_milestone(milestone_id: String, context: Dictionary = {}) -> void:
	story_milestone.emit(milestone_id, context.duplicate(true))


## Dispatch to the correct landmark resolution handler and emit a story
## milestone so ambient systems can react without coupling to internals.
func _resolve_landmark(landmark_id: String) -> void:
	m_landmark_progression.resolve_landmark(landmark_id)


func _resolve_piano_ferry() -> void:
	m_landmark_progression.resolve_piano_ferry()


## Award the Trinity Church melody fragment, update melody state, and unlock
## the tunnel landmarks. Called automatically when the church_caretaker's
## resolved dialogue beat fires with "landmark_reward": "trinity_church".
func _resolve_trinity_church() -> void:
	m_landmark_progression.resolve_trinity_church()


func _award_festival_source_once(source_id: String, counts_as_fragment: bool = true) -> Dictionary:
	return m_landmark_progression.award_festival_source_once(source_id, counts_as_fragment)


func _emit_fragment_story_milestones(
	previous_melody: Dictionary,
	source_id: String,
	melody_state: Dictionary,
	counts_as_fragment: bool = true
) -> void:
	m_landmark_progression.emit_fragment_story_milestones(
		previous_melody,
		source_id,
		melody_state,
		counts_as_fragment
	)


func _sync_festival_state_from_fragments(melody_state: Dictionary) -> void:
	m_landmark_progression.sync_festival_state_from_fragments(melody_state)


func _perform_festival_melody() -> void:
	m_landmark_progression.perform_festival_melody()
