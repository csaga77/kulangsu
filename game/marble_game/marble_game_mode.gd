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
var m_rng := RandomNumberGenerator.new()

func on_apply_mode(game: MarbleGame) -> void:
	m_game = game
	m_rng.randomize()

func on_restart(game: MarbleGame) -> void:
	m_game = game
	m_rng.randomize()
	on_throw_initial_balls(game)

func on_exit_mode() -> void:
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
			# Defer teleports so restart logic never moves bodies mid-physics step.
			b.controller.call_deferred("spawn_and_throw_away_from_hole", m_rng)
		else:
			b.linear_velocity = Vector2.ZERO
			b.angular_velocity = 0.0
			b.sleeping = false

	print("[GameMode] throw initial balls")

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
