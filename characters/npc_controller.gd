@tool
class_name NPCController
extends BaseController

var m_target: Node2D = null

func _on_closest_object_changed(obj: Node2D) -> void:
	super._on_closest_object_changed(obj)
	m_target = obj

func _process(delta: float) -> void:
	super._process(delta)

	if m_character == null or !is_instance_valid(m_character):
		return

	if m_target == null or !is_instance_valid(m_target):
		return

	var to_target: Vector2 = m_target.global_position - m_character.global_position
	if to_target.length_squared() < 0.001:
		return

	m_character.direction = rad_to_deg(-to_target.angle())
