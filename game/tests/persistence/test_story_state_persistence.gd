extends Node

const TEST_AUTOSAVE_PATH := "user://story_state_persistence.save"
const OVERRIDE_PATH := "res://game/residents/definitions/terrace_painter_nian.tres"
const APP_RUNTIME := preload("res://game/app_runtime.gd")

var m_failures := PackedStringArray()
var m_app_state: AppStateService


func _app_state() -> AppStateService:
	return m_app_state


func _ready() -> void:
	m_app_state = AppStateService.new(StorySaveRepository.new(TEST_AUTOSAVE_PATH))
	m_app_state.name = "AppState"
	add_child(m_app_state)
	call_deferred("_run")


func _run() -> void:
	_app_state().clear_story_save()

	_app_state().start_new_story()
	_progress_through_ferry_opening()
	_app_state().apply_story_effects({
		"story_flags": {"custom_route_echo": "afterglow"},
	})
	_assert_true(
		String(_app_state().get_projection().get_resident_definition("terrace_painter_nian").resource_path) == OVERRIDE_PATH,
		"Terrace Painter Nian still comes from the external override resource"
	)

	_app_state().request_autosave()
	_app_state().start_free_walk()
	_assert_true(_app_state().resume_story(), "Continue restores the saved story state persistence test")
	_assert_true(
		String(_app_state().get_snapshot().story_flags.get("custom_route_echo", "")) == "afterglow",
		"Unknown story flags still persist across autosave and continue"
	)

	var resident_profile: Dictionary = _app_state().get_projection().get_resident_profile("ferry_caretaker")
	_assert_true(bool(resident_profile.get("known", false)), "Resident profiles stay introduced after continue")
	_assert_true(
		int(resident_profile.get("conversation_index", 0)) >= 1,
		"Resident profiles keep their conversation index after continue"
	)
	_assert_true(
		int(resident_profile.get("trust", 0)) > 0,
		"Resident profiles keep their trust value after continue"
	)
	_assert_true(
		!String(resident_profile.get("quest_state", "")).is_empty(),
		"Resident profiles keep their quest state after continue"
	)
	_assert_true(
		!String(resident_profile.get("current_step", "")).is_empty(),
		"Resident profiles keep their current journal step after continue"
	)

	_app_state().clear_story_save()

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
	_activate_landmark_subject("piano_ferry", "harbor_refrain", "Harbor Clue")
	_app_state().interact_with_resident("ferry_caretaker")


func _activate_landmark_subject(landmark_id: String, trigger_id: String, display_name: String) -> bool:
	var subject_id := "landmark:%s.%s" % [landmark_id, trigger_id]
	var context := {"display_name": display_name}
	var metadata: Dictionary = _app_state().describe_story_subject_metadata(subject_id, context)
	var action := String(metadata.get("action", "")).strip_edges().to_lower()
	if action.is_empty():
		action = "inspect"
	var result: Dictionary = _app_state().activate_story_subject(subject_id, action, context)
	return bool(result.get("consumed", false))


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	m_failures.append("%s." % label)
