@tool
extends VBoxContainer
## Inspector-side validation panel for storyline route and event resources.
##
## Shows current validation warnings and refreshes automatically when the
## inspected resource emits [signal Resource.changed].

var m_target_object: Object
var m_target_resource: Resource
var m_header_lbl: Label
var m_warning_rows: VBoxContainer


func setup(target_object: Object) -> void:
	if m_target_resource != null:
		_disconnect_target_resource()

	m_target_object = target_object
	m_target_resource = target_object as Resource
	if is_node_ready():
		_connect_target_resource()
		refresh()


func _ready() -> void:
	_build_ui()
	_connect_target_resource()
	refresh()


func _exit_tree() -> void:
	_disconnect_target_resource()


func refresh() -> void:
	if m_header_lbl == null or m_warning_rows == null:
		return

	for child: Node in m_warning_rows.get_children():
		m_warning_rows.remove_child(child)
		child.queue_free()

	var warnings := _warnings_for_target()
	if warnings.is_empty():
		m_header_lbl.text = "✓  No validation warnings"
		_configure_tooltip_label(m_header_lbl, "No validation warnings.")
		m_header_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
	else:
		m_header_lbl.text = "⚠  %d warning%s" % [
			warnings.size(), "" if warnings.size() == 1 else "s"
		]
		_configure_tooltip_label(m_header_lbl, _warnings_tooltip(warnings))
		m_header_lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.2))
		for warning: String in warnings:
			var warning_lbl := Label.new()
			warning_lbl.text = "  • " + warning
			_configure_tooltip_label(warning_lbl, warning)
			warning_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			warning_lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3))
			m_warning_rows.add_child(warning_lbl)


func _build_ui() -> void:
	if get_child_count() > 0:
		return

	add_theme_constant_override("separation", 2)

	var header_row := HBoxContainer.new()
	add_child(header_row)

	m_header_lbl = Label.new()
	header_row.add_child(m_header_lbl)

	var refresh_btn := Button.new()
	refresh_btn.text = "⟳"
	refresh_btn.tooltip_text = "Revalidate"
	refresh_btn.flat = true
	refresh_btn.pressed.connect(refresh)
	header_row.add_child(refresh_btn)

	m_warning_rows = VBoxContainer.new()
	m_warning_rows.add_theme_constant_override("separation", 2)
	add_child(m_warning_rows)

	add_child(HSeparator.new())


func _connect_target_resource() -> void:
	if m_target_resource == null:
		return
	if not m_target_resource.changed.is_connected(_on_target_resource_changed):
		m_target_resource.changed.connect(_on_target_resource_changed, CONNECT_DEFERRED)


func _disconnect_target_resource() -> void:
	if m_target_resource == null:
		return
	if m_target_resource.changed.is_connected(_on_target_resource_changed):
		m_target_resource.changed.disconnect(_on_target_resource_changed)


func _on_target_resource_changed() -> void:
	refresh()


func _warnings_for_target() -> PackedStringArray:
	if m_target_object is StorylineEventResource:
		return (m_target_object as StorylineEventResource).validate()
	if m_target_object is StorylineRouteResource:
		return (m_target_object as StorylineRouteResource).validate()
	return PackedStringArray()


func _warnings_tooltip(warnings: PackedStringArray) -> String:
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
