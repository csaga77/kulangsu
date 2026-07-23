extends Node

const TEST_AUTOSAVE_PATH := "user://story_state_persistence.save"
const OVERRIDE_PATH := "res://game/residents/definitions/terrace_painter_nian.tres"
const APP_RUNTIME := preload("res://game/app_runtime.gd")

var m_failures := PackedStringArray()
var m_app_state: AppStateService
var m_repository: StorySaveRepository


func _app_state() -> AppStateService:
	return m_app_state


func _ready() -> void:
	m_repository = StorySaveRepository.new(TEST_AUTOSAVE_PATH)
	m_app_state = AppStateService.new(m_repository)
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

	_test_story_moment_save_normalization()
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


func _test_story_moment_save_normalization() -> void:
	var codec := StorySaveCodec.new()
	var defaults := _app_state().get_snapshot()
	var open_legacy := {
		"version": 1,
		"season_phase": "winter",
		"story_flags": {
			"winter_memory_reveal": true,
		},
	}
	var open_decoded := codec.decode(open_legacy, defaults)
	var open_snapshot: AppStateSnapshot = open_decoded.get("snapshot")
	_assert_true(
		!bool(open_snapshot.story_flags.get("family_household_care_seen", false))
			and !bool(open_snapshot.story_flags.get("family_household_care_missed", false)),
		"A pre-ledger save inside the open Winter window keeps household care open"
	)

	var closed_legacy := {
		"version": 1,
		"season_phase": "winter",
		"story_flags": {
			"winter_memory_reveal": true,
			"spring_festival_prepared": true,
		},
	}
	var closed_decoded := codec.decode(closed_legacy, defaults)
	var closed_snapshot: AppStateSnapshot = closed_decoded.get("snapshot")
	_assert_true(
		bool(closed_snapshot.story_flags.get("family_household_care_missed", false))
			and !bool(closed_snapshot.story_flags.get("family_household_care_seen", false)),
		"A pre-ledger save beyond the closer acquires the missed fact"
	)

	var malformed_dual := {
		"version": 2,
		"season_phase": "winter",
		"story_flags": {
			"winter_memory_reveal": true,
			"family_household_care_seen": true,
			"family_household_care_missed": true,
			"spring_festival_prepared": true,
		},
	}
	var dual_decoded := codec.decode(malformed_dual, defaults)
	var dual_snapshot: AppStateSnapshot = dual_decoded.get("snapshot")
	_assert_true(
		bool(dual_snapshot.story_flags.get("family_household_care_seen", false))
			and !bool(dual_snapshot.story_flags.get("family_household_care_missed", false)),
		"Malformed dual-fact save data deterministically normalizes to seen"
	)

	var seen_snapshot := defaults.duplicate_state()
	seen_snapshot.season_phase = "winter"
	seen_snapshot.story_flags["winter_memory_reveal"] = true
	seen_snapshot.story_flags["family_household_care_seen"] = true
	seen_snapshot.story_flags["family_household_care_missed"] = false
	var seen_round_trip := codec.decode(codec.encode(seen_snapshot, 101), defaults)
	var seen_round_trip_snapshot: AppStateSnapshot = seen_round_trip.get("snapshot")
	_assert_true(
		bool(seen_round_trip_snapshot.story_flags.get("family_household_care_seen", false))
			and !bool(seen_round_trip_snapshot.story_flags.get("family_household_care_missed", false)),
		"Seen household care survives a V2 save round trip"
	)

	var missed_snapshot := defaults.duplicate_state()
	missed_snapshot.season_phase = "winter"
	missed_snapshot.story_flags["winter_memory_reveal"] = true
	missed_snapshot.story_flags["spring_festival_prepared"] = true
	missed_snapshot.story_flags["family_household_care_seen"] = false
	missed_snapshot.story_flags["family_household_care_missed"] = true
	var missed_round_trip := codec.decode(codec.encode(missed_snapshot, 102), defaults)
	var missed_round_trip_snapshot: AppStateSnapshot = missed_round_trip.get("snapshot")
	_assert_true(
		bool(missed_round_trip_snapshot.story_flags.get("family_household_care_missed", false))
			and !bool(missed_round_trip_snapshot.story_flags.get("family_household_care_seen", false)),
		"Missed household care survives a V2 save round trip"
	)

	m_repository.save_payload(closed_legacy)
	_assert_true(
		_app_state().resume_story(),
		"Continue accepts a legacy save beyond the household-care closer"
	)
	_assert_true(
		bool(_app_state().get_snapshot().story_flags.get(
			"family_household_care_missed",
			false
		)),
		"Continue exposes the normalized missed fact before projection"
	)
	_app_state().request_autosave()
	var upgraded_payload := m_repository.load_payload()
	_assert_true(
		int(upgraded_payload.get("version", 0)) == StorySaveCodec.SAVE_VERSION
			and bool(
				(upgraded_payload.get("story_flags", {}) as Dictionary).get(
					"family_household_care_missed",
					false
				)
			),
		"The next autosave persists the normalized legacy outcome"
	)


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	m_failures.append("%s." % label)
