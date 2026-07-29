class_name WorldActionCoordinator3D
extends Node

## Sole owner of contextual-action input and hint arbitration in the 3D world.
## Physical targets are ranked with story subjects, while story request building
## and AppState dispatch remain delegated to StoryInteractionCoordinator.

signal semantic_completion_requested(event_id: StringName, context: Dictionary)
signal physical_cancel_consumed(reason: StringName)

const ACTION_TARGET_GROUP := &"character_action_target_3d"

var m_world_root: Node3D = null
var m_actor: CharacterBody3D = null
var m_app_state: AppStateService = null
var m_story_coordinator: StoryInteractionCoordinator = null
var m_targets: Array[CharacterActionTarget3D] = []
var m_active_target: CharacterActionTarget3D = null
var m_selected_target: CharacterActionTarget3D = null
var m_selected_subject: StorySubject3D = null
var m_connected_action_signal: StringName = &""
var m_publishing_hint := false
var m_hint_dirty := true


func _ready() -> void:
	set_process(false)
	set_physics_process(is_configured())


func configure(
	world_root: Node3D,
	actor: CharacterBody3D,
	app_state: AppStateService,
	story_coordinator: StoryInteractionCoordinator
) -> void:
	_disconnect_controller()
	_disconnect_app_state()
	_disconnect_targets()
	m_world_root = world_root
	m_actor = actor
	m_app_state = app_state
	m_story_coordinator = story_coordinator
	refresh_targets()
	_connect_controller()
	_connect_app_state()
	set_process(false)
	set_physics_process(is_configured())


func _exit_tree() -> void:
	cancel_active_action(&"scene_unload")
	_disconnect_controller()
	_disconnect_app_state()
	_disconnect_targets()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		cancel_active_action(&"pause")


func _physics_process(_delta: float) -> void:
	update_selection()


func is_configured() -> bool:
	return (
		is_instance_valid(m_world_root)
		and is_instance_valid(m_actor)
		and is_instance_valid(m_app_state)
		and is_instance_valid(m_story_coordinator)
	)


func refresh_targets() -> void:
	_disconnect_targets()
	m_targets.clear()
	if !is_instance_valid(m_world_root) or m_world_root.get_tree() == null:
		return
	for node in m_world_root.get_tree().get_nodes_in_group(ACTION_TARGET_GROUP):
		var target := node as CharacterActionTarget3D
		if target == null or !m_world_root.is_ancestor_of(target):
			continue
		m_targets.append(target)
		_connect_target(target)
	if is_instance_valid(m_story_coordinator):
		m_story_coordinator.refresh_subjects()
	m_hint_dirty = true


func get_targets() -> Array[CharacterActionTarget3D]:
	return m_targets.duplicate()


func get_selected_target() -> CharacterActionTarget3D:
	return m_selected_target


func get_selected_story_subject() -> StorySubject3D:
	return m_selected_subject


func get_active_target() -> CharacterActionTarget3D:
	return m_active_target


func has_active_action() -> bool:
	return is_instance_valid(m_active_target)


func update_selection() -> void:
	if !is_configured():
		_set_selection(null, null)
		return
	if is_instance_valid(m_active_target):
		if m_hint_dirty:
			_publish_hint_action(m_active_target.get_active_hint())
			m_hint_dirty = false
		return

	var best_target: CharacterActionTarget3D = null
	var best_subject: StorySubject3D = null
	var best_priority := 2147483647
	var best_facing := -INF
	var best_distance := INF

	for target in m_targets:
		if !is_instance_valid(target) or !target.is_action_available(m_actor):
			continue
		var candidate_priority := target.get_action_priority()
		var candidate_facing := target.get_facing_alignment(m_actor)
		var candidate_distance := target.get_action_distance(m_actor)
		if _candidate_is_better(
			candidate_priority,
			candidate_facing,
			candidate_distance,
			best_priority,
			best_facing,
			best_distance
		):
			best_target = target
			best_subject = null
			best_priority = candidate_priority
			best_facing = candidate_facing
			best_distance = candidate_distance

	for subject in m_story_coordinator.get_subjects():
		if !is_instance_valid(subject) or !subject.is_targetable():
			continue
		var subject_distance := _flat_distance(m_actor.global_position, subject.global_position)
		if subject_distance > subject.interaction_radius:
			continue
		var subject_priority := subject.get_interaction_priority()
		var subject_facing := _facing_alignment_to(subject.global_position)
		if _candidate_is_better(
			subject_priority,
			subject_facing,
			subject_distance,
			best_priority,
			best_facing,
			best_distance
		):
			best_target = null
			best_subject = subject
			best_priority = subject_priority
			best_facing = subject_facing
			best_distance = subject_distance

	_set_selection(best_target, best_subject)


