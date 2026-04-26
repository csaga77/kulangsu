@tool
extends VBoxContainer
## Inspector-side prerequisite picker for [StorylineEventResource].
##
## Replaces raw string-array editing for `story_flags_all` / `story_flags_any`
## with the same route-rooted event tree used by the storyline browser.

const _ROUTE_COLORS := {
	"family_memory":            Color(0.95, 0.63, 0.12),
	"study_future":             Color(0.29, 0.57, 0.86),
	"preservation_inheritance": Color(0.38, 0.76, 0.26),
	"melody_landmarks":         Color(0.61, 0.34, 0.76),
}
const _DEFAULT_ROUTE_COLOR := Color(0.55, 0.55, 0.55)
const _BUCKETS := [
	{
		"name": "story_flags_all",
		"title": "All Prerequisites",
		"hint": "Every selected event must be resolved.",
	},
	{
		"name": "story_flags_any",
		"title": "Any Prerequisites",
		"hint": "At least one selected event must be resolved.",
	},
]

var m_event_resource: StorylineEventResource
var m_bucket_lists: Dictionary = {}
var m_picker_dialog: ConfirmationDialog
var m_picker_tree: Tree
var m_picker_bucket: String = ""
var m_route_defs: Dictionary = {}
var m_event_defs: Dictionary = {}
var m_on_prerequisites_changed: Callable
var m_layout_refresh_queued := false


func setup(
	event_resource: StorylineEventResource,
	on_prerequisites_changed: Callable = Callable()
) -> void:
	m_event_resource = event_resource
	m_on_prerequisites_changed = on_prerequisites_changed
	if is_node_ready():
		_build_ui()


func refresh() -> void:
	_load_catalog_data()
	_rebuild_all_bucket_rows()
	if m_picker_dialog != null and m_picker_dialog.visible:
		_rebuild_picker_tree()
	_queue_layout_refresh()


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

	var header := Label.new()
	header.text = "Prerequisite Events"
	header.mouse_filter = Control.MOUSE_FILTER_PASS
	header.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	add_child(header)

	for bucket in _BUCKETS:
		var bucket_name := String(bucket.get("name", ""))
		var section := VBoxContainer.new()
		section.mouse_filter = Control.MOUSE_FILTER_PASS
		section.add_theme_constant_override("separation", 4)
		add_child(section)

		var header_row := HBoxContainer.new()
		header_row.mouse_filter = Control.MOUSE_FILTER_PASS
		section.add_child(header_row)

		var title_lbl := Label.new()
		title_lbl.text = String(bucket.get("title", bucket_name))
		title_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header_row.add_child(title_lbl)

		var add_btn := Button.new()
		add_btn.text = "+ Add"
		add_btn.tooltip_text = String(bucket.get("hint", ""))
		add_btn.pressed.connect(_open_picker_for_bucket.bind(bucket_name))
		header_row.add_child(add_btn)

		var list_box := VBoxContainer.new()
		list_box.mouse_filter = Control.MOUSE_FILTER_PASS
		list_box.add_theme_constant_override("separation", 2)
		section.add_child(list_box)
		m_bucket_lists[bucket_name] = list_box

	_rebuild_all_bucket_rows()
	_build_picker_dialog()
	add_child(HSeparator.new())


func _build_picker_dialog() -> void:
	m_picker_dialog = ConfirmationDialog.new()
	m_picker_dialog.title = "Select Story Event"
	m_picker_dialog.ok_button_text = "Add"
	m_picker_dialog.min_size = Vector2i(420, 420)
	add_child(m_picker_dialog)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 4)
	m_picker_dialog.add_child(body)

	var hint_lbl := Label.new()
	hint_lbl.text = "Choose an event from the storyline tree."
	body.add_child(hint_lbl)

	m_picker_tree = Tree.new()
	m_picker_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_picker_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m_picker_tree.columns = 1
	m_picker_tree.hide_root = true
	m_picker_tree.set_column_title(0, "Route / Event")
	m_picker_tree.set_column_expand(0, true)
	m_picker_tree.column_titles_visible = true
	m_picker_tree.item_activated.connect(_on_picker_tree_item_activated)
	body.add_child(m_picker_tree)

	m_picker_dialog.confirmed.connect(_confirm_picker_selection)


func _open_picker_for_bucket(bucket_name: String) -> void:
	m_picker_bucket = bucket_name
	_load_catalog_data()
	_rebuild_picker_tree()
	m_picker_dialog.popup_centered_ratio(0.45)


func _load_catalog_data() -> void:
	m_route_defs = StorylineCatalog.build_route_definitions()
	m_event_defs = StorylineCatalog.build_event_definitions()


func _rebuild_picker_tree() -> void:
	m_picker_tree.clear()
	var root := m_picker_tree.create_item()
	var current_event_id := m_event_resource.id.strip_edges()

	for route_id: String in StorylineCatalog.route_display_order():
		var route_def: Dictionary = m_route_defs.get(route_id, {})
		if route_def.is_empty():
			continue

		var route_item := m_picker_tree.create_item(root)
		route_item.set_text(
			0,
			String(route_def.get("display_name", route_id))
		)
		route_item.set_custom_color(0, _ROUTE_COLORS.get(route_id, _DEFAULT_ROUTE_COLOR))
		route_item.set_metadata(0, {
			"kind": "route",
			"route_id": route_id,
		})

		for event_def: Dictionary in _events_for_route(route_id):
			var event_id := String(event_def.get("id", "")).strip_edges()
			if event_id.is_empty() or event_id == current_event_id:
				continue
			var event_item := m_picker_tree.create_item(route_item)
			event_item.set_text(0, event_id)
			event_item.set_tooltip_text(0, String(event_def.get("lead_text", "")))
			event_item.set_metadata(0, {
				"kind": "event",
				"event_id": event_id,
			})


