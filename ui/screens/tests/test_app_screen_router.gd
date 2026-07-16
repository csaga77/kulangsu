extends Node

const APP_SCREEN_ROUTER_SCRIPT := preload("res://ui/app_screen_router.gd")
const ScreenState = APP_SCREEN_ROUTER_SCRIPT.ScreenState

var m_failures := PackedStringArray()


func _ready() -> void:
	_run()


func _run() -> void:
	var router: APP_SCREEN_ROUTER_SCRIPT = APP_SCREEN_ROUTER_SCRIPT.new()
	_assert_presentation(
		"Boot is the initial route",
		router.resolve_presentation(),
		ScreenState.BOOT,
		&"boot",
		false,
		false,
		false
	)

	router.replace_route(ScreenState.TITLE)
	router.push_route(ScreenState.SETTINGS)
	_assert_presentation(
		"Title settings inherit frontend context",
		router.resolve_presentation(),
		ScreenState.SETTINGS,
		&"settings",
		false,
		false,
		false
	)
	_assert_true("Settings back returns to title", router.pop_route())
	_assert_equal("Settings back restores title", router.current_state(), ScreenState.TITLE)

	router.replace_route(ScreenState.PLAYING)
	router.push_route(ScreenState.PAUSE)
	router.push_route(ScreenState.SETTINGS)
	_assert_presentation(
		"Pause settings inherit gameplay context",
		router.resolve_presentation(),
		ScreenState.SETTINGS,
		&"settings",
		true,
		true,
		true
	)
	_assert_true("Settings back returns to pause", router.pop_route())
	_assert_equal("Gameplay settings restore pause", router.current_state(), ScreenState.PAUSE)
	_assert_true("Pause back returns to gameplay", router.pop_route())
	_assert_equal("Pause back restores gameplay", router.current_state(), ScreenState.PLAYING)

	router.push_route(ScreenState.JOURNAL)
	router.push_route(ScreenState.MELODY_PROMPT)
	_assert_true("Melody prompt back returns to journal", router.pop_route())
	_assert_equal("Melody prompt restores journal", router.current_state(), ScreenState.JOURNAL)

	router.replace_route(ScreenState.PLAYING)
	router.push_route(ScreenState.ENDING)
	router.push_route(ScreenState.CREDITS)
	_assert_presentation(
		"Ending credits preserve paused gameplay context",
		router.resolve_presentation(),
		ScreenState.CREDITS,
		&"credits",
		true,
		true,
		true
	)
	_assert_true("Credits back returns to ending", router.pop_route())
	_assert_equal("Credits restore ending", router.current_state(), ScreenState.ENDING)

	router.replace_route(ScreenState.TITLE)
	router.push_route(ScreenState.CONFIRM)
	var title_confirm := router.resolve_presentation()
	_assert_equal("Title confirm remains the input route", int(title_confirm.get("top_state", -1)), ScreenState.CONFIRM)
	_assert_equal("Title remains beneath confirm", title_confirm.get("content_panel_id", &""), &"title")
	_assert_equal("Confirm is the modal panel", title_confirm.get("modal_panel_id", &""), &"confirm")
	_assert_true("Title confirm does not pause gameplay", !bool(title_confirm.get("pause_game", true)))
	_assert_true("Confirm back returns to title", router.pop_route())
	_assert_equal("Confirm restores title without visibility inference", router.current_state(), ScreenState.TITLE)

	router.replace_route(ScreenState.PLAYING)
	router.push_route(ScreenState.PAUSE)
	router.push_route(ScreenState.CONFIRM)
	var pause_confirm := router.resolve_presentation()
	_assert_equal("Pause remains beneath confirm", pause_confirm.get("content_panel_id", &""), &"pause")
	_assert_true("Gameplay confirm remains paused", bool(pause_confirm.get("pause_game", false)))
	_assert_true("Gameplay confirm keeps the HUD", bool(pause_confirm.get("show_hud", false)))

	router.replace_route(ScreenState.DEPARTURE)
	_assert_equal("Replacing a route clears modal history", router.get_route_stack(), [ScreenState.DEPARTURE])
	_assert_true("A modal cannot replace the route stack", !router.replace_route(ScreenState.CONFIRM))
	_assert_equal("Rejected modal replacement preserves departure", router.current_state(), ScreenState.DEPARTURE)

	if m_failures.is_empty():
		print("PASS: app screen router regression")
	else:
		for failure in m_failures:
			push_error(failure)
		push_error("App screen router regression failed with %d issue(s)." % m_failures.size())

	get_tree().quit(0 if m_failures.is_empty() else 1)


func _assert_presentation(
	label: String,
	presentation: Dictionary,
	expected_state: int,
	expected_panel_id: StringName,
	expected_game_context: bool,
	expected_pause: bool,
	expected_hud: bool
) -> void:
	_assert_equal("%s uses the expected route" % label, int(presentation.get("top_state", -1)), expected_state)
	_assert_equal("%s uses the expected panel" % label, presentation.get("content_panel_id", &""), expected_panel_id)
	_assert_equal("%s resolves game context" % label, bool(presentation.get("game_context", false)), expected_game_context)
	_assert_equal("%s resolves pause state" % label, bool(presentation.get("pause_game", false)), expected_pause)
	_assert_equal("%s resolves HUD state" % label, bool(presentation.get("show_hud", false)), expected_hud)


func _assert_true(label: String, condition: bool) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	m_failures.append("%s. Expected true, got false." % label)


func _assert_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual == expected:
		print("PASS: %s" % label)
		return
	m_failures.append("%s. Expected %s, got %s." % [label, str(expected), str(actual)])
