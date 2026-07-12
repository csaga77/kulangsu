# MarbleGame.gd
@tool
class_name MarbleGame
extends Node3D

enum GameStatus { FREE_PLAY, WAITING_FOR_REST, WAITING_FOR_KICK, GAME_OVER }

@export var game_mode: MarbleGameMode:
	set(value):
		game_mode = value
		_apply_mode()

## X/Z board bounds. Rect2.y maps to world Z.
@export var spawn_bounds: Rect2 = Rect2()
@export var board_surface_y: float = 0.0

signal game_mode_changed(new_mode: MarbleGameMode)
signal status_changed(new_status: GameStatus)
signal turn_active_changed(is_active: bool)
signal current_ball_changed(ball: MarbleBall)
signal rest_progress_changed(progress_0_1: float)

signal ball_won(ball: MarbleBall)
signal ball_lost(ball: MarbleBall)
signal game_over

var m_winners: Array[MarbleBall] = []
var m_loser: MarbleBall = null
var m_active_lock_ball: MarbleBall = null

var m_status: GameStatus = GameStatus.WAITING_FOR_REST
var m_turn_active: bool = false
var m_rest_progress: float = 0.0
var m_current_ball: MarbleBall = null

var m_balls: Array[MarbleBall] = []
var m_mode: MarbleGameMode = null

@onready var m_hole: MarbleHole = $hole


func _ready() -> void:
	if not Engine.is_editor_hint():
		_auto_discover_balls()

	_assign_game_to_balls()

	if not Engine.is_editor_hint():
		restart_game()


func _auto_discover_balls() -> void:
	m_balls.clear()
	_find_balls_recursive(self)
	print("[MarbleGame] Auto found balls: ", m_balls.size())


func _find_balls_recursive(node: Node) -> void:
	for child: Node in node.get_children():
		if child is MarbleBall:
			m_balls.append(child as MarbleBall)
		_find_balls_recursive(child)


func get_balls() -> Array[MarbleBall]:
	return m_balls


func get_hole() -> MarbleHole:
	return m_hole


func get_spawn_rect_for_ball(ball: MarbleBall) -> Rect2:
	if ball == null or not is_instance_valid(ball):
		return Rect2()
	if spawn_bounds.size.x <= 0.0 or spawn_bounds.size.y <= 0.0:
		return Rect2()

	var margin: float = maxf(ball.marble_radius, 0.0)
	var usable_position: Vector2 = spawn_bounds.position + Vector2.ONE * margin
	var usable_size: Vector2 = spawn_bounds.size - Vector2.ONE * margin * 2.0
	if usable_size.x <= 0.0 or usable_size.y <= 0.0:
		return Rect2()

	return Rect2(usable_position, usable_size)


func get_ball_spawn_height(ball: MarbleBall) -> float:
	if ball == null or not is_instance_valid(ball):
		return board_surface_y
	return board_surface_y + ball.marble_radius + 0.04


func restart_game() -> void:
	m_winners.clear()
	m_loser = null
	m_active_lock_ball = null

	_set_current_ball(null)
	_set_turn_active(false)
	_set_rest_progress(0.0)
	_set_status(GameStatus.WAITING_FOR_REST)

	_apply_mode()
	if m_mode != null:
		m_mode.on_restart(self)


func declare_winner(ball: MarbleBall) -> void:
	if ball == null or not is_instance_valid(ball) or m_winners.has(ball):
		return

	m_winners.append(ball)
	var place: int = m_winners.size()
	print("[MarbleGame] WINNER ", _ordinal(place), " -> ", ball.name)
	ball_won.emit(ball)


func declare_loser(ball: MarbleBall) -> void:
	if ball == null or not is_instance_valid(ball) or m_loser == ball:
		return

	m_loser = ball
	var total: int = m_balls.size()
	print("[MarbleGame] LOSER ", _ordinal(total), " -> ", ball.name)
	ball_lost.emit(ball)


