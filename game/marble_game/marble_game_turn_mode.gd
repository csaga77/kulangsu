# MarbleGameTurnMode.gd
class_name MarbleGameTurnMode
extends MarbleGameMode

@export var starting_ball_index: int = 0
@export var enable_extra_chance_on_hit: bool = true
@export var print_extra_chance_events: bool = true
@export var lock_chances_default: int = 3

@export var auto_restart_on_game_over: bool = true
@export var auto_restart_delay_sec: float = 0.6

var m_waiting_for_kick: bool = false
var m_rest_timer: float = 0.0

var m_current_ball: MarbleBall = null
var m_turn_index: int = -1
var m_first_turn_pending: bool = true

var m_turn_kicks_taken: int = 0
var m_extra_chance_awarded: bool = false
var m_extra_kick_consumed: bool = false

var m_is_winner: Dictionary = {}
var m_chances_remaining: Dictionary = {}
var m_locked_balls: Array[MarbleBall] = []

var m_pending_loser_ball: MarbleBall = null
var m_last_debug_frame: int = -999999
var m_restart_timer: float = 0.0


func on_restart(game: MarbleGame) -> void:
	super.on_restart(game)
	_disable_all(game)

	m_waiting_for_kick = false
	m_rest_timer = 0.0

	m_current_ball = null
	m_turn_index = -1
	m_first_turn_pending = true

	_reset_turn_state()

	m_is_winner.clear()
	m_chances_remaining.clear()
	m_locked_balls.clear()
	m_pending_loser_ball = null

	m_restart_timer = 0.0

	for b: MarbleBall in game.get_balls():
		m_is_winner[b] = false
		m_chances_remaining[b] = 0

	game._set_status(MarbleGame.GameStatus.WAITING_FOR_REST)
	game._set_turn_active(false)
	game._set_rest_progress(0.0)
	game._set_current_ball(null)


func on_apply_mode(game: MarbleGame) -> void:
	super.on_apply_mode(game)


func on_physics_process(game: MarbleGame, delta: float) -> void:
	if game.m_status == MarbleGame.GameStatus.GAME_OVER:
		if auto_restart_on_game_over:
			m_restart_timer += delta
			if m_restart_timer >= auto_restart_delay_sec:
				m_restart_timer = 0.0
				game.restart_game()
		return

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

	game._set_rest_progress(m_rest_timer / max(rest_settle_time, 0.001))
	if m_rest_timer < rest_settle_time:
		return

	m_rest_timer = 0.0
	game._set_rest_progress(0.0)

	_evaluate_after_rest(game)


func on_ball_kicked(game: MarbleGame, ball: MarbleBall) -> void:
	if not m_waiting_for_kick:
		return
	if ball != m_current_ball:
		return

	m_turn_kicks_taken += 1

	if _is_lock_active():
		var cur: int = int(m_chances_remaining.get(ball, 0))
		if cur > 0:
			cur -= 1
			m_chances_remaining[ball] = cur
			if print_extra_chance_events:
				print("[TurnMode] Chance used. Ball=", ball.name, " remaining=", cur)

		if cur == 0:
			var last := _get_last_remaining_nonwinner_not_in_hole(game)
			if last != null and last == ball:
				m_pending_loser_ball = ball
				if print_extra_chance_events:
					print("[TurnMode] Pending loser set (final chance used): ", ball.name)

	m_waiting_for_kick = false
	_disable_all(game)

	game._set_turn_active(false)
	game._set_status(MarbleGame.GameStatus.WAITING_FOR_REST)
	game._set_rest_progress(0.0)


func on_ball_body_entered(_game: MarbleGame, self_ball: MarbleBall, other_body: Node) -> void:
	if self_ball.m_in_hole:
		return
	if _is_winner(self_ball):
		return
	if not enable_extra_chance_on_hit:
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
	if print_extra_chance_events:
		print("[TurnMode] Extra chance awarded. Ball=", self_ball.name)


func on_ball_hole_state_changed(game: MarbleGame, ball: MarbleBall, in_hole: bool) -> void:
	if _is_winner(ball):
		return

	var was_lock_active := _is_lock_active()

	if in_hole:
		_clear_ball_turn_and_lock_state_on_hole(game, ball)

		if not m_locked_balls.has(ball):
			m_locked_balls.append(ball)

		if m_pending_loser_ball == ball:
			m_pending_loser_ball = null
			if print_extra_chance_events:
				print("[TurnMode] Pending loser cleared (entered hole): ", ball.name)

		var now_lock_active := _is_lock_active()
		if (not was_lock_active) and now_lock_active:
			_grant_lock_chances_for_all(game)
	else:
		m_locked_balls.erase(ball)

		if _is_lock_active() and (not ball.m_in_hole):
			_grant_lock_chances_if_eligible(ball)


