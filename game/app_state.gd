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
const STORY_AUTOSAVE_VERSION := 1
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
signal save_metadata_changed(metadata: Dictionary)

var mode := "Title"
var chapter := "Arrival"
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


func _enter_tree() -> void:
	add_to_group(APP_STATE_GROUP)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
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
	_story_autosave_path = path.strip_edges()
	if _story_autosave_path.is_empty():
		_story_autosave_path = STORY_AUTOSAVE_PATH
	refresh_story_autosave_metadata()


func clear_story_autosave() -> void:
	if FileAccess.file_exists(_story_autosave_path):
		DirAccess.remove_absolute(_story_autosave_path)
	refresh_story_autosave_metadata()


func clear_story_autosave_for_tests() -> void:
	clear_story_autosave()


func refresh_story_autosave_metadata() -> void:
	var next_metadata := _default_story_save_metadata()
	var payload := _read_story_autosave_payload()
	if !payload.is_empty():
		next_metadata = _build_story_save_metadata_from_payload(payload)

	story_save_metadata = next_metadata
	save_metadata_changed.emit(get_story_save_metadata())


func save_story_autosave(status_text: String = "") -> bool:
	if !_is_story_persistable_mode():
		return false

	var file := FileAccess.open(_story_autosave_path, FileAccess.WRITE)
	if file == null:
		if !status_text.is_empty():
			set_save_status(status_text)
		return false

	file.store_var(_build_story_autosave_payload(), false)
	file.flush()
	refresh_story_autosave_metadata()

	if !status_text.is_empty():
		set_save_status(status_text)

	return true


func load_story_autosave() -> bool:
	var payload := _read_story_autosave_payload()
	if payload.is_empty():
		return false

	return _apply_story_autosave_payload(payload)


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
	summary_changed.emit(ending_summary)


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

	return _build_melody_prompt_segments(melody_id).size() >= 2


func can_perform_melody(melody_id: String) -> bool:
	if melody_id == "festival_melody":
		if get_landmark_state("festival_stage") != "available":
			return false
		return can_practice_melody(melody_id)
	return false


func request_melody_practice(melody_id: String) -> void:
	_request_melody_prompt(melody_id, "practice")


func complete_prompt_request(request: Dictionary) -> void:
	var completion_kind := String(request.get("completion_kind", ""))
	var melody_id := String(request.get("melody_id", ""))

	match completion_kind:
		"melody_practice":
			complete_melody_practice(melody_id)
		"festival_performance":
			complete_melody_performance(melody_id)
		"trinity_chime":
			_complete_trinity_church_chime()
		"bi_shan_chamber":
			_complete_bi_shan_chamber()
		"long_shan_route":
			_complete_long_shan_route()
		_:
			set_save_status("The phrase settles, but nothing answers it yet.")


func complete_melody_practice(melody_id: String) -> void:
	var melody_definition := get_melody_definition(melody_id)
	if melody_definition.is_empty():
		set_save_status("The phrase slips away before you can practice it.")
		return

	set_save_status("%s feels steadier after a short rehearsal." % String(melody_definition.get("display_name", "The melody")))


func complete_melody_performance(melody_id: String) -> void:
	var melody_state := get_melody_state(melody_id)
	if melody_state.is_empty():
		set_save_status("The performance point is not ready yet.")
		return

	if bool(melody_state.get("performed", false)):
		set_save_status("The harbor already remembers this melody.")
		return

	if !can_perform_melody(melody_id):
		set_save_status("The phrase is not ready to carry across the harbor yet.")
		return

	match melody_id:
		"festival_melody":
			_perform_festival_melody()
		_:
			set_save_status("This performance point is not wired yet.")


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
	return player_profile.duplicate(true)


func get_player_body_display_name() -> String:
	return PLAYER_APPEARANCE_CATALOG_SCRIPT.body_frame_display_name(
		String(player_profile.get("body_frame_id", "adult"))
	)


func get_player_gender_display_name() -> String:
	return PLAYER_APPEARANCE_CATALOG_SCRIPT.presentation_display_name(
		String(player_profile.get("presentation_id", "masculine"))
	)


func get_player_skin_display_name() -> String:
	return PLAYER_APPEARANCE_CATALOG_SCRIPT.skin_tone_display_name(
		String(player_profile.get("skin_tone_id", "light"))
	)


func get_player_hair_style_display_name() -> String:
	return PLAYER_APPEARANCE_CATALOG_SCRIPT.hair_style_display_name(
		String(player_profile.get("hair_style_id", "short_bangs"))
	)


func get_player_hair_color_display_name() -> String:
	return PLAYER_APPEARANCE_CATALOG_SCRIPT.hair_color_display_name(
		String(player_profile.get("hair_color_id", "chestnut"))
	)


func get_player_costume_ids() -> PackedStringArray:
	return PLAYER_COSTUME_CATALOG_SCRIPT.ordered_ids()


func get_player_costume(costume_id: String) -> Dictionary:
	if !player_costume_catalog.has(costume_id):
		return {}
	return player_costume_catalog[costume_id].duplicate(true)


func get_unlocked_player_costume_ids() -> PackedStringArray:
	return PackedStringArray(unlocked_player_costume_ids)


