# MarbleGameFreeMode.gd
class_name MarbleGameFreeMode
extends MarbleGameMode

## FREE mode: player controllers are allowed; AI controllers never kick.

func on_restart(game: MarbleGame) -> void:
	for b: MarbleBall in game.get_balls():
		if not is_instance_valid(b):
			continue
		# Only allow player-controlled balls in free mode
		b.set_controller_active(b.is_player_controlled and not b.m_in_hole)

	game._set_status(MarbleGame.GameStatus.FREE_PLAY)
	game._set_turn_active(true)
	game._set_rest_progress(0.0)

func on_apply_mode(game: MarbleGame) -> void:
	on_restart(game)

func on_physics_process(game: MarbleGame, _delta: float) -> void:
	# Keep controller activity consistent if balls enter/exit hole.
	for b: MarbleBall in game.get_balls():
		if not is_instance_valid(b):
			continue
		b.set_controller_active(b.is_player_controlled and not b.m_in_hole)
