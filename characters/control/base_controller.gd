@tool
class_name BaseController
extends Resource

enum MoveDirectionEnum {
	MOVE_IDLE = 0,
	MOVE_FORWARD   = 1 << 0,
	MOVE_BACKWARD  = 1 << 1,
	MOVE_LEFTWARD  = 1 << 2,
	MOVE_RIGHTWARD = 1 << 3
}

var move_direction: int = MoveDirectionEnum.MOVE_IDLE
var blackboard: BTBlackboard = BTBlackboard.new()

signal closest_object_changed(closest_object: Node2D)

@export var speech_balloon_scene: PackedScene = preload("res://gui/speech_balloon.tscn")
@export var follow_offset: Vector2 = Vector2(-8, -54)
@export var interaction_radius: float = 48.0:
	set(v):
		interaction_radius = max(v, 0.0)
		_update_collision_radius()

var m_character: HumanBody2D = null
var m_nearby_objects: Array[Node2D] = []
var m_closest_object: Node2D = null

var m_balloon: SpeechBalloon = null
var m_balloon_text: String = ""
var m_balloon_closed: bool = false

var m_area: Area2D = null
var m_collision_shape: CollisionShape2D = null
var m_circle_shape: CircleShape2D = null

func is_talking() -> bool:
	return is_instance_valid(m_balloon)

func is_in_flock() -> bool:
	return false

func is_flock_lead() -> bool:
	return false

func get_global_position() -> Vector2:
	if !is_instance_valid(m_character):
		return Vector2.ZERO
	return m_character.global_position

func get_direction_vector() -> Vector2:
	if !is_instance_valid(m_character):
		return Vector2.ZERO
	return m_character.get_direction_vector()

func set_target_direction(dir: Vector2) -> void:
	if is_instance_valid(m_character):
		m_character.set_direction_vector(dir)

func get_linear_velocity() -> Vector2:
	if !is_instance_valid(m_character):
		return Vector2.ZERO
	return m_character.velocity
	
func set_running(is_running: bool) -> void:
	if is_instance_valid(m_character):
		m_character.is_running = is_running

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
		m_character.is_walking = false

func is_moving() -> bool:
	return move_direction != MoveDirectionEnum.MOVE_IDLE

func setup(character: HumanBody2D) -> void:
	if m_character == character:
		return

	teardown()

	m_character = character
	_create_area_on_parent()
	
	_on_setup()
	
func _on_setup() -> void:
	pass

func get_time_stamp() -> float:
	return Time.get_ticks_msec() / 1000.0

func teardown() -> void:
	_destroy_balloon()

	if m_area != null and is_instance_valid(m_area):
		m_area.queue_free()

	m_area = null
	m_collision_shape = null
	m_circle_shape = null
	m_nearby_objects.clear()
	m_closest_object = null
	m_balloon_text = ""
	m_balloon_closed = false
	blackboard = BTBlackboard.new()
	m_character = null

func process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_process(delta)

func _process(_delta: float) -> void:
	if is_instance_valid(m_character):
		m_character.is_walking = is_moving()

		if move_direction & MoveDirectionEnum.MOVE_FORWARD:
			m_character.move(m_character.get_direction_vector())

	_cleanup_nearby_objects()

	var closest_object: Node2D = _get_closest_object()
	var object_changed := m_closest_object != closest_object

	if object_changed:
		m_closest_object = closest_object
		m_balloon_closed = false
		_on_closest_object_changed(m_closest_object)
		closest_object_changed.emit(m_closest_object)
		_update_balloon_content()

	if m_balloon != null and is_instance_valid(m_balloon):
		if !is_instance_valid(m_character):
			_destroy_balloon()
		else:
			_update_balloon_position()

func inspect() -> void:
	if m_closest_object == null or !is_instance_valid(m_closest_object):
		print("Invalid target!")
		return
	print(m_closest_object.name)

func speak(text: String) -> void:
	if text.is_empty():
		m_balloon_text = ""
		m_balloon_closed = true
		_destroy_balloon()
		return

	m_balloon_text = text
	m_balloon_closed = false

	if !is_instance_valid(m_character):
		return

	_ensure_balloon_instance()

	if m_balloon == null or !is_instance_valid(m_balloon):
		return

	m_balloon.text = text
	_update_balloon_position()

func _on_closest_object_changed(_obj: Node2D) -> void:
	pass

func _on_body_entered(body: Node2D) -> void:
	if !_is_valid_object(body):
		return

	if m_nearby_objects.has(body):
		return

	m_nearby_objects.append(body)

