@tool
class_name LevelNode2D
extends AutoVisibilityNode2D

signal resolved_level_changed(resolved_level: int)

enum LevelSource {
	EXPLICIT = 0,
	CONTEXT_SLOT = 1,
	INHERIT_PARENT = 2,
}

@export var level := 0:
	set(new_level):
		if level == new_level:
			return
		level = new_level
		_update_level()

@export var level_source: LevelSource = LevelSource.EXPLICIT:
	set(new_level_source):
		if level_source == new_level_source:
			return
		level_source = new_level_source
		_rebind_level_dependencies()
		_update_level()

@export var level_slot := 0:
	set(new_level_slot):
		if level_slot == new_level_slot:
			return
		level_slot = new_level_slot
		_update_level()
		
@export var physics_layers : Array [TileMapLayer]
@export var sub_level_nodes : Array [LevelNode2D]

var m_resolved_level := 0
var m_level_context: LevelContext2D = null
var m_parent_level_node: LevelNode2D = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super._ready()
	_rebind_level_dependencies()
	_update_level()

func _exit_tree() -> void:
	_unbind_level_dependencies()

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

func get_resolved_level() -> int:
	return m_resolved_level

func _resolve_level() -> int:
	match level_source:
		LevelSource.CONTEXT_SLOT:
			var level_context := _find_level_context()
			if level_context != null:
				return level_context.resolve_level_slot(level_slot, level)
		LevelSource.INHERIT_PARENT:
			var parent_level_node := _find_parent_level_node()
			if is_instance_valid(parent_level_node):
				return parent_level_node.get_resolved_level()
	return level

func _resolve_physics_atlas_column(level_id: int) -> int:
	var level_context := _find_level_context()
	if level_context == null:
		return level_id
	return level_context.resolve_level_physics_atlas_column(level_id, level_id)

func _rebind_level_dependencies() -> void:
	var level_context_changed := Callable(self, "_on_level_context_changed")
	var next_level_context := _find_level_context()
	if is_instance_valid(m_level_context):
		var should_disconnect_context := m_level_context != next_level_context
		if should_disconnect_context and m_level_context.is_connected("runtime_levels_changed", level_context_changed):
			m_level_context.disconnect("runtime_levels_changed", level_context_changed)
	m_level_context = next_level_context
	if is_instance_valid(m_level_context):
		if !m_level_context.is_connected("runtime_levels_changed", level_context_changed):
			m_level_context.connect("runtime_levels_changed", level_context_changed)

	var next_parent_level_node := _find_parent_level_node()
	if is_instance_valid(m_parent_level_node):
		var should_disconnect_parent := m_parent_level_node != next_parent_level_node or level_source != LevelSource.INHERIT_PARENT
		if should_disconnect_parent and m_parent_level_node.resolved_level_changed.is_connected(self._on_parent_level_changed):
			m_parent_level_node.resolved_level_changed.disconnect(self._on_parent_level_changed)
	m_parent_level_node = next_parent_level_node
	if level_source == LevelSource.INHERIT_PARENT and is_instance_valid(m_parent_level_node):
		if !m_parent_level_node.resolved_level_changed.is_connected(self._on_parent_level_changed):
			m_parent_level_node.resolved_level_changed.connect(self._on_parent_level_changed)

func _unbind_level_dependencies() -> void:
	var level_context_changed := Callable(self, "_on_level_context_changed")
	if is_instance_valid(m_level_context) and m_level_context.is_connected("runtime_levels_changed", level_context_changed):
		m_level_context.disconnect("runtime_levels_changed", level_context_changed)
	if is_instance_valid(m_parent_level_node) and m_parent_level_node.resolved_level_changed.is_connected(self._on_parent_level_changed):
		m_parent_level_node.resolved_level_changed.disconnect(self._on_parent_level_changed)
	m_level_context = null
	m_parent_level_node = null

func _find_level_context() -> LevelContext2D:
	return LevelContext2D.find_from(self)

func _find_parent_level_node() -> LevelNode2D:
	var node := get_parent()
	while node != null:
		if node is LevelNode2D:
			return node as LevelNode2D
		node = node.get_parent()
	return null

func _on_level_context_changed() -> void:
	_update_level()

func _on_parent_level_changed(_resolved_level: int) -> void:
	_update_level()
