@tool
extends VBoxContainer
## GraphEdit-based view/editor for storyline event dependencies.
##
## Reads route and event data from StorylineCatalog at editor time without
## introducing a second source of truth. Connections represent
## story_flags_all / story_flags_any prerequisites. Cross-route dependencies
## are shown when "All routes" is selected, and graph edits are written back
## to the canonical route resource for the target event.
##
## Compatibility-only: if the target route still lives in a legacy
## *_storyline.gd module, the first graph edit auto-promotes that route into
## game/storylines/routes/<route_id>.tres before saving the new dependency.
##
## Layout: events are arranged in columns by dependency depth (longest
## prerequisite chain), sorted within each column by route display_order.
## Time flows left to right: prerequisites are always to the left of their
## dependents.

signal catalog_changed

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Per-route accent colors — matched to the four canonical route families.
const _ROUTE_COLORS := {
	"family_memory":           Color(0.95, 0.63, 0.12),   # warm amber
	"study_future":            Color(0.29, 0.57, 0.86),   # cool blue
	"preservation_inheritance": Color(0.38, 0.76, 0.26),  # earthy green
	"melody_landmarks":        Color(0.61, 0.34, 0.76),   # soft purple
}
const _DEFAULT_ROUTE_COLOR := Color(0.52, 0.52, 0.52)
const _PREREQ_ALL_COLOR := Color(0.95, 0.78, 0.28)
const _PREREQ_ANY_COLOR := Color(0.48, 0.74, 0.96)

## Slot type index — all ports use the same type so any output can connect to
## any input (GraphEdit only wires same-type ports by default).
const _SLOT_TYPE := 0
const _NODE_OUTPUT_SLOT := 0
const _NODE_ALL_INPUT_SLOT := 1
const _NODE_ANY_INPUT_SLOT := 2
const _PREREQ_ALL_KEY := "story_flags_all"
const _PREREQ_ANY_KEY := "story_flags_any"

## Layout geometry.
const _NODE_WIDTH        := 280.0
const _COLUMN_GAP        := 90.0
const _ROW_GAP           := 20.0
## Approximate row height; actual height depends on label wrapping.
const _ROW_HEIGHT        := 120.0
const _LAYOUT_ORIGIN     := Vector2(20.0, 20.0)
const _LAYOUT_STATE_SECTION := "storyline_graph"
const _LAYOUT_STATE_KEY := "positions"
const _DEFAULT_LAYOUT_STATE_PATH := "user://storyline_editor/graph_layout.cfg"

# ---------------------------------------------------------------------------
# UI members
# ---------------------------------------------------------------------------

var m_toolbar: HBoxContainer
var m_route_filter: OptionButton
var m_refresh_btn: Button
var m_arrange_btn: Button
var m_event_count_lbl: Label

var m_graph_edit: GraphEdit
var m_editor_interface: EditorInterface

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## Keyed by route_id, value is the route definition Dictionary.
var m_route_defs: Dictionary = {}
## Keyed by event_id, value is the event definition Dictionary
## (with "route_id" injected by StorylineCatalog.build_event_definitions).
var m_event_defs: Dictionary = {}
## Keyed by route_id, value is the saved .tres path for that route.
var m_route_resource_paths: Dictionary = {}
## Keyed by event_id, value is the most recently arranged graph position.
var m_layout_positions: Dictionary = {}
var m_layout_state_path: String = _DEFAULT_LAYOUT_STATE_PATH

## Maps event_id (String) -> GraphNode currently in the graph.
var m_node_map: Dictionary = {}

var m_selected_event_id: String = ""
var m_connection_drag_selected_event_id: String = ""
var m_graph_rebuild_token: int = 0
var m_refresh_queued: bool = false
var m_watched_route_resources: Array[StorylineRouteResource] = []
var m_left_disconnect_types: Dictionary = {}
var m_right_disconnect_types: Dictionary = {}

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_build_ui()
	_load_persisted_layout_state()
	# Defer the first load so the editor plugin infrastructure finishes before
	# we call DirAccess and load() inside StorylineCatalog.
	call_deferred("_refresh_graph")


func _exit_tree() -> void:
	_disconnect_route_resource_watchers()
	_capture_current_layout_positions()
	_save_persisted_layout_state()


func setup(editor_interface: EditorInterface) -> void:
	m_editor_interface = editor_interface


func refresh_from_disk() -> void:
	_refresh_graph()


func delete_event(event_id: String) -> void:
	event_id = event_id.strip_edges()
	if event_id.is_empty():
		return

	var event_def: Dictionary = m_event_defs.get(event_id, {})
	if event_def.is_empty():
		_load_catalog_data()
		event_def = m_event_defs.get(event_id, {})
		if event_def.is_empty():
			push_warning("StorylineGraphEditor: unknown event '%s' for deletion" % event_id)
			return

	var route_id := String(event_def.get("route_id", "")).strip_edges()
	if route_id.is_empty():
		push_warning("StorylineGraphEditor: event '%s' has no route_id for deletion" % event_id)
		return

	var route_resource := _ensure_route_resource_for_editing(route_id)
	if route_resource == null:
		push_warning("StorylineGraphEditor: unable to load route resource for deletion '%s'" % route_id)
		return

	var delete_index := _find_event_resource_index(route_resource, event_id)
	if delete_index < 0:
		push_warning(
			"StorylineGraphEditor: route '%s' has no editable event '%s' to delete'"
			% [route_id, event_id]
		)
		return

	var updated_events: Array[StorylineEventResource] = route_resource.events.duplicate()
	updated_events.remove_at(delete_index)
	route_resource.events = updated_events

	var save_path := _route_resource_path_for(route_id)
	var save_error := ResourceSaver.save(route_resource, save_path)
	if save_error != OK:
		push_error(
			"StorylineGraphEditor: failed to save '%s' after deleting '%s' (err=%d)"
			% [save_path, event_id, save_error]
		)
		return

	route_resource.take_over_path(save_path)
	m_route_resource_paths[route_id] = save_path
	_clear_inspector_if_editing_deleted_event(event_id)
	var preserved_selected_event_id := m_selected_event_id
	if preserved_selected_event_id == event_id:
		preserved_selected_event_id = ""
	var preserved_scroll_offset := m_graph_edit.scroll_offset
	_refresh_graph()
	catalog_changed.emit()
	call_deferred(
		"_restore_graph_state_after_refresh",
		preserved_selected_event_id,
		preserved_scroll_offset
	)


# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	visibility_changed.connect(_on_graph_editor_visibility_changed)

	# --- Toolbar ---
	m_toolbar = HBoxContainer.new()
	m_toolbar.add_theme_constant_override("separation", 6)
	add_child(m_toolbar)

	var route_lbl := Label.new()
	route_lbl.text = "  Route: "
	m_toolbar.add_child(route_lbl)

	m_route_filter = OptionButton.new()
	m_route_filter.add_item("All routes")
	m_route_filter.set_item_metadata(0, "")
	m_route_filter.item_selected.connect(_on_filter_changed)
	m_toolbar.add_child(m_route_filter)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_toolbar.add_child(spacer)

	m_event_count_lbl = Label.new()
	m_event_count_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	m_toolbar.add_child(m_event_count_lbl)

	m_refresh_btn = Button.new()
	m_refresh_btn.text = "Refresh"
	m_refresh_btn.tooltip_text = (
		"Reload storyline data from disk and rebuild the dependency graph."
	)
	m_refresh_btn.pressed.connect(_refresh_graph)
	m_toolbar.add_child(m_refresh_btn)

	m_arrange_btn = Button.new()
	m_arrange_btn.text = "Arrange"
	m_arrange_btn.tooltip_text = (
		"Reset all visible story event nodes to the automatic dependency layout."
	)
	m_arrange_btn.pressed.connect(_arrange_visible_nodes)
	m_toolbar.add_child(m_arrange_btn)

	# Small gap between toolbar and graph area.
	add_child(HSeparator.new())

	m_graph_edit = GraphEdit.new()
	m_graph_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_graph_edit.size_flags_vertical  = Control.SIZE_EXPAND_FILL
	m_graph_edit.show_arrange_button = false
	m_graph_edit.connection_drag_started.connect(_on_connection_drag_started)
	m_graph_edit.connection_drag_ended.connect(_on_connection_drag_ended)
	m_graph_edit.connection_request.connect(_on_connection_request)
	m_graph_edit.disconnection_request.connect(_on_disconnection_request)
	m_graph_edit.node_selected.connect(_on_node_selected)
	m_graph_edit.node_deselected.connect(_on_node_deselected)
	m_graph_edit.resized.connect(_on_graph_edit_resized)
	_configure_disconnect_drag()
	add_child(m_graph_edit)


# ---------------------------------------------------------------------------
# Data loading
# ---------------------------------------------------------------------------

func _refresh_graph() -> void:
	_load_catalog_data()
	_repopulate_route_filter()
	_rebuild_graph()


func _load_catalog_data() -> void:
	m_route_defs = StorylineCatalog.build_route_definitions()
	m_event_defs = StorylineCatalog.build_event_definitions()
	m_route_resource_paths.clear()
	var route_resources := StorylineCatalog.load_route_resources()
	_update_route_resource_watchers(route_resources)
	for route_resource: StorylineRouteResource in route_resources:
		if route_resource == null:
			continue
		var route_id := route_resource.id.strip_edges()
		if route_id.is_empty():
			continue
		var resource_path := route_resource.resource_path
		if resource_path.is_empty():
			resource_path = _route_resource_path_for(route_id)
		m_route_resource_paths[route_id] = resource_path
	_prune_persisted_layout_positions()


func _queue_graph_refresh() -> void:
	if m_refresh_queued:
		return
	m_refresh_queued = true
	call_deferred("_apply_queued_graph_refresh")


func _apply_queued_graph_refresh() -> void:
	m_refresh_queued = false
	if not is_inside_tree() or m_graph_edit == null:
		return

	var preserved_selected_event_id := m_selected_event_id
	var preserved_scroll_offset := m_graph_edit.scroll_offset
	_refresh_graph()
	call_deferred(
		"_restore_graph_state_after_refresh",
		preserved_selected_event_id,
		preserved_scroll_offset
	)


func _update_route_resource_watchers(
	route_resources: Array[StorylineRouteResource]
) -> void:
	var watcher_callback := Callable(self, "_on_watched_route_resource_changed")
	for watched_resource: StorylineRouteResource in m_watched_route_resources:
		if watched_resource == null or not is_instance_valid(watched_resource):
			continue
		if route_resources.has(watched_resource):
			continue
		if watched_resource.changed.is_connected(watcher_callback):
			watched_resource.changed.disconnect(watcher_callback)

	m_watched_route_resources.clear()
	for route_resource: StorylineRouteResource in route_resources:
		if route_resource == null:
			continue
		if not route_resource.changed.is_connected(watcher_callback):
			route_resource.changed.connect(watcher_callback, CONNECT_DEFERRED)
		m_watched_route_resources.append(route_resource)


func _disconnect_route_resource_watchers() -> void:
	var watcher_callback := Callable(self, "_on_watched_route_resource_changed")
	for watched_resource: StorylineRouteResource in m_watched_route_resources:
		if watched_resource == null or not is_instance_valid(watched_resource):
			continue
		if watched_resource.changed.is_connected(watcher_callback):
			watched_resource.changed.disconnect(watcher_callback)
	m_watched_route_resources.clear()


