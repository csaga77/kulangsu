extends Node

const GAME_SCENE: PackedScene = preload("res://scenes/game_main.tscn")
const BOOT_SCREEN_SCENE: PackedScene = preload("res://ui/screens/boot_screen.tscn")
const TITLE_SCREEN_SCENE: PackedScene = preload("res://ui/screens/title_screen.tscn")
const PLAYER_SETUP_SCENE: PackedScene = preload("res://ui/screens/player_customization_overlay.tscn")
const HUD_SCENE: PackedScene = preload("res://ui/screens/game_hud.tscn")
const JOURNAL_SCENE: PackedScene = preload("res://ui/screens/journal_overlay.tscn")
const PAUSE_SCENE: PackedScene = preload("res://ui/screens/pause_overlay.tscn")
const SETTINGS_SCENE: PackedScene = preload("res://ui/screens/settings_overlay.tscn")
const CREDITS_SCENE: PackedScene = preload("res://ui/screens/credits_overlay.tscn")
const ENDING_SCENE: PackedScene = preload("res://ui/screens/ending_overlay.tscn")
const CONFIRM_SCENE: PackedScene = preload("res://ui/screens/confirm_modal.tscn")
const UI_DESIGN_SIZE := Vector2(1920.0, 1080.0)

enum ScreenState {
	BOOT,
	TITLE,
	PLAYER_SETUP,
	PLAYING,
	JOURNAL,
	PAUSE,
	SETTINGS,
	CREDITS,
	ENDING,
	CONFIRM,
}

var m_state: ScreenState = ScreenState.BOOT
var m_game_root: Node = null
var m_has_resume_state := false

var m_viewport_root: Control
var m_ui_root: Control
var m_backdrop: ColorRect
var m_boot_screen: Control
var m_title_screen: Control
var m_player_setup_panel: PanelContainer
var m_hud: Control
var m_journal_panel: PanelContainer
var m_pause_panel: PanelContainer
var m_settings_panel: PanelContainer
var m_credits_panel: PanelContainer
var m_ending_panel: PanelContainer
var m_confirm_panel: PanelContainer
var m_confirm_action: Callable
var m_pending_setup_free_walk := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if !AppState.story_milestone.is_connected(_on_story_milestone):
		AppState.story_milestone.connect(_on_story_milestone)
	_build_app_shell()
	get_viewport().size_changed.connect(_update_ui_layout)
	_update_ui_layout()
	_show_boot_sequence()


func _input(event: InputEvent) -> void:
	if event.is_echo():
		return

	if m_state == ScreenState.BOOT and event.is_pressed():
		_show_title()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				_handle_escape()
				get_viewport().set_input_as_handled()
			KEY_J:
				if _is_game_active():
					if !AppState.is_journal_unlocked():
						if m_state == ScreenState.PLAYING:
							AppState.set_save_status("The journal will open after you return to Caretaker Lian with the harbor clue.")
					elif m_state == ScreenState.JOURNAL:
						_resume_gameplay()
					elif m_state == ScreenState.PLAYING:
						_open_overlay(ScreenState.JOURNAL)
					get_viewport().set_input_as_handled()


