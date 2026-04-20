@tool
extends EditorInspectorPlugin
## Inspector plugin for [StorylineEventResource] and [StorylineRouteResource].
##
## Adds two UI panels to the Inspector whenever one of those resource types is
## selected:
##   1. A **Validation** panel — shows warnings from [method validate] in red
##      so authors see problems without leaving the Inspector.
##   2. An **Event ID Reference** panel — collapsible list of all known event
##      ids grouped by route, for copy-paste when editing story_flags_all /
##      story_flags_any fields.  Refreshes when the inspector opens the resource.

# Cached so successive inspector loads don't call DirAccess repeatedly.
var m_cached_event_ids: Dictionary = {}   # route_id -> Array[String]
var m_cache_valid: bool = false


# ---------------------------------------------------------------------------
# EditorInspectorPlugin overrides
# ---------------------------------------------------------------------------

func _can_handle(object: Object) -> bool:
	return object is StorylineEventResource or object is StorylineRouteResource


func _parse_begin(object: Object) -> void:
	_refresh_cache_if_needed()

	# --- Validation panel ---
	var warnings: PackedStringArray
	if object is StorylineEventResource:
		warnings = (object as StorylineEventResource).validate()
	else:
		warnings = (object as StorylineRouteResource).validate()

	var validation_box := _build_validation_panel(warnings)
	add_custom_control(validation_box)

	# --- Event-id reference panel (only useful when editing prerequisites) ---
	if object is StorylineEventResource:
		var ref_box := _build_event_id_reference_panel()
		add_custom_control(ref_box)


# ---------------------------------------------------------------------------
# UI builders
# ---------------------------------------------------------------------------

func _build_validation_panel(warnings: PackedStringArray) -> Control:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 2)

	var header_row := HBoxContainer.new()
	container.add_child(header_row)

	var header_lbl := Label.new()
	header_lbl.add_theme_font_size_override("font_size", 11)
	header_row.add_child(header_lbl)

	var refresh_btn := Button.new()
	refresh_btn.text = "⟳"
	refresh_btn.tooltip_text = "Revalidate"
	refresh_btn.flat = true
	refresh_btn.pressed.connect(func() -> void:
		m_cache_valid = false
	)
	header_row.add_child(refresh_btn)

	if warnings.is_empty():
		header_lbl.text = "✓  No validation warnings"
		_configure_tooltip_label(
			header_lbl,
			"No validation warnings."
		)
		header_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
	else:
		header_lbl.text = "⚠  %d warning%s" % [
			warnings.size(), "" if warnings.size() == 1 else "s"
		]
		_configure_tooltip_label(header_lbl, _warnings_tooltip(warnings))
		header_lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.2))
		for w: String in warnings:
			var w_lbl := Label.new()
			w_lbl.text = "  • " + w
			_configure_tooltip_label(w_lbl, w)
			w_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			w_lbl.add_theme_font_size_override("font_size", 10)
			w_lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3))
			container.add_child(w_lbl)

	container.add_child(HSeparator.new())
	return container


func _build_event_id_reference_panel() -> Control:
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 2)

	# Collapsible toggle.
	var toggle_btn := Button.new()
	toggle_btn.text = "▸  Known event IDs  (for story_flags_all / any)"
	toggle_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	toggle_btn.flat = true
	toggle_btn.add_theme_font_size_override("font_size", 11)
	outer.add_child(toggle_btn)

	var body := VBoxContainer.new()
	body.visible = false
	body.add_theme_constant_override("separation", 1)
	outer.add_child(body)

	toggle_btn.pressed.connect(func() -> void:
		body.visible = not body.visible
		toggle_btn.text = (
			"▾  Known event IDs  (for story_flags_all / any)"
			if body.visible else
			"▸  Known event IDs  (for story_flags_all / any)"
		)
	)

	# Populate grouped by route.
	if m_cached_event_ids.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "  (no events found — check storyline directory)"
		empty_lbl.add_theme_font_size_override("font_size", 10)
		body.add_child(empty_lbl)
	else:
		var sorted_routes: Array = m_cached_event_ids.keys()
		sorted_routes.sort()
		for route_id: String in sorted_routes:
			var route_lbl := Label.new()
			route_lbl.text = route_id
			route_lbl.add_theme_font_size_override("font_size", 10)
			route_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9))
			body.add_child(route_lbl)

			var ids: Array = m_cached_event_ids[route_id]
			for eid: String in ids:
				var id_btn := Button.new()
				id_btn.text = "    " + eid
				id_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
				id_btn.flat = true
				id_btn.add_theme_font_size_override("font_size", 10)
				id_btn.tooltip_text = "Click to copy '%s' to clipboard" % eid
				id_btn.pressed.connect(func() -> void:
					DisplayServer.clipboard_set(eid)
				)
				body.add_child(id_btn)

	outer.add_child(HSeparator.new())
	return outer


# ---------------------------------------------------------------------------
# Cache management
# ---------------------------------------------------------------------------

func _refresh_cache_if_needed() -> void:
	if m_cache_valid:
		return
	m_cached_event_ids.clear()
	var event_defs: Dictionary = StorylineCatalog.build_event_definitions()
	for eid_var in event_defs.keys():
		var eid: String = str(eid_var)
		var route_id: String = str(event_defs[eid_var].get("route_id", "unknown"))
		if not m_cached_event_ids.has(route_id):
			m_cached_event_ids[route_id] = []
		(m_cached_event_ids[route_id] as Array).append(eid)
	m_cache_valid = true


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
