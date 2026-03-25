# @tool is required so that catalog data (melody_catalog, player_costume_catalog,
# etc.) is populated when the autoload is loaded in the Godot editor. This allows
# UI scenes and inspector tools to read catalog state at edit-time. No scene-
# mutating or signal-dependent logic runs at edit-time; all state is initialized
# inline from the catalog scripts, which are themselves @tool-safe pure functions.
@tool
extends Node

const RESIDENT_CATALOG_SCRIPT := preload("res://game/resident_catalog.gd")
const MELODY_CATALOG_SCRIPT := preload("res://game/melody_catalog.gd")
const PLAYER_APPEARANCE_CATALOG_SCRIPT := preload("res://game/player_appearance_catalog.gd")
const PLAYER_COSTUME_CATALOG_SCRIPT := preload("res://game/player_costume_catalog.gd")

signal mode_changed(mode: String)
signal chapter_changed(chapter: String)
signal location_changed(location: String)
signal objective_changed(objective: String)
signal hint_changed(hint: String)
signal save_status_changed(status: String)
signal fragments_changed(found: int, total: int)
signal melody_progress_changed(melody_id: String, melody: Dictionary)
signal landmarks_changed(landmarks: PackedStringArray)
signal residents_changed(residents: PackedStringArray)
signal resident_profile_changed(resident_id: String, resident: Dictionary)
signal player_profile_changed(profile: Dictionary)
signal player_costume_changed(costume_id: String, costume: Dictionary)
signal player_costumes_changed(unlocked_ids: PackedStringArray, equipped_costume_id: String)
signal player_appearance_changed(profile: Dictionary, appearance_config: Dictionary)
signal summary_changed(summary: Dictionary)
signal landmark_progress_changed(landmark_id: String, progress: Dictionary)

var mode := "Title"
var chapter := "Arrival"
var location := "Piano Ferry"
var objective := "Find out why the island feels quiet today."
var hint := "R Inspect   J Journal   Esc Pause"
var save_status := "Autosave: ready"
var fragments_found := 0
var fragments_total := 4
var melody_catalog: Dictionary = MELODY_CATALOG_SCRIPT.build_catalog()
var melody_progress: Dictionary = _default_melody_progress()
var landmarks: PackedStringArray = _default_landmarks()
var residents: PackedStringArray = PackedStringArray()
var resident_profiles: Dictionary = _default_resident_profiles()
var player_profile: Dictionary = PLAYER_APPEARANCE_CATALOG_SCRIPT.default_profile()
var player_costume_catalog: Dictionary = PLAYER_COSTUME_CATALOG_SCRIPT.build_catalog()
var unlocked_player_costume_ids: PackedStringArray = PLAYER_COSTUME_CATALOG_SCRIPT.build_unlocked_costume_ids(
	mode,
	fragments_found,
	fragments_total,
	resident_profiles
)
var equipped_player_costume_id := PLAYER_COSTUME_CATALOG_SCRIPT.default_costume_id()
var landmark_progress: Dictionary = _default_landmark_progress()
var ending_summary := {
	"fragments": "4 / 4",
	"residents": "0",
	"collectibles": "prototype",
	"playtime": "a brief evening on Kulangsu",
}


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
	return RESIDENT_CATALOG_SCRIPT.build_defaults()


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


func get_resident_profile(resident_id: String) -> Dictionary:
	if !resident_profiles.has(resident_id):
		return {}
	return resident_profiles[resident_id].duplicate(true)


func get_resident_display_name(resident_id: String) -> String:
	var resident: Dictionary = resident_profiles.get(resident_id, {})
	return String(resident.get("display_name", "Resident"))


func get_resident_landmark(resident_id: String) -> String:
	var resident: Dictionary = resident_profiles.get(resident_id, {})
	return String(resident.get("landmark", "Unknown District"))


