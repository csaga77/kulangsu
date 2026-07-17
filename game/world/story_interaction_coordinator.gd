class_name StoryInteractionCoordinator
extends Node

## Owns the active world-subject selection and the spatial adapter between the
## player controller and AppState's dimension-neutral story-subject API.

const STORY_SUBJECT_GROUP := &"story_subject_3d"

@export_range(0.0, 30.0, 0.1) var resident_talk_pause_seconds := 4.0

var m_world_root: Node3D = null
var m_actor: CharacterBody3D = null
var m_app_state: AppStateService = null
var m_subjects: Array[StorySubject3D] = []
var m_active_subject: StorySubject3D = null
var m_hint_dirty := true
var m_publishing_hint := false


func _ready() -> void:
	set_process(is_configured())


func configure(
	world_root: Node3D,
	actor: CharacterBody3D,
	app_state: AppStateService
) -> void:
	_disconnect_inspect()
	_disconnect_app_state()
	m_world_root = world_root
	m_actor = actor
	m_app_state = app_state
	_connect_app_state()
	refresh_subjects()
	_connect_inspect()
	set_process(is_configured())
	update_target()


func _exit_tree() -> void:
	_disconnect_inspect()
	_disconnect_app_state()


func _process(_delta: float) -> void:
	update_target()


func is_configured() -> bool:
	return (
		is_instance_valid(m_world_root)
		and is_instance_valid(m_actor)
		and is_instance_valid(m_app_state)
	)


func refresh_subjects() -> void:
	m_subjects.clear()
	if !is_instance_valid(m_world_root) or m_world_root.get_tree() == null:
		return
	for node in m_world_root.get_tree().get_nodes_in_group(STORY_SUBJECT_GROUP):
		var subject := node as StorySubject3D
		if subject == null or !m_world_root.is_ancestor_of(subject):
			continue
		m_subjects.append(subject)


func get_subjects() -> Array[StorySubject3D]:
	return m_subjects.duplicate()


func get_active_subject() -> StorySubject3D:
	return m_active_subject


func update_target() -> void:
	if !is_configured():
		m_active_subject = null
		return
	var next_subject := _resolve_closest_subject()
	if next_subject == m_active_subject and !m_hint_dirty:
		return
	m_active_subject = next_subject
	m_hint_dirty = false
	_update_hint_text(m_active_subject)


func build_story_interaction_request(subject: StorySubject3D) -> Dictionary:
	if !is_instance_valid(subject):
		return {}
	var subject_id := subject.get_story_subject_id()
	var action := subject.get_story_action()
	if subject_id.is_empty() or action.is_empty():
		return {}
	return {
		"subject_id": subject_id,
		"action": action,
		"display_name": subject.get_display_name(),
		"context": _build_story_subject_context(subject, subject.build_story_subject_context()),
	}


func _connect_inspect() -> void:
	var controller: Variant = m_actor.get("controller") if is_instance_valid(m_actor) else null
	if controller == null or !(controller is Object) or !controller.has_signal("inspect_requested"):
		return
	if !controller.is_connected("inspect_requested", _on_inspect_requested):
		controller.connect("inspect_requested", _on_inspect_requested)


func _disconnect_inspect() -> void:
	var controller: Variant = m_actor.get("controller") if is_instance_valid(m_actor) else null
	if controller == null or !(controller is Object) or !controller.has_signal("inspect_requested"):
		return
	if controller.is_connected("inspect_requested", _on_inspect_requested):
		controller.disconnect("inspect_requested", _on_inspect_requested)


func _connect_app_state() -> void:
	if !is_instance_valid(m_app_state):
		return
	if !m_app_state.state_committed.is_connected(_on_state_committed):
		m_app_state.state_committed.connect(_on_state_committed)
	m_hint_dirty = true


func _disconnect_app_state() -> void:
	if !is_instance_valid(m_app_state):
		return
	if m_app_state.state_committed.is_connected(_on_state_committed):
		m_app_state.state_committed.disconnect(_on_state_committed)


func _on_state_committed(_changes: AppStateChangeSet) -> void:
	if !m_publishing_hint:
		m_hint_dirty = true


