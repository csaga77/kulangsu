@tool
extends VBoxContainer
## Editor dock that lists all known storyline routes and their events.
##
## Shows:
##   • One combined storyline tree with route root nodes
##   • Event rows nested under their owning route
##   • Project-wide validation warnings surfaced inline
##   • "Show in Graph" button to select the event in the graph editor
##
## Wire [signal event_show_in_graph_requested] in [StorylineEditorPlugin] to
## [method StorylineGraphEditor.select_event].

## Emitted when the user wants to highlight an event in the dependency graph.
signal event_show_in_graph_requested(event_id: String)
## Emitted when the user selects a route row and wants to edit the route in the Inspector.
signal route_inspector_requested(route_id: String)
## Emitted when the user selects an event row and wants to edit it in the Inspector.
signal event_inspector_requested(event_id: String)
## Emitted when the user confirms deleting an event row from the browser tree.
signal event_delete_requested(event_id: String)
## Emitted when route files are created or deleted and the editor should reload.
signal catalog_changed

const _ROUTE_COLORS := {
	"family_memory":            Color(0.95, 0.63, 0.12),
	"study_future":             Color(0.29, 0.57, 0.86),
	"preservation_inheritance": Color(0.38, 0.76, 0.26),
	"melody_landmarks":         Color(0.61, 0.34, 0.76),
}
const _DEFAULT_ROUTE_COLOR := Color(0.55, 0.55, 0.55)

# ---------------------------------------------------------------------------
# UI members
# ---------------------------------------------------------------------------

var m_toolbar: HBoxContainer
var m_refresh_btn: Button
var m_new_route_btn: Button
var m_delete_route_btn: Button

var m_event_tree: Tree

var m_warnings_panel: VBoxContainer
var m_warnings_scroll: ScrollContainer
var m_delete_route_dialog: ConfirmationDialog
var m_delete_route_message: Label
var m_delete_event_dialog: ConfirmationDialog
var m_delete_event_message: Label

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## Full catalog data, refreshed on each reload.
var m_route_defs: Dictionary = {}
var m_event_defs: Dictionary = {}
## Maps route_id -> PackedStringArray[String] of source paths.
var m_route_resource_paths: Dictionary = {}
## Project-wide validation warnings: Array[String]
var m_all_warnings: Array[String] = []

var m_editor_interface: EditorInterface


func setup(editor_interface: EditorInterface) -> void:
	m_editor_interface = editor_interface


func refresh_from_disk() -> void:
	_refresh()


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_build_ui()
	call_deferred("_refresh")


# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 0)

	# --- Toolbar ---
	m_toolbar = HBoxContainer.new()
	m_toolbar.add_theme_constant_override("separation", 4)
	add_child(m_toolbar)

	var title_lbl := Label.new()
	title_lbl.text = "  Routes"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_toolbar.add_child(title_lbl)

	m_new_route_btn = Button.new()
	m_new_route_btn.text = "+ New"
	m_new_route_btn.tooltip_text = (
		"Creates a new StorylineRouteResource .tres file in game/storylines/routes/"
	)
	m_new_route_btn.pressed.connect(_on_new_route_pressed)
	m_toolbar.add_child(m_new_route_btn)

	m_delete_route_btn = Button.new()
	m_delete_route_btn.text = "Delete"
	m_delete_route_btn.tooltip_text = "Select a route row to delete that storyline."
	m_delete_route_btn.disabled = true
	m_delete_route_btn.pressed.connect(_on_delete_route_pressed)
	m_toolbar.add_child(m_delete_route_btn)

	m_refresh_btn = Button.new()
	m_refresh_btn.text = "⟳"
	m_refresh_btn.tooltip_text = "Reload all storyline data from disk"
	m_refresh_btn.pressed.connect(_refresh)
	m_toolbar.add_child(m_refresh_btn)

	add_child(HSeparator.new())

	m_event_tree = Tree.new()
	m_event_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m_event_tree.columns = 1
	m_event_tree.hide_root = true
	m_event_tree.set_column_expand(0, true)
	m_event_tree.column_titles_visible = false
	m_event_tree.item_selected.connect(_on_event_tree_item_selected)
	m_event_tree.item_activated.connect(_on_event_tree_item_activated)
	add_child(m_event_tree)

	# Warnings scroll at the bottom.
	m_warnings_scroll = ScrollContainer.new()
	m_warnings_scroll.custom_minimum_size = Vector2(0.0, 72.0)
	m_warnings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(m_warnings_scroll)

	m_warnings_panel = VBoxContainer.new()
	m_warnings_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_warnings_scroll.add_child(m_warnings_panel)

	_ensure_delete_route_dialog()
	_ensure_delete_event_dialog()


