class_name RouteResolver
extends RefCounted

const LEVEL_REGISTRY := preload("res://common/level_registry.gd")
const TUNNEL_ENTRY_FRONT_APPROACH_DISTANCE := 96.0
const TUNNEL_PORTAL_SUFFIX := " Portal"
const DIRECTIONAL_PORTAL_MIN_OFFSET_DISTANCE := 16.0

var m_spawn_anchor_nodes: Dictionary = {}


func _init(spawn_anchor_nodes: Dictionary = {}) -> void:
	update_spawn_anchor_nodes(spawn_anchor_nodes)


func update_spawn_anchor_nodes(spawn_anchor_nodes: Dictionary) -> void:
	m_spawn_anchor_nodes = spawn_anchor_nodes


func build_resident_movement_config(resident_id: String, actor: HumanBody2D, movement_config: Dictionary) -> Dictionary:
	if movement_config.is_empty():
		return {}

	var resolved_route_points: Array[Dictionary] = []
	var previous_position := Vector2.ZERO
	var previous_anchor_id := ""
	var previous_anchor_node: Node2D = null
	var previous_tunnel: Tunnel = null
	var has_previous_point := false
	for point_value in movement_config.get("route_points", []):
		var route_point := point_value as Dictionary
		if route_point.is_empty():
			continue

		var anchor_id := String(route_point.get("anchor_id", ""))
		var anchor_node := m_spawn_anchor_nodes.get(anchor_id) as Node2D
		if !is_instance_valid(anchor_node):
			push_warning("Missing NPC movement anchor '%s' for resident '%s'." % [anchor_id, resident_id])
			return {}

		var point_copy := route_point.duplicate(true)
		var route_offset: Vector2 = route_point.get("offset", Vector2.ZERO)
		var resolved_position := resolve_route_anchor_position(actor, anchor_id, anchor_node, route_offset)
		var route_tunnel := find_walkable_tunnel_ancestor(anchor_node)
		if has_previous_point and route_tunnel != null and route_tunnel == previous_tunnel:
			var tunnel_path := route_tunnel.get_path_between_world_positions(actor, previous_position, resolved_position)
			for i in range(maxi(tunnel_path.size() - 1, 0)):
				resolved_route_points.append({
					"position": tunnel_path[i],
					"wait_min_sec": 0.0,
					"wait_max_sec": 0.0,
					"allow_collision_bypass": true,
				})
		elif has_previous_point:
			var transition_points := build_tunnel_boundary_transition_points(
				actor,
				previous_anchor_id,
				previous_anchor_node,
				previous_position,
				anchor_id,
				anchor_node,
				resolved_position
			)
			for transition_point in transition_points:
				resolved_route_points.append(transition_point)

		if route_tunnel != null or anchor_id.ends_with(TUNNEL_PORTAL_SUFFIX):
			point_copy["allow_collision_bypass"] = true
		point_copy["position"] = resolved_position
		point_copy.erase("anchor_id")
		point_copy.erase("offset")
		resolved_route_points.append(point_copy)
		previous_position = resolved_position
		previous_anchor_id = anchor_id
		previous_anchor_node = anchor_node
		previous_tunnel = route_tunnel
		has_previous_point = true

	if resolved_route_points.size() < 2:
		return {}

	var resolved_config := movement_config.duplicate(true)
	resolved_config["route_points"] = resolved_route_points
	return resolved_config


func resolve_actor_anchor_position(actor: HumanBody2D, anchor_node: Node2D, offset: Vector2) -> Vector2:
	if !is_instance_valid(anchor_node):
		return offset

	var desired_position := anchor_node.global_position + offset
	var tunnel_anchor := find_walkable_tunnel_ancestor(anchor_node)
	if tunnel_anchor == null:
		return desired_position

	return tunnel_anchor.snap_actor_to_walkable_position(actor, desired_position)


