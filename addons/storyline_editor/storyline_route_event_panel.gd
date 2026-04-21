@tool
extends VBoxContainer
## Inspector-side event list/editor helper for [StorylineRouteResource].
##
## Replaces raw event-array editing with explicit add, edit, reorder, and
## remove actions so new events can start with a unique default id.

var m_route_resource: StorylineRouteResource
var m_editor_interface: EditorInterface
var m_event_rows: VBoxContainer
var m_on_route_events_changed: Callable
var m_delete_event_dialog: ConfirmationDialog
var m_delete_event_message: Label
var m_pending_delete_event_index: int = -1
var m_pending_delete_event_id: String = ""


func setup(
	route_resource: StorylineRouteResource,
	editor_interface: EditorInterface = null,
	on_route_events_changed: Callable = Callable()
) -> void:
	m_route_resource = route_resource
	m_editor_interface = editor_interface
	m_on_route_events_changed = on_route_events_changed
	if is_node_ready():
		_build_ui()


func _ready() -> void:
	_build_ui()


func refresh() -> void:
	_rebuild_event_rows()


func _build_ui() -> void:
	if m_route_resource == null:
		return
	if get_child_count() > 0:
		return

	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 6)

	var header_row := HBoxContainer.new()
	add_child(header_row)

	var title_lbl := Label.new()
	title_lbl.text = "Route Events"
	title_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title_lbl)

	var add_btn := Button.new()
	add_btn.text = "+ Add Event"
	add_btn.tooltip_text = "Create a new story event with a unique default id."
	add_btn.pressed.connect(_on_add_event_pressed)
	header_row.add_child(add_btn)

	m_event_rows = VBoxContainer.new()
	m_event_rows.add_theme_constant_override("separation", 4)
	add_child(m_event_rows)

	_ensure_delete_event_dialog()
	_rebuild_event_rows()
	add_child(HSeparator.new())


func _on_add_event_pressed() -> void:
	if m_route_resource == null:
		return

	var new_event := m_route_resource.create_default_event_resource()
	var updated_events: Array[StorylineEventResource] = m_route_resource.events.duplicate()
	updated_events.append(new_event)
	m_route_resource.events = updated_events
	m_route_resource.emit_changed()
	_rebuild_event_rows()
	_notify_route_events_changed()

	if m_editor_interface != null:
		m_editor_interface.edit_resource(new_event)


func _on_edit_event_pressed(index: int) -> void:
	if m_editor_interface == null or m_route_resource == null:
		return
	if index < 0 or index >= m_route_resource.events.size():
		return
	var event_resource := m_route_resource.events[index]
	if event_resource != null:
		m_editor_interface.edit_resource(event_resource)


func _on_move_event_pressed(from_index: int, offset: int) -> void:
	if m_route_resource == null:
		return
	var to_index := from_index + offset
	if from_index < 0 or from_index >= m_route_resource.events.size():
		return
	if to_index < 0 or to_index >= m_route_resource.events.size():
		return

	var updated_events: Array[StorylineEventResource] = m_route_resource.events.duplicate()
	var moved_event := updated_events[from_index]
	updated_events[from_index] = updated_events[to_index]
	updated_events[to_index] = moved_event
	m_route_resource.events = updated_events
	m_route_resource.emit_changed()
	_rebuild_event_rows()
	_notify_route_events_changed()


func _on_remove_event_pressed(index: int) -> void:
	if m_route_resource == null:
		return
	if index < 0 or index >= m_route_resource.events.size():
		return

	m_pending_delete_event_index = index
	var pending_event := m_route_resource.events[index]
	m_pending_delete_event_id = ""
	if pending_event != null:
		m_pending_delete_event_id = pending_event.id.strip_edges()

	_ensure_delete_event_dialog()
	if m_delete_event_message != null:
		var event_name := (
			m_pending_delete_event_id
			if not m_pending_delete_event_id.is_empty()
			else "(unnamed event)"
		)
		m_delete_event_message.text = (
			"Delete story event '%s'? This cannot be undone." % event_name
		)
	if m_delete_event_dialog != null:
		m_delete_event_dialog.popup_centered()


func _confirm_delete_event() -> void:
	if m_route_resource == null:
		_reset_pending_delete_event()
		return

	var index := m_pending_delete_event_index
	if not m_pending_delete_event_id.is_empty():
		for event_index: int in m_route_resource.events.size():
			var event_resource := m_route_resource.events[event_index]
			if event_resource != null and event_resource.id.strip_edges() == m_pending_delete_event_id:
				index = event_index
				break
	if index < 0 or index >= m_route_resource.events.size():
		_reset_pending_delete_event()
		return

	var updated_events: Array[StorylineEventResource] = m_route_resource.events.duplicate()
	updated_events.remove_at(index)
	m_route_resource.events = updated_events
	m_route_resource.emit_changed()
	_rebuild_event_rows()
	_notify_route_events_changed()
	_reset_pending_delete_event()


func _rebuild_event_rows() -> void:
	if m_event_rows == null:
		return
	for child: Node in m_event_rows.get_children():
		m_event_rows.remove_child(child)
		child.queue_free()

	if m_route_resource == null or m_route_resource.events.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "(no events yet)"
		empty_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		m_event_rows.add_child(empty_lbl)
		return

	for index: int in m_route_resource.events.size():
		var event_resource := m_route_resource.events[index]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		m_event_rows.add_child(row)

		var event_lbl := Label.new()
		var event_id := ""
		if event_resource != null:
			event_id = event_resource.id.strip_edges()
		event_lbl.text = event_id if not event_id.is_empty() else "(unnamed event)"
		event_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(event_lbl)

		var edit_btn := Button.new()
		edit_btn.text = "Edit"
		edit_btn.flat = true
		edit_btn.disabled = event_resource == null or m_editor_interface == null
		edit_btn.pressed.connect(_on_edit_event_pressed.bind(index))
		row.add_child(edit_btn)

		var up_btn := Button.new()
		up_btn.text = "Up"
		up_btn.flat = true
		up_btn.disabled = index == 0
		up_btn.pressed.connect(_on_move_event_pressed.bind(index, -1))
		row.add_child(up_btn)

		var down_btn := Button.new()
		down_btn.text = "Down"
		down_btn.flat = true
		down_btn.disabled = index >= m_route_resource.events.size() - 1
		down_btn.pressed.connect(_on_move_event_pressed.bind(index, 1))
		row.add_child(down_btn)

		var remove_btn := Button.new()
		remove_btn.text = "Remove"
		remove_btn.flat = true
		remove_btn.pressed.connect(_on_remove_event_pressed.bind(index))
		row.add_child(remove_btn)


func _ensure_delete_event_dialog() -> void:
	if m_delete_event_dialog != null:
		return

	m_delete_event_dialog = ConfirmationDialog.new()
	m_delete_event_dialog.title = "Delete Story Event"
	m_delete_event_dialog.ok_button_text = "Delete"
	add_child(m_delete_event_dialog)

	m_delete_event_message = Label.new()
	m_delete_event_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m_delete_event_message.custom_minimum_size = Vector2(320.0, 0.0)
	m_delete_event_dialog.add_child(m_delete_event_message)

	m_delete_event_dialog.confirmed.connect(_confirm_delete_event)
	m_delete_event_dialog.canceled.connect(_reset_pending_delete_event)


func _reset_pending_delete_event() -> void:
	m_pending_delete_event_index = -1
	m_pending_delete_event_id = ""


func _notify_route_events_changed() -> void:
	if m_on_route_events_changed.is_valid():
		m_on_route_events_changed.call()
