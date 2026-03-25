@tool
class_name LevelNode2D
extends AutoVisibilityNode2D

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
		
@export var physics_layers : Array [TileMapLayer]
@export var sub_level_nodes : Array [LevelNode2D]

var m_resolved_level := 0
var m_parent_level_node: Node = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super._ready()
	_rebind_level_dependencies()
	_update_level()

func _exit_tree() -> void:
	_unbind_level_dependencies()

func _request_level_refresh() -> void:
	if !is_inside_tree():
		return
	_rebind_level_dependencies()
	_update_level()

func _update_level() -> void:
	var new_resolved_level := _resolve_level()
	var level_changed := m_resolved_level != new_resolved_level
	m_resolved_level = new_resolved_level
	var atlas_column := _resolve_physics_atlas_column(m_resolved_level)

	for physics_layer in physics_layers:
		for cell in physics_layer.get_used_cells():
			var source_id = physics_layer.get_cell_source_id(cell)
			var alternative_tile = physics_layer.get_cell_alternative_tile(cell)
			var coords = physics_layer.get_cell_atlas_coords(cell)
			coords.x = atlas_column
			physics_layer.set_cell(cell, source_id, coords, alternative_tile)

	var ancestors_to_remove := []
	for room in sub_level_nodes:
		if room == null or !is_instance_valid(room):
			ancestors_to_remove.append(room)
			continue
		if CommonUtils.is_ancestor(room, self):
			ancestors_to_remove.append(room)
			continue
		room.refresh_level_from_context()
	if !ancestors_to_remove.is_empty():
		print("Warning: do not assign acestor rooms to children rooms! " + self.name)
		for ancestor in ancestors_to_remove:
			sub_level_nodes.erase(ancestor)

	if level_changed:
		resolved_level_changed.emit(m_resolved_level)

func refresh_level_from_context() -> void:
	_rebind_level_dependencies()
	_update_level()

func get_resolved_level_id() -> int:
	return m_resolved_level

func get_resolved_level() -> int:
	return get_resolved_level_id()

func _resolve_level() -> int:
	return LEVEL_REGISTRY.resolve_level_id(self, level_id, level_id_mode)

func _resolve_physics_atlas_column(resolved_level_id: int) -> int:
	return LEVEL_REGISTRY.resolve_level_physics_atlas_column(resolved_level_id, resolved_level_id)

func _rebind_level_dependencies() -> void:
	var next_parent_level_node := _find_parent_level_node()
	if is_instance_valid(m_parent_level_node):
		var should_disconnect_parent: bool = m_parent_level_node != next_parent_level_node or level_id_mode != LEVEL_REGISTRY.LevelIdMode.RELATIVE_TO_PARENT
		if should_disconnect_parent and m_parent_level_node.has_signal("resolved_level_changed") and m_parent_level_node.is_connected("resolved_level_changed", self._on_parent_level_changed):
			m_parent_level_node.disconnect("resolved_level_changed", self._on_parent_level_changed)
	m_parent_level_node = next_parent_level_node
	if level_id_mode == LEVEL_REGISTRY.LevelIdMode.RELATIVE_TO_PARENT and is_instance_valid(m_parent_level_node) and m_parent_level_node.has_signal("resolved_level_changed"):
		if !m_parent_level_node.is_connected("resolved_level_changed", self._on_parent_level_changed):
			m_parent_level_node.connect("resolved_level_changed", self._on_parent_level_changed)

func _unbind_level_dependencies() -> void:
	if is_instance_valid(m_parent_level_node) and m_parent_level_node.has_signal("resolved_level_changed") and m_parent_level_node.is_connected("resolved_level_changed", self._on_parent_level_changed):
		m_parent_level_node.disconnect("resolved_level_changed", self._on_parent_level_changed)
	m_parent_level_node = null

func _find_parent_level_node() -> Node:
	return LEVEL_REGISTRY.find_parent_level_node(self)

func _on_parent_level_changed(_resolved_level: int) -> void:
	_update_level()