func resolve_route_anchor_position(actor: HumanBody2D, anchor_id: String, anchor_node: Node2D, offset: Vector2) -> Vector2:
	if anchor_id.ends_with(TUNNEL_PORTAL_SUFFIX):
		return resolve_directional_portal_route_position(actor, anchor_id, anchor_node, offset)
	return resolve_actor_anchor_position(actor, anchor_node, offset)


func resolve_directional_portal_route_position(
	actor: HumanBody2D,
	portal_anchor_id: String,
	portal_anchor_node: Node2D,
	offset: Vector2
) -> Vector2:
	var entry_anchor_id := get_tunnel_entry_anchor_id_for_portal(portal_anchor_id)
	if entry_anchor_id.is_empty():
		return resolve_actor_anchor_position(actor, portal_anchor_node, offset)

	var entry_anchor_node := m_spawn_anchor_nodes.get(entry_anchor_id) as Node2D
	if !is_instance_valid(entry_anchor_node):
		return resolve_actor_anchor_position(actor, portal_anchor_node, offset)

	var portal_center := resolve_portal_center_position(actor, portal_anchor_node)
	var portal_direction := get_portal_direction_vector(portal_anchor_node)
	if portal_direction.length_squared() <= 0.001:
		return resolve_actor_anchor_position(actor, portal_anchor_node, offset)
	var portal_lateral := get_portal_lateral_vector(portal_anchor_node)

	var tunnel_side_sign := get_portal_tunnel_side_sign(portal_anchor_node)
	var portal_distance := maxf(absf(offset.x), DIRECTIONAL_PORTAL_MIN_OFFSET_DISTANCE)
	var lateral_offset := offset.y

	return portal_center + portal_direction * tunnel_side_sign * portal_distance + portal_lateral * lateral_offset


func build_tunnel_boundary_transition_points(
	actor: HumanBody2D,
	previous_anchor_id: String,
	previous_anchor_node: Node2D,
	previous_position: Vector2,
	current_anchor_id: String,
	current_anchor_node: Node2D,
	current_position: Vector2
) -> Array[Dictionary]:
	var portal_anchor_id := ""
	var portal_anchor_node: Node2D = null

	if get_tunnel_entry_anchor_id_for_portal(previous_anchor_id) == current_anchor_id:
		portal_anchor_id = previous_anchor_id
		portal_anchor_node = previous_anchor_node
	elif get_tunnel_entry_anchor_id_for_portal(current_anchor_id) == previous_anchor_id:
		portal_anchor_id = current_anchor_id
		portal_anchor_node = current_anchor_node
	else:
		return []

	if !is_instance_valid(portal_anchor_node):
		return []

	var entry_anchor_id := get_tunnel_entry_anchor_id_for_portal(portal_anchor_id)
	var entry_anchor_node := m_spawn_anchor_nodes.get(entry_anchor_id) as Node2D
	if !is_instance_valid(entry_anchor_node):
		return []

	var portal_center := resolve_portal_center_position(actor, portal_anchor_node)
	var portal_direction := get_portal_direction_vector(portal_anchor_node)
	if portal_direction.length_squared() <= 0.001:
		return []

	var transition_points: Array[Dictionary] = []
	var outside_side_sign := -get_portal_tunnel_side_sign(portal_anchor_node)
	var portal_target_position := current_position if portal_anchor_id == current_anchor_id else previous_position
	var relative_to_portal := portal_target_position - portal_center
	var lateral_component := relative_to_portal - portal_direction * relative_to_portal.dot(portal_direction)
	append_unique_transition_point(
		transition_points,
		portal_center + portal_direction * outside_side_sign * TUNNEL_ENTRY_FRONT_APPROACH_DISTANCE + lateral_component
	)

	return transition_points


