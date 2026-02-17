# MarbleGame.gd
@tool
class_name MarbleGame
extends Node2D

enum GameStatus { FREE_PLAY, WAITING_FOR_REST, WAITING_FOR_KICK, GAME_OVER }

@export var game_mode: MarbleGameMode:
	set(v):
		game_mode = v
		_apply_mode()

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

@onready var m_hole: MarbleHole = $hole

var m_mode: MarbleGameMode = null


func _ready() -> void:
	if not Engine.is_editor_hint():
		_auto_discover_balls()

	_assign_game_to_balls()

	if not Engine.is_editor_hint():
		restart_game()


func _auto_discover_balls() -> void:
	m_balls.clear()

	var found: Array = CommonUtils.find_all_children_of_type(self, MarbleBall)
	for n in found:
		var b: MarbleBall = n
		if b != null:
			m_balls.append(b)

	print("[MarbleGame] Auto found balls: ", m_balls.size())


func get_balls() -> Array[MarbleBall]:
	return m_balls


func get_hole() -> MarbleHole:
	return m_hole


func restart_game() -> void:
	m_winners.clear()
	m_loser = null
	m_active_lock_ball = null

	for b in m_balls:
		if is_instance_valid(b):
			b.set_in_hole(false)
			# IMPORTANT: do not disable balls here. Modes decide controller activation.

	_set_current_ball(null)
	_set_turn_active(false)
	_set_rest_progress(0.0)
	_set_status(GameStatus.WAITING_FOR_REST)

	_apply_mode()

	# Throw balls on restart (mode can implement or ignore)
	if m_mode != null:
		if m_mode.has_method("on_throw_initial_balls"):
			m_mode.call("on_throw_initial_balls", self)
		m_mode.on_restart(self)


func declare_winner(ball: MarbleBall) -> void:
	if ball == null or not is_instance_valid(ball):
		return
	if m_winners.has(ball):
		return

	m_winners.append(ball)
	var place := m_winners.size()
	print("[MarbleGame] WINNER ", _ordinal(place), " -> ", ball.name)
	ball_won.emit(ball)


func declare_loser(ball: MarbleBall) -> void:
	if ball == null or not is_instance_valid(ball):
		return
	if m_loser == ball:
		return

	m_loser = ball
	var total := m_balls.size()
	print("[MarbleGame] LOSER ", _ordinal(total), " -> ", ball.name)
	ball_lost.emit(ball)


func set_active_lock_ball(ball: MarbleBall) -> void:
	# TurnMode may still use this. FreeMode should ignore it.
	if m_active_lock_ball == ball:
		return
	m_active_lock_ball = ball
	if m_active_lock_ball != null:
		print("[MarbleGame] ActiveLockBall -> ", m_active_lock_ball.name)
	else:
		print("[MarbleGame] ActiveLockBall -> <none>")


func end_game() -> void:
	if m_status == GameStatus.GAME_OVER:
		return

	# IMPORTANT: do not disable balls here either. If you want that behavior,
	# do it in the mode before calling end_game().
	_set_current_ball(null)
	_set_turn_active(false)
	_set_rest_progress(0.0)
	_set_status(GameStatus.GAME_OVER)

	print("[MarbleGame] GAME OVER")
	game_over.emit()


func _assign_game_to_balls() -> void:
	for b in m_balls:
		if not is_instance_valid(b):
			continue

		b.set_game(self)

		# Forward ball events to active mode.
		if not b.kicked.is_connected(_on_ball_kicked):
			b.kicked.connect(_on_ball_kicked)
		if not b.body_hit.is_connected(_on_ball_body_hit):
			b.body_hit.connect(_on_ball_body_hit)
		if not b.hole_state_changed.is_connected(_on_ball_hole_state_changed):
			b.hole_state_changed.connect(_on_ball_hole_state_changed)


func _apply_mode() -> void:
	if Engine.is_editor_hint():
		return

	if m_mode != null:
		m_mode.on_exit_mode()

	if is_instance_valid(game_mode):
		m_mode = game_mode.duplicate(true) as MarbleGameMode
	else:
		m_mode = null

	game_mode_changed.emit(m_mode)

	if m_mode != null:
		m_mode.on_apply_mode(self)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if m_status == GameStatus.GAME_OVER:
		return

	if m_mode != null:
		m_mode.on_physics_process(self, delta)


# ------------------------------------------------
# Ball event forwarders (NO global win/lose/end logic here)
# ------------------------------------------------
func _on_ball_kicked(ball: MarbleBall) -> void:
	if m_mode != null:
		m_mode.on_ball_kicked(self, ball)

func _on_ball_body_hit(ball: MarbleBall, other_body: Node) -> void:
	if m_mode != null:
		m_mode.on_ball_body_entered(self, ball, other_body)

func _on_ball_hole_state_changed(ball: MarbleBall, in_hole: bool) -> void:
	# IMPORTANT: never auto-end or auto-restart here.
	if m_mode != null:
		m_mode.on_ball_hole_state_changed(self, ball, in_hole)


# -----------------------
# UI/state helpers
# -----------------------
func _set_status(s: GameStatus) -> void:
	if m_status == s:
		return
	m_status = s
	status_changed.emit(m_status)
	print("[MarbleGame] Status -> ", _status_name(m_status))

func _set_turn_active(is_active: bool) -> void:
	if m_turn_active == is_active:
		return
	m_turn_active = is_active
	turn_active_changed.emit(m_turn_active)
	print("[MarbleGame] TurnActive -> ", m_turn_active)

func _set_rest_progress(p: float) -> void:
	p = clamp(p, 0.0, 1.0)
	if is_equal_approx(m_rest_progress, p):
		return
	m_rest_progress = p
	rest_progress_changed.emit(m_rest_progress)

func _set_current_ball(ball: MarbleBall) -> void:
	if m_current_ball == ball:
		return
	m_current_ball = ball
	current_ball_changed.emit(m_current_ball)
	if m_current_ball != null:
		print("[MarbleGame] CurrentBall -> ", m_current_ball.name)
	else:
		print("[MarbleGame] CurrentBall -> <none>")

func _status_name(s: GameStatus) -> String:
	match s:
		GameStatus.FREE_PLAY: return "FREE_PLAY"
		GameStatus.WAITING_FOR_REST: return "WAITING_FOR_REST"
		GameStatus.WAITING_FOR_KICK: return "WAITING_FOR_KICK"
		GameStatus.GAME_OVER: return "GAME_OVER"
	return "UNKNOWN"

func _ordinal(n: int) -> String:
	var mod100 := n % 100
	if mod100 >= 11 and mod100 <= 13:
		return str(n) + "th"
	match n % 10:
		1: return str(n) + "st"
		2: return str(n) + "nd"
		3: return str(n) + "rd"
		_: return str(n) + "th"
