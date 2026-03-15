@tool
extends Node

const RESIDENT_CATALOG_SCRIPT := preload("res://game/resident_catalog.gd")

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


func interact_with_resident(resident_id: String) -> Dictionary:
	if !resident_profiles.has(resident_id):
		return {}

	var resident: Dictionary = resident_profiles[resident_id].duplicate(true)
	var dialogue_beats: Array = resident.get("dialogue_beats", [])

	resident["known"] = true

	if dialogue_beats.is_empty():
		resident_profiles[resident_id] = resident
		_sync_known_residents()
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
