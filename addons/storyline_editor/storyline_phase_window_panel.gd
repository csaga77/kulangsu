@tool
extends VBoxContainer
## Inspector-side phase-window picker for [StorylineEventResource].
##
## Replaces raw array editing with a constrained season-phase picker that keeps
## duplicate selections out of the dropdowns and disables add once every
## authorable phase is already selected.

const _STORY_SEASON_PHASES_SCRIPT := preload("res://game/story_season_phases.gd")

var m_event_resource: StorylineEventResource
var m_phase_rows: VBoxContainer
var m_add_button: Button
var m_on_phase_window_changed: Callable
var m_layout_refresh_queued := false


func setup(
	event_resource: StorylineEventResource,
	on_phase_window_changed: Callable = Callable()
) -> void:
	m_event_resource = event_resource
	m_on_phase_window_changed = on_phase_window_changed
	if is_node_ready():
		_build_ui()


func refresh() -> void:
	_normalize_phase_window()
	_rebuild_phase_rows()


func _ready() -> void:
	_build_ui()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_queue_layout_refresh()


func _build_ui() -> void:
	if m_event_resource == null:
		return
	if get_child_count() > 0:
		return

	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 6)

	var header_row := HBoxContainer.new()
	header_row.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(header_row)

	var title_lbl := Label.new()
	title_lbl.text = "Phase Window"
	title_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	title_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title_lbl)

	m_add_button = Button.new()
	m_add_button.text = "+ Add Element"
	m_add_button.tooltip_text = "Add another allowed season phase."
	m_add_button.pressed.connect(_on_add_phase_pressed)
	header_row.add_child(m_add_button)

	m_phase_rows = VBoxContainer.new()
	m_phase_rows.mouse_filter = Control.MOUSE_FILTER_PASS
	m_phase_rows.add_theme_constant_override("separation", 4)
	add_child(m_phase_rows)

	_normalize_phase_window()
	_rebuild_phase_rows()
	add_child(HSeparator.new())


func _rebuild_phase_rows() -> void:
	if m_phase_rows == null:
		return
	for child: Node in m_phase_rows.get_children():
		m_phase_rows.remove_child(child)
		child.queue_free()

	if m_event_resource == null:
		return

	var phase_window := m_event_resource.phase_window
	if phase_window.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "(none)"
		empty_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		empty_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		m_phase_rows.add_child(empty_lbl)
		_refresh_add_button()
		_queue_layout_refresh()
		return

	for index: int in phase_window.size():
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_theme_constant_override("separation", 4)
		m_phase_rows.add_child(row)

		var phase_picker := OptionButton.new()
		phase_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		phase_picker.mouse_filter = Control.MOUSE_FILTER_PASS
		_populate_phase_picker(phase_picker, index)
		phase_picker.item_selected.connect(_on_phase_selected.bind(index, phase_picker))
		row.add_child(phase_picker)

		var remove_btn := Button.new()
		remove_btn.text = "Remove"
		remove_btn.flat = true
		remove_btn.pressed.connect(_on_remove_phase_pressed.bind(index))
		row.add_child(remove_btn)

	_refresh_add_button()
	_queue_layout_refresh()


func _populate_phase_picker(picker: OptionButton, index: int) -> void:
	picker.clear()
	if m_event_resource == null:
		return

	var current_phase := ""
	if index >= 0 and index < m_event_resource.phase_window.size():
		current_phase = String(m_event_resource.phase_window[index]).strip_edges()
	var available_phases := _available_phases_for_index(index)
	var selected_item := -1

	if not current_phase.is_empty() and not available_phases.has(current_phase):
		available_phases.append(current_phase)

	for phase_id: String in available_phases:
		picker.add_item(_phase_label(phase_id))
		var item_index := picker.item_count - 1
		picker.set_item_metadata(item_index, phase_id)
		if phase_id == current_phase:
			selected_item = item_index

	if selected_item < 0 and picker.item_count > 0:
		selected_item = 0
	if selected_item >= 0:
		picker.select(selected_item)


func _available_phases_for_index(index: int) -> Array[String]:
	var available_phases: Array[String] = []
	var selected_phases := _selected_phase_ids()
	var current_phase := ""
	if m_event_resource != null and index >= 0 and index < m_event_resource.phase_window.size():
		current_phase = String(m_event_resource.phase_window[index]).strip_edges()

	for phase_id: String in _STORY_SEASON_PHASES_SCRIPT.AUTHORABLE_PHASE_IDS:
		if phase_id == current_phase or not selected_phases.has(phase_id):
			available_phases.append(phase_id)
	return available_phases


