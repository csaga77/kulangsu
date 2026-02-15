# MarbleGameTurnMode.gd
class_name MarbleGameTurnMode
extends MarbleGameMode

## TURN mode:
## Decisions are ONLY made after rest settles.
## Priority at rest-settle:
##   A) Maintain lock queue (promote queued lock if no active lock)
##   B) Extra chance kick
##   C) Hole-lock challenger kick (or lock resolves into a winner)
##   D) Normal next ball kick
##   E) (LAST) Pending-loser resolution, Game over, Continue

var m_waiting_for_kick: bool = false
var m_rest_timer: float = 0.0

var m_current_ball: MarbleBall = null
var m_turn_index: int = -1
var m_first_turn_pending: bool = true

# Per-turn extra chance bookkeeping (used only after rest settles)
var m_turn_kicks_taken: int = 0
var m_extra_chance_awarded: bool = false
var m_extra_kick_consumed: bool = false

# Winner / lock state
var m_is_winner: Dictionary = {}                 # MarbleBall -> bool
var m_lock_ball: MarbleBall = null               # currently challenged ball in hole
var m_lock_queue: Array[MarbleBall] = []         # balls that entered hole while a lock was active
var m_chances_remaining: Dictionary = {}         # MarbleBall -> int (challenger chances during current lock)

# Pending “last chance used” loser check, resolved after all other logic
var m_pending_loser_ball: MarbleBall = null

# Debug spam guard
var m_last_debug_frame: int = -999999

const LOCK_CHANCES_DEFAULT: int = 3


func on_restart(game: MarbleGame) -> void:
	_disable_all(game)

	m_waiting_for_kick = false
	m_rest_timer = 0.0

	m_current_ball = null
	m_turn_index = -1
	m_first_turn_pending = true

	_reset_turn_state()

	m_is_winner.clear()
	m_chances_remaining.clear()
	m_lock_ball = null
	m_lock_queue.clear()
	m_pending_loser_ball = null

	for b: MarbleBall in game.get_balls():
		m_is_winner[b] = false
		m_chances_remaining[b] = 0

	game.set_active_lock_ball(null)

	game._set_status(MarbleGame.GameStatus.WAITING_FOR_REST)
	game._set_turn_active(false)
	game._set_rest_progress(0.0)
	game._set_current_ball(null)


func on_apply_mode(game: MarbleGame) -> void:
	on_restart(game)


func on_physics_process(game: MarbleGame, delta: float) -> void:
	if game.m_status == MarbleGame.GameStatus.GAME_OVER:
		return

	# Kick window active: wait for controller to kick
	if m_waiting_for_kick:
		game._set_status(MarbleGame.GameStatus.WAITING_FOR_KICK)
		game._set_turn_active(true)
		game._set_rest_progress(0.0)
		return

	# Waiting for rest (always)
	game._set_status(MarbleGame.GameStatus.WAITING_FOR_REST)
	game._set_turn_active(false)

	if _all_balls_are_slow(game):
		m_rest_timer += delta
	else:
		m_rest_timer = 0.0

	game._set_rest_progress(m_rest_timer / max(game.rest_settle_time, 0.001))
	if m_rest_timer < game.rest_settle_time:
		return

	# Rest settled -> evaluate next action (ALL decisions centralized here)
	m_rest_timer = 0.0
	game._set_rest_progress(0.0)

	_evaluate_after_rest(game)