func _build_app_shell() -> void:
	var game_layer := Node2D.new()
	game_layer.name = "GameLayer"
	add_child(game_layer)

	var ui_layer := CanvasLayer.new()
	ui_layer.name = "UILayer"
	ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui_layer)

	m_viewport_root = Control.new()
	m_viewport_root.name = "ViewportRoot"
	m_viewport_root.process_mode = Node.PROCESS_MODE_ALWAYS
	m_viewport_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(m_viewport_root)

	m_backdrop = ColorRect.new()
	m_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	m_backdrop.color = Color(0.06, 0.10, 0.14, 1.0)
	m_viewport_root.add_child(m_backdrop)

	m_ui_root = Control.new()
	m_ui_root.name = "Root"
	m_ui_root.process_mode = Node.PROCESS_MODE_ALWAYS
	m_ui_root.position = Vector2.ZERO
	m_ui_root.custom_minimum_size = UI_DESIGN_SIZE
	m_ui_root.size = UI_DESIGN_SIZE
	m_viewport_root.add_child(m_ui_root)

	m_boot_screen = BOOT_SCREEN_SCENE.instantiate() as Control
	m_ui_root.add_child(m_boot_screen)
	if m_boot_screen.has_signal("skipped"):
		m_boot_screen.connect("skipped", _show_title)

	m_title_screen = TITLE_SCREEN_SCENE.instantiate() as Control
	m_ui_root.add_child(m_title_screen)
	m_title_screen.connect("continue_pressed", _on_continue_pressed)
	m_title_screen.connect("new_game_pressed", _on_new_game_pressed)
	m_title_screen.connect("free_walk_pressed", _on_free_walk_pressed)
	m_title_screen.connect("settings_pressed", _on_title_settings_pressed)
	m_title_screen.connect("credits_pressed", _on_title_credits_pressed)
	m_title_screen.connect("quit_pressed", _on_title_quit_pressed)

	m_player_setup_panel = PLAYER_SETUP_SCENE.instantiate() as PanelContainer
	m_ui_root.add_child(m_player_setup_panel)
	m_player_setup_panel.connect("confirm_requested", _on_player_setup_confirmed)
	m_player_setup_panel.connect("cancel_requested", _on_player_setup_cancelled)

	m_hud = HUD_SCENE.instantiate() as Control
	m_ui_root.add_child(m_hud)

	m_journal_panel = JOURNAL_SCENE.instantiate() as PanelContainer
	m_ui_root.add_child(m_journal_panel)
	m_journal_panel.connect("close_requested", _resume_gameplay)

	m_pause_panel = PAUSE_SCENE.instantiate() as PanelContainer
	m_ui_root.add_child(m_pause_panel)
	m_pause_panel.connect("resume_requested", _resume_gameplay)
	m_pause_panel.connect("journal_requested", func() -> void:
		_open_overlay(ScreenState.JOURNAL)
	)
	m_pause_panel.connect("settings_requested", func() -> void:
		_open_overlay(ScreenState.SETTINGS)
	)
	m_pause_panel.connect("return_to_title_requested", func() -> void:
		_show_confirm(
			"Return to Title?",
			"The current prototype does not save story progress. Return anyway?",
			_return_to_title
		)
	)
	m_pause_panel.connect("quit_requested", func() -> void:
		_show_confirm(
			"Quit the App?",
			"Leave Kulangsu for now?",
			func() -> void:
				get_tree().quit()
		)
	)

	m_settings_panel = SETTINGS_SCENE.instantiate() as PanelContainer
	m_ui_root.add_child(m_settings_panel)
	m_settings_panel.connect("back_requested", _close_settings_panel)

	m_credits_panel = CREDITS_SCENE.instantiate() as PanelContainer
	m_ui_root.add_child(m_credits_panel)
	m_credits_panel.connect("back_requested", func() -> void:
		if _is_game_active():
			_resume_gameplay()
		else:
			_set_panel_visible(m_credits_panel, false)
			_show_title()
	)

	m_ending_panel = ENDING_SCENE.instantiate() as PanelContainer
	m_ui_root.add_child(m_ending_panel)
	m_ending_panel.connect("return_to_title_requested", func() -> void:
		_show_confirm(
			"Return to Title?",
			"The ferry departs at dawn. Roll credits and return to title?",
			_return_to_title
		)
	)
	m_ending_panel.connect("stay_requested", func() -> void:
		AppState.configure_postgame()
		_resume_gameplay()
	)
	m_ending_panel.connect("credits_requested", func() -> void:
		_open_overlay(ScreenState.CREDITS)
	)

	m_confirm_panel = CONFIRM_SCENE.instantiate() as PanelContainer
	m_ui_root.add_child(m_confirm_panel)
	m_confirm_panel.connect("cancel_requested", _hide_confirm)
	m_confirm_panel.connect("confirm_requested", _on_confirm_accepted)

	_set_panel_visible(m_title_screen, false)
	_set_panel_visible(m_player_setup_panel, false)
	_set_panel_visible(m_hud, false)
	_set_panel_visible(m_journal_panel, false)
	_set_panel_visible(m_pause_panel, false)
	_set_panel_visible(m_settings_panel, false)
	_set_panel_visible(m_credits_panel, false)
	_set_panel_visible(m_ending_panel, false)
	_set_panel_visible(m_confirm_panel, false)


func _update_ui_layout() -> void:
	if m_ui_root == null or !is_instance_valid(m_ui_root):
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var scale_factor: float = min(
		viewport_size.x / UI_DESIGN_SIZE.x,
		viewport_size.y / UI_DESIGN_SIZE.y
	)
	scale_factor = max(scale_factor, 0.1)

	m_ui_root.scale = Vector2.ONE * scale_factor
	m_ui_root.position = (viewport_size - (UI_DESIGN_SIZE * scale_factor)) / 2.0