# ---------------------------------------------------------------------------
# Data loading
# ---------------------------------------------------------------------------

func _refresh() -> void:
	_load_catalog_data()
	_rebuild_story_tree()
	_rebuild_warnings_panel()
	_update_route_delete_button_state()


func _load_catalog_data() -> void:
	m_route_defs = StorylineCatalog.build_route_definitions()
	m_event_defs = StorylineCatalog.build_event_definitions()
	m_route_resource_paths.clear()
	var route_resource_paths := StorylineCatalog.build_route_resource_paths()
	for route_id_var in route_resource_paths.keys():
		var route_id := String(route_id_var)
		m_route_resource_paths[route_id] = PackedStringArray(
			route_resource_paths.get(route_id, PackedStringArray())
		)

	# Run project-wide validation.
	_collect_all_warnings()


# ---------------------------------------------------------------------------
# Story tree
# ---------------------------------------------------------------------------

func _rebuild_story_tree() -> void:
	m_event_tree.clear()
	var root: TreeItem = m_event_tree.create_item()
	var all_event_ids := _all_event_ids()

	for route_id: String in _sorted_route_ids():
		var route_def: Dictionary = m_route_defs.get(route_id, {})
		var route_item := _create_route_tree_item(root, route_id, route_def)
		for event_def: Dictionary in _events_for_route(route_id):
			_create_event_tree_item(route_item, event_def, all_event_ids)


