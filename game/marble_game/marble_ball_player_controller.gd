class_name MarbleBallPlayerController
extends MarbleBallController

@export var drag_pick_radius: float = 0.7
@export var kick_impulse_scale: float = 0.65
@export var kick_max_impulse: float = 5.5
@export var min_drag_distance: float = 0.12
@export var slowdown_factor: float = 0.35

var m_dragging: bool = false
var m_drag_start_position: Vector3 = Vector3.ZERO
var m_drag_end_position: Vector3 = Vector3.ZERO


func handle_input(event: InputEvent) -> void:
	if not m_allowed or not is_instance_valid(m_ball) or m_ball.m_in_hole:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_event := event as InputEventMouseButton
		var board_position: Variant = _project_mouse_to_board(mouse_event.position)
		if board_position == null:
			return
		var world_position: Vector3 = board_position
		if mouse_event.pressed:
			var planar_ball_position := Vector3(m_ball.global_position.x, world_position.y, m_ball.global_position.z)
			if world_position.distance_to(planar_ball_position) <= drag_pick_radius:
				m_dragging = true
				m_drag_start_position = world_position
				m_drag_end_position = world_position
				_slow_down_ball()
		elif m_dragging:
			m_dragging = false
			m_drag_end_position = world_position
			_kick_ball()
	elif event is InputEventMouseMotion and m_dragging:
		var motion_event := event as InputEventMouseMotion
		var board_position: Variant = _project_mouse_to_board(motion_event.position)
		if board_position != null:
			m_drag_end_position = board_position


func _slow_down_ball() -> void:
	m_ball.linear_velocity *= slowdown_factor
	m_ball.angular_velocity *= slowdown_factor


func _kick_ball() -> void:
	var drag_vector: Vector3 = m_drag_end_position - m_drag_start_position
	drag_vector.y = 0.0
	if drag_vector.length() < min_drag_distance:
		return

	var impulse: Vector3 = drag_vector * kick_impulse_scale
	if impulse.length() > kick_max_impulse:
		impulse = impulse.normalized() * kick_max_impulse
	m_ball.apply_central_impulse(impulse)
	m_ball.notify_kicked()


func _project_mouse_to_board(screen_position: Vector2) -> Variant:
	if not is_instance_valid(m_ball):
		return null
	var camera: Camera3D = m_ball.get_viewport().get_camera_3d()
	if camera == null:
		return null

	var ray_origin: Vector3 = camera.project_ray_origin(screen_position)
	var ray_direction: Vector3 = camera.project_ray_normal(screen_position)
	var board_plane := Plane(Vector3.UP, m_ball.global_position.y)
	return board_plane.intersects_ray(ray_origin, ray_direction)
