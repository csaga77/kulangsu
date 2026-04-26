extends Node2D

const TEST_AUTOSAVE_PATH := "user://resident_interaction_test.save"
const APP_RUNTIME := preload("res://game/app_runtime.gd")

var m_failures := PackedStringArray()
var m_story_milestones: Array[Dictionary] = []


func _app_state():
	return APP_RUNTIME.get_app_state(self)


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_app_state().override_story_autosave_path_for_tests(TEST_AUTOSAVE_PATH)
	_app_state().clear_story_autosave_for_tests()
	if !_app_state().story_milestone.is_connected(_on_story_milestone):
		_app_state().story_milestone.connect(_on_story_milestone)

	_app_state().configure_new_game()
	var pei_too_early: Dictionary = _app_state().interact_with_resident("dock_musician_pei")
	_assert_true(
		String(pei_too_early.get("line", "")).to_lower().contains("homecoming"),
		"Resident interaction now falls back when a story-event beat is blocked by route prerequisites"
	)
	_assert_true(
		int(_app_state().get_resident_profile("dock_musician_pei").get("conversation_index", 0)) == 0,
		"Blocked route-gated resident beats do not advance conversation progress"
	)
	_assert_true(
		!bool(_app_state().get_story_flag("autumn_pressure_named", false)),
		"Blocked route-gated resident beats do not resolve their story event"
	)

	_app_state().configure_new_game()
	var lian_intro: Dictionary = _app_state().interact_with_resident("ferry_caretaker")
	_assert_true(
		String(lian_intro.get("line", "")).to_lower().contains("old piano crate"),
		"Ferry caretaker still opens with the harbor-clue onboarding beat"
	)
	_assert_true(
		int(_app_state().get_resident_profile("ferry_caretaker").get("conversation_index", 0)) == 1,
		"Ferry caretaker advances to the second beat after the intro"
	)

	var lian_gated: Dictionary = _app_state().interact_with_resident("ferry_caretaker")
	_assert_true(
		String(lian_gated.get("line", "")).to_lower().contains("old piano crate"),
		"Gate fallback still repeats the harbor-clue requirement before the ferry trigger is found"
	)
	_assert_true(
		int(_app_state().get_resident_profile("ferry_caretaker").get("conversation_index", 0)) == 1,
		"Gate fallback does not advance ferry caretaker dialogue progress"
	)

	_progress_through_ferry_opening()
	_restore_first_fragment()

	var lian_fragment: Dictionary = _app_state().interact_with_resident("ferry_caretaker")
	_assert_true(
		String(lian_fragment.get("line", "")).to_lower().contains("church phrase came home"),
		"Ferry caretaker still reacts to the first restored fragment through the conditional follow-up beat"
	)
	_assert_true(
		int(_app_state().get_resident_profile("ferry_caretaker").get("trust", 0)) == 3,
		"Ferry caretaker still reaches max trust after the first-fragment return"
	)
	_assert_true(
		_has_story_milestone("resident_trust_max", {"resident_id": "ferry_caretaker"}),
		"Resident trust-max milestone still fires when the first-fragment return completes Lian's arc"
	)

	m_story_milestones.clear()
	_app_state().configure_new_game()
	_progress_through_ferry_opening()
	_app_state().interact_with_resident("dock_musician_pei")
	_app_state().interact_with_resident("postcard_seller_an")
	_assert_true(
		bool(_app_state().get_story_flag("preservation_inheritance_seen", false)),
		"Postcard Seller An still advances the preservation route from resident interaction"
	)

	_app_state().configure_free_walk()
	_assert_true(_app_state().configure_continue(), "Continue still reloads resident-driven autosave state")
	_assert_true(_app_state().mode == "Story", "Continue restores Story mode after resident interaction autosave")
	_assert_true(
		bool(_app_state().get_story_flag("preservation_inheritance_seen", false)),
		"Resident-driven preservation progress survives autosave and continue"
	)

	_app_state().configure_new_game()
	_progress_to_exam_ending()
	var pei_repeat_exam: Dictionary = _app_state().interact_with_resident("dock_musician_pei")
	_assert_true(
		String(pei_repeat_exam.get("line", "")).to_lower().contains("exam is finally over"),
		"Resolved story-event beats replay their authored line instead of reporting the route gate as blocked"
	)

	_app_state().clear_story_autosave_for_tests()

	if m_failures.is_empty():
		print("PASS: resident interaction flow")
	else:
		for failure in m_failures:
			push_error(failure)
		push_error("Resident interaction flow failed with %d issue(s)." % m_failures.size())

	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0 if m_failures.is_empty() else 1)


func _progress_through_ferry_opening() -> void:
	_app_state().interact_with_resident("ferry_caretaker")
	_app_state().activate_landmark_trigger("piano_ferry", "harbor_refrain", "Harbor Clue")
	_app_state().interact_with_resident("ferry_caretaker")


func _restore_first_fragment() -> void:
	_app_state().interact_with_resident("church_caretaker")
	_app_state().interact_with_resident("church_caretaker")
	_app_state().activate_landmark_trigger("trinity_church", "steps", "Steps")
	_app_state().activate_landmark_trigger("trinity_church", "garden", "Garden")
	_app_state().activate_landmark_trigger("trinity_church", "yard", "Yard")
	_app_state().activate_landmark_trigger("trinity_church", "choir_chime", "Choir Chime")
	_app_state().complete_prompt_request({"completion_kind": "trinity_chime"})
	_app_state().interact_with_resident("church_caretaker")


func _progress_to_exam_ending() -> void:
	_progress_through_ferry_opening()
	_app_state().interact_with_resident("dock_musician_pei")
	_app_state().interact_with_resident("postcard_seller_an")
	_app_state().interact_with_resident("choir_student_lin")
	_app_state().interact_with_resident("church_caretaker")
	_app_state().interact_with_resident("church_caretaker")
	_app_state().interact_with_resident("tea_vendor_hua")
	_app_state().interact_with_resident("ferry_caretaker")
	_app_state().interact_with_resident("dock_musician_pei")
	_app_state().interact_with_resident("dock_musician_pei")


func _on_story_milestone(milestone_id: String, context: Dictionary) -> void:
	m_story_milestones.append({
		"id": milestone_id,
		"context": context.duplicate(true),
	})


func _has_story_milestone(milestone_id: String, expected_context: Dictionary = {}) -> bool:
	for entry in m_story_milestones:
		if String(entry.get("id", "")) != milestone_id:
			continue
		var context: Dictionary = entry.get("context", {})
		var matched := true
		for context_key in expected_context.keys():
			if context.get(context_key) != expected_context[context_key]:
				matched = false
				break
		if matched:
			return true
	return false


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	m_failures.append("%s." % label)
