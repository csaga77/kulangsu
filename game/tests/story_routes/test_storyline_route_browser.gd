extends Node

const ROUTE_BROWSER_SCRIPT := preload("res://addons/storyline_editor/storyline_route_browser.gd")
const ROUTE_EVENT_PANEL_SCRIPT := preload(
	"res://addons/storyline_editor/storyline_route_event_panel.gd"
)
const _TEMP_DELETE_ROUTE_RESOURCE_PATH := "user://storyline_route_browser_delete_test.tres"

var m_failures := PackedStringArray()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var route_browser = ROUTE_BROWSER_SCRIPT.new()
	add_child(route_browser)
	await get_tree().process_frame

	var route_inspector_requested_ids := PackedStringArray()
	route_browser.route_inspector_requested.connect(func(route_id: String) -> void:
		route_inspector_requested_ids.append(route_id)
	)

	var inspector_requested_ids := PackedStringArray()
	route_browser.event_inspector_requested.connect(func(event_id: String) -> void:
		inspector_requested_ids.append(event_id)
	)
	var deleted_event_ids := PackedStringArray()
	route_browser.event_delete_requested.connect(func(event_id: String) -> void:
		deleted_event_ids.append(event_id)
	)

	route_browser._load_catalog_data()
	route_browser._rebuild_story_tree()
	var inspected_family_route := StorylineRouteResource.new()
	inspected_family_route.id = "family_memory"
	var inspected_family_event := StorylineEventResource.new()
	inspected_family_event.id = "summer_return_complete"
	var inspected_other_event := StorylineEventResource.new()
	inspected_other_event.id = "autumn_study_commitment"
	_assert_true(
		route_browser._should_clear_inspector_for_deleted_route(
			"family_memory",
			inspected_family_route
		),
		"Route browser clears the inspector for a deleted route resource"
	)
	_assert_true(
		route_browser._should_clear_inspector_for_deleted_route(
			"family_memory",
			inspected_family_event
		),
		"Route browser clears the inspector for an event inside the deleted route"
	)
	_assert_true(
		not route_browser._should_clear_inspector_for_deleted_route(
			"family_memory",
			inspected_other_event
		),
		"Route browser keeps unrelated inspector objects when deleting another route"
	)
	_assert_true(
		route_browser.m_event_tree.columns == 1,
		"Route browser story tree uses a single visible column"
	)
	_assert_true(
		not route_browser.m_event_tree.column_titles_visible,
		"Route browser hides the story tree column title"
	)
	var tree_root: TreeItem = route_browser.m_event_tree.get_root()
	_assert_true(tree_root != null, "Route browser builds a hidden story tree root")
	if tree_root != null:
		var first_route_item: TreeItem = tree_root.get_first_child()
		_assert_true(first_route_item != null, "Route browser tree includes route root rows")
		if first_route_item != null:
			_assert_true(
				first_route_item.get_text(0).contains("Family and Memory"),
				"Route browser route roots show the route display name"
			)
			route_browser.m_event_tree.set_selected(first_route_item, 0)
			await get_tree().process_frame
			_assert_true(
				route_inspector_requested_ids.size() == 1,
				"Route browser route selection emits one route inspector edit request"
			)
			if route_inspector_requested_ids.size() == 1:
				_assert_true(
					route_inspector_requested_ids[0] == "family_memory",
					"Route browser route selection requests inspector editing for the selected route"
				)
			_assert_true(
				inspector_requested_ids.is_empty(),
				"Route browser route selection does not emit an event inspector edit request"
			)

			var first_event_item: TreeItem = first_route_item.get_first_child()
			_assert_true(first_event_item != null, "Route browser event rows live under their route root")
			if first_event_item != null:
				_assert_true(
					first_event_item.get_first_child() == null,
					"Route browser event rows do not render prerequisite child rows"
				)
				route_browser.m_event_tree.set_selected(first_event_item, 0)
				await get_tree().process_frame
				_assert_true(
					inspector_requested_ids.size() == 1,
					"Route browser event selection emits one inspector edit request"
				)
				_assert_true(
					not route_browser.m_delete_route_btn.disabled,
					"Route browser enables deletion for a selected event row"
				)
				if inspector_requested_ids.size() == 1:
					_assert_true(
						inspector_requested_ids[0] == "summer_return_complete",
						"Route browser event selection requests inspector editing for the selected event"
					)
				route_browser._on_delete_route_pressed()
				_assert_true(
					deleted_event_ids.is_empty(),
					"Route browser event delete prompt does not emit the delete request before confirmation"
				)
				route_browser._confirm_delete_event()
				_assert_true(
					deleted_event_ids.size() == 1,
					"Route browser emits one delete request after confirming event deletion"
				)
				if deleted_event_ids.size() == 1:
					_assert_true(
						deleted_event_ids[0] == "summer_return_complete",
						"Route browser event delete request targets the selected event"
					)

	var live_route_resource := _load_live_route_resource("melody_landmarks")
	_assert_true(
		live_route_resource != null,
		"Route browser live-refresh test can load a typed route resource"
	)
	if live_route_resource != null:
		var expected_new_event_id := live_route_resource.next_default_event_id()
		var route_event_panel = ROUTE_EVENT_PANEL_SCRIPT.new()
		route_event_panel.setup(
			live_route_resource,
			null,
			Callable(route_browser, "refresh_from_disk")
		)
		add_child(route_event_panel)
		await get_tree().process_frame
		route_event_panel._on_add_event_pressed()
		await get_tree().process_frame
		_assert_true(
			_tree_contains_event_id(route_browser.m_event_tree, expected_new_event_id),
			"Route browser shows a newly created event immediately after the route panel adds it"
		)

		var cleaned_events: Array[StorylineEventResource] = live_route_resource.events.duplicate()
		if not cleaned_events.is_empty():
			var last_event := cleaned_events[cleaned_events.size() - 1]
			if last_event != null and last_event.id == expected_new_event_id:
				cleaned_events.remove_at(cleaned_events.size() - 1)
				live_route_resource.events = cleaned_events
				live_route_resource.emit_changed()
				route_browser.refresh_from_disk()
		route_event_panel.queue_free()
		await get_tree().process_frame

	_cleanup_temp_route_delete_files()
	_write_temp_route_delete_file(_TEMP_DELETE_ROUTE_RESOURCE_PATH, "[gd_resource type=\"Resource\" format=3]\n")
	route_browser.m_route_defs["temp_delete_route"] = {
		"id": "temp_delete_route",
		"display_name": "Temp Delete Route",
		"display_order": 9998,
	}
	route_browser.m_route_resource_paths["temp_delete_route"] = PackedStringArray([
		_TEMP_DELETE_ROUTE_RESOURCE_PATH,
	])
	route_browser._rebuild_story_tree()
	await get_tree().process_frame

	var temp_route_item := _find_tree_item_with_route_id(
		route_browser.m_event_tree.get_root(),
		"temp_delete_route"
	)
	_assert_true(
		temp_route_item != null,
		"Route browser delete test can find the temporary route row"
	)
	if temp_route_item != null:
		route_browser.m_event_tree.set_selected(temp_route_item, 0)
		await get_tree().process_frame
		_assert_true(
			not route_browser.m_delete_route_btn.disabled,
			"Route browser enables route deletion for a selected route"
		)
		route_browser._on_delete_route_pressed()
		_assert_true(
			FileAccess.file_exists(ProjectSettings.globalize_path(_TEMP_DELETE_ROUTE_RESOURCE_PATH)),
			"Route browser route delete prompt does not delete the resource before confirmation"
		)
		route_browser._confirm_delete_route()
		_assert_true(
			not FileAccess.file_exists(ProjectSettings.globalize_path(_TEMP_DELETE_ROUTE_RESOURCE_PATH)),
			"Route browser deletes the selected route resource after confirmation"
		)
		_assert_true(
			not _tree_contains_route_id(route_browser.m_event_tree, "temp_delete_route"),
			"Route browser removes the deleted route from the story tree after confirmation"
		)

	var sample_warnings: Array[String] = [
		"[demo_route] first warning",
		"[demo_event] second warning",
	]
	route_browser.m_all_warnings = sample_warnings
	route_browser._rebuild_warnings_panel()

	var warning_children: Array = route_browser.m_warnings_panel.get_children()
	_assert_true(
		warning_children.size() == 3,
		"Route browser renders one warning header plus one row per warning"
	)
	if warning_children.size() >= 3:
		var header := warning_children[0] as Label
		var first_warning := warning_children[1] as Label
		var second_warning := warning_children[2] as Label
		_assert_true(header != null, "Route browser warning header is a label")
		_assert_true(first_warning != null, "Route browser first warning row is a label")
		_assert_true(second_warning != null, "Route browser second warning row is a label")

		if header != null:
			_assert_true(
				header.tooltip_text.contains("[demo_route] first warning"),
				"Route browser warning header tooltip includes the first warning"
			)
			_assert_true(
				header.tooltip_text.contains("[demo_event] second warning"),
				"Route browser warning header tooltip includes the second warning"
			)
			_assert_true(
				header.mouse_filter == Control.MOUSE_FILTER_STOP,
				"Route browser warning header captures hover for tooltip display"
			)

		if first_warning != null:
			_assert_true(
				first_warning.tooltip_text == "[demo_route] first warning",
				"Route browser warning rows expose their full warning text in tooltips"
			)
			_assert_true(
				first_warning.mouse_filter == Control.MOUSE_FILTER_STOP,
				"Route browser warning rows capture hover for tooltip display"
			)
			_assert_true(
				first_warning.mouse_default_cursor_shape == Control.CURSOR_HELP,
				"Route browser warning rows use the help cursor to hint at hover details"
			)

		if second_warning != null:
			_assert_true(
				second_warning.tooltip_text == "[demo_event] second warning",
				"Route browser keeps per-row tooltip text distinct"
			)

	route_browser.queue_free()
	await get_tree().process_frame
	_cleanup_temp_route_delete_files()

	if m_failures.is_empty():
		print("PASS: storyline route browser warnings")
	else:
		for failure in m_failures:
			push_error(failure)
		push_error("Storyline route browser warnings failed with %d issue(s)." % m_failures.size())

	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0 if m_failures.is_empty() else 1)


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	m_failures.append("%s." % label)


