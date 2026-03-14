@tool
extends Node

signal mode_changed(mode: String)
signal chapter_changed(chapter: String)
signal location_changed(location: String)
signal objective_changed(objective: String)
signal hint_changed(hint: String)
signal save_status_changed(status: String)
signal fragments_changed(found: int, total: int)
signal landmarks_changed(landmarks: PackedStringArray)
signal residents_changed(residents: PackedStringArray)
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
var residents: PackedStringArray = _default_residents()
var ending_summary := {
	"fragments": "4 / 4",
	"residents": "4",
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


func set_landmarks(new_landmarks: PackedStringArray) -> void:
	landmarks = new_landmarks
	landmarks_changed.emit(landmarks)


func set_residents(new_residents: PackedStringArray) -> void:
	residents = new_residents
	residents_changed.emit(residents)


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


func _default_residents() -> PackedStringArray:
	return PackedStringArray([
		"Caretaker",
		"Ferry Worker",
		"Tunnel Guide",
		"Tower Keeper",
	])


func configure_new_game() -> void:
	set_mode("Story")
	set_chapter("Arrival")
	set_location("Piano Ferry")
	set_objective("Find out why the island feels quiet today.")
	set_hint("R Inspect   J Journal   Esc Pause")
	set_save_status("Autosave: prototype checkpoint ready")
	set_fragments(0, 4)
	set_landmarks(_default_landmarks())
	set_residents(_default_residents())
	set_summary({
		"fragments": "4 / 4",
		"residents": "4",
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


func configure_free_walk() -> void:
	set_mode("Free Walk")
	set_chapter("Free Walk")
	set_location("Piano Ferry")
	set_objective("Wander the island and learn how the first district wants to be introduced.")
	set_hint("R Inspect   J Journal   Esc Pause")
	set_save_status("Autosave: free walk sandbox ready")
	set_fragments(0, 4)


func configure_postgame() -> void:
	set_mode("Postgame")
	set_chapter("Festival Night")
	set_location("Ferry Plaza")
	set_objective("Wander the island after the festival.")
	set_hint("R Inspect   J Journal   Esc Pause")
	set_save_status("Autosave: postgame prototype checkpoint ready")
	set_fragments(4, 4)
