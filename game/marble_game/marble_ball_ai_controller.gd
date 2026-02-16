# MarbleBallAIController.gd
class_name MarbleBallAIController
extends MarbleBallController

## Base multiplier applied after distance-based magnitude is computed.
@export var kick_impulse_scale: float = 1.0

## Maximum impulse length that can be applied.
@export var kick_max_impulse: float = 260.0

## Minimum impulse length applied (prevents tiny taps).
@export var kick_min_impulse: float = 30.0

## Distance (px) considered "near" the hole for impulse mapping.
@export var dist_near: float = 80.0

## Distance (px) considered "far" the hole for impulse mapping.
@export var dist_far: float = 520.0

## Impulse length to use when at dist_near.
@export var impulse_near: float = 45.0

## Impulse length to use when at dist_far.
@export var impulse_far: float = 140.0

## Delay (seconds) before AI kicks after becoming allowed.
@export var think_delay: float = 0.25

## Random aim jitter in radians (direction randomness).
@export var aim_jitter_radians: float = 0.10

## Random strength multiplier range (e.g. 0.9~1.1).
@export var strength_random_min: float = 0.90
@export var strength_random_max: float = 1.10

## Optional: add a little "lead" to compensate damping/friction (1.0 = none).
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
	if not is_instance_valid(m_game):
		return
	if not is_instance_valid(m_game.get_hole()):
		return

	m_timer += delta
	if m_timer < think_delay:
		return

	_kick_towards_hole(m_game)
	m_timer = 0.0


func _kick_towards_hole(game: MarbleGame) -> void:
	var to_hole = (game.get_hole().global_position - m_ball.global_position)
	var dist = to_hole.length()
	if dist < 0.001:
		return

	# --- Direction with randomness ---
	var dir = to_hole.normalized()
	var jitter := randf_range(-aim_jitter_radians, aim_jitter_radians)
	dir = dir.rotated(jitter)

	# --- Distance -> impulse magnitude ---
	# Map dist_near..dist_far to impulse_near..impulse_far
	var t := 0.0
	if dist_far > dist_near:
		t = clamp((dist - dist_near) / (dist_far - dist_near), 0.0, 1.0)

	# Smooth the curve a bit so it doesn't jump (smoothstep)
	t = t * t * (3.0 - 2.0 * t)

	var magnitude = lerp(impulse_near, impulse_far, t)

	# Apply lead & randomness
	magnitude *= max(0.0, lead_factor)
	magnitude *= randf_range(strength_random_min, strength_random_max)

	# Scale, clamp
	magnitude *= kick_impulse_scale
	magnitude = clamp(magnitude, kick_min_impulse, kick_max_impulse)

	var impulse = dir * magnitude
	m_ball.apply_central_impulse(impulse)
	m_ball.notify_kicked()