func _selected_phase_ids() -> Dictionary:
	var selected_phases: Dictionary = {}
	if m_event_resource == null:
		return selected_phases
	for phase_id: String in m_event_resource.phase_window:
		var normalized_phase := phase_id.strip_edges()
		if normalized_phase.is_empty():
			continue
		selected_phases[normalized_phase] = true
	return selected_phases


func _on_add_phase_pressed() -> void:
	if m_event_resource == null:
		return

	var next_phase := _first_unselected_phase()
	if next_phase.is_empty():
		_refresh_add_button()
		return

	var updated_phase_window: Array[String] = m_event_resource.phase_window.duplicate()
	updated_phase_window.append(next_phase)
	m_event_resource.phase_window = updated_phase_window
	_notify_phase_window_changed()
	_rebuild_phase_rows()


func _on_remove_phase_pressed(index: int) -> void:
	if m_event_resource == null:
		return
	if index < 0 or index >= m_event_resource.phase_window.size():
		return

	var updated_phase_window: Array[String] = m_event_resource.phase_window.duplicate()
	updated_phase_window.remove_at(index)
	m_event_resource.phase_window = updated_phase_window
	_notify_phase_window_changed()
	_rebuild_phase_rows()


func _on_phase_selected(_item_index: int, phase_index: int, picker: OptionButton) -> void:
	if m_event_resource == null:
		return
	if phase_index < 0 or phase_index >= m_event_resource.phase_window.size():
		return

	var selected_id := _selected_picker_phase_id(picker)
	if selected_id.is_empty():
		return

	var updated_phase_window: Array[String] = m_event_resource.phase_window.duplicate()
	updated_phase_window[phase_index] = selected_id
	m_event_resource.phase_window = updated_phase_window
	_notify_phase_window_changed()
	_rebuild_phase_rows()


func _selected_picker_phase_id(picker: OptionButton) -> String:
	if picker == null:
		return ""
	var selected_index := picker.get_selected()
	if selected_index < 0:
		return ""
	return String(picker.get_item_metadata(selected_index)).strip_edges()


func _notify_phase_window_changed() -> void:
	if m_event_resource != null:
		m_event_resource.emit_changed()
	if m_on_phase_window_changed.is_valid():
		m_on_phase_window_changed.call()


func _normalize_phase_window() -> void:
	if m_event_resource == null:
		return
	if m_event_resource.normalize_phase_window():
		m_event_resource.emit_changed()


func _refresh_add_button() -> void:
	if m_add_button == null:
		return
	var has_available_phase := not _first_unselected_phase().is_empty()
	m_add_button.disabled = not has_available_phase
	if has_available_phase:
		m_add_button.tooltip_text = "Add another allowed season phase."
	else:
		m_add_button.tooltip_text = "Every season phase is already selected."


func _first_unselected_phase() -> String:
	var selected_phases := _selected_phase_ids()
	for phase_id: String in _STORY_SEASON_PHASES_SCRIPT.AUTHORABLE_PHASE_IDS:
		if not selected_phases.has(phase_id):
			return phase_id
	return ""


func _phase_label(phase_id: String) -> String:
	if _STORY_SEASON_PHASES_SCRIPT.is_authorable_phase(phase_id):
		return _STORY_SEASON_PHASES_SCRIPT.display_name(phase_id)
	return "%s (invalid)" % phase_id


func _queue_layout_refresh() -> void:
	if m_layout_refresh_queued:
		return
	m_layout_refresh_queued = true
	call_deferred("_refresh_layout_metrics")


func _refresh_layout_metrics() -> void:
	m_layout_refresh_queued = false
	if not is_inside_tree():
		return
	_refresh_control_tree_layout(self)
	var ancestor: Node = get_parent()
	while ancestor is Control:
		var ancestor_control := ancestor as Control
		if ancestor_control is Container:
			(ancestor_control as Container).queue_sort()
		ancestor_control.update_minimum_size()
		ancestor = ancestor_control.get_parent()


func _refresh_control_tree_layout(control: Control) -> void:
	if control is Container:
		(control as Container).queue_sort()
	control.update_minimum_size()
	for child: Node in control.get_children():
		var child_control := child as Control
		if child_control != null:
			_refresh_control_tree_layout(child_control)
