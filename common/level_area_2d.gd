@tool
class_name LevelArea2D
extends Area2D

signal resolved_level_changed(resolved_level: int)

const LEVEL_REGISTRY := preload("res://common/level_registry.gd")

@export var level_id: int = 0:
	set(new_level_id):
		if level_id == new_level_id:
			return
		level_id = new_level_id
		_request_level_refresh()

@export_enum("Absolute", "Relative To Parent") var level_id_mode: int = LEVEL_REGISTRY.LevelIdMode.ABSOLUTE:
	set(new_level_id_mode):
		if level_id_mode == new_level_id_mode:
			return
		level_id_mode = new_level_id_mode
		_request_level_refresh()

@export var level_context_path: NodePath:
	set(new_level_context_path):
		if level_context_path == new_level_context_path:
			return
		level_context_path = new_level_context_path
		_request_level_refresh()

@export var sync_z_index_to_resolved_level := false:
	set(new_sync_z_index_to_resolved_level):
		if sync_z_index_to_resolved_level == new_sync_z_index_to_resolved_level:
			return
		sync_z_index_to_resolved_level = new_sync_z_index_to_resolved_level
		_request_level_refresh()

var m_resolved_level := 0
var m_level_context_node: Node = null


func _ready() -> void:
	_rebind_level_dependencies()
	_update_level_context()


func _exit_tree() -> void:
	_unbind_level_dependencies()


func _request_level_refresh() -> void:
	if !is_inside_tree():
		return
	_rebind_level_dependencies()
	_update_level_context()


func refresh_level_from_context() -> void:
	_rebind_level_dependencies()
	_update_level_context()


func get_resolved_level_id() -> int:
	return m_resolved_level


func get_resolved_level() -> int:
	return get_resolved_level_id()


func _resolve_level() -> int:
	if level_id_mode != LEVEL_REGISTRY.LevelIdMode.RELATIVE_TO_PARENT:
		return level_id
	var level_context_node := _find_level_context_node()
	if level_context_node == null:
		return level_id
	return int(level_context_node.call("get_resolved_level_id")) + level_id


func _update_level_context() -> void:
	var new_resolved_level := _resolve_level()
	var level_changed := m_resolved_level != new_resolved_level
	m_resolved_level = new_resolved_level

	if sync_z_index_to_resolved_level:
		_sync_z_index_to_resolved_level()

	if level_changed:
		resolved_level_changed.emit(m_resolved_level)


func _sync_z_index_to_resolved_level() -> void:
	var target_absolute_z := LEVEL_REGISTRY.resolve_level_z_index(m_resolved_level, z_index)
	var parent_absolute_z := 0
	if z_as_relative:
		var parent_node := get_parent() as Node2D
		if parent_node != null:
			parent_absolute_z = CommonUtils.get_absolute_z_index(parent_node)
	z_index = target_absolute_z - parent_absolute_z


func _rebind_level_dependencies() -> void:
	var next_level_context_node := _find_level_context_node()
	if is_instance_valid(m_level_context_node):
		var should_disconnect_context := (
			m_level_context_node != next_level_context_node
			or level_id_mode != LEVEL_REGISTRY.LevelIdMode.RELATIVE_TO_PARENT
		)
		if (
			should_disconnect_context
			and m_level_context_node.has_signal("resolved_level_changed")
			and m_level_context_node.is_connected("resolved_level_changed", self._on_level_context_changed)
		):
			m_level_context_node.disconnect("resolved_level_changed", self._on_level_context_changed)

	m_level_context_node = next_level_context_node
	if (
		level_id_mode == LEVEL_REGISTRY.LevelIdMode.RELATIVE_TO_PARENT
		and is_instance_valid(m_level_context_node)
		and m_level_context_node.has_signal("resolved_level_changed")
	):
		if !m_level_context_node.is_connected("resolved_level_changed", self._on_level_context_changed):
			m_level_context_node.connect("resolved_level_changed", self._on_level_context_changed)


func _unbind_level_dependencies() -> void:
	if (
		is_instance_valid(m_level_context_node)
		and m_level_context_node.has_signal("resolved_level_changed")
		and m_level_context_node.is_connected("resolved_level_changed", self._on_level_context_changed)
	):
		m_level_context_node.disconnect("resolved_level_changed", self._on_level_context_changed)
	m_level_context_node = null


func _find_level_context_node() -> Node:
	if !level_context_path.is_empty():
		var explicit_context := get_node_or_null(level_context_path)
		if LEVEL_REGISTRY.is_level_related_node(explicit_context):
			return explicit_context
	return LEVEL_REGISTRY.find_parent_level_node(self)


func _on_level_context_changed(_resolved_level: int) -> void:
	_update_level_context()
