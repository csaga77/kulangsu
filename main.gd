extends Node

# The low-poly 3D overworld is the runtime overworld (Phase G cutover recorded in
# docs/plan/low_poly_3d_replacement.md and docs/plan/implementation_plan.md). The 2D
# overworld (formerly scenes/game_main.tscn) has been retired and removed.
const GAME_SCENE: PackedScene = preload("res://scenes/game_world_3d.tscn")
const BOOT_SCREEN_SCENE: PackedScene = preload("res://ui/screens/boot_screen.tscn")
const TITLE_SCREEN_SCENE: PackedScene = preload("res://ui/screens/title_screen.tscn")
const PLAYER_SETUP_SCENE: PackedScene = preload("res://ui/screens/player_customization_overlay.tscn")
const HUD_SCENE: PackedScene = preload("res://ui/screens/game_hud.tscn")
const JOURNAL_SCENE: PackedScene = preload("res://ui/screens/journal_overlay.tscn")
const MELODY_PROMPT_SCENE: PackedScene = preload("res://ui/screens/melody_prompt_overlay.tscn")
const PAUSE_SCENE: PackedScene = preload("res://ui/screens/pause_overlay.tscn")
const SETTINGS_SCENE: PackedScene = preload("res://ui/screens/settings_overlay.tscn")
const CREDITS_SCENE: PackedScene = preload("res://ui/screens/credits_overlay.tscn")
const ENDING_SCENE: PackedScene = preload("res://ui/screens/ending_overlay.tscn")
const DEPARTURE_SCENE: PackedScene = preload("res://ui/screens/departure_overlay.tscn")
const CONFIRM_SCENE: PackedScene = preload("res://ui/screens/confirm_modal.tscn")
const APP_SCREEN_ROUTER_SCRIPT := preload("res://ui/app_screen_router.gd")
const APP_RUNTIME := preload("res://game/app_runtime.gd")
const WEATHER_RUNTIME := preload("res://weather/weather_runtime.gd")
const UI_DESIGN_SIZE := Vector2(1920.0, 1080.0)
const ScreenState = APP_SCREEN_ROUTER_SCRIPT.ScreenState

var m_state: int = ScreenState.BOOT
var m_game_root: Node = null
var m_has_resume_state := false
var m_screen_router: APP_SCREEN_ROUTER_SCRIPT = APP_SCREEN_ROUTER_SCRIPT.new(ScreenState.BOOT)
var m_route_panels: Dictionary = {}

var m_viewport_root: Control
var m_ui_root: Control
var m_backdrop: ColorRect
var m_boot_screen: Control
var m_title_screen: Control
var m_player_setup_panel: PanelContainer
var m_hud: Control
var m_journal_panel: PanelContainer
var m_melody_prompt_panel: PanelContainer
var m_pause_panel: PanelContainer
var m_settings_panel: PanelContainer
var m_credits_panel: PanelContainer
var m_ending_panel: PanelContainer
var m_departure_panel: PanelContainer
var m_confirm_panel: PanelContainer
var m_confirm_action: Callable
var m_pending_setup_free_walk := false


func _app_state():
	return APP_RUNTIME.get_app_state(self)


func _enter_tree() -> void:
	_app_state()
	WEATHER_RUNTIME.get_weather_manager(self)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if !_app_state().story_milestone.is_connected(_on_story_milestone):
		_app_state().story_milestone.connect(_on_story_milestone)
	if !_app_state().melody_prompt_requested.is_connected(_on_melody_prompt_requested):
		_app_state().melody_prompt_requested.connect(_on_melody_prompt_requested)
	_build_app_shell()
	if !_app_state().state_committed.is_connected(_on_state_committed):
		_app_state().state_committed.connect(_on_state_committed)
	_refresh_story_save_state(_app_state().get_save_metadata())
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
					if !_app_state().get_projection().journal_unlocked:
						if m_state == ScreenState.PLAYING:
							_app_state().update_world_context({
								"status": "The journal will open after you return to Caretaker Lian with the harbor clue.",
							})
					elif m_state == ScreenState.JOURNAL:
						_resume_gameplay()
					elif m_state == ScreenState.PLAYING:
						_open_overlay(ScreenState.JOURNAL)
					get_viewport().set_input_as_handled()