func get_equipped_player_costume_id() -> String:
	return equipped_player_costume_id


func get_equipped_player_costume() -> Dictionary:
	return get_player_costume(equipped_player_costume_id)


func get_equipped_player_costume_display_name() -> String:
	return String(get_equipped_player_costume().get("display_name", "Harbor Arrival"))


func set_player_profile(new_profile: Dictionary) -> bool:
	var normalized_profile := PLAYER_APPEARANCE_CATALOG_SCRIPT.normalize_profile(new_profile)
	if player_profile == normalized_profile:
		return false

	player_profile = normalized_profile
	player_profile_changed.emit(get_player_profile())
	_emit_player_appearance_changed()
	return true


func cycle_player_body_frame(direction: int) -> void:
	_cycle_player_profile_option(
		"body_frame_id",
		PLAYER_APPEARANCE_CATALOG_SCRIPT.body_frame_options(),
		direction
	)


func cycle_player_gender(direction: int) -> void:
	_cycle_player_profile_option(
		"presentation_id",
		PLAYER_APPEARANCE_CATALOG_SCRIPT.presentation_options(),
		direction
	)


func cycle_player_skin_tone(direction: int) -> void:
	_cycle_player_profile_option(
		"skin_tone_id",
		PLAYER_APPEARANCE_CATALOG_SCRIPT.skin_tone_options(),
		direction
	)


func cycle_player_hair_style(direction: int) -> void:
	_cycle_player_profile_option(
		"hair_style_id",
		PLAYER_APPEARANCE_CATALOG_SCRIPT.hair_style_options(),
		direction
	)


func cycle_player_hair_color(direction: int) -> void:
	_cycle_player_profile_option(
		"hair_color_id",
		PLAYER_APPEARANCE_CATALOG_SCRIPT.hair_color_options(),
		direction
	)


func get_player_appearance_config() -> Dictionary:
	var costume: Dictionary = get_equipped_player_costume()
	var costume_selections: Dictionary = costume.get("selections", {})
	return PLAYER_APPEARANCE_CATALOG_SCRIPT.build_appearance_config(player_profile, costume_selections)


func equip_player_costume(costume_id: String) -> bool:
	if !player_costume_catalog.has(costume_id):
		return false
	if unlocked_player_costume_ids.find(costume_id) < 0:
		return false
	if equipped_player_costume_id == costume_id:
		return true

	equipped_player_costume_id = costume_id
	player_costume_changed.emit(equipped_player_costume_id, get_equipped_player_costume())
	_emit_player_appearance_changed()
	player_costumes_changed.emit(get_unlocked_player_costume_ids(), equipped_player_costume_id)
	return true


func cycle_player_costume(direction: int) -> void:
	if unlocked_player_costume_ids.is_empty():
		return

	var current_index := unlocked_player_costume_ids.find(equipped_player_costume_id)
	if current_index < 0:
		equip_player_costume(String(unlocked_player_costume_ids[0]))
		return

	var next_index := posmod(current_index + direction, unlocked_player_costume_ids.size())
	equip_player_costume(String(unlocked_player_costume_ids[next_index]))


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
	var landmark_text := "None marked yet."
	if !landmarks.is_empty():
		landmark_text = "\n".join(landmarks)

	var shortcut_text := "No dependable routes noted yet."
	if !open_shortcuts.is_empty():
		var shortcut_sections: Array[String] = []
		for shortcut_id in open_shortcuts:
			var shortcut_definition: Dictionary = SHORTCUT_DEFINITIONS.get(String(shortcut_id), {})
			shortcut_sections.append(
				"%s\n%s" % [
					String(shortcut_definition.get("display_name", shortcut_id)),
					String(shortcut_definition.get("summary", "")),
				]
			)
		shortcut_text = "\n\n".join(PackedStringArray(shortcut_sections))

	return "Discovered landmarks\n%s\n\nCurrent location\n%s\n\nDependable routes\n%s" % [
		landmark_text,
		location,
		shortcut_text,
	]


func build_resident_journal_text() -> String:
	_ensure_resident_profiles()
	var sections: Array[String] = []

	for resident_id in RESIDENT_CATALOG_SCRIPT.resident_order():
		var resident: Dictionary = resident_profiles.get(resident_id, {})
		if !resident.get("known", false):
			continue

		sections.append(
			"%s\n%s\nUsually found: %s\nTrust: %d / %d\nCurrent lead: %s\nMelody clue: %s" % [
				String(resident.get("display_name", resident_id)),
				String(resident.get("role", "")),
				String(resident.get("routine_note", "")),
				int(resident.get("trust", 0)),
				RESIDENT_CATALOG_SCRIPT.max_trust(),
				String(resident.get("current_step", "Stay in touch.")),
				String(resident.get("melody_hint", "")),
			]
		)

	if sections.is_empty():
		return "No residents introduced yet.\n\nListen for a nearby greeting or use R when a talk prompt appears."

	return "\n\n".join(PackedStringArray(sections))


