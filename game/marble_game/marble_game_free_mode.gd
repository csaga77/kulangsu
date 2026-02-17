# MarbleGameFreeMode.gd
class_name MarbleGameFreeMode
extends MarbleGameMode

@export var print_debug: bool = false
@export var restart_delay: float = 1.2

var m_rest_timer: float = 0.0
var m_started: bool = false
var m_restart_timer: float = 0.0


func on_restart(game: MarbleGame) -> void:
	super.on_restart(game)

	m_rest_timer = 0.0
	m_started = false
	m_restart_timer = 0.0

	# Free mode: all balls active except balls already in hole
	for b: MarbleBall in game.get_balls():
		if not is_instance_valid(b):
			continue

		if not b.hole_state_changed.is_connected(_on_ball_hole_state_changed):
			b.hole_state_changed.connect(_on_ball_hole_state_changed)

		b.set_controller_active(not b.m_in_hole)

	game._set_current_ball(null)
	game._set_turn_active(false)
	game._set_rest_progress(0.0)
	game._set_status(MarbleGame.GameStatus.WAITING_FOR_REST)


func on_physics_process(game: MarbleGame, delta: float) -> void:
	# ---------------------------------------------------
	# GAME OVER → restart automatically (after delay)
	# ---------------------------------------------------
	if game.m_status == MarbleGame.GameStatus.GAME_OVER:
		m_restart_timer += delta
		if m_restart_timer >= restart_delay:
			if print_debug:
				print("[FreeMode] Restarting game after GAME_OVER")
			m_restart_timer = 0.0
			game.restart_game()
		return

	# Keep “in hole” balls not kickable
	_enforce_in_hole_not_kickable(game)

	# Always in rest-wait state in FreeMode
	game._set_status(MarbleGame.GameStatus.WAITING_FOR_REST)
	game._set_turn_active(false)

	# Base rest settle logic
	if _all_balls_are_slow(game):
		m_rest_timer += delta
	else:
		m_rest_timer = 0.0

	game._set_rest_progress(m_rest_timer / max(rest_settle_time, 0.001))
	if m_rest_timer < rest_settle_time:
		return

	# Rest settled
	m_rest_timer = 0.0
	game._set_rest_progress(0.0)

	if not m_started:
		m_started = true
		if print_debug:
			print("[FreeMode] Started after settle")

	# ---------------------------------------------------
	# IMPORTANT CHANGE:
	# Only declare GAME OVER when:
	#   1) all balls are in hole
	#   2) and we are at a rest-settle moment (we are here)
	# ---------------------------------------------------
	if _all_balls_in_hole(game):
		if print_debug:
			print("[FreeMode] All balls settled in hole -> end_game")
		game.end_game()
		return


func _on_ball_hole_state_changed(ball: MarbleBall, in_hole: bool) -> void:
	if not is_instance_valid(ball):
		return
	# Free mode rule: balls inside hole cannot be kicked
	ball.set_controller_active(not in_hole)


func _enforce_in_hole_not_kickable(game: MarbleGame) -> void:
	for b: MarbleBall in game.get_balls():
		if not is_instance_valid(b):
			continue
		if b.m_in_hole:
			b.set_controller_active(false)


func _all_balls_in_hole(game: MarbleGame) -> bool:
	for b: MarbleBall in game.get_balls():
		if not is_instance_valid(b):
			continue
		if not b.m_in_hole:
			return false
	return true
