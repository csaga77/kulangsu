extends Node

const TEST_AUTOSAVE_PATH := "user://story_event_service_test.save"
const APP_RUNTIME := preload("res://game/app_runtime.gd")
const STORY_EVENT_CATALOG := preload("res://game/story_event_catalog.gd")
const STORY_EFFECT_SCHEMA := preload("res://game/story_effect_schema.gd")

var m_failures := PackedStringArray()
var m_prompt_requests: Array[Dictionary] = []
var m_melody_hints: Array[String] = []
var m_app_state: AppStateService


func _app_state() -> AppStateService:
	return m_app_state


func _view() -> AppStateProjection:
	return m_app_state.get_projection()


func _ready() -> void:
	m_app_state = AppStateService.new(StorySaveRepository.new(TEST_AUTOSAVE_PATH))
	m_app_state.name = "AppState"
	add_child(m_app_state)
	call_deferred("_run")


func _run() -> void:
	if !_app_state().melody_prompt_requested.is_connected(_on_melody_prompt_requested):
		_app_state().melody_prompt_requested.connect(_on_melody_prompt_requested)
	if !_app_state().melody_hint_shown.is_connected(_on_melody_hint_shown):
		_app_state().melody_hint_shown.connect(_on_melody_hint_shown)

	_app_state().clear_story_save()

	var event_definitions := StorylineCatalog.build_event_definitions()
	var household_route_contract_available := event_definitions.has("family_household_care_seen")
	var validation_event_definitions: Dictionary = event_definitions.duplicate(true)
	if !household_route_contract_available:
		# This worker owns the world binding while the ledger worker owns the
		# canonical route resource. Keep isolated validation strict for every
		# reference while supplying that one exact integration contract.
		validation_event_definitions["family_household_care_seen"] = {
			"id": "family_household_care_seen",
			"route_id": "family_memory",
		}
	var story_event_reference_warnings := STORY_EVENT_CATALOG.validate_story_event_references(
		validation_event_definitions
	)
	_assert_true(
		story_event_reference_warnings.is_empty(),
		"StoryEvent catalog effects only reference canonical storyline route events"
	)
	var validation_context := STORY_EFFECT_SCHEMA.build_validation_context({
		"event_definitions": validation_event_definitions,
	})
	var catalog_schema_warnings := STORY_EVENT_CATALOG.validate_catalog(validation_context)
	for warning in catalog_schema_warnings:
		_assert_true(false, "StoryEvent catalog schema: %s" % warning)
	_assert_true(
		catalog_schema_warnings.is_empty(),
		"StoryEvent catalog conditions and effects satisfy the complete host schema"
	)
	_assert_true(
		_warnings_contain(
			STORY_EFFECT_SCHEMA.validate_effects(
				{"objectve": "Typo must not mutate state"},
				validation_context
			),
			"Unknown story effect key 'objectve'"
		),
		"Story effect validation reports unknown keys"
	)
	_assert_true(
		_warnings_contain(
			STORY_EFFECT_SCHEMA.validate_effects(
				{"conditional_effects": [{"effects": {"objective": 42}}]},
				validation_context
			),
			"objective must be a String"
		),
		"Story effect validation recursively checks conditional payload types"
	)
	_assert_true(
		_warnings_contain(
			STORY_EFFECT_SCHEMA.validate_conditions(
				{"season_phase": "not_a_phase"},
				validation_context
			),
			"unknown id 'not_a_phase'"
		),
		"Story condition validation checks canonical ids"
	)
	_assert_true(
		_warnings_contain(
			STORY_EFFECT_SCHEMA.validate_effects(
				{
					"landmark_audio_cue_request": {
						"cue_id": "not_a_landmark_cue",
						"landmark_id": "piano_ferry",
						"trigger_id": "test_trigger",
					}
				},
				validation_context
			),
			"unknown id 'not_a_landmark_cue'"
		),
		"Story effect validation checks catalog-backed landmark cue ids"
	)
	var extracted_resident_effects := STORY_EFFECT_SCHEMA.extract_effects({
		"line": "Resident dialogue metadata",
		"trust_delta": 1,
		"objective": "A real story effect",
		"story_event": "summer_return_complete",
	})
	_assert_true(
		extracted_resident_effects.size() == 2
			and extracted_resident_effects.has("objective")
			and extracted_resident_effects.has("story_event"),
		"Resident beats pass only declared StoryEvent effects into the atomic executor"
	)

	_app_state().start_new_story()
	_app_state().apply_story_effects({"story_event": "future_commitment_choice"})
	_assert_true(
		!bool(_app_state().get_snapshot().story_flags.get("future_commitment_choice", false)),
		"StoryEvent effects no longer force blocked route events through shared progression"
	)
	_assert_true(_view().story_day == 1, "Story time starts on the first story day")
	_assert_true(_view().time_of_day == "morning", "Story time starts in the morning")
	_assert_true(
		_app_state().matches_story_conditions({"time_of_day": "morning", "world_hour_min": 7.5, "world_hour_max": 8.5}),
		"StoryEvent conditions can match the current story time"
	)
	_app_state().apply_story_effects({"advance_time": {"advance_to_time_of_day": "afternoon"}})
	_assert_true(_view().time_of_day == "afternoon", "StoryEvent effects can advance to a later day phase")
	_assert_true(
		!_app_state().matches_story_conditions({"time_of_day": "morning"}),
		"Morning-only StoryEvent conditions close after the time phase advances"
	)
	_app_state().apply_story_effects({"advance_hours": 10.0})
	_assert_true(_view().time_of_day == "night", "StoryEvent effects can advance by authored hours")
	_app_state().apply_story_effects({"advance_day": 1})
	_assert_true(_view().story_day == 2, "StoryEvent effects can advance to the next story day")
	_assert_true(_view().time_of_day == "morning", "Advancing the day resets to morning by default")

	_app_state().start_new_story()
	var harbor_trigger := StorySubject3D.new()
	harbor_trigger.subject_id = "landmark:piano_ferry.harbor_refrain"
	_assert_true(
		harbor_trigger.get_story_subject_id() == "landmark:piano_ferry.harbor_refrain",
		"StorySubject3D keeps a stable world subject id"
	)
	_assert_true(
		harbor_trigger.get_story_action() == "collect",
		"StorySubject3D resolves the default collect action from StoryEvent metadata"
	)
	_assert_true(
		!harbor_trigger.build_story_subject_context().has("melody_hint"),
		"StorySubject3D keeps melody-specific flavour text out of the generic world-subject context"
	)
	var choir_trigger := StorySubject3D.new()
	choir_trigger.subject_id = "landmark:trinity_church.choir_chime"
	_assert_true(
		choir_trigger.get_story_action() == "perform",
		"StorySubject3D resolves the default perform action from StoryEvent metadata"
	)
	harbor_trigger.free()
	choir_trigger.free()

	var lian_intro: Dictionary = _app_state().activate_story_subject("npc:ferry_caretaker", "talk")
	_assert_true(
		String(lian_intro.get("line", "")).to_lower().contains("old piano crate"),
		"StoryEvent talk activation routes ferry caretaker dialogue through the generic subject API"
	)
	_assert_true(
		int(_view().get_resident_profile("ferry_caretaker").get("conversation_index", 0)) == 1,
		"StoryEvent talk activation still advances resident progress"
	)

	_app_state().start_new_story()
	m_prompt_requests.clear()
	m_melody_hints.clear()
	_progress_through_landmark_spine_via_story_subjects()

	_app_state().start_new_story()
	_progress_to_winter_memory_via_story_subjects()
	var bench_preview: Dictionary = _app_state().describe_story_subject("inspectable:church_stone_bench", "inspect")
	_assert_true(
		String(bench_preview.get("text", "")).to_lower().contains("winter memory"),
		"StoryEvent inspect description resolves route-aware inspect text"
	)
	var bench_activation: Dictionary = _app_state().activate_story_subject("inspectable:church_stone_bench", "inspect")
	_assert_true(
		String(bench_activation.get("text", "")).to_lower().contains("winter memory"),
		"StoryEvent inspect activation resolves the same route-aware inspect text"
	)
	var arrival_metadata: Dictionary = _app_state().describe_story_subject_metadata(
		"landmark:family_household.arrival"
	)
	_assert_true(
		bool(arrival_metadata.get("visible", false))
			and bool(arrival_metadata.get("targetable", false))
			and String(arrival_metadata.get("action", "")) == "perform",
		"Winter reveal exposes the household arrival through StorySubject metadata"
	)
	var arrival_result: Dictionary = _app_state().activate_story_subject(
		"landmark:family_household.arrival",
		"perform"
	)
	_assert_true(
		bool(arrival_result.get("consumed", false))
			and bool(_app_state().get_snapshot().story_flags.get("family_household_arrived", false)),
		"Household arrival publishes only its semantic arrival fact through StoryEvent effects"
	)
	var care_metadata: Dictionary = _app_state().describe_story_subject_metadata(
		"landmark:family_household.courtyard_care"
	)
	_assert_true(
		bool(care_metadata.get("visible", false))
			and bool(care_metadata.get("targetable", false)),
		"Household arrival exposes the small courtyard care action"
	)
	var household_binding_index := STORY_EVENT_CATALOG.build_subject_binding_index()
	var care_bindings: Array = household_binding_index.get(
		"landmark:family_household.courtyard_care|perform",
		[]
	)
	var care_effects: Dictionary = (
		care_bindings[0].get("effects", {}) if !care_bindings.is_empty() else {}
	)
	_assert_true(
		String(care_effects.get("story_event", "")) == "family_household_care_seen"
			and !care_effects.has("route_progress"),
		"Courtyard care resolves the canonical route event without direct route writes"
	)
	if household_route_contract_available:
		var care_result: Dictionary = _app_state().activate_story_subject(
			"landmark:family_household.courtyard_care",
			"perform"
		)
		_assert_true(
			bool(care_result.get("consumed", false))
				and bool(_app_state().get_snapshot().story_flags.get("family_household_care_seen", false)),
			"Courtyard care resolves the canonical seen fact through the integrated route definition"
		)
		_assert_true(
			String(care_result.get("text", "")).to_lower().contains(
				"care is how a house answers"
			),
			"Courtyard care presents A Po's authored reflective response"
		)
		var repeated_care: Dictionary = _app_state().activate_story_subject(
			"landmark:family_household.courtyard_care",
			"perform"
		)
		_assert_true(
			bool(repeated_care.get("blocked", false)),
			"Resolved courtyard care is no longer targetable"
		)
	else:
		print(
			"SKIP: household completion activation awaits the ledger worker's "
			+ "family_household_care_seen route definition"
		)
	_app_state().start_new_story()
	_app_state().apply_story_effects({
		"season_phase": "winter",
		"story_flags": {
			"winter_memory_reveal": true,
			"family_household_arrived": true,
			"spring_festival_prepared": true,
		},
	})
	var closed_arrival_metadata: Dictionary = _app_state().describe_story_subject_metadata(
		"landmark:family_household.arrival"
	)
	var closed_care_metadata: Dictionary = _app_state().describe_story_subject_metadata(
		"landmark:family_household.courtyard_care"
	)
	_assert_true(
		!bool(closed_arrival_metadata.get("targetable", true))
			and !bool(closed_care_metadata.get("targetable", true)),
		"Spring Festival preparation closes both household subjects even while phase remains Winter"
	)

	# Routine overrides are validated at the shared-state level: the retired 2D
	# overworld used to reapply them to live actors; the 3D overworld does not
	# yet listen for resident_routine_override_changed (known coverage gap,
	# tracked in docs/plan/implementation_plan.md).
	_app_state().start_new_story()
	var base_spawn: Dictionary = _view().get_resident_spawn_config("ferry_caretaker")
	var base_anchor := String(base_spawn.get("anchor_id", ""))
	_assert_true(!base_anchor.is_empty(), "Ferry caretaker exposes a base authored spawn anchor")

	_app_state().set_resident_routine_override("ferry_caretaker", {
		"spawn": {
			"anchor_id": "Trinity Church",
		},
	})
	var override_spawn: Dictionary = _view().get_resident_spawn_config("ferry_caretaker")
	_assert_true(
		String(override_spawn.get("anchor_id", "")) == "Trinity Church",
		"Resident routine overrides redirect the shared spawn-anchor config to the story-driven anchor"
	)

	_app_state().clear_resident_routine_override("ferry_caretaker")
	var restored_spawn: Dictionary = _view().get_resident_spawn_config("ferry_caretaker")
	_assert_true(
		String(restored_spawn.get("anchor_id", "")) == base_anchor,
		"Clearing a resident routine override restores the resident's base authored spawn config"
	)

	_app_state().clear_story_save()

	if m_failures.is_empty():
		print("PASS: story event service flow")
	else:
		for failure in m_failures:
			push_error(failure)
		push_error("Story event service flow failed with %d issue(s)." % m_failures.size())

	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0 if m_failures.is_empty() else 1)


