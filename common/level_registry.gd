@tool
class_name LevelRegistry

# Static global level lookup. Call `LevelRegistry.resolve_*()` directly.
enum LevelIdMode {
	ABSOLUTE,
	RELATIVE_TO_PARENT,
}

const BASE_COLLISION_MASK_BIT := 19

static func is_level_related_node(node: Node) -> bool:
	return node != null and node.has_method("get_resolved_level_id")

static func find_parent_level_node(node: Node) -> Node:
	var current := node.get_parent()
	while current != null:
		if is_level_related_node(current):
			return current
		current = current.get_parent()
	return null

static func resolve_level_id(node: Node, local_level_id: int, level_id_mode: int) -> int:
	if level_id_mode != LevelIdMode.RELATIVE_TO_PARENT:
		return local_level_id
	var parent_level_node := find_parent_level_node(node)
	if parent_level_node == null:
		return local_level_id
	return int(parent_level_node.call("get_resolved_level_id")) + local_level_id

static func has_level_data(level_id: int) -> bool:
	return level_id >= 0

static func resolve_level_physics_atlas_column(level_id: int, fallback_column: int = 0) -> int:
	if !has_level_data(level_id):
		return fallback_column
	return level_id

static func resolve_level_collision_mask(level_id: int, fallback_mask: int = 0) -> int:
	if !has_level_data(level_id):
		return fallback_mask
	return 1 << (BASE_COLLISION_MASK_BIT + level_id)

static func resolve_level_z_index(level_id: int, fallback_z_index: int = 0) -> int:
	if !has_level_data(level_id):
		return fallback_z_index
	return level_id

static func apply_level_to_actor(level_id: int, actor: Node2D) -> bool:
	if actor == null or !has_level_data(level_id):
		return false
	actor.collision_mask = resolve_level_collision_mask(level_id, actor.collision_mask)
	actor.z_index = resolve_level_z_index(level_id, actor.z_index)
	return true
