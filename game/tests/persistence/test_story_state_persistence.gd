extends Node2D

const TEST_AUTOSAVE_PATH := "user://story_state_persistence.save"
const OVERRIDE_PATH := "res://game/residents/definitions/terrace_painter_nian.tres"
const APP_RUNTIME := preload("res://game/app_runtime.gd")

var m_failures := PackedStringArray()


func _app_state():
	return APP_RUNTIME.get_app_state(self)


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_app_state().override_story_autosave_path_for_tests(TEST_AUTOSAVE_PATH)
	_app_state().clear_story_autosave_for_tests()

	_app_state().configure_new_game()
	_progress_through_ferry_opening()
	_app_state().set_story_flag("custom_route_echo", "afterglow")
	_app_state()._seed_resident_progress(
		"terrace_painter_nian",
		1,
		2,
		"introduced",
		"External override persisted."
	)
	_assert_true(
		String(_app_state().get_resident_definition("terrace_painter_nian").resource_path) == OVERRIDE_PATH,
		"Terrace Painter Nian still comes from the external override resource"
	)

	_app_state().save_story_autosave()
	_app_state().configure_free_walk()
	_assert_true(_app_state().configure_continue(), "Continue restores the saved story state persistence test")
	_assert_true(
		String(_app_state().get_story_flag("custom_route_echo", "")) == "afterglow",
		"Unknown story flags still persist across autosave and continue"
	)

	var nian_profile: Dictionary = _app_state().get_resident_profile("terrace_painter_nian")
	_assert_true(bool(nian_profile.get("known", false)), "Override-backed resident profiles stay introduced after continue")
	_assert_true(
		int(nian_profile.get("conversation_index", 0)) == 1,
		"Override-backed resident profiles keep their conversation index after continue"
	)
	_assert_true(
		int(nian_profile.get("trust", 0)) == 2,
		"Override-backed resident profiles keep their trust value after continue"
	)
	_assert_true(
		String(nian_profile.get("quest_state", "")) == "introduced",
		"Override-backed resident profiles keep their quest state after continue"
	)
	_assert_true(
		String(nian_profile.get("current_step", "")) == "External override persisted.",
		"Override-backed resident profiles keep their current journal step after continue"
	)

	_app_state().clear_story_autosave_for_tests()

	if m_failures.is_empty():
		print("PASS: story state persistence")
	else:
		for failure in m_failures:
			push_error(failure)
		push_error("Story state persistence failed with %d issue(s)." % m_failures.size())

	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0 if m_failures.is_empty() else 1)


func _progress_through_ferry_opening() -> void:
	_app_state().interact_with_resident("ferry_caretaker")
	_app_state().activate_landmark_trigger("piano_ferry", "harbor_refrain", "Harbor Clue")
	_app_state().interact_with_resident("ferry_caretaker")


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	m_failures.append("%s." % label)
