# res://game/go_game/go_ai_agent.gd
@tool
class_name GoAIAgent
extends Node

# GoAIAgent depends on GoGame (one-way dependency).
# Guarantee: AI makes at most ONE move per GoGame turn token.

@export var game_path: NodePath:
	set(v):
		game_path = v
		_bind_game()

@export var enabled: bool = true:
	set(v):
		enabled = v
		_trigger_if_needed()

@export var ai_color: int = GoGame.Stone.WHITE:
	set(v):
		ai_color = v
		_trigger_if_needed()

@export_range(0, 2, 1) var level: int = 1
@export var delay_sec: float = 0.15

var m_game: GoGame = null
var m_rng: RandomNumberGenerator = RandomNumberGenerator.new()

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
	m_game = n as GoGame
	if m_game == null:
		return

	if not m_game.turn_changed.is_connected(_on_turn_changed):
		m_game.turn_changed.connect(_on_turn_changed)
	if not m_game.game_reset.is_connected(_on_game_reset):
		m_game.game_reset.connect(_on_game_reset)

	# IMPORTANT:
	# Set "seen" to one behind so AI can act immediately if it is Black at game start.
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
	m_pending = false
	m_pending_token = -1
	m_turn_token_seen = -1

func _on_game_reset() -> void:
	if m_game == null:
		return
	# Same logic: allow immediate first move if AI is Black.
	m_turn_token_seen = m_game.get_turn_token() - 1
	m_pending = false
	m_pending_token = -1
	_trigger_if_needed()

func _on_turn_changed(_turn_color: int) -> void:
	_trigger_if_needed()

func _is_my_turn() -> bool:
	return enabled and m_game != null and m_game.get_turn() == ai_color and (not Engine.is_editor_hint())

func _trigger_if_needed() -> void:
	if m_game == null:
		return
	if not _is_my_turn():
		return

	var token := m_game.get_turn_token()

	# Already acted for this token OR already scheduled for this token.
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

	# If game advanced since scheduling, abort.
	if m_game.get_turn_token() != token:
		m_pending = false
		return

	if delay_sec > 0.0 and is_inside_tree():
		await get_tree().create_timer(delay_sec).timeout

	# Re-check after delay
	if m_game == null:
		m_pending = false
		return
	if m_game.get_turn_token() != token:
		m_pending = false
		return
	if not _is_my_turn():
		m_pending = false
		return

	var move := _choose_move()
	if move.x >= 0:
		m_game.play_move(move)
	# If no legal moves, AI effectively "passes" for this token.

	m_turn_token_seen = token
	m_pending = false
	m_pending_token = -1

func _choose_move() -> Vector2i:
	var bs := m_game.get_board_size()
	var legal: Array[Vector2i] = []
	var best_moves: Array[Vector2i] = []
	var best_score: float = -1e30

	var center := Vector2(float(bs - 1) * 0.5, float(bs - 1) * 0.5)

	for y in range(bs):
		for x in range(bs):
			var c := Vector2i(x, y)
			if not m_game.is_empty_cell(c):
				continue

			var info: Dictionary = {}
			if not m_game.simulate_move(ai_color, c, info):
				continue

			legal.append(c)

			if level == 0:
				continue

			var captured: int = int(info.get("captured", 0))
			var self_lib: int = int(info.get("self_liberties", 0))
			var dist := center.distance_to(Vector2(x, y))
			var center_bonus := -dist

			var score: float = 0.0
			if level >= 1:
				score += float(captured) * 1000.0
				score += float(self_lib) * 2.0
				score += center_bonus * 0.8
			if level >= 2:
				score += float(captured) * 800.0
				score += float(self_lib) * 4.0
				score += center_bonus * 1.2

			if score > best_score + 0.0001:
				best_score = score
				best_moves = [c]
			elif absf(score - best_score) <= 0.0001:
				best_moves.append(c)

	if legal.is_empty():
		return Vector2i(-1, -1)

	if level == 0 or best_moves.is_empty():
		return legal[m_rng.randi_range(0, legal.size() - 1)]
	return best_moves[m_rng.randi_range(0, best_moves.size() - 1)]
