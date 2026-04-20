extends Node

const ROUTE_BROWSER_SCRIPT := preload("res://addons/storyline_editor/storyline_route_browser.gd")

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

	route_browser._load_catalog_data()
	route_browser._rebuild_story_tree()
	_assert_true(
		route_browser.m_event_tree.columns == 1,
		"Route browser story tree uses a single visible column"
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
				route_browser.m_event_tree.set_selected(first_event_item, 0)
				await get_tree().process_frame
				_assert_true(
					inspector_requested_ids.size() == 1,
					"Route browser event selection emits one inspector edit request"
				)
				if inspector_requested_ids.size() == 1:
					_assert_true(
						inspector_requested_ids[0] == "summer_return_complete",
						"Route browser event selection requests inspector editing for the selected event"
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
