@tool
extends EditorPlugin

var m_graph_editor: Control
var m_route_browser: Control
var m_inspector_plugin: EditorInspectorPlugin


func _enter_tree() -> void:
	# --- Graph editor (bottom panel) ---
	var graph_script: GDScript = load(
		"res://addons/storyline_editor/storyline_graph_editor.gd"
	) as GDScript
	if graph_script != null and graph_script.can_instantiate():
		m_graph_editor = graph_script.new() as Control
		if m_graph_editor != null:
			m_graph_editor.name = "Storyline Graph"
			if m_graph_editor.has_method("setup"):
				m_graph_editor.setup(get_editor_interface())
			add_control_to_bottom_panel(m_graph_editor, "Storyline Graph")
	elif graph_script != null:
		push_warning("StorylineEditorPlugin: graph editor script failed to instantiate")

	# --- Route browser (left dock) ---
	var browser_script: GDScript = load(
		"res://addons/storyline_editor/storyline_route_browser.gd"
	) as GDScript
	if browser_script != null and browser_script.can_instantiate():
		m_route_browser = browser_script.new() as Control
		if m_route_browser != null:
			m_route_browser.name = "Storyline Browser"
			if m_route_browser.has_method("setup"):
				m_route_browser.setup(get_editor_interface())
			add_control_to_dock(DOCK_SLOT_LEFT_BL, m_route_browser)
			# Wire "Show in Graph" from browser to graph editor.
			if m_graph_editor != null and m_route_browser.has_signal("event_show_in_graph_requested"):
				m_route_browser.event_show_in_graph_requested.connect(
					_on_event_show_in_graph_requested
				)
			if m_graph_editor != null and m_route_browser.has_signal("route_inspector_requested"):
				m_route_browser.route_inspector_requested.connect(
					_on_route_inspector_requested
				)
			if m_graph_editor != null and m_route_browser.has_signal("event_inspector_requested"):
				m_route_browser.event_inspector_requested.connect(
					_on_event_inspector_requested
				)
			if m_graph_editor != null and m_graph_editor.has_signal("catalog_changed"):
				m_graph_editor.catalog_changed.connect(_on_storyline_catalog_changed)
	elif browser_script != null:
		push_warning("StorylineEditorPlugin: route browser script failed to instantiate")

	# --- Inspector plugin (validation + event-id picker) ---
	var inspector_script: GDScript = load(
		"res://addons/storyline_editor/storyline_validator_inspector_plugin.gd"
	) as GDScript
	if inspector_script != null and inspector_script.can_instantiate():
		m_inspector_plugin = inspector_script.new() as EditorInspectorPlugin
		if m_inspector_plugin != null:
			add_inspector_plugin(m_inspector_plugin)
	elif inspector_script != null:
		push_warning("StorylineEditorPlugin: inspector plugin script failed to instantiate")


func _exit_tree() -> void:
	if m_inspector_plugin != null:
		remove_inspector_plugin(m_inspector_plugin)
		m_inspector_plugin = null

	if m_route_browser != null:
		remove_control_from_docks(m_route_browser)
		m_route_browser.queue_free()
		m_route_browser = null

	if m_graph_editor != null:
		remove_control_from_bottom_panel(m_graph_editor)
		m_graph_editor.queue_free()
		m_graph_editor = null


func _on_event_show_in_graph_requested(event_id: String) -> void:
	# Bring the graph editor to the foreground and select the node.
	if m_graph_editor == null:
		return
	make_bottom_panel_item_visible(m_graph_editor)
	if m_graph_editor.has_method("select_event"):
		m_graph_editor.select_event(event_id)


func _on_event_inspector_requested(event_id: String) -> void:
	if m_graph_editor == null:
		return
	if m_graph_editor.has_method("edit_event_in_inspector"):
		m_graph_editor.edit_event_in_inspector(event_id)


func _on_route_inspector_requested(route_id: String) -> void:
	if m_graph_editor == null:
		return
	if m_graph_editor.has_method("edit_route_in_inspector"):
		m_graph_editor.edit_route_in_inspector(route_id)


func _on_storyline_catalog_changed() -> void:
	if m_route_browser != null and m_route_browser.has_method("refresh_from_disk"):
		m_route_browser.refresh_from_disk()
