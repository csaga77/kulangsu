# MarbleBallAIController.gd
class_name MarbleBallAIController
extends MarbleBallController

## AI kick impulse multiplier (slightly bigger than player).
@export var kick_impulse_scale: float = 4.5

## Maximum impulse length.
@export var kick_max_impulse: float = 240.0

## Minimum impulse length (prevents tiny taps).
@export var kick_min_impulse: float = 30.0

## Delay (seconds) before AI kicks after becoming allowed.
@export var think_delay: float = 0.25

## How much randomness to add to aim direction (radians).
@export var aim_jitter_radians: float = 0.12

## Extra lead factor: aims a bit past the hole to compensate friction/damp.
@export var lead_factor: float = 1.0

var m_timer: float = 0.0

func _on_allowed_changed(is_allowed: bool) -> void:
	m_timer = 0.0
	if not is_allowed:
		return

func physics_tick(delta: float) -> void:
	if not m_allowed:
		return
	if not is_instance_valid(m_ball):
		return
	if m_ball.m_in_hole:
		return

	m_timer += delta
	if m_timer < think_delay:
		return

	if not is_instance_valid(m_game) or not is_instance_valid(m_game.m_hole):
		return

	_kick_towards_hole(m_game)
	m_timer = 0.0

func _kick_towards_hole(game: MarbleGame) -> void:
	var to_hole := (game.m_hole.global_position - m_ball.global_position)
	var dist := to_hole.length()
	if dist < 0.001:
		return

	var dir := to_hole.normalized()
	dir = dir.rotated(randf_range(-aim_jitter_radians, aim_jitter_radians))

	var base_len = clamp(dist * lead_factor, kick_min_impulse, kick_max_impulse)
	var impulse = dir * base_len * kick_impulse_scale
	if impulse.length() > kick_max_impulse:
		impulse = impulse.normalized() * kick_max_impulse

	m_ball.apply_central_impulse(impulse)
	m_ball.notify_kicked()
