# MarbleGameFreeMode.gd
class_name MarbleGameFreeMode
extends MarbleGameMode

## FREE mode:
## - All controllers allowed unless the ball is in the hole.

func on_restart(game: MarbleGame) -> void:
	_enable_all(game)

	game._set_status(MarbleGame.GameStatus.FREE_PLAY)
	game._set_turn_active(true)
	game._set_rest_progress(0.0)
	game._set_current_ball(null)

func on_apply_mode(game: MarbleGame) -> void:
	on_restart(game)

func on_physics_process(game: MarbleGame, _delta: float) -> void:
	# Maintain controller activity if hole state changes.
	for b: MarbleBall in game.get_balls():
		if is_instance_valid(b):
			b.set_controller_active(not b.m_in_hole)

func _enable_all(game: MarbleGame) -> void:
	for b: MarbleBall in game.get_balls():
		if is_instance_valid(b):
			b.set_controller_active(not b.m_in_hole)
