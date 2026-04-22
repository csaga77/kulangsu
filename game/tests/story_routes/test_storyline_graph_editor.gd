extends Node

const GRAPH_EDITOR_SCRIPT := preload("res://addons/storyline_editor/storyline_graph_editor.gd")
const ROUTE_EVENT_PANEL_SCRIPT := preload(
	"res://addons/storyline_editor/storyline_route_event_panel.gd"
)

const _TEMP_DIR := "user://storyline_graph_editor_test"
const _TEMP_ROUTE_PATH := "user://storyline_graph_editor_test/family_memory.tres"
const _TEMP_LAYOUT_STATE_PATH := "user://storyline_graph_editor_test/graph_layout.cfg"
const _TEMP_SYNC_ROUTE_PATH := "res://game/storylines/routes/__storyline_graph_editor_sync_route.tres"
const _TEMP_SYNC_ROUTE_ID := "storyline_graph_editor_sync_route"
const _LIVE_MELODY_ROUTE_PATH := "res://game/storylines/routes/melody_landmarks.tres"

var m_failures := PackedStringArray()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var temp_dir_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(_TEMP_DIR)
	)
	_assert_true(
		temp_dir_error == OK or temp_dir_error == ERR_ALREADY_EXISTS,
		"Graph editor test temp directory is available"
	)
	_cleanup_temp_route()
	_cleanup_temp_layout_state()
	_cleanup_temp_sync_route()
	var live_melody_route_snapshot := _read_text_file(_LIVE_MELODY_ROUTE_PATH)

	var graph_editor = GRAPH_EDITOR_SCRIPT.new()
	graph_editor.m_layout_state_path = _TEMP_LAYOUT_STATE_PATH
	add_child(graph_editor)
	await get_tree().process_frame
	graph_editor._refresh_graph()
	await get_tree().process_frame

	var inspected_deleted_event := StorylineEventResource.new()
	inspected_deleted_event.id = "summer_return_complete"
	var inspected_other_event := StorylineEventResource.new()
	inspected_other_event.id = "spring_festival_prepared"
	var inspected_target_event := StorylineEventResource.new()
	inspected_target_event.id = "winter_memory_reveal"
	var inspected_route := StorylineRouteResource.new()
	inspected_route.id = "family_memory"
	var updated_target_event := StorylineEventResource.new()
	updated_target_event.id = "winter_memory_reveal"
	var updated_target_route := StorylineRouteResource.new()
	updated_target_route.id = "family_memory"
	_assert_true(
		graph_editor._should_clear_inspector_for_deleted_event(
			"summer_return_complete",
			inspected_deleted_event
		),
		"Graph editor clears the inspector for the deleted event resource"
	)
	_assert_true(
		not graph_editor._should_clear_inspector_for_deleted_event(
			"summer_return_complete",
			inspected_other_event
		),
		"Graph editor keeps other event resources in the inspector"
	)
	_assert_true(
		not graph_editor._should_clear_inspector_for_deleted_event(
			"summer_return_complete",
			inspected_route
		),
		"Graph editor keeps route resources in the inspector when deleting an event"
	)
	_assert_true(
		graph_editor._inspector_resource_to_refresh_for_storyline_change(
			updated_target_route,
			updated_target_event,
			inspected_target_event
		) == updated_target_event,
		"Graph editor refreshes the inspector when the edited target event changes"
	)
	_assert_true(
		graph_editor._inspector_resource_to_refresh_for_storyline_change(
			updated_target_route,
			updated_target_event,
			inspected_route
		) == updated_target_route,
		"Graph editor refreshes the inspector when the owning route is open"
	)
	_assert_true(
		graph_editor._inspector_resource_to_refresh_for_storyline_change(
			updated_target_route,
			updated_target_event,
			inspected_other_event
		) == null,
		"Graph editor leaves unrelated inspected events alone after dependency edits"
	)
	_assert_true(
		graph_editor.m_graph_edit.right_disconnects,
		"Graph editor enables drag disconnects from output ports"
	)
	_assert_true(
		graph_editor._supports_disconnect_drag_type(0, false),
		"Graph editor enables drag disconnects from input ports for the storyline slot type"
	)
	_assert_true(
		graph_editor._supports_disconnect_drag_type(0, true),
		"Graph editor enables drag disconnects from output ports for the storyline slot type"
	)

	var visible_event_ids := graph_editor._visible_event_ids("")
	var expected_initial_connection_count := 0
	for event_id: String in visible_event_ids:
		expected_initial_connection_count += graph_editor._gather_prereqs(
			graph_editor.m_event_defs.get(event_id, {})
		).size()
	var initial_connections: Array = graph_editor.m_graph_edit.get_connection_list()
	_assert_true(
		initial_connections.size() == expected_initial_connection_count,
		"Graph editor draws the expected connections on first open"
	)
	graph_editor.m_graph_edit.clear_connections()
	graph_editor._schedule_connection_redraw_for_visible_graph()
	await get_tree().process_frame
	await get_tree().process_frame
	var restored_connections: Array = graph_editor.m_graph_edit.get_connection_list()
	_assert_true(
		restored_connections.size() == expected_initial_connection_count,
		"Graph editor can redraw connections after a visible-panel refresh"
	)

	var layout_anchor: GraphNode = graph_editor.m_node_map.get("summer_return_complete") as GraphNode
	_assert_true(layout_anchor != null, "Graph editor builds an initial node map")
	if layout_anchor != null:
		_assert_true(
			layout_anchor.title == "summer_return_complete",
			"Graph editor node titles use the story event id"
		)
		var anchor_labels: Array[Label] = []
		for child: Node in layout_anchor.get_children():
			if child is Label:
				anchor_labels.append(child as Label)
		_assert_true(
			anchor_labels.size() == 3,
			"Graph editor nodes show storyline plus All and Any connection rows"
		)
		if anchor_labels.size() == 3:
			_assert_true(
				anchor_labels[0].text == "Family and Memory",
				"Graph editor nodes show the owning storyline in the body"
			)
			_assert_true(
				anchor_labels[1].text == "All",
				"Graph editor nodes expose an All prerequisite slot"
			)
			_assert_true(
				anchor_labels[2].text == "Any",
				"Graph editor nodes expose an Any prerequisite slot"
			)
		var custom_position := Vector2(640.0, 320.0)
		layout_anchor.position_offset = custom_position
		graph_editor._rebuild_graph()
		var rebuilt_anchor: GraphNode = graph_editor.m_node_map.get("summer_return_complete") as GraphNode
		_assert_true(rebuilt_anchor != null, "Graph editor rebuild keeps the moved node available")
		if rebuilt_anchor != null:
			_assert_true(
				rebuilt_anchor.position_offset.is_equal_approx(custom_position),
				"Graph editor rebuild preserves manually arranged node positions"
			)
		var auto_depth_map := graph_editor._compute_depths(visible_event_ids)
		var auto_placement := graph_editor._compute_placement(
			visible_event_ids,
			auto_depth_map
		)
		var expected_auto_position: Vector2 = auto_placement.get(
			"summer_return_complete",
			Vector2.ZERO
		)
		graph_editor._arrange_visible_nodes()
		await get_tree().process_frame
		var arranged_anchor: GraphNode = graph_editor.m_node_map.get("summer_return_complete") as GraphNode
		_assert_true(arranged_anchor != null, "Graph editor arrange keeps the moved node available")
		if arranged_anchor != null:
			_assert_true(
				arranged_anchor.position_offset.is_equal_approx(expected_auto_position),
				"Graph editor arrange resets visible nodes to automatic layout"
			)
			arranged_anchor.position_offset = custom_position
			graph_editor._rebuild_graph()
		graph_editor._capture_current_layout_positions()
		graph_editor._save_persisted_layout_state()

	graph_editor.queue_free()
	await get_tree().process_frame

	var reopened_graph_editor = GRAPH_EDITOR_SCRIPT.new()
	reopened_graph_editor.m_layout_state_path = _TEMP_LAYOUT_STATE_PATH
	add_child(reopened_graph_editor)
	await get_tree().process_frame
	reopened_graph_editor._refresh_graph()

	var reopened_anchor: GraphNode = reopened_graph_editor.m_node_map.get("summer_return_complete") as GraphNode
	_assert_true(reopened_anchor != null, "Reopened graph editor restores the saved node")
	if reopened_anchor != null:
		_assert_true(
			reopened_anchor.position_offset.is_equal_approx(Vector2(640.0, 320.0)),
			"Graph editor persists layout across editor instances"
		)

	graph_editor = reopened_graph_editor

	graph_editor.select_event("summer_return_complete", false)
	graph_editor._on_connection_drag_started(&"summer_return_complete", 0, true)
	var accidental_target_selection: GraphNode = graph_editor.m_node_map.get("spring_festival_prepared") as GraphNode
	_assert_true(accidental_target_selection != null, "Connection-drag selection test can find the target node")
	if accidental_target_selection != null:
		accidental_target_selection.selected = true
	graph_editor._on_connection_drag_ended()
	await get_tree().process_frame

	var restored_selection: GraphNode = graph_editor.m_node_map.get("summer_return_complete") as GraphNode
	var restored_target: GraphNode = graph_editor.m_node_map.get("spring_festival_prepared") as GraphNode
	_assert_true(restored_selection != null, "Connection-drag restore keeps the original node available")
	_assert_true(restored_target != null, "Connection-drag restore keeps the target node available")
	if restored_selection != null:
		_assert_true(
			restored_selection.selected,
			"Connection drag restores the prior selection"
		)
	if restored_target != null:
		_assert_true(
			not restored_target.selected,
			"Connection drag does not leave accidental target selection behind"
		)

	graph_editor._load_catalog_data()
	graph_editor.m_route_resource_paths["family_memory"] = _TEMP_ROUTE_PATH
	var editable_event := graph_editor._ensure_event_resource_for_editing("spring_festival_prepared")
	_assert_true(
		editable_event != null,
		"Graph editor can resolve an editable event resource for inspector editing"
	)
	if editable_event != null:
		_assert_true(
			editable_event.id == "spring_festival_prepared",
			"Editable event resource matches the selected graph node"
		)
	_assert_true(
		FileAccess.file_exists(ProjectSettings.globalize_path(_TEMP_ROUTE_PATH)),
		"Inspector editing path materializes a saved route resource when needed"
	)
	_cleanup_temp_route()

	graph_editor._load_catalog_data()
	var live_route_resource := _load_live_route_resource("melody_landmarks")
	_assert_true(
		live_route_resource != null,
		"Graph editor stale-catalog test can load a typed route resource"
	)
	if live_route_resource != null:
		var route_event_panel = ROUTE_EVENT_PANEL_SCRIPT.new()
		route_event_panel.setup(live_route_resource)
		add_child(route_event_panel)
		await get_tree().process_frame
		var panel_added_event_id := live_route_resource.next_default_event_id()
		route_event_panel._on_add_event_pressed()
		await get_tree().process_frame
		await get_tree().process_frame
		_assert_true(
			graph_editor.m_node_map.has(panel_added_event_id),
			"Graph editor reflects route-panel event adds without a manual refresh"
		)
		route_event_panel._on_remove_event_pressed(live_route_resource.events.size() - 1)
		_assert_true(
			graph_editor.m_node_map.has(panel_added_event_id),
			"Graph editor keeps the event node until delete confirmation"
		)
		route_event_panel._confirm_delete_event()
		await get_tree().process_frame
		await get_tree().process_frame
		_assert_true(
			not graph_editor.m_node_map.has(panel_added_event_id),
			"Graph editor reflects route-panel event deletes after confirmation"
		)
		route_event_panel.queue_free()
		await get_tree().process_frame

		_create_temp_sync_route()
		graph_editor.refresh_from_disk()
		await get_tree().process_frame
		_assert_true(
			graph_editor.m_route_defs.has(_TEMP_SYNC_ROUTE_ID),
			"Graph editor refresh picks up a newly created route resource"
		)
		_assert_true(
			_route_filter_has_route(graph_editor, _TEMP_SYNC_ROUTE_ID),
			"Graph editor route filter includes the newly created route"
		)
		_cleanup_temp_sync_route()
		graph_editor.refresh_from_disk()
		await get_tree().process_frame
		_assert_true(
			not graph_editor.m_route_defs.has(_TEMP_SYNC_ROUTE_ID),
			"Graph editor refresh drops a deleted route resource"
		)
		_assert_true(
			not _route_filter_has_route(graph_editor, _TEMP_SYNC_ROUTE_ID),
			"Graph editor route filter drops the deleted route"
		)

		var live_test_event := StorylineEventResource.new()
		live_test_event.id = "melody_landmarks_new_event_live_test"
		live_test_event.lead_text = "Live event"
		live_test_event.journal_note = "Created after the graph editor snapshot."
		live_test_event.status_text = "Live event status."
		live_test_event.phase_window = PackedStringArray(["summer_1"])

		var updated_live_events: Array[StorylineEventResource] = live_route_resource.events.duplicate()
		updated_live_events.append(live_test_event)
		live_route_resource.events = updated_live_events
		live_route_resource.emit_changed()

		var live_editable_event := graph_editor._ensure_event_resource_for_editing(
			"melody_landmarks_new_event_live_test"
		)
		_assert_true(
			live_editable_event != null,
			"Graph editor can resolve a newly created cached event resource for inspector editing"
		)
		if live_editable_event != null:
			_assert_true(
				live_editable_event.id == "melody_landmarks_new_event_live_test",
				"Graph editor resolves the newly created cached event by id"
			)

		graph_editor.select_event("melody_landmarks_new_event_live_test", false)
		var live_node := graph_editor.m_node_map.get("melody_landmarks_new_event_live_test") as GraphNode
		_assert_true(
			live_node != null,
			"Graph editor can rebuild and select a newly created cached event"
		)
		graph_editor.delete_event("melody_landmarks_new_event_live_test")
		await get_tree().process_frame
		var refreshed_live_route := _load_live_route_resource("melody_landmarks")
		_assert_true(
			_find_event(refreshed_live_route, "melody_landmarks_new_event_live_test") == null,
			"Graph editor can delete a newly created cached event"
		)
		_assert_true(
			not graph_editor.m_node_map.has("melody_landmarks_new_event_live_test"),
			"Graph editor removes the deleted event node after refresh"
		)

	graph_editor._load_catalog_data()
	graph_editor.m_route_resource_paths["family_memory"] = _TEMP_ROUTE_PATH
	graph_editor.select_event("summer_return_complete", false)
	graph_editor.m_graph_edit.scroll_offset = Vector2(920.0, 480.0)
	var summer_return_node := graph_editor.m_node_map.get("summer_return_complete") as GraphNode
	var spring_prepared_node := graph_editor.m_node_map.get("spring_festival_prepared") as GraphNode
	var source_output_port := graph_editor._find_output_port_index_for_slot(summer_return_node, 0)
	var all_input_port := graph_editor._find_input_port_index_for_slot(spring_prepared_node, 1)
	graph_editor._on_connection_request(
		&"summer_return_complete",
		source_output_port,
		&"spring_festival_prepared",
		all_input_port
	)
	await get_tree().process_frame

	var promoted_route := _load_temp_route()
	_assert_true(promoted_route != null, "Graph editor materializes a legacy route resource on first edit")
	_assert_true(
		graph_editor.m_graph_edit.scroll_offset.is_equal_approx(Vector2(920.0, 480.0)),
		"Graph editor preserves scroll position after connect"
	)
	var selected_after_connect: GraphNode = graph_editor.m_node_map.get("summer_return_complete") as GraphNode
	var target_after_connect: GraphNode = graph_editor.m_node_map.get("spring_festival_prepared") as GraphNode
	_assert_true(selected_after_connect != null, "Connect keeps the originally selected node available")
	_assert_true(target_after_connect != null, "Connect keeps the target node available")
	if selected_after_connect != null:
		_assert_true(
			selected_after_connect.selected,
			"Connect preserves the previously selected node"
		)
	if target_after_connect != null:
		_assert_true(
			not target_after_connect.selected,
			"Connect does not auto-select the target node"
		)
	if promoted_route != null:
		var prepared_event := _find_event(promoted_route, "spring_festival_prepared")
		_assert_true(prepared_event != null, "Materialized route preserves the edited target event")
		if prepared_event != null:
			_assert_true(
				prepared_event.story_flags_all.has("summer_return_complete"),
				"Graph editor All-slot connect adds the new hard prerequisite"
			)
			_assert_true(
				prepared_event.story_flags_all.has("winter_memory_reveal"),
				"Graph editor All-slot connect preserves existing hard prerequisites"
			)
			_assert_true(
				prepared_event.story_flags_all.has("preservation_inheritance_seen"),
				"Graph editor All-slot connect keeps cross-route prerequisites intact"
			)
			_assert_true(
				not prepared_event.story_flags_any.has("summer_return_complete"),
				"Graph editor All-slot connect does not also add an Any prerequisite"
			)

	graph_editor._load_catalog_data()
	graph_editor.m_route_resource_paths["family_memory"] = _TEMP_ROUTE_PATH
	graph_editor.m_graph_edit.scroll_offset = Vector2(780.0, 260.0)
	summer_return_node = graph_editor.m_node_map.get("summer_return_complete") as GraphNode
	spring_prepared_node = graph_editor.m_node_map.get("spring_festival_prepared") as GraphNode
	source_output_port = graph_editor._find_output_port_index_for_slot(summer_return_node, 0)
	all_input_port = graph_editor._find_input_port_index_for_slot(spring_prepared_node, 1)
	graph_editor._on_disconnection_request(
		&"summer_return_complete",
		source_output_port,
		&"spring_festival_prepared",
		all_input_port
	)
	await get_tree().process_frame

	var trimmed_route := _load_temp_route()
	_assert_true(trimmed_route != null, "Graph editor preserves the temp route resource after disconnect")
	_assert_true(
		graph_editor.m_graph_edit.scroll_offset.is_equal_approx(Vector2(780.0, 260.0)),
		"Graph editor preserves scroll position after disconnect"
	)
	var selected_after_disconnect: GraphNode = graph_editor.m_node_map.get("summer_return_complete") as GraphNode
	var target_after_disconnect: GraphNode = graph_editor.m_node_map.get("spring_festival_prepared") as GraphNode
	_assert_true(selected_after_disconnect != null, "Disconnect keeps the originally selected node available")
	_assert_true(target_after_disconnect != null, "Disconnect keeps the target node available")
	if selected_after_disconnect != null:
		_assert_true(
			selected_after_disconnect.selected,
			"Disconnect preserves the previously selected node"
		)
	if target_after_disconnect != null:
		_assert_true(
			not target_after_disconnect.selected,
			"Disconnect does not auto-select the target node"
		)
	if trimmed_route != null:
		var trimmed_event := _find_event(trimmed_route, "spring_festival_prepared")
		_assert_true(trimmed_event != null, "Disconnect keeps the target event editable")
		if trimmed_event != null:
			_assert_true(
				not trimmed_event.story_flags_all.has("summer_return_complete"),
				"Graph editor All-slot disconnect removes the target prerequisite"
			)
			_assert_true(
				not trimmed_event.story_flags_any.has("summer_return_complete"),
				"Graph editor All-slot disconnect leaves Any prerequisites cleared"
			)

	graph_editor._load_catalog_data()
	graph_editor.m_route_resource_paths["family_memory"] = _TEMP_ROUTE_PATH
	graph_editor.m_graph_edit.scroll_offset = Vector2(640.0, 180.0)
	summer_return_node = graph_editor.m_node_map.get("summer_return_complete") as GraphNode
	spring_prepared_node = graph_editor.m_node_map.get("spring_festival_prepared") as GraphNode
	source_output_port = graph_editor._find_output_port_index_for_slot(summer_return_node, 0)
	var any_input_port := graph_editor._find_input_port_index_for_slot(spring_prepared_node, 2)
	graph_editor._on_connection_request(
		&"summer_return_complete",
		source_output_port,
		&"spring_festival_prepared",
		any_input_port
	)
	await get_tree().process_frame

	var any_route := _load_temp_route()
	_assert_true(any_route != null, "Graph editor preserves the temp route resource after Any connect")
	_assert_true(
		graph_editor.m_graph_edit.scroll_offset.is_equal_approx(Vector2(640.0, 180.0)),
		"Graph editor preserves scroll position after Any connect"
	)
	if any_route != null:
		var any_event := _find_event(any_route, "spring_festival_prepared")
		_assert_true(any_event != null, "Any connect keeps the target event editable")
		if any_event != null:
			_assert_true(
				any_event.story_flags_any.has("summer_return_complete"),
				"Graph editor Any-slot connect adds an optional prerequisite"
			)
			_assert_true(
				not any_event.story_flags_all.has("summer_return_complete"),
				"Graph editor Any-slot connect does not add a hard prerequisite"
			)

	graph_editor._load_catalog_data()
	graph_editor.m_route_resource_paths["family_memory"] = _TEMP_ROUTE_PATH
	graph_editor.m_graph_edit.scroll_offset = Vector2(610.0, 140.0)
	summer_return_node = graph_editor.m_node_map.get("summer_return_complete") as GraphNode
	spring_prepared_node = graph_editor.m_node_map.get("spring_festival_prepared") as GraphNode
	source_output_port = graph_editor._find_output_port_index_for_slot(summer_return_node, 0)
	any_input_port = graph_editor._find_input_port_index_for_slot(spring_prepared_node, 2)
	graph_editor._on_disconnection_request(
		&"summer_return_complete",
		source_output_port,
		&"spring_festival_prepared",
		any_input_port
	)
	await get_tree().process_frame

	var any_trimmed_route := _load_temp_route()
	_assert_true(any_trimmed_route != null, "Graph editor preserves the temp route resource after Any disconnect")
	_assert_true(
		graph_editor.m_graph_edit.scroll_offset.is_equal_approx(Vector2(610.0, 140.0)),
		"Graph editor preserves scroll position after Any disconnect"
	)
	if any_trimmed_route != null:
		var any_trimmed_event := _find_event(any_trimmed_route, "spring_festival_prepared")
		_assert_true(any_trimmed_event != null, "Any disconnect keeps the target event editable")
		if any_trimmed_event != null:
			_assert_true(
				not any_trimmed_event.story_flags_any.has("summer_return_complete"),
				"Graph editor Any-slot disconnect removes the optional prerequisite"
			)

	graph_editor._load_catalog_data()
	graph_editor.m_route_resource_paths["family_memory"] = _TEMP_ROUTE_PATH
	var spring_source_node := graph_editor.m_node_map.get("spring_festival_prepared") as GraphNode
	var summer_target_node := graph_editor.m_node_map.get("summer_return_complete") as GraphNode
	var reverse_source_output_port := graph_editor._find_output_port_index_for_slot(spring_source_node, 0)
	var reverse_all_input_port := graph_editor._find_input_port_index_for_slot(summer_target_node, 1)
	graph_editor._on_connection_request(
		&"spring_festival_prepared",
		reverse_source_output_port,
		&"summer_return_complete",
		reverse_all_input_port
	)
	await get_tree().process_frame

	var cycle_checked_route := _load_temp_route()
	_assert_true(cycle_checked_route != null, "Cycle-guard check still leaves a readable route resource")
	if cycle_checked_route != null:
		var anchor_event := _find_event(cycle_checked_route, "summer_return_complete")
		_assert_true(anchor_event != null, "Cycle-guard check preserves the anchor event")
		if anchor_event != null:
			_assert_true(
				not anchor_event.story_flags_all.has("spring_festival_prepared"),
				"Graph editor refuses reverse All-slot dependencies that would create a cycle"
			)

	_cleanup_temp_route()
	_cleanup_temp_layout_state()
	_cleanup_temp_sync_route()
	_restore_text_file(_LIVE_MELODY_ROUTE_PATH, live_melody_route_snapshot)

	if m_failures.is_empty():
		print("PASS: storyline graph editor persistence")
	else:
		for failure in m_failures:
			push_error(failure)
		push_error("Storyline graph editor persistence failed with %d issue(s)." % m_failures.size())

	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0 if m_failures.is_empty() else 1)


