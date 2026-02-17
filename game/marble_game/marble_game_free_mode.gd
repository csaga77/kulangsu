# MarbleGameFreeMode.gd
class_name MarbleGameFreeMode
extends MarbleGameMode

@export var auto_restart_when_all_in_hole: bool = true
@export var restart_delay_sec: float = 0.6

var m_rest_timer: float = 0.0
var m_restart_timer: float = 0.0

func on_apply_mode(game: MarbleGame) -> void:
	super.on_apply_mode(game)


func on_restart(game: MarbleGame) -> void:
	super.on_restart(game)

	m_rest_timer = 0.0
	m_restart_timer = 0.0

	# Free mode: keep everyone controllable.
	for b: MarbleBall in game.get_balls():
		if is_instance_valid(b):
			b.set_controller_active(true)

	# Throw balls at restart (same as TurnMode path)
	on_throw_initial_balls(game)

	game._set_status(MarbleGame.GameStatus.FREE_PLAY)
	game._set_turn_active(false)
	game._set_rest_progress(0.0)
	game._set_current_ball(null)


func on_throw_initial_balls(game: MarbleGame) -> void:
	m_rng.randomize()

	for b: MarbleBall in game.get_balls():
		if not is_instance_valid(b):
			continue
		if is_instance_valid(b.controller) and b.controller.has_method("spawn_and_throw_away_from_hole"):
			b.controller.spawn_and_throw_away_from_hole(m_rng)
		else:
			# fallback
			b.linear_velocity = Vector2.ZERO
			b.angular_velocity = 0.0
			b.sleeping = false


func on_physics_process(game: MarbleGame, delta: float) -> void:
	if game.m_status == MarbleGame.GameStatus.GAME_OVER:
		return

	game._set_status(MarbleGame.GameStatus.FREE_PLAY)
	game._set_turn_active(false)

	# Rest settle progress (purely for UI)
	if _all_balls_are_slow(game):
		m_rest_timer += delta
	else:
		m_rest_timer = 0.0
	game._set_rest_progress(m_rest_timer / max(rest_settle_time, 0.001))

	# Auto-restart after all balls are in the hole AND settled
	if not auto_restart_when_all_in_hole:
		return

	if _all_balls_in_hole(game) and m_rest_timer >= rest_settle_time:
		m_restart_timer += delta
		if m_restart_timer >= restart_delay_sec:
			m_restart_timer = 0.0
			game.restart_game()
	else:
		m_restart_timer = 0.0


func _all_balls_in_hole(game: MarbleGame) -> bool:
	for b: MarbleBall in game.get_balls():
		if not is_instance_valid(b):
			continue
		if not b.m_in_hole:
			return false
	return true