# ---------------------------------------------------------------------------
# Route filter
# ---------------------------------------------------------------------------

func _repopulate_route_filter() -> void:
	# Remember current selection before clearing.
	var current_filter := ""
	if m_route_filter.selected > 0:
		current_filter = str(m_route_filter.get_item_metadata(m_route_filter.selected))

	m_route_filter.clear()
	m_route_filter.add_item("All routes")
	m_route_filter.set_item_metadata(0, "")

	var sorted_ids := _sorted_route_ids()
	var restore_idx := 0
	for i: int in sorted_ids.size():
		var rid: String = sorted_ids[i]
		var rdef: Dictionary = m_route_defs.get(rid, {})
		m_route_filter.add_item(str(rdef.get("display_name", rid)))
		m_route_filter.set_item_metadata(i + 1, rid)
		if rid == current_filter:
			restore_idx = i + 1

	m_route_filter.selected = restore_idx


func _current_filter() -> String:
	return str(m_route_filter.get_item_metadata(m_route_filter.selected))


# ---------------------------------------------------------------------------
# Graph construction
# ---------------------------------------------------------------------------

func _rebuild_graph(capture_layout_positions: bool = true) -> void:
	if capture_layout_positions:
		_capture_current_layout_positions()
		_save_persisted_layout_state()

	# Clear previous graph contents.
	m_graph_edit.clear_connections()
	for node_key in m_node_map.keys():
		var gnode: GraphNode = m_node_map.get(node_key) as GraphNode
		if is_instance_valid(gnode):
			m_graph_edit.remove_child(gnode)
			gnode.queue_free()
	m_node_map.clear()
	m_selected_event_id = ""

	var filter  := _current_filter()
	var visible := _visible_event_ids(filter)

	m_event_count_lbl.text = "%d event%s" % [
		visible.size(), "" if visible.size() == 1 else "s"
	]

	if visible.is_empty():
		return

	m_graph_rebuild_token += 1
	var rebuild_token := m_graph_rebuild_token
	var depth_map   := _compute_depths(visible)
	var placement   := _compute_placement(visible, depth_map)

	for eid: String in visible:
		var edef: Dictionary = m_event_defs.get(eid, {})
		var pos: Vector2 = m_layout_positions.get(
			eid,
			placement.get(eid, Vector2.ZERO)
		)
		_create_event_node(eid, edef, pos)

	_draw_connections(visible)
	call_deferred("_redraw_connections_after_layout", rebuild_token, visible.duplicate())


func _arrange_visible_nodes() -> void:
	var visible := _visible_event_ids(_current_filter())
	if visible.is_empty():
		return

	var depth_map := _compute_depths(visible)
	var placement := _compute_placement(visible, depth_map)
	var preserved_selected_event_id := m_selected_event_id
	var preserved_scroll_offset := m_graph_edit.scroll_offset

	for event_id: String in visible:
		var arranged_position: Variant = placement.get(event_id, Vector2.ZERO)
		if arranged_position is Vector2:
			m_layout_positions[event_id] = arranged_position

	_save_persisted_layout_state()
	_rebuild_graph(false)
	call_deferred(
		"_restore_graph_state_after_refresh",
		preserved_selected_event_id,
		preserved_scroll_offset
	)


func _capture_current_layout_positions() -> void:
	for event_id_var in m_node_map.keys():
		var event_id := String(event_id_var)
		var node: GraphNode = m_node_map.get(event_id) as GraphNode
		if is_instance_valid(node):
			m_layout_positions[event_id] = node.position_offset


func _prune_persisted_layout_positions() -> void:
	var known_event_ids: Dictionary = {}
	for event_id_var in m_event_defs.keys():
		known_event_ids[String(event_id_var)] = true

	var stale_event_ids := PackedStringArray()
	for event_id_var in m_layout_positions.keys():
		var event_id := String(event_id_var)
		if not known_event_ids.has(event_id):
			stale_event_ids.append(event_id)

	if stale_event_ids.is_empty():
		return

	for event_id: String in stale_event_ids:
		m_layout_positions.erase(event_id)
	_save_persisted_layout_state()


func _load_persisted_layout_state() -> void:
	m_layout_positions.clear()

	var config := ConfigFile.new()
	var load_error := config.load(m_layout_state_path)
	if load_error != OK:
		return

	var positions_value: Variant = config.get_value(
		_LAYOUT_STATE_SECTION,
		_LAYOUT_STATE_KEY,
		{}
	)
	if typeof(positions_value) != TYPE_DICTIONARY:
		return

	var serialized_positions: Dictionary = positions_value
	for event_id_var in serialized_positions.keys():
		var event_id := String(event_id_var).strip_edges()
		if event_id.is_empty():
			continue
		var position_value = _deserialize_position(serialized_positions[event_id_var])
		if position_value is Vector2:
			m_layout_positions[event_id] = position_value


func _save_persisted_layout_state() -> void:
	var config := ConfigFile.new()
	var layout_dir := ProjectSettings.globalize_path(m_layout_state_path).get_base_dir()
	var make_dir_error := DirAccess.make_dir_recursive_absolute(layout_dir)
	if make_dir_error != OK and make_dir_error != ERR_ALREADY_EXISTS:
		push_warning(
			"StorylineGraphEditor: failed to create layout dir '%s' (err=%d)"
			% [layout_dir, make_dir_error]
		)
		return

	var serialized_positions: Dictionary = {}
	for event_id_var in m_layout_positions.keys():
		var event_id := String(event_id_var).strip_edges()
		if event_id.is_empty():
			continue
		var position_value = m_layout_positions[event_id_var]
		if position_value is Vector2:
			var position := position_value as Vector2
			serialized_positions[event_id] = {
				"x": position.x,
				"y": position.y,
			}

	config.set_value(_LAYOUT_STATE_SECTION, _LAYOUT_STATE_KEY, serialized_positions)
	var save_error := config.save(m_layout_state_path)
	if save_error != OK:
		push_warning(
			"StorylineGraphEditor: failed to save layout state to '%s' (err=%d)"
			% [m_layout_state_path, save_error]
		)


