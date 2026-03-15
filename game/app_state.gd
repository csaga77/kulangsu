@tool
extends Node

const RESIDENT_CATALOG_SCRIPT := preload("res://game/resident_catalog.gd")
const PLAYER_APPEARANCE_CATALOG_SCRIPT := preload("res://game/player_appearance_catalog.gd")
const PLAYER_COSTUME_CATALOG_SCRIPT := preload("res://game/player_costume_catalog.gd")

signal mode_changed(mode: String)
signal chapter_changed(chapter: String)
signal location_changed(location: String)
signal objective_changed(objective: String)
signal hint_changed(hint: String)
signal save_status_changed(status: String)
signal fragments_changed(found: int, total: int)
signal landmarks_changed(landmarks: PackedStringArray)
signal residents_changed(residents: PackedStringArray)
signal resident_profile_changed(resident_id: String, resident: Dictionary)
signal player_profile_changed(profile: Dictionary)
signal player_costume_changed(costume_id: String, costume: Dictionary)
signal player_costumes_changed(unlocked_ids: PackedStringArray, equipped_costume_id: String)
signal player_appearance_changed(profile: Dictionary, appearance_config: Dictionary)
signal summary_changed(summary: Dictionary)

var mode := "Title"
var chapter := "Arrival"
var location := "Piano Ferry"
var objective := "Find out why the island feels quiet today."
var hint := "R Inspect   J Journal   Esc Pause"
var save_status := "Autosave: ready"
var fragments_found := 0
var fragments_total := 4
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


func get_resident_ids() -> PackedStringArray:
	return PackedStringArray(RESIDENT_CATALOG_SCRIPT.resident_order())


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
	set_fragments(0, 4)
	set_landmarks(_default_landmarks())
	set_resident_profiles(_default_resident_profiles())
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
	set_fragments(2, 4)
	set_landmarks(_default_landmarks())
	set_resident_profiles(_default_resident_profiles())
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
	set_fragments(0, 4)
	set_landmarks(_default_landmarks())
	set_resident_profiles(_default_resident_profiles())
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
	set_fragments(4, 4)
	set_landmarks(_default_landmarks())
	set_resident_profiles(_default_resident_profiles())
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
