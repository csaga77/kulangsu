@tool
class_name StorySubject3D
extends Area3D

# 3D counterpart of StorySubjectArea2D.
#
# Phase E of docs/plan/low_poly_3d_replacement.md: the interaction contract that
# the whole cutover hinges on. A StorySubject3D exposes a stable `subject_id` and
# resolves its action, display name, and runtime presence from the SAME shared
# StoryEvent catalog / AppState metadata the 2D subject uses. It performs no story
# logic itself; the owning 3D world scene reads these fields, picks one active
# subject by proximity, and dispatches through AppState.activate_story_subject(...)
# exactly like scenes/game_main.gd does for StorySubjectArea2D.
#
# It deliberately does NOT reimplement the LevelArea2D multi-level system; 3D
# tunnels/levels are a later Phase E item. Until then level_id is reported as 0.

const APP_RUNTIME := preload("res://game/app_runtime.gd")
const STORY_EVENT_CATALOG := preload("res://game/story_event_catalog.gd")

@export var subject_id: String = "":
	set(value):
		var normalized := value.strip_edges()
		if subject_id == normalized:
			return
		subject_id = normalized
		update_configuration_warnings()
		if is_inside_tree() and !Engine.is_editor_hint():
			sync_story_presence()

@export var story_action: String = ""
@export var display_name: String = ""
# Selection range used by the owning world scene's proximity picker.
@export_range(0.5, 12.0, 0.1) var interaction_radius := 3.0

var m_story_state: Node = null


func _app_state():
	if !is_inside_tree():
		return null
	return APP_RUNTIME.get_app_state(self)


func _ready() -> void:
	if Engine.is_editor_hint():
		update_configuration_warnings()
		return
	# Binding to AppState can create the shared service node; defer until the scene
	# tree is no longer busy instantiating this scene so the add_child succeeds.
	call_deferred("_deferred_story_bind")


func _deferred_story_bind() -> void:
	if Engine.is_editor_hint() or !is_inside_tree():
		return
	_bind_story_state()
	sync_story_presence()


func _exit_tree() -> void:
	_unbind_story_state()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if subject_id.is_empty():
		warnings.append("Choose a subject_id.")
		return warnings
	if STORY_EVENT_CATALOG.get_subject_metadata(subject_id).is_empty():
		warnings.append("subject_id '%s' is not in the StoryEvent world-subject catalog." % subject_id)
	return warnings


func get_story_subject_id() -> String:
	return subject_id.strip_edges()


func get_story_action() -> String:
	var explicit_action := story_action.strip_edges().to_lower()
	if !explicit_action.is_empty():
		return explicit_action
	var runtime_action := String(_runtime_subject_metadata().get("action", "")).strip_edges().to_lower()
	if !runtime_action.is_empty():
		return runtime_action
	return String(_subject_metadata().get("default_action", "")).strip_edges().to_lower()


func get_display_name() -> String:
	var explicit_name := display_name.strip_edges()
	if !explicit_name.is_empty():
		return explicit_name
	var runtime_name := String(_runtime_subject_metadata().get("display_name", "")).strip_edges()
	if !runtime_name.is_empty():
		return runtime_name
	var metadata_name := String(_subject_metadata().get("display_name", "")).strip_edges()
	if !metadata_name.is_empty():
		return metadata_name
	return _fallback_display_name()


func get_interaction_priority() -> int:
	match get_story_action():
		"collect", "perform":
			return 0
		_:
			return 1


func is_targetable() -> bool:
	return monitorable and !get_story_subject_id().is_empty()


func build_story_subject_context() -> Dictionary:
	var context := _build_base_story_subject_context()
	var resolved_action := get_story_action()
	if !resolved_action.is_empty():
		context["action"] = resolved_action
	var resolved_display_name := get_display_name()
	if !resolved_display_name.is_empty():
		context["display_name"] = resolved_display_name
	return context


func sync_story_presence() -> void:
	if Engine.is_editor_hint():
		return

	var should_be_visible := !subject_id.is_empty()
	var should_be_targetable := should_be_visible
	var app_state = _app_state()
	if should_be_visible and app_state != null and app_state.has_method("describe_story_subject_metadata"):
		var metadata_value = app_state.call(
			"describe_story_subject_metadata",
			get_story_subject_id(),
			_build_base_story_subject_context()
		)
		if metadata_value is Dictionary and !(metadata_value as Dictionary).is_empty():
			var metadata: Dictionary = metadata_value
			should_be_visible = bool(metadata.get("visible", true))
			should_be_targetable = bool(metadata.get("targetable", should_be_visible))

	visible = should_be_visible
	set_deferred("monitoring", should_be_targetable)
	set_deferred("monitorable", should_be_targetable)


func _bind_story_state() -> void:
	var next_story_state = _app_state()
	if next_story_state == null:
		return
	m_story_state = next_story_state
	for signal_name in _story_state_signal_names():
		if !m_story_state.has_signal(signal_name):
			continue
		if !m_story_state.is_connected(signal_name, _on_story_state_changed):
			m_story_state.connect(signal_name, _on_story_state_changed)


func _unbind_story_state() -> void:
	if !is_instance_valid(m_story_state):
		m_story_state = null
		return
	for signal_name in _story_state_signal_names():
		if m_story_state.has_signal(signal_name) and m_story_state.is_connected(signal_name, _on_story_state_changed):
			m_story_state.disconnect(signal_name, _on_story_state_changed)
	m_story_state = null


func _subject_metadata() -> Dictionary:
	return STORY_EVENT_CATALOG.get_subject_metadata(get_story_subject_id())


func _runtime_subject_metadata() -> Dictionary:
	if Engine.is_editor_hint():
		return {}
	var normalized_subject_id := get_story_subject_id()
	if normalized_subject_id.is_empty():
		return {}
	var app_state = _app_state()
	if app_state == null or !app_state.has_method("describe_story_subject_metadata"):
		return {}
	var metadata_value = app_state.call(
		"describe_story_subject_metadata",
		normalized_subject_id,
		_build_base_story_subject_context()
	)
	if metadata_value is Dictionary:
		return (metadata_value as Dictionary).duplicate(true)
	return {}


func _story_state_signal_names() -> PackedStringArray:
	return PackedStringArray([
		"mode_changed",
		"chapter_changed",
		"story_time_changed",
		"landmark_progress_changed",
		"route_progress_changed",
		"story_milestone",
		"season_phase_changed",
		"active_leads_changed",
		"endgame_state_changed",
	])


func _build_base_story_subject_context() -> Dictionary:
	var context := {
		"subject_id": get_story_subject_id(),
		"world_position": global_position,
		"level_id": 0,
	}
	var explicit_action := story_action.strip_edges().to_lower()
	if !explicit_action.is_empty():
		context["action"] = explicit_action
	var explicit_name := display_name.strip_edges()
	if !explicit_name.is_empty():
		context["display_name"] = explicit_name
	return context


func _fallback_display_name() -> String:
	var normalized_subject := get_story_subject_id()
	if normalized_subject.is_empty():
		return "Inspect"
	var subject_tail := normalized_subject.get_slice(":", 1)
	if subject_tail.is_empty():
		subject_tail = normalized_subject
	subject_tail = subject_tail.get_slice(".", subject_tail.get_slice_count(".") - 1)
	return String(subject_tail).replace("_", " ").strip_edges().capitalize()


func _on_story_state_changed(_arg1 = null, _arg2 = null) -> void:
	sync_story_presence()
