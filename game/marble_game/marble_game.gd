# MarbleGame.gd
@tool
class_name MarbleGame
extends Node2D

enum GameMode { FREE, TURN }
enum GameStatus { FREE_PLAY, WAITING_FOR_REST, WAITING_FOR_KICK }

## Selected game mode (FREE or TURN).
@export var game_mode: GameMode = GameMode.TURN:
	set(v):
		game_mode = v
		_apply_mode()

## Balls in this game (multi-ball). Assign in editor.
@export var balls: Array[MarbleBall] = []

## Index of the ball that gets the first turn in TURN mode.
@export var starting_ball_index: int = 0

## If true, enables "extra chance on hit" rule.
@export var enable_extra_chance_on_hit: bool = true

## Prints extra-chance / hole-lock events.
@export var print_extra_chance_events: bool = true

## Seconds required to be "settled" before a kick window opens.
@export var rest_settle_time: float = 0.35

## Linear speed threshold considered "stopped enough".
@export var rest_linear_speed_threshold: float = 12.0

## Angular speed threshold considered "stopped enough".
@export var rest_angular_speed_threshold: float = 2.5

## Hole pull force scale (optional).
@export var hole_pull_strength: float = 0.5

## Hole area (used for hole pull + enter/exit tracking).
@export var hole_path: NodePath

## Optional damping area path.
@export var damping_area_path: NodePath

## Damping inside damping area.
@export var linear_damp_in_zone: float = 3.0
@export var angular_damp_in_zone: float = 3.0

signal game_mode_changed(new_mode: GameMode)
signal status_changed(new_status: GameStatus)
signal turn_active_changed(is_active: bool)
signal current_ball_changed(ball: MarbleBall)
signal rest_progress_changed(progress_0_1: float)

var m_mode: MarbleGameMode = null
var m_status: GameStatus = GameStatus.WAITING_FOR_REST
var m_turn_active: bool = false
var m_rest_progress: float = 0.0
var m_current_ball: MarbleBall = null

var m_balls_in_hole: Array[MarbleBall] = []

@onready var m_hole: Area2D = get_node_or_null(hole_path) as Area2D
@onready var m_damping_area: Area2D = get_node_or_null(damping_area_path) as Area2D


func _ready() -> void:
	_assign_game_to_balls()
	_connect_ball_signals()
	_apply_mode()


## Returns the list of balls for modes/controllers.
func get_balls() -> Array[MarbleBall]:
	return balls


func restart_game() -> void:
	m_balls_in_hole.clear()
	for b in balls:
		if is_instance_valid(b):
			b.set_in_hole(false)

	_apply_mode()
	if m_mode != null:
		m_mode.on_restart(self)


func _assign_game_to_balls() -> void:
	for b in balls:
		if not is_instance_valid(b):
			continue
		b.set_game(self)


func _connect_ball_signals() -> void:
	for b in balls:
		if not is_instance_valid(b):
			continue

		if not b.kicked.is_connected(_on_ball_kicked):
			b.kicked.connect(_on_ball_kicked)

		if not b.body_hit.is_connected(_on_ball_body_hit):
			b.body_hit.connect(_on_ball_body_hit)

		if not b.hole_state_changed.is_connected(_on_ball_hole_state_changed):
			b.hole_state_changed.connect(_on_ball_hole_state_changed)

	# Hole enter/exit
	if is_instance_valid(m_hole):
		if not m_hole.body_entered.is_connected(_on_hole_body_entered):
			m_hole.body_entered.connect(_on_hole_body_entered)
		if not m_hole.body_exited.is_connected(_on_hole_body_exited):
			m_hole.body_exited.connect(_on_hole_body_exited)

	# Damping enter/exit (optional)
	if is_instance_valid(m_damping_area):
		if not m_damping_area.body_entered.is_connected(_on_damping_area_body_entered):
			m_damping_area.body_entered.connect(_on_damping_area_body_entered)
		if not m_damping_area.body_exited.is_connected(_on_damping_area_body_exited):
			m_damping_area.body_exited.connect(_on_damping_area_body_exited)


func _apply_mode() -> void:
	if Engine.is_editor_hint():
		return

	if game_mode == GameMode.FREE:
		m_mode = MarbleGameFreeMode.new()
	else:
		m_mode = MarbleGameTurnMode.new()

	game_mode_changed.emit(game_mode)

	if m_mode != null:
		m_mode.on_apply_mode(self)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	# Optional hole pull
	if is_instance_valid(m_hole) and hole_pull_strength > 0.0:
		for b in m_balls_in_hole:
			if not is_instance_valid(b):
				continue
			var vec := m_hole.global_position - b.global_position
			if vec.length() > 0.001:
				b.apply_central_force(vec.normalized() * vec.length_squared() * hole_pull_strength)

	if m_mode != null:
		m_mode.on_physics_process(self, delta)

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

func _on_hole_body_entered(body: Node2D) -> void:
	if body is MarbleBall:
		var b := body as MarbleBall
		if not m_balls_in_hole.has(b):
			m_balls_in_hole.append(b)
			b.set_meta("old_linear_damp", b.linear_damp)
			b.set_meta("old_angular_damp", b.angular_damp)
			b.linear_damp = linear_damp_in_zone
			b.angular_damp = angular_damp_in_zone
		b.set_in_hole(true)

func _on_hole_body_exited(body: Node2D) -> void:
	if body is MarbleBall:
		var b := body as MarbleBall
		if m_balls_in_hole.has(b):
			if b.has_meta("old_linear_damp"):
				b.linear_damp = float(b.get_meta("old_linear_damp"))
			if b.has_meta("old_angular_damp"):
				b.angular_damp = float(b.get_meta("old_angular_damp"))
			m_balls_in_hole.erase(b)
			
		b.set_in_hole(false)

# -----------------------
# Optional damping area
# -----------------------
func _on_damping_area_body_entered(body: Node2D) -> void:
	if body is RigidBody2D:
		var rb := body as RigidBody2D
		rb.set_meta("old_linear_damp", rb.linear_damp)
		rb.set_meta("old_angular_damp", rb.angular_damp)
		rb.linear_damp = linear_damp_in_zone
		rb.angular_damp = angular_damp_in_zone

func _on_damping_area_body_exited(body: Node2D) -> void:
	if body is RigidBody2D:
		var rb := body as RigidBody2D
		if rb.has_meta("old_linear_damp"):
			rb.linear_damp = float(rb.get_meta("old_linear_damp"))
		if rb.has_meta("old_angular_damp"):
			rb.angular_damp = float(rb.get_meta("old_angular_damp"))
