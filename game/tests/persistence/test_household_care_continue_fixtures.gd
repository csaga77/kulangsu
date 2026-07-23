extends Node

const TEST_SAVE_PATH := "user://household_care_continue_fixtures_test.save"
const APP_STATE_SCRIPT := preload("res://game/app_state.gd")
const APP_STATE_SNAPSHOT_SCRIPT := preload("res://game/app_state/app_state_snapshot.gd")
const JOURNAL_BUILDER_SCRIPT := preload("res://game/journal_builder.gd")
const STORY_SAVE_CODEC := preload("res://game/app_state/story_save_codec.gd")
const STORY_SAVE_REPOSITORY := preload("res://game/app_state/story_save_repository.gd")
const FIXTURES := preload(
	"res://game/tests/persistence/fixtures/household_care_continue_fixtures.gd"
)
const HOUSEHOLD_SCRIPT := preload(
	"res://architecture/apo_household/apo_household_courtyard_3d.gd"
)

var m_failures := PackedStringArray()
var m_repository = STORY_SAVE_REPOSITORY.new(TEST_SAVE_PATH)


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	m_repository.clear()
	_test_open_winter_continue()
	_test_legacy_post_closer_continue()
	m_repository.clear()

	if m_failures.is_empty():
		print("PASS: household-care Continue fixtures")
	else:
		for failure in m_failures:
			push_error(failure)
		push_error(
			"Household-care Continue fixtures failed with %d issue(s)."
			% m_failures.size()
		)

	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0 if m_failures.is_empty() else 1)


func _test_open_winter_continue() -> void:
	var payload: Dictionary = FIXTURES.build_payload(FIXTURES.OPEN_WINTER)
	_assert_true(
		int(payload.get("version", 0)) == STORY_SAVE_CODEC.SAVE_VERSION,
		"The open-window fixture uses the current save format"
	)
	var app_state = _resume_fixture(payload, "Open-window")
	if app_state == null:
		return

	var snapshot = app_state.get_snapshot()
	var projection = app_state.get_projection()
	var family_progress: Dictionary = projection.get_route_progress("family_memory")
	_assert_true(
		!bool(snapshot.story_flags.get("family_household_care_seen", false))
			and !bool(snapshot.story_flags.get("family_household_care_missed", false)),
		"Open-window Continue preserves an unresolved household-care outcome"
	)
	_assert_true(
		_normalize_string_array(family_progress.get("available_beat_ids", [])).has(
			"family_household_care_seen"
		),
		"Open-window Continue exposes household care as a live lead"
	)
	_assert_true(
		JOURNAL_BUILDER_SCRIPT.build_story_routes_journal_text(projection).contains(
			"Missed optional beats: 0"
		),
		"Open-window Continue journal keeps the optional beat unmissed"
	)
	_assert_household_presentation(snapshot.story_flags, "waiting", "")

	_assert_true(
		app_state.resolve_story_event("family_household_care_seen"),
		"Household care remains completable after open-window Continue"
	)
	_assert_true(
		app_state.resolve_story_event("spring_festival_prepared"),
		"Festival preparation remains independent after completing care"
	)
	_assert_common_route_and_endgame_continuity(
		app_state,
		"family_household_care_seen",
		"warm answer"
	)
	_assert_continue_round_trip(app_state, "family_household_care_seen", "Open-window")
	app_state.free()


func _test_legacy_post_closer_continue() -> void:
	var payload: Dictionary = FIXTURES.build_payload(FIXTURES.LEGACY_POST_CLOSER)
	_assert_true(
		int(payload.get("version", 0)) == 1,
		"The post-closer fixture remains a pre-ledger legacy save"
	)
	var app_state = _resume_fixture(payload, "Legacy post-closer")
	if app_state == null:
		return

	var snapshot = app_state.get_snapshot()
	var projection = app_state.get_projection()
	var family_progress: Dictionary = projection.get_route_progress("family_memory")
	var available_ids := _normalize_string_array(
		family_progress.get("available_beat_ids", [])
	)
	var blocked_ids := _normalize_string_array(family_progress.get("blocked_beat_ids", []))
	var missed_ids := _normalize_string_array(family_progress.get("missed_beat_ids", []))
	_assert_true(
		bool(snapshot.story_flags.get("family_household_care_missed", false))
			and !bool(snapshot.story_flags.get("family_household_care_seen", false)),
		"Legacy post-closer Continue normalizes to one missed fact"
	)
	_assert_true(
		!available_ids.has("family_household_care_seen")
			and !blocked_ids.has("family_household_care_seen")
			and missed_ids.has("family_household_care_seen"),
		"Legacy post-closer Continue projects the optional beat as terminal"
	)
	_assert_true(
		JOURNAL_BUILDER_SCRIPT.build_story_routes_journal_text(projection).contains(
			"Missed optional beats: 1"
		),
		"Legacy post-closer Continue journal distinguishes the missed beat"
	)
	_assert_household_presentation(
		snapshot.story_flags,
		"untended",
		"dry leaves"
	)

	_assert_common_route_and_endgame_continuity(
		app_state,
		"family_household_care_missed",
		"regret"
	)
	_assert_continue_round_trip(
		app_state,
		"family_household_care_missed",
		"Legacy post-closer"
	)
	var upgraded_payload := m_repository.load_payload()
	_assert_true(
		int(upgraded_payload.get("version", 0)) == STORY_SAVE_CODEC.SAVE_VERSION
			and bool(
				(upgraded_payload.get("story_flags", {}) as Dictionary).get(
					"family_household_care_missed",
					false
				)
			),
		"The first post-Continue autosave upgrades and persists the legacy missed outcome"
	)
	app_state.free()


