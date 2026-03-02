# res://game/grid_board_game/board_ai_agent.gd
@tool
class_name GridBoardGameAIAgent
extends Node

# Scheduler + "one move per turn token".
# Delegates move selection to rule-specific strategy classes.

@export var game_path: NodePath:
	set(v):
		game_path = v
		_bind_game()

@export var enabled: bool = true:
	set(v):
		enabled = v
		_trigger_if_needed()

@export var ai_color: int = GridBoardGame.Stone.WHITE:
	set(v):
		ai_color = v
		_trigger_if_needed()

@export_range(0, 2, 1) var level: int = 1
@export var delay_sec: float = 0.15

var m_game: GridBoardGame = null
var m_rng: RandomNumberGenerator = RandomNumberGenerator.new()

# strategies (logic split)
var m_go_ai: BoardAIStrategy = GoAIStrategy.new()
var m_gomoku_ai: BoardAIStrategy = GomokuAIStrategy.new()
var m_ai: BoardAIStrategy = null

# one-move-per-turn-token guards
var m_pending: bool = false
var m_pending_token: int = -1
var m_turn_token_seen: int = -1

func _ready() -> void:
	m_rng.randomize()
	_bind_game()

func _exit_tree() -> void:
	_unbind_game()

func _bind_game() -> void:
	_unbind_game()

	if game_path == NodePath():
		return
	if not is_inside_tree():
		return

	var n := get_node_or_null(game_path)
	m_game = n as GridBoardGame
	if m_game == null:
		return

	if not m_game.turn_changed.is_connected(_on_turn_changed):
		m_game.turn_changed.connect(_on_turn_changed)
	if not m_game.game_reset.is_connected(_on_game_reset):
		m_game.game_reset.connect(_on_game_reset)

	_select_strategy()

	# allow immediate first move (important if AI is Black at start)
	m_turn_token_seen = m_game.get_turn_token() - 1
	m_pending = false
	m_pending_token = -1

	_trigger_if_needed()

func _unbind_game() -> void:
	if m_game:
		if m_game.turn_changed.is_connected(_on_turn_changed):
			m_game.turn_changed.disconnect(_on_turn_changed)
		if m_game.game_reset.is_connected(_on_game_reset):
			m_game.game_reset.disconnect(_on_game_reset)

	m_game = null
	m_ai = null
	m_pending = false
	m_pending_token = -1
	m_turn_token_seen = -1

func _on_game_reset() -> void:
	if m_game == null:
		return
	_select_strategy()
	m_turn_token_seen = m_game.get_turn_token() - 1
	m_pending = false
	m_pending_token = -1
	_trigger_if_needed()

func _on_turn_changed(_turn_color: int) -> void:
	_select_strategy()
	_trigger_if_needed()

func _select_strategy() -> void:
	if m_game == null:
		m_ai = null
		return
	m_ai = m_gomoku_ai if m_game.rules is GomokuRules else m_go_ai

func _is_game_over() -> bool:
	return m_game != null and m_game.has_method("is_game_over") and bool(m_game.call("is_game_over"))

func _is_my_turn() -> bool:
	if not enabled:
		return false
	if m_game == null:
		return false
	if m_ai == null:
		return false
	if Engine.is_editor_hint():
		return false
	if _is_game_over():
		return false
	return m_game.get_turn() == ai_color

func _trigger_if_needed() -> void:
	if m_game == null:
		return
	if not _is_my_turn():
		return

	var token := m_game.get_turn_token()

	if token == m_turn_token_seen:
		return
	if m_pending and token == m_pending_token:
		return

	m_pending = true
	m_pending_token = token
	call_deferred("_play_async", token)

func _play_async(token: int) -> void:
	if m_game == null:
		m_pending = false
		return

	if m_game.get_turn_token() != token:
		m_pending = false
		return

	if delay_sec > 0.0 and is_inside_tree():
		await get_tree().create_timer(delay_sec).timeout

	if m_game == null:
		m_pending = false
		return
	if m_game.get_turn_token() != token:
		m_pending = false
		return
	if not _is_my_turn():
		m_pending = false
		return

	var move := m_ai.choose_move(m_game, ai_color, level, m_rng)
	if move.x >= 0:
		m_game.play_move(move)

	m_turn_token_seen = token
	m_pending = false
	m_pending_token = -1