func set_active_lock_ball(ball: MarbleBall) -> void:
	if m_active_lock_ball == ball:
		return
	m_active_lock_ball = ball
	print("[MarbleGame] ActiveLockBall -> ", m_active_lock_ball.name if m_active_lock_ball != null else "<none>")


func end_game() -> void:
	if m_status == GameStatus.GAME_OVER:
		return

	_set_current_ball(null)
	_set_turn_active(false)
	_set_rest_progress(0.0)
	_set_status(GameStatus.GAME_OVER)
	print("[MarbleGame] GAME OVER")
	game_over.emit()


func _assign_game_to_balls() -> void:
	for ball: MarbleBall in m_balls:
		if not is_instance_valid(ball):
			continue

		ball.set_game(self)
		if not ball.kicked.is_connected(_on_ball_kicked):
			ball.kicked.connect(_on_ball_kicked)
		if not ball.body_hit.is_connected(_on_ball_body_hit):
			ball.body_hit.connect(_on_ball_body_hit)
		if not ball.hole_state_changed.is_connected(_on_ball_hole_state_changed):
			ball.hole_state_changed.connect(_on_ball_hole_state_changed)


func _apply_mode() -> void:
	if Engine.is_editor_hint():
		return

	if m_mode != null:
		m_mode.on_exit_mode()

	m_mode = game_mode.duplicate(true) as MarbleGameMode if is_instance_valid(game_mode) else null
	game_mode_changed.emit(m_mode)

	if m_mode != null:
		m_mode.on_apply_mode(self)


func _physics_process(delta: float) -> void:
	if not Engine.is_editor_hint() and m_mode != null:
		m_mode.on_physics_process(self, delta)


func _on_ball_kicked(ball: MarbleBall) -> void:
	if m_mode != null:
		m_mode.on_ball_kicked(self, ball)


func _on_ball_body_hit(ball: MarbleBall, other_body: Node) -> void:
	if m_mode != null:
		m_mode.on_ball_body_entered(self, ball, other_body)


func _on_ball_hole_state_changed(ball: MarbleBall, in_hole: bool) -> void:
	if m_mode != null:
		m_mode.on_ball_hole_state_changed(self, ball, in_hole)


func _set_status(status: GameStatus) -> void:
	if m_status == status:
		return
	m_status = status
	status_changed.emit(m_status)
	print("[MarbleGame] Status -> ", _status_name(m_status))


func _set_turn_active(is_active: bool) -> void:
	if m_turn_active == is_active:
		return
	m_turn_active = is_active
	turn_active_changed.emit(m_turn_active)


func _set_rest_progress(progress: float) -> void:
	progress = clampf(progress, 0.0, 1.0)
	if is_equal_approx(m_rest_progress, progress):
		return
	m_rest_progress = progress
	rest_progress_changed.emit(m_rest_progress)


func _set_current_ball(ball: MarbleBall) -> void:
	if m_current_ball == ball:
		return
	m_current_ball = ball
	current_ball_changed.emit(m_current_ball)
	print("[MarbleGame] CurrentBall -> ", m_current_ball.name if m_current_ball != null else "<none>")


func _status_name(status: GameStatus) -> String:
	match status:
		GameStatus.FREE_PLAY:
			return "FREE_PLAY"
		GameStatus.WAITING_FOR_REST:
			return "WAITING_FOR_REST"
		GameStatus.WAITING_FOR_KICK:
			return "WAITING_FOR_KICK"
		GameStatus.GAME_OVER:
			return "GAME_OVER"
	return "UNKNOWN"


func _ordinal(number: int) -> String:
	var mod100: int = number % 100
	if mod100 >= 11 and mod100 <= 13:
		return str(number) + "th"
	match number % 10:
		1:
			return str(number) + "st"
		2:
			return str(number) + "nd"
		3:
			return str(number) + "rd"
		_:
			return str(number) + "th"
