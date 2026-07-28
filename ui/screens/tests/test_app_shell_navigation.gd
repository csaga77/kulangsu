extends Node

const MAIN_SCENE := preload("res://main.tscn")
const APP_SCREEN_ROUTER_SCRIPT := preload("res://ui/app_screen_router.gd")
const HUMAN_BODY_SCENE := preload("res://characters/human_body_3d.tscn")
const PLAYER_CONTROLLER_SCRIPT := preload(
	"res://characters/control/player_controller_3d.gd"
)
const ScreenState = APP_SCREEN_ROUTER_SCRIPT.ScreenState

var m_failures := PackedStringArray()
var m_unhandled_mouse_motion_count := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")


func _run() -> void:
	var shell := MAIN_SCENE.instantiate()
	add_child(shell)
	await get_tree().process_frame

	shell.call("_show_title")
	_assert_shell_state(shell, "Title route", ScreenState.TITLE, true, false, false, true, false)

	shell.call("_on_title_settings_pressed")
	_assert_shell_state(shell, "Title settings", ScreenState.SETTINGS, false, true, false, true, false)
	shell.call("_close_settings_panel")
	_assert_shell_state(shell, "Settings back", ScreenState.TITLE, true, false, false, true, false)

	shell.call("_show_confirm", "Quit?", "Return to title state?", Callable())
	_assert_shell_state(shell, "Title confirm", ScreenState.CONFIRM, true, false, true, true, false)
	shell.call("_hide_confirm")
	_assert_shell_state(shell, "Title confirm cancel", ScreenState.TITLE, true, false, false, true, false)

	var fake_game_root := Node3D.new()
	fake_game_root.name = "FakeGameRoot"
	shell.get_node("GameLayer").add_child(fake_game_root)
	shell.set("m_game_root", fake_game_root)
	shell.call("_replace_route", ScreenState.PLAYING)
	_assert_shell_state(shell, "Gameplay route", ScreenState.PLAYING, false, false, false, false, true)
	_assert_true("Gameplay route shows the world", fake_game_root.visible)
	await _assert_gameplay_mouse_passthrough(shell)

	var fake_player := HUMAN_BODY_SCENE.instantiate() as HumanBody3D
	fake_player.name = "FakePlayer"
	fake_player.character_model_scene = null
	fake_player.draw_skeleton_bones = false
	fake_player.add_to_group("player")
	var controller := PLAYER_CONTROLLER_SCRIPT.new() as PlayerController3D
	fake_player.controller = controller
	fake_game_root.add_child(fake_player)
	var consume_cancel := true
	controller.cancel_requested.connect(
		func() -> void:
			if consume_cancel:
				controller.consume_cancel_request()
	)
	shell.call("_handle_escape")
	_assert_shell_state(
		shell,
		"Active action consumes first Escape",
		ScreenState.PLAYING,
		false,
		false,
		false,
		false,
		true
	)
	consume_cancel = false
	controller.clear_cancel_request()
	shell.call("_handle_escape")
	_assert_shell_state(shell, "Pause route", ScreenState.PAUSE, false, false, false, true, true, true)
	shell.call("_open_overlay", ScreenState.SETTINGS)
	_assert_shell_state(shell, "Gameplay settings", ScreenState.SETTINGS, false, true, false, true, true, true)
	shell.call("_close_settings_panel")
	_assert_shell_state(shell, "Gameplay settings back", ScreenState.PAUSE, false, false, false, true, true, true)

	shell.call("_show_confirm", "Return?", "Keep pause beneath this modal.", Callable())
	_assert_shell_state(shell, "Pause confirm", ScreenState.CONFIRM, false, false, true, true, true, true)
	shell.call("_hide_confirm")
	_assert_shell_state(shell, "Pause confirm cancel", ScreenState.PAUSE, false, false, false, true, true, true)

	shell.call("_resume_gameplay")
	_assert_shell_state(shell, "Resume route", ScreenState.PLAYING, false, false, false, false, true)
	_assert_true("Resume keeps the world visible", fake_game_root.visible)

	get_tree().paused = false
	if m_failures.is_empty():
		print("PASS: app shell navigation regression")
	else:
		for failure in m_failures:
			push_error(failure)
		push_error("App shell navigation regression failed with %d issue(s)." % m_failures.size())

	shell.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if m_failures.is_empty() else 1)


func _assert_shell_state(
	shell: Node,
	label: String,
	expected_state: int,
	title_visible: bool,
	settings_visible: bool,
	confirm_visible: bool,
	backdrop_visible: bool,
	hud_visible: bool,
	paused: bool = false
) -> void:
	_assert_equal("%s has the expected state" % label, int(shell.get("m_state")), expected_state)
	_assert_equal("%s resolves title visibility" % label, _panel_visible(shell, "m_title_screen"), title_visible)
	_assert_equal("%s resolves settings visibility" % label, _panel_visible(shell, "m_settings_panel"), settings_visible)
	_assert_equal("%s resolves confirm visibility" % label, _panel_visible(shell, "m_confirm_panel"), confirm_visible)
	_assert_equal("%s resolves backdrop visibility" % label, _panel_visible(shell, "m_backdrop"), backdrop_visible)
	_assert_equal("%s resolves HUD visibility" % label, _panel_visible(shell, "m_hud"), hud_visible)
	_assert_equal("%s resolves pause state" % label, get_tree().paused, paused)


func _panel_visible(shell: Node, property_name: String) -> bool:
	var panel := shell.get(property_name) as CanvasItem
	return panel != null and panel.visible


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		m_unhandled_mouse_motion_count += 1


func _assert_gameplay_mouse_passthrough(shell: Node) -> void:
	var viewport_root := shell.get("m_viewport_root") as Control
	var ui_root := shell.get("m_ui_root") as Control
	var hud := shell.get("m_hud") as Control
	_assert_true(
		"Gameplay viewport root passes mouse input to the world",
		viewport_root != null and viewport_root.mouse_filter == Control.MOUSE_FILTER_IGNORE
	)
	_assert_true(
		"Gameplay UI root passes mouse input to the world",
		ui_root != null and ui_root.mouse_filter == Control.MOUSE_FILTER_IGNORE
	)
	_assert_true(
		"Gameplay HUD passes mouse input to the world",
		hud != null and _control_tree_ignores_mouse(hud)
	)

	var previous_motion_count := m_unhandled_mouse_motion_count
	var motion := InputEventMouseMotion.new()
	motion.position = get_viewport().get_visible_rect().size * 0.5
	motion.relative = Vector2(12.0, 0.0)
	Input.parse_input_event(motion)
	await get_tree().process_frame
	_assert_true(
		"Gameplay mouse motion reaches the unhandled world-input stage",
		m_unhandled_mouse_motion_count > previous_motion_count
	)


func _control_tree_ignores_mouse(root_control: Control) -> bool:
	if root_control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return false
	for node in root_control.find_children("*", "Control", true, false):
		var child_control := node as Control
		if child_control != null and child_control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			return false
	return true


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
