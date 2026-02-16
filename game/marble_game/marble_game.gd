# MarbleGame.gd
@tool
class_name MarbleGame
extends Node2D

enum GameMode { FREE, TURN }
enum GameStatus { FREE_PLAY, WAITING_FOR_REST, WAITING_FOR_KICK, GAME_OVER }

## Selected game mode (FREE or TURN).
@export var game_mode: GameMode = GameMode.TURN:
	set(v):
		game_mode = v
		_apply_mode()

## Balls in this game (multi-ball). Assign in editor.
## If empty at runtime, the game will auto-pick up MarbleBall children.
@export var m_balls: Array[MarbleBall] = []

## Index of the ball that gets the first turn in TURN mode.
@export var starting_ball_index: int = 0

## If true, enables "extra chance on hit" rule.
@export var enable_extra_chance_on_hit: bool = true

## Prints extra-chance / debug events (TurnMode uses this too).
@export var print_extra_chance_events: bool = true

## Seconds required to be "settled" before a kick window opens.
@export var rest_settle_time: float = 0.35

## Linear speed threshold considered "stopped enough".
@export var rest_linear_speed_threshold: float = 12.0

## Angular speed threshold considered "stopped enough".
@export var rest_angular_speed_threshold: float = 2.5

## Hole pull force scale (delegated to MarbleHole).
@export var hole_pull_strength: float = 0.5:
	set(v):
		hole_pull_strength = v
		_apply_hole_pull_strength()

## Hole path (optional). If unset, $hole is used.
@export var hole_path: NodePath

# -----------------------
# UI signals
# -----------------------
signal game_mode_changed(new_mode: GameMode)
signal status_changed(new_status: GameStatus)
signal turn_active_changed(is_active: bool)
signal current_ball_changed(ball: MarbleBall)
signal rest_progress_changed(progress_0_1: float)

## Emitted when a ball becomes a winner (locked in hole permanently).
signal ball_won(ball: MarbleBall)

## Emitted when a ball becomes the loser (last remaining and runs out of chances).
signal ball_lost(ball: MarbleBall)

## Emitted once when the game ends.
signal game_over

# -----------------------
# Runtime UI properties
# -----------------------
## Current winners list (read-only for UI).
var m_winners: Array[MarbleBall] = []

## The losing ball (null if none).
var m_loser: MarbleBall = null

## Active "challenge lock" ball: a ball currently being challenged while in the hole.
var m_active_lock_ball: MarbleBall = null


var m_mode: MarbleGameMode = null
var m_status: GameStatus = GameStatus.WAITING_FOR_REST
var m_turn_active: bool = false
var m_rest_progress: float = 0.0
var m_current_ball: MarbleBall = null

# Prefer explicit $hole (you said no need to discover hole)
@onready var m_hole: MarbleHole = ($hole as MarbleHole) if has_node("hole") else null


func _ready() -> void:
	# Hole fallback: use hole_path only if $hole doesn't exist / isn't set.
	if m_hole == null and hole_path != NodePath():
		m_hole = get_node_or_null(hole_path) as MarbleHole

	_apply_hole_pull_strength()

	# Backward compatible: if editor didn't assign balls, auto pickup at runtime.
	if not Engine.is_editor_hint():
		if m_balls.is_empty():
			var found: Array = CommonUtils.find_all_children_of_type(self, MarbleBall)
			for n in found:
				var b: MarbleBall = n
				if b != null:
					m_balls.append(b)

	_assign_game_to_balls()
	_connect_ball_signals()

	if not Engine.is_editor_hint():
		restart_game()


func _apply_hole_pull_strength() -> void:
	if is_instance_valid(m_hole):
		m_hole.pull_strength = hole_pull_strength


func _ordinal(n: int) -> String:
	var mod100 := n % 100
	if mod100 >= 11 and mod100 <= 13:
		return str(n) + "th"
	match n % 10:
		1: return str(n) + "st"
		2: return str(n) + "nd"
		3: return str(n) + "rd"
		_: return str(n) + "th"


## Returns the list of balls for modes/controllers.
func get_balls() -> Array[MarbleBall]:
	return m_balls