func _deserialize_position(value: Variant) -> Variant:
	if value is Vector2:
		return value
	if value is Dictionary:
		var dict_value := value as Dictionary
		var x_value: Variant = dict_value.get("x", 0.0)
		var y_value: Variant = dict_value.get("y", 0.0)
		if typeof(x_value) in [TYPE_INT, TYPE_FLOAT] and typeof(y_value) in [TYPE_INT, TYPE_FLOAT]:
			return Vector2(float(x_value), float(y_value))
	return null


func _visible_event_ids(filter: String) -> Array[String]:
	var ids: Array[String] = []
	for eid_var in m_event_defs.keys():
		var eid: String = str(eid_var)
		if filter.is_empty():
			ids.append(eid)
		else:
			var route_id: String = str(m_event_defs.get(eid, {}).get("route_id", ""))
			if route_id == filter:
				ids.append(eid)
	return ids


# ---------------------------------------------------------------------------
# Depth / layout
# ---------------------------------------------------------------------------

func _compute_depths(visible_ids: Array[String]) -> Dictionary:
	var visible_set: Dictionary = {}
	for eid: String in visible_ids:
		visible_set[eid] = true

	var depth_map: Dictionary = {}
	for eid: String in visible_ids:
		_depth_of(eid, depth_map, visible_set)
	return depth_map


## Returns the depth of event [param eid] in [param depth_map], computing it
## recursively if not yet cached. The guard value -1 breaks cycles safely.
func _depth_of(
	eid: String, depth_map: Dictionary, visible_set: Dictionary
) -> int:
	if depth_map.has(eid):
		return int(depth_map[eid])

	# Cycle guard: mark as -1 before recursing.
	depth_map[eid] = -1

	var edef: Dictionary = m_event_defs.get(eid, {})
	var prereqs := _gather_prereqs(edef)
	var max_prereq_depth := -1
	for prereq: String in prereqs:
		if visible_set.has(prereq):
			var pd: int = _depth_of(prereq, depth_map, visible_set)
			if pd > max_prereq_depth:
				max_prereq_depth = pd

	var d: int = max_prereq_depth + 1
	depth_map[eid] = d
	return d


## Collects all event ids referenced in story_flags_all and story_flags_any
## prerequisites of [param edef].
func _gather_prereqs(edef: Dictionary) -> Array[String]:
	var prereqs: Array[String] = []
	for key: String in [_PREREQ_ALL_KEY, _PREREQ_ANY_KEY]:
		for prereq: String in _prereq_flags_for_key(edef, key):
			if not prereqs.has(prereq):
				prereqs.append(prereq)
	return prereqs


func _prereq_flags_for_key(edef: Dictionary, key: String) -> Array[String]:
	var prereqs: Array[String] = []
	var prereq_val = edef.get("prerequisites", {})
	if not (prereq_val is Dictionary):
		return prereqs

	var flags_val = (prereq_val as Dictionary).get(key, [])
	if not (flags_val is Array):
		return prereqs

	for f_var in flags_val as Array:
		var f: String = str(f_var).strip_edges()
		if not f.is_empty():
			prereqs.append(f)
	return prereqs


## Returns a placement Dictionary mapping event_id -> Vector2 position.
func _compute_placement(
	visible_ids: Array[String], depth_map: Dictionary
) -> Dictionary:
	# Group by depth column.
	var depth_groups: Dictionary = {}   # int -> Array (of String event ids)
	for eid: String in visible_ids:
		var d: int = int(depth_map.get(eid, 0))
		if not depth_groups.has(d):
			depth_groups[d] = []
		(depth_groups[d] as Array).append(eid)

	# Sort within each column: route display_order first, then event id.
	for d in depth_groups.keys():
		(depth_groups[d] as Array).sort_custom(_sort_events_in_column)

	# Compute pixel positions.
	var placement: Dictionary = {}
	for d in depth_groups.keys():
		var grp: Array = depth_groups[d] as Array
		var x: float = float(int(d)) * (_NODE_WIDTH + _COLUMN_GAP) + _LAYOUT_ORIGIN.x
		for i: int in grp.size():
			var y: float = float(i) * (_ROW_HEIGHT + _ROW_GAP) + _LAYOUT_ORIGIN.y
			placement[str(grp[i])] = Vector2(x, y)
	return placement


## Comparator for sort_custom: sorts by route display_order, then event id.
func _sort_events_in_column(a: String, b: String) -> bool:
	var ra: String = str(m_event_defs.get(a, {}).get("route_id", ""))
	var rb: String = str(m_event_defs.get(b, {}).get("route_id", ""))
	var oa: int = int(m_route_defs.get(ra, {}).get("display_order", 9999))
	var ob: int = int(m_route_defs.get(rb, {}).get("display_order", 9999))
	if oa != ob:
		return oa < ob
	return a < b


# ---------------------------------------------------------------------------
# GraphNode creation
# ---------------------------------------------------------------------------