func on_ball_kicked(game: MarbleGame, ball: MarbleBall) -> void:
	# Close kick window, but DO NOT decide next step here.
	if not m_waiting_for_kick:
		return
	if ball != m_current_ball:
		return

	m_turn_kicks_taken += 1

	# If lock is active, consume a chance for this challenger
	if _is_lock_active():
		var cur := int(m_chances_remaining.get(ball, 0))
		if cur > 0:
			cur -= 1
			m_chances_remaining[ball] = cur
			if game.print_extra_chance_events:
				print("[TurnMode] Chance used. Ball=", ball.name, " remaining=", cur)

		# If this ball is the last remaining challenger AND it used its last chance,
		# we set pending loser and resolve only after ALL other logic.
		if cur == 0:
			var last := _get_last_remaining_nonwinner_not_in_hole(game)
			if last != null and last == ball:
				m_pending_loser_ball = ball
				if game.print_extra_chance_events:
					print("[TurnMode] Pending loser set (final chance used): ", ball.name)

	# Close the kick window and wait for rest settle
	m_waiting_for_kick = false
	_disable_all(game)

	game._set_turn_active(false)
	game._set_status(MarbleGame.GameStatus.WAITING_FOR_REST)
	game._set_rest_progress(0.0)


func on_ball_body_entered(game: MarbleGame, self_ball: MarbleBall, other_body: Node) -> void:
	# Extra chance does NOT apply when the hitting ball is in the hole.
	if self_ball.m_in_hole:
		return
	if _is_winner(self_ball):
		return
	if not game.enable_extra_chance_on_hit:
		return

	# Only award for the current active ball, after its first kick of the turn.
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
		print("[TurnMode] Extra chance awarded. Ball=", self_ball.name)


func on_ball_hole_state_changed(game: MarbleGame, ball: MarbleBall, in_hole: bool) -> void:
	if _is_winner(ball):
		return

	if in_hole:
		# NEW RULE:
		# When a ball settles in a hole, it clears all its kick extra chance
		# and lock-hole challenger chances.
		_clear_ball_turn_and_lock_state_on_hole(game, ball)

		# If a lock is active for another ball, queue this one.
		if _is_lock_active() and m_lock_ball != ball:
			if not m_lock_queue.has(ball):
				m_lock_queue.append(ball)
				if game.print_extra_chance_events:
					print("[TurnMode] Queued lock ball:", ball.name, " (lock active:", m_lock_ball.name, ")")
			return

		# Otherwise start lock now (evaluation still happens only after rest settles)
		_start_lock_for_ball(game, ball)

		# If pending loser ball entered hole, it’s no longer pending.
		if m_pending_loser_ball == ball:
			m_pending_loser_ball = null
			if game.print_extra_chance_events:
				print("[TurnMode] Pending loser cleared (entered hole): ", ball.name)

	else:
		# If lock ball got kicked out, cancel lock (evaluation continues after rest settles)
		if m_lock_ball == ball:
			if game.print_extra_chance_events:
				print("[TurnMode] Lock ball kicked out:", ball.name, " -> cancel lock")
			_cancel_lock(game)
			return

		# If a lock is active and a non-winner ball gets kicked OUT of the hole,
		# it becomes an eligible challenger and MUST receive lock chances now.
		if _is_lock_active() and ball != m_lock_ball and (not ball.m_in_hole):
			_grant_lock_chances_if_eligible(game, ball)


