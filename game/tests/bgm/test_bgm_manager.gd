extends Node

const APP_RUNTIME := preload("res://game/app_runtime.gd")
const BGM_CATALOG_SCRIPT := preload("res://game/bgm_catalog.gd")
const BGM_MANAGER_SCRIPT := preload("res://game/bgm_manager.gd")

const NATURAL_FADE_MIN_SECONDS := 3.0
const NATURAL_FADE_MAX_SECONDS := 5.0
const MIN_SCHEDULED_FADE_DELAY_SECONDS := 0.05
const TIMER_TOLERANCE_SECONDS := 1.0

var m_failures := PackedStringArray()


func _app_state():
	return APP_RUNTIME.get_app_state(self)


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_assert_catalog_validation_stays_lazy()
	await _assert_runtime_selection_behaviors()

	if m_failures.is_empty():
		print("PASS: BGM manager regression checks")
	else:
		for failure in m_failures:
			push_error(failure)
		push_error("BGM manager regression checks failed with %d issue(s)." % m_failures.size())

	await get_tree().create_timer(0.1).timeout
	get_tree().quit(0 if m_failures.is_empty() else 1)


func _assert_catalog_validation_stays_lazy() -> void:
	var manager := BGM_MANAGER_SCRIPT.new()
	manager.m_catalog = BGM_CATALOG_SCRIPT.build_catalog()
	manager._validate_catalog()
	_assert_true(
		manager.m_stream_cache.is_empty(),
		"Catalog validation leaves stream cache empty until a track is selected"
	)
	manager.free()


func _assert_runtime_selection_behaviors() -> void:
	_app_state().configure_new_game()
	_app_state().set_location("Ferry Plaza")

	var manager: BgmManager = BGM_MANAGER_SCRIPT.new()
	add_child(manager)

	await get_tree().process_frame
	await get_tree().process_frame

	_assert_true(!manager.get_current_track_id().is_empty(), "Startup selection picks a playable BGM track")
	_assert_true(manager.m_stream_cache.size() == 1, "Startup selection only caches the chosen stream")
	_assert_true(
		is_instance_valid(manager.m_track_end_fade_timer) and !manager.m_track_end_fade_timer.is_stopped(),
		"Natural-end fade scheduling arms a one-shot timer after playback begins"
	)
	_assert_true(
		manager.m_scheduled_fade_duration >= NATURAL_FADE_MIN_SECONDS
		and manager.m_scheduled_fade_duration <= NATURAL_FADE_MAX_SECONDS,
		"Natural-end fade duration stays inside the documented 3-5 second range"
	)

	var current_track: Dictionary = manager.m_catalog.get(manager.get_current_track_id(), {})
	var expected_fade_delay := maxf(
		manager._resolve_track_duration_seconds(current_track, manager.m_player.stream)
		- manager.m_scheduled_fade_duration,
		MIN_SCHEDULED_FADE_DELAY_SECONDS
	)
	_assert_approx(
		"Natural-end fade timer lines up with track duration minus fade time",
		manager.m_track_end_fade_timer.time_left,
		expected_fade_delay,
		TIMER_TOLERANCE_SECONDS
	)
	manager._on_track_end_fade_timer_timeout()
	await get_tree().process_frame
	_assert_true(
		manager.m_player.playing,
		"Natural-end fade keeps the current track playing until the stream actually finishes"
	)
	_assert_true(
		!manager.m_is_transitioning and manager.m_is_natural_end_fading,
		"Natural-end fade does not reuse the mid-track transition path"
	)
	_assert_true(
		manager.m_gap_timer.is_stopped(),
		"Natural-end fade does not start the silence gap before the stream finishes"
	)

	manager.m_recent_history.clear()
	manager.m_recent_history.append_array(["seaside_portico_waltz", "wave_of_kulangsu"])
	manager.m_current_track_id = "wave_of_kulangsu"
	manager.m_context["location"] = "ferry_plaza"
	manager.m_player.stop()
	await get_tree().process_frame
	_assert_true(
		manager.m_recent_history.has("seaside_portico_waltz") and manager.m_recent_history.has("wave_of_kulangsu"),
		"Fallback test seeds the expected recent-history buffer"
	)

	_assert_equal(
		"Location-only fallback preserves variety when a non-recent local match exists",
		manager._pick_location_fallback_track_id(true),
		"sunny_side_stroll"
	)
	_assert_equal(
		"Relaxed location fallback still recovers the strongest local match when history must be ignored",
		manager._pick_location_fallback_track_id(false),
		"seaside_portico_waltz"
	)

	manager.queue_free()
	await get_tree().process_frame


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	m_failures.append("%s." % label)


func _assert_approx(label: String, actual: float, expected: float, tolerance: float) -> void:
	if absf(actual - expected) <= tolerance:
		print("PASS: %s" % label)
		return
	m_failures.append("%s. Expected %.3f, got %.3f (tolerance %.3f)." % [label, expected, actual, tolerance])


func _assert_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual == expected:
		print("PASS: %s" % label)
		return
	m_failures.append("%s. Expected %s, got %s." % [label, str(expected), str(actual)])