func _create_event_node(eid: String, edef: Dictionary, pos: Vector2) -> void:
	var route_id: String     = str(edef.get("route_id", ""))
	var rdef: Dictionary     = m_route_defs.get(route_id, {})
	var route_color: Color   = _ROUTE_COLORS.get(route_id, _DEFAULT_ROUTE_COLOR)
	var route_display: String = str(rdef.get("display_name", route_id))

	var gnode := GraphNode.new()
	gnode.name            = eid
	gnode.title           = eid
	gnode.position_offset = pos
	gnode.custom_minimum_size = Vector2(_NODE_WIDTH, 0.0)

	# Storyline label — slot 0, carries the output port so the event can be used
	# as a prerequisite for other nodes.
	var route_lbl := Label.new()
	route_lbl.text = route_display
	route_lbl.add_theme_color_override("font_color", route_color)
	route_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	gnode.add_child(route_lbl)

	var all_lbl := Label.new()
	all_lbl.text = "All"
	all_lbl.add_theme_color_override("font_color", _PREREQ_ALL_COLOR)
	all_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	gnode.add_child(all_lbl)

	var any_lbl := Label.new()
	any_lbl.text = "Any"
	any_lbl.add_theme_color_override("font_color", _PREREQ_ANY_COLOR)
	any_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	gnode.add_child(any_lbl)

	# Configure slot 0: right output only, colored by route.
	gnode.set_slot(
		_NODE_OUTPUT_SLOT,
		false, _SLOT_TYPE, route_color,   # left input
		true,  _SLOT_TYPE, route_color    # right output
	)
	gnode.set_slot(
		_NODE_ALL_INPUT_SLOT,
		true,  _SLOT_TYPE, _PREREQ_ALL_COLOR,
		false, _SLOT_TYPE, _PREREQ_ALL_COLOR
	)
	gnode.set_slot(
		_NODE_ANY_INPUT_SLOT,
		true,  _SLOT_TYPE, _PREREQ_ANY_COLOR,
		false, _SLOT_TYPE, _PREREQ_ANY_COLOR
	)

	gnode.position_offset_changed.connect(_on_node_position_offset_changed.bind(eid))
	m_graph_edit.add_child(gnode)
	m_node_map[eid] = gnode


# ---------------------------------------------------------------------------
# Connections
# ---------------------------------------------------------------------------

func _draw_connections(visible_ids: Array[String]) -> void:
	var visible_set: Dictionary = {}
	for eid: String in visible_ids:
		visible_set[eid] = true

	for eid: String in visible_ids:
		var edef: Dictionary = m_event_defs.get(eid, {})
		var target_node: GraphNode = m_node_map.get(eid) as GraphNode
		if not is_instance_valid(target_node):
			continue
		var all_input_port := _find_input_port_index_for_slot(
			target_node,
			_NODE_ALL_INPUT_SLOT
		)
		var any_input_port := _find_input_port_index_for_slot(
			target_node,
			_NODE_ANY_INPUT_SLOT
		)
		for prereq: String in _prereq_flags_for_key(edef, _PREREQ_ALL_KEY):
			if not visible_set.has(prereq):
				continue
			var source_node_all: GraphNode = m_node_map.get(prereq) as GraphNode
			var source_output_port_all := _find_output_port_index_for_slot(
				source_node_all,
				_NODE_OUTPUT_SLOT
			)
			if not is_instance_valid(source_node_all) or source_output_port_all < 0 or all_input_port < 0:
				continue
			# connect_node(from_node, from_port, to_node, to_port)
			# Arrow: prereq output(right) -> eid "All" input(left)
			var err: int = m_graph_edit.connect_node(
				prereq,
				source_output_port_all,
				eid,
				all_input_port
			)
			if err != OK:
				push_warning(
					"StorylineGraphEditor: connect_node(%s -> %s [All]) returned %d"
					% [prereq, eid, err]
				)
		for prereq: String in _prereq_flags_for_key(edef, _PREREQ_ANY_KEY):
			if not visible_set.has(prereq):
				continue
			var source_node_any: GraphNode = m_node_map.get(prereq) as GraphNode
			var source_output_port_any := _find_output_port_index_for_slot(
				source_node_any,
				_NODE_OUTPUT_SLOT
			)
			if not is_instance_valid(source_node_any) or source_output_port_any < 0 or any_input_port < 0:
				continue
			var err: int = m_graph_edit.connect_node(
				prereq,
				source_output_port_any,
				eid,
				any_input_port
			)
			if err != OK:
				push_warning(
					"StorylineGraphEditor: connect_node(%s -> %s [Any]) returned %d"
					% [prereq, eid, err]
				)


func _redraw_connections_after_layout(
	rebuild_token: int,
	visible_ids: Array[String]
) -> void:
	if rebuild_token != m_graph_rebuild_token:
		return
	if m_node_map.is_empty():
		return
	m_graph_edit.clear_connections()
	_draw_connections(visible_ids)
	m_graph_edit.queue_redraw()


func _schedule_connection_redraw_for_visible_graph() -> void:
	if m_node_map.is_empty():
		return
	if not is_visible_in_tree() or not m_graph_edit.is_visible_in_tree():
		return
	call_deferred(
		"_redraw_connections_after_layout",
		m_graph_rebuild_token,
		_visible_event_ids(_current_filter()).duplicate()
	)


