@tool
class_name PlayerController
extends BaseController

signal inspect_requested

func _process(delta: float) -> void:
	super._process(delta)

	if m_character == null or !is_instance_valid(m_character):
		return

	var new_direction_vector: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if new_direction_vector.is_zero_approx():
		m_character.is_walking = false
		m_character.velocity = Vector2.ZERO
	else:
		m_character.direction = rad_to_deg(-new_direction_vector.angle())
		m_character.is_walking = true
		m_character.is_running = !Input.is_action_pressed("ui_walk")
		m_character.move(new_direction_vector)

	if Input.is_action_just_pressed("ui_jump"):
		m_character.jump()

	if Input.is_action_just_pressed("ui_inspect"):
		inspect_requested.emit()
		inspect()