func _route_tooltip(rid: String, rdef: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("id: %s" % rid)
	lines.append("display_order: %s" % str(rdef.get("display_order", "?")))
	var event_count := 0
	for edef in m_event_defs.values():
		if str((edef as Dictionary).get("route_id", "")) == rid:
			event_count += 1
	lines.append("events: %d" % event_count)
	return "\n".join(lines)


# ---------------------------------------------------------------------------
# Combined story tree
# ---------------------------------------------------------------------------

func _rebuild_event_tree(_route_id: String = "") -> void:
	_rebuild_story_tree()


func _create_route_tree_item(
	parent: TreeItem, route_id: String, route_def: Dictionary
) -> TreeItem:
	var display: String = str(route_def.get("display_name", route_id))
	var route_item := m_event_tree.create_item(parent)
	route_item.set_text(0, display)
	route_item.set_tooltip_text(0, _route_tooltip(route_id, route_def))
	route_item.set_custom_color(0, _ROUTE_COLORS.get(route_id, _DEFAULT_ROUTE_COLOR))
	route_item.set_metadata(0, {
		"kind": "route",
		"route_id": route_id,
	})
	return route_item


func _create_event_tree_item(
	parent: TreeItem, event_def: Dictionary, all_event_ids: Dictionary
) -> void:
	var event_id: String = str(event_def.get("id", ""))
	var event_item := m_event_tree.create_item(parent)
	event_item.set_text(0, event_id)
	event_item.set_tooltip_text(0, str(event_def.get("lead_text", "")))

	var prereqs := _event_prereqs(event_def)
	event_item.set_metadata(0, {
		"kind": "event",
		"event_id": event_id,
		"route_id": String(event_def.get("route_id", "")).strip_edges(),
	})

	for prereq: String in prereqs:
		if not all_event_ids.has(prereq):
			event_item.set_custom_color(0, Color(1.0, 0.6, 0.3))
			break


func _on_event_tree_item_selected() -> void:
	var route_id := _selected_route_tree_route_id()
	_update_route_delete_button_state()
	if not route_id.is_empty():
		route_inspector_requested.emit(route_id)
		return

	var eid := _selected_event_tree_event_id()
	if eid.is_empty():
		return
	event_inspector_requested.emit(eid)


func _on_event_tree_item_activated() -> void:
	var eid := _selected_event_tree_event_id()
	if eid.is_empty():
		return
	event_show_in_graph_requested.emit(eid)


func _selected_event_tree_event_id() -> String:
	var metadata := _selected_tree_metadata()
	if metadata.is_empty():
		return ""
	if String(metadata.get("kind", "")) != "event":
		return ""
	return String(metadata.get("event_id", "")).strip_edges()


func _selected_event_tree_route_id() -> String:
	var metadata := _selected_tree_metadata()
	if metadata.is_empty():
		return ""
	if String(metadata.get("kind", "")) != "event":
		return ""
	return String(metadata.get("route_id", "")).strip_edges()


func _selected_route_tree_route_id() -> String:
	var metadata := _selected_tree_metadata()
	if metadata.is_empty():
		return ""
	if String(metadata.get("kind", "")) != "route":
		return ""
	return String(metadata.get("route_id", "")).strip_edges()


func _selected_tree_metadata() -> Dictionary:
	var item: TreeItem = m_event_tree.get_selected()
	if item == null:
		return {}
	var metadata: Variant = item.get_metadata(0)
	if not (metadata is Dictionary):
		return {}
	return metadata as Dictionary


# ---------------------------------------------------------------------------
# Validation warnings
# ---------------------------------------------------------------------------

func _collect_all_warnings() -> void:
	m_all_warnings.clear()

	# Load route resources for typed validation.
	var resources: Array[StorylineRouteResource] = StorylineCatalog.load_route_resources()
	for res: StorylineRouteResource in resources:
		for w: String in res.validate():
			m_all_warnings.append("[%s]  %s" % [res.id, w])

	for warning: String in StoryEventCatalog.validate_story_event_references(m_event_defs):
		m_all_warnings.append("[StoryEventCatalog]  %s" % warning)

	# Project-wide prerequisite existence check against the full event catalog.
	var all_event_ids: Dictionary = {}
	for eid in m_event_defs.keys():
		all_event_ids[str(eid)] = true

	for eid_var in m_event_defs.keys():
		var edef: Dictionary = m_event_defs[eid_var] as Dictionary
		var eid: String = str(eid_var)
		var prereq_dict = edef.get("prerequisites", {})
		if not (prereq_dict is Dictionary):
			continue
		for key: String in ["story_flags_all", "story_flags_any"]:
			var flags = (prereq_dict as Dictionary).get(key, [])
			if not (flags is Array):
				continue
			for f in (flags as Array):
				var fs: String = str(f).strip_edges()
				if not fs.is_empty() and not all_event_ids.has(fs):
					m_all_warnings.append(
						"[%s] prerequisite '%s' not found in any route" % [eid, fs]
					)


func _rebuild_warnings_panel() -> void:
	for child: Node in m_warnings_panel.get_children():
		m_warnings_panel.remove_child(child)
		child.queue_free()

	if m_all_warnings.is_empty():
		var ok_lbl := Label.new()
		ok_lbl.text = "  ✓  No project-wide warnings"
		_configure_tooltip_label(
			ok_lbl,
			"No project-wide validation warnings."
		)
		ok_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
		m_warnings_panel.add_child(ok_lbl)
		return

	var header := Label.new()
	header.text = "  ⚠  Project warnings (%d)" % m_all_warnings.size()
	_configure_tooltip_label(header, _warnings_tooltip(m_all_warnings))
	header.add_theme_color_override("font_color", Color(1.0, 0.75, 0.2))
	m_warnings_panel.add_child(header)

	for w: String in m_all_warnings:
		var lbl := Label.new()
		lbl.text = "  • " + w
		_configure_tooltip_label(lbl, w)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3))
		m_warnings_panel.add_child(lbl)


# ---------------------------------------------------------------------------
# New route resource helper
# ---------------------------------------------------------------------------

func _on_new_route_pressed() -> void:
	# Ask for a file name, then create the .tres under game/storylines/routes/.
	var dialog := ConfirmationDialog.new()
	dialog.title = "New Route Resource"
	dialog.ok_button_text = "Create"

	var vbox := VBoxContainer.new()
	dialog.add_child(vbox)

	var hint := Label.new()
	hint.text = "File name (without .tres):"
	vbox.add_child(hint)

	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "e.g. my_new_route"
	name_edit.custom_minimum_size = Vector2(260.0, 0.0)
	vbox.add_child(name_edit)

	add_child(dialog)
	dialog.popup_centered()

	dialog.confirmed.connect(func() -> void:
		var file_name: String = name_edit.text.strip_edges()
		if file_name.is_empty():
			return
		if not file_name.ends_with(".tres"):
			file_name = file_name + ".tres"
		var path: String = "res://game/storylines/routes/" + file_name
		var res: StorylineRouteResource = StorylineRouteResource.new()
		var err: int = ResourceSaver.save(res, path)
		if err != OK:
			push_error("StorylineRouteBrowser: failed to save new resource at %s (err=%d)" % [path, err])
		else:
			_refresh()
			catalog_changed.emit()
			if m_editor_interface != null:
				m_editor_interface.edit_resource(res)
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
	)


