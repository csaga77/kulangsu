@tool
extends EditorInspectorPlugin
## Inspector plugin for [StorylineEventResource] and [StorylineRouteResource].
##
## Adds editor-side helper UI to the Inspector whenever one of those resource types is
## selected:
##   1. A **Validation** panel — shows warnings from [method validate] in red
##      so authors see problems without leaving the Inspector.
##   2. A **Prerequisite picker** for [StorylineEventResource] objects that
##      replaces raw `story_flags_all` / `story_flags_any` string editing with
##      a route-rooted event picker matching the storyline browser.

const _PREREQUISITE_PICKER_PANEL_SCRIPT := preload(
	"res://addons/storyline_editor/storyline_prerequisite_picker_panel.gd"
)


# ---------------------------------------------------------------------------
# EditorInspectorPlugin overrides
# ---------------------------------------------------------------------------

func _can_handle(object: Object) -> bool:
	return object is StorylineEventResource or object is StorylineRouteResource


func _parse_begin(object: Object) -> void:
	# --- Validation panel ---
	var validation_box := _build_validation_panel(object)
	add_custom_control(validation_box)

	# --- Prerequisite picker for story_flags_all / story_flags_any ---
	if object is StorylineEventResource:
		var prerequisite_picker := _PREREQUISITE_PICKER_PANEL_SCRIPT.new() as Control
		if prerequisite_picker != null and prerequisite_picker.has_method("setup"):
			prerequisite_picker.setup(object as StorylineEventResource)
			add_custom_control(prerequisite_picker)


func _parse_property(
	object: Object,
	_type: int,
	name: String,
	_hint_type: int,
	_hint_string: String,
	_usage_flags: int,
	_wide: bool
) -> bool:
	if object is StorylineEventResource and name in ["story_flags_all", "story_flags_any"]:
		return true
	return false


# ---------------------------------------------------------------------------
# UI builders
# ---------------------------------------------------------------------------

func _build_validation_panel(object: Object) -> Control:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 2)

	var header_row := HBoxContainer.new()
	container.add_child(header_row)

	var header_lbl := Label.new()
	header_row.add_child(header_lbl)

	var refresh_btn := Button.new()
	refresh_btn.text = "⟳"
	refresh_btn.tooltip_text = "Revalidate"
	refresh_btn.flat = true
	header_row.add_child(refresh_btn)

	var warning_rows := VBoxContainer.new()
	warning_rows.add_theme_constant_override("separation", 2)
	container.add_child(warning_rows)

	refresh_btn.pressed.connect(func() -> void:
		_populate_validation_panel(header_lbl, warning_rows, object)
	)
	_populate_validation_panel(header_lbl, warning_rows, object)

	container.add_child(HSeparator.new())
	return container


func _populate_validation_panel(
	header_lbl: Label, warning_rows: VBoxContainer, object: Object
) -> void:
	for child: Node in warning_rows.get_children():
		warning_rows.remove_child(child)
		child.queue_free()

	var warnings := _warnings_for_object(object)
	if warnings.is_empty():
		header_lbl.text = "✓  No validation warnings"
		_configure_tooltip_label(header_lbl, "No validation warnings.")
		header_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
	else:
		header_lbl.text = "⚠  %d warning%s" % [
			warnings.size(), "" if warnings.size() == 1 else "s"
		]
		_configure_tooltip_label(header_lbl, _warnings_tooltip(warnings))
		header_lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.2))
		for warning: String in warnings:
			var warning_lbl := Label.new()
			warning_lbl.text = "  • " + warning
			_configure_tooltip_label(warning_lbl, warning)
			warning_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			warning_lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3))
			warning_rows.add_child(warning_lbl)


func _warnings_for_object(object: Object) -> PackedStringArray:
	if object is StorylineEventResource:
		return (object as StorylineEventResource).validate()
	if object is StorylineRouteResource:
		return (object as StorylineRouteResource).validate()
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
