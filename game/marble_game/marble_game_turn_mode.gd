# MarbleGameTurnMode.gd
class_name MarbleGameTurnMode
extends MarbleGameMode

## TURN mode (MULTI-BALL) with hole-lock + extra chance rules:
##
## Turn:
## - Round-robin over all balls, skipping any ball that is in the hole.
##
## Hole-lock:
## - If any ball is in the hole, balls NOT in hole may have up to 3 "hole-lock chances".
## - A ball already in the hole never gets chances.
## - When a ball enters hole: its own stored chances reset to 0.
## - If a ball exits hole while other balls still in hole: that exiting ball gets 3 chances.
## - If no eligible ball has chances while hole-lock is active: pause until state changes.
##
## Extra chance on hit:
## - Awarded only after the ball's first kick of that turn.
## - Does NOT apply if the hitting ball is in the hole.

var m_waiting_for_kick: bool = false
var m_rest_timer: float = 0.0
var m_first_kick_pending: bool = true

# Current turn ball (the only active controller)
var m_current_ball: MarbleBall = null
var m_turn_index: int = -1

# "Fresh turn" tracking for extra chance
var m_turn_kicks_taken: int = 0
var m_extra_chance_awarded: bool = false
var m_extra_kick_consumed: bool = false

# Hole-lock bookkeeping
var m_locked_in_hole: Dictionary = {}        # MarbleBall -> bool
var m_chances_remaining: Dictionary = {}     # MarbleBall -> int

func on_restart(game: MarbleGame) -> void:
	_disable_all(game)

	m_waiting_for_kick = false
	m_rest_timer = 0.0
	m_first_kick_pending = true

	m_current_ball = null
	m_turn_index = -1

	_reset_fresh_turn_state()

	m_locked_in_hole.clear()
	m_chances_remaining.clear()
	for b: MarbleBall in game.get_balls():
		m_locked_in_hole[b] = false
		m_chances_remaining[b] = 0

	game._set_status(MarbleGame.GameStatus.WAITING_FOR_REST)
	game._set_turn_active(false)
	game._set_rest_progress(0.0)
	game._set_current_ball(null)

func on_apply_mode(game: MarbleGame) -> void:
	on_restart(game)

func on_physics_process(game: MarbleGame, delta: float) -> void:
	if m_waiting_for_kick:
		game._set_status(MarbleGame.GameStatus.WAITING_FOR_KICK)
		game._set_turn_active(true)
		game._set_rest_progress(0.0)
		return

	game._set_status(MarbleGame.GameStatus.WAITING_FOR_REST)
	game._set_turn_active(false)

	if _all_balls_are_slow(game):
		m_rest_timer += delta
	else:
		m_rest_timer = 0.0

	game._set_rest_progress(m_rest_timer / max(game.rest_settle_time, 0.001))
	if m_rest_timer < game.rest_settle_time:
		return

	m_rest_timer = 0.0
	game._set_rest_progress(0.0)

	# Hole-lock flow has priority
	if _is_any_hole_lock_active(game):
		_handle_hole_lock_turn_flow(game)
		return

	# First kick: pick starting index without swapping away
	if m_first_kick_pending:
		m_first_kick_pending = false
		m_current_ball = _pick_next_normal_ball(game, true)
		_reset_fresh_turn_state()
		_begin_kick_window(game, m_current_ball)
		return

	# Optional extra kick
	if _should_start_extra_kick(game):
		m_extra_kick_consumed = true
		_begin_kick_window(game, m_current_ball)
		return

	# Next normal turn
	m_current_ball = _pick_next_normal_ball(game, false)
	_reset_fresh_turn_state()
	_begin_kick_window(game, m_current_ball)

func on_ball_kicked(game: MarbleGame, ball: MarbleBall) -> void:
	if not m_waiting_for_kick:
		return
	if ball != m_current_ball:
		return

	m_turn_kicks_taken += 1

	# If hole-lock active, consume a chance from this ball
	if _is_any_hole_lock_active(game):
		var cur: int = int(m_chances_remaining.get(ball, 0))
		if cur > 0:
			cur -= 1
			m_chances_remaining[ball] = cur
			if game.print_extra_chance_events:
				print("[TurnMode] Hole-lock chance used. Ball=", ball.name, " remaining=", cur)

	# End kick window
	m_waiting_for_kick = false
	_disable_all(game)

	game._set_turn_active(false)
	game._set_status(MarbleGame.GameStatus.WAITING_FOR_REST)
	game._set_rest_progress(0.0)

func on_ball_body_entered(game: MarbleGame, self_ball: MarbleBall, other_body: Node) -> void:
	# Extra chance does NOT apply when the hitting ball is in the hole
	if self_ball.m_in_hole:
		return

	if not game.enable_extra_chance_on_hit:
		return
	if m_waiting_for_kick:
		return
	if self_ball != m_current_ball:
		return
	if m_turn_kicks_taken != 1:
		return
	if m_extra_chance_awarded:
		return
	if not (other_body is MarbleBall):
		return

	m_extra_chance_awarded = true
	if game.print_extra_chance_events:
		print("[TurnMode] Hit detected. ball=", self_ball.name,
			" kicks_taken=", m_turn_kicks_taken,
			" waiting=", m_waiting_for_kick,
			" in_hole=", self_ball.m_in_hole,
			" other=", other_body.name)

