extends Node

const TEST_AUTOSAVE_PATH := "user://story_routes_test.save"
const APP_RUNTIME := preload("res://game/app_runtime.gd")
const STORY_MOMENT_LEDGER := preload("res://game/story_moment_ledger.gd")

var m_failures := PackedStringArray()
var m_app_state: AppStateService


func _app_state() -> AppStateService:
	return m_app_state


func _view() -> AppStateProjection:
	return m_app_state.get_projection()


func _story_flag(flag_id: String, fallback: Variant = false) -> Variant:
	return m_app_state.get_snapshot().story_flags.get(flag_id, fallback)


func _read_context() -> AppStateReducerContext:
	return AppStateReducerContext.new(AppStateTransition.new(m_app_state.get_snapshot()))


func _ready() -> void:
	m_app_state = AppStateService.new(StorySaveRepository.new(TEST_AUTOSAVE_PATH))
	m_app_state.name = "AppState"
	add_child(m_app_state)
	call_deferred("_run")


func _run() -> void:
	_app_state().clear_story_save()

	_assert_true(_view().season_phase == "summer_1", "Shared state boots in the first summer by default")

	_app_state().start_new_story()
	_assert_true(_view().season_phase == "summer_1", "New game starts in Summer 1")
	_assert_true(_view().route_ids.size() == 4, "Story routes load from modular storyline definitions")
	var family_prep_definition: Dictionary = _view().get_story_event_definition("spring_festival_prepared")
	_assert_true(String(family_prep_definition.get("route_id", "")) == "family_memory", "Family preparation remains owned by the family storyline route resource")
	var household_care_definition: Dictionary = _view().get_story_event_definition(
		"family_household_care_seen"
	)
	_assert_true(
		String(household_care_definition.get("route_id", "")) == "family_memory"
			and _sorted_strings(household_care_definition.get("phase_window", [])) == ["winter"],
		"Household care is an explicitly bounded Winter event in the family route"
	)
	var moment_definition: Dictionary = STORY_MOMENT_LEDGER.definition_for_moment(
		"family_household_care"
	)
	_assert_true(
		String(moment_definition.get("completed_event_id", "")) == "family_household_care_seen"
			and String(moment_definition.get("missed_fact_id", "")) == "family_household_care_missed"
			and String(moment_definition.get("opener_event_id", "")) == "winter_memory_reveal"
			and String(moment_definition.get("closer_event_id", "")) == "spring_festival_prepared",
		"The story-moment ledger exposes one explicit household-care policy"
	)
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
	_assert_route_score_min_uses_all_route_completion()
	_assert_true(!_read_context().can_resolve_story_event("future_commitment_choice"), "Blocked story events now report unavailable through the shared route API")
	var future_choice_blockers: Dictionary = _read_context().get_story_event_blockers("future_commitment_choice")
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
	_assert_true(!bool(_story_flag("autumn_pressure_named", false)), "Early Pei talk no longer resolves the autumn-pressure story event")
	_assert_true(
		int(_view().get_resident_profile("dock_musician_pei").get("conversation_index", 0)) == 0,
		"Blocked route-gated resident beats no longer advance resident dialogue progress"
	)
	var mei_opening_too_early: Dictionary = _app_state().interact_with_resident("church_caretaker")
	_assert_true(
		String(mei_opening_too_early.get("line", "")).to_lower().contains("harbor"),
		"Mei now waits for the harbor opening before starting the church-memory route"
	)
	_assert_true(!bool(_story_flag("trinity_memory_awakened", false)), "Early church talk no longer resolves the church-memory story event")
	_assert_true(
		int(_view().get_resident_profile("church_caretaker").get("conversation_index", 0)) == 0,
		"Blocked church route beats stay on their current dialogue step"
	)
	_assert_true(_view().available_lead_ids.size() >= 2, "New game seeds multiple live routes")
	_assert_true(!_view().active_lead_id.is_empty(), "New game pins one HUD lead")
	_assert_true(
		_normalize_string_array(
			_view().get_route_progress("family_memory").get("blocked_beat_ids", [])
		).has("family_household_care_seen"),
		"Household care stays blocked before the Winter memory reveal"
	)

	_progress_through_ferry_opening()
	_assert_true(bool(_story_flag("summer_return_complete", false)), "Ferry opening resolves the family return anchor")
	_assert_true(_view().available_lead_ids.size() >= 3, "Opening the island exposes multiple concurrent route leads")

	_app_state().cycle_story_lead(1)
	var pinned_lead_id: String = _view().active_lead_id
	_assert_true(!pinned_lead_id.is_empty(), "Cycling story leads pins a manual lead selection")
	_app_state().request_autosave()
	_app_state().start_free_walk()
	_assert_true(_view().available_lead_ids.is_empty(), "Free Walk clears the story lead list")
	_assert_true(_view().active_lead_id.is_empty(), "Free Walk clears the active story lead")
	_assert_true(_app_state().resume_story(), "Continue restores the story-routes autosave")
	_assert_true(_view().active_lead_id == pinned_lead_id, "Manual lead pinning survives autosave and continue")

	_app_state().start_new_story()
	_progress_through_ferry_opening()
	_app_state().interact_with_resident("dock_musician_pei")
	_assert_true(_view().season_phase == "autumn_study", "Pei names the autumn study pressure")
	_assert_true(bool(_story_flag("autumn_pressure_named", false)), "Autumn pressure anchor resolves from the harbor route")

	var pei_too_early: Dictionary = _app_state().interact_with_resident("dock_musician_pei")
	_assert_true(
		String(pei_too_early.get("line", "")).to_lower().contains("spring festival"),
		"The future-choice beat stays gated until both the shared pressure and Spring Festival are ready"
	)
	_assert_true(!bool(_story_flag("future_commitment_choice", false)), "Pei cannot resolve the future choice too early")

	_app_state().interact_with_resident("postcard_seller_an")
	_assert_true(bool(_story_flag("preservation_inheritance_seen", false)), "Preservation now starts at the harbor without requiring Bagua first")

	_app_state().interact_with_resident("choir_student_lin")
	_assert_true(bool(_story_flag("autumn_pressure_shared", false)), "The study route now gets a second shared-pressure beat before the future choice")

	_app_state().interact_with_resident("church_caretaker")
	_assert_true(bool(_story_flag("trinity_memory_awakened", false)), "Trinity awakens the family-memory route without clearing the church landmark")
	_app_state().interact_with_resident("church_caretaker")
	_assert_true(_view().season_phase == "winter", "The church memory reveal advances the year into winter")
	_assert_true(bool(_story_flag("winter_memory_reveal", false)), "Winter memory reveal can resolve through route dialogue")
	var family_before_close: Dictionary = _view().get_route_progress("family_memory")
	_assert_true(
		_normalize_string_array(
			family_before_close.get("available_beat_ids", [])
		).has("family_household_care_seen"),
		"Household care opens only after the Winter memory reveal"
	)
	var family_score_before_close := int(family_before_close.get("completion_score", 0))

	_app_state().interact_with_resident("tea_vendor_hua")
	_assert_true(bool(_story_flag("spring_festival_prepared", false)), "Spring Festival now has a harbor-preparation step before Lian resolves it")
	_assert_true(
		bool(_story_flag("family_household_care_missed", false))
			and !bool(_story_flag("family_household_care_seen", false)),
		"Festival preparation closes unresolved household care as one exclusive missed fact"
	)
	var family_after_close: Dictionary = _view().get_route_progress("family_memory")
	_assert_true(
		!_normalize_string_array(
			family_after_close.get("available_beat_ids", [])
		).has("family_household_care_seen")
			and !_normalize_string_array(
				family_after_close.get("blocked_beat_ids", [])
			).has("family_household_care_seen")
			and _normalize_string_array(
				family_after_close.get("missed_beat_ids", [])
			).has("family_household_care_seen"),
		"A missed care beat is terminal instead of remaining available or blocked"
	)
	_assert_true(
		int(family_after_close.get("completion_score", 0)) == family_score_before_close + 1,
		"Missing household care adds no completion score beyond festival preparation itself"
	)
	_assert_true(
		JournalBuilder.build_story_routes_journal_text(_view()).contains(
			"Missed optional beats: 1"
		),
		"The journal distinguishes the missed optional beat from blocked work"
	)
	var saves_after_miss := _app_state().get_save_metadata()
	_assert_true(
		!_app_state().resolve_story_event("family_household_care_seen")
			and bool(_story_flag("family_household_care_missed", false)),
		"Care completion cannot replace a previously committed missed outcome"
	)
	_assert_true(
		_app_state().get_save_metadata() == saves_after_miss,
		"Repeating completion after a miss is a persistence no-op"
	)

	var lian_result: Dictionary = _app_state().interact_with_resident("ferry_caretaker")
	_assert_true(String(lian_result.get("line", "")).to_lower().contains("festival"), "Cross-route family dialogue changes once winter memory and preservation align")
	_assert_true(_view().season_phase == "spring_festival", "The harbor conversation advances the year into spring festival")
	_assert_true(bool(_story_flag("spring_festival_resolved", false)), "Spring festival anchor resolves from the family route")
	_assert_true(!bool(_view().endgame_state.get("active", false)), "Resolving spring festival alone does not start the final act")

	_assert_true(_read_context().can_resolve_story_event("future_commitment_choice"), "The shared route API reports when the future-choice beat becomes available")
	_app_state().interact_with_resident("dock_musician_pei")
	_assert_true(bool(_story_flag("future_commitment_choice", false)), "Pei can resolve the future-choice beat once spring and shared pressure are both settled")
	_assert_true(!bool(_view().endgame_state.get("active", false)), "Naming a future does not end the game until a designated major event lands")

	_app_state().interact_with_resident("dock_musician_pei")
	_assert_true(bool(_story_flag("summer_exam_complete", false)), "The exam completion beat can resolve without finishing the landmark melody route")
	_assert_true(bool(_view().endgame_state.get("active", false)), "A designated major event starts the final act")
	_assert_true(_view().season_phase == "endgame", "The final act replaces the normal seasonal phase once it starts")
	_assert_true(String(_view().endgame_state.get("trigger_event_id", "")) == "summer_exam_complete", "Exam completion is stored as the active endgame trigger")
	_assert_true(String(_view().endgame_state.get("ending_behavior", "")) == "end_run", "Exam completion is classified as a hard ending")
	_assert_true(_view().active_lead_id == "summer_exam_complete", "Endgame pins the closing lead")
	_assert_true(_view().get_landmark_state("bagua_tower") == "locked", "The landmark route can remain largely untouched without blocking the seasonal mainline")
	_assert_true(_view().get_landmark_state("festival_stage") == "locked", "Second-summer endings do not require the harbor festival route")
	_assert_true(String(_view().endgame_state.get("ending_behavior", "")) != "continue_story", "Hard endings do not offer the continue-story path")
	_assert_true(!_app_state().continue_story_after_endgame(), "Hard endings refuse to clear into continued story play")

	_app_state().request_autosave()
	_app_state().start_free_walk()
	_assert_true(_app_state().resume_story(), "Continue can restore a saved final-act state")
	_assert_true(bool(_view().endgame_state.get("active", false)), "Endgame state survives autosave and continue")
	_assert_true(String(_view().endgame_state.get("trigger_event_id", "")) == "summer_exam_complete", "Continue preserves the exam-driven endgame trigger")
	_assert_true(String(_view().endgame_state.get("ending_behavior", "")) == "end_run", "Continue preserves the hard-ending classification")
	_app_state().apply_ending_choice("leave")
	_assert_true(String(_view().ending_summary.get("ending_tones", "")).contains("departure"), "Departure choices still add a departure tone on hard endings")

	_app_state().start_new_story()
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
	_assert_true(bool(_story_flag("future_commitment_witnessed", false)), "Ticket Clerk Min now witnesses the future choice before it can become an ending")
	_assert_true(!bool(_view().endgame_state.get("active", false)), "Witnessing the future choice alone does not start the final act")
	_app_state().interact_with_resident("ferry_caretaker")
	_assert_true(bool(_story_flag("future_commitment_end", false)), "Lian now closes the honest-future ending after the harbor witnesses it")
	_assert_true(bool(_view().endgame_state.get("active", false)), "The honest-future ending can still start the final act once the harbor answers it")
	_assert_true(String(_view().endgame_state.get("trigger_event_id", "")) == "future_commitment_end", "The honest-future ending stores the correct endgame trigger")
	_assert_true(String(_view().endgame_state.get("ending_behavior", "")) == "end_run", "The honest-future ending is also classified as a hard ending")

	_app_state().start_new_story()
	_progress_through_ferry_opening()
	_app_state().interact_with_resident("dock_musician_pei")
	_app_state().interact_with_resident("postcard_seller_an")
	_app_state().apply_story_effects({"unlock_landmark": "bagua_tower"})
	_app_state().interact_with_resident("terrace_painter_nian")
	_assert_true(bool(_story_flag("preservation_tower_perspective", false)), "Preservation now gets a Bagua follow-up beat once the tower is reachable")

	_app_state().start_new_story()
	_app_state().apply_story_effects({
		"season_phase": "winter",
		"story_flags": {
			"winter_memory_reveal": true,
			"preservation_inheritance_seen": true,
		},
	})
	_assert_true(
		_normalize_string_array(
			_view().get_route_progress("family_memory").get("available_beat_ids", [])
		).has("family_household_care_seen"),
		"The care event is available in a normalized open-window fixture"
	)
	_assert_true(
		_app_state().resolve_story_event("family_household_care_seen"),
		"The open care event resolves through the canonical route API"
	)
	_assert_true(
		bool(_story_flag("family_household_care_seen", false))
			and !bool(_story_flag("family_household_care_missed", false)),
		"Completing care publishes only the seen outcome"
	)
	_assert_true(
		_app_state().resolve_story_event("spring_festival_prepared"),
		"Seen care does not block the independent festival-preparation anchor"
	)
	_assert_true(
		bool(_story_flag("family_household_care_seen", false))
			and !bool(_story_flag("family_household_care_missed", false)),
		"Closing an already completed moment preserves its first outcome"
	)
	_assert_true(
		_app_state().resolve_story_event("spring_festival_resolved"),
		"Seen care leaves the main family-route resolution available"
	)
	_assert_true(
		String(_view().ending_summary.get("care_texture", "")).contains("warmth"),
		"The ending summary projects care texture without changing eligibility"
	)

	_app_state().clear_story_save()

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


