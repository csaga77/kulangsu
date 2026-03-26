@tool
class_name Tunnel
extends LevelNode2D

@onready var m_path_layer :TileMapLayer = $path
var m_walkable_world_positions: Array[Vector2] = []
var m_walkable_cells: Array[Vector2i] = []
var m_walkable_world_positions_by_cell: Dictionary = {}

const WALKABLE_NEIGHBORS := [
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.DOWN,
]

func contains_actor(actor_node: Node2D) -> bool:
	if actor_node == null:
		return false

	if actor_node.has_method("get_ground_rect"):
		return _contains_actor_rect(actor_node, actor_node.call("get_ground_rect"), false)

	if actor_node.has_method("get_bounding_rect"):
		return _contains_actor_rect(actor_node, actor_node.call("get_bounding_rect"), false)

	return false

func contains_actor_interior(actor_node: Node2D) -> bool:
	if actor_node == null:
		return false

	if actor_node.has_method("get_ground_rect"):
		return _contains_actor_rect(actor_node, actor_node.call("get_ground_rect"), true)

	if actor_node.has_method("get_bounding_rect"):
		return _contains_actor_rect(actor_node, actor_node.call("get_bounding_rect"), true)

	return false

func mask_player(player_node: Node2D, bounding_rect: Rect2) -> bool:
	return _contains_actor_rect(player_node, bounding_rect, true)

func snap_actor_to_walkable_position(actor_node: Node2D, desired_global_position: Vector2) -> Vector2:
	if actor_node == null or m_path_layer == null:
		return desired_global_position

	_cache_walkable_world_positions()

	var previous_position := actor_node.global_position
	actor_node.global_position = desired_global_position
	if contains_actor(actor_node):
		actor_node.global_position = previous_position
		return desired_global_position

	var nearest_position := desired_global_position
	var nearest_distance_sq := INF
	for walkable_position in m_walkable_world_positions:
		actor_node.global_position = walkable_position
		if !contains_actor(actor_node):
			continue

		var distance_sq := desired_global_position.distance_squared_to(walkable_position)
		if distance_sq < nearest_distance_sq:
			nearest_distance_sq = distance_sq
			nearest_position = walkable_position

	actor_node.global_position = previous_position
	return nearest_position


func get_path_between_world_positions(actor_node: Node2D, from_global_position: Vector2, to_global_position: Vector2) -> Array[Vector2]:
	_cache_walkable_world_positions()
	if m_path_layer == null or m_walkable_cells.is_empty():
		return [to_global_position]

	var start_cell := _find_nearest_walkable_cell(actor_node, from_global_position)
	var end_cell := _find_nearest_walkable_cell(actor_node, to_global_position)
	if start_cell == end_cell:
		return [_world_position_for_cell(end_cell)]

	var frontier: Array[Vector2i] = [start_cell]
	var came_from: Dictionary = {
		start_cell: start_cell,
	}

	while !frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		if current == end_cell:
			break

		for direction in WALKABLE_NEIGHBORS:
			var neighbor: Vector2i = current + Vector2i(direction)
			if !m_walkable_world_positions_by_cell.has(neighbor):
				continue
			if came_from.has(neighbor):
				continue
			came_from[neighbor] = current
			frontier.append(neighbor)

	if !came_from.has(end_cell):
		return [_world_position_for_cell(end_cell)]

	var reverse_cells: Array[Vector2i] = []
	var cursor: Vector2i = end_cell
	while cursor != start_cell:
		reverse_cells.append(cursor)
		cursor = came_from[cursor]

	reverse_cells.reverse()

	var world_path: Array[Vector2] = []
	for cell in reverse_cells:
		world_path.append(_world_position_for_cell(cell))
	return world_path

func _contains_actor_rect(actor_node: Node2D, bounding_rect: Rect2, require_matching_level: bool) -> bool:
	if actor_node == null:
		return false

	if m_path_layer == null:
		return false

	if require_matching_level and !_actor_is_on_tunnel_level(actor_node):
		return false

	return TileMapUtils.intersects_iso_grid_rect_global(m_path_layer, bounding_rect)

func _ready() -> void:
	super._ready()
	_cache_walkable_world_positions()

func _process(delta: float) -> void:
	pass

func _cache_walkable_world_positions() -> void:
	m_walkable_world_positions.clear()
	m_walkable_cells.clear()
	m_walkable_world_positions_by_cell.clear()
	if m_path_layer == null:
		return

	for cell in m_path_layer.get_used_cells():
		var world_position := _world_position_for_cell(cell)
		m_walkable_cells.append(cell)
		m_walkable_world_positions.append(world_position)
		m_walkable_world_positions_by_cell[cell] = world_position


func _find_nearest_walkable_cell(actor_node: Node2D, desired_global_position: Vector2) -> Vector2i:
	var snapped_position := snap_actor_to_walkable_position(actor_node, desired_global_position)
	var nearest_cell := Vector2i.ZERO
	var nearest_distance_sq := INF

	for cell in m_walkable_cells:
		var world_position: Vector2 = m_walkable_world_positions_by_cell.get(cell, Vector2.ZERO)
		var distance_sq := snapped_position.distance_squared_to(world_position)
		if distance_sq < nearest_distance_sq:
			nearest_distance_sq = distance_sq
			nearest_cell = cell

	return nearest_cell


func _world_position_for_cell(cell: Vector2i) -> Vector2:
	return m_path_layer.to_global(m_path_layer.map_to_local(cell))


func _actor_is_on_tunnel_level(actor_node: Node2D) -> bool:
	return CommonUtils.get_absolute_z_index(actor_node) == get_resolved_level_id()
