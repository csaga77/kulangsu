class_name CharacterActionController3D
extends Resource

## Story-free sustained-action lifecycle for HumanBody3D.
##
## This controller never discovers or ranks targets. A world coordinator selects a
## target, checks feature-specific constraints, and asks this controller to reserve
## one typed posture. Feature targets may expose optional begin/cancel/complete
## hooks, but save-relevant meaning remains outside this class.

enum ActionMode {
	FREE,
	CARRY,
	PUSH,
	PULL,
	SIT,
}

signal action_mode_changed(mode: ActionMode)
signal action_started(mode: ActionMode, target: Object)
signal action_cancelled(mode: ActionMode, target: Object)
signal action_completed(mode: ActionMode, target: Object)

var m_actor: Node3D = null
var m_action_mode: ActionMode = ActionMode.FREE
var m_active_target: Object = null


func setup(actor: Node3D) -> void:
	if m_actor == actor:
		return
	cleanup()
	m_actor = actor


func teardown() -> void:
	cleanup()
	m_actor = null


func get_action_mode() -> ActionMode:
	return m_action_mode


func is_free() -> bool:
	return m_action_mode == ActionMode.FREE


func get_active_target() -> Object:
	return m_active_target


func can_begin_action(mode: ActionMode) -> bool:
	if mode == ActionMode.FREE or !is_free() or !is_instance_valid(m_actor):
		return false
	if m_actor.has_method("is_grounded") and !bool(m_actor.call("is_grounded")):
		return false
	if m_actor.has_method("is_free_locomotion") and !bool(
		m_actor.call("is_free_locomotion")
	):
		return false
	return true


func begin_action(
	mode: ActionMode,
	target: Object = null,
	invoke_target_hook := true
) -> bool:
	if !can_begin_action(mode):
		return false
	m_action_mode = mode
	m_active_target = target
	if invoke_target_hook:
		_call_target_hook(&"begin_action")
	action_mode_changed.emit(m_action_mode)
	action_started.emit(m_action_mode, m_active_target)
	return true


func cancel_active_action(invoke_target_hook := true) -> bool:
	if is_free():
		return false
	var previous_mode := m_action_mode
	var previous_target := m_active_target
	_clear_active_action()
	if invoke_target_hook:
		_call_hook_on_target(previous_target, &"cancel_action")
	action_cancelled.emit(previous_mode, previous_target)
	return true


func complete_active_action(invoke_target_hook := true) -> bool:
	if is_free():
		return false
	var previous_mode := m_action_mode
	var previous_target := m_active_target
	_clear_active_action()
	if invoke_target_hook:
		_call_hook_on_target(previous_target, &"complete_action")
	action_completed.emit(previous_mode, previous_target)
	return true


func cleanup() -> void:
	if !is_free():
		cancel_active_action()
	else:
		m_active_target = null


func _clear_active_action() -> void:
	m_action_mode = ActionMode.FREE
	m_active_target = null
	action_mode_changed.emit(m_action_mode)


func _call_target_hook(method_name: StringName) -> void:
	_call_hook_on_target(m_active_target, method_name)


func _call_hook_on_target(target: Object, method_name: StringName) -> void:
	if !is_instance_valid(target) or !target.has_method(method_name):
		return
	target.call(method_name, m_actor)
