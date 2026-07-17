extends Node

const MEMORY_REPOSITORY := preload("res://game/tests/state/memory_story_save_repository.gd")

var m_failures := PackedStringArray()
var m_atomic_commit_count := 0
var m_milestone_saw_commit := false


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_detached_reads_do_not_mutate_store()
	_test_hot_path_budget()
	_test_atomic_transition_and_event_order()
	_test_codec_round_trip_and_v1_migration()
	_test_v1_load_is_lazy_and_settings_stay_runtime_only()
	_test_save_failure_keeps_committed_state_and_metadata()
	_test_mode_factories_clear_story_state()

	if m_failures.is_empty():
		print("PASS: AppState snapshot store")
	else:
		for failure in m_failures:
			push_error(failure)
		push_error("AppState snapshot store failed with %d issue(s)." % m_failures.size())

	await get_tree().create_timer(0.1).timeout
	get_tree().quit(0 if m_failures.is_empty() else 1)


func _test_detached_reads_do_not_mutate_store() -> void:
	var state := AppStateService.new(MEMORY_REPOSITORY.new())
	add_child(state)
	state.start_new_story()
	var snapshot := state.get_snapshot()
	var projection := state.get_projection()
	snapshot.objective = "Detached mutation"
	snapshot.story_flags["detached_mutation"] = true
	projection.objective = "Detached projection mutation"
	projection.landmark_progress["piano_ferry"]["state"] = "locked"
	var committed_snapshot := state.get_snapshot()
	var committed_projection := state.get_projection()
	_assert_true(
		committed_snapshot.objective != "Detached mutation"
			and !committed_snapshot.story_flags.has("detached_mutation"),
		"Detached snapshots cannot mutate committed canonical state"
	)
	_assert_true(
		committed_projection.objective != "Detached projection mutation"
			and committed_projection.get_landmark_state("piano_ferry") != "locked",
		"Detached projections cannot mutate the committed projection cache"
	)
	state.queue_free()


func _test_hot_path_budget() -> void:
	var state := AppStateService.new(MEMORY_REPOSITORY.new())
	add_child(state)
	state.start_free_walk()
	state.update_world_context({"hint_action": "R Inspect"})
	state.describe_story_subject("inspectable:harbor_notice_board", "inspect")
	var commit_count := 0
	state.state_committed.connect(func(_changes: AppStateChangeSet) -> void:
		commit_count += 1
	)

	var iterations := 120
	var started := Time.get_ticks_usec()
	for index in iterations:
		state.update_world_context({"hint_action": "R Inspect"})
	var no_op_msec := float(Time.get_ticks_usec() - started) / 1000.0
	_assert_true(commit_count == 0, "Repeated unchanged world context produces no state commits")
	_assert_true(
		no_op_msec < 25.0,
		"Repeated unchanged world context stays below the hot-path budget"
	)

	started = Time.get_ticks_usec()
	for index in iterations:
		state.describe_story_subject("inspectable:harbor_notice_board", "inspect")
	var describe_msec := float(Time.get_ticks_usec() - started) / 1000.0
	_assert_true(
		describe_msec < 600.0,
		"Detached story-subject descriptions stay below the hot-path budget"
	)
	state.queue_free()


func _test_atomic_transition_and_event_order() -> void:
	var repository := MEMORY_REPOSITORY.new()
	var state := AppStateService.new(repository)
	add_child(state)
	state.start_new_story()
	m_atomic_commit_count = 0
	m_milestone_saw_commit = false
	var event_order := PackedStringArray()
	state.state_committed.connect(func(_changes: AppStateChangeSet) -> void:
		m_atomic_commit_count += 1
		event_order.append("commit")
	)
	state.landmark_audio_cue_requested.connect(func(
		_cue_id: String,
		_context: Dictionary
	) -> void:
		event_order.append("audio")
		_assert_true(state.get_projection().hint == "Nested effects committed.", "Committed state is visible before audio cues")
	)
	state.melody_hint_shown.connect(func(_text: String) -> void:
		event_order.append("hint")
		_assert_true(state.get_projection().hint == "Nested effects committed.", "Committed state is visible before melody hints")
	)
	state.melody_prompt_requested.connect(func(_request: Dictionary) -> void:
		event_order.append("prompt")
		_assert_true(state.get_projection().hint == "Nested effects committed.", "Committed state is visible before melody prompts")
	)
	state.story_milestone.connect(func(milestone_id: String, _context: Dictionary) -> void:
		if milestone_id == "atomic_transition_complete":
			event_order.append("milestone")
			m_milestone_saw_commit = state.get_projection().hint == "Nested effects committed."
	)
	var saves_before := repository.save_count
	state.apply_story_effects({
		"objective": "Commit a compound effect.",
		"story_flags": {"snapshot_store_atomic_root": true},
		"conditional_effects": [{
			"priority": 10,
			"conditions": {},
			"effects": {
				"hint": "Nested effects committed.",
				"landmark_audio_cue_request": {
					"cue_id": "piano_ferry",
					"landmark_id": "piano_ferry",
					"trigger_id": "snapshot_store_test",
				},
				"melody_hint_text": "Queued hint",
				"melody_prompt_request": {
					"melody_id": "festival_melody",
					"mode": "performance",
					"completion_kind": "snapshot_store_test",
					"segments": [{
						"source_id": "test",
						"label": "Test",
						"landmark": "Piano Ferry",
					}],
					"expected_order": ["test"],
				},
				"story_milestone": "atomic_transition_complete",
			},
		}],
		"autosave_story_progress": true,
	})
	_assert_true(m_atomic_commit_count == 1, "A recursive StoryEffect emits one state commit")
	_assert_true(repository.save_count == saves_before + 1, "A recursive StoryEffect autosaves at most once")
	_assert_true(m_milestone_saw_commit, "Committed projection is visible before queued milestones")
	_assert_true(
		event_order == PackedStringArray(["commit", "audio", "hint", "prompt", "milestone"]),
		"Queued imperative events retain authored reducer order after the state commit"
	)
	state.queue_free()