func restart_game() -> void:
	m_winners.clear()
	m_loser = null
	m_active_lock_ball = null

	for b in m_balls:
		if is_instance_valid(b):
			b.set_in_hole(false)
			b.set_controller_active(false)

	_set_current_ball(null)
	_set_turn_active(false)
	_set_rest_progress(0.0)
	_set_status(GameStatus.WAITING_FOR_REST)

	_apply_mode()
	if m_mode != null:
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
	if total > 0:
		print("[MarbleGame] LOSER ", _ordinal(total), " -> ", ball.name)
	else:
		print("[MarbleGame] LOSER -> ", ball.name)

	ball_lost.emit(ball)


func set_active_lock_ball(ball: MarbleBall) -> void:
	if m_active_lock_ball == ball:
		return
	m_active_lock_ball = ball
	if m_active_lock_ball != null:
		print("[MarbleGame] ActiveLockBall -> ", m_active_lock_ball.name)
	else:
		print("[MarbleGame] ActiveLockBall -> <none>")


func _print_leaderboard() -> void:
	var total := m_balls.size()
	print("[MarbleGame] Leaderboard:")
	for i in m_winners.size():
		var b := m_winners[i]
		print("  ", _ordinal(i + 1), ": ", b.name if is_instance_valid(b) else "<invalid>")
	if is_instance_valid(m_loser):
		print("  ", _ordinal(total), ": ", m_loser.name)
	else:
		if m_winners.size() < total:
			for b in m_balls:
				if not is_instance_valid(b):
					continue
				if m_winners.has(b):
					continue
				print("  ", "<unranked>: ", b.name)


func end_game() -> void:
	if m_status == GameStatus.GAME_OVER:
		return

	for b in m_balls:
		if is_instance_valid(b):
			b.set_controller_active(false)

	_set_current_ball(null)
	_set_turn_active(false)
	_set_rest_progress(0.0)
	_set_status(GameStatus.GAME_OVER)

	print("[MarbleGame] GAME OVER")
	_print_leaderboard()
	game_over.emit()


func _assign_game_to_balls() -> void:
	for b in m_balls:
		if is_instance_valid(b):
			b.set_game(self)


func _connect_ball_signals() -> void:
	for b in m_balls:
		if not is_instance_valid(b):
			continue

		if not b.kicked.is_connected(_on_ball_kicked):
			b.kicked.connect(_on_ball_kicked)
		if not b.body_hit.is_connected(_on_ball_body_hit):
			b.body_hit.connect(_on_ball_body_hit)
		if not b.hole_state_changed.is_connected(_on_ball_hole_state_changed):
			b.hole_state_changed.connect(_on_ball_hole_state_changed)

	# ❌ No hole signal connections needed anymore.
	# Hole updates ball state; ball emits hole_state_changed; we already listen to that.


func _apply_mode() -> void:
	if Engine.is_editor_hint():
		return

	m_mode = MarbleGameFreeMode.new() if game_mode == GameMode.FREE else MarbleGameTurnMode.new()
	game_mode_changed.emit(game_mode)

	if m_mode != null:
		m_mode.on_apply_mode(self)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if m_status == GameStatus.GAME_OVER:
		return
	if m_mode != null:
		m_mode.on_physics_process(self, delta)


# -----------------------
# UI/state helpers (with prints)
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
	print("[MarbleGame] CurrentBall -> ", (m_current_ball.name if m_current_ball != null else "<none>"))

func _status_name(s: GameStatus) -> String:
	match s:
		GameStatus.FREE_PLAY: return "FREE_PLAY"
		GameStatus.WAITING_FOR_REST: return "WAITING_FOR_REST"
		GameStatus.WAITING_FOR_KICK: return "WAITING_FOR_KICK"
		GameStatus.GAME_OVER: return "GAME_OVER"
	return "UNKNOWN"


# -----------------------
# Forward events to mode
# -----------------------
func _on_ball_kicked(ball: MarbleBall) -> void:
	if m_mode != null:
		m_mode.on_ball_kicked(self, ball)

func _on_ball_body_hit(ball: MarbleBall, other: Node) -> void:
	if m_mode != null:
		m_mode.on_ball_body_entered(self, ball, other)

func _on_ball_hole_state_changed(ball: MarbleBall, in_hole: bool) -> void:
	if m_mode != null:
		m_mode.on_ball_hole_state_changed(self, ball, in_hole)