func _persist_dependency_change(
	event_id: String,
	prereq_id: String,
	prerequisite_key: String,
	should_add: bool
) -> void:
	event_id = event_id.strip_edges()
	prereq_id = prereq_id.strip_edges()
	if event_id.is_empty() or prereq_id.is_empty():
		return
	if not [_PREREQ_ALL_KEY, _PREREQ_ANY_KEY].has(prerequisite_key):
		push_warning(
			"StorylineGraphEditor: unknown prerequisite bucket '%s'"
			% prerequisite_key
		)
		return
	if event_id == prereq_id:
		push_warning("StorylineGraphEditor: ignored self-dependency on '%s'" % event_id)
		return
	if not m_event_defs.has(event_id):
		push_warning("StorylineGraphEditor: unknown target event '%s'" % event_id)
		return
	if not m_event_defs.has(prereq_id):
		push_warning("StorylineGraphEditor: unknown prerequisite event '%s'" % prereq_id)
		return
	if should_add and _would_create_cycle(prereq_id, event_id):
		push_warning(
			"StorylineGraphEditor: refusing to add %s -> %s because it creates a cycle"
			% [prereq_id, event_id]
		)
		return

	var event_def: Dictionary = m_event_defs.get(event_id, {})
	var route_id := String(event_def.get("route_id", "")).strip_edges()
	if route_id.is_empty():
		push_warning("StorylineGraphEditor: event '%s' has no route_id" % event_id)
		return

	var route_resource := _load_or_materialize_route_resource(route_id)
	if route_resource == null:
		push_warning("StorylineGraphEditor: unable to load route resource for '%s'" % route_id)
		return

	var target_event := _find_event_resource(route_resource, event_id)
	if target_event == null:
		push_warning(
			"StorylineGraphEditor: route '%s' has no editable event '%s'"
			% [route_id, event_id]
		)
		return

	var all_flags: PackedStringArray = target_event.story_flags_all
	var any_flags: PackedStringArray = target_event.story_flags_any
	var target_flags: PackedStringArray = (
		all_flags if prerequisite_key == _PREREQ_ALL_KEY else any_flags
	)
	var other_flags: PackedStringArray = (
		any_flags if prerequisite_key == _PREREQ_ALL_KEY else all_flags
	)
	var changed := false
	if should_add:
		if not target_flags.has(prereq_id):
			target_flags.append(prereq_id)
			changed = true
		var other_idx := other_flags.find(prereq_id)
		if other_idx >= 0:
			other_flags.remove_at(other_idx)
			changed = true
	else:
		var target_idx := target_flags.find(prereq_id)
		if target_idx >= 0:
			target_flags.remove_at(target_idx)
			changed = true

	if not changed:
		return

	if prerequisite_key == _PREREQ_ALL_KEY:
		target_event.story_flags_all = target_flags
		target_event.story_flags_any = other_flags
	else:
		target_event.story_flags_all = other_flags
		target_event.story_flags_any = target_flags

	var save_path := _route_resource_path_for(route_id)
	var save_error := ResourceSaver.save(route_resource, save_path)
	if save_error != OK:
		push_error(
			"StorylineGraphEditor: failed to save '%s' after editing %s -> %s (err=%d)"
			% [save_path, prereq_id, event_id, save_error]
		)
		return

	route_resource.take_over_path(save_path)
	m_route_resource_paths[route_id] = save_path
	var preserved_selected_event_id := m_selected_event_id
	var preserved_scroll_offset := m_graph_edit.scroll_offset
	_refresh_graph()
	catalog_changed.emit()
	call_deferred(
		"_restore_graph_state_after_refresh",
		preserved_selected_event_id,
		preserved_scroll_offset
	)


func _load_or_materialize_route_resource(route_id: String) -> StorylineRouteResource:
	var save_path := _route_resource_path_for(route_id)
	if m_route_resource_paths.has(route_id) and ResourceLoader.exists(save_path):
		var existing_resource := load(save_path)
		if existing_resource is StorylineRouteResource:
			return existing_resource as StorylineRouteResource

	var storyline_dict := _build_storyline_dict_for_route(route_id)
	if storyline_dict.is_empty():
		return null

	var absolute_dir := ProjectSettings.globalize_path(StorylineCatalog.ROUTE_RESOURCE_DIR)
	var make_dir_error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if make_dir_error != OK and make_dir_error != ERR_ALREADY_EXISTS:
		push_error(
			"StorylineGraphEditor: failed to create route resource dir '%s' (err=%d)"
			% [absolute_dir, make_dir_error]
		)
		return null

	var route_resource := StorylineRouteResource.from_storyline_dict(storyline_dict)
	route_resource.take_over_path(save_path)
	return route_resource


func _ensure_route_resource_for_editing(route_id: String) -> StorylineRouteResource:
	var save_path := _route_resource_path_for(route_id)
	var loaded_route_resource := _find_loaded_route_resource(route_id)
	if loaded_route_resource != null:
		var loaded_path := loaded_route_resource.resource_path
		if not loaded_path.is_empty() and loaded_path == save_path:
			m_route_resource_paths[route_id] = loaded_path
			return loaded_route_resource

	var already_exists := ResourceLoader.exists(save_path)
	var route_resource := _load_or_materialize_route_resource(route_id)
	if route_resource == null:
		return null
	if already_exists:
		return route_resource

	var save_error := ResourceSaver.save(route_resource, save_path)
	if save_error != OK:
		push_error(
			"StorylineGraphEditor: failed to save editable route resource '%s' (err=%d)"
			% [save_path, save_error]
		)
		return null

	route_resource.take_over_path(save_path)
	m_route_resource_paths[route_id] = save_path
	catalog_changed.emit()
	return route_resource


func _ensure_event_resource_for_editing(event_id: String) -> StorylineEventResource:
	event_id = event_id.strip_edges()
	if event_id.is_empty():
		return null

	var event_def: Dictionary = m_event_defs.get(event_id, {})
	if event_def.is_empty():
		_load_catalog_data()
		event_def = m_event_defs.get(event_id, {})
		if event_def.is_empty():
			return _find_loaded_event_resource(event_id)

	var route_id := String(event_def.get("route_id", "")).strip_edges()
	if route_id.is_empty():
		return _find_loaded_event_resource(event_id)

	var route_resource := _ensure_route_resource_for_editing(route_id)
	if route_resource == null:
		return _find_loaded_event_resource(event_id)

	var event_resource := _find_event_resource(route_resource, event_id)
	if event_resource != null:
		return event_resource
	return _find_loaded_event_resource(event_id)


