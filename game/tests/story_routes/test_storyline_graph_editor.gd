extends Node

const GRAPH_EDITOR_SCRIPT := preload("res://addons/storyline_editor/storyline_graph_editor.gd")

const _TEMP_DIR := "user://storyline_graph_editor_test"
const _TEMP_ROUTE_PATH := "user://storyline_graph_editor_test/family_memory.tres"
const _TEMP_LAYOUT_STATE_PATH := "user://storyline_graph_editor_test/graph_layout.cfg"

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

	var graph_editor = GRAPH_EDITOR_SCRIPT.new()
	graph_editor.m_layout_state_path = _TEMP_LAYOUT_STATE_PATH
	add_child(graph_editor)
	await get_tree().process_frame
	graph_editor._refresh_graph()

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
			anchor_labels.size() == 1,
			"Graph editor nodes show only one body label beneath the title"
		)
		if anchor_labels.size() == 1:
			_assert_true(
				anchor_labels[0].text == "Family and Memory",
				"Graph editor nodes show the owning storyline in the body"
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
		var visible_event_ids := graph_editor._visible_event_ids("")
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
	graph_editor.m_route_resource_paths["family_memory"] = _TEMP_ROUTE_PATH
	graph_editor.select_event("summer_return_complete", false)
	graph_editor.m_graph_edit.scroll_offset = Vector2(920.0, 480.0)
	graph_editor._persist_dependency_change(
		"spring_festival_prepared",
		"summer_return_complete",
		true
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
				"Graph editor connect adds the new hard prerequisite"
			)
			_assert_true(
				prepared_event.story_flags_all.has("winter_memory_reveal"),
				"Graph editor connect preserves existing hard prerequisites"
			)
			_assert_true(
				prepared_event.story_flags_all.has("preservation_inheritance_seen"),
				"Graph editor connect keeps cross-route prerequisites intact"
			)

	graph_editor._load_catalog_data()
	graph_editor.m_route_resource_paths["family_memory"] = _TEMP_ROUTE_PATH
	graph_editor.m_graph_edit.scroll_offset = Vector2(780.0, 260.0)
	graph_editor._persist_dependency_change(
		"spring_festival_prepared",
		"summer_return_complete",
		false
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
				"Graph editor disconnect removes the target prerequisite"
			)

	graph_editor._load_catalog_data()
	graph_editor.m_route_resource_paths["family_memory"] = _TEMP_ROUTE_PATH
	graph_editor._persist_dependency_change(
		"summer_return_complete",
		"spring_festival_prepared",
		true
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
				"Graph editor refuses reverse dependencies that would create a cycle"
			)

	_cleanup_temp_route()
	_cleanup_temp_layout_state()

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


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	m_failures.append("%s." % label)