func on_ball_hole_state_changed(game: MarbleGame, ball: MarbleBall, in_hole: bool) -> void:
	if not m_locked_in_hole.has(ball):
		m_locked_in_hole[ball] = false
	if not m_chances_remaining.has(ball):
		m_chances_remaining[ball] = 0

	if in_hole:
		# entering hole resets its own stored chances
		m_chances_remaining[ball] = 0

		if not bool(m_locked_in_hole[ball]):
			m_locked_in_hole[ball] = true
			ball.set_controller_active(false)

			# grant chances to other balls not in hole (only if they currently have 0)
			for other: MarbleBall in game.get_balls():
				if other == ball:
					continue
				if other.m_in_hole:
					continue
				if int(m_chances_remaining.get(other, 0)) <= 0:
					m_chances_remaining[other] = 3

			if game.print_extra_chance_events:
				print("[TurnMode] Ball entered hole:", ball.name, " -> grant chances to others")
	else:
		# exiting hole
		m_locked_in_hole[ball] = false

		if _is_any_hole_lock_active(game):
			# other balls still in hole -> this exiting ball gets 3 chances
			m_chances_remaining[ball] = 0 if ball.m_in_hole else 3
			if game.print_extra_chance_events:
				print("[TurnMode] Ball exited hole while others remain:", ball.name, " chances=3")
		else:
			# no lock remains -> clear all chances
			for b: MarbleBall in game.get_balls():
				m_chances_remaining[b] = 0
			if game.print_extra_chance_events:
				print("[TurnMode] No balls locked -> clear all chances")

func _handle_hole_lock_turn_flow(game: MarbleGame) -> void:
	var chosen := _pick_next_hole_lock_ball(game)
	if chosen == null:
		_disable_all(game)
		game._set_turn_active(false)
		game._set_status(MarbleGame.GameStatus.WAITING_FOR_REST)
		return

	m_current_ball = chosen
	_reset_fresh_turn_state()
	_begin_kick_window(game, m_current_ball)

func _begin_kick_window(game: MarbleGame, ball: MarbleBall) -> void:
	_disable_all(game)

	if ball == null or not is_instance_valid(ball):
		m_waiting_for_kick = false
		game._set_turn_active(false)
		game._set_status(MarbleGame.GameStatus.WAITING_FOR_REST)
		game._set_current_ball(null)
		return

	# never activate a ball that is in the hole
	if ball.m_in_hole:
		m_waiting_for_kick = false
		game._set_turn_active(false)
		game._set_status(MarbleGame.GameStatus.WAITING_FOR_REST)
		game._set_current_ball(null)
		return

	m_waiting_for_kick = true
	game._set_status(MarbleGame.GameStatus.WAITING_FOR_KICK)
	game._set_turn_active(true)
	game._set_current_ball(ball)

	ball.set_controller_active(true)

func _pick_next_normal_ball(game: MarbleGame, allow_same_index: bool) -> MarbleBall:
	var balls := game.get_balls()
	if balls.is_empty():
		return null

	var start := m_turn_index
	if m_turn_index < 0:
		start = game.starting_ball_index % balls.size()
	elif not allow_same_index:
		start = (m_turn_index + 1) % balls.size()

	for step in balls.size():
		var idx := (start + step) % balls.size()
		var b := balls[idx]
		if not is_instance_valid(b):
			continue
		if b.m_in_hole:
			continue
		m_turn_index = idx
		return b

	return null

func _pick_next_hole_lock_ball(game: MarbleGame) -> MarbleBall:
	var balls := game.get_balls()
	if balls.is_empty():
		return null

	var start := m_turn_index
	if m_turn_index < 0:
		start = game.starting_ball_index % balls.size()
	else:
		start = (m_turn_index + 1) % balls.size()

	for step in balls.size():
		var idx := (start + step) % balls.size()
		var b := balls[idx]
		if not is_instance_valid(b):
			continue
		if b.m_in_hole:
			continue
		if int(m_chances_remaining.get(b, 0)) <= 0:
			continue
		m_turn_index = idx
		return b

	return null

func _reset_fresh_turn_state() -> void:
	m_turn_kicks_taken = 0
	m_extra_chance_awarded = false
	m_extra_kick_consumed = false

func _should_start_extra_kick(game: MarbleGame) -> bool:
	if not game.enable_extra_chance_on_hit:
		return false
	return (m_turn_kicks_taken == 1) and m_extra_chance_awarded and (not m_extra_kick_consumed)

func _disable_all(game: MarbleGame) -> void:
	for b: MarbleBall in game.get_balls():
		if is_instance_valid(b):
			b.set_controller_active(false)

func _is_any_hole_lock_active(game: MarbleGame) -> bool:
	for b: MarbleBall in game.get_balls():
		if bool(m_locked_in_hole.get(b, false)) and b.m_in_hole:
			return true
	return false

func _all_balls_are_slow(game: MarbleGame) -> bool:
	for b: MarbleBall in game.get_balls():
		if not is_instance_valid(b):
			continue
		if b.linear_velocity.length() > game.rest_linear_speed_threshold:
			return false
		if absf(b.angular_velocity) > game.rest_angular_speed_threshold:
			return false
	return true
