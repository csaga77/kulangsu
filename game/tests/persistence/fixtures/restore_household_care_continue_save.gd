extends Node

const STORY_SAVE_REPOSITORY := preload("res://game/app_state/story_save_repository.gd")
const BACKUP_PATH := "user://story_autosave.milestone_a_backup.save"


func _ready() -> void:
	call_deferred("_restore_save")


func _restore_save() -> void:
	if !FileAccess.file_exists(BACKUP_PATH):
		print("No Milestone A autosave backup was present; nothing changed.")
		get_tree().quit(0)
		return

	var backup_file := FileAccess.open(BACKUP_PATH, FileAccess.READ)
	if backup_file == null:
		push_error("Could not read the Milestone A autosave backup.")
		get_tree().quit(1)
		return
	var backup_value: Variant = backup_file.get_var(false)
	if !(backup_value is Dictionary):
		push_error("The Milestone A autosave backup is malformed; it was left in place.")
		get_tree().quit(1)
		return

	var backup: Dictionary = backup_value
	var repository := STORY_SAVE_REPOSITORY.new()
	if bool(backup.get("had_save", false)):
		var payload_value: Variant = backup.get("payload", {})
		if !(payload_value is Dictionary) or !(repository.save_payload(payload_value)):
			push_error("Could not restore the preserved story autosave.")
			get_tree().quit(1)
			return
	else:
		repository.clear()

	var remove_error := DirAccess.remove_absolute(BACKUP_PATH)
	if remove_error != OK:
		push_error("The story autosave was restored, but the backup marker could not be removed.")
		get_tree().quit(1)
		return
	print("Restored the story autosave that preceded the Milestone A fixture review.")
	get_tree().quit(0)