func get_resident_appearance_config(resident_id: String) -> Dictionary:
	var resident: Dictionary = resident_profiles.get(resident_id, {})
	var appearance: Dictionary = resident.get("appearance", {})
	return appearance.duplicate(true)


func get_resident_spawn_config(resident_id: String) -> Dictionary:
	var resident: Dictionary = resident_profiles.get(resident_id, {})
	var spawn: Dictionary = resident.get("spawn", {})
	return spawn.duplicate(true)


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
	var names := PackedStringArray()
	for resident_id in RESIDENT_CATALOG_SCRIPT.resident_order():
		var resident: Dictionary = resident_profiles.get(resident_id, {})
		if resident.get("known", false):
			names.append(String(resident.get("display_name", resident_id)))
	return names


func get_resident_ambient_line(resident_id: String) -> String:
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


func build_resident_journal_text() -> String:
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


func interact_with_resident(resident_id: String) -> Dictionary:
	if !resident_profiles.has(resident_id):
		return {}

	var resident: Dictionary = resident_profiles[resident_id].duplicate(true)
	var dialogue_beats: Array = resident.get("dialogue_beats", [])

	resident["known"] = true

	if dialogue_beats.is_empty():
		resident_profiles[resident_id] = resident
		_sync_known_residents()
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
		_refresh_player_costumes()
		resident_profile_changed.emit(resident_id, get_resident_profile(resident_id))
		var fallback := String(beat.get("gate_fallback", ""))
		return {"line": fallback}

	resident["trust"] = clampi(
		int(resident.get("trust", 0)) + int(beat.get("trust_delta", 0)),
		0,
		RESIDENT_CATALOG_SCRIPT.max_trust()
	)
	resident["quest_state"] = String(beat.get("quest_state", resident.get("quest_state", "available")))
	resident["current_step"] = String(beat.get("journal_step", beat.get("objective", "Stay in touch.")))

	if beat_index < dialogue_beats.size() - 1:
		resident["conversation_index"] = beat_index + 1

	resident_profiles[resident_id] = resident
	_sync_known_residents()
	_apply_resident_beat(beat)
	_refresh_player_costumes()
	resident_profile_changed.emit(resident_id, get_resident_profile(resident_id))
	return beat.duplicate(true)


func configure_new_game() -> void:
	set_mode("Story")
	set_chapter("Arrival")
	set_location("Piano Ferry")
	set_objective("Find out why the island feels quiet today.")
	set_hint("R Inspect   J Journal   Esc Pause")
	set_save_status("Autosave: prototype checkpoint ready")
	set_landmarks(_default_landmarks())
	set_resident_profiles(_default_resident_profiles())
	set_melody_progress(_build_story_melody_progress("new_game"))
	set_all_landmark_progress(_build_landmark_progress("new_game"))
	set_summary({
		"fragments": "0 / 4",
		"residents": "0",
		"collectibles": "prototype",
		"playtime": "a brief evening on Kulangsu",
	})


func configure_continue() -> void:
	set_mode("Story")
	set_chapter("Midway")
	set_location("Harbor Path")
	set_objective("Resume exploring from the harbor and choose your next district.")
	set_hint("R Inspect   J Journal   Esc Pause")
	set_save_status("Autosave: resumed from the latest harbor checkpoint")
	set_landmarks(_default_landmarks())
	set_resident_profiles(_default_resident_profiles())
	set_melody_progress(_build_story_melody_progress("continue"))
	set_all_landmark_progress(_build_landmark_progress("continue"))
	_seed_resident_progress("ferry_caretaker", 2, 2, "resolved", "Waiting for the harbor to hear a fully restored phrase.")
	_seed_resident_progress("church_caretaker", 2, 2, "reward_collected", "The church phrase is stable and pointing toward the tunnels.")
	_seed_resident_progress("tower_keeper", 1, 1, "introduced", "Preparing to compare fragments at Bagua Tower.")
	_update_summary_counts()