func _build_app_shell() -> void:
	var game_layer := Node.new()
	game_layer.name = "GameLayer"
	add_child(game_layer)

	var ui_layer := CanvasLayer.new()
	ui_layer.name = "UILayer"
	ui_layer.layer = 10
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

	m_melody_prompt_panel = MELODY_PROMPT_SCENE.instantiate() as PanelContainer
	m_ui_root.add_child(m_melody_prompt_panel)
	m_melody_prompt_panel.connect("close_requested", _close_melody_prompt)
	m_melody_prompt_panel.connect("practice_completed", _on_melody_prompt_practice_completed)
	m_melody_prompt_panel.connect("performance_completed", _on_melody_prompt_performance_completed)

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
			"The latest safe story checkpoint will be autosaved before you leave.",
			_return_to_title
		)
	)
	m_pause_panel.connect("quit_requested", func() -> void:
		_show_confirm(
			"Quit the App?",
			"Leave Kulangsu for now?",
			func() -> void:
				_persist_story_session()
				get_tree().quit()
		)
	)

	m_settings_panel = SETTINGS_SCENE.instantiate() as PanelContainer
	m_ui_root.add_child(m_settings_panel)
	m_settings_panel.connect("back_requested", _close_settings_panel)

	m_credits_panel = CREDITS_SCENE.instantiate() as PanelContainer
	m_ui_root.add_child(m_credits_panel)
	m_credits_panel.connect("back_requested", _close_credits_panel)

	m_ending_panel = ENDING_SCENE.instantiate() as PanelContainer
	m_ui_root.add_child(m_ending_panel)
	m_ending_panel.connect("leave_requested", func() -> void:
		_app_state().apply_ending_choice("leave")
		_show_confirm(
			"Leave on the Morning Ferry?",
			"Depart Kulangsu, roll credits, and close this story run?",
			_complete_story_departure
		)
	)
	m_ending_panel.connect("continue_story_requested", func() -> void:
		if _app_state().continue_story_after_endgame():
			_resume_gameplay()
	)
	m_ending_panel.connect("credits_requested", func() -> void:
		_open_credits_panel()
	)

	m_departure_panel = DEPARTURE_SCENE.instantiate() as PanelContainer
	m_ui_root.add_child(m_departure_panel)
	m_departure_panel.connect("continue_requested", _on_departure_continue_requested)

	m_confirm_panel = CONFIRM_SCENE.instantiate() as PanelContainer
	m_ui_root.add_child(m_confirm_panel)
	m_confirm_panel.connect("cancel_requested", _hide_confirm)
	m_confirm_panel.connect("confirm_requested", _on_confirm_accepted)

	m_route_panels = {
		&"boot": m_boot_screen,
		&"title": m_title_screen,
		&"player_setup": m_player_setup_panel,
		&"journal": m_journal_panel,
		&"melody_prompt": m_melody_prompt_panel,
		&"pause": m_pause_panel,
		&"settings": m_settings_panel,
		&"credits": m_credits_panel,
		&"ending": m_ending_panel,
		&"departure": m_departure_panel,
		&"confirm": m_confirm_panel,
	}


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
	_replace_route(ScreenState.BOOT)
	await get_tree().create_timer(1.1, true, false, true).timeout
	if m_state == ScreenState.BOOT:
		_show_title()


func _show_title() -> void:
	_replace_route(ScreenState.TITLE)
	_refresh_story_save_state(_app_state().get_save_metadata())
	_app_state().enter_title_mode()


