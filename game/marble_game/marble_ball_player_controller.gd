# MarbleBallPlayerController.gd
class_name MarbleBallPlayerController
extends MarbleBallController

## How close the mouse must be to pick the ball for dragging.
@export var drag_pick_radius: float = 48.0

## Drag vector multiplier to compute kick impulse.
@export var kick_impulse_scale: float = 4.0

## Maximum impulse length applied to the ball.
@export var kick_max_impulse: float = 200.0

## Ignore drag if shorter than this (px).
@export var min_drag_distance: float = 6.0

## When player grabs the ball, scale down its current velocity.
@export var slowdown_factor: float = 0.35

var m_dragging: bool = false
var m_drag_start_pos: Vector2 = Vector2.ZERO
var m_drag_end_pos: Vector2 = Vector2.ZERO

func handle_input(event: InputEvent) -> void:
	if not m_allowed:
		return
	if not is_instance_valid(m_ball):
		return
	if m_ball.m_in_hole:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var mouse_pos := m_ball.get_global_mouse_position()
			if mouse_pos.distance_to(m_ball.global_position) <= drag_pick_radius:
				m_dragging = true
				m_drag_start_pos = mouse_pos
				m_drag_end_pos = mouse_pos
				_slow_down_ball()
		else:
			if m_dragging:
				m_dragging = false
				m_drag_end_pos = m_ball.get_global_mouse_position()
				_kick_ball()

	elif event is InputEventMouseMotion:
		if m_dragging:
			m_drag_end_pos = m_ball.get_global_mouse_position()

func _slow_down_ball() -> void:
	m_ball.linear_velocity *= slowdown_factor
	m_ball.angular_velocity *= slowdown_factor

func _kick_ball() -> void:
	var drag_vec := m_drag_end_pos - m_drag_start_pos
	var dist := drag_vec.length()
	if dist < min_drag_distance:
		return

	var impulse := drag_vec * kick_impulse_scale
	var impulse_len := impulse.length()
	if impulse_len > kick_max_impulse:
		impulse = impulse * (kick_max_impulse / impulse_len)

	m_ball.apply_central_impulse(impulse)
	m_ball.notify_kicked()