func _events_for_route(route_id: String) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for event_id_var in m_event_defs.keys():
		var event_def: Dictionary = m_event_defs.get(event_id_var, {}) as Dictionary
		if String(event_def.get("route_id", "")) == route_id:
			events.append(event_def)
	return events


func _on_picker_tree_item_activated() -> void:
	_confirm_picker_selection()


func _confirm_picker_selection() -> void:
	var selected_event_id := _selected_picker_event_id()
	if selected_event_id.is_empty():
		return
	_add_prerequisite(selected_event_id, m_picker_bucket)
	m_picker_dialog.hide()


func _selected_picker_event_id() -> String:
	if m_picker_tree == null:
		return ""
	var selected_item := m_picker_tree.get_selected()
	if selected_item == null:
		return ""
	var metadata: Variant = selected_item.get_metadata(0)
	if not (metadata is Dictionary):
		return ""
	if String((metadata as Dictionary).get("kind", "")) != "event":
		return ""
	return String((metadata as Dictionary).get("event_id", "")).strip_edges()


func _add_prerequisite(event_id: String, bucket_name: String) -> void:
	if m_event_resource == null:
		return
	event_id = event_id.strip_edges()
	if event_id.is_empty():
		return

	var target_flags := _property_flags(bucket_name)
	if not target_flags.has(event_id):
		target_flags.append(event_id)
	_set_property_flags(bucket_name, target_flags)

	var other_bucket := _other_bucket_name(bucket_name)
	if not other_bucket.is_empty():
		var other_flags := _property_flags(other_bucket)
		var other_index := other_flags.find(event_id)
		if other_index >= 0:
			other_flags.remove_at(other_index)
			_set_property_flags(other_bucket, other_flags)

	_rebuild_all_bucket_rows()
	_notify_prerequisites_changed()


func _remove_prerequisite(event_id: String, bucket_name: String) -> void:
	var flags := _property_flags(bucket_name)
	var flag_index := flags.find(event_id)
	if flag_index < 0:
		return
	flags.remove_at(flag_index)
	_set_property_flags(bucket_name, flags)
	_rebuild_bucket_rows(bucket_name)
	_notify_prerequisites_changed()


func _rebuild_all_bucket_rows() -> void:
	for bucket in _BUCKETS:
		_rebuild_bucket_rows(String(bucket.get("name", "")))


func _rebuild_bucket_rows(bucket_name: String) -> void:
	var list_box := m_bucket_lists.get(bucket_name) as VBoxContainer
	if list_box == null:
		return
	for child: Node in list_box.get_children():
		list_box.remove_child(child)
		child.queue_free()

	var flags := _property_flags(bucket_name)
	if flags.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "(none)"
		empty_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		empty_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		list_box.add_child(empty_lbl)
		_queue_layout_refresh()
		return

	var known_event_ids: Dictionary = {}
	for event_id_var in StorylineCatalog.build_event_definitions().keys():
		known_event_ids[String(event_id_var)] = true

	for event_id: String in flags:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		list_box.add_child(row)

		var event_lbl := Label.new()
		event_lbl.text = event_id
		event_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		event_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if not known_event_ids.has(event_id):
			event_lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3))
			event_lbl.tooltip_text = "This prerequisite is not currently found in the storyline catalog."
		row.add_child(event_lbl)

		var remove_btn := Button.new()
		remove_btn.text = "Remove"
		remove_btn.flat = true
		remove_btn.pressed.connect(_remove_prerequisite.bind(event_id, bucket_name))
		row.add_child(remove_btn)
	_queue_layout_refresh()


func _property_flags(bucket_name: String) -> PackedStringArray:
	var result := PackedStringArray()
	if m_event_resource == null:
		return result
	var value: Variant = m_event_resource.get(bucket_name)
	if value is PackedStringArray:
		for event_id: String in value as PackedStringArray:
			var normalized := event_id.strip_edges()
			if not normalized.is_empty():
				result.append(normalized)
	elif value is Array:
		for event_id_var in value as Array:
			var normalized := String(event_id_var).strip_edges()
			if not normalized.is_empty():
				result.append(normalized)
	return result


func _set_property_flags(bucket_name: String, flags: PackedStringArray) -> void:
	if m_event_resource == null:
		return
	m_event_resource.set(bucket_name, flags)
	m_event_resource.emit_changed()


func _other_bucket_name(bucket_name: String) -> String:
	match bucket_name:
		"story_flags_all":
			return "story_flags_any"
		"story_flags_any":
			return "story_flags_all"
		_:
			return ""


func _notify_prerequisites_changed() -> void:
	if m_on_prerequisites_changed.is_valid():
		m_on_prerequisites_changed.call_deferred()


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
