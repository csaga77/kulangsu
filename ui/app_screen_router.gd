class_name AppScreenRouter
extends RefCounted

enum ScreenState {
	BOOT,
	TITLE,
	PLAYER_SETUP,
	PLAYING,
	JOURNAL,
	MELODY_PROMPT,
	PAUSE,
	SETTINGS,
	CREDITS,
	ENDING,
	DEPARTURE,
	CONFIRM,
}

const ROUTE_RULES: Dictionary = {
	ScreenState.BOOT: {
		"panel_id": &"boot",
		"game_context": false,
		"pause_game": false,
		"show_backdrop": true,
		"show_hud": false,
	},
	ScreenState.TITLE: {
		"panel_id": &"title",
		"game_context": false,
		"pause_game": false,
		"show_backdrop": true,
		"show_hud": false,
	},
	ScreenState.PLAYER_SETUP: {
		"panel_id": &"player_setup",
		"game_context": false,
		"pause_game": false,
		"show_backdrop": true,
		"show_hud": false,
	},
	ScreenState.PLAYING: {
		"panel_id": &"",
		"game_context": true,
		"pause_game": false,
		"show_backdrop": false,
		"show_hud": true,
	},
	ScreenState.JOURNAL: {
		"panel_id": &"journal",
		"game_context": true,
		"pause_game": true,
		"show_backdrop": true,
		"show_hud": true,
	},
	ScreenState.MELODY_PROMPT: {
		"panel_id": &"melody_prompt",
		"game_context": true,
		"pause_game": true,
		"show_backdrop": true,
		"show_hud": true,
	},
	ScreenState.PAUSE: {
		"panel_id": &"pause",
		"game_context": true,
		"pause_game": true,
		"show_backdrop": true,
		"show_hud": true,
	},
	ScreenState.SETTINGS: {
		"panel_id": &"settings",
		"inherit_context": true,
		"show_backdrop": true,
	},
	ScreenState.CREDITS: {
		"panel_id": &"credits",
		"inherit_context": true,
		"show_backdrop": true,
	},
	ScreenState.ENDING: {
		"panel_id": &"ending",
		"game_context": true,
		"pause_game": true,
		"show_backdrop": true,
		"show_hud": true,
	},
	ScreenState.DEPARTURE: {
		"panel_id": &"departure",
		"game_context": false,
		"pause_game": false,
		"show_backdrop": true,
		"show_hud": false,
	},
	ScreenState.CONFIRM: {
		"panel_id": &"confirm",
		"modal": true,
	},
}

var m_route_stack: Array[int] = []


func _init(initial_state: int = ScreenState.BOOT) -> void:
	if !replace_route(initial_state):
		m_route_stack.append(ScreenState.BOOT)


func replace_route(state: int) -> bool:
	if !_is_known_state(state) or _is_modal_state(state):
		return false
	m_route_stack.clear()
	m_route_stack.append(state)
	return true


func push_route(state: int) -> bool:
	if !_is_known_state(state):
		return false
	if m_route_stack.is_empty():
		if _is_modal_state(state):
			return false
		m_route_stack.append(state)
		return true
	if current_state() == state:
		return false
	m_route_stack.append(state)
	return true


func pop_route() -> bool:
	if m_route_stack.size() <= 1:
		return false
	m_route_stack.pop_back()
	return true


func current_state() -> int:
	if m_route_stack.is_empty():
		return ScreenState.BOOT
	return m_route_stack.back()


func get_route_stack() -> Array[int]:
	return m_route_stack.duplicate()


func resolve_presentation() -> Dictionary:
	if m_route_stack.is_empty():
		replace_route(ScreenState.BOOT)

	var top_index := m_route_stack.size() - 1
	var top_state := int(m_route_stack[top_index])
	var modal_panel_id: StringName = &""
	var content_index := top_index
	if _is_modal_state(top_state):
		modal_panel_id = StringName(_rule_for_state(top_state).get("panel_id", &""))
		content_index = _find_previous_content_index(top_index - 1)

	if content_index < 0:
		content_index = 0
	var content_state := int(m_route_stack[content_index])
	var content_rule := _rule_for_state(content_state)
	var context := _resolve_context(content_index)
	var game_context := bool(context.get("game_context", false))
	var pause_game := bool(context.get("pause_game", false))
	var show_backdrop := bool(content_rule.get("show_backdrop", false))
	if !modal_panel_id.is_empty():
		show_backdrop = true
		if game_context:
			pause_game = true

	return {
		"top_state": top_state,
		"content_state": content_state,
		"content_panel_id": StringName(content_rule.get("panel_id", &"")),
		"modal_panel_id": modal_panel_id,
		"game_context": game_context,
		"pause_game": pause_game,
		"show_backdrop": show_backdrop,
		"show_hud": bool(context.get("show_hud", false)),
	}


func _resolve_context(index: int) -> Dictionary:
	if index < 0 or index >= m_route_stack.size():
		return _default_context()

	var state := int(m_route_stack[index])
	var rule := _rule_for_state(state)
	if bool(rule.get("inherit_context", false)):
		return _resolve_context(_find_previous_content_index(index - 1))

	return {
		"game_context": bool(rule.get("game_context", false)),
		"pause_game": bool(rule.get("pause_game", false)),
		"show_hud": bool(rule.get("show_hud", false)),
	}


func _find_previous_content_index(start_index: int) -> int:
	for index in range(start_index, -1, -1):
		if !_is_modal_state(int(m_route_stack[index])):
			return index
	return -1


func _default_context() -> Dictionary:
	return {
		"game_context": false,
		"pause_game": false,
		"show_hud": false,
	}


func _rule_for_state(state: int) -> Dictionary:
	var rule_value: Variant = ROUTE_RULES.get(state, {})
	if rule_value is Dictionary:
		return rule_value as Dictionary
	return {}


func _is_known_state(state: int) -> bool:
	return ROUTE_RULES.has(state)


func _is_modal_state(state: int) -> bool:
	return bool(_rule_for_state(state).get("modal", false))