func _assert_story_flag_all(event_id: String, expected: Array[String], label: String) -> void:
	_assert_true(_event_story_flags(event_id, "story_flags_all") == _sorted_strings(expected), label)


func _assert_story_flag_any(event_id: String, expected: Array[String], label: String) -> void:
	_assert_true(_event_story_flags(event_id, "story_flags_any") == _sorted_strings(expected), label)


func _assert_route_score_min_uses_all_route_completion() -> void:
	var graph := StoryRouteGraph.new(
		AppStateReducerContext.new(AppStateTransition.new(_app_state().get_snapshot()))
	) as StoryRouteGraph
	var saved_route_definitions := graph.m_route_definitions.duplicate(true)
	var saved_event_definitions := graph.m_event_definitions.duplicate(true)
	var saved_route_display_order := graph.m_route_display_order.duplicate()

	graph.m_route_definitions = {
		"early_route": {
			"id": "early_route",
			"display_name": "Early Route",
			"display_order": 1,
			"pin_priority": 10,
		},
		"late_route": {
			"id": "late_route",
			"display_name": "Late Route",
			"display_order": 2,
			"pin_priority": 9,
		},
	}
	graph.m_event_definitions = {
		"early_score_gate": {
			"id": "early_score_gate",
			"route_id": "early_route",
			"lead_text": "This beat depends on a later route score.",
			"prerequisites": {
				"route_score_min": {"late_route": 1},
			},
		},
		"late_route_resolved": {
			"id": "late_route_resolved",
			"route_id": "late_route",
			"lead_text": "This later route beat is already complete.",
			"completion_score": 1,
		},
	}
	graph.m_route_display_order = ["early_route", "late_route"]

	var flags := graph.build_default_story_flags()
	flags["late_route_resolved"] = true
	var snapshot: Dictionary = graph._compute_route_snapshot(
		flags,
		"summer_1",
		StoryRouteGraph.default_endgame_state(),
		"",
		true
	)
	var route_progress: Dictionary = snapshot.get("route_progress", {})
	var early_route_progress: Dictionary = route_progress.get("early_route", {})
	var early_available_ids := _normalize_string_array(early_route_progress.get("available_beat_ids", []))
	_assert_true(
		early_available_ids.has("early_score_gate"),
		"Route score gates can see completed scores from later display-order routes"
	)

	graph.m_route_definitions = saved_route_definitions
	graph.m_event_definitions = saved_event_definitions
	graph.m_route_display_order = saved_route_display_order


func _event_story_flags(event_id: String, key: String) -> Array[String]:
	var definition: Dictionary = _view().get_story_event_definition(event_id)
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