func append_unique_transition_point(points: Array[Dictionary], candidate: Vector2) -> void:
	if !points.is_empty():
		var previous_position: Vector2 = points[points.size() - 1].get("position", Vector2.ZERO)
		if previous_position.distance_to(candidate) <= 1.0:
			return

	points.append({
		"position": candidate,
		"wait_min_sec": 0.0,
		"wait_max_sec": 0.0,
		"allow_collision_bypass": true,
	})


func get_tunnel_entry_anchor_id_for_portal(anchor_id: String) -> String:
	if !anchor_id.ends_with(TUNNEL_PORTAL_SUFFIX):
		return ""
	return anchor_id.left(anchor_id.length() - TUNNEL_PORTAL_SUFFIX.length())


func resolve_portal_center_position(actor: HumanBody2D, portal_anchor_node: Node2D) -> Vector2:
	var portal_node := get_portal_for_anchor(portal_anchor_node)
	if portal_node != null:
		return resolve_actor_anchor_position(actor, portal_node, Vector2.ZERO)
	return resolve_actor_anchor_position(actor, portal_anchor_node, Vector2.ZERO)


func get_portal_direction_vector(portal_anchor_node: Node2D) -> Vector2:
	var portal_node := get_portal_for_anchor(portal_anchor_node)
	if portal_node == null:
		return Vector2.ZERO

	var collision_shape := portal_node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null:
		return collision_shape.global_transform.x.normalized()

	return portal_node.global_transform.x.normalized()


func get_portal_lateral_vector(portal_anchor_node: Node2D) -> Vector2:
	var portal_node := get_portal_for_anchor(portal_anchor_node)
	if portal_node == null:
		return Vector2.ZERO

	var collision_shape := portal_node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null:
		return collision_shape.global_transform.y.normalized()

	return portal_node.global_transform.y.normalized()


func get_portal_tunnel_side_sign(portal_anchor_node: Node2D) -> float:
	var portal_node := get_portal_for_anchor(portal_anchor_node)
	var tunnel_anchor := find_tunnel_ancestor(portal_anchor_node)
	if portal_node == null or tunnel_anchor == null:
		return 1.0

	var tunnel_mask := LEVEL_REGISTRY.resolve_level_collision_mask(tunnel_anchor.get_resolved_level_id())
	if (int(portal_node.get("mask1")) & tunnel_mask) != 0:
		return -1.0
	if (int(portal_node.get("mask2")) & tunnel_mask) != 0:
		return 1.0
	return 1.0


func get_portal_for_anchor(anchor_node: Node2D) -> Portal:
	if anchor_node == null:
		return null

	var direct_portal := anchor_node as Portal
	if direct_portal != null:
		return direct_portal

	for child in anchor_node.get_children():
		var portal_child := child as Portal
		if portal_child != null:
			return portal_child

	return null


func apply_anchor_level_to_actor(actor: HumanBody2D, anchor_node: Node) -> void:
	if !is_instance_valid(actor):
		return

	var level_node := find_level_node(anchor_node)
	if level_node == null:
		return

	LEVEL_REGISTRY.apply_level_to_actor(int(level_node.call("get_resolved_level_id")), actor)


func find_tunnel_ancestor(start_node: Node) -> Tunnel:
	var current := start_node
	while current != null:
		var tunnel := current as Tunnel
		if tunnel != null:
			return tunnel
		current = current.get_parent()
	return null


func find_level_node(start_node: Node) -> Node:
	var tunnel_anchor := find_tunnel_ancestor(start_node)
	if tunnel_anchor != null and !tunnel_anchor.uses_walkable_path_for_anchor(start_node):
		return null

	var current := start_node
	while current != null:
		if current.has_method("get_resolved_level_id"):
			return current
		current = current.get_parent()
	return null


func find_walkable_tunnel_ancestor(start_node: Node) -> Tunnel:
	var tunnel_anchor := find_tunnel_ancestor(start_node)
	if tunnel_anchor == null:
		return null
	if !tunnel_anchor.uses_walkable_path_for_anchor(start_node):
		return null
	return tunnel_anchor