func _load_live_route_resource(route_id: String) -> StorylineRouteResource:
	for route_resource: StorylineRouteResource in StorylineCatalog.load_route_resources():
		if route_resource != null and route_resource.id.strip_edges() == route_id:
			return route_resource
	return null


func _tree_contains_event_id(tree: Tree, event_id: String) -> bool:
	var root := tree.get_root()
	if root == null:
		return false
	return _tree_item_contains_event_id(root, event_id)


func _tree_contains_route_id(tree: Tree, route_id: String) -> bool:
	var root := tree.get_root()
	if root == null:
		return false
	return _find_tree_item_with_route_id(root, route_id) != null


func _tree_item_contains_event_id(item: TreeItem, event_id: String) -> bool:
	var metadata: Variant = item.get_metadata(0)
	if metadata is Dictionary:
		var metadata_dict := metadata as Dictionary
		if String(metadata_dict.get("kind", "")) == "event" and String(metadata_dict.get("event_id", "")) == event_id:
			return true

	var child := item.get_first_child()
	while child != null:
		if _tree_item_contains_event_id(child, event_id):
			return true
		child = child.get_next()
	return false


func _find_tree_item_with_route_id(item: TreeItem, route_id: String) -> TreeItem:
	var metadata: Variant = item.get_metadata(0)
	if metadata is Dictionary:
		var metadata_dict := metadata as Dictionary
		if String(metadata_dict.get("kind", "")) == "route" and String(metadata_dict.get("route_id", "")) == route_id:
			return item

	var child := item.get_first_child()
	while child != null:
		var found := _find_tree_item_with_route_id(child, route_id)
		if found != null:
			return found
		child = child.get_next()
	return null


func _write_temp_route_delete_file(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		m_failures.append("Unable to write temp route delete file %s." % path)
		return
	file.store_string(content)


func _cleanup_temp_route_delete_files() -> void:
	for path in [
		_TEMP_DELETE_ROUTE_RESOURCE_PATH,
	]:
		var absolute_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute_path):
			var remove_error := DirAccess.remove_absolute(absolute_path)
			_assert_true(remove_error == OK, "Route browser temp delete file cleanup succeeds for %s" % path)