func build_melody_journal_text() -> String:
	var sections: Array[String] = []

	for melody_id in get_melody_ids():
		var melody_definition := get_melody_definition(melody_id)
		if melody_definition.is_empty():
			continue

		var melody_state := get_melody_state(melody_id)
		var known_sources := _normalize_string_array(melody_state.get("known_sources", []))
		var source_lines: Array[String] = []

		for source in melody_definition.get("sources", []):
			var source_id := String(source.get("source_id", ""))
			var source_status := "Not yet confirmed"
			if known_sources.find(source_id) >= 0:
				source_status = "Confirmed clue"

			source_lines.append(
				"%s (%s)\n%s\n%s" % [
					String(source.get("label", "Unknown clue")),
					String(source.get("landmark", "Unknown landmark")),
					source_status,
					String(source.get("summary", "")),
				]
			)

		sections.append(
			"%s\nDistrict: %s\nStage: %s\nRecovered fragments: %d / %d\nSummary: %s\nNext lead: %s\nPerformance point: %s\nWorld response: %s\n\nClue map\n%s" % [
				String(melody_definition.get("display_name", melody_id)),
				String(melody_definition.get("district", "Unknown district")),
				MELODY_CATALOG_SCRIPT.state_display_name(String(melody_state.get("state", "unknown"))),
				int(melody_state.get("fragments_found", 0)),
				int(melody_state.get("fragments_total", int(melody_definition.get("fragment_total", 0)))),
				String(melody_definition.get("summary", "")),
				String(melody_state.get("next_lead", melody_definition.get("unlock_condition", ""))),
				String(melody_definition.get("performance_landmark", "Unknown")),
				String(melody_definition.get("world_response_summary", "")),
				"\n\n".join(PackedStringArray(source_lines)),
			]
		)

	if sections.is_empty():
		return "No melody notes recorded yet.\n\nKeep exploring, listen for a repeated phrase, and check the journal after each major clue."

	return "\n\n".join(PackedStringArray(sections))


func build_player_costume_journal_text() -> String:
	var sections: Array[String] = []

	sections.append(
		"Current look: %s\nBody: %s\nGender: %s\nHair: %s\nHair color: %s\nUnlocked looks: %d / %d\nUse the controls below to change costume and hair." % [
			get_equipped_player_costume_display_name(),
			get_player_body_display_name(),
			get_player_gender_display_name(),
			get_player_hair_style_display_name(),
			get_player_hair_color_display_name(),
			unlocked_player_costume_ids.size(),
			get_player_costume_ids().size(),
		]
	)

	for costume_id in get_player_costume_ids():
		var costume: Dictionary = player_costume_catalog.get(costume_id, {})
		var is_unlocked := unlocked_player_costume_ids.find(costume_id) >= 0
		var state_text := "Locked"
		if costume_id == equipped_player_costume_id:
			state_text = "Wearing"
		elif is_unlocked:
			state_text = "Unlocked"

		sections.append(
			"%s: %s\n%s\nRoute: %s" % [
				state_text,
				String(costume.get("display_name", costume_id)),
				String(costume.get("summary", "")),
				String(costume.get("unlock_hint", "Always available.")),
			]
		)

	return "\n\n".join(PackedStringArray(sections))


func build_player_setup_summary_text() -> String:
	return "Body: %s\nGender: %s\nSkin: %s\nHair: %s\nHair color: %s\nStarting look: %s" % [
		get_player_body_display_name(),
		get_player_gender_display_name(),
		get_player_skin_display_name(),
		get_player_hair_style_display_name(),
		get_player_hair_color_display_name(),
		get_equipped_player_costume_display_name(),
	]


func _is_story_persistable_mode(mode_id: String = mode) -> bool:
	return mode_id in ["Story", "Postgame"]


