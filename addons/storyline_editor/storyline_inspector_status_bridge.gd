@tool
extends RefCounted
## Shared refresh helper for storyline inspector status surfaces.
##
## Lets the editor inspector plugin refresh validation UI and browser warnings
## after inspector edits, while staying testable in headless scenes where
## [EditorInspectorPlugin] itself cannot be instantiated.

var m_validation_panel: Control
var m_catalog_changed_callback: Callable


func setup(
	validation_panel: Control = null,
	catalog_changed_callback: Callable = Callable()
) -> void:
	m_validation_panel = validation_panel
	m_catalog_changed_callback = catalog_changed_callback


func set_validation_panel(validation_panel: Control) -> void:
	m_validation_panel = validation_panel


func refresh_validation_panel() -> void:
	if m_validation_panel != null and is_instance_valid(m_validation_panel):
		if m_validation_panel.has_method("refresh"):
			m_validation_panel.refresh()


func refresh_storyline_status_for_object(object: Object) -> void:
	if not (object is StorylineEventResource or object is StorylineRouteResource):
		return

	refresh_validation_panel()

	if m_catalog_changed_callback.is_valid():
		m_catalog_changed_callback.call_deferred()
