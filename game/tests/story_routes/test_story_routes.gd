extends Node2D

const TEST_AUTOSAVE_PATH := "user://story_routes_test.save"
const APP_RUNTIME := preload("res://game/app_runtime.gd")

var m_failures := PackedStringArray()


func _app_state():
	return APP_RUNTIME.get_app_state(self)


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_app_state().override_story_autosave_path_for_tests(TEST_AUTOSAVE_PATH)
	_app_state().clear_story_autosave_for_tests()

	_assert_true(_app_state().season_phase == "summer_1", "Shared state boots in the first summer by default")

	_app_state().configure_new_game()
	_assert_true(_app_state().season_phase == "summer_1", "New game starts in Summer 1")
	_assert_true(_app_state().get_available_lead_ids().size() >= 2, "New game seeds multiple live routes")
	_assert_true(!_app_state().get_active_lead_id().is_empty(), "New game pins one HUD lead")

	_progress_through_ferry_opening()
	_assert_true(bool(_app_state().get_story_flag("summer_return_complete", false)), "Ferry opening resolves the family return anchor")
	_assert_true(_app_state().get_available_lead_ids().size() >= 3, "Opening the island exposes multiple concurrent route leads")

	_app_state().cycle_story_lead(1)
	var pinned_lead_id: String = _app_state().get_active_lead_id()
	_assert_true(!pinned_lead_id.is_empty(), "Cycling story leads pins a manual lead selection")
	_app_state().save_story_autosave()
	_app_state().configure_free_walk()
	_assert_true(_app_state().configure_continue(), "Continue restores the story-routes autosave")
	_assert_true(_app_state().get_active_lead_id() == pinned_lead_id, "Manual lead pinning survives autosave and continue")

	_app_state().configure_new_game()
	_progress_through_ferry_opening()
	_app_state().interact_with_resident("dock_musician_pei")
	_assert_true(_app_state().season_phase == "autumn_study", "Pei names the autumn study pressure")
	_assert_true(bool(_app_state().get_story_flag("autumn_pressure_named", false)), "Autumn pressure anchor resolves from the harbor route")

	_app_state().interact_with_resident("church_caretaker")
	_assert_true(bool(_app_state().get_story_flag("trinity_memory_awakened", false)), "Trinity awakens the family-memory route without clearing the church landmark")
	_app_state().interact_with_resident("church_caretaker")
	_assert_true(_app_state().season_phase == "winter", "The church memory reveal advances the year into winter")
	_assert_true(bool(_app_state().get_story_flag("winter_memory_reveal", false)), "Winter memory reveal can resolve through route dialogue")

	_app_state().interact_with_resident("terrace_painter_nian")
	_assert_true(bool(_app_state().get_story_flag("preservation_inheritance_seen", false)), "Preservation route can advance from the tower district without finishing the melody arc")

	var lian_result: Dictionary = _app_state().interact_with_resident("ferry_caretaker")
	_assert_true(String(lian_result.get("line", "")).to_lower().contains("festival"), "Cross-route family dialogue changes once winter memory and preservation align")
	_assert_true(_app_state().season_phase == "spring_festival", "The harbor conversation advances the year into spring festival")
	_assert_true(bool(_app_state().get_story_flag("spring_festival_resolved", false)), "Spring festival anchor resolves from the family route")
	_assert_true(!bool(_app_state().endgame_state.get("active", false)), "Resolving spring festival alone does not start the final act")

	_app_state().interact_with_resident("dock_musician_pei")
	_assert_true(bool(_app_state().get_story_flag("future_commitment_choice", false)), "Pei can resolve the future-choice beat once spring is settled")
	_assert_true(!bool(_app_state().endgame_state.get("active", false)), "Naming a future does not end the game until a designated major event lands")

	_app_state().interact_with_resident("dock_musician_pei")
	_assert_true(bool(_app_state().get_story_flag("summer_exam_complete", false)), "The exam completion beat can resolve without finishing the landmark melody route")
	_assert_true(bool(_app_state().endgame_state.get("active", false)), "A designated major event starts the final act")
	_assert_true(_app_state().season_phase == "endgame", "The final act replaces the normal seasonal phase once it starts")
	_assert_true(String(_app_state().endgame_state.get("trigger_event_id", "")) == "summer_exam_complete", "Exam completion is stored as the active endgame trigger")
	_assert_true(_app_state().get_active_lead_id() == "summer_exam_complete", "Endgame pins the closing lead")
	_assert_true(_app_state().get_landmark_state("bagua_tower") == "locked", "The landmark route can remain largely untouched without blocking the seasonal mainline")
	_assert_true(_app_state().get_landmark_state("festival_stage") == "locked", "Second-summer endings do not require the harbor festival route")

	_app_state().save_story_autosave()
	_app_state().configure_free_walk()
	_assert_true(_app_state().configure_continue(), "Continue can restore a saved final-act state")
	_assert_true(bool(_app_state().endgame_state.get("active", false)), "Endgame state survives autosave and continue")
	_assert_true(String(_app_state().endgame_state.get("trigger_event_id", "")) == "summer_exam_complete", "Continue preserves the exam-driven endgame trigger")

	_app_state().apply_ending_choice("stay")
	_assert_true(String(_app_state().ending_summary.get("ending_tones", "")).contains("lingering"), "Stay-style endings add a lingering tone")
	_app_state().configure_postgame()
	_assert_true(_app_state().mode == "Postgame", "Stay-style endings unlock postgame exploration")
	_assert_true(_app_state().season_phase == "postgame", "Postgame swaps the season label into the afterword phase")
	_assert_true(String(_app_state().ending_summary.get("ending_tones", "")).contains("lingering"), "Postgame keeps the stay-ending tone summary")

	_app_state().clear_story_autosave_for_tests()

	if m_failures.is_empty():
		print("PASS: story route architecture flow")
	else:
		for failure in m_failures:
			push_error(failure)
		push_error("Story route architecture flow failed with %d issue(s)." % m_failures.size())

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
