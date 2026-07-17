class_name AppStatePortBase
extends RefCounted

var m_app_state: Node = null


func _init(app_state: Node) -> void:
	assert(app_state != null, "AppState runtime ports require a live AppState node.")
	m_app_state = app_state


func _state_value(property_name: StringName, default_value: Variant = null) -> Variant:
	if m_app_state == null:
		return default_value
	var value: Variant = m_app_state.get(property_name)
	return default_value if value == null else value