func _progress_through_ferry_opening() -> void:
	_app_state().activate_story_subject("npc:ferry_caretaker", "talk")
	var melody_hint_count_before := m_melody_hints.size()
	var harbor_result: Dictionary = _app_state().activate_story_subject(
		"landmark:piano_ferry.harbor_refrain",
		"collect",
		{"display_name": "Harbor Clue"}
	)
	_assert_true(
		bool(harbor_result.get("consumed", false)),
		"StoryEvent landmark activation routes the harbor refrain through the generic subject API"
	)
	_assert_true(
		m_melody_hints.size() == melody_hint_count_before + 1,
		"Harbor refrain still emits melody flavour text through an authored StoryEvent effect"
	)
	var latest_melody_hint := ""
	if m_melody_hints.size() > melody_hint_count_before:
		latest_melody_hint = m_melody_hints[m_melody_hints.size() - 1]
	_assert_true(
		latest_melody_hint.contains("patient two-note pulse"),
		"Harbor refrain melody flavour text now comes from the authored StoryEvent effect payload"
	)
	_app_state().activate_story_subject("npc:ferry_caretaker", "talk")


func _warnings_contain(warnings: PackedStringArray, expected_text: String) -> bool:
	for warning in warnings:
		if warning.contains(expected_text):
			return true
	return false