# -------------------------------------------------
# Core: decide next action ONLY after rest settles
# Game over / continue evaluated LAST
# -------------------------------------------------
func _evaluate_after_rest(game: MarbleGame) -> void:
	# -------------------------------------------------
	# A) Maintain lock queue (promote queued lock if no active lock)
	# -------------------------------------------------
	if (not _is_lock_active()) and (not m_lock_queue.is_empty()):
		while not m_lock_queue.is_empty():
			var next_lock = m_lock_queue.pop_front()
			if is_instance_valid(next_lock) and next_lock.m_in_hole and not _is_winner(next_lock):
				_start_lock_for_ball(game, next_lock)
				break

	# -------------------------------------------------
	# B) Extra chance (highest priority kick action)
	# -------------------------------------------------
	if _should_start_extra_kick():
		m_extra_kick_consumed = true
		_open_kick_window(game, m_current_ball)
		return

	# -------------------------------------------------
	# C) Hole-lock challenger selection / lock resolve
	# -------------------------------------------------
	if _is_lock_active():
		var challenger := _pick_next_challenger_with_chances(game)
		if challenger != null:
			_reset_turn_state() # new kicker gets a fresh turn state
			m_current_ball = challenger
			_open_kick_window(game, m_current_ball)
			return

		# No challenger with chances remaining -> lock ball is CONFIRMED winner.
		_set_winner(game, m_lock_ball)
		_cancel_lock(game)

		# After lock resolves, immediately re-run evaluation to pick next action this same settle.
		_evaluate_after_rest(game)
		return

	# -------------------------------------------------
	# D) Normal next ball
	# -------------------------------------------------
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

	# -------------------------------------------------
	# E) ONLY NOW evaluate "continue" and "game over"
	# -------------------------------------------------

	# E1) Resolve pending loser ONLY after other logic had no action
	if m_pending_loser_ball != null and is_instance_valid(m_pending_loser_ball):
		if m_pending_loser_ball.m_in_hole:
			if game.print_extra_chance_events:
				print("[TurnMode] Pending loser cleared (entered hole): ", m_pending_loser_ball.name)
			m_pending_loser_ball = null
		elif _is_lock_active():
			# Lock ball still in hole -> lock wins; pending loses -> game over
			_set_winner(game, m_lock_ball)

			for qb in m_lock_queue:
				if is_instance_valid(qb) and qb.m_in_hole and not _is_winner(qb):
					_set_winner(game, qb)
			m_lock_queue.clear()

			game.declare_loser(m_pending_loser_ball)
			m_pending_loser_ball = null
			game.end_game()
			return
		else:
			if game.print_extra_chance_events:
				print("[TurnMode] Pending loser cleared (lock ended): ", m_pending_loser_ball.name)
			m_pending_loser_ball = null

	# E2) Game over if all balls are either confirmed winners OR currently in the hole.
	# Winners may get kicked out later, but they still count as finished.
	if _all_balls_finished(game):
		_resolve_all_in_hole_as_winners(game)
		game.end_game()
		return

	# E3) Continue (no action possible this settle)
	_debug(game, "continue_no_action")


# -----------------------
# Lock / Win logic
# -----------------------
func _start_lock_for_ball(game: MarbleGame, ball: MarbleBall) -> void:
	m_lock_ball = ball
	game.set_active_lock_ball(ball)

	# Reset chances: all eligible challengers get 3 chances.
	for b: MarbleBall in game.get_balls():
		_grant_lock_chances_or_zero(game, b)

	if game.print_extra_chance_events:
		print("[TurnMode] Lock started for:", ball.name, " (challengers get ", LOCK_CHANCES_DEFAULT, " chances)")


func _grant_lock_chances_or_zero(game: MarbleGame, b: MarbleBall) -> void:
	if not is_instance_valid(b):
		return
	if b == m_lock_ball:
		m_chances_remaining[b] = 0
		return
	if _is_winner(b):
		m_chances_remaining[b] = 0
		return
	if b.m_in_hole:
		# In-hole balls do NOT get hole-lock chances.
		m_chances_remaining[b] = 0
		return
	m_chances_remaining[b] = LOCK_CHANCES_DEFAULT


# Grant chances dynamically when a ball becomes eligible during active lock.
func _grant_lock_chances_if_eligible(game: MarbleGame, b: MarbleBall) -> void:
	if not _is_lock_active():
		return
	if b == null or not is_instance_valid(b):
		return
	if b == m_lock_ball:
		return
	if _is_winner(b):
		return
	if b.m_in_hole:
		return

	var cur := int(m_chances_remaining.get(b, 0))
	if cur <= 0:
		m_chances_remaining[b] = LOCK_CHANCES_DEFAULT
		if game.print_extra_chance_events:
			print("[TurnMode] Lock chances granted (became eligible): ", b.name, " -> ", LOCK_CHANCES_DEFAULT)


