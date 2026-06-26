@tool
class_name BaseController3D
extends Resource

enum MoveDirectionEnum {
	MOVE_IDLE = 0,
	MOVE_FORWARD   = 1 << 0,
	MOVE_BACKWARD  = 1 << 1,
	MOVE_LEFTWARD  = 1 << 2,
	MOVE_RIGHTWARD = 1 << 3
}

var move_direction: int = MoveDirectionEnum.MOVE_IDLE
var m_character: Node3D = null


func is_in_flock() -> bool:
	return false


func is_flock_lead() -> bool:
	return false


func get_global_position() -> Vector3:
	if !is_instance_valid(m_character):
		return Vector3.ZERO
	return m_character.global_position


func get_direction_vector() -> Vector3:
	if !is_instance_valid(m_character):
		return Vector3.ZERO
	if !m_character.has_method("get_direction_vector"):
		return Vector3.ZERO
	return m_character.call("get_direction_vector")


func set_target_direction(dir: Vector3) -> void:
	if is_instance_valid(m_character) and m_character.has_method("set_direction_vector"):
		m_character.call("set_direction_vector", dir)


func get_linear_velocity() -> Vector3:
	if !is_instance_valid(m_character):
		return Vector3.ZERO
	var character_velocity: Variant = m_character.get("velocity")
	if character_velocity is Vector3:
		return character_velocity
	return Vector3.ZERO


func set_running(is_running: bool) -> void:
	if is_instance_valid(m_character):
		m_character.set("is_running", is_running)


func move_forward() -> void:
	move_direction &= (0xFFFFFFFF ^ MoveDirectionEnum.MOVE_BACKWARD)
	move_direction |= MoveDirectionEnum.MOVE_FORWARD


func move_backward() -> void:
	move_direction &= (0xFFFFFFFF ^ MoveDirectionEnum.MOVE_FORWARD)
	move_direction |= MoveDirectionEnum.MOVE_BACKWARD


func move_leftward() -> void:
	move_direction &= (0xFFFFFFFF ^ MoveDirectionEnum.MOVE_RIGHTWARD)
	move_direction |= MoveDirectionEnum.MOVE_LEFTWARD


func move_rightward() -> void:
	move_direction &= (0xFFFFFFFF ^ MoveDirectionEnum.MOVE_LEFTWARD)
	move_direction |= MoveDirectionEnum.MOVE_RIGHTWARD


func stop_moving() -> void:
	move_direction = MoveDirectionEnum.MOVE_IDLE
	if is_instance_valid(m_character):
		m_character.set("is_walking", false)
		# Zero horizontal velocity but keep the vertical component so the body keeps
		# falling under gravity (and settling onto the floor) while it has no movement
		# input, instead of freezing in mid-air.
		var current_velocity: Variant = m_character.get("velocity")
		if current_velocity is Vector3:
			m_character.set("velocity", Vector3(0.0, (current_velocity as Vector3).y, 0.0))
		else:
			m_character.set("velocity", Vector3.ZERO)


func is_moving() -> bool:
	return move_direction != MoveDirectionEnum.MOVE_IDLE


func setup(character: Node3D) -> void:
	if m_character == character:
		return

	teardown()

	m_character = character
	_on_setup()


func _on_setup() -> void:
	pass


func get_time_stamp() -> float:
	return Time.get_ticks_msec() / 1000.0


func teardown() -> void:
	stop_moving()
	m_character = null


func process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_process(delta)


func _process(_delta: float) -> void:
	if is_instance_valid(m_character):
		m_character.set("is_walking", is_moving())

		if move_direction & MoveDirectionEnum.MOVE_FORWARD and m_character.has_method("move"):
			m_character.call("move", get_direction_vector())


func inspect() -> void:
	print("PlayerController3D inspect requested")