func _grant_lock_chances_for_all(game: MarbleGame) -> void:
	for b: MarbleBall in game.get_balls():
		if not is_instance_valid(b):
			continue
		if _is_winner(b):
			m_chances_remaining[b] = 0
			continue
		if b.m_in_hole:
			m_chances_remaining[b] = 0
			continue
		m_chances_remaining[b] = max(0, lock_chances_default)

	if print_extra_chance_events:
		print("[TurnMode] Lock activated. Granted chances to all challengers: ", lock_chances_default)


func _evaluate_after_rest(game: MarbleGame) -> void:
	_cleanup_locked_list()

	if _should_start_extra_kick():
		m_extra_kick_consumed = true
		_open_kick_window(game, m_current_ball)
		return

	if _is_lock_active():
		var challenger := _pick_next_challenger_with_chances(game)
		if challenger != null:
			_reset_turn_state()
			m_current_ball = challenger
			_open_kick_window(game, m_current_ball)
			return

		var last := _get_only_remaining_nonwinner_not_in_hole(game)
		if last != null:
			var ch := int(m_chances_remaining.get(last, 0))
			if ch <= 0 and (not last.m_in_hole) and (not _is_winner(last)):
				_resolve_locked_balls_as_winners(game)
				game.declare_loser(last)
				game.end_game()
				m_restart_timer = 0.0
				return

		_resolve_locked_balls_as_winners(game)
		_evaluate_after_rest(game)
		return

	if m_first_turn_pending:
		m_first_turn_pending = false
		m_current_ball = _pick_next_normal_ball(game, true)
		_reset_turn_state()
		if m_current_ball != null:
			_open_kick_window(game, m_current_ball)
			return
	else:
		m_current_ball = _pick_next_normal_ball(game, false)
		_reset_turn_state()
		if m_current_ball != null:
			_open_kick_window(game, m_current_ball)
			return

	if m_pending_loser_ball != null and is_instance_valid(m_pending_loser_ball):
		if m_pending_loser_ball.m_in_hole:
			if print_extra_chance_events:
				print("[TurnMode] Pending loser cleared (entered hole): ", m_pending_loser_ball.name)
			m_pending_loser_ball = null
		elif _is_lock_active():
			_resolve_locked_balls_as_winners(game)
			game.declare_loser(m_pending_loser_ball)
			m_pending_loser_ball = null
			game.end_game()
			m_restart_timer = 0.0
			return
		else:
			if print_extra_chance_events:
				print("[TurnMode] Pending loser cleared (lock ended): ", m_pending_loser_ball.name)
			m_pending_loser_ball = null

	if _all_balls_finished(game):
		_resolve_all_in_hole_as_winners(game)
		game.end_game()
		m_restart_timer = 0.0
		return

	_debug(game, "continue_no_action")


func _cleanup_locked_list() -> void:
	for i in range(m_locked_balls.size() - 1, -1, -1):
		var b := m_locked_balls[i]
		if not is_instance_valid(b) or _is_winner(b) or (not b.m_in_hole):
			m_locked_balls.remove_at(i)


func _is_lock_active() -> bool:
	for b: MarbleBall in m_locked_balls:
		if is_instance_valid(b) and b.m_in_hole and (not _is_winner(b)):
			return true
	return false


func _resolve_locked_balls_as_winners(game: MarbleGame) -> void:
	for i in range(m_locked_balls.size() - 1, -1, -1):
		var b: MarbleBall = m_locked_balls[i]
		if is_instance_valid(b) and b.m_in_hole and not _is_winner(b):
			_set_winner(game, b)
		m_locked_balls.remove_at(i)

	for k in m_chances_remaining.keys():
		m_chances_remaining[k] = 0


func _set_winner(game: MarbleGame, ball: MarbleBall) -> void:
	if ball == null or not is_instance_valid(ball):
		return
	if _is_winner(ball):
		return

	m_is_winner[ball] = true
	ball.set_controller_active(false)
	game.declare_winner(ball)

	if print_extra_chance_events:
		print("[TurnMode] Winner confirmed:", ball.name)


func _grant_lock_chances_if_eligible(b: MarbleBall) -> void:
	if not _is_lock_active():
		return
	if b == null or not is_instance_valid(b):
		return
	if _is_winner(b):
		return
	if b.m_in_hole:
		return

	var cur: int = int(m_chances_remaining.get(b, 0))
	if cur <= 0:
		m_chances_remaining[b] = max(0, lock_chances_default)
		if print_extra_chance_events:
			print("[TurnMode] Lock chances granted: ", b.name, " -> ", lock_chances_default)


func _resolve_all_in_hole_as_winners(game: MarbleGame) -> void:
	for b: MarbleBall in game.get_balls():
		if is_instance_valid(b) and b.m_in_hole and not _is_winner(b):
			_set_winner(game, b)
	m_locked_balls.clear()