func request_context_action() -> bool:
	if is_instance_valid(m_active_target):
		if m_active_target.has_method("request_active_context_action"):
			return bool(
				m_active_target.call("request_active_context_action", m_actor)
			)
		return true
	if is_instance_valid(m_selected_target):
		if !m_selected_target.begin_action(m_actor):
			m_hint_dirty = true
			update_selection()
			return false
		if m_selected_target.sustained_action:
			m_active_target = m_selected_target
			m_hint_dirty = true
			update_selection()
		else:
			m_selected_target.complete_action(m_actor)
		return true
	if is_instance_valid(m_selected_subject):
		return m_story_coordinator.activate_subject(m_selected_subject)
	m_app_state.update_world_context({"status": "Inspect: nothing nearby"})
	return false


func cancel_active_action(reason: StringName = &"cancel") -> bool:
	if !is_instance_valid(m_active_target):
		return false
	var target := m_active_target
	m_active_target = null
	target.cancel_action(m_actor, reason)
	physical_cancel_consumed.emit(reason)
	m_hint_dirty = true
	update_selection()
	return true


func cancel_or_recover_actor(reason: StringName = &"cancel") -> bool:
	if cancel_active_action(reason):
		return true
	if !is_instance_valid(m_actor):
		return false
	if m_actor.has_method("is_airborne") and bool(m_actor.call("is_airborne")):
		if m_actor.has_method("recover_to_safe_transform"):
			m_actor.call("recover_to_safe_transform")
			physical_cancel_consumed.emit(reason)
			m_hint_dirty = true
			return true
	return false


func recover_active_action(recovery_transform: Transform3D) -> void:
	cancel_active_action(&"recovery")
	if !is_instance_valid(m_actor):
		return
	if m_actor.has_method("recover_to_transform"):
		m_actor.call("recover_to_transform", recovery_transform)
	else:
		m_actor.global_transform = recovery_transform


func _set_selection(
	target: CharacterActionTarget3D,
	subject: StorySubject3D
) -> void:
	if target == m_selected_target and subject == m_selected_subject and !m_hint_dirty:
		return
	m_selected_target = target
	m_selected_subject = subject
	m_hint_dirty = false
	if is_instance_valid(target):
		_publish_hint_action("R %s" % target.get_action_label())
	elif is_instance_valid(subject):
		_publish_hint_action(m_story_coordinator.describe_subject_hint(subject))
	else:
		_publish_hint_action("R Inspect")


func _connect_controller() -> void:
	var controller := _resolve_controller()
	if controller == null:
		return
	if controller.has_signal("context_action_requested"):
		m_connected_action_signal = &"context_action_requested"
	elif controller.has_signal("inspect_requested"):
		m_connected_action_signal = &"inspect_requested"
	if !m_connected_action_signal.is_empty() and !controller.is_connected(
		m_connected_action_signal,
		_on_context_action_requested
	):
		controller.connect(m_connected_action_signal, _on_context_action_requested)
	if controller.has_signal("cancel_requested") and !controller.is_connected(
		"cancel_requested",
		_on_cancel_requested
	):
		controller.connect("cancel_requested", _on_cancel_requested)