func _resolve_closest_subject() -> StorySubject3D:
	var actor_flat := _flatten(m_actor.global_position)
	var best: StorySubject3D = null
	var best_distance := INF
	var best_priority := 2147483647
	for subject in m_subjects:
		if !is_instance_valid(subject) or !subject.is_targetable():
			continue
		var distance := actor_flat.distance_to(_flatten(subject.global_position))
		if distance > subject.interaction_radius:
			continue
		var priority := subject.get_interaction_priority()
		if priority < best_priority or (priority == best_priority and distance < best_distance):
			best = subject
			best_distance = distance
			best_priority = priority
	return best


func _on_inspect_requested() -> void:
	if !is_instance_valid(m_active_subject):
		m_app_state.update_world_context({"status": "Inspect: nothing nearby"})
		return

	var interaction_request := build_story_interaction_request(m_active_subject)
	if interaction_request.is_empty():
		m_app_state.update_world_context({
			"status": "Inspect: %s" % m_active_subject.get_display_name(),
		})
		return

	var interaction: Dictionary = m_app_state.activate_story_subject(
		String(interaction_request.get("subject_id", "")),
		String(interaction_request.get("action", "")),
		interaction_request.get("context", {})
	)

	var request_action := String(interaction_request.get("action", ""))
	var subject_display_name := String(interaction_request.get("display_name", ""))
	if request_action == "talk":
		var line := String(interaction.get("line", ""))
		if line.is_empty():
			line = "Talked with %s" % subject_display_name
		_show_resident_balloon(m_active_subject, line)
		_pause_and_face_resident(m_active_subject)
		m_app_state.update_world_context({"status": line})
	elif request_action == "inspect":
		m_app_state.update_world_context({
			"status": String(interaction.get("text", "Inspect: %s" % subject_display_name)),
		})

	_update_hint_text(m_active_subject)


func _build_story_subject_context(
	subject: StorySubject3D,
	extra_context: Dictionary = {}
) -> Dictionary:
	var context := extra_context.duplicate(true)
	context["location"] = m_app_state.get_projection().location
	if is_instance_valid(subject):
		context["display_name"] = context.get("display_name", subject.get_display_name())
		context["world_position"] = subject.global_position
		context["level_id"] = 0
	return context


func _update_hint_text(subject: StorySubject3D) -> void:
	if !is_instance_valid(subject):
		_publish_hint_action("R Inspect")
		return

	var interaction_request := build_story_interaction_request(subject)
	if interaction_request.is_empty():
		_publish_hint_action("R Inspect %s" % subject.get_display_name())
		return

	var action := String(interaction_request.get("action", ""))
	var display_name := String(interaction_request.get("display_name", ""))
	if action == "talk":
		_publish_hint_action("R Talk to %s" % display_name)
		return

	var description: Dictionary = m_app_state.describe_story_subject(
		String(interaction_request.get("subject_id", "")),
		action,
		interaction_request.get("context", {})
	)
	var prompt_text := String(description.get("prompt", "")).strip_edges()
	if prompt_text.is_empty():
		prompt_text = "%s %s" % [_interaction_verb_for_action(action), display_name]
	_publish_hint_action("R %s" % prompt_text)


func _publish_hint_action(action: String) -> void:
	m_publishing_hint = true
	m_app_state.update_world_context({"hint_action": action})
	m_publishing_hint = false


func _show_resident_balloon(subject: StorySubject3D, line: String) -> void:
	if !is_instance_valid(subject):
		return
	var resident := subject.get_parent()
	if resident == null:
		return
	var balloon := resident.get_node_or_null("Balloon3D")
	if balloon != null and balloon.has_method("show_line"):
		balloon.call("show_line", line)


func _pause_and_face_resident(subject: StorySubject3D) -> void:
	if !is_instance_valid(subject) or !is_instance_valid(m_actor):
		return
	var resident := subject.get_parent() as Node3D
	if !is_instance_valid(resident):
		return

	var to_player := m_actor.global_position - resident.global_position
	to_player.y = 0.0
	if to_player.length() > 0.01 and resident.has_method("set_direction_vector"):
		resident.call("set_direction_vector", to_player.normalized())

	var controller: Variant = resident.get("controller")
	if controller != null and controller is Object and controller.has_method("pause_for"):
		controller.call("pause_for", resident_talk_pause_seconds)


func _flatten(position: Vector3) -> Vector2:
	return Vector2(position.x, position.z)


func _interaction_verb_for_action(action: String) -> String:
	match action:
		"perform":
			return "Perform"
		"collect":
			return "Collect"
		"talk":
			return "Talk to"
		_:
			return "Inspect"