func _test_codec_round_trip_and_v1_migration() -> void:
	var repository := MEMORY_REPOSITORY.new()
	var state := AppStateService.new(repository)
	add_child(state)
	state.start_new_story()
	var defaults := state.get_snapshot()
	var codec := StorySaveCodec.new()
	var v2 := codec.encode(defaults, 1234)
	for derived_key in [
		"chapter", "time_of_day", "fragments_found", "route_progress",
		"available_lead_ids", "ending_summary", "hint", "save_status", "settings",
	]:
		_assert_true(!v2.has(derived_key), "V2 omits derived/transient key '%s'" % derived_key)
	var round_trip := codec.decode(v2, defaults)
	_assert_true(!round_trip.is_empty(), "V2 payloads round-trip through the codec")
	var round_trip_snapshot: AppStateSnapshot = round_trip.get("snapshot")
	_assert_true(
		round_trip_snapshot.story_flags == defaults.story_flags
			and round_trip_snapshot.landmark_progress == defaults.landmark_progress,
		"V2 round-trip preserves canonical story progress"
	)

	var v1_flags := defaults.story_flags.duplicate(true)
	v1_flags["unknown_migration_flag"] = "kept"
	var v1_residents := defaults.resident_profiles.duplicate(true)
	v1_residents["ferry_caretaker"]["known"] = true
	v1_residents["ferry_caretaker"]["trust"] = 3
	var v1_landmarks := defaults.landmark_progress.duplicate(true)
	v1_landmarks["piano_ferry"]["state"] = "reward_collected"
	var v1 := {
		"version": 1,
		"mode": "Postgame",
		"season_phase": "postgame",
		"story_time": {"story_day": 4, "world_hour": 19.0},
		"location": "Trinity Church",
		"objective": "Migrated objective",
		"story_flags": v1_flags,
		"resident_profiles": v1_residents,
		"resident_routine_overrides": {
			"ferry_caretaker": {"spawn": {"anchor_id": "Trinity Church"}},
		},
		"landmark_progress": v1_landmarks,
		"player_profile": {
			"body_frame_id": "teen",
			"presentation_id": "feminine",
			"skin_tone_id": "olive",
			"hair_style_id": "bob",
			"hair_color_id": "black",
		},
		"equipped_player_costume_id": "not_a_costume",
		"story_resume_anchor_id": "Trinity Church",
		"story_resume_location": "Church Steps",
		"endgame_state": {
			"active": true,
			"ending_behavior": "continue_story",
			"resume_phase_id": "not_a_phase",
		},
		"manual_pinned_lead_id": "not_a_lead",
		"chapter": "Obsolete chapter",
		"route_progress": {"obsolete": true},
		"fragments_found": 999,
	}
	var migrated := codec.decode(v1, defaults)
	_assert_true(int(migrated.get("source_version", 0)) == 1, "V1 payloads are identified during migration")
	var migrated_snapshot: AppStateSnapshot = migrated.get("snapshot")
	_assert_true(migrated_snapshot.season_phase == "spring_festival", "V1 postgame phases normalize to the current resume phase")
	_assert_true(migrated_snapshot.story_day == 4 and is_equal_approx(migrated_snapshot.world_hour, 19.0), "V1 story time survives migration")
	_assert_true(migrated_snapshot.story_flags.get("unknown_migration_flag") == "kept", "Unknown V1 story flags survive migration")
	_assert_true(bool(migrated_snapshot.resident_profiles["ferry_caretaker"].get("known")), "Known resident data survives V1 migration")
	_assert_true(String(migrated_snapshot.landmark_progress["piano_ferry"].get("state")) == "reward_collected", "Known landmark data survives V1 migration")
	_assert_true(!migrated_snapshot.resident_routine_overrides.is_empty(), "Resident routine overrides survive V1 migration")
	_assert_true(migrated_snapshot.story_resume_anchor_id == "Trinity Church", "Resume checkpoints survive V1 migration")
	_assert_true(
		String(migrated_snapshot.player_profile.get("hair_style_id")) == "bob",
		"Player appearance survives V1 migration"
	)
	_assert_true(
		bool(migrated_snapshot.endgame_state.get("active"))
			and String(migrated_snapshot.endgame_state.get("ending_behavior")) == "continue_story"
			and String(migrated_snapshot.endgame_state.get("resume_phase_id")) == "spring_festival",
		"Soft-ending continuation state survives V1 migration and normalizes its resume phase"
	)
	_assert_true(migrated_snapshot.equipped_player_costume_id != "not_a_costume", "Invalid V1 costumes normalize through the current catalog")
	_assert_true(migrated_snapshot.manual_pinned_lead_id.is_empty(), "Invalid V1 lead pins are discarded")
	_assert_true(codec.decode({"version": 99}, defaults).is_empty(), "Future save versions are rejected")
	state.queue_free()