func _on_delete_route_pressed() -> void:
	var event_id := _selected_event_tree_event_id()
	if not event_id.is_empty():
		_on_delete_event_pressed(event_id)
		return

	var route_id := _selected_route_tree_route_id()
	if route_id.is_empty():
		return
	var deletable_paths := _deletable_route_paths(route_id)
	if deletable_paths.is_empty():
		return

	_ensure_delete_route_dialog()
	var route_name := String(m_route_defs.get(route_id, {}).get("display_name", route_id))
	if m_delete_route_message != null:
		m_delete_route_message.text = (
			"Delete storyline route '%s' and all matching source files? This cannot be undone."
			% route_name
		)
		if m_delete_route_dialog != null:
			m_delete_route_dialog.set_meta("route_id", route_id)
			m_delete_route_dialog.popup_centered()


func _on_delete_event_pressed(event_id: String = "") -> void:
	event_id = event_id.strip_edges()
	if event_id.is_empty():
		event_id = _selected_event_tree_event_id()
	if event_id.is_empty():
		return

	_ensure_delete_event_dialog()
	if m_delete_event_message != null:
		m_delete_event_message.text = (
			"Delete story event '%s'? This cannot be undone." % event_id
		)
	if m_delete_event_dialog != null:
		m_delete_event_dialog.set_meta("event_id", event_id)
		m_delete_event_dialog.popup_centered()


func _confirm_delete_route() -> void:
	if m_delete_route_dialog == null:
		return

	var route_id := String(m_delete_route_dialog.get_meta("route_id", "")).strip_edges()
	m_delete_route_dialog.hide()
	m_delete_route_dialog.remove_meta("route_id")
	if route_id.is_empty():
		return

	var deletion_errors := PackedStringArray()
	for path: String in _deletable_route_paths(route_id):
		var absolute_path := ProjectSettings.globalize_path(path)
		if not FileAccess.file_exists(absolute_path):
			continue
		var remove_error := DirAccess.remove_absolute(absolute_path)
		if remove_error != OK:
			deletion_errors.append("%s (err=%d)" % [path, remove_error])

	if not deletion_errors.is_empty():
		push_error(
			"StorylineRouteBrowser: failed to delete route '%s': %s"
			% [route_id, ", ".join(deletion_errors)]
		)
		return

	if m_editor_interface != null:
		var inspector := m_editor_interface.get_inspector()
		if inspector != null and _should_clear_inspector_for_deleted_route(
			route_id,
			inspector.get_edited_object()
		):
			inspector.edit(null)

	_refresh()
	catalog_changed.emit()


func _confirm_delete_event() -> void:
	if m_delete_event_dialog == null:
		return

	var event_id := String(m_delete_event_dialog.get_meta("event_id", "")).strip_edges()
	m_delete_event_dialog.hide()
	m_delete_event_dialog.remove_meta("event_id")
	if event_id.is_empty():
		return

	event_delete_requested.emit(event_id)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _sorted_route_ids() -> Array[String]:
	var ids: Array[String] = []
	for rid_var in m_route_defs.keys():
		ids.append(str(rid_var))
	ids.sort_custom(func(a: String, b: String) -> bool:
		var oa: int = int(m_route_defs.get(a, {}).get("display_order", 9999))
		var ob: int = int(m_route_defs.get(b, {}).get("display_order", 9999))
		if oa != ob:
			return oa < ob
		return a < b
	)
	return ids


func _events_for_route(route_id: String) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for event_id_var in m_event_defs.keys():
		var event_def: Dictionary = m_event_defs[event_id_var] as Dictionary
		if str(event_def.get("route_id", "")) == route_id:
			events.append(event_def)
	return events


func _all_event_ids() -> Dictionary:
	var all_event_ids: Dictionary = {}
	for event_id_var in m_event_defs.keys():
		all_event_ids[str(event_id_var)] = true
	return all_event_ids


