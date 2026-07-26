class_name CharacterActionTarget3D
extends Node3D

## Reusable authored target contract for contextual physical actions. Targets own
## only local transforms, availability, and lifecycle; story state is published
## through semantic_completion_requested and handled by the production world.

signal action_started(actor: CharacterBody3D)
signal action_finished(actor: CharacterBody3D, reason: StringName)
signal semantic_completion_requested(event_id: StringName, context: Dictionary)

const ACTION_TARGET_GROUP := &"character_action_target_3d"

@export var action_id: StringName = &""
@export var action_label := "Interact"
@export_range(-100, 100, 1) var action_priority := 0
@export_range(0.1, 10.0, 0.05) var interaction_range := 1.5
@export_range(0.0, 5.0, 0.05) var max_vertical_delta := 1.0
@export_range(0.0, 180.0, 0.5) var facing_tolerance_degrees := 60.0
@export var action_anchor_path: NodePath
@export var action_enabled := true
@export var sustained_action := false
@export var semantic_completion_id: StringName = &""

var m_reserved_actor: CharacterBody3D = null


func _enter_tree() -> void:
	add_to_group(ACTION_TARGET_GROUP)


func _exit_tree() -> void:
	if is_instance_valid(m_reserved_actor):
		cancel_action(m_reserved_actor, &"scene_unload")
	remove_from_group(ACTION_TARGET_GROUP)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED and is_instance_valid(m_reserved_actor):
		cancel_action(m_reserved_actor, &"pause")


func get_action_id() -> StringName:
	return action_id


func get_action_label() -> String:
	return action_label.strip_edges()


func get_action_priority() -> int:
	return action_priority


func get_action_anchor() -> Node3D:
	if !action_anchor_path.is_empty():
		var authored_anchor := get_node_or_null(action_anchor_path) as Node3D
		if is_instance_valid(authored_anchor):
			return authored_anchor
	return self


func get_action_anchor_transform(_actor: CharacterBody3D = null) -> Transform3D:
	var anchor := get_action_anchor()
	return anchor.global_transform if is_instance_valid(anchor) else global_transform


func get_action_distance(actor: CharacterBody3D) -> float:
	if !is_instance_valid(actor):
		return INF
	var delta := get_action_anchor_transform(actor).origin - actor.global_position
	delta.y = 0.0
	return delta.length()


func get_vertical_delta(actor: CharacterBody3D) -> float:
	if !is_instance_valid(actor):
		return INF
	return absf(get_action_anchor_transform(actor).origin.y - actor.global_position.y)


func get_facing_alignment(actor: CharacterBody3D) -> float:
	if !is_instance_valid(actor):
		return -1.0
	var to_anchor := get_action_anchor_transform(actor).origin - actor.global_position
	to_anchor.y = 0.0
	if to_anchor.length_squared() <= 0.000001:
		return 1.0
	to_anchor = to_anchor.normalized()
	return clampf(_resolve_actor_forward(actor).dot(to_anchor), -1.0, 1.0)


func is_within_facing_gate(actor: CharacterBody3D) -> bool:
	if facing_tolerance_degrees >= 180.0:
		return true
	return get_facing_alignment(actor) >= cos(deg_to_rad(facing_tolerance_degrees))


func is_action_available(actor: CharacterBody3D) -> bool:
	if !action_enabled or !is_instance_valid(actor):
		return false
	if is_instance_valid(m_reserved_actor) and m_reserved_actor != actor:
		return false
	if get_action_distance(actor) > interaction_range:
		return false
	if get_vertical_delta(actor) > max_vertical_delta:
		return false
	if !is_within_facing_gate(actor):
		return false
	return _actor_is_free(actor) or m_reserved_actor == actor


func begin_action(actor: CharacterBody3D) -> bool:
	if !is_action_available(actor):
		return false
	m_reserved_actor = actor
	action_started.emit(actor)
	return true


func cancel_action(actor: CharacterBody3D, reason: StringName = &"cancel") -> void:
	if !is_instance_valid(m_reserved_actor) or actor != m_reserved_actor:
		return
	var released_actor := m_reserved_actor
	m_reserved_actor = null
	action_finished.emit(released_actor, reason)


func complete_action(actor: CharacterBody3D, context: Dictionary = {}) -> void:
	if !is_instance_valid(m_reserved_actor) or actor != m_reserved_actor:
		return
	var released_actor := m_reserved_actor
	if !semantic_completion_id.is_empty():
		var completion_context := context.duplicate(true)
		completion_context["action_id"] = String(action_id)
		semantic_completion_requested.emit(semantic_completion_id, completion_context)
	m_reserved_actor = null
	action_finished.emit(released_actor, &"complete")


func has_reserved_actor() -> bool:
	return is_instance_valid(m_reserved_actor)


func get_reserved_actor() -> CharacterBody3D:
	return m_reserved_actor


func get_active_hint() -> String:
	return "Esc Cancel"


func _actor_is_free(actor: CharacterBody3D) -> bool:
	if actor.has_method("is_action_free") and !bool(actor.call("is_action_free")):
		return false
	if actor.has_method("is_free_locomotion"):
		return bool(actor.call("is_free_locomotion"))
	if actor.has_method("is_recovering") and bool(actor.call("is_recovering")):
		return false
	if actor.has_method("is_on_ladder") and bool(actor.call("is_on_ladder")):
		return false
	return true


func _resolve_actor_forward(actor: CharacterBody3D) -> Vector3:
	if actor.has_method("get_direction_vector"):
		var direction_value: Variant = actor.call("get_direction_vector")
		if direction_value is Vector3:
			var authored_direction := direction_value as Vector3
			authored_direction.y = 0.0
			if authored_direction.length_squared() > 0.000001:
				return authored_direction.normalized()
	var fallback := actor.global_basis.z
	fallback.y = 0.0
	if fallback.length_squared() <= 0.000001:
		return Vector3.FORWARD
	return fallback.normalized()