func _disconnect_controller() -> void:
	var controller := _resolve_controller()
	if controller == null:
		m_connected_action_signal = &""
		return
	if !m_connected_action_signal.is_empty() and controller.has_signal(
		m_connected_action_signal
	) and controller.is_connected(m_connected_action_signal, _on_context_action_requested):
		controller.disconnect(m_connected_action_signal, _on_context_action_requested)
	if controller.has_signal("cancel_requested") and controller.is_connected(
		"cancel_requested",
		_on_cancel_requested
	):
		controller.disconnect("cancel_requested", _on_cancel_requested)
	m_connected_action_signal = &""


func _resolve_controller() -> Object:
	if !is_instance_valid(m_actor):
		return null
	var controller_value: Variant = m_actor.get("controller")
	return controller_value as Object


func _connect_app_state() -> void:
	if !is_instance_valid(m_app_state):
		return
	if !m_app_state.state_committed.is_connected(_on_state_committed):
		m_app_state.state_committed.connect(_on_state_committed)


func _disconnect_app_state() -> void:
	if !is_instance_valid(m_app_state):
		return
	if m_app_state.state_committed.is_connected(_on_state_committed):
		m_app_state.state_committed.disconnect(_on_state_committed)


func _connect_target(target: CharacterActionTarget3D) -> void:
	if !target.action_finished.is_connected(_on_target_action_finished):
		target.action_finished.connect(_on_target_action_finished.bind(target))
	if !target.semantic_completion_requested.is_connected(_on_semantic_completion_requested):
		target.semantic_completion_requested.connect(_on_semantic_completion_requested)


func _disconnect_targets() -> void:
	for target in m_targets:
		if !is_instance_valid(target):
			continue
		var finished_callback := _on_target_action_finished.bind(target)
		if target.action_finished.is_connected(finished_callback):
			target.action_finished.disconnect(finished_callback)
		if target.semantic_completion_requested.is_connected(_on_semantic_completion_requested):
			target.semantic_completion_requested.disconnect(_on_semantic_completion_requested)


func _on_context_action_requested() -> void:
	request_context_action()


func _on_cancel_requested() -> void:
	if !cancel_or_recover_actor(&"cancel"):
		return
	var controller := _resolve_controller()
	if controller != null and controller.has_method("consume_cancel_request"):
		controller.call("consume_cancel_request")


func _on_target_action_finished(
	_actor: CharacterBody3D,
	reason: StringName,
	target: CharacterActionTarget3D
) -> void:
	if is_instance_valid(m_actor):
		if reason == &"complete" and m_actor.has_method(
			"complete_sustained_action"
		):
			m_actor.call("complete_sustained_action", target)
		elif m_actor.has_method("cancel_sustained_action"):
			m_actor.call("cancel_sustained_action", target)
	if target == m_active_target:
		m_active_target = null
	m_hint_dirty = true


func _on_semantic_completion_requested(
	event_id: StringName,
	context: Dictionary
) -> void:
	semantic_completion_requested.emit(event_id, context.duplicate(true))


func _on_state_committed(_changes: AppStateChangeSet) -> void:
	if !m_publishing_hint:
		m_hint_dirty = true


func _publish_hint_action(action: String) -> void:
	if !is_instance_valid(m_app_state):
		return
	m_publishing_hint = true
	m_app_state.update_world_context({"hint_action": action})
	m_publishing_hint = false


func _candidate_is_better(
	priority: int,
	facing: float,
	distance: float,
	best_priority: int,
	best_facing: float,
	best_distance: float
) -> bool:
	if priority != best_priority:
		return priority < best_priority
	if !is_equal_approx(facing, best_facing):
		return facing > best_facing
	return distance < best_distance


func _facing_alignment_to(position: Vector3) -> float:
	var to_position := position - m_actor.global_position
	to_position.y = 0.0
	if to_position.length_squared() <= 0.000001:
		return 1.0
	to_position = to_position.normalized()
	var actor_forward := m_actor.global_basis.z
	if m_actor.has_method("get_direction_vector"):
		var direction_value: Variant = m_actor.call("get_direction_vector")
		if direction_value is Vector3:
			actor_forward = direction_value as Vector3
	actor_forward.y = 0.0
	if actor_forward.length_squared() <= 0.000001:
		return 0.0
	return clampf(actor_forward.normalized().dot(to_position), -1.0, 1.0)


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
