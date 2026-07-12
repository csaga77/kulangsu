class_name MarbleBallController
extends Resource

var m_ball: MarbleBall = null
var m_game: MarbleGame = null
var m_allowed: bool = false


func set_ball(ball: MarbleBall) -> void:
	m_ball = ball


func set_game(game: MarbleGame) -> void:
	m_game = game


func set_allowed(is_allowed: bool) -> void:
	if m_allowed == is_allowed:
		return
	m_allowed = is_allowed
	_on_allowed_changed(m_allowed)


func _on_allowed_changed(_is_allowed: bool) -> void:
	pass


func handle_input(_event: InputEvent) -> void:
	pass


func physics_tick(_delta: float) -> void:
	pass


func spawn_and_throw_away_from_hole(rng: RandomNumberGenerator) -> void:
	if not is_instance_valid(m_ball) or not is_instance_valid(m_game):
		return

	var hole: MarbleHole = m_game.get_hole()
	if not is_instance_valid(hole):
		return

	m_ball.sleeping = false
	m_ball.freeze = false
	m_ball.linear_velocity = Vector3.ZERO
	m_ball.angular_velocity = Vector3.ZERO
	m_ball.clear_damping_contributions()
	m_ball.set_in_hole(false)

	var hole_position_2d := Vector2(hole.global_position.x, hole.global_position.z)
	var minimum_distance: float = m_ball.marble_radius * 4.0
	var maximum_distance: float = m_ball.marble_radius * 24.0
	var spawn_rect: Rect2 = m_game.get_spawn_rect_for_ball(m_ball)
	var spawn_position_2d := _pick_spawn_position(
		rng,
		hole_position_2d,
		minimum_distance,
		maximum_distance,
		spawn_rect
	)
	var spawn_position := Vector3(
		spawn_position_2d.x,
		m_game.get_ball_spawn_height(m_ball),
		spawn_position_2d.y
	)
	m_ball.global_position = spawn_position
	m_ball.reset_physics_interpolation()

	var direction_2d := (spawn_position_2d - hole_position_2d).normalized()
	direction_2d = direction_2d.rotated(rng.randf_range(-0.35, 0.35)).normalized()
	var throw_speed: float = rng.randf_range(2.2, 5.4)
	m_ball.linear_velocity = Vector3(direction_2d.x, 0.0, direction_2d.y) * throw_speed


func _pick_spawn_position(
	rng: RandomNumberGenerator,
	hole_position: Vector2,
	minimum_distance: float,
	maximum_distance: float,
	spawn_rect: Rect2
) -> Vector2:
	var has_spawn_rect: bool = spawn_rect.size.x > 0.0 and spawn_rect.size.y > 0.0
	if has_spawn_rect:
		for _attempt: int in 48:
			var candidate := Vector2(
				rng.randf_range(spawn_rect.position.x, spawn_rect.end.x),
				rng.randf_range(spawn_rect.position.y, spawn_rect.end.y)
			)
			var distance_to_hole: float = candidate.distance_to(hole_position)
			if distance_to_hole < minimum_distance or distance_to_hole > maximum_distance:
				continue
			if _is_spawn_position_clear(candidate):
				return candidate

		for _attempt: int in 48:
			var relaxed_candidate := Vector2(
				rng.randf_range(spawn_rect.position.x, spawn_rect.end.x),
				rng.randf_range(spawn_rect.position.y, spawn_rect.end.y)
			)
			if _is_spawn_position_clear(relaxed_candidate):
				return relaxed_candidate
		return spawn_rect.get_center()

	for _attempt: int in 48:
		var angle: float = rng.randf_range(0.0, TAU)
		var distance: float = rng.randf_range(minimum_distance, maximum_distance)
		var candidate := hole_position + Vector2.RIGHT.rotated(angle) * distance
		if _is_spawn_position_clear(candidate):
			return candidate
	return hole_position + Vector2.RIGHT * minimum_distance


func _is_spawn_position_clear(candidate: Vector2) -> bool:
	if not is_instance_valid(m_game) or not is_instance_valid(m_ball):
		return true

	var minimum_gap: float = m_ball.marble_radius * 2.25
	for other: MarbleBall in m_game.get_balls():
		if other == null or other == m_ball or not is_instance_valid(other):
			continue
		var other_position := Vector2(other.global_position.x, other.global_position.z)
		if candidate.distance_to(other_position) < minimum_gap:
			return false
	return true
