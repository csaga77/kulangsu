extends Node2D

const GAME_SCENE: PackedScene = preload("res://scenes/game_main.tscn")
const TEST_AUTOSAVE_PATH := "user://story_autosave_test.save"

var m_failures := PackedStringArray()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	AppState.override_story_autosave_path_for_tests(TEST_AUTOSAVE_PATH)
	AppState.clear_story_autosave_for_tests()

	_assert_true(!AppState.has_story_autosave(), "Test autosave path starts empty")

	AppState.configure_new_game()
	_assert_true(AppState.has_story_autosave(), "New game writes the first story autosave")
	_assert_true(AppState.get_story_save_metadata().get("resume_location", "") == "Piano Ferry", "New game metadata points to Piano Ferry")

	AppState.interact_with_resident("ferry_caretaker")
	AppState.activate_landmark_trigger("piano_ferry", "harbor_refrain", "Harbor Refrain")
	AppState.interact_with_resident("ferry_caretaker")
	AppState.set_story_resume_checkpoint("Trinity Church", "Trinity Church")
	AppState.save_story_autosave()

	var metadata := AppState.get_story_save_metadata()
	_assert_true(bool(metadata.get("exists", false)), "Story autosave metadata reports an available save")
	_assert_true(String(metadata.get("resume_location", "")) == "Trinity Church", "Story autosave metadata keeps the saved resume location")

	AppState.configure_free_walk()
	_assert_true(AppState.mode == "Free Walk", "Free Walk can replace live runtime state before Continue")

	_assert_true(AppState.configure_continue(), "Continue loads the story autosave")
	_assert_true(AppState.mode == "Story", "Continue restores story mode")
	_assert_true(AppState.is_journal_unlocked(), "Continue restores the unlocked journal state")
	_assert_true(AppState.get_landmark_state("piano_ferry") == "reward_collected", "Continue restores ferry onboarding progress")
	_assert_true(AppState.get_landmark_state("trinity_church") == "available", "Continue restores the next unlocked landmark")
	_assert_true(AppState.get_story_resume_anchor_id() == "Trinity Church", "Continue restores the saved resume anchor")
	_assert_true(AppState.get_story_resume_location() == "Trinity Church", "Continue restores the saved resume location label")

	var story_scene := GAME_SCENE.instantiate()
	add_child(story_scene)
	await get_tree().process_frame

	var player := story_scene.get_node("actors/player") as Node2D
	var trinity_anchor := story_scene.get_node("terrain/ground/buildings/TrinityChurch") as Node2D
	var expected_position: Vector2 = story_scene.call("_resolve_actor_anchor_position", player, trinity_anchor, Vector2.ZERO)
	_assert_true(player.global_position.distance_to(expected_position) <= 1.0, "GameMain places the player at the saved Trinity resume anchor")
	story_scene.queue_free()
	await get_tree().process_frame

	AppState.configure_postgame()
	AppState.set_story_resume_checkpoint("Piano Ferry", "Ferry Plaza")
	AppState.save_story_autosave()
	_assert_true(AppState.configure_continue(), "Continue can load a saved postgame state")
	_assert_true(AppState.mode == "Postgame", "Continue restores postgame mode")
	_assert_true(AppState.get_landmark_state("festival_stage") == "reward_collected", "Continue restores the completed festival stage in postgame")
	_assert_true(AppState.get_story_resume_location() == "Ferry Plaza", "Postgame continue keeps the harbor resume label")

	AppState.clear_story_autosave_for_tests()

	if m_failures.is_empty():
		print("PASS: story autosave flow")
	else:
		for failure in m_failures:
			push_error(failure)
		push_error("Story autosave flow failed with %d issue(s)." % m_failures.size())

	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0 if m_failures.is_empty() else 1)


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	m_failures.append("%s." % label)