func _load_temp_route() -> StorylineRouteResource:
	var resource := ResourceLoader.load(
		_TEMP_ROUTE_PATH,
		"",
		ResourceLoader.CACHE_MODE_REPLACE
	)
	return resource as StorylineRouteResource


func _load_live_route_resource(route_id: String) -> StorylineRouteResource:
	for route_resource: StorylineRouteResource in StorylineCatalog.load_route_resources():
		if route_resource != null and route_resource.id.strip_edges() == route_id:
			return route_resource
	return null


func _route_filter_has_route(graph_editor: Control, route_id: String) -> bool:
	for item_index: int in graph_editor.m_route_filter.item_count:
		if String(graph_editor.m_route_filter.get_item_metadata(item_index)).strip_edges() == route_id:
			return true
	return false


func _find_event(
	route_resource: StorylineRouteResource, event_id: String
) -> StorylineEventResource:
	for event_resource: StorylineEventResource in route_resource.events:
		if event_resource != null and event_resource.id == event_id:
			return event_resource
	return null


func _cleanup_temp_route() -> void:
	var abs_path := ProjectSettings.globalize_path(_TEMP_ROUTE_PATH)
	if FileAccess.file_exists(abs_path):
		var remove_error := DirAccess.remove_absolute(abs_path)
		_assert_true(remove_error == OK, "Graph editor test temp resource cleanup succeeds")


