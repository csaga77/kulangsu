extends Node

const FIXTURE := preload(
	"res://game/tests/persistence/fixtures/bagua_ascent_continue_fixture.gd"
)
const STORY_SAVE_REPOSITORY := preload("res://game/app_state/story_save_repository.gd")
const BACKUP_PATH := "user://story_autosave.milestone_b_backup.save"
const MAIN_SCENE_PATH := "res://main.tscn"


func _ready() -> void:
	call_deferred("_prepare_fixture")


func _prepare_fixture() -> void:
	var repository := STORY_SAVE_REPOSITORY.new()
	if !_preserve_existing_save(repository):
		get_tree().quit(1)
		return
	if !repository.save_payload(FIXTURE.build_payload()):
		push_error("Could not write the Bagua pre-ascent Continue fixture.")
		get_tree().quit(1)
		return

	print(
		(
			"Prepared Milestone B Bagua pre-ascent Continue fixture. "
			+ "The previous autosave remains preserved at %s."
		) % BACKUP_PATH
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
		push_error("Could not create the Milestone B autosave backup.")
		return false
	backup_file.store_var({
		"had_save": repository.exists(),
		"payload": repository.load_payload(),
	}, false)
	backup_file.flush()
	return true
