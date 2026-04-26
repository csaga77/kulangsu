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
	_assert_true(_app_state().get_story_route_ids().size() == 4, "Story routes load from modular storyline definitions")
	var family_prep_definition: Dictionary = _app_state().get_story_event_definition("spring_festival_prepared")
	_assert_true(String(family_prep_definition.get("route_id", "")) == "family_memory", "Family preparation remains owned by the family storyline route resource")
	_assert_story_flag_all(
		"trinity_memory_awakened",
		["summer_return_complete"],
		"Church memory now unlocks after the harbor return anchor"
	)
	_assert_story_flag_all(
		"autumn_pressure_named",
		["summer_return_complete"],
		"Autumn pressure now opens only after the harbor return settles"
	)
	_assert_story_flag_all(
		"preservation_inheritance_seen",
		["autumn_pressure_named"],
		"Preservation now starts from the harbor after autumn pressure is named"
	)
	_assert_story_flag_all(
		"winter_memory_reveal",
		["autumn_pressure_named", "trinity_memory_awakened"],
		"Winter memory still waits for both the church beat and the autumn turn"
	)
	_assert_story_flag_all(
		"spring_festival_prepared",
		["preservation_inheritance_seen", "winter_memory_reveal"],
		"Spring Festival preparation stays tied to both family memory and preservation"
	)
	_assert_story_flag_all(
		"future_commitment_choice",
		["autumn_pressure_shared", "spring_festival_resolved"],
		"The future-choice beat stays gated behind shared pressure and Spring Festival"
	)
	_assert_story_flag_all(
		"melody_church_restored",
		["melody_ferry_settled"],
		"The Trinity melody beat follows the ferry refrain"
	)
	_assert_story_flag_all(
		"melody_long_shan_restored",
		["melody_church_restored"],
		"Long Shan now follows the church restoration instead of skipping ahead"
	)
	_assert_story_flag_all(
		"harbor_festival_performed",
		["melody_bagua_aligned", "spring_festival_resolved"],
		"The harbor performance stays gated by Bagua alignment and Spring Festival only"
	)
	_assert_story_flag_any(
		"trinity_memory_awakened",
		[],
		"Church memory no longer uses a loose any-of prerequisite"
	)
	_assert_true(!_app_state().can_resolve_story_event("future_commitment_choice"), "Blocked story events now report unavailable through the shared route API")
	var future_choice_blockers: Dictionary = _app_state().get_story_event_blockers("future_commitment_choice")
	_assert_true(
		_sorted_strings(future_choice_blockers.get("missing_story_flags_all", [])) == ["autumn_pressure_shared", "spring_festival_resolved"],
		"Future-choice blockers now come from the canonical storyline prerequisites"
	)
	_assert_true(!_app_state().resolve_story_event("future_commitment_choice"), "Direct story-event resolution now refuses blocked route events")

	var pei_opening_too_early: Dictionary = _app_state().interact_with_resident("dock_musician_pei")
	_assert_true(
		String(pei_opening_too_early.get("line", "")).to_lower().contains("homecoming"),
		"Pei now waits for the harbor opening instead of naming autumn pressure too early"
	)
	_assert_true(!bool(_app_state().get_story_flag("autumn_pressure_named", false)), "Early Pei talk no longer resolves the autumn-pressure story event")
	_assert_true(
		int(_app_state().get_resident_profile("dock_musician_pei").get("conversation_index", 0)) == 0,
		"Blocked route-gated resident beats no longer advance resident dialogue progress"
	)
	var mei_opening_too_early: Dictionary = _app_state().interact_with_resident("church_caretaker")
	_assert_true(
		String(mei_opening_too_early.get("line", "")).to_lower().contains("harbor"),
		"Mei now waits for the harbor opening before starting the church-memory route"
	)
	_assert_true(!bool(_app_state().get_story_flag("trinity_memory_awakened", false)), "Early church talk no longer resolves the church-memory story event")
	_assert_true(
		int(_app_state().get_resident_profile("church_caretaker").get("conversation_index", 0)) == 0,
		"Blocked church route beats stay on their current dialogue step"
	)
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

	var pei_too_early: Dictionary = _app_state().interact_with_resident("dock_musician_pei")
	_assert_true(
		String(pei_too_early.get("line", "")).to_lower().contains("spring festival"),
		"The future-choice beat stays gated until both the shared pressure and Spring Festival are ready"
	)
	_assert_true(!bool(_app_state().get_story_flag("future_commitment_choice", false)), "Pei cannot resolve the future choice too early")

	_app_state().interact_with_resident("postcard_seller_an")
	_assert_true(bool(_app_state().get_story_flag("preservation_inheritance_seen", false)), "Preservation now starts at the harbor without requiring Bagua first")

	_app_state().interact_with_resident("choir_student_lin")
	_assert_true(bool(_app_state().get_story_flag("autumn_pressure_shared", false)), "The study route now gets a second shared-pressure beat before the future choice")

	_app_state().interact_with_resident("church_caretaker")
	_assert_true(bool(_app_state().get_story_flag("trinity_memory_awakened", false)), "Trinity awakens the family-memory route without clearing the church landmark")
	_app_state().interact_with_resident("church_caretaker")
	_assert_true(_app_state().season_phase == "winter", "The church memory reveal advances the year into winter")
	_assert_true(bool(_app_state().get_story_flag("winter_memory_reveal", false)), "Winter memory reveal can resolve through route dialogue")

	_app_state().interact_with_resident("tea_vendor_hua")
	_assert_true(bool(_app_state().get_story_flag("spring_festival_prepared", false)), "Spring Festival now has a harbor-preparation step before Lian resolves it")

	var lian_result: Dictionary = _app_state().interact_with_resident("ferry_caretaker")
	_assert_true(String(lian_result.get("line", "")).to_lower().contains("festival"), "Cross-route family dialogue changes once winter memory and preservation align")
	_assert_true(_app_state().season_phase == "spring_festival", "The harbor conversation advances the year into spring festival")
	_assert_true(bool(_app_state().get_story_flag("spring_festival_resolved", false)), "Spring festival anchor resolves from the family route")
	_assert_true(!bool(_app_state().endgame_state.get("active", false)), "Resolving spring festival alone does not start the final act")

	_assert_true(_app_state().can_resolve_story_event("future_commitment_choice"), "The shared route API reports when the future-choice beat becomes available")
	_app_state().interact_with_resident("dock_musician_pei")
	_assert_true(bool(_app_state().get_story_flag("future_commitment_choice", false)), "Pei can resolve the future-choice beat once spring and shared pressure are both settled")
	_assert_true(!bool(_app_state().endgame_state.get("active", false)), "Naming a future does not end the game until a designated major event lands")

	_app_state().interact_with_resident("dock_musician_pei")
	_assert_true(bool(_app_state().get_story_flag("summer_exam_complete", false)), "The exam completion beat can resolve without finishing the landmark melody route")
	_assert_true(bool(_app_state().endgame_state.get("active", false)), "A designated major event starts the final act")
	_assert_true(_app_state().season_phase == "endgame", "The final act replaces the normal seasonal phase once it starts")
	_assert_true(String(_app_state().endgame_state.get("trigger_event_id", "")) == "summer_exam_complete", "Exam completion is stored as the active endgame trigger")
	_assert_true(_app_state().get_endgame_behavior() == "end_run", "Exam completion is classified as a hard ending")
	_assert_true(_app_state().get_active_lead_id() == "summer_exam_complete", "Endgame pins the closing lead")
	_assert_true(_app_state().get_landmark_state("bagua_tower") == "locked", "The landmark route can remain largely untouched without blocking the seasonal mainline")
	_assert_true(_app_state().get_landmark_state("festival_stage") == "locked", "Second-summer endings do not require the harbor festival route")
	_assert_true(!_app_state().can_continue_after_endgame(), "Hard endings do not offer the continue-story path")
	_assert_true(!_app_state().continue_story_after_endgame(), "Hard endings refuse to clear into continued story play")

	_app_state().save_story_autosave()
	_app_state().configure_free_walk()
	_assert_true(_app_state().configure_continue(), "Continue can restore a saved final-act state")
	_assert_true(bool(_app_state().endgame_state.get("active", false)), "Endgame state survives autosave and continue")
	_assert_true(String(_app_state().endgame_state.get("trigger_event_id", "")) == "summer_exam_complete", "Continue preserves the exam-driven endgame trigger")
	_assert_true(_app_state().get_endgame_behavior() == "end_run", "Continue preserves the hard-ending classification")
	_app_state().apply_ending_choice("leave")
	_assert_true(String(_app_state().ending_summary.get("ending_tones", "")).contains("departure"), "Departure choices still add a departure tone on hard endings")

	_app_state().configure_new_game()
	_progress_through_ferry_opening()
	_app_state().interact_with_resident("dock_musician_pei")
	_app_state().interact_with_resident("postcard_seller_an")
	_app_state().interact_with_resident("choir_student_lin")
	_app_state().interact_with_resident("church_caretaker")
	_app_state().interact_with_resident("church_caretaker")
	_app_state().interact_with_resident("tea_vendor_hua")
	_app_state().interact_with_resident("ferry_caretaker")
	_app_state().interact_with_resident("dock_musician_pei")
	_app_state().interact_with_resident("ticket_clerk_min")
	_assert_true(bool(_app_state().get_story_flag("future_commitment_witnessed", false)), "Ticket Clerk Min now witnesses the future choice before it can become an ending")
	_assert_true(!bool(_app_state().endgame_state.get("active", false)), "Witnessing the future choice alone does not start the final act")
	_app_state().interact_with_resident("ferry_caretaker")
	_assert_true(bool(_app_state().get_story_flag("future_commitment_end", false)), "Lian now closes the honest-future ending after the harbor witnesses it")
	_assert_true(bool(_app_state().endgame_state.get("active", false)), "The honest-future ending can still start the final act once the harbor answers it")
	_assert_true(String(_app_state().endgame_state.get("trigger_event_id", "")) == "future_commitment_end", "The honest-future ending stores the correct endgame trigger")
	_assert_true(_app_state().get_endgame_behavior() == "end_run", "The honest-future ending is also classified as a hard ending")

	_app_state().configure_new_game()
	_progress_through_ferry_opening()
	_app_state().interact_with_resident("dock_musician_pei")
	_app_state().interact_with_resident("postcard_seller_an")
	_app_state().advance_landmark_state("bagua_tower", "available")
	_app_state().refresh_story_routes()
	_app_state().interact_with_resident("terrace_painter_nian")
	_assert_true(bool(_app_state().get_story_flag("preservation_tower_perspective", false)), "Preservation now gets a Bagua follow-up beat once the tower is reachable")

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


func _assert_story_flag_all(event_id: String, expected: Array[String], label: String) -> void:
	_assert_true(_event_story_flags(event_id, "story_flags_all") == _sorted_strings(expected), label)


func _assert_story_flag_any(event_id: String, expected: Array[String], label: String) -> void:
	_assert_true(_event_story_flags(event_id, "story_flags_any") == _sorted_strings(expected), label)


func _event_story_flags(event_id: String, key: String) -> Array[String]:
	var definition: Dictionary = _app_state().get_story_event_definition(event_id)
	var prerequisites: Dictionary = definition.get("prerequisites", {})
	return _sorted_strings(prerequisites.get(key, []))


func _normalize_string_array(value: Variant) -> PackedStringArray:
	var output := PackedStringArray()
	if value is PackedStringArray:
		for entry in value:
			output.append(String(entry))
		return output
	if value is Array:
		for entry in value:
			output.append(String(entry))
	return output


func _sorted_strings(value: Variant) -> Array[String]:
	var output: Array[String] = []
	for entry in _normalize_string_array(value):
		output.append(String(entry))
	output.sort()
	return output