func _show_boot_sequence() -> void:
	m_state = ScreenState.BOOT
	_set_panel_visible(m_boot_screen, true)
	_set_panel_visible(m_title_screen, false)
	await get_tree().create_timer(1.1, true, false, true).timeout
	if m_state == ScreenState.BOOT:
		_show_title()


func _show_title() -> void:
	m_state = ScreenState.TITLE
	get_tree().paused = false
	_set_panel_visible(m_backdrop, true)
	_set_panel_visible(m_boot_screen, false)
	_set_panel_visible(m_title_screen, true)
	_set_panel_visible(m_player_setup_panel, false)
	_set_panel_visible(m_hud, false)
	_set_panel_visible(m_journal_panel, false)
	_set_panel_visible(m_pause_panel, false)
	_set_panel_visible(m_settings_panel, false)
	_set_panel_visible(m_credits_panel, false)
	_set_panel_visible(m_ending_panel, false)
	_set_panel_visible(m_confirm_panel, false)
	if m_game_root != null:
		m_game_root.visible = false
	m_title_screen.call("set_continue_enabled", m_has_resume_state)
	AppState.set_mode("Title")


func _ensure_game_loaded() -> void:
	if m_game_root != null and is_instance_valid(m_game_root):
		m_game_root.visible = true
		return

	if m_game_root != null and !is_instance_valid(m_game_root):
		m_game_root = null

	m_game_root = GAME_SCENE.instantiate()
	m_game_root.name = "GameRoot"
	get_node("GameLayer").add_child(m_game_root)


func _discard_game_loaded() -> void:
	if m_game_root == null:
		return
	if !is_instance_valid(m_game_root):
		m_game_root = null
		return

	var previous_root := m_game_root
	m_game_root = null
	var game_layer := get_node_or_null("GameLayer")
	if game_layer != null and previous_root.get_parent() == game_layer:
		game_layer.remove_child(previous_root)
	previous_root.queue_free()


func _begin_gameplay(is_free_walk: bool, is_continue: bool = false) -> void:
	_discard_game_loaded()
	if is_continue:
		AppState.configure_continue()
	elif is_free_walk:
		AppState.configure_free_walk()
	else:
		AppState.configure_new_game()

	m_has_resume_state = true
	_ensure_game_loaded()
	m_game_root.visible = true
	if m_game_root.has_method("sync_ui_state"):
		m_game_root.call("sync_ui_state")

	_set_panel_visible(m_backdrop, false)
	_set_panel_visible(m_boot_screen, false)
	_set_panel_visible(m_title_screen, false)
	_set_panel_visible(m_player_setup_panel, false)
	_set_panel_visible(m_hud, true)
	_set_panel_visible(m_journal_panel, false)
	_set_panel_visible(m_pause_panel, false)
	_set_panel_visible(m_settings_panel, false)
	_set_panel_visible(m_credits_panel, false)
	_set_panel_visible(m_ending_panel, false)
	_set_panel_visible(m_confirm_panel, false)
	m_state = ScreenState.PLAYING
	get_tree().paused = false


func _open_overlay(new_state: ScreenState) -> void:
	if !_is_game_active():
		return
	if new_state == ScreenState.JOURNAL and !AppState.is_journal_unlocked():
		AppState.set_save_status("The journal will open after you return to Caretaker Lian with the harbor clue.")
		return
	m_state = new_state
	get_tree().paused = true
	_refresh_journal_content()
	_refresh_ending_content()
	if new_state == ScreenState.PAUSE:
		m_pause_panel.call("set_journal_enabled", AppState.is_journal_unlocked())
	_set_panel_visible(m_backdrop, true)
	_set_panel_visible(m_hud, true)
	_set_panel_visible(m_journal_panel, new_state == ScreenState.JOURNAL)
	_set_panel_visible(m_pause_panel, new_state == ScreenState.PAUSE)
	_set_panel_visible(m_settings_panel, new_state == ScreenState.SETTINGS)
	_set_panel_visible(m_credits_panel, new_state == ScreenState.CREDITS)
	_set_panel_visible(m_ending_panel, new_state == ScreenState.ENDING)
	_set_panel_visible(m_confirm_panel, false)


func _resume_gameplay() -> void:
	if !_is_game_active():
		return
	m_state = ScreenState.PLAYING
	get_tree().paused = false
	_set_panel_visible(m_backdrop, false)
	_set_panel_visible(m_journal_panel, false)
	_set_panel_visible(m_pause_panel, false)
	_set_panel_visible(m_settings_panel, false)
	_set_panel_visible(m_credits_panel, false)
	_set_panel_visible(m_ending_panel, false)
	_set_panel_visible(m_confirm_panel, false)
	_set_panel_visible(m_hud, true)