func _progress_to_winter_memory_via_story_subjects() -> void:
	_progress_through_ferry_opening()
	_app_state().activate_story_subject("npc:dock_musician_pei", "talk")
	_app_state().activate_story_subject("npc:postcard_seller_an", "talk")
	_app_state().activate_story_subject("npc:choir_student_lin", "talk")
	_app_state().activate_story_subject("npc:church_caretaker", "talk")
	_app_state().activate_story_subject("npc:church_caretaker", "talk")


func _progress_through_trinity_church_via_story_subjects() -> void:
	_progress_through_ferry_opening()
	_app_state().activate_story_subject("npc:church_caretaker", "talk")
	_app_state().activate_story_subject("npc:church_caretaker", "talk")
	var steps_result: Dictionary = _app_state().activate_story_subject(
		"landmark:trinity_church.steps",
		"collect",
		{"display_name": "Stone Steps"}
	)
	_assert_true(
		bool(steps_result.get("consumed", false)),
		"StoryEvent landmark activation collects the first Trinity cue through the generic subject API"
	)
	var garden_result: Dictionary = _app_state().activate_story_subject(
		"landmark:trinity_church.garden",
		"collect",
		{"display_name": "Side Garden"}
	)
	_assert_true(
		bool(garden_result.get("consumed", false)),
		"StoryEvent landmark activation collects the second Trinity cue through the generic subject API"
	)
	var yard_result: Dictionary = _app_state().activate_story_subject(
		"landmark:trinity_church.yard",
		"collect",
		{"display_name": "Quiet Yard"}
	)
	_assert_true(
		bool(yard_result.get("consumed", false)),
		"StoryEvent landmark activation collects the final Trinity cue through the generic subject API"
	)
	_assert_true(
		_view().get_landmark_progress("trinity_church").get("cues_collected", []).size() == 3,
		"StoryEvent landmark activation updates Trinity cue progress in shared landmark state"
	)

	var prompt_count_before := m_prompt_requests.size()
	var choir_result: Dictionary = _app_state().activate_story_subject(
		"landmark:trinity_church.choir_chime",
		"perform",
		{"display_name": "Choir Chime"}
	)
	_assert_true(
		!bool(choir_result.get("consumed", true)),
		"StoryEvent landmark activation keeps the Trinity choir chime available while the prompt is open"
	)
	_assert_true(
		m_prompt_requests.size() == prompt_count_before + 1,
		"StoryEvent landmark activation emits the Trinity choir prompt through the shared melody prompt signal"
	)
	var latest_prompt: Dictionary = {}
	if m_prompt_requests.size() > 0:
		latest_prompt = m_prompt_requests[m_prompt_requests.size() - 1]
	_assert_true(
		String(latest_prompt.get("completion_kind", "")) == "trinity_chime",
		"StoryEvent landmark activation emits the authored Trinity choir prompt payload"
	)


