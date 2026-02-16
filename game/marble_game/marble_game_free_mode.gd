# MarbleGameFreeMode.gd
class_name MarbleGameFreeMode
extends MarbleGameMode

## FREE mode:
## - Endless play (never ends game automatically).
## - All controllers are always allowed (no turns).
## - Re-throws balls on restart.

var m_rng := RandomNumberGenerator.new()

func on_apply_mode(game: MarbleGame) -> void:
	super.on_apply_mode(game)

	m_rng.randomize()
	_enable_all(game)

	game._set_status(MarbleGame.GameStatus.FREE_PLAY)
	game._set_turn_active(false)
	game._set_rest_progress(0.0)
	game._set_current_ball(null)

func on_restart(game: MarbleGame) -> void:
	super.on_restart(game)

	m_rng.randomize()
	_enable_all(game)

	game._set_status(MarbleGame.GameStatus.FREE_PLAY)
	game._set_turn_active(false)
	game._set_rest_progress(0.0)
	game._set_current_ball(null)

func on_exit_mode() -> void:
	if is_instance_valid(m_game):
		_disable_all(m_game)
	super.on_exit_mode()

func on_physics_process(game: MarbleGame, _delta: float) -> void:
	# Keep UI state stable in FREE play.
	if game.m_status != MarbleGame.GameStatus.FREE_PLAY:
		game._set_status(MarbleGame.GameStatus.FREE_PLAY)

	game._set_turn_active(false)
	game._set_rest_progress(0.0)
	game._set_current_ball(null)

func on_throw_initial_balls(game: MarbleGame) -> void:
	# Re-throw ALL balls every restart
	for b: MarbleBall in game.get_balls():
		if not is_instance_valid(b):
			continue
		if b.has_method("spawn_and_throw_away_from_hole"):
			b.call("spawn_and_throw_away_from_hole", m_rng)
		else:
			# fallback: at least wake and clear velocities
			b.linear_velocity = Vector2.ZERO
			b.angular_velocity = 0.0
			b.sleeping = false

# -----------------------
# Helpers
# -----------------------
func _enable_all(game: MarbleGame) -> void:
	for b: MarbleBall in game.get_balls():
		if is_instance_valid(b):
			b.set_controller_active(true)

func _disable_all(game: MarbleGame) -> void:
	for b: MarbleBall in game.get_balls():
		if is_instance_valid(b):
			b.set_controller_active(false)