func _edit_event_in_inspector(event_id: String) -> void:
	if m_editor_interface == null:
		return

	var event_resource := _ensure_event_resource_for_editing(event_id)
	if event_resource == null:
		return

	m_editor_interface.edit_resource(event_resource)


func edit_event_in_inspector(event_id: String) -> void:
	_edit_event_in_inspector(event_id)


func _edit_route_in_inspector(route_id: String) -> void:
	if m_editor_interface == null:
		return

	var route_resource := _ensure_route_resource_for_editing(route_id)
	if route_resource == null:
		return

	m_editor_interface.edit_resource(route_resource)


func edit_route_in_inspector(route_id: String) -> void:
	_edit_route_in_inspector(route_id)


func _build_storyline_dict_for_route(route_id: String) -> Dictionary:
	var route_def: Dictionary = m_route_defs.get(route_id, {})
	if route_def.is_empty():
		return {}

	var event_dicts: Array[Dictionary] = []
	for event_id_var in m_event_defs.keys():
		var event_id := String(event_id_var)
		var event_def: Dictionary = m_event_defs.get(event_id, {})
		if String(event_def.get("route_id", "")).strip_edges() != route_id:
			continue
		var copied_event := event_def.duplicate(true)
		copied_event.erase("route_id")
		event_dicts.append(copied_event)

	return {
		"path": _route_resource_path_for(route_id),
		"route": route_def.duplicate(true),
		"events": event_dicts,
	}


func _route_resource_path_for(route_id: String) -> String:
	return str(m_route_resource_paths.get(
		route_id,
		"%s/%s.tres" % [StorylineCatalog.ROUTE_RESOURCE_DIR, route_id]
	))


func _find_input_port_index_for_slot(node: GraphNode, slot_index: int) -> int:
	if not is_instance_valid(node):
		return -1
	for port_index in node.get_input_port_count():
		if node.get_input_port_slot(port_index) == slot_index:
			return port_index
	return -1


func _find_output_port_index_for_slot(node: GraphNode, slot_index: int) -> int:
	if not is_instance_valid(node):
		return -1
	for port_index in node.get_output_port_count():
		if node.get_output_port_slot(port_index) == slot_index:
			return port_index
	return -1


func _find_event_resource(
	route_resource: StorylineRouteResource, event_id: String
) -> StorylineEventResource:
	for event_resource: StorylineEventResource in route_resource.events:
		if event_resource != null and event_resource.id.strip_edges() == event_id:
			return event_resource
	return null


func _find_event_resource_index(
	route_resource: StorylineRouteResource, event_id: String
) -> int:
	for event_index: int in route_resource.events.size():
		var event_resource := route_resource.events[event_index]
		if event_resource != null and event_resource.id.strip_edges() == event_id:
			return event_index
	return -1


func _find_loaded_route_resource(route_id: String) -> StorylineRouteResource:
	route_id = route_id.strip_edges()
	if route_id.is_empty():
		return null

	for route_resource: StorylineRouteResource in StorylineCatalog.load_route_resources():
		if route_resource != null and route_resource.id.strip_edges() == route_id:
			return route_resource
	return null


func _find_loaded_event_resource(event_id: String) -> StorylineEventResource:
	event_id = event_id.strip_edges()
	if event_id.is_empty():
		return null

	for route_resource: StorylineRouteResource in StorylineCatalog.load_route_resources():
		var event_resource := _find_event_resource(route_resource, event_id)
		if event_resource != null:
			return event_resource
	return null


func _clear_inspector_if_editing_deleted_event(event_id: String) -> void:
	if m_editor_interface == null:
		return
	var inspector := m_editor_interface.get_inspector()
	if inspector == null:
		return
	if _should_clear_inspector_for_deleted_event(
		event_id,
		inspector.get_edited_object()
	):
		inspector.edit(null)


func _should_clear_inspector_for_deleted_event(
	event_id: String, edited_object: Object
) -> bool:
	event_id = event_id.strip_edges()
	if event_id.is_empty() or edited_object == null:
		return false
	return (
		edited_object is StorylineEventResource
		and (edited_object as StorylineEventResource).id.strip_edges() == event_id
	)


func _would_create_cycle(prereq_id: String, event_id: String) -> bool:
	var adjacency: Dictionary = {}
	for node_id_var in m_event_defs.keys():
		var node_id := String(node_id_var)
		var event_def: Dictionary = m_event_defs.get(node_id, {})
		for existing_prereq: String in _gather_prereqs(event_def):
			if not adjacency.has(existing_prereq):
				adjacency[existing_prereq] = []
			(adjacency[existing_prereq] as Array).append(node_id)
	return _can_reach_dependent(event_id, prereq_id, adjacency, {})


func _can_reach_dependent(
	current_id: String, target_id: String, adjacency: Dictionary, visited: Dictionary
) -> bool:
	if current_id == target_id:
		return true
	if visited.has(current_id):
		return false
	visited[current_id] = true

	var next_nodes = adjacency.get(current_id, [])
	if next_nodes is Array:
		for next_id_var in next_nodes as Array:
			if _can_reach_dependent(
				String(next_id_var), target_id, adjacency, visited
			):
				return true
	return false


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


## Joins all elements of [param arr] as strings with [param sep].
func _join_str(arr: Array, sep: String) -> String:
	var parts := PackedStringArray()
	for item in arr:
		parts.append(str(item))
	return sep.join(parts)


func _configure_disconnect_drag() -> void:
	if m_graph_edit == null:
		return
	m_graph_edit.right_disconnects = true
	_allow_disconnect_drag_type(_SLOT_TYPE, false)
	_allow_disconnect_drag_type(_SLOT_TYPE, true)


