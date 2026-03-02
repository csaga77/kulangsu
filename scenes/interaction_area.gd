class_name InteractionArea
extends Area2D

@export var speech_balloon_scene: PackedScene
@export var anchor_path: NodePath = ^".."
@export var follow_offset: Vector2 = Vector2(0, -48)

var m_anchor: Node2D = null
var m_npc: Node2D = null
var m_balloon: Node2D = null

func _ready() -> void:
	m_anchor = get_node_or_null(anchor_path) as Node2D

func _process(_delta: float) -> void:
	if m_npc == null or !is_instance_valid(m_npc):
		_destroy_balloon()
		return

	if !_is_closest_to_player():
		_destroy_balloon()
		return

	_ensure_balloon()
	_update_balloon_position()

func _on_body_entered(body: Node2D) -> void:
	if body == null:
		return
	m_npc = body

func _on_body_exited(body: Node2D) -> void:
	if body == null or body != m_npc:
		return
	m_npc = null
	_destroy_balloon()

# -------------------------------------------------

func _is_closest_to_player() -> bool:
	if m_npc == null:
		return false

	return true

func _ensure_balloon() -> void:
	if m_balloon != null and is_instance_valid(m_balloon):
		return

	if speech_balloon_scene == null:
		return

	m_balloon = speech_balloon_scene.instantiate() as Node2D
	get_tree().current_scene.add_child(m_balloon)
	m_balloon.top_level = true

func _update_balloon_position() -> void:
	if m_balloon == null or m_npc == null:
		return

	m_balloon.global_position = m_npc.global_position + follow_offset

func _destroy_balloon() -> void:
	if m_balloon != null and is_instance_valid(m_balloon):
		var tween = AnimationUtils.tween_node2d_visibility(m_balloon, false, 1.0)
		tween.finished.connect(m_balloon.queue_free)
	m_balloon = null