func _event_prereqs(event_def: Dictionary) -> Array[String]:
	var prereqs: Array[String] = []
	var prereq_dict = event_def.get("prerequisites", {})
	if prereq_dict is Dictionary:
		for key: String in ["story_flags_all", "story_flags_any"]:
			var flags = (prereq_dict as Dictionary).get(key, [])
			if flags is Array:
				for flag in flags as Array:
					var flag_id: String = str(flag).strip_edges()
					if not flag_id.is_empty() and not prereqs.has(flag_id):
						prereqs.append(flag_id)
	return prereqs


func _warnings_tooltip(warnings: Array[String]) -> String:
	if warnings.is_empty():
		return "No warnings."

	var lines := PackedStringArray()
	for warning: String in warnings:
		lines.append("• %s" % warning)
	return "\n".join(lines)


func _configure_tooltip_label(label: Label, tooltip: String) -> void:
	label.tooltip_text = tooltip
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.mouse_default_cursor_shape = Control.CURSOR_HELP


func _ensure_delete_route_dialog() -> void:
	if m_delete_route_dialog != null:
		return

	m_delete_route_dialog = ConfirmationDialog.new()
	m_delete_route_dialog.title = "Delete Storyline Route"
	m_delete_route_dialog.ok_button_text = "Delete"
	add_child(m_delete_route_dialog)

	m_delete_route_message = Label.new()
	m_delete_route_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m_delete_route_message.custom_minimum_size = Vector2(360.0, 0.0)
	m_delete_route_dialog.add_child(m_delete_route_message)

	m_delete_route_dialog.confirmed.connect(_confirm_delete_route)
	m_delete_route_dialog.canceled.connect(func() -> void:
		if m_delete_route_dialog != null:
			m_delete_route_dialog.remove_meta("route_id")
	)


func _ensure_delete_event_dialog() -> void:
	if m_delete_event_dialog != null:
		return

	m_delete_event_dialog = ConfirmationDialog.new()
	m_delete_event_dialog.title = "Delete Story Event"
	m_delete_event_dialog.ok_button_text = "Delete"
	add_child(m_delete_event_dialog)

	m_delete_event_message = Label.new()
	m_delete_event_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m_delete_event_message.custom_minimum_size = Vector2(360.0, 0.0)
	m_delete_event_dialog.add_child(m_delete_event_message)

	m_delete_event_dialog.confirmed.connect(_confirm_delete_event)
	m_delete_event_dialog.canceled.connect(func() -> void:
		if m_delete_event_dialog != null:
			m_delete_event_dialog.remove_meta("event_id")
	)


func _update_route_delete_button_state() -> void:
	if m_delete_route_btn == null:
		return

	var event_id := _selected_event_tree_event_id()
	if not event_id.is_empty():
		m_delete_route_btn.disabled = false
		m_delete_route_btn.tooltip_text = "Delete the selected story event after confirmation."
		return

	var route_id := _selected_route_tree_route_id()
	var can_delete := not route_id.is_empty() and not _deletable_route_paths(route_id).is_empty()
	m_delete_route_btn.disabled = not can_delete
	if route_id.is_empty():
		m_delete_route_btn.tooltip_text = "Select a route or event row to delete it."
	elif can_delete:
		m_delete_route_btn.tooltip_text = "Delete the selected storyline route after confirmation."
	else:
		m_delete_route_btn.tooltip_text = "The selected route does not have deletable source files."


func _deletable_route_paths(route_id: String) -> PackedStringArray:
	var delete_paths := PackedStringArray()
	for resource_path: String in PackedStringArray(m_route_resource_paths.get(route_id, PackedStringArray())):
		if not resource_path.is_empty() and not delete_paths.has(resource_path):
			delete_paths.append(resource_path)
	return delete_paths


func _should_clear_inspector_for_deleted_route(
	route_id: String, edited_object: Object
) -> bool:
	route_id = route_id.strip_edges()
	if route_id.is_empty() or edited_object == null:
		return false
	if edited_object is StorylineRouteResource:
		return (edited_object as StorylineRouteResource).id.strip_edges() == route_id
	if edited_object is StorylineEventResource:
		var edited_event_id := (edited_object as StorylineEventResource).id.strip_edges()
		if edited_event_id.is_empty():
			return false
		var event_def: Dictionary = m_event_defs.get(edited_event_id, {})
		return String(event_def.get("route_id", "")).strip_edges() == route_id
	return false
