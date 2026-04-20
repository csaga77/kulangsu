@tool
extends VBoxContainer
## Editor dock that lists all known storyline routes and their events.
##
## Shows:
##   • Route list (all routes, color-coded, resource vs. .gd-module badge)
##   • Per-route event tree with prerequisite counts and completion scores
##   • Project-wide validation warnings surfaced inline
##   • Quick-open button to navigate to the backing .tres or .gd file
##   • "Show in Graph" button to select the event in the graph editor
##
## Wire [signal event_show_in_graph_requested] in [StorylineEditorPlugin] to
## [method StorylineGraphEditor.select_event].

## Emitted when the user wants to highlight an event in the dependency graph.
signal event_show_in_graph_requested(event_id: String)
## Emitted when the user selects an event row and wants to edit it in the Inspector.
signal event_inspector_requested(event_id: String)

const _ROUTE_COLORS := {
	"family_memory":            Color(0.95, 0.63, 0.12),
	"study_future":             Color(0.29, 0.57, 0.86),
	"preservation_inheritance": Color(0.38, 0.76, 0.26),
	"melody_landmarks":         Color(0.61, 0.34, 0.76),
}
const _DEFAULT_ROUTE_COLOR := Color(0.55, 0.55, 0.55)
const _BADGE_RESOURCE := "●"
const _BADGE_GDSCRIPT  := "◎"

# ---------------------------------------------------------------------------
# UI members
# ---------------------------------------------------------------------------

var m_toolbar: HBoxContainer
var m_refresh_btn: Button
var m_new_route_btn: Button
var m_split: VSplitContainer

var m_route_list: ItemList
var m_event_tree: Tree

var m_warnings_panel: VBoxContainer
var m_warnings_scroll: ScrollContainer

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## Indexed by ItemList row — route_id for each row.
var m_route_ids: Array[String] = []
## Full catalog data, refreshed on each reload.
var m_route_defs: Dictionary = {}
var m_event_defs: Dictionary = {}
## Maps route_id -> "resource" | "gdscript" | ""
var m_route_source: Dictionary = {}
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

	m_refresh_btn = Button.new()
	m_refresh_btn.text = "⟳"
	m_refresh_btn.tooltip_text = "Reload all storyline data from disk"
	m_refresh_btn.pressed.connect(_refresh)
	m_toolbar.add_child(m_refresh_btn)

	add_child(HSeparator.new())

	# --- Vertical split: top = route list, bottom = event tree + warnings ---
	m_split = VSplitContainer.new()
	m_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(m_split)

	# Route list panel.
	var route_panel := VBoxContainer.new()
	route_panel.custom_minimum_size = Vector2(0.0, 120.0)
	m_split.add_child(route_panel)

	var route_header := Label.new()
	route_header.text = "  Routes"
	route_header.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	route_panel.add_child(route_header)

	m_route_list = ItemList.new()
	m_route_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m_route_list.item_selected.connect(_on_route_selected)
	route_panel.add_child(m_route_list)

	# Events panel + warnings panel stacked below.
	var bottom_vbox := VBoxContainer.new()
	bottom_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m_split.add_child(bottom_vbox)

	var event_header_row := HBoxContainer.new()
	bottom_vbox.add_child(event_header_row)

	var event_header_lbl := Label.new()
	event_header_lbl.text = "  Events"
	event_header_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	event_header_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_header_row.add_child(event_header_lbl)

	m_event_tree = Tree.new()
	m_event_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m_event_tree.columns = 3
	m_event_tree.set_column_title(0, "Event ID")
	m_event_tree.set_column_title(1, "Score")
	m_event_tree.set_column_title(2, "Prereqs")
	m_event_tree.set_column_expand(0, true)
	m_event_tree.set_column_expand(1, false)
	m_event_tree.set_column_expand(2, false)
	m_event_tree.set_column_custom_minimum_width(1, 64)
	m_event_tree.set_column_custom_minimum_width(2, 84)
	m_event_tree.column_titles_visible = true
	m_event_tree.item_selected.connect(_on_event_tree_item_selected)
	m_event_tree.item_activated.connect(_on_event_tree_item_activated)
	bottom_vbox.add_child(m_event_tree)

	# Warnings scroll at the bottom.
	m_warnings_scroll = ScrollContainer.new()
	m_warnings_scroll.custom_minimum_size = Vector2(0.0, 72.0)
	m_warnings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bottom_vbox.add_child(m_warnings_scroll)

	m_warnings_panel = VBoxContainer.new()
	m_warnings_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_warnings_scroll.add_child(m_warnings_panel)


# ---------------------------------------------------------------------------
# Data loading
# ---------------------------------------------------------------------------

func _refresh() -> void:
	_load_catalog_data()
	_rebuild_route_list()
	_rebuild_warnings_panel()
	# Reselect first route if nothing was selected.
	if m_route_list.item_count > 0 and m_route_list.get_selected_items().is_empty():
		m_route_list.select(0)
		_on_route_selected(0)


func _load_catalog_data() -> void:
	m_route_defs = StorylineCatalog.build_route_definitions()
	m_event_defs = StorylineCatalog.build_event_definitions()

	# Determine source type for each route.
	m_route_source.clear()
	var resource_route_ids: Dictionary = {}
	for res: StorylineRouteResource in StorylineCatalog.load_route_resources():
		resource_route_ids[res.id.strip_edges()] = true
	for route_id: String in m_route_defs.keys():
		if resource_route_ids.has(route_id):
			m_route_source[route_id] = "resource"
		else:
			m_route_source[route_id] = "gdscript"

	# Run project-wide validation.
	_collect_all_warnings()


