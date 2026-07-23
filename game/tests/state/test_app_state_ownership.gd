extends Node

const MEMORY_REPOSITORY := preload(
	"res://game/tests/state/memory_story_save_repository.gd"
)

var m_failures := PackedStringArray()
var m_app_state: AppStateService
var m_repository: MemoryStorySaveRepository
var m_commit_count := 0
var m_player_commit_count := 0
var m_time_commit_count := 0
var m_settings_commit_count := 0
var m_expiry_commit_saw_missed := false


func _app_state() -> AppStateService:
	return m_app_state


func _ready() -> void:
	m_repository = MEMORY_REPOSITORY.new()
	m_app_state = AppStateService.new(m_repository)
	m_app_state.name = "AppState"
	add_child(m_app_state)
	call_deferred("_run")


func _run() -> void:
	var app_state := _app_state()
	app_state.state_committed.connect(func(changes: AppStateChangeSet) -> void:
		m_commit_count += 1
		if changes.has_domain(AppStateChangeSet.Domain.PLAYER):
			m_player_commit_count += 1
		if changes.has_domain(AppStateChangeSet.Domain.TIME):
			m_time_commit_count += 1
		if changes.has_domain(AppStateChangeSet.Domain.SETTINGS):
			m_settings_commit_count += 1
		if (
			changes.has_domain(AppStateChangeSet.Domain.STORY)
			and bool(app_state.get_snapshot().story_flags.get(
				"family_household_care_missed",
				false
			))
		):
			m_expiry_commit_saw_missed = true
	)

	app_state.start_free_walk()
	m_commit_count = 0
	m_player_commit_count = 0
	m_time_commit_count = 0
	m_settings_commit_count = 0

	var next_profile := app_state.get_projection().player_profile
	next_profile["body_frame_id"] = "teen"
	_assert_true(app_state.replace_player_profile(next_profile), "Player profile accepts a real change")
	_assert_true(
		String(app_state.get_projection().player_profile.get("body_frame_id", "")) == "teen",
		"AppState stores the canonical player profile"
	)
	_assert_true(
		m_player_commit_count == 1,
		"Player profile changes emit once after AppState commits"
	)
	var detached_profile := app_state.get_snapshot().player_profile
	detached_profile["body_frame_id"] = "adult"
	_assert_true(
		String(app_state.get_snapshot().player_profile.get("body_frame_id", "")) == "teen",
		"Detached snapshots cannot mutate canonical AppState data"
	)

	_assert_true(
		app_state.equip_player_costume("festival_evening"),
		"Free Walk can equip an unlocked costume"
	)
	_assert_true(
		app_state.get_projection().equipped_player_costume_id == "festival_evening",
		"AppState stores the canonical equipped costume id"
	)
	_assert_true(
		m_player_commit_count == 2,
		"Costume changes emit once after AppState commits"
	)

	app_state.update_world_context({
		"story_time": {"story_day": 2, "world_hour": 13.0},
	})
	_assert_true(
		app_state.get_projection().story_day == 2
			and is_equal_approx(app_state.get_projection().world_hour, 13.0)
			and app_state.get_projection().time_of_day == "afternoon",
		"AppState stores canonical story-time fields"
	)
	_assert_true(
		m_time_commit_count == 1,
		"Story-time state changes emit once after AppState commits"
	)
	app_state.update_world_context({
		"story_time": {
			"story_day": 3,
			"world_hour": 9.0,
			"advance_hours": 10.0,
		},
	})
	_assert_true(
		app_state.get_projection().story_day == 3
			and is_equal_approx(app_state.get_projection().world_hour, 19.0)
			and app_state.get_projection().time_of_day == "evening",
		"Compound story-time operations resolve into one final AppState snapshot"
	)
	_assert_true(
		m_time_commit_count == 2,
		"Compound story-time operations emit only their final state"
	)

	app_state.commit_settings({
		"master_volume_percent": 65.0,
		"music_volume_percent": 55.0,
		"prompt_volume_percent": 40.0,
		"dialogue_text_speed_percent": 150.0,
	})
	var settings := app_state.get_projection()
	_assert_true(
		is_equal_approx(settings.master_volume_percent, 65.0)
			and is_equal_approx(settings.music_volume_percent, 55.0)
			and is_equal_approx(settings.prompt_volume_percent, 40.0)
			and is_equal_approx(settings.dialogue_text_speed_percent, 150.0),
		"AppState owns the canonical runtime settings values"
	)
	_assert_true(
		m_settings_commit_count == 1,
		"A complete runtime settings command emits one state commit"
	)
	app_state.commit_settings({"master_volume_percent": 100.0})

	app_state.start_new_story()
	m_commit_count = 0
	m_expiry_commit_saw_missed = false
	var saves_before_expiry := m_repository.save_count
	app_state.apply_story_effects({
		"season_phase": "winter",
		"story_flags": {
			"winter_memory_reveal": true,
			"spring_festival_prepared": true,
		},
		"autosave_story_progress": true,
	})
	var expired_flags := app_state.get_snapshot().story_flags
	_assert_true(
		bool(expired_flags.get("family_household_care_missed", false))
			and !bool(expired_flags.get("family_household_care_seen", false)),
		"Closer expiry normalizes into one exclusive missed outcome"
	)
	_assert_true(
		m_commit_count == 1 and m_repository.save_count == saves_before_expiry + 1,
		"Closer expiry commits and autosaves exactly once"
	)
	_assert_true(
		m_expiry_commit_saw_missed,
		"The committed missed fact is visible before command delivery completes"
	)

	var repeated_transition := AppStateTransition.new(app_state.get_snapshot())
	var repeated_context := AppStateReducerContext.new(repeated_transition)
	var normalized_once := repeated_transition.next_snapshot.story_flags.duplicate(true)
	repeated_context.normalize_snapshot()
	repeated_context.normalize_snapshot()
	_assert_true(
		repeated_transition.next_snapshot.story_flags == normalized_once,
		"Repeated story-moment normalization is idempotent"
	)
	repeated_context.dispose()

	var commits_before_repeat := m_commit_count
	var saves_before_repeat := m_repository.save_count
	_assert_true(
		!app_state.resolve_story_event("family_household_care_seen")
			and !app_state.resolve_story_event("spring_festival_prepared"),
		"Repeated completion and close commands are rejected after expiry"
	)
	_assert_true(
		m_commit_count == commits_before_repeat
			and m_repository.save_count == saves_before_repeat,
		"Repeated terminal commands produce no commit or autosave"
	)

	app_state.start_new_story()
	app_state.apply_story_effects({
		"season_phase": "winter",
		"story_flags": {
			"winter_memory_reveal": true,
			"family_household_care_seen": true,
			"family_household_care_missed": true,
			"spring_festival_prepared": true,
		},
	})
	var dual_flags := app_state.get_snapshot().story_flags
	_assert_true(
		bool(dual_flags.get("family_household_care_seen", false))
			and !bool(dual_flags.get("family_household_care_missed", false)),
		"Completion wins when one detached command produces both outcomes"
	)

	if m_failures.is_empty():
		print("PASS: AppState ownership regression")
	else:
		for failure in m_failures:
			push_error(failure)
		push_error("AppState ownership regression failed with %d issue(s)." % m_failures.size())

	await get_tree().create_timer(0.1).timeout
	get_tree().quit(0 if m_failures.is_empty() else 1)


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	m_failures.append("%s." % label)
