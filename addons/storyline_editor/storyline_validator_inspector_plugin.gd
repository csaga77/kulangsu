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

const _VALIDATION_PANEL_SCRIPT := preload(
	"res://addons/storyline_editor/storyline_validation_panel.gd"
)
const _INSPECTOR_STATUS_BRIDGE_SCRIPT := preload(
	"res://addons/storyline_editor/storyline_inspector_status_bridge.gd"
)
const _PREREQUISITE_PICKER_PANEL_SCRIPT := preload(
	"res://addons/storyline_editor/storyline_prerequisite_picker_panel.gd"
)
const _ROUTE_EVENT_PANEL_SCRIPT := preload(
	"res://addons/storyline_editor/storyline_route_event_panel.gd"
)

var m_editor_interface: EditorInterface
var m_catalog_changed_callback: Callable
var m_inspector: EditorInspector
var m_current_validation_panel: Control
var m_current_prerequisite_picker: Control
var m_current_route_event_panel: Control
var m_status_bridge: RefCounted


# ---------------------------------------------------------------------------
# EditorInspectorPlugin overrides
# ---------------------------------------------------------------------------

func _can_handle(object: Object) -> bool:
	return object is StorylineEventResource or object is StorylineRouteResource


func setup(
	editor_interface: EditorInterface,
	catalog_changed_callback: Callable = Callable()
) -> void:
	m_editor_interface = editor_interface
	m_catalog_changed_callback = catalog_changed_callback
	if _INSPECTOR_STATUS_BRIDGE_SCRIPT != null:
		m_status_bridge = _INSPECTOR_STATUS_BRIDGE_SCRIPT.new()
		if m_status_bridge != null and m_status_bridge.has_method("setup"):
			m_status_bridge.setup(null, m_catalog_changed_callback)
	_connect_inspector_signals()


func teardown() -> void:
	_disconnect_inspector_signals()
	m_current_validation_panel = null
	m_current_prerequisite_picker = null
	m_current_route_event_panel = null


func _parse_begin(object: Object) -> void:
	m_current_validation_panel = null
	m_current_prerequisite_picker = null
	m_current_route_event_panel = null

	# --- Validation panel ---
	var validation_panel := _VALIDATION_PANEL_SCRIPT.new() as Control
	if validation_panel != null and validation_panel.has_method("setup"):
		validation_panel.setup(object)
		m_current_validation_panel = validation_panel
		if m_status_bridge != null and m_status_bridge.has_method("set_validation_panel"):
			m_status_bridge.set_validation_panel(validation_panel)
		add_custom_control(validation_panel)

	# --- Prerequisite picker for story_flags_all / story_flags_any ---
	if object is StorylineEventResource:
		var prerequisite_picker := _PREREQUISITE_PICKER_PANEL_SCRIPT.new() as Control
		if prerequisite_picker != null and prerequisite_picker.has_method("setup"):
			prerequisite_picker.setup(
				object as StorylineEventResource,
				m_catalog_changed_callback
			)
			m_current_prerequisite_picker = prerequisite_picker
			add_custom_control(prerequisite_picker)
		elif object is StorylineRouteResource:
			var route_event_panel := _ROUTE_EVENT_PANEL_SCRIPT.new() as Control
			if route_event_panel != null and route_event_panel.has_method("setup"):
				route_event_panel.setup(
					object as StorylineRouteResource,
					m_editor_interface,
					m_catalog_changed_callback
				)
				m_current_route_event_panel = route_event_panel
				add_custom_control(route_event_panel)


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
	if object is StorylineRouteResource and name == "events":
		return true
	return false


func _connect_inspector_signals() -> void:
	if m_editor_interface == null:
		return
	var inspector := m_editor_interface.get_inspector()
	if inspector == null:
		return

	m_inspector = inspector
	if not m_inspector.property_edited.is_connected(_on_inspector_property_edited):
		m_inspector.property_edited.connect(_on_inspector_property_edited, CONNECT_DEFERRED)
	if not m_inspector.property_deleted.is_connected(_on_inspector_property_deleted):
		m_inspector.property_deleted.connect(_on_inspector_property_deleted, CONNECT_DEFERRED)
	if not m_inspector.edited_object_changed.is_connected(_on_inspector_edited_object_changed):
		m_inspector.edited_object_changed.connect(
			_on_inspector_edited_object_changed,
			CONNECT_DEFERRED
		)


func _disconnect_inspector_signals() -> void:
	if m_inspector == null:
		return
	if m_inspector.property_edited.is_connected(_on_inspector_property_edited):
		m_inspector.property_edited.disconnect(_on_inspector_property_edited)
	if m_inspector.property_deleted.is_connected(_on_inspector_property_deleted):
		m_inspector.property_deleted.disconnect(_on_inspector_property_deleted)
	if m_inspector.edited_object_changed.is_connected(_on_inspector_edited_object_changed):
		m_inspector.edited_object_changed.disconnect(_on_inspector_edited_object_changed)
	m_inspector = null


func _on_inspector_property_edited(_property: String) -> void:
	_refresh_storyline_status_for_object(_inspector_edited_object())


func _on_inspector_property_deleted(_property: String) -> void:
	_refresh_storyline_status_for_object(_inspector_edited_object())


func _on_inspector_edited_object_changed() -> void:
	if m_status_bridge != null and m_status_bridge.has_method("refresh_validation_panel"):
		m_status_bridge.refresh_validation_panel()


func _inspector_edited_object() -> Object:
	if m_inspector == null:
		return null
	return m_inspector.get_edited_object()


func _refresh_storyline_status_for_object(object: Object) -> void:
	if m_status_bridge != null and m_status_bridge.has_method("refresh_storyline_status_for_object"):
		m_status_bridge.refresh_storyline_status_for_object(object)


func refresh_storyline_controls() -> void:
	if m_status_bridge != null and m_status_bridge.has_method("refresh_validation_panel"):
		m_status_bridge.refresh_validation_panel()
	_refresh_custom_control(m_current_prerequisite_picker)
	_refresh_custom_control(m_current_route_event_panel)


func _refresh_custom_control(control: Control) -> void:
	if control == null or not is_instance_valid(control):
		return
	if control.has_method("refresh"):
		control.refresh()