func _resume_fixture(payload: Dictionary, label: String):
	m_repository.clear()
	if !m_repository.save_payload(payload):
		m_failures.append("%s fixture could not be written." % label)
		return null
	var app_state = APP_STATE_SCRIPT.new(m_repository)
	var metadata := app_state.get_save_metadata()
	_assert_true(
		bool(metadata.get("exists", false))
			and String(metadata.get("resume_location", "")) == "Piano Ferry"
			and String(metadata.get("chapter", "")).to_lower().contains("winter"),
		"%s fixture appears on the title screen with Winter resume metadata" % label
	)
	_assert_true(
		String(metadata.get("fragments_text", "")) == "0 / 4",
		"%s fixture preserves canonical title-screen melody totals" % label
	)
	_assert_true(app_state.resume_story(), "%s fixture resumes through Continue" % label)
	_assert_true(
		app_state.get_projection().mode_id == APP_STATE_SNAPSHOT_SCRIPT.MODE_STORY,
		"%s fixture resumes in Story mode" % label
	)
	return app_state


func _assert_household_presentation(
	story_flags: Dictionary,
	expected_state: String,
	expected_text: String
) -> void:
	var household = HOUSEHOLD_SCRIPT.new()
	household.apply_story_flags(story_flags)
	_assert_true(
		household.get_presentation_state() == expected_state,
		"Continue restores the household's %s presentation" % expected_state
	)
	var app_state = APP_STATE_SCRIPT.new(m_repository)
	_assert_true(app_state.resume_story(), "Household presentation check can reload its fixture")
	if expected_state == "waiting":
		var metadata: Dictionary = app_state.describe_story_subject_metadata(
			"inspectable:family_household_courtyard"
		)
		_assert_true(
			!bool(metadata.get("targetable", true)),
			"Open-window Continue keeps reflection gated until care resolves"
		)
		household.free()
		app_state.free()
		return
	var result: Dictionary = app_state.activate_story_subject(
		"inspectable:family_household_courtyard",
		"inspect",
		{"display_name": "A Po's Courtyard"}
	)
	var line := String(result.get("line", ""))
	_assert_true(
		line.to_lower().contains(expected_text),
		"Continue restores the household's %s inspect response (received: %s)"
		% [expected_state, line]
	)
	household.free()
	app_state.free()


func _assert_common_route_and_endgame_continuity(
	app_state,
	terminal_fact_id: String,
	expected_dialogue_text: String
) -> void:
	_assert_true(
		app_state.resolve_story_event("spring_festival_resolved"),
		"%s leaves Spring Festival resolution available" % terminal_fact_id
	)
	_assert_true(
		!bool(app_state.get_projection().endgame_state.get("active", false)),
		"%s does not start the final act before a designated trigger" % terminal_fact_id
	)
	var hua_result: Dictionary = app_state.interact_with_resident("tea_vendor_hua")
	_assert_true(
		String(hua_result.get("line", "")).to_lower().contains(expected_dialogue_text),
		"%s restores its later Spring Festival dialogue" % terminal_fact_id
	)
	_assert_true(
		app_state.resolve_story_event("future_commitment_choice")
			and app_state.resolve_story_event("summer_exam_complete"),
		"%s preserves the independent study route into a valid final act"
		% terminal_fact_id
	)
	_assert_true(
		bool(app_state.get_projection().endgame_state.get("active", false))
			and String(
				app_state.get_projection().endgame_state.get("trigger_event_id", "")
			) == "summer_exam_complete",
		"%s preserves designated endgame eligibility" % terminal_fact_id
	)


func _assert_continue_round_trip(
	app_state,
	terminal_fact_id: String,
	label: String
) -> void:
	_assert_true(app_state.request_autosave(), "%s path writes a follow-up autosave" % label)
	var resumed_state = APP_STATE_SCRIPT.new(m_repository)
	_assert_true(resumed_state.resume_story(), "%s path can Continue again" % label)
	_assert_true(
		bool(resumed_state.get_snapshot().story_flags.get(terminal_fact_id, false)),
		"%s path retains its terminal household fact on repeated Continue" % label
	)
	resumed_state.free()


func _normalize_string_array(value: Variant) -> PackedStringArray:
	var output := PackedStringArray()
	if value is PackedStringArray or value is Array:
		for entry in value:
			output.append(String(entry))
	return output


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	m_failures.append("%s." % label)
