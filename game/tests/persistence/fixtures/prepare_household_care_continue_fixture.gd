extends Node

const FIXTURES := preload(
	"res://game/tests/persistence/fixtures/household_care_continue_fixtures.gd"
)
const STORY_SAVE_REPOSITORY := preload("res://game/app_state/story_save_repository.gd")
const BACKUP_PATH := "user://story_autosave.milestone_a_backup.save"
const MAIN_SCENE_PATH := "res://main.tscn"

@export_enum("open_winter", "legacy_post_closer") var fixture_id := "open_winter"


func _ready() -> void:
	call_deferred("_prepare_fixture")


func _prepare_fixture() -> void:
	var payload: Dictionary = FIXTURES.build_payload(fixture_id)
	if payload.is_empty():
		push_error("Unknown household-care Continue fixture: %s" % fixture_id)
		get_tree().quit(1)
		return

	var repository := STORY_SAVE_REPOSITORY.new()
	if !_preserve_existing_save(repository):
		get_tree().quit(1)
		return
	if !repository.save_payload(payload):
		push_error("Could not write the household-care Continue fixture.")
		get_tree().quit(1)
		return

	print(
		(
			"Prepared Milestone A Continue fixture '%s'. "
			+ "The previous autosave remains preserved at %s."
		) % [fixture_id, BACKUP_PATH]
	)
	var change_error := get_tree().change_scene_to_file(MAIN_SCENE_PATH)
	if change_error != OK:
		push_error("Could not open the production title flow after preparing the fixture.")
		get_tree().quit(1)


func _preserve_existing_save(repository) -> bool:
	if FileAccess.file_exists(BACKUP_PATH):
		return true
	var backup_file := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
	if backup_file == null:
		push_error("Could not create the Milestone A autosave backup.")
		return false
	backup_file.store_var({
		"had_save": repository.exists(),
		"payload": repository.load_payload(),
	}, false)
	backup_file.flush()
	return true