func _cleanup_temp_layout_state() -> void:
	var abs_path := ProjectSettings.globalize_path(_TEMP_LAYOUT_STATE_PATH)
	if FileAccess.file_exists(abs_path):
		var remove_error := DirAccess.remove_absolute(abs_path)
		_assert_true(remove_error == OK, "Graph editor test temp layout cleanup succeeds")


func _create_temp_sync_route() -> void:
	_cleanup_temp_sync_route()
	var route_resource := StorylineRouteResource.new()
	route_resource.id = _TEMP_SYNC_ROUTE_ID
	route_resource.display_name = "Graph Sync Route"
	route_resource.display_order = 9997
	var save_error := ResourceSaver.save(route_resource, _TEMP_SYNC_ROUTE_PATH)
	_assert_true(save_error == OK, "Graph editor test temp sync route save succeeds")


func _cleanup_temp_sync_route() -> void:
	var abs_path := ProjectSettings.globalize_path(_TEMP_SYNC_ROUTE_PATH)
	if FileAccess.file_exists(abs_path):
		var remove_error := DirAccess.remove_absolute(abs_path)
		_assert_true(remove_error == OK, "Graph editor test temp sync route cleanup succeeds")


func _read_text_file(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


func _restore_text_file(path: String, contents: String) -> void:
	if contents.is_empty():
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	_assert_true(file != null, "Graph editor test can restore %s" % path)
	if file == null:
		return
	file.store_string(contents)


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	m_failures.append("%s." % label)
