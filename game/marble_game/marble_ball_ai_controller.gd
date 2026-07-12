class_name MarbleBallAIController
extends MarbleBallController

@export var kick_impulse_scale: float = 1.0
@export var kick_max_impulse: float = 4.8
@export var kick_min_impulse: float = 0.8
@export var dist_near: float = 2.0
@export var dist_far: float = 13.0
@export var impulse_near: float = 1.1
@export var impulse_far: float = 3.6
@export var think_delay: float = 0.4
@export var aim_jitter_radians: float = 0.10
@export var strength_random_min: float = 0.90
@export var strength_random_max: float = 1.10
@export var lead_factor: float = 1.0

var m_timer: float = 0.0


func _on_allowed_changed(_is_allowed: bool) -> void:
	m_timer = 0.0


func physics_tick(delta: float) -> void:
	if not m_allowed or not is_instance_valid(m_ball) or m_ball.m_in_hole:
		return
	if not is_instance_valid(m_game) or not is_instance_valid(m_game.get_hole()):
		return

	m_timer += delta
	if m_timer < think_delay:
		return
	_kick_towards_hole(m_game)
	m_timer = 0.0


func _kick_towards_hole(game: MarbleGame) -> void:
	var to_hole: Vector3 = game.get_hole().global_position - m_ball.global_position
	to_hole.y = 0.0
	var distance: float = to_hole.length()
	if distance < 0.001:
		return

	var direction: Vector3 = to_hole.normalized()
	direction = direction.rotated(Vector3.UP, randf_range(-aim_jitter_radians, aim_jitter_radians))
	var amount: float = 0.0
	if dist_far > dist_near:
		amount = clampf((distance - dist_near) / (dist_far - dist_near), 0.0, 1.0)
	amount = amount * amount * (3.0 - 2.0 * amount)

	var magnitude: float = lerpf(impulse_near, impulse_far, amount)
	magnitude *= maxf(0.0, lead_factor)
	magnitude *= randf_range(strength_random_min, strength_random_max)
	magnitude = clampf(magnitude * kick_impulse_scale, kick_min_impulse, kick_max_impulse)

	m_ball.apply_central_impulse(direction * magnitude)
	m_ball.notify_kicked()
