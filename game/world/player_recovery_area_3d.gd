class_name PlayerRecoveryArea3D
extends Area3D

## Stateless authored recovery trigger. HumanBody3D owns safe-transform state;
## this area only identifies the configured player, cancels any world action, and
## requests recovery to its authored fallback without touching story state.

signal recovery_triggered(recovery_transform: Transform3D)

const RECOVERY_VOLUME_GROUP := &"player_recovery_volume_3d"

@export var safe_anchor_path: NodePath
@export_range(0.0, 20.0, 0.1) var drop_threshold_m := 4.0

var m_actor: CharacterBody3D = null
var m_action_coordinator: WorldActionCoordinator3D = null


func _enter_tree() -> void:
	add_to_group(RECOVERY_VOLUME_GROUP)


func _ready() -> void:
	if safe_anchor_path.is_empty() and has_meta("safe_anchor_path"):
		safe_anchor_path = NodePath(String(get_meta("safe_anchor_path")))
	if has_meta("drop_threshold_m"):
		drop_threshold_m = float(get_meta("drop_threshold_m"))
	if !body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _exit_tree() -> void:
	if body_entered.is_connected(_on_body_entered):
		body_entered.disconnect(_on_body_entered)
	remove_from_group(RECOVERY_VOLUME_GROUP)


func configure(
	actor: CharacterBody3D,
	action_coordinator: WorldActionCoordinator3D
) -> void:
	m_actor = actor
	m_action_coordinator = action_coordinator


func recover_actor() -> bool:
	if !is_instance_valid(m_actor):
		return false
	var recovery_transform := _resolve_recovery_transform()
	if is_instance_valid(m_action_coordinator):
		m_action_coordinator.cancel_active_action(&"recovery")
	if !safe_anchor_path.is_empty() and _has_valid_safe_anchor():
		if m_actor.has_method("recover_to_transform"):
			m_actor.call("recover_to_transform", recovery_transform)
		else:
			m_actor.global_transform = recovery_transform
	elif m_actor.has_method("recover_to_safe_transform"):
		m_actor.call("recover_to_safe_transform")
		recovery_transform = m_actor.global_transform
	else:
		return false
	recovery_triggered.emit(recovery_transform)
	return true


func _on_body_entered(body: Node3D) -> void:
	if body == m_actor:
		recover_actor()


func _resolve_recovery_transform() -> Transform3D:
	var anchor := _get_safe_anchor()
	if is_instance_valid(anchor):
		return anchor.global_transform
	if is_instance_valid(m_actor) and m_actor.has_method("get_safe_transform"):
		var transform_value: Variant = m_actor.call("get_safe_transform")
		if transform_value is Transform3D:
			return transform_value as Transform3D
	return m_actor.global_transform if is_instance_valid(m_actor) else Transform3D.IDENTITY


func _has_valid_safe_anchor() -> bool:
	return is_instance_valid(_get_safe_anchor())


func _get_safe_anchor() -> Node3D:
	if safe_anchor_path.is_empty():
		return null
	return get_node_or_null(safe_anchor_path) as Node3D