func _build_story_autosave_payload() -> Dictionary:
	return {
		"version": STORY_AUTOSAVE_VERSION,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"mode": mode,
		"chapter": chapter,
		"location": location,
		"objective": objective,
		"journal_unlocked": journal_unlocked,
		"melody_progress": melody_progress.duplicate(true),
		"landmark_progress": landmark_progress.duplicate(true),
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
		"location": String(payload.get("location", "Piano Ferry")),
		"objective": String(payload.get("objective", "Find out why the island feels quiet today.")),
		"journal_unlocked": bool(payload.get("journal_unlocked", true)),
		"melody_progress": payload.get("melody_progress", {}),
		"landmark_progress": payload.get("landmark_progress", {}),
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
		"chapter": String(payload.get("chapter", "")),
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
	set_chapter(String(payload.get("chapter", "Arrival")))
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
	set_mode("Story")
	set_chapter("Arrival")
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
	set_mode("Free Walk")
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
	set_chapter("Festival Night")
	set_location("Ferry Plaza")
	set_objective("Wander the island after the festival.")
	set_journal_unlocked(true)
	set_hint(build_input_hint("R Inspect"))
	set_save_status("Autosave: postgame checkpoint saved")
	set_landmarks(_default_landmarks())
	set_open_shortcuts(PackedStringArray(["bi_shan_crossing"]))
	set_resident_profiles(_default_resident_profiles())
	set_melody_progress(_build_story_melody_progress("postgame"))
	set_all_landmark_progress(_build_landmark_progress("postgame"))
	story_resume_anchor_id = "Piano Ferry"
	story_resume_location = "Ferry Plaza"
	for resident_id in RESIDENT_CATALOG_SCRIPT.resident_order():
		_seed_resident_progress(resident_id, 2, RESIDENT_CATALOG_SCRIPT.max_trust(), "resolved", "Present at the restored festival and ready for lighter postgame dialogue.")
	_update_summary_counts()
	save_story_autosave()


func _apply_resident_beat(beat: Dictionary) -> void:
	var new_objective := String(beat.get("objective", ""))
	if !new_objective.is_empty():
		set_objective(new_objective)

	var new_hint := String(beat.get("hint", ""))
	if !new_hint.is_empty():
		set_hint(new_hint)

	var new_chapter := String(beat.get("chapter", ""))
	if !new_chapter.is_empty():
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
	var next_unlocked := PLAYER_COSTUME_CATALOG_SCRIPT.build_unlocked_costume_ids(
		mode,
		fragments_found,
		fragments_total,
		resident_profiles
	)
	var unlocked_changed := unlocked_player_costume_ids != next_unlocked
	var next_equipped := equipped_player_costume_id

	if next_unlocked.find(next_equipped) < 0:
		next_equipped = PLAYER_COSTUME_CATALOG_SCRIPT.default_costume_id()
		if next_unlocked.find(next_equipped) < 0 and !next_unlocked.is_empty():
			next_equipped = String(next_unlocked[0])

	var costume_changed := next_equipped != equipped_player_costume_id

	unlocked_player_costume_ids = next_unlocked
	equipped_player_costume_id = next_equipped

	if costume_changed:
		player_costume_changed.emit(equipped_player_costume_id, get_equipped_player_costume())
		_emit_player_appearance_changed()

	if unlocked_changed or costume_changed:
		player_costumes_changed.emit(get_unlocked_player_costume_ids(), equipped_player_costume_id)


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


## Called when the player inspects a LandmarkTrigger in the world.
## Routes to the appropriate per-landmark collection handler.
## Returns true only when the caller should consume the trigger in the scene.
## melody_hint is optional flavour text shown to the player on collection.
func activate_landmark_trigger(landmark_id: String, trigger_id: String, display_name: String, melody_hint: String = "") -> bool:
	match landmark_id:
		"piano_ferry":
			if trigger_id != "harbor_refrain":
				return false
			var ferry_progress := get_landmark_progress("piano_ferry")
			if ferry_progress.is_empty() or bool(ferry_progress.get("harbor_clue_found", false)):
				return false
			_collect_piano_ferry_harbor_clue()
			if melody_hint != "":
				melody_hint_shown.emit(melody_hint)
			set_objective("Return to Caretaker Lian with the harbor refrain.")
			set_hint(build_input_hint("R Talk to Caretaker Lian"))
			set_save_status("The harbor refrain is clearer now — return to Caretaker Lian.")
			_autosave_story_progress()
			return true
		"trinity_church":
			var church_progress := get_landmark_progress("trinity_church")
			if church_progress.is_empty():
				return false
			if trigger_id == "choir_chime":
				if bool(church_progress.get("chime_performed", false)):
					return false
				var cue_count := _normalize_string_array(church_progress.get("cues_collected", [])).size()
				if cue_count < 3:
					set_save_status("The church phrase needs all three choir cues before it can settle.")
					return false
				if melody_hint != "":
					melody_hint_shown.emit(melody_hint)
				_request_trinity_chime_prompt()
				return false
			if _progress_has_string_entry(church_progress, "cues_collected", trigger_id):
				return false
			var all_collected := _collect_trinity_church_cue(trigger_id)
			var cue_count := _normalize_string_array(
				get_landmark_progress("trinity_church").get("cues_collected", [])
			).size()
			set_save_status("Found: %s" % display_name)
			if melody_hint != "":
				melody_hint_shown.emit(melody_hint)
			if all_collected:
				melody_hint_shown.emit("The three choir cues lean toward one church chime, but they still need to be settled together.")
				set_objective("Settle the church phrase at the choir chime near the steps.")
				set_hint(build_input_hint("R Perform Choir Chime"))
				set_save_status("All choir cues found — settle them at the choir chime.")
			elif cue_count == 1:
				set_objective("Follow the next choir cue toward the side garden.")
			elif cue_count == 2:
				set_objective("Find the last choir cue in the quiet yard.")
			_autosave_story_progress()
			return true
		"bi_shan_tunnel":
			var tunnel_progress := get_landmark_progress("bi_shan_tunnel")
			if tunnel_progress.is_empty():
				return false
			if trigger_id == "chamber":
				var echoes: Array = tunnel_progress.get("echoes_collected", [])
				if echoes.size() >= 3:
					if melody_hint != "":
						melody_hint_shown.emit(melody_hint)
					_request_bi_shan_chamber_prompt()
					return false
				else:
					set_save_status("The mural panel is silent. Trace the three tunnel echoes first.")
					return false
			if _progress_has_string_entry(tunnel_progress, "echoes_collected", trigger_id):
				return false
			var all_echoes := _collect_bi_shan_echo(trigger_id)
			set_save_status("Heard: %s" % display_name)
			if all_echoes:
				set_objective("Reach the mural chamber at the far end of Bi Shan Tunnel.")
				set_hint("Follow the resonance to the chamber.   J Journal   Esc Pause")
				set_save_status("All three echoes traced — follow the resonance to the chamber.")
			_autosave_story_progress()
			return true
		"long_shan_tunnel":
			match trigger_id:
				"tunnel_entry":
					if get_landmark_state("long_shan_tunnel") == "available":
						advance_landmark_state("long_shan_tunnel", "introduced")
						set_save_status("Long Shan Tunnel entry reached — find Tunnel Guide Ren.")
						_autosave_story_progress()
						return true
					return false
				"light_pocket_south", "light_pocket_north":
					if get_landmark_state("long_shan_tunnel") != "in_progress":
						set_save_status("The lit pockets matter once Tunnel Guide Ren starts the crossing.")
						return false
					var all_checkpoints := _collect_long_shan_checkpoint(trigger_id)
					if melody_hint != "":
						melody_hint_shown.emit(melody_hint)
					if all_checkpoints:
						set_objective("Lead the route through to the Long Shan Tunnel exit.")
						set_hint(build_input_hint("R Collect Long Shan Tunnel Exit"))
						set_save_status("Both lit pockets are steady — guide the route to the exit.")
					else:
						set_objective("Keep moving with Ren until you reach the next lit pocket.")
						set_save_status("A safe-lit pocket steadied the route ahead.")
					_autosave_story_progress()
					return true
				"tunnel_exit":
					if get_landmark_state("long_shan_tunnel") == "in_progress":
						var checkpoint_count := _normalize_string_array(
							get_landmark_progress("long_shan_tunnel").get("checkpoints_collected", [])
						).size()
						if checkpoint_count >= 2:
							if melody_hint != "":
								melody_hint_shown.emit(melody_hint)
							_request_long_shan_route_prompt()
							return false
						set_save_status("The route is still uneven. Pause with Ren at the lit pockets before crossing.")
						return false
					set_save_status("Tunnel exit reached — talk to Tunnel Guide Ren before crossing.")
					return false
			return false
		"bagua_tower":
			if trigger_id == "synthesis_chamber":
				var tower_progress := get_landmark_progress("bagua_tower")
				if tower_progress.is_empty():
					return false
				var melody_state := get_melody_state("festival_melody")
				var fragments_in := int(melody_state.get("fragments_found", 0))
				if get_landmark_state("bagua_tower") == "in_progress" \
				and fragments_in >= 3 \
				and !bool(tower_progress.get("synthesis_done", false)):
					_resolve_bagua_tower_synthesis()
					_autosave_story_progress()
					return true
				set_save_status("The tower shows distance but not yet direction. Recover more fragments first.")
				return false
			return false
		"festival_stage":
			if get_landmark_state("festival_stage") != "available":
				return false
			if melody_hint != "":
				melody_hint_shown.emit(melody_hint)
			_request_melody_prompt("festival_melody", "performance")
			return false
	return false


func _progress_has_string_entry(progress: Dictionary, progress_key: String, entry_id: String) -> bool:
	return _normalize_string_array(progress.get(progress_key, [])).find(entry_id) >= 0


func _request_melody_prompt(
	melody_id: String,
	prompt_mode: String,
	completion_kind: String = "",
	request_overrides: Dictionary = {}
) -> void:
	var melody_definition := get_melody_definition(melody_id)
	if melody_definition.is_empty():
		set_save_status("The phrase slips away before it can be arranged.")
		return

	var melody_state := get_melody_state(melody_id)
	if melody_state.is_empty():
		set_save_status("The phrase is not ready yet.")
		return

	var prompt_segments := _build_melody_prompt_segments(melody_id)
	if prompt_segments.size() < 2:
		set_save_status("Recover at least two steady phrase segments before arranging the melody.")
		return

	var melody_stage := String(melody_state.get("state", "unknown"))
	if melody_stage not in ["reconstructed", "performed", "resonant"]:
		set_save_status("The phrase needs more shape before it can be rehearsed.")
		return

	var normalized_completion_kind := completion_kind
	if normalized_completion_kind.is_empty():
		normalized_completion_kind = "festival_performance" if prompt_mode == "performance" else "melody_practice"

	if prompt_mode == "performance" and normalized_completion_kind == "festival_performance" and !can_perform_melody(melody_id):
		set_save_status("The performance point is not ready to answer the melody yet.")
		return

	var expected_order: Array[String] = []
	for segment in prompt_segments:
		expected_order.append(String(segment.get("source_id", "")))

	var first_label := String(prompt_segments[0].get("label", "the opening phrase"))
	var display_name := String(melody_definition.get("display_name", melody_id))
	var prompt_title := "Practice %s" % display_name
	var prompt_body := "Arrange the phrase segments in the order that feels right. There is no penalty for trying again."
	if prompt_mode == "performance":
		prompt_title = "Perform %s" % display_name
		prompt_body = String(melody_definition.get("performance_prompt", ""))
	var request := {
		"melody_id": melody_id,
		"mode": prompt_mode,
		"completion_kind": normalized_completion_kind,
		"title": prompt_title,
		"body": prompt_body,
		"segments": prompt_segments,
		"expected_order": expected_order,
		"retry_hint": "That contour felt off. Try beginning with %s." % first_label,
		"hint_text": "Choose the known phrase segments in order.",
	}
	request.merge(request_overrides, true)
	melody_prompt_requested.emit(request)


func _request_trinity_chime_prompt() -> void:
	var request := {
		"melody_id": "festival_melody",
		"mode": "performance",
		"completion_kind": "trinity_chime",
		"title": "Settle the Trinity Chime",
		"body": "Arrange the choir cues in the order Mei taught you, then let the church phrase settle into one calm chime.",
		"segments": [
			{"source_id": "steps", "label": "Stone Steps", "landmark": "Trinity Church"},
			{"source_id": "garden", "label": "Side Garden", "landmark": "Trinity Church"},
			{"source_id": "yard", "label": "Quiet Yard", "landmark": "Trinity Church"},
		],
		"expected_order": ["steps", "garden", "yard"],
		"retry_hint": "The church phrase begins at the steps before the garden and quiet yard answer.",
		"hint_text": "Choose the choir cues in Mei's order.",
	}
	melody_prompt_requested.emit(request)


func _request_bi_shan_chamber_prompt() -> void:
	var request := {
		"melody_id": "festival_melody",
		"mode": "performance",
		"completion_kind": "bi_shan_chamber",
		"title": "Settle the Bi Shan Contour",
		"body": "Arrange the tunnel echoes from the first steady contour to the mural-facing answer so the chamber can respond.",
		"segments": [
			{"source_id": "echo_a", "label": "North Wall Echo", "landmark": "Bi Shan Tunnel"},
			{"source_id": "echo_b", "label": "Arch Midpoint", "landmark": "Bi Shan Tunnel"},
			{"source_id": "echo_c", "label": "Mural Approach", "landmark": "Bi Shan Tunnel"},
		],
		"expected_order": ["echo_a", "echo_b", "echo_c"],
		"retry_hint": "Let the north wall answer first, then the arch midpoint, before the mural approach settles.",
		"hint_text": "Choose the tunnel echoes in the contour they reveal together.",
	}
	melody_prompt_requested.emit(request)


func _request_long_shan_route_prompt() -> void:
	var request := {
		"melody_id": "festival_melody",
		"mode": "performance",
		"completion_kind": "long_shan_route",
		"title": "Steady the Long Shan Route",
		"body": "Confirm the lit-pocket rhythm that carried Ren through the tunnel before the exit can settle into one route.",
		"segments": [
			{"source_id": "light_pocket_south", "label": "South Lit Pocket", "landmark": "Long Shan Tunnel"},
			{"source_id": "light_pocket_north", "label": "North Lit Pocket", "landmark": "Long Shan Tunnel"},
		],
		"expected_order": ["light_pocket_south", "light_pocket_north"],
		"retry_hint": "The steadier route begins with the south lit pocket before the northern light answers it.",
		"hint_text": "Choose the lit pockets in the order Ren followed them.",
	}
	melody_prompt_requested.emit(request)


func _build_melody_prompt_segments(melody_id: String) -> Array[Dictionary]:
	var melody_definition := get_melody_definition(melody_id)
	var melody_state := get_melody_state(melody_id)
	if melody_definition.is_empty() or melody_state.is_empty():
		return []

	var known_sources := _normalize_string_array(melody_state.get("known_sources", []))
	var prompt_segments: Array[Dictionary] = []

	for source in melody_definition.get("sources", []):
		var source_id := String(source.get("source_id", ""))
		if source_id.is_empty():
			continue
		if !bool(source.get("counts_as_fragment", true)):
			continue
		if known_sources.find(source_id) < 0:
			continue

		prompt_segments.append({
			"source_id": source_id,
			"label": String(source.get("label", "Unknown phrase")),
			"landmark": String(source.get("landmark", "Unknown landmark")),
		})

	return prompt_segments


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
	var progress := get_landmark_progress("trinity_church")
	if progress.is_empty():
		set_save_status("The church phrase is not ready to settle yet.")
		return

	var cues := _normalize_string_array(progress.get("cues_collected", []))
	if cues.size() < 3:
		set_save_status("The church phrase still needs all three choir cues.")
		return

	if bool(progress.get("chime_performed", false)):
		set_save_status("The church bells have already settled into place.")
		return

	progress["chime_performed"] = true
	progress["state"] = "resolved"
	set_landmark_progress("trinity_church", progress)
	set_objective("Return to Choir Caretaker Mei with the settled church phrase.")
	set_hint(build_input_hint("R Talk to Choir Caretaker Mei"))
	set_save_status("The choir phrase settled into one calm church chime.")
	_autosave_story_progress()


func _complete_bi_shan_chamber() -> void:
	var progress := get_landmark_progress("bi_shan_tunnel")
	var echoes := _normalize_string_array(progress.get("echoes_collected", []))
	if echoes.size() < 3:
		set_save_status("The mural panel is still waiting on the three tunnel echoes.")
		return

	if get_landmark_state("bi_shan_tunnel") == "reward_collected":
		set_save_status("The Bi Shan contour has already settled into the tunnel walls.")
		return

	_resolve_bi_shan_tunnel()
	_autosave_story_progress()


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
	var progress := get_landmark_progress("long_shan_tunnel")
	var checkpoints := _normalize_string_array(progress.get("checkpoints_collected", []))
	if checkpoints.size() < 2 or get_landmark_state("long_shan_tunnel") != "in_progress":
		set_save_status("The Long Shan route still needs both lit pockets before it can settle.")
		return

	_resolve_long_shan_tunnel()
	_autosave_story_progress()


## Award the Bi Shan Tunnel melody fragment and advance melody state.
## Called when the player settles the mural chamber prompt after tracing all echoes.
func _resolve_bi_shan_tunnel() -> void:
	advance_landmark_state("bi_shan_tunnel", "reward_collected")

	var previous_melody: Dictionary = get_melody_state("festival_melody").duplicate(true)
	var melody_state := _award_festival_source_once("bi_shan_echo")
	_sync_festival_state_from_fragments(melody_state)

	set_melody_progress({"festival_melody": melody_state})
	_emit_fragment_story_milestones(previous_melody, "bi_shan_echo", melody_state)
	unlock_shortcut("bi_shan_crossing")
	if get_landmark_state("long_shan_tunnel") == "reward_collected" and get_landmark_state("bagua_tower") == "locked":
		set_objective("Return to Tunnel Guide Ren now that both tunnel routes agree.")
		set_hint(build_input_hint("R Talk to Tunnel Guide Ren"))
		set_save_status("Bi Shan Tunnel — mural resonance restored. Ren can now compare the two tunnel routes.")
	elif get_landmark_state("bagua_tower") != "locked":
		set_objective("Carry the steadier tunnel route up to Bagua Tower.")
		set_hint(build_input_hint("R Talk to Tower Keeper Suyin"))
		set_save_status("Bi Shan Tunnel — mural resonance restored, and the tower can now read the route clearly.")
	else:
		set_objective("Explore Long Shan Tunnel and move with Ren between the lit pockets.")
		set_hint(build_input_hint("R Inspect"))
		set_save_status("Bi Shan Tunnel — mural resonance restored, and the tunnel route feels steadier now.")


## Award the Long Shan Tunnel melody fragment and advance melody state.
## Called when the player settles the exit-route prompt after both lit pockets.
func _resolve_long_shan_tunnel() -> void:
	advance_landmark_state("long_shan_tunnel", "reward_collected")

	var previous_melody: Dictionary = get_melody_state("festival_melody").duplicate(true)
	var melody_state := _award_festival_source_once("long_shan_route")
	_sync_festival_state_from_fragments(melody_state)

	set_melody_progress({"festival_melody": melody_state})
	_emit_fragment_story_milestones(previous_melody, "long_shan_route", melody_state)
	set_objective("Return to Tunnel Guide Ren and compare what the tunnel routes now suggest.")
	set_hint(build_input_hint("R Talk to Tunnel Guide Ren"))
	set_save_status("Long Shan Tunnel — passage completed. Ren can now judge what the route means.")


## Called when the synthesis chamber trigger fires at the top of Bagua Tower.
## Marks synthesis as done, which gates tower_keeper's final resolved beat.
func _resolve_bagua_tower_synthesis() -> void:
	var progress := get_landmark_progress("bagua_tower")
	progress["synthesis_done"] = true
	progress["state"] = "resolved"
	set_landmark_progress("bagua_tower", progress)
	set_objective("Return to Tower Keeper Suyin to confirm the island route.")
	set_save_status("Bagua Tower synthesis complete — return to Tower Keeper Suyin.")


## Award the final Bagua Tower melody fragment and complete the island melody.
## Called when tower_keeper's final dialogue beat fires with "landmark_reward": "bagua_tower".
func _resolve_bagua_tower() -> void:
	advance_landmark_state("bagua_tower", "reward_collected")

	var previous_melody: Dictionary = get_melody_state("festival_melody").duplicate(true)
	var melody_state := _award_festival_source_once("tower_chamber")
	_sync_festival_state_from_fragments(melody_state)
	melody_state["next_lead"] = "Return to the ferry plaza and perform the restored melody at the festival stage."

	set_melody_progress({"festival_melody": melody_state})
	_emit_fragment_story_milestones(previous_melody, "tower_chamber", melody_state)
	advance_landmark_state("festival_stage", "available")
	set_objective("Return to Piano Ferry and perform the restored melody at the festival stage.")
	set_save_status("The island melody is whole — the harbor stage is ready.")


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
			"mode":
				if mode != String(conditions[key]):
					return false
			"resident_known":
				var required_known: Array = conditions[key] if conditions[key] is Array else []
				for rid in required_known:
					var other: Dictionary = resident_profiles.get(String(rid), {})
					if !bool(other.get("known", false)):
						return false
	return true


## Emit a resident_trust_max milestone the first time a resident reaches max trust.
func _emit_trust_milestone_if_max(resident_id: String, old_trust: int, new_trust: int) -> void:
	if new_trust >= RESIDENT_CATALOG_SCRIPT.max_trust() and old_trust < RESIDENT_CATALOG_SCRIPT.max_trust():
		story_milestone.emit("resident_trust_max", {"resident_id": resident_id})


## Dispatch to the correct landmark resolution handler and emit a story
## milestone so ambient systems can react without coupling to internals.
func _resolve_landmark(landmark_id: String) -> void:
	match landmark_id:
		"piano_ferry":
			_resolve_piano_ferry()
		"trinity_church":
			_resolve_trinity_church()
		"bagua_tower":
			_resolve_bagua_tower()

	story_milestone.emit("landmark_resolved", {
		"landmark_id": landmark_id,
		"fragments_found": fragments_found,
		"helped_residents": _count_helped_residents(),
	})


func _resolve_piano_ferry() -> void:
	advance_landmark_state("piano_ferry", "reward_collected")
	set_journal_unlocked(true)

	var previous_melody: Dictionary = get_melody_state("festival_melody").duplicate(true)
	var melody_state := _award_festival_source_once("ferry_plaza", false)
	_sync_festival_state_from_fragments(melody_state)
	melody_state["next_lead"] = "Speak with the church caretaker and compare how the bells answer the harbor."
	set_melody_progress({"festival_melody": melody_state})
	_emit_fragment_story_milestones(previous_melody, "ferry_plaza", melody_state, false)
	set_save_status("Journal unlocked — Trinity Church is marked as your first lead.")


## Award the Trinity Church melody fragment, update melody state, and unlock
## the tunnel landmarks. Called automatically when the church_caretaker's
## resolved dialogue beat fires with "landmark_reward": "trinity_church".
func _resolve_trinity_church() -> void:
	advance_landmark_state("trinity_church", "reward_collected")

	# Add church_bells as a confirmed melody source and award one fragment.
	var previous_melody: Dictionary = get_melody_state("festival_melody").duplicate(true)
	var melody_state := _award_festival_source_once("church_bells")
	_sync_festival_state_from_fragments(melody_state)

	set_melody_progress({"festival_melody": melody_state})
	_emit_fragment_story_milestones(previous_melody, "church_bells", melody_state)

	# Open the tunnel landmarks for the next phase.
	advance_landmark_state("bi_shan_tunnel", "available")
	advance_landmark_state("long_shan_tunnel", "available")


func _award_festival_source_once(source_id: String, counts_as_fragment: bool = true) -> Dictionary:
	var melody_state := get_melody_state("festival_melody").duplicate(true)
	var sources: Array[String] = _normalize_string_array(melody_state.get("known_sources", []))
	if sources.find(source_id) >= 0:
		melody_state["known_sources"] = sources
		return melody_state

	sources.append(source_id)
	melody_state["known_sources"] = sources
	if counts_as_fragment:
		var new_count := mini(
			int(melody_state.get("fragments_found", 0)) + 1,
			int(melody_state.get("fragments_total", fragments_total))
		)
		melody_state["fragments_found"] = new_count

	return melody_state


func _emit_fragment_story_milestones(
	previous_melody: Dictionary,
	source_id: String,
	melody_state: Dictionary,
	counts_as_fragment: bool = true
) -> void:
	var previous_sources: Array[String] = _normalize_string_array(previous_melody.get("known_sources", []))
	if previous_sources.find(source_id) >= 0:
		return

	if !counts_as_fragment:
		return

	var new_count := int(melody_state.get("fragments_found", 0))
	story_milestone.emit("fragment_restored", {
		"melody_id": "festival_melody",
		"source_id": source_id,
		"total_found": new_count,
	})

	if new_count >= int(melody_state.get("fragments_total", fragments_total)):
		story_milestone.emit("festival_ready", {
			"fragments_found": new_count,
			"helped_residents": _count_helped_residents(),
		})


func _sync_festival_state_from_fragments(melody_state: Dictionary) -> void:
	var found := int(melody_state.get("fragments_found", 0))
	var performed := bool(melody_state.get("performed", false))
	var known_sources := _normalize_string_array(melody_state.get("known_sources", []))
	if performed:
		melody_state["state"] = "performed"
		melody_state["performed"] = true
	elif found >= 2:
		melody_state["state"] = "reconstructed"
		melody_state["performed"] = bool(melody_state.get("performed", false))
	elif found >= 1 or !known_sources.is_empty():
		melody_state["state"] = "heard"
		melody_state["performed"] = bool(melody_state.get("performed", false))
	else:
		melody_state["state"] = "unknown"
		melody_state["performed"] = bool(melody_state.get("performed", false))


func _perform_festival_melody() -> void:
	advance_landmark_state("festival_stage", "reward_collected")

	var melody_state := get_melody_state("festival_melody").duplicate(true)
	melody_state["performed"] = true
	melody_state["state"] = "performed"
	melody_state["next_lead"] = "Stay for the harbor gathering or keep wandering once the festival recap ends."
	set_melody_progress({"festival_melody": melody_state})

	set_chapter("Festival Night")
	set_objective("The restored festival melody carries across the harbor.")
	set_save_status("The harbor gathering answers the restored melody.")
	story_milestone.emit("festival_performed", {
		"fragments_found": fragments_found,
		"helped_residents": _count_helped_residents(),
	})
