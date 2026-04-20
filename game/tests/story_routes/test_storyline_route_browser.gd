extends Node

const ROUTE_BROWSER_SCRIPT := preload("res://addons/storyline_editor/storyline_route_browser.gd")

var m_failures := PackedStringArray()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var route_browser = ROUTE_BROWSER_SCRIPT.new()
	add_child(route_browser)
	await get_tree().process_frame

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