func _allow_disconnect_drag_type(slot_type: int, right_side: bool) -> void:
	if m_graph_edit == null:
		return
	if right_side:
		m_graph_edit.add_valid_right_disconnect_type(slot_type)
		m_right_disconnect_types[slot_type] = true
		return
	m_graph_edit.add_valid_left_disconnect_type(slot_type)
	m_left_disconnect_types[slot_type] = true


func _supports_disconnect_drag_type(slot_type: int, right_side: bool) -> bool:
	var allowed_types := m_right_disconnect_types if right_side else m_left_disconnect_types
	return bool(allowed_types.get(slot_type, false))


# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

## Selects the GraphNode for [param event_id], scrolling it into view and
## showing its details. Called by the plugin when the route browser requests
## "Show in Graph". Rebuilds first if the event is not currently visible
## (e.g. because of the active route filter).
func select_event(event_id: String, center_view: bool = true) -> void:
	if not m_event_defs.has(event_id):
		_refresh_graph()
	if not m_node_map.has(event_id):
		# Event may be filtered out — clear the filter and rebuild.
		m_route_filter.selected = 0
		_rebuild_graph()

	var gnode: GraphNode = m_node_map.get(event_id) as GraphNode
	if not is_instance_valid(gnode):
		return

	# Deselect all, then select the target node.
	for node_key in m_node_map.keys():
		var n: GraphNode = m_node_map[node_key] as GraphNode
		if is_instance_valid(n):
			n.selected = false
	gnode.selected = true

	if center_view:
		# Scroll to center the node.
		var center: Vector2 = gnode.position_offset + gnode.size * 0.5
		m_graph_edit.scroll_offset = center - m_graph_edit.size * 0.5


func _restore_graph_state_after_refresh(
	selected_event_id: String, preserved_scroll_offset: Vector2
) -> void:
	if not selected_event_id.strip_edges().is_empty():
		select_event(selected_event_id, false)
	m_graph_edit.scroll_offset = preserved_scroll_offset


func _on_watched_route_resource_changed() -> void:
	_queue_graph_refresh()


func _on_filter_changed(_idx: int) -> void:
	_rebuild_graph()


func _on_connection_drag_started(
	_from_node: StringName, _from_port: int, _is_output: bool
) -> void:
	m_connection_drag_selected_event_id = m_selected_event_id
	m_graph_edit.add_theme_color_override("selection_fill", Color(0.0, 0.0, 0.0, 0.0))
	m_graph_edit.add_theme_color_override("selection_stroke", Color(0.0, 0.0, 0.0, 0.0))


func _on_connection_drag_ended() -> void:
	call_deferred("_restore_selection_after_connection_drag")


func _restore_selection_after_connection_drag() -> void:
	m_graph_edit.remove_theme_color_override("selection_fill")
	m_graph_edit.remove_theme_color_override("selection_stroke")

	var preserved_event_id := m_connection_drag_selected_event_id
	m_connection_drag_selected_event_id = ""

	if preserved_event_id.strip_edges().is_empty():
		for node_key in m_node_map.keys():
			var node: GraphNode = m_node_map[node_key] as GraphNode
			if is_instance_valid(node):
				node.selected = false
		m_selected_event_id = ""
		return

	select_event(preserved_event_id, false)


func _on_node_position_offset_changed(event_id: String) -> void:
	var node: GraphNode = m_node_map.get(event_id) as GraphNode
	if is_instance_valid(node):
		m_layout_positions[event_id] = node.position_offset


func _on_graph_editor_visibility_changed() -> void:
	_schedule_connection_redraw_for_visible_graph()


func _on_graph_edit_resized() -> void:
	_schedule_connection_redraw_for_visible_graph()


func _on_connection_request(
	from_node: StringName, _from_port: int, to_node: StringName, to_port: int
) -> void:
	var prerequisite_key := _prerequisite_key_for_input_port(String(to_node), to_port)
	if prerequisite_key.is_empty():
		return
	_persist_dependency_change(
		String(to_node),
		String(from_node),
		prerequisite_key,
		true
	)


func _on_disconnection_request(
	from_node: StringName, _from_port: int, to_node: StringName, to_port: int
) -> void:
	var prerequisite_key := _prerequisite_key_for_input_port(String(to_node), to_port)
	if prerequisite_key.is_empty():
		return
	_persist_dependency_change(
		String(to_node),
		String(from_node),
		prerequisite_key,
		false
	)


func _prerequisite_key_for_input_port(to_node_name: String, to_port: int) -> String:
	var node: GraphNode = m_node_map.get(to_node_name) as GraphNode
	if not is_instance_valid(node):
		push_warning(
			"StorylineGraphEditor: missing target node '%s' for input port %d"
			% [to_node_name, to_port]
		)
		return ""
	if to_port < 0 or to_port >= node.get_input_port_count():
		push_warning(
			"StorylineGraphEditor: unsupported input port %d on '%s'"
			% [to_port, to_node_name]
		)
		return ""

	var slot_index := node.get_input_port_slot(to_port)
	match slot_index:
		_NODE_ALL_INPUT_SLOT:
			return _PREREQ_ALL_KEY
		_NODE_ANY_INPUT_SLOT:
			return _PREREQ_ANY_KEY
		_:
			push_warning(
				"StorylineGraphEditor: unsupported prerequisite slot %d on '%s'"
				% [slot_index, to_node_name]
			)
			return ""


func _on_node_selected(node: Node) -> void:
	if not (node is GraphNode):
		return
	m_selected_event_id = node.name
	_edit_event_in_inspector(m_selected_event_id)


func _on_node_deselected(_node: Node) -> void:
	m_selected_event_id = ""