func _ensure_game_loaded() -> void:
	if m_game_root != null and is_instance_valid(m_game_root):
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
		if !_app_state().resume_story():
			_refresh_story_save_state(_app_state().get_save_metadata())
			_show_title()
			_show_confirm(
				"Continue Unavailable",
				"No usable story autosave was found. Start a new game or begin a free walk instead.",
				Callable()
			)
			return
	elif is_free_walk:
		_app_state().start_free_walk()
	else:
		_app_state().start_new_story()

	_refresh_story_save_state(_app_state().get_save_metadata())
	_ensure_game_loaded()
	if m_game_root.has_method("sync_ui_state"):
		m_game_root.call("sync_ui_state")

	_replace_route(ScreenState.PLAYING)
	if bool(_app_state().get_projection().endgame_state.get("active", false)):
		call_deferred("_open_overlay", ScreenState.ENDING)


func _open_overlay(new_state: int) -> void:
	if !_is_game_active():
		return
	if new_state == ScreenState.JOURNAL and !_app_state().get_projection().journal_unlocked:
		_app_state().update_world_context({
			"status": "The journal will open after you return to Caretaker Lian with the harbor clue.",
		})
		return
	if new_state == ScreenState.JOURNAL:
		_refresh_journal_content()
	elif new_state == ScreenState.ENDING:
		_refresh_ending_content()
	if new_state == ScreenState.PAUSE:
		m_pause_panel.call(
			"set_journal_enabled",
			_app_state().get_projection().journal_unlocked
		)
	_push_route(new_state)


func _resume_gameplay() -> void:
	if !_is_game_active():
		return
	_replace_route(ScreenState.PLAYING)


func _close_settings_panel() -> void:
	if !_pop_route():
		_show_title()


func _show_confirm(title_text: String, body_text: String, action: Callable) -> void:
	m_confirm_action = action
	m_confirm_panel.call("set_content", title_text, body_text)
	_push_route(ScreenState.CONFIRM)


func _hide_confirm() -> void:
	m_confirm_action = Callable()
	if !_pop_route():
		_show_title()


func _open_credits_panel() -> void:
	_push_route(ScreenState.CREDITS)


func _close_credits_panel() -> void:
	if !_pop_route():
		_show_title()


func _open_melody_prompt(request: Dictionary) -> void:
	if !_is_game_active():
		return

	m_melody_prompt_panel.call("configure_request", request)
	_push_route(ScreenState.MELODY_PROMPT)


func _close_melody_prompt() -> void:
	if !_is_game_active():
		return
	if !_pop_route():
		_resume_gameplay()
		return
	if m_state == ScreenState.JOURNAL:
		_refresh_journal_content()


func _return_to_title() -> void:
	_persist_story_session()
	_show_title()


func _complete_story_departure() -> void:
	_app_state().clear_story_save()
	_app_state().enter_title_mode()
	_discard_game_loaded()
	_open_departure_panel()


func _open_departure_panel() -> void:
	m_departure_panel.call("refresh_from_state")
	_replace_route(ScreenState.DEPARTURE)


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
			if !_pop_route():
				_show_title()
		ScreenState.PLAYING:
			_open_overlay(ScreenState.PAUSE)
		ScreenState.JOURNAL:
			_resume_gameplay()
		ScreenState.MELODY_PROMPT:
			_close_melody_prompt()
		ScreenState.PAUSE:
			_resume_gameplay()
		ScreenState.SETTINGS:
			_close_settings_panel()
		ScreenState.CREDITS:
			_close_credits_panel()
		ScreenState.ENDING:
			pass
		ScreenState.DEPARTURE:
			pass
		ScreenState.CONFIRM:
			_hide_confirm()


func _on_confirm_accepted() -> void:
	var action := m_confirm_action
	m_confirm_action = Callable()
	if !_pop_route():
		_show_title()
	if action.is_valid():
		action.call()


func _replace_route(state: int) -> bool:
	if !m_screen_router.replace_route(state):
		return false
	_render_routes()
	return true


func _push_route(state: int) -> bool:
	if !m_screen_router.push_route(state):
		return false
	_render_routes()
	return true


func _pop_route() -> bool:
	if !m_screen_router.pop_route():
		return false
	_render_routes()
	return true


