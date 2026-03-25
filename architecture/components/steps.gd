@tool
class_name Steps
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

@export var level_bottom := -1:
	set(new_level_bottom):
		if level_bottom == new_level_bottom:
			return
		level_bottom = new_level_bottom
		_request_level_refresh()

@export var level_top := -1:
	set(new_level_top):
		if level_top == new_level_top:
			return
		level_top = new_level_top
		_request_level_refresh()

@export var layer1_nodes :Array[Portal]

var m_is_syncing_legacy_layers := false
@export_flags_2d_physics var layer1 := 0:
	set(new_layer):
		if layer1 == new_layer:
			return
		layer1 = new_layer
		if m_is_syncing_legacy_layers:
			return
		_request_mask_update()

@export var body_nodes :Array[CollisionObject2D]

@export_flags_2d_physics var collision_layer := 0:
	set(new_layer):
		if collision_layer == new_layer:
			return
		collision_layer = new_layer
		_request_mask_update()

@export var layer2_nodes :Array[Portal]

@export_flags_2d_physics var layer2 := 0:
	set(new_layer):
		if layer2 == new_layer:
			return
		layer2 = new_layer
		if m_is_syncing_legacy_layers:
			return
		_request_mask_update()

var m_parent_level_node: Node = null
var m_resolved_level_id := 0

func get_resolved_level_id() -> int:
	return m_resolved_level_id

func _request_level_refresh() -> void:
	if !is_inside_tree():
		return
	_rebind_level_dependencies()
	_update_mask()

func _request_mask_update() -> void:
	if !is_inside_tree():
		return
	_update_mask()

func _update_mask() -> void:
	var new_resolved_level_id := _resolve_local_level_id(level_id)
	var level_changed := m_resolved_level_id != new_resolved_level_id
	m_resolved_level_id = new_resolved_level_id
	var resolved_level_bottom := _resolve_optional_level_id(level_bottom)
	var resolved_level_top := _resolve_optional_level_id(level_top)
	var has_bottom_level_data := LEVEL_REGISTRY.has_level_data(resolved_level_bottom)
	var has_top_level_data := LEVEL_REGISTRY.has_level_data(resolved_level_top)

	# If both level ids are provided, use them to derive the collision masks.
	if resolved_level_bottom >= 0 and resolved_level_top >= 0 and has_bottom_level_data and has_top_level_data:
		var bottom_mask: int = LEVEL_REGISTRY.resolve_level_collision_mask(resolved_level_bottom, layer1)
		var top_mask: int = LEVEL_REGISTRY.resolve_level_collision_mask(resolved_level_top, layer2)
		var bottom_z: int = LEVEL_REGISTRY.resolve_level_z_index(resolved_level_bottom, 0)
		var top_z: int = LEVEL_REGISTRY.resolve_level_z_index(resolved_level_top, 0)
		var z_gap: int = abs(top_z - bottom_z)
		var should_override_delta: bool = z_gap % 2 == 0
		var portal_delta_z: int = z_gap >> 1 if should_override_delta else 1
		if !should_override_delta:
			push_warning(
				"Steps '%s' expected an even z gap between levels %d and %d, keeping existing portal delta_z."
				% [name, resolved_level_bottom, resolved_level_top]
			)

		m_is_syncing_legacy_layers = true
		layer1 = bottom_mask
		layer2 = top_mask
		m_is_syncing_legacy_layers = false

		# Apply to body nodes (CollisionObject2D): set collision_layer bits
		for body in body_nodes:
			if is_instance_valid(body):
				body.collision_layer = collision_layer

		# Apply to portal1 nodes: mask1 = bottom level, mask2 = collision_layer
		for p1 in layer1_nodes:
			if is_instance_valid(p1):
				p1.level_id_mode = LEVEL_REGISTRY.LevelIdMode.ABSOLUTE
				p1.level_id = resolved_level_bottom
				p1.mask1 = bottom_mask
				p1.mask2 = collision_layer
				if should_override_delta:
					p1.delta_z = portal_delta_z

		# Apply to portal2 nodes: mask1 = collision_layer, mask2 = top level
		for p2 in layer2_nodes:
			if is_instance_valid(p2):
				p2.level_id_mode = LEVEL_REGISTRY.LevelIdMode.ABSOLUTE
				p2.level_id = resolved_level_top
				p2.mask1 = collision_layer
				p2.mask2 = top_mask
				if should_override_delta:
					p2.delta_z = portal_delta_z
	else:
		# Fallback to original behavior if level ids are not provided.
		# Apply to body nodes (CollisionObject2D): set collision_layer bits
		for body in body_nodes:
			if is_instance_valid(body):
				body.collision_layer = collision_layer

		# Apply to portal1 nodes: mask1 = layer1, mask2 = collision_layer
		for p1 in layer1_nodes:
			if is_instance_valid(p1):
				p1.mask1 = layer1
				p1.mask2 = collision_layer

		# Apply to portal2 nodes: mask1 = collision_layer, mask2 = layer2
		for p2 in layer2_nodes:
			if is_instance_valid(p2):
				p2.mask1 = collision_layer
				p2.mask2 = layer2

	if level_changed:
		resolved_level_changed.emit(m_resolved_level_id)
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super._ready()
	_rebind_level_dependencies()
	_update_mask()

func _exit_tree() -> void:
	_unbind_level_dependencies()

func _resolve_optional_level_id(local_level_id: int) -> int:
	if local_level_id < 0:
		return -1
	return _resolve_local_level_id(local_level_id)

func _resolve_local_level_id(local_level_id: int) -> int:
	return LEVEL_REGISTRY.resolve_level_id(self, local_level_id, level_id_mode)

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
	_update_mask()