func _on_body_exited(body: Node2D) -> void:
	if body == null:
		return

	var index := m_nearby_objects.find(body)
	if index >= 0:
		m_nearby_objects.remove_at(index)

	if body == m_closest_object:
		m_closest_object = null
		_on_closest_object_changed(m_closest_object)
		closest_object_changed.emit(null)
		
	if _can_talk_to(body):
		m_balloon_closed = false
		_update_balloon_content()

func _create_area_on_parent() -> void:
	if m_character == null:
		push_warning("BaseController requires a HumanBody2D host")
		return

	if m_area != null and is_instance_valid(m_area):
		return

	m_area = Area2D.new()
	m_area.name = "InteractionArea2D"
	m_area.monitoring = true
	m_area.monitorable = true

	m_collision_shape = CollisionShape2D.new()

	m_circle_shape = CircleShape2D.new()
	m_circle_shape.radius = interaction_radius
	m_collision_shape.shape = m_circle_shape

	m_area.add_child(m_collision_shape)
	m_character.add_child(m_area)

	m_area.body_entered.connect(_on_body_entered)
	m_area.body_exited.connect(_on_body_exited)
	m_area.area_entered.connect(_on_body_entered)
	m_area.area_exited.connect(_on_body_exited)

func _update_collision_radius() -> void:
	if m_circle_shape == null:
		return
	m_circle_shape.radius = interaction_radius

func _is_valid_object(body: Node2D) -> bool:
	if body == null:
		return false

	if !is_instance_valid(body):
		return false

	var landmark_trigger := body as LandmarkTrigger
	if landmark_trigger != null and landmark_trigger.is_collected():
		return false

	if m_character != null and (body == m_character or CommonUtils.is_ancestor(body, m_character)):
		return false

	if !_shares_interaction_layer(body):
		return false

	return true

func _shares_interaction_layer(target_node: Node2D) -> bool:
	if !is_instance_valid(m_character):
		return false
	if !is_instance_valid(target_node):
		return false
	return CommonUtils.get_absolute_z_index(m_character) == CommonUtils.get_absolute_z_index(target_node)

func _cleanup_nearby_objects() -> void:
	var valid_objects: Array[Node2D] = []

	for object_node in m_nearby_objects:
		if _is_valid_object(object_node):
			valid_objects.append(object_node)

	m_nearby_objects = valid_objects

func _get_reference_position() -> Vector2:
	if is_instance_valid(m_character):
		return m_character.global_position

	return Vector2.ZERO

func _get_closest_object() -> Node2D:
	if m_nearby_objects.is_empty():
		return null

	var reference_position := _get_reference_position()
	var closest_object: Node2D = null
	var closest_priority := INF
	var closest_distance_sq := INF

	for object_node in m_nearby_objects:
		var interaction_priority := _get_interaction_priority(object_node)
		var distance_sq := reference_position.distance_squared_to(object_node.global_position)

		if interaction_priority < closest_priority:
			closest_priority = interaction_priority
			closest_distance_sq = distance_sq
			closest_object = object_node
			continue

		if interaction_priority == closest_priority and distance_sq < closest_distance_sq:
			closest_distance_sq = distance_sq
			closest_object = object_node

	return closest_object


func _get_interaction_priority(object_node: Node2D) -> int:
	if object_node == null or !is_instance_valid(object_node):
		return 100

	if object_node is HumanBody2D:
		return 0

	if object_node is LandmarkTrigger:
		return 2

	return 1

func _ensure_balloon_instance() -> void:
	if m_balloon != null and is_instance_valid(m_balloon):
		return

	if speech_balloon_scene == null:
		return

	if m_character == null or !is_instance_valid(m_character):
		return

	if m_character.get_tree() == null or m_character.get_tree().current_scene == null:
		return

	m_balloon = speech_balloon_scene.instantiate() as SpeechBalloon

	if m_balloon == null:
		return

	m_character.get_tree().current_scene.add_child(m_balloon)
	m_balloon.top_level = true

func _update_balloon_content() -> void:
	if m_balloon_closed:
		return
		
	var speech = ""

	for obj in m_nearby_objects:
		if !_can_talk_to(obj):
			continue
		speech = _get_speech(obj)
		break
	
	speak(speech)

func _can_talk_to(_target_node: Node2D) -> bool:
	return false

func _get_speech(_target_node: Node2D) -> String:
	return ""

func _update_balloon_position() -> void:
	if m_balloon == null or !is_instance_valid(m_balloon):
		return

	if !is_instance_valid(m_character):
		return

	m_balloon.global_position = m_character.global_position + follow_offset

func _destroy_balloon() -> void:
	m_balloon_text = ""

	if m_balloon != null and is_instance_valid(m_balloon):
		var balloon := m_balloon
		m_balloon = null

		var tween := AnimationUtils.tween_node2d_visibility(balloon, false, 1.0)
		tween.finished.connect(balloon.queue_free)