# ---------------------------------------------------------------------------
# Route list
# ---------------------------------------------------------------------------

func _rebuild_route_list() -> void:
	var prev_route := ""
	var sel := m_route_list.get_selected_items()
	if sel.size() > 0 and sel[0] < m_route_ids.size():
		prev_route = m_route_ids[sel[0]]

	m_route_list.clear()
	m_route_ids.clear()

	var sorted_ids := _sorted_route_ids()
	for rid: String in sorted_ids:
		var rdef: Dictionary = m_route_defs.get(rid, {})
		var display: String = str(rdef.get("display_name", rid))
		var source: String = str(m_route_source.get(rid, ""))
		var badge: String = _BADGE_RESOURCE if source == "resource" else _BADGE_GDSCRIPT
		var label: String = "%s %s" % [badge, display]
		var idx: int = m_route_list.add_item(label)
		m_route_list.set_item_tooltip(idx, _route_tooltip(rid, rdef, source))
		var color: Color = _ROUTE_COLORS.get(rid, _DEFAULT_ROUTE_COLOR)
		m_route_list.set_item_custom_fg_color(idx, color)
		m_route_ids.append(rid)

	# Restore selection.
	var restore_idx := 0
	for i: int in m_route_ids.size():
		if m_route_ids[i] == prev_route:
			restore_idx = i
			break
	if m_route_list.item_count > 0:
		m_route_list.select(restore_idx)
		_on_route_selected(restore_idx)


func _route_tooltip(rid: String, rdef: Dictionary, source: String) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("id: %s" % rid)
	lines.append("display_order: %s" % str(rdef.get("display_order", "?")))
	lines.append("source: %s" % source)
	var event_count := 0
	for edef in m_event_defs.values():
		if str((edef as Dictionary).get("route_id", "")) == rid:
			event_count += 1
	lines.append("events: %d" % event_count)
	return "\n".join(lines)


# ---------------------------------------------------------------------------
# Event tree
# ---------------------------------------------------------------------------

func _on_route_selected(idx: int) -> void:
	if idx < 0 or idx >= m_route_ids.size():
		return
	_rebuild_event_tree(m_route_ids[idx])


func _rebuild_event_tree(route_id: String) -> void:
	m_event_tree.clear()
	var root: TreeItem = m_event_tree.create_item()
	root.set_text(0, route_id)

	# Collect events for this route in catalog insertion order so the browser
	# matches the authored event order from resources or legacy modules.
	var events: Array[Dictionary] = []
	for eid_var in m_event_defs.keys():
		var edef: Dictionary = m_event_defs[eid_var] as Dictionary
		if str(edef.get("route_id", "")) == route_id:
			events.append(edef)

	var all_event_ids: Dictionary = {}
	for eid_var in m_event_defs.keys():
		all_event_ids[str(eid_var)] = true

	for edef: Dictionary in events:
		var eid: String = str(edef.get("id", ""))
		var item: TreeItem = m_event_tree.create_item(root)
		item.set_text(0, eid)
		item.set_tooltip_text(0, str(edef.get("lead_text", "")))
		item.set_text(1, str(edef.get("completion_score", 1)))
		item.set_text_alignment(1, HORIZONTAL_ALIGNMENT_CENTER)

		var prereq_dict = edef.get("prerequisites", {})
		var prereqs: Array[String] = []
		if prereq_dict is Dictionary:
			for key: String in ["story_flags_all", "story_flags_any"]:
				var flags = (prereq_dict as Dictionary).get(key, [])
				if flags is Array:
					for f in (flags as Array):
						var fs: String = str(f)
						if not fs.is_empty() and not prereqs.has(fs):
							prereqs.append(fs)

		item.set_text(2, str(prereqs.size()))
		item.set_text_alignment(2, HORIZONTAL_ALIGNMENT_CENTER)

		# Color: dim if all prereqs are unresolved cross-route refs.
		var has_missing := false
		for prereq: String in prereqs:
			if not all_event_ids.has(prereq):
				has_missing = true
				break
		if has_missing:
			item.set_custom_color(0, Color(1.0, 0.6, 0.3))

		# Add prerequisite child rows.
		for prereq: String in prereqs:
			var dep_item: TreeItem = m_event_tree.create_item(item)
			var exists: bool = all_event_ids.has(prereq)
			dep_item.set_text(0, "  ← %s" % prereq)
			dep_item.set_custom_color(0,
				Color(0.5, 0.5, 0.5) if exists else Color(1.0, 0.5, 0.3)
			)
			dep_item.set_tooltip_text(0,
				"prerequisite — %s" % ("found" if exists else "NOT FOUND in catalog")
			)

		# Store eid in metadata for double-click.
		item.set_metadata(0, eid)


func _on_event_tree_item_selected() -> void:
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
	var item: TreeItem = m_event_tree.get_selected()
	if item == null:
		return ""
	return str(item.get_metadata(0)).strip_edges()


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

	# Cross-route prerequisite check against the full event catalog.
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
			if m_editor_interface != null:
				m_editor_interface.edit_resource(res)
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
	)


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
