# MarbleBallController.gd
class_name MarbleBallController
extends Resource

## The ball currently controlled by this controller (assigned by MarbleBall).
var m_ball: MarbleBall = null

## The game instance owning the ball (assigned by MarbleGame -> MarbleBall).
var m_game: MarbleGame = null

## Whether the game/mode currently allows this controller to act.
var m_allowed: bool = false

## Called by MarbleBall when the controller is assigned / re-assigned.
func set_ball(ball: MarbleBall) -> void:
	m_ball = ball

## Called by MarbleBall when MarbleGame injects the game instance.
func set_game(game: MarbleGame) -> void:
	m_game = game

## Called by MarbleBall (via game/mode) to enable/disable this controller.
func set_allowed(is_allowed: bool) -> void:
	if m_allowed == is_allowed:
		return
	m_allowed = is_allowed
	_on_allowed_changed(m_allowed)

## Optional override in subclasses.
func _on_allowed_changed(_is_allowed: bool) -> void:
	pass

## Called by MarbleBall from _unhandled_input.
func handle_input(_event: InputEvent) -> void:
	pass

## Called by MarbleBall from _physics_process.
func physics_tick(_delta: float) -> void:
	pass
	
func spawn_and_throw_away_from_hole(rng: RandomNumberGenerator) -> void:
	if m_ball == null or not is_instance_valid(m_ball):
		return
	if m_game == null or not is_instance_valid(m_game):
		return

	var hole: MarbleHole = m_game.get_hole()
	if hole == null or not is_instance_valid(hole):
		return

	# -----------------------------
	# Reset physics safely
	# -----------------------------
	m_ball.sleeping = false
	m_ball.freeze = false
	m_ball.linear_velocity = Vector2.ZERO
	m_ball.angular_velocity = 0.0

	# Reset rolling state (prevents shader jumps after teleport)
	# These fields exist in your MarbleBall.gd script.
	m_ball.m_last_valid_roll_axis = Vector2.UP
	m_ball.m_roll_q = Quaternion()

	# -----------------------------
	# Pick a spawn position OUTSIDE the hole area
	# -----------------------------
	var hole_pos: Vector2 = hole.global_position

	var r := float(m_ball.marble_radius_px)
	var min_dist := r * 10.0
	var max_dist := r * 30.0

	var angle := rng.randf_range(0.0, TAU)
	var dist := rng.randf_range(min_dist, max_dist)

	var spawn_pos := hole_pos + Vector2.RIGHT.rotated(angle) * dist
	CommonUtils.safe_teleport_body(m_ball, spawn_pos)
	m_ball.m_last_pos = spawn_pos

	# Important for your roll accumulation method (uses position delta)
	m_ball.m_last_pos = m_ball.global_position

	# -----------------------------
	# Throw direction AWAY from hole (+ small spread)
	# -----------------------------
	var dir := (spawn_pos - hole_pos).normalized()
	dir = dir.rotated(rng.randf_range(-0.35, 0.35)).normalized()

	var throw_speed := rng.randf_range(100.0, 500.0)
	m_ball.linear_velocity = dir * throw_speed
	print("spawn_and_throw_away_from_hole:", throw_speed)
	m_ball.angular_velocity = 0.0