func _cancel_lock(game: MarbleGame) -> void:
	m_lock_ball = null
	game.set_active_lock_ball(null)
	for b: MarbleBall in game.get_balls():
		m_chances_remaining[b] = 0


func _is_lock_active() -> bool:
	return m_lock_ball != null and is_instance_valid(m_lock_ball) and m_lock_ball.m_in_hole and (not _is_winner(m_lock_ball))


func _set_winner(game: MarbleGame, ball: MarbleBall) -> void:
	if ball == null or not is_instance_valid(ball):
		return
	if _is_winner(ball):
		return

	m_is_winner[ball] = true
	ball.set_controller_active(false)
	game.declare_winner(ball)

	if game.print_extra_chance_events:
		print("[TurnMode] Winner confirmed:", ball.name)


func _resolve_all_in_hole_as_winners(game: MarbleGame) -> void:
	if _is_lock_active():
		_set_winner(game, m_lock_ball)

	for b in m_lock_queue:
		if is_instance_valid(b) and b.m_in_hole and not _is_winner(b):
			_set_winner(game, b)
	m_lock_queue.clear()

	for b: MarbleBall in game.get_balls():
		if is_instance_valid(b) and b.m_in_hole and not _is_winner(b):
			_set_winner(game, b)


# -----------------------
# Kick window
# -----------------------
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


# -----------------------
# Selection
# -----------------------
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
		start = game.starting_ball_index % balls.size()
	else:
		start = (m_turn_index + 1) % balls.size()

	for step in balls.size():
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


# -----------------------
# Extra chance / turn state
# -----------------------
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


# -----------------------
# New: “settled in hole” cleanup
# -----------------------
func _clear_ball_turn_and_lock_state_on_hole(game: MarbleGame, ball: MarbleBall) -> void:
	# Clear lock-hole chances for this ball immediately.
	m_chances_remaining[ball] = 0

	# If it was pending loser, it is no longer pending.
	if m_pending_loser_ball == ball:
		m_pending_loser_ball = null
		if game.print_extra_chance_events:
			print("[TurnMode] Pending loser cleared (entered hole): ", ball.name)

	# If this ball is the current kicker, clear extra-kick state and close any kick window.
	if ball == m_current_ball:
		_reset_turn_state()
		if game.print_extra_chance_events:
			print("[TurnMode] Cleared turn extra-chance state (entered hole): ", ball.name)

		# If a kick window was open for this ball, close it defensively.
		if m_waiting_for_kick:
			m_waiting_for_kick = false
			_disable_all(game)
			game._set_turn_active(false)
			game._set_status(MarbleGame.GameStatus.WAITING_FOR_REST)
			game._set_rest_progress(0.0)


# -----------------------
# Utilities
# -----------------------
func _disable_all(game: MarbleGame) -> void:
	for b: MarbleBall in game.get_balls():
		if is_instance_valid(b):
			b.set_controller_active(false)

func _is_winner(ball: MarbleBall) -> bool:
	return bool(m_is_winner.get(ball, false))

# Finished means confirmed winner OR currently in hole
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
		if b.linear_velocity.length() > game.rest_linear_speed_threshold:
			return false
		if absf(b.angular_velocity) > game.rest_angular_speed_threshold:
			return false
		return true
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

func _debug(game: MarbleGame, tag: String) -> void:
	var frame := Engine.get_physics_frames()
	if frame - m_last_debug_frame < 30:
		return
	m_last_debug_frame = frame

	print("[TurnMode DEBUG] ", tag,
		" lock=", (m_lock_ball.name if m_lock_ball != null else "<none>"),
		" queue=", m_lock_queue.size(),
		" pending_loser=", (m_pending_loser_ball.name if m_pending_loser_ball != null else "<none>"))

	for b: MarbleBall in game.get_balls():
		if not is_instance_valid(b):
			continue
		print("  -> ", b.name,
			" in_hole=", b.m_in_hole,
			" winner=", _is_winner(b),
			" chances=", int(m_chances_remaining.get(b, 0)))
