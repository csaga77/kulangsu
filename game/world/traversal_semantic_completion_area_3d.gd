class_name TraversalSemanticCompletionArea3D
extends Area3D

## Emits a semantic result only after the configured actor has settled inside the
## authored landing volume. Story-mode eligibility and persistence remain owned by
## the production world and StoryEvent runtime.

signal semantic_completion_requested(event_id: StringName, context: Dictionary)

const COMPLETION_AREA_GROUP := &"traversal_semantic_completion_area_3d"

@export var semantic_completion_id: StringName = &""
@export var require_grounded := true
@export var require_airborne_entry := true
@export var one_shot_per_entry := true
@export_range(0.0, 1.0, 0.01) var settled_duration := 0.08

var m_actor: CharacterBody3D = null
var m_pending_bodies: Dictionary = {}
var m_completed_bodies: Dictionary = {}


func _enter_tree() -> void:
	add_to_group(COMPLETION_AREA_GROUP)


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	set_physics_process(true)


func _exit_tree() -> void:
	m_pending_bodies.clear()
	m_completed_bodies.clear()
	remove_from_group(COMPLETION_AREA_GROUP)


func configure_actor(actor: CharacterBody3D) -> void:
	m_actor = actor
	m_pending_bodies.clear()
	m_completed_bodies.clear()


func reset_completion() -> void:
	m_pending_bodies.clear()
	m_completed_bodies.clear()


func _physics_process(delta: float) -> void:
	for instance_id_value in m_pending_bodies.keys():
		var instance_id := int(instance_id_value)
		var body := instance_from_id(instance_id) as CharacterBody3D
		if !is_instance_valid(body):
			m_pending_bodies.erase(instance_id)
			m_completed_bodies.erase(instance_id)
			continue
		if require_grounded and !_actor_is_grounded(body):
			m_pending_bodies[instance_id] = 0.0
			continue
		var elapsed := float(m_pending_bodies.get(instance_id, 0.0)) + delta
		m_pending_bodies[instance_id] = elapsed
		if elapsed < settled_duration:
			continue
		_emit_completion(body)


func _on_body_entered(body: Node3D) -> void:
	var actor := body as CharacterBody3D
	if !is_instance_valid(actor):
		return
	if is_instance_valid(m_actor) and actor != m_actor:
		return
	if require_airborne_entry and !_actor_is_airborne(actor):
		return
	var instance_id := actor.get_instance_id()
	if one_shot_per_entry and m_completed_bodies.has(instance_id):
		return
	m_pending_bodies[instance_id] = 0.0


func _on_body_exited(body: Node3D) -> void:
	var actor := body as CharacterBody3D
	if !is_instance_valid(actor):
		return
	var instance_id := actor.get_instance_id()
	m_pending_bodies.erase(instance_id)
	if one_shot_per_entry:
		m_completed_bodies.erase(instance_id)


func _emit_completion(actor: CharacterBody3D) -> void:
	var instance_id := actor.get_instance_id()
	m_pending_bodies.erase(instance_id)
	m_completed_bodies[instance_id] = true
	if semantic_completion_id.is_empty():
		return
	semantic_completion_requested.emit(semantic_completion_id, {
		"completion_kind": "settled_landing",
		"world_position": actor.global_position,
	})


func _actor_is_grounded(actor: CharacterBody3D) -> bool:
	if actor.has_method("is_grounded"):
		return bool(actor.call("is_grounded"))
	if actor.has_method("is_airborne"):
		return !bool(actor.call("is_airborne"))
	return actor.is_on_floor()


func _actor_is_airborne(actor: CharacterBody3D) -> bool:
	if actor.has_method("is_airborne"):
		return bool(actor.call("is_airborne"))
	if actor.has_method("is_grounded"):
		return !bool(actor.call("is_grounded"))
	return !actor.is_on_floor()
