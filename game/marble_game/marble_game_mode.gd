# MarbleGameMode.gd
class_name MarbleGameMode
extends Resource

# --------------------------------------------------------------------
# Rest / settle configuration (mode-owned, editable per mode resource)
# --------------------------------------------------------------------

## Seconds required to be "settled" before a kick window opens.
@export var rest_settle_time: float = 0.35

## Linear speed threshold considered "stopped enough".
@export var rest_linear_speed_threshold: float = 12.0

## Angular speed threshold considered "stopped enough".
@export var rest_angular_speed_threshold: float = 2.5

var m_game: MarbleGame = null
var m_connected: bool = false
var m_rng := RandomNumberGenerator.new()

func on_apply_mode(game: MarbleGame) -> void:
	m_game = game
	_connect_ball_signals()

func on_restart(game: MarbleGame) -> void:
	m_game = game
	_disconnect_ball_signals()
	_connect_ball_signals()
	on_throw_initial_balls(game)

func on_exit_mode() -> void:
	_disconnect_ball_signals()
	m_game = null

func on_physics_process(_game: MarbleGame, _delta: float) -> void:
	pass

func on_ball_kicked(_game: MarbleGame, _ball: MarbleBall) -> void:
	pass

func on_ball_body_entered(_game: MarbleGame, _ball: MarbleBall, _other: Node) -> void:
	pass

func on_ball_hole_state_changed(_game: MarbleGame, _ball: MarbleBall, _in_hole: bool) -> void:
	pass

func on_throw_initial_balls(game: MarbleGame) -> void:
	for b: MarbleBall in game.get_balls():
		if not is_instance_valid(b):
			continue
		if is_instance_valid(b.controller):
			b.controller.spawn_and_throw_away_from_hole(m_rng)
		else:
			b.linear_velocity = Vector2.ZERO
			b.angular_velocity = 0.0
			b.sleeping = false

	print("[GameMode] throw initial balls")

func _ready() -> void:
	m_rng.randomize()

# ----------------------------------------------------------
# Shared rest utility for modes
# ----------------------------------------------------------
func _all_balls_are_slow(game: MarbleGame) -> bool:
	for b: MarbleBall in game.get_balls():
		if not is_instance_valid(b):
			continue
		if b.linear_velocity.length() > rest_linear_speed_threshold:
			return false
		if absf(b.angular_velocity) > rest_angular_speed_threshold:
			return false
	return true


# ----------------------------------------------------------
# Internal: connect/disconnect
# ----------------------------------------------------------
func _connect_ball_signals() -> void:
	if m_connected:
		return
	if not is_instance_valid(m_game):
		return

	for b: MarbleBall in m_game.get_balls():
		if not is_instance_valid(b):
			continue
		if not b.kicked.is_connected(_on_ball_kicked):
			b.kicked.connect(_on_ball_kicked)
		if not b.body_hit.is_connected(_on_ball_body_hit):
			b.body_hit.connect(_on_ball_body_hit)
		if not b.hole_state_changed.is_connected(_on_ball_hole_state_changed):
			b.hole_state_changed.connect(_on_ball_hole_state_changed)

	m_connected = true

func _disconnect_ball_signals() -> void:
	if not m_connected:
		return
	if not is_instance_valid(m_game):
		m_connected = false
		return

	for b: MarbleBall in m_game.get_balls():
		if not is_instance_valid(b):
			continue
		if b.kicked.is_connected(_on_ball_kicked):
			b.kicked.disconnect(_on_ball_kicked)
		if b.body_hit.is_connected(_on_ball_body_hit):
			b.body_hit.disconnect(_on_ball_body_hit)
		if b.hole_state_changed.is_connected(_on_ball_hole_state_changed):
			b.hole_state_changed.disconnect(_on_ball_hole_state_changed)

	m_connected = false


func _on_ball_kicked(ball: MarbleBall) -> void:
	if is_instance_valid(m_game):
		on_ball_kicked(m_game, ball)

func _on_ball_body_hit(ball: MarbleBall, other: Node) -> void:
	if is_instance_valid(m_game):
		on_ball_body_entered(m_game, ball, other)

func _on_ball_hole_state_changed(ball: MarbleBall, in_hole: bool) -> void:
	if is_instance_valid(m_game):
		on_ball_hole_state_changed(m_game, ball, in_hole)
