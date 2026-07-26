@tool
class_name PlayerController3D
extends "res://characters/control/base_controller_3d.gd"

signal inspect_requested
signal context_action_requested
signal cancel_requested

@export var camera_relative_movement := false
@export var camera_path: NodePath
@export var walk_action := "ui_walk"
@export var jump_action := "ui_jump"
@export var inspect_action := "ui_inspect"
@export var cancel_action := "ui_cancel"

var m_cancel_request_pending := false
var m_cancel_request_consumed := false
var m_cancel_request_frame := -1


func _process(delta: float) -> void:
	if m_character == null or !is_instance_valid(m_character):
		return
	_expire_cancel_request()

	set_running(!Input.is_action_pressed(walk_action))

	var input_vector := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var movement_direction := _resolve_movement_direction(input_vector)
	if movement_direction.is_zero_approx():
		stop_moving()
	else:
		set_target_direction(movement_direction)
		move_forward()

	# Submit the current-frame movement intent before jump so takeoff captures the
	# accepted horizontal speed instead of the previous frame's velocity.
	super._process(delta)

	if Input.is_action_just_pressed(jump_action):
		if m_character.has_method("request_jump"):
			m_character.call("request_jump")
		elif m_character.has_method("jump"):
			m_character.call("jump")
	if Input.is_action_just_released(jump_action) and m_character.has_method("release_jump"):
		m_character.call("release_jump")

	if Input.is_action_just_pressed(inspect_action):
		context_action_requested.emit()
		inspect_requested.emit()
		inspect()

	if Input.is_action_just_pressed(cancel_action):
		request_cancel()


## Publishes one cancel intention synchronously. A world coordinator can consume
## it from its signal callback, then mark the originating InputEvent handled so
## the same Esc press does not also open pause.
func request_cancel() -> bool:
	var frame := Engine.get_process_frames()
	if m_cancel_request_frame == frame:
		return m_cancel_request_consumed
	m_cancel_request_frame = frame
	m_cancel_request_pending = true
	m_cancel_request_consumed = false
	cancel_requested.emit()
	return m_cancel_request_consumed


func has_pending_cancel_request() -> bool:
	return m_cancel_request_pending


func consume_cancel_request() -> bool:
	if !m_cancel_request_pending:
		return false
	m_cancel_request_pending = false
	m_cancel_request_consumed = true
	return true


func was_cancel_consumed() -> bool:
	return m_cancel_request_consumed


func clear_cancel_request() -> void:
	m_cancel_request_pending = false
	m_cancel_request_consumed = false


func _expire_cancel_request() -> void:
	if m_cancel_request_frame == Engine.get_process_frames():
		return
	m_cancel_request_pending = false
	m_cancel_request_consumed = false


func _resolve_movement_direction(input_vector: Vector2) -> Vector3:
	if input_vector.is_zero_approx():
		return Vector3.ZERO
	if camera_relative_movement:
		return _resolve_camera_relative_direction(input_vector)
	return Vector3(input_vector.x, 0.0, input_vector.y).normalized()


func _resolve_camera_relative_direction(input_vector: Vector2) -> Vector3:
	var camera := _resolve_camera()
	if !is_instance_valid(camera):
		return Vector3(input_vector.x, 0.0, input_vector.y).normalized()

	var right := camera.global_transform.basis.x
	var forward := -camera.global_transform.basis.z
	right.y = 0.0
	forward.y = 0.0
	if right.length_squared() <= 0.000001 or forward.length_squared() <= 0.000001:
		return Vector3(input_vector.x, 0.0, input_vector.y).normalized()

	right = right.normalized()
	forward = forward.normalized()
	return (right * input_vector.x - forward * input_vector.y).normalized()


func _resolve_camera() -> Camera3D:
	if !is_instance_valid(m_character):
		return null
	if !camera_path.is_empty():
		var explicit_camera := m_character.get_node_or_null(camera_path) as Camera3D
		if explicit_camera != null:
			return explicit_camera
	var viewport := m_character.get_viewport()
	if viewport == null:
		return null
	return viewport.get_camera_3d()
