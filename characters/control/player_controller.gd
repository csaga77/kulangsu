@tool
class_name PlayerController
extends BaseController

signal inspect_requested

func _process(delta: float) -> void:
	super._process(delta)

	if m_character == null or !is_instance_valid(m_character):
		return
	
	m_character.is_running = !Input.is_action_pressed("ui_walk")
	
	var new_direction_vector: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if new_direction_vector.is_zero_approx():
		stop_moving()
	else:
		set_target_direction(new_direction_vector)
		move_forward()

	if Input.is_action_just_pressed("ui_jump"):
		m_character.jump()

	if Input.is_action_just_pressed("ui_inspect"):
		inspect_requested.emit()
		inspect()