func _render_routes() -> void:
	if m_route_panels.is_empty():
		return

	var presentation := m_screen_router.resolve_presentation()
	m_state = int(presentation.get("top_state", ScreenState.BOOT))
	for panel_value in m_route_panels.values():
		var panel := panel_value as CanvasItem
		if panel != null:
			_set_panel_visible(panel, false)

	var content_panel_id := StringName(presentation.get("content_panel_id", &""))
	_show_route_panel(content_panel_id)
	var modal_panel_id := StringName(presentation.get("modal_panel_id", &""))
	_show_route_panel(modal_panel_id)

	_set_panel_visible(m_backdrop, bool(presentation.get("show_backdrop", false)))
	_set_panel_visible(m_hud, bool(presentation.get("show_hud", false)))
	if m_game_root != null and is_instance_valid(m_game_root):
		m_game_root.visible = bool(presentation.get("game_context", false))
	get_tree().paused = bool(presentation.get("pause_game", false))
	_set_prompt_bgm_ducked(
		int(presentation.get("content_state", ScreenState.BOOT)) == ScreenState.MELODY_PROMPT
	)


func _show_route_panel(panel_id: StringName) -> void:
	if panel_id.is_empty():
		return
	var panel := m_route_panels.get(panel_id) as CanvasItem
	if panel != null:
		_set_panel_visible(panel, true)


func _set_panel_visible(node: CanvasItem, is_visible: bool) -> void:
	node.visible = is_visible


func _set_prompt_bgm_ducked(ducked: bool) -> void:
	if m_game_root == null or !is_instance_valid(m_game_root):
		return
	if m_game_root.has_method("set_prompt_bgm_ducked"):
		m_game_root.call("set_prompt_bgm_ducked", ducked)


func _is_game_active() -> bool:
	return m_game_root != null and is_instance_valid(m_game_root) and m_game_root.visible


func _persist_story_session() -> void:
	if _app_state().get_projection().mode_id == AppStateSnapshot.MODE_STORY:
		_app_state().request_autosave()


func _refresh_story_save_state(metadata: Dictionary) -> void:
	m_has_resume_state = bool(metadata.get("exists", false))
	if m_title_screen == null or !is_instance_valid(m_title_screen):
		return
	m_title_screen.call("set_continue_enabled", m_has_resume_state)
	m_title_screen.call("set_continue_metadata", metadata)


func _on_continue_pressed() -> void:
	if !m_has_resume_state:
		return
	_begin_gameplay(false, true)


func _on_new_game_pressed() -> void:
	_open_player_setup(false)


func _on_free_walk_pressed() -> void:
	_open_player_setup(true)


func _on_title_settings_pressed() -> void:
	_push_route(ScreenState.SETTINGS)


func _on_title_credits_pressed() -> void:
	_open_credits_panel()


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
	_push_route(ScreenState.PLAYER_SETUP)


func _on_player_setup_confirmed() -> void:
	_begin_gameplay(m_pending_setup_free_walk, false)


func _on_player_setup_cancelled() -> void:
	if !_pop_route():
		_show_title()


func _on_story_milestone(milestone_id: String, _context: Dictionary) -> void:
	if milestone_id == "endgame_started" and _is_game_active():
		_open_overlay(ScreenState.ENDING)


func _on_state_committed(changes: AppStateChangeSet) -> void:
	if changes.has_domain(AppStateChangeSet.Domain.SAVE):
		_refresh_story_save_state(_app_state().get_save_metadata())


func _on_melody_prompt_requested(request: Dictionary) -> void:
	if !_is_game_active():
		return
	_open_melody_prompt(request)


func _on_melody_prompt_practice_completed(request: Dictionary) -> void:
	_app_state().complete_prompt_request(request)
	_close_melody_prompt()


func _on_melody_prompt_performance_completed(request: Dictionary) -> void:
	_app_state().complete_prompt_request(request)
	if m_state == ScreenState.MELODY_PROMPT:
		_close_melody_prompt()


func _on_departure_continue_requested() -> void:
	_show_title()
	_open_credits_panel()