func _close_settings_panel() -> void:
	if _is_game_active():
		_open_overlay(ScreenState.PAUSE)
	else:
		_set_panel_visible(m_backdrop, true)
		_set_panel_visible(m_settings_panel, false)
		_show_title()


func _show_confirm(title_text: String, body_text: String, action: Callable) -> void:
	m_confirm_action = action
	m_confirm_panel.call("set_content", title_text, body_text)
	_set_panel_visible(m_backdrop, true)
	_set_panel_visible(m_confirm_panel, true)
	m_state = ScreenState.CONFIRM
	get_tree().paused = _is_game_active()


func _hide_confirm() -> void:
	_set_panel_visible(m_confirm_panel, false)
	if _is_game_active():
		if m_pause_panel.visible:
			m_state = ScreenState.PAUSE
			_set_panel_visible(m_backdrop, true)
		elif m_ending_panel.visible:
			m_state = ScreenState.ENDING
			_set_panel_visible(m_backdrop, true)
		else:
			m_state = ScreenState.PLAYING
			get_tree().paused = false
			_set_panel_visible(m_backdrop, false)
	else:
		m_state = ScreenState.TITLE
		_set_panel_visible(m_backdrop, true)


func _return_to_title() -> void:
	get_tree().paused = false
	if m_game_root != null:
		m_game_root.visible = false
	_show_title()


func _refresh_journal_content() -> void:
	m_journal_panel.call("refresh_from_state")


func _refresh_ending_content() -> void:
	m_ending_panel.call("refresh_from_state")


func _handle_escape() -> void:
	match m_state:
		ScreenState.BOOT:
			_show_title()
		ScreenState.TITLE:
			_show_confirm(
				"Quit the App?",
				"Leave Kulangsu for now?",
				func() -> void:
					get_tree().quit()
			)
		ScreenState.PLAYER_SETUP:
			_show_title()
		ScreenState.PLAYING:
			_open_overlay(ScreenState.PAUSE)
		ScreenState.JOURNAL:
			_resume_gameplay()
		ScreenState.PAUSE:
			_resume_gameplay()
		ScreenState.SETTINGS:
			_close_settings_panel()
		ScreenState.CREDITS:
			if _is_game_active():
				_resume_gameplay()
			else:
				_set_panel_visible(m_credits_panel, false)
				_show_title()
		ScreenState.ENDING:
			_resume_gameplay()
		ScreenState.CONFIRM:
			_hide_confirm()


func _on_confirm_accepted() -> void:
	_hide_confirm()
	if m_confirm_action.is_valid():
		m_confirm_action.call()


func _set_panel_visible(node: CanvasItem, is_visible: bool) -> void:
	node.visible = is_visible


func _is_game_active() -> bool:
	return m_game_root != null and is_instance_valid(m_game_root) and m_game_root.visible


func _on_continue_pressed() -> void:
	_begin_gameplay(false, true)


func _on_new_game_pressed() -> void:
	_open_player_setup(false)


func _on_free_walk_pressed() -> void:
	_open_player_setup(true)


func _on_title_settings_pressed() -> void:
	_set_panel_visible(m_title_screen, false)
	_set_panel_visible(m_settings_panel, true)
	m_state = ScreenState.SETTINGS


func _on_title_credits_pressed() -> void:
	_set_panel_visible(m_title_screen, false)
	_set_panel_visible(m_credits_panel, true)
	m_state = ScreenState.CREDITS


func _on_title_quit_pressed() -> void:
	_show_confirm(
		"Quit the App?",
		"Leave Kulangsu for now?",
		func() -> void: get_tree().quit()
	)


func _open_player_setup(is_free_walk: bool) -> void:
	m_pending_setup_free_walk = is_free_walk
	m_player_setup_panel.call("set_flow_context", is_free_walk)
	m_player_setup_panel.call("refresh_from_state")
	_set_panel_visible(m_backdrop, true)
	_set_panel_visible(m_title_screen, false)
	_set_panel_visible(m_player_setup_panel, true)
	_set_panel_visible(m_confirm_panel, false)
	m_state = ScreenState.PLAYER_SETUP
	get_tree().paused = false


func _on_player_setup_confirmed() -> void:
	_begin_gameplay(m_pending_setup_free_walk, false)


func _on_player_setup_cancelled() -> void:
	_show_title()


func _on_story_milestone(milestone_id: String, _context: Dictionary) -> void:
	if milestone_id == "festival_performed" and _is_game_active():
		_open_overlay(ScreenState.ENDING)
