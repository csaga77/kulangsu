extends Node

const APP_RUNTIME := preload("res://game/app_runtime.gd")

var m_failures := PackedStringArray()
var m_player_profile_signal_count := 0
var m_player_costume_signal_count := 0
var m_story_time_signal_count := 0
var m_master_volume_signal_count := 0
var m_music_volume_signal_count := 0
var m_prompt_volume_signal_count := 0
var m_dialogue_speed_signal_count := 0


func _app_state() -> AppStateService:
	return APP_RUNTIME.get_app_state(self) as AppStateService


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var app_state := _app_state()
	app_state.player_profile_changed.connect(func(_profile: Dictionary) -> void:
		m_player_profile_signal_count += 1
	)
	app_state.player_costume_changed.connect(func(_costume_id: String, _costume: Dictionary) -> void:
		m_player_costume_signal_count += 1
	)
	app_state.story_time_changed.connect(func(_time_state: Dictionary) -> void:
		m_story_time_signal_count += 1
	)
	app_state.master_volume_changed.connect(func(_percent: float) -> void:
		m_master_volume_signal_count += 1
	)
	app_state.music_volume_changed.connect(func(_percent: float) -> void:
		m_music_volume_signal_count += 1
	)
	app_state.prompt_volume_changed.connect(func(_percent: float) -> void:
		m_prompt_volume_signal_count += 1
	)
	app_state.dialogue_text_speed_changed.connect(
		func(_percent: float, _characters_per_second: float) -> void:
			m_dialogue_speed_signal_count += 1
	)

	app_state.configure_free_walk()
	m_player_profile_signal_count = 0
	m_player_costume_signal_count = 0
	m_story_time_signal_count = 0

	var next_profile := app_state.get_player_profile()
	next_profile["body_frame_id"] = "teen"
	_assert_true(app_state.set_player_profile(next_profile), "Player profile accepts a real change")
	_assert_true(
		String(app_state.player_profile.get("body_frame_id", "")) == "teen",
		"AppState stores the canonical player profile"
	)
	_assert_true(
		m_player_profile_signal_count == 1,
		"Player profile changes emit once after AppState commits"
	)
	var detached_profile := app_state.get_player_profile()
	detached_profile["body_frame_id"] = "adult"
	_assert_true(
		String(app_state.player_profile.get("body_frame_id", "")) == "teen",
		"Player profile getters cannot mutate canonical AppState data"
	)

	_assert_true(
		app_state.equip_player_costume("festival_evening"),
		"Free Walk can equip an unlocked costume"
	)
	_assert_true(
		app_state.equipped_player_costume_id == "festival_evening",
		"AppState stores the canonical equipped costume id"
	)
	_assert_true(
		m_player_costume_signal_count == 1,
		"Costume changes emit once after AppState commits"
	)

	_assert_true(
		app_state.set_story_time_state({"story_day": 2, "world_hour": 13.0}),
		"Story time accepts a normalized state change"
	)
	_assert_true(
		app_state.story_day == 2 and is_equal_approx(app_state.world_hour, 13.0)
			and app_state.time_of_day == "afternoon",
		"AppState stores canonical story-time fields"
	)
	_assert_true(
		m_story_time_signal_count == 1,
		"Story-time state changes emit once after AppState commits"
	)
	app_state.apply_story_time_effects({
		"story_day": 3,
		"world_hour": 9.0,
		"advance_hours": 10.0,
	})
	_assert_true(
		app_state.story_day == 3 and is_equal_approx(app_state.world_hour, 19.0)
			and app_state.time_of_day == "evening",
		"Compound story-time operations resolve into one final AppState snapshot"
	)
	_assert_true(
		m_story_time_signal_count == 2,
		"Compound story-time operations emit only their final state"
	)

	app_state.set_master_volume_percent(65.0)
	app_state.set_music_volume_percent(55.0)
	app_state.set_prompt_volume_percent(40.0)
	app_state.set_dialogue_text_speed_percent(150.0)
	_assert_true(
		is_equal_approx(app_state.get_master_volume_percent(), 65.0)
			and is_equal_approx(app_state.get_music_volume_percent(), 55.0)
			and is_equal_approx(app_state.get_prompt_volume_percent(), 40.0)
			and is_equal_approx(app_state.get_dialogue_text_speed_percent(), 150.0),
		"AppState owns the canonical runtime settings values"
	)
	_assert_true(
		m_master_volume_signal_count == 1
			and m_music_volume_signal_count == 1
			and m_prompt_volume_signal_count == 1
			and m_dialogue_speed_signal_count == 1,
		"Runtime settings emit once after AppState commits"
	)
	app_state.set_master_volume_percent(100.0)

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
