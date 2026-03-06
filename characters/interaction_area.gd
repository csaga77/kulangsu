class_name InteractionArea
extends Area2D

enum BalloonFollowTargetEnum {
	NONE   = 0,
	ANCHOR = 1,
	TARGET = 2
}

@export var speech_balloon_scene: PackedScene
@export var anchor_path: NodePath = ^".."
@export var follow_offset: Vector2 = Vector2(-8, -54)
@export var balloon_follow_target: BalloonFollowTargetEnum = BalloonFollowTargetEnum.TARGET

func inspect() -> void:
	if m_closest_object == null or !is_instance_valid(m_closest_object):
		print("Invalid target!")
		return
	print(m_closest_object.name)

var m_anchor: Node2D = null
var m_nearby_objects: Array[Node2D] = []
var m_closest_object: Node2D = null
var m_balloon: SpeechBalloon = null

func _ready() -> void:
	m_anchor = get_node_or_null(anchor_path) as Node2D

func _process(_delta: float) -> void:
	_cleanup_nearby_npcs()

	var closest_npc: Node2D = _get_closest_npc()
	if closest_npc == null:
		m_closest_object = null
		_destroy_balloon()
		return

	var npc_changed: bool = m_closest_object != closest_npc
	m_closest_object = closest_npc

	_ensure_balloon()

	if m_balloon == null:
		return

	if npc_changed:
		_update_balloon_content()

	_update_balloon_position()

func _on_body_entered(body: Node2D) -> void:
	if !_is_valid_npc(body):
		return

	if m_nearby_objects.has(body):
		return

	m_nearby_objects.append(body)

func _on_body_exited(body: Node2D) -> void:
	if body == null:
		return

	var index: int = m_nearby_objects.find(body)
	if index >= 0:
		m_nearby_objects.remove_at(index)

	if body == m_closest_object:
		m_closest_object = null

# -------------------------------------------------

func _is_valid_npc(body: Node2D) -> bool:
	if body == null:
		return false
	if !is_instance_valid(body):
		return false
	if CommonUtils.is_ancestor(body, self):
		return false
	return true

func _cleanup_nearby_npcs() -> void:
	var valid_npcs: Array[Node2D] = []

	for npc in m_nearby_objects:
		if _is_valid_npc(npc):
			valid_npcs.append(npc)

	m_nearby_objects = valid_npcs

func _get_reference_position() -> Vector2:
	if m_anchor != null and is_instance_valid(m_anchor):
		return m_anchor.global_position
	return global_position

func _get_closest_npc() -> Node2D:
	if m_nearby_objects.is_empty():
		return null

	var reference_position: Vector2 = _get_reference_position()
	var closest_npc: Node2D = null
	var closest_distance_sq: float = INF

	for npc in m_nearby_objects:
		var distance_sq: float = reference_position.distance_squared_to(npc.global_position)
		if distance_sq < closest_distance_sq:
			closest_distance_sq = distance_sq
			closest_npc = npc

	return closest_npc

func _ensure_balloon() -> void:
	if balloon_follow_target == BalloonFollowTargetEnum.NONE:
		return
	if m_balloon != null and is_instance_valid(m_balloon):
		return

	if speech_balloon_scene == null:
		return

	m_balloon = speech_balloon_scene.instantiate() as SpeechBalloon
	if m_balloon == null:
		return

	get_tree().current_scene.add_child(m_balloon)
	m_balloon.top_level = true
	_update_balloon_content()
	_update_balloon_position()

func _update_balloon_content() -> void:
	if m_balloon == null or !is_instance_valid(m_balloon):
		return
	
	var speaker :Node2D
	if balloon_follow_target == BalloonFollowTargetEnum.ANCHOR:
		speaker = m_anchor
	elif balloon_follow_target == BalloonFollowTargetEnum.TARGET:
		speaker = m_closest_object
		
	if speaker == null or !is_instance_valid(speaker):
		return
	m_balloon.text = "{0}: ♪...".format([speaker.name])

func _get_balloon_follow_node() -> Node2D:
	match balloon_follow_target:
		BalloonFollowTargetEnum.ANCHOR:
			if m_anchor != null and is_instance_valid(m_anchor):
				return m_anchor
		BalloonFollowTargetEnum.TARGET:
			if m_closest_object != null and is_instance_valid(m_closest_object):
				return m_closest_object

	return null

func _update_balloon_position() -> void:
	if m_balloon == null or !is_instance_valid(m_balloon):
		return

	var follow_node: Node2D = _get_balloon_follow_node()
	if follow_node == null:
		return

	m_balloon.global_position = follow_node.global_position + follow_offset

func _destroy_balloon() -> void:
	if m_balloon != null and is_instance_valid(m_balloon):
		var balloon: SpeechBalloon = m_balloon
		m_balloon = null
		var tween = AnimationUtils.tween_node2d_visibility(balloon, false, 1.0)
		tween.finished.connect(balloon.queue_free)
