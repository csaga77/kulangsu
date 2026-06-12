@tool
class_name PlayerController3D
extends "res://characters/control/base_controller_3d.gd"

signal inspect_requested

@export var camera_relative_movement := false
@export var camera_path: NodePath
@export var walk_action := "ui_walk"
@export var jump_action := "ui_jump"
@export var inspect_action := "ui_inspect"


func _process(delta: float) -> void:
	if m_character == null or !is_instance_valid(m_character):
		return

	set_running(!Input.is_action_pressed(walk_action))

	var input_vector := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var movement_direction := _resolve_movement_direction(input_vector)
	if movement_direction.is_zero_approx():
		stop_moving()
	else:
		set_target_direction(movement_direction)
		move_forward()

	if Input.is_action_just_pressed(jump_action) and m_character.has_method("jump"):
		m_character.call("jump")

	if Input.is_action_just_pressed(inspect_action):
		inspect_requested.emit()
		inspect()

	super._process(delta)


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