func configure_free_walk() -> void:
	set_mode("Free Walk")
	set_chapter("Free Walk")
	set_location("Piano Ferry")
	set_objective("Wander the island and learn how the first district wants to be introduced.")
	set_hint("R Inspect   J Journal   Esc Pause")
	set_save_status("Autosave: free walk sandbox ready")
	set_landmarks(_default_landmarks())
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
	set_hint("R Inspect   J Journal   Esc Pause")
	set_save_status("Autosave: postgame prototype checkpoint ready")
	set_landmarks(_default_landmarks())
	set_resident_profiles(_default_resident_profiles())
	set_melody_progress(_build_story_melody_progress("postgame"))
	set_all_landmark_progress(_build_landmark_progress("postgame"))
	for resident_id in RESIDENT_CATALOG_SCRIPT.resident_order():
		_seed_resident_progress(resident_id, 2, RESIDENT_CATALOG_SCRIPT.max_trust(), "resolved", "Present at the restored festival and ready for lighter postgame dialogue.")
	_update_summary_counts()


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
					"next_lead": "Speak with the church caretaker and compare how the bells answer the harbor.",
					"performed": false,
				},
			}
		"continue":
			return {
				"festival_melody": {
					"state": "reconstructed",
					"fragments_found": 2,
					"known_sources": ["ferry_plaza", "church_bells", "tunnel_echo"],
					"next_lead": "Carry the stronger contour toward Bagua Tower and compare the recovered phrases.",
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
					"known_sources": ["ferry_plaza", "church_bells", "tunnel_echo", "tower_chamber"],
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


# ---------------------------------------------------------------------------
# Landmark Progress
# ---------------------------------------------------------------------------

func _default_landmark_progress() -> Dictionary:
	return {
		"piano_ferry": {"state": "locked"},
		"trinity_church": {"state": "locked", "cues_collected": []},
		"bi_shan_tunnel": {"state": "locked", "echoes_collected": []},
		"long_shan_tunnel": {"state": "locked"},
		"bagua_tower": {"state": "locked"},
	}


func _build_landmark_progress(state_id: String) -> Dictionary:
	match state_id:
		"new_game":
			return {
				"piano_ferry": {"state": "available"},
				"trinity_church": {"state": "locked", "cues_collected": []},
				"bi_shan_tunnel": {"state": "locked", "echoes_collected": []},
				"long_shan_tunnel": {"state": "locked"},
				"bagua_tower": {"state": "locked"},
			}
		"continue":
			return {
				"piano_ferry": {"state": "reward_collected"},
				"trinity_church": {"state": "reward_collected", "cues_collected": ["steps", "garden", "yard"]},
				"bi_shan_tunnel": {"state": "introduced", "echoes_collected": []},
				"long_shan_tunnel": {"state": "available"},
				"bagua_tower": {"state": "locked"},
			}
		"free_walk":
			return {
				"piano_ferry": {"state": "available"},
				"trinity_church": {"state": "available", "cues_collected": []},
				"bi_shan_tunnel": {"state": "available", "echoes_collected": []},
				"long_shan_tunnel": {"state": "available"},
				"bagua_tower": {"state": "available"},
			}
		"postgame":
			return {
				"piano_ferry": {"state": "reward_collected"},
				"trinity_church": {"state": "reward_collected", "cues_collected": ["steps", "garden", "yard"]},
				"bi_shan_tunnel": {"state": "reward_collected", "echoes_collected": ["echo_a", "echo_b", "echo_c"]},
				"long_shan_tunnel": {"state": "reward_collected"},
				"bagua_tower": {"state": "reward_collected"},
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
func activate_landmark_trigger(landmark_id: String, trigger_id: String, display_name: String) -> void:
	match landmark_id:
		"trinity_church":
			var all_collected := _collect_trinity_church_cue(trigger_id)
			set_save_status("Found: %s" % display_name)
			if all_collected:
				set_objective("Return to Choir Caretaker Mei with all three choir cues.")
				set_hint("R Talk to Choir Caretaker Mei   J Journal   Esc Pause")
				set_save_status("All choir cues found — return to Choir Caretaker Mei.")
		"bi_shan_tunnel":
			if trigger_id == "chamber":
				var progress := get_landmark_progress("bi_shan_tunnel")
				var echoes: Array = progress.get("echoes_collected", [])
				if echoes.size() >= 3:
					_resolve_bi_shan_tunnel()
				else:
					set_save_status("The mural panel is silent. Trace the three tunnel echoes first.")
			else:
				var all_echoes := _collect_bi_shan_echo(trigger_id)
				set_save_status("Heard: %s" % display_name)
				if all_echoes:
					set_objective("Reach the mural chamber at the far end of Bi Shan Tunnel.")
					set_hint("Follow the resonance to the chamber.   J Journal   Esc Pause")
					set_save_status("All three echoes traced — follow the resonance to the chamber.")
		"long_shan_tunnel":
			match trigger_id:
				"tunnel_entry":
					if get_landmark_state("long_shan_tunnel") == "available":
						advance_landmark_state("long_shan_tunnel", "introduced")
						set_save_status("Long Shan Tunnel entry reached — find Tunnel Guide Ren.")
				"tunnel_exit":
					if get_landmark_state("long_shan_tunnel") == "in_progress":
						_resolve_long_shan_tunnel()
					else:
						set_save_status("Tunnel exit reached — talk to Tunnel Guide Ren before crossing.")
		"bagua_tower":
			if trigger_id == "synthesis_chamber":
				var melody_state := get_melody_state("festival_melody")
				var fragments_in := int(melody_state.get("fragments_found", 0))
				if get_landmark_state("bagua_tower") == "in_progress" and fragments_in >= 3:
					_resolve_bagua_tower_synthesis()
				else:
					set_save_status("The tower shows distance but not yet direction. Recover more fragments first.")


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


## Award the Bi Shan Tunnel melody fragment and advance melody state.
## Called when the player activates the mural chamber trigger with all echoes.
func _resolve_bi_shan_tunnel() -> void:
	advance_landmark_state("bi_shan_tunnel", "reward_collected")

	var melody_state := get_melody_state("festival_melody").duplicate(true)
	var sources: Array[String] = _normalize_string_array(melody_state.get("known_sources", []))
	if sources.find("tunnel_echo") < 0:
		sources.append("tunnel_echo")
	melody_state["known_sources"] = sources

	var new_found := mini(
		int(melody_state.get("fragments_found", 0)) + 1,
		int(melody_state.get("fragments_total", 4))
	)
	melody_state["fragments_found"] = new_found
	if new_found >= 2:
		melody_state["state"] = "reconstructed"
	elif new_found >= 1:
		melody_state["state"] = "heard"

	set_melody_progress({"festival_melody": melody_state})
	set_objective("Explore Long Shan Tunnel and find Tunnel Guide Ren.")
	set_save_status("Bi Shan Tunnel — mural resonance restored.")


## Award the Long Shan Tunnel melody fragment and advance melody state.
## Called when the player exits the tunnel with the escort in progress.
func _resolve_long_shan_tunnel() -> void:
	advance_landmark_state("long_shan_tunnel", "reward_collected")

	var melody_state := get_melody_state("festival_melody").duplicate(true)
	var sources: Array[String] = _normalize_string_array(melody_state.get("known_sources", []))
	if sources.find("tunnel_passage") < 0:
		sources.append("tunnel_passage")
	melody_state["known_sources"] = sources

	var new_found := mini(
		int(melody_state.get("fragments_found", 0)) + 1,
		int(melody_state.get("fragments_total", 4))
	)
	melody_state["fragments_found"] = new_found
	if new_found >= 2:
		melody_state["state"] = "reconstructed"
	elif new_found >= 1:
		melody_state["state"] = "heard"

	set_melody_progress({"festival_melody": melody_state})
	set_objective("Climb Bagua Tower and find Tower Keeper Lin.")
	set_save_status("Long Shan Tunnel — passage completed.")


## Called when the synthesis chamber trigger fires at the top of Bagua Tower.
## Marks synthesis as done, which gates tower_keeper's final resolved beat.
func _resolve_bagua_tower_synthesis() -> void:
	var progress := get_landmark_progress("bagua_tower")
	progress["synthesis_done"] = true
	progress["state"] = "resolved"
	set_landmark_progress("bagua_tower", progress)
	set_objective("Return to Tower Keeper Lin to confirm the island melody.")
	set_save_status("Bagua Tower synthesis complete — return to Tower Keeper Lin.")


## Award the final Bagua Tower melody fragment and complete the island melody.
## Called when tower_keeper's final dialogue beat fires with "landmark_reward": "bagua_tower".
func _resolve_bagua_tower() -> void:
	advance_landmark_state("bagua_tower", "reward_collected")

	var melody_state := get_melody_state("festival_melody").duplicate(true)
	var sources: Array[String] = _normalize_string_array(melody_state.get("known_sources", []))
	if sources.find("tower_synthesis") < 0:
		sources.append("tower_synthesis")
	melody_state["known_sources"] = sources

	var new_found := mini(
		int(melody_state.get("fragments_found", 0)) + 1,
		int(melody_state.get("fragments_total", 4))
	)
	melody_state["fragments_found"] = new_found
	if new_found >= 4:
		melody_state["state"] = "performed"
	elif new_found >= 2:
		melody_state["state"] = "reconstructed"
	elif new_found >= 1:
		melody_state["state"] = "heard"

	set_melody_progress({"festival_melody": melody_state})
	set_objective("The island melody is complete. Find the festival stage to perform it.")
	set_save_status("The island melody is whole.")


## Gate check: returns false if a beat's prerequisite condition is not met.
## The conversation does not advance and a fallback line is shown instead.
func _check_beat_gate(beat: Dictionary) -> bool:
	var gate := String(beat.get("gate", ""))
	if gate.is_empty():
		return true
	match gate:
		"trinity_church_cues":
			var progress := get_landmark_progress("trinity_church")
			var cues: Array = progress.get("cues_collected", [])
			return cues.size() >= 3
		"long_shan_exit_reached":
			return get_landmark_state("long_shan_tunnel") == "reward_collected"
		"bagua_synthesis_done":
			var progress := get_landmark_progress("bagua_tower")
			return bool(progress.get("synthesis_done", false))
	return true


## Dispatch to the correct landmark resolution handler.
func _resolve_landmark(landmark_id: String) -> void:
	match landmark_id:
		"trinity_church":
			_resolve_trinity_church()
		"bagua_tower":
			_resolve_bagua_tower()


## Award the Trinity Church melody fragment, update melody state, and unlock
## the tunnel landmarks. Called automatically when the church_caretaker's
## resolved dialogue beat fires with "landmark_reward": "trinity_church".
func _resolve_trinity_church() -> void:
	advance_landmark_state("trinity_church", "reward_collected")

	# Add church_bells as a confirmed melody source and award one fragment.
	var melody_state := get_melody_state("festival_melody").duplicate(true)
	var sources: Array[String] = _normalize_string_array(melody_state.get("known_sources", []))
	if sources.find("church_bells") < 0:
		sources.append("church_bells")
	melody_state["known_sources"] = sources

	var new_found := mini(
		int(melody_state.get("fragments_found", 0)) + 1,
		int(melody_state.get("fragments_total", 4))
	)
	melody_state["fragments_found"] = new_found
	if new_found >= 2:
		melody_state["state"] = "reconstructed"
	elif new_found >= 1:
		melody_state["state"] = "heard"

	set_melody_progress({"festival_melody": melody_state})

	# Open the tunnel landmarks for the next phase.
	advance_landmark_state("bi_shan_tunnel", "available")
	advance_landmark_state("long_shan_tunnel", "available")