func _open_kick_window(game: MarbleGame, ball: MarbleBall) -> void:
	_disable_all(game)

	if ball == null or not is_instance_valid(ball):
		m_waiting_for_kick = false
		game._set_turn_active(false)
		game._set_status(MarbleGame.GameStatus.WAITING_FOR_REST)
		game._set_current_ball(null)
		return

	if _is_winner(ball) or ball.m_in_hole:
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
		start = starting_ball_index % balls.size()
	elif not allow_same_index:
		start = (m_turn_index + 1) % balls.size()

	for step in range(balls.size()):
		var idx := (start + step) % balls.size()
		var b := balls[idx]
		if not is_instance_valid(b):
			continue
		if _is_winner(b):
			continue
		if b.m_in_hole:
			continue
		m_turn_index = idx
		return b

	return null


func _pick_next_challenger_with_chances(game: MarbleGame) -> MarbleBall:
	var balls := game.get_balls()
	if balls.is_empty():
		return null

	var start := m_turn_index
	if m_turn_index < 0:
		start = starting_ball_index % balls.size()
	else:
		start = (m_turn_index + 1) % balls.size()

	for step in range(balls.size()):
		var idx := (start + step) % balls.size()
		var b := balls[idx]
		if not is_instance_valid(b):
			continue
		if _is_winner(b):
			continue
		if b.m_in_hole:
			continue
		if int(m_chances_remaining.get(b, 0)) <= 0:
			continue
		m_turn_index = idx
		return b

	return null


func _reset_turn_state() -> void:
	m_turn_kicks_taken = 0
	m_extra_chance_awarded = false
	m_extra_kick_consumed = false


func _should_start_extra_kick() -> bool:
	if m_current_ball == null or not is_instance_valid(m_current_ball):
		return false
	if m_current_ball.m_in_hole or _is_winner(m_current_ball):
		return false
	return (m_turn_kicks_taken == 1) and m_extra_chance_awarded and (not m_extra_kick_consumed)


func _clear_ball_turn_and_lock_state_on_hole(game: MarbleGame, ball: MarbleBall) -> void:
	m_chances_remaining[ball] = 0

	if m_pending_loser_ball == ball:
		m_pending_loser_ball = null
		if print_extra_chance_events:
			print("[TurnMode] Pending loser cleared (entered hole): ", ball.name)

	if ball == m_current_ball:
		_reset_turn_state()
		if print_extra_chance_events:
			print("[TurnMode] Cleared turn extra-chance state (entered hole): ", ball.name)

		if m_waiting_for_kick:
			m_waiting_for_kick = false
			_disable_all(game)
			game._set_turn_active(false)
			game._set_status(MarbleGame.GameStatus.WAITING_FOR_REST)
			game._set_rest_progress(0.0)


func _disable_all(game: MarbleGame) -> void:
	for b: MarbleBall in game.get_balls():
		if is_instance_valid(b):
			b.set_controller_active(false)


func _is_winner(ball: MarbleBall) -> bool:
	return bool(m_is_winner.get(ball, false))


func _all_balls_finished(game: MarbleGame) -> bool:
	for b: MarbleBall in game.get_balls():
		if not is_instance_valid(b):
			continue
		if _is_winner(b):
			continue
		if b.m_in_hole:
			continue
		return false
	return true


func _all_balls_are_slow(game: MarbleGame) -> bool:
	for b: MarbleBall in game.get_balls():
		if not is_instance_valid(b):
			continue
		if b.linear_velocity.length() > rest_linear_speed_threshold:
			return false
		if absf(b.angular_velocity) > rest_angular_speed_threshold:
			return false
	return true


func _get_last_remaining_nonwinner_not_in_hole(game: MarbleGame) -> MarbleBall:
	var last: MarbleBall = null
	for b: MarbleBall in game.get_balls():
		if not is_instance_valid(b):
			continue
		if _is_winner(b):
			continue
		if b.m_in_hole:
			continue
		if last != null:
			return null
		last = b
	return last


func _get_only_remaining_nonwinner_not_in_hole(game: MarbleGame) -> MarbleBall:
	var last: MarbleBall = null
	for b: MarbleBall in game.get_balls():
		if not is_instance_valid(b):
			continue
		if _is_winner(b):
			continue
		if b.m_in_hole:
			continue
		if last != null:
			return null
		last = b
	return last


func _debug(game: MarbleGame, tag: String) -> void:
	var frame := Engine.get_physics_frames()
	if frame - m_last_debug_frame < 30:
		return
	m_last_debug_frame = frame

	print("[TurnMode DEBUG] ", tag,
		" locked=", m_locked_balls.size(),
		" pending_loser=", (m_pending_loser_ball.name if m_pending_loser_ball != null else "<none>"))

	for b: MarbleBall in game.get_balls():
		if not is_instance_valid(b):
			continue
		print("  -> ", b.name,
			" in_hole=", b.m_in_hole,
			" winner=", _is_winner(b),
			" chances=", int(m_chances_remaining.get(b, 0)))