func _test_v1_load_is_lazy_and_settings_stay_runtime_only() -> void:
	var repository := MEMORY_REPOSITORY.new()
	var bootstrap := AppStateService.new(repository)
	add_child(bootstrap)
	bootstrap.start_new_story()
	var defaults := bootstrap.get_snapshot()
	repository.payload = {
		"version": 1,
		"season_phase": defaults.season_phase,
		"story_time": {"story_day": 2, "world_hour": 14.0},
		"location": "Bagua Tower",
		"story_flags": defaults.story_flags,
		"resident_profiles": defaults.resident_profiles,
		"landmark_progress": defaults.landmark_progress,
		"melody_progress": defaults.melody_progress,
		"player_profile": defaults.player_profile,
	}
	repository.save_count = 0
	bootstrap.queue_free()
	var state := AppStateService.new(repository)
	add_child(state)
	state.commit_settings({
		"master_volume_percent": 42.0,
		"music_volume_percent": 43.0,
		"prompt_volume_percent": 44.0,
		"dialogue_text_speed_percent": 145.0,
	})
	_assert_true(state.resume_story(), "A V1 repository payload remains loadable")
	_assert_true(repository.save_count == 0 and int(repository.payload.get("version", 0)) == 1, "Loading V1 does not rewrite the save file")
	var projection := state.get_projection()
	_assert_true(
		is_equal_approx(projection.master_volume_percent, 42.0)
			and is_equal_approx(projection.prompt_volume_percent, 44.0),
		"Runtime settings survive resume without entering the story payload"
	)
	state.request_autosave()
	_assert_true(repository.save_count == 1 and int(repository.payload.get("version", 0)) == 2, "The next normal autosave upgrades V1 to V2")
	state.queue_free()


func _test_save_failure_keeps_committed_state_and_metadata() -> void:
	var repository := MEMORY_REPOSITORY.new()
	var state := AppStateService.new(repository)
	add_child(state)
	state.start_new_story()
	var metadata_before := state.get_save_metadata()
	repository.fail_saves = true
	state.apply_story_effects({
		"objective": "Gameplay survives a failed save.",
		"autosave_story_progress": true,
	})
	_assert_true(state.get_projection().objective == "Gameplay survives a failed save.", "Failed autosave does not roll back gameplay state")
	_assert_true(state.get_save_metadata() == metadata_before, "Failed autosave preserves prior valid save metadata")
	_assert_true(!state.request_autosave(), "An explicit failed autosave reports failure")
	state.queue_free()


func _test_mode_factories_clear_story_state() -> void:
	var state := AppStateService.new(MEMORY_REPOSITORY.new())
	add_child(state)
	state.start_new_story()
	var initial_leads := state.get_projection().available_lead_ids
	if !initial_leads.is_empty():
		state.pin_story_lead(initial_leads[0])
	state.set_resident_routine_override("ferry_caretaker", {
		"spawn": {"anchor_id": "Trinity Church"},
	})
	state.update_resume_checkpoint("Trinity Church", "Trinity Church")
	state.start_free_walk()
	var free_walk := state.get_snapshot()
	_assert_true(free_walk.resident_routine_overrides.is_empty(), "Free Walk starts without stale resident overrides")
	_assert_true(free_walk.story_resume_anchor_id == "Piano Ferry", "Free Walk starts from a clean checkpoint")
	_assert_true(free_walk.manual_pinned_lead_id.is_empty(), "Free Walk starts without stale manual leads")
	var free_walk_summary := state.get_projection().ending_summary
	_assert_true(
		String(free_walk_summary.get("ending_trigger", "")).is_empty()
			and String(free_walk_summary.get("ending_choice", "")).is_empty(),
		"Free Walk starts without a stale ending summary"
	)
	state.start_new_story()
	var new_story := state.get_snapshot()
	_assert_true(new_story.manual_pinned_lead_id.is_empty(), "New Story starts without stale manual leads")
	_assert_true(new_story.resident_routine_overrides.is_empty(), "New Story starts without stale resident overrides")
	var new_story_summary := state.get_projection().ending_summary
	_assert_true(
		String(new_story_summary.get("ending_trigger", "")).is_empty()
			and String(new_story_summary.get("ending_choice", "")).is_empty(),
		"New Story starts without a stale ending summary"
	)
	state.queue_free()


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	m_failures.append("%s." % label)