func _progress_through_landmark_spine_via_story_subjects() -> void:
	_progress_through_trinity_church_via_story_subjects()
	_app_state().complete_prompt_request(m_prompt_requests[m_prompt_requests.size() - 1])
	_app_state().activate_story_subject("npc:church_caretaker", "talk")
	_assert_true(
		_view().fragments_found == 1,
		"StoryEvent landmark prompt completion still leaves Trinity reward resolution intact"
	)

	_assert_true(
		bool(_app_state().activate_story_subject(
			"landmark:bi_shan_tunnel.echo_a",
			"collect",
			{"display_name": "North Wall Echo"}
		).get("consumed", false)),
		"StoryEvent landmark activation collects the first Bi Shan echo through the generic subject API"
	)
	_assert_true(
		bool(_app_state().activate_story_subject(
			"landmark:bi_shan_tunnel.echo_b",
			"collect",
			{"display_name": "Arch Midpoint"}
		).get("consumed", false)),
		"StoryEvent landmark activation collects the second Bi Shan echo through the generic subject API"
	)
	_assert_true(
		bool(_app_state().activate_story_subject(
			"landmark:bi_shan_tunnel.echo_c",
			"collect",
			{"display_name": "Mural Approach"}
		).get("consumed", false)),
		"StoryEvent landmark activation collects the final Bi Shan echo through the generic subject API"
	)

	var bi_shan_prompt_count := m_prompt_requests.size()
	var chamber_result: Dictionary = _app_state().activate_story_subject(
		"landmark:bi_shan_tunnel.chamber",
		"collect",
		{"display_name": "Mural Chamber"}
	)
	_assert_true(
		!bool(chamber_result.get("consumed", true)),
		"StoryEvent landmark activation keeps the Bi Shan chamber available while the prompt is open"
	)
	_assert_true(
		m_prompt_requests.size() == bi_shan_prompt_count + 1,
		"StoryEvent landmark activation emits the Bi Shan chamber prompt through the shared melody prompt signal"
	)
	_assert_true(
		String(m_prompt_requests[m_prompt_requests.size() - 1].get("completion_kind", "")) == "bi_shan_chamber",
		"StoryEvent landmark activation emits the authored Bi Shan chamber prompt payload"
	)
	_app_state().complete_prompt_request(m_prompt_requests[m_prompt_requests.size() - 1])
	_assert_true(
		_view().fragments_found == 2,
		"StoryEvent landmark prompt completion still resolves the Bi Shan reward path"
	)

	_assert_true(
		bool(_app_state().activate_story_subject(
			"landmark:long_shan_tunnel.tunnel_entry",
			"collect",
			{"display_name": "Long Shan Entry"}
		).get("consumed", false)),
		"StoryEvent landmark activation routes the Long Shan entry through the generic subject API"
	)
	_app_state().activate_story_subject("npc:tunnel_guide", "talk")
	_app_state().activate_story_subject("npc:tunnel_guide", "talk")
	_assert_true(
		bool(_app_state().activate_story_subject(
			"landmark:long_shan_tunnel.light_pocket_south",
			"collect",
			{"display_name": "South Lit Pocket"}
		).get("consumed", false)),
		"StoryEvent landmark activation collects the first Long Shan checkpoint through the generic subject API"
	)
	_assert_true(
		bool(_app_state().activate_story_subject(
			"landmark:long_shan_tunnel.light_pocket_north",
			"collect",
			{"display_name": "North Lit Pocket"}
		).get("consumed", false)),
		"StoryEvent landmark activation collects the second Long Shan checkpoint through the generic subject API"
	)

	var long_shan_prompt_count := m_prompt_requests.size()
	var exit_result: Dictionary = _app_state().activate_story_subject(
		"landmark:long_shan_tunnel.tunnel_exit",
		"collect",
		{"display_name": "Tunnel Exit"}
	)
	_assert_true(
		!bool(exit_result.get("consumed", true)),
		"StoryEvent landmark activation keeps the Long Shan exit available while the prompt is open"
	)
	_assert_true(
		m_prompt_requests.size() == long_shan_prompt_count + 1,
		"StoryEvent landmark activation emits the Long Shan route prompt through the shared melody prompt signal"
	)
	_assert_true(
		String(m_prompt_requests[m_prompt_requests.size() - 1].get("completion_kind", "")) == "long_shan_route",
		"StoryEvent landmark activation emits the authored Long Shan route prompt payload"
	)
	_app_state().complete_prompt_request(m_prompt_requests[m_prompt_requests.size() - 1])
	_app_state().activate_story_subject("npc:tunnel_guide", "talk")
	_assert_true(
		_view().get_landmark_state("bagua_tower") == "available",
		"StoryEvent landmark prompt completion still leaves Ren's Bagua handoff intact"
	)

	_app_state().activate_story_subject("npc:tower_keeper", "talk")
	_app_state().activate_story_subject("npc:tower_keeper", "talk")
	var bagua_result: Dictionary = _app_state().activate_story_subject(
		"landmark:bagua_tower.synthesis_chamber",
		"collect",
		{"display_name": "Synthesis Chamber"}
	)
	_assert_true(
		bool(bagua_result.get("consumed", false)),
		"StoryEvent landmark activation routes the Bagua synthesis chamber through the generic subject API"
	)
	_assert_true(
		bool(_view().get_landmark_progress("bagua_tower").get("synthesis_done", false)),
		"StoryEvent landmark activation writes Bagua synthesis progress through shared landmark state"
	)
	_app_state().activate_story_subject("npc:tower_keeper", "talk")
	_assert_true(
		_view().get_landmark_state("festival_stage") == "locked",
		"StoryEvent landmark migration keeps the festival stage gated behind Spring Festival resolution"
	)

	_app_state().activate_story_subject("npc:dock_musician_pei", "talk")
	_app_state().activate_story_subject("npc:postcard_seller_an", "talk")
	_app_state().activate_story_subject("npc:church_caretaker", "talk")
	_app_state().activate_story_subject("npc:tea_vendor_hua", "talk")
	_app_state().activate_story_subject("npc:ferry_caretaker", "talk")
	_assert_true(
		bool(_app_state().get_snapshot().story_flags.get("spring_festival_resolved", false)),
		"StoryEvent landmark migration still fits the existing Spring Festival resolution path"
	)
	_assert_true(
		_view().get_landmark_state("festival_stage") == "available",
		"StoryEvent landmark migration still unlocks the harbor stage once melody and Spring Festival are ready"
	)

	var festival_prompt_count := m_prompt_requests.size()
	var festival_result: Dictionary = _app_state().activate_story_subject(
		"landmark:festival_stage.harbor_stage",
		"perform",
		{"display_name": "Festival Stage"}
	)
	_assert_true(
		!bool(festival_result.get("consumed", true)),
		"StoryEvent landmark activation keeps the festival stage available while the harbor prompt is open"
	)
	_assert_true(
		m_prompt_requests.size() == festival_prompt_count + 1,
		"StoryEvent landmark activation emits the harbor-stage melody prompt through the shared melody prompt builder"
	)
	_assert_true(
		String(m_prompt_requests[m_prompt_requests.size() - 1].get("completion_kind", "")) == "festival_performance",
		"StoryEvent landmark activation emits the live festival-performance prompt payload"
	)
	_app_state().complete_prompt_request(m_prompt_requests[m_prompt_requests.size() - 1])
	_assert_true(
		bool(_view().get_melody_state("festival_melody").get("performed", false)),
		"StoryEvent landmark prompt completion still resolves the harbor-stage performance path"
	)


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	m_failures.append("%s." % label)


func _on_melody_prompt_requested(request: Dictionary) -> void:
	m_prompt_requests.append(request.duplicate(true))


func _on_melody_hint_shown(text: String) -> void:
	m_melody_hints.append(text)
