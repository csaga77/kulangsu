@tool
extends Node

const GAME_MAIN_SCENE := preload("res://scenes/game_main.tscn")
const APP_RUNTIME := preload("res://game/app_runtime.gd")
const ROUTED_RESIDENT_ID := "tunnel_guide"
const SECOND_ROUTED_RESIDENT_ID := "tunnel_listener_nuo"
const WAIT_TIMEOUT_SEC := 18.0
const TUNNEL_ENTRY_FRONT_APPROACH_DISTANCE := 96.0
const DIRECTIONAL_PORTAL_MIN_OFFSET_DISTANCE := 16.0
const ROUTE_POSITION_TOLERANCE := 8.0


func _app_state():
	return APP_RUNTIME.get_app_state(self)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	call_deferred("_run")


func _run() -> void:
	_app_state().configure_new_game()
	var game_main := GAME_MAIN_SCENE.instantiate()
	add_child(game_main)

	await _settle()

	var residents_root := game_main.get_node("actors/Residents") as Node2D
	var long_shan_tunnel := game_main.get_node("terrain/long_shan_tunnel") as Tunnel
	var bi_shan_tunnel := game_main.get_node("terrain/bi_shan_tunnel") as Tunnel
	var long_shan_portal_south := game_main.get_node("terrain/long_shan_tunnel/exit_south") as Node2D
	var long_shan_portal_north := game_main.get_node("terrain/long_shan_tunnel/exit_north") as Node2D
	var bi_shan_entry_south := game_main.get_node("terrain/ground/bi_shan_tunnel_entries/entry_south") as Node2D
	var bi_shan_portal_south := game_main.get_node("terrain/bi_shan_tunnel/exit_south") as Node2D
	var routed_resident := _resident_node(residents_root, ROUTED_RESIDENT_ID)
	var second_routed_resident := _resident_node(residents_root, SECOND_ROUTED_RESIDENT_ID)
	var routed_controller := routed_resident.controller as NPCController
	var second_routed_controller := second_routed_resident.controller as NPCController
	var outside_level_id := 0
	var outside_collision_mask := LevelRegistry.resolve_level_collision_mask(outside_level_id)

	_assert(residents_root != null, "Resident root did not load.")
	_assert(long_shan_tunnel != null, "Long Shan Tunnel did not load.")
	_assert(bi_shan_tunnel != null, "Bi Shan Tunnel did not load.")
	_assert(long_shan_portal_south != null, "Long Shan Tunnel south portal did not load.")
	_assert(long_shan_portal_north != null, "Long Shan Tunnel north portal did not load.")
	_assert(bi_shan_entry_south != null, "Bi Shan Tunnel south entry did not load.")
	_assert(bi_shan_portal_south != null, "Bi Shan Tunnel south portal did not load.")
	_assert(routed_resident != null, "Routed resident did not load.")
	_assert(second_routed_resident != null, "Second routed resident did not load.")
	_assert(routed_controller != null, "%s controller did not load." % routed_resident.name)
	_assert(second_routed_controller != null, "%s controller did not load." % second_routed_resident.name)
	_assert(long_shan_tunnel.contains_actor_interior(routed_resident), "%s should start inside Long Shan Tunnel interior." % routed_resident.name)
	_assert(bi_shan_tunnel.contains_actor_interior(second_routed_resident), "%s should start inside Bi Shan Tunnel interior." % second_routed_resident.name)
	_assert(!routed_resident.visible, "%s should start hidden while the player is outside." % routed_resident.name)
	_assert_tunnel_portal_endpoint(
		routed_resident,
		routed_controller,
		long_shan_tunnel,
		long_shan_portal_south,
		Vector2(-32.0, 0.0),
		0,
		"%s route should start at the south tunnel mouth inside the walls." % routed_resident.name
	)
	_assert_route_contains_point_after(
		routed_controller.m_route_points,
		long_shan_tunnel.snap_actor_to_walkable_position(
			routed_resident,
			long_shan_tunnel.global_position + Vector2(-1536.0, -1072.0)
		),
		ROUTE_POSITION_TOLERANCE,
		"%s route should include a mid-tunnel interior point." % routed_resident.name
	)
	_assert_tunnel_portal_endpoint(
		routed_resident,
		routed_controller,
		long_shan_tunnel,
		long_shan_portal_north,
		Vector2(-32.0, 0.0),
		routed_controller.m_route_points.size() - 1,
		"%s route should end at the north tunnel mouth inside the walls." % routed_resident.name
	)
	_assert_route_points_on_tunnel_path(
		long_shan_tunnel,
		routed_controller.m_route_points,
		"%s route should stay on the tunnel interior path." % routed_resident.name
	)
	_assert_front_entry_transition(
		second_routed_resident,
		second_routed_controller,
		bi_shan_tunnel,
		bi_shan_portal_south,
		bi_shan_entry_south,
		Vector2(40.0, 0.0),
		Vector2(288.0, -144.0)
	)
	_assert_animation_advances_while_moving(routed_resident, WAIT_TIMEOUT_SEC)

	await _wait_for_tunnel_state(second_routed_resident, bi_shan_tunnel, false, WAIT_TIMEOUT_SEC)
	_assert(second_routed_resident.visible, "%s should be visible once they walk outside while the player is outside." % second_routed_resident.name)
	_assert(CommonUtils.get_absolute_z_index(second_routed_resident) == outside_level_id, "%s should resolve back to outside z %d." % [second_routed_resident.name, outside_level_id])
	_assert(second_routed_resident.collision_mask == outside_collision_mask, "%s should resolve back to outside collision mask %d." % [second_routed_resident.name, outside_collision_mask])

	print("Tunnel NPC travel regression passed.")
	get_tree().quit(0)


func _assert_tunnel_portal_endpoint(
	resident: HumanBody2D,
	controller: NPCController,
	tunnel: Tunnel,
	portal_anchor: Node2D,
	portal_offset: Vector2,
	expected_index: int,
	message: String
) -> void:
	var route_points := controller.m_route_points
	_assert(expected_index >= 0 and expected_index < route_points.size(), message)

	var portal := _portal_node(portal_anchor)
	_assert(portal != null, "%s should expose a portal node for route checks." % resident.name)
	var portal_center := _resolve_portal_center(tunnel, resident, portal_anchor)
	var portal_direction := _portal_direction_vector(portal_anchor)
	var portal_lateral := _portal_lateral_vector(portal_anchor)
	var tunnel_side_sign := _portal_tunnel_side_sign(tunnel, portal_anchor)
	var portal_distance := maxf(absf(portal_offset.x), DIRECTIONAL_PORTAL_MIN_OFFSET_DISTANCE)
	var lateral_component := portal_lateral * portal_offset.y
	var portal_target := portal_center + portal_direction * tunnel_side_sign * portal_distance + lateral_component
	var route_position: Vector2 = route_points[expected_index].get("position", Vector2.ZERO)

	_assert(route_position.distance_to(portal_target) <= ROUTE_POSITION_TOLERANCE, message)


func _assert_route_points_on_tunnel_path(tunnel: Tunnel, route_points: Array[Dictionary], message: String) -> void:
	var path_layer := tunnel.get_node_or_null("path") as TileMapLayer
	_assert(path_layer != null, "%s Missing tunnel path layer." % message)

	var used_cells := path_layer.get_used_cells()
	for route_point in route_points:
		var route_position: Vector2 = route_point.get("position", Vector2.ZERO)
		var local_position := path_layer.to_local(route_position)
		var cell := path_layer.local_to_map(local_position)
		_assert(used_cells.has(cell), message)


func _assert_front_entry_transition(
	resident: HumanBody2D,
	controller: NPCController,
	tunnel: Tunnel,
	portal_anchor: Node2D,
	entry_anchor: Node2D,
	portal_offset: Vector2,
	outside_offset: Vector2,
	outside_axis_lateral_tolerance: float = -1.0
) -> void:
	var route_points := controller.m_route_points
	_assert(route_points.size() >= 4, "%s should have a resolved route with tunnel boundary waypoints." % resident.name)

	var portal := _portal_node(portal_anchor)
	_assert(portal != null, "%s should expose a portal node for route checks." % resident.name)
	var portal_center := _resolve_portal_center(tunnel, resident, portal_anchor)
	var portal_direction := _portal_direction_vector(portal_anchor)
	var portal_lateral := _portal_lateral_vector(portal_anchor)
	_assert(portal_direction.length_squared() > 0.001, "%s should expose a usable portal direction." % resident.name)

	var tunnel_side_sign := _portal_tunnel_side_sign(tunnel, portal_anchor)
	var outside_side_sign := -tunnel_side_sign
	var portal_distance := maxf(absf(portal_offset.x), DIRECTIONAL_PORTAL_MIN_OFFSET_DISTANCE)
	var lateral_component := portal_lateral * portal_offset.y

	var portal_target := portal_center + portal_direction * tunnel_side_sign * portal_distance + lateral_component
	var outside_portal_position := portal_center + portal_direction * outside_side_sign * TUNNEL_ENTRY_FRONT_APPROACH_DISTANCE + lateral_component
	var outside_target := entry_anchor.global_position + outside_offset
	var outside_target_local := portal.to_local(outside_target)
	var portal_index := _find_route_point_index(route_points, portal_target, ROUTE_POSITION_TOLERANCE)
	var outside_portal_index := _find_route_point_index_in_range(
		route_points,
		outside_portal_position,
		portal_index + 1,
		route_points.size() - 1,
		ROUTE_POSITION_TOLERANCE
	)
	var outside_index := _find_route_point_index_in_range(
		route_points,
		outside_target,
		outside_portal_index + 1,
		route_points.size() - 1,
		ROUTE_POSITION_TOLERANCE
	)

	_assert(portal_index >= 0, "%s route should include the portal target." % resident.name)
	_assert(outside_portal_index > portal_index, "%s route should include an outside portal-approach waypoint." % resident.name)
	_assert(outside_index > portal_index, "%s route should continue from the portal to an outside target." % resident.name)
	_assert(
		outside_index - portal_index >= 2,
		"%s should route through the portal direction before reaching the outside target." % resident.name
	)
	_assert(
		outside_portal_index < outside_index,
		"%s should follow the portal-direction approach before heading to the outside target." % resident.name
	)
	if outside_axis_lateral_tolerance >= 0.0:
		_assert(
			absf(outside_target_local.y) <= outside_axis_lateral_tolerance,
			"%s outside wait point should stay aligned to the portal axis." % resident.name
		)


func _assert_animation_advances_while_moving(resident: HumanBody2D, timeout_sec: float) -> void:
	var sprite := _resident_sprite(resident)
	_assert(sprite != null, "%s should expose an AnimatedSprite2D for animation checks." % resident.name)

	var elapsed := 0.0
	var previous_position := resident.global_position
	var previous_frame := sprite.frame
	var previous_progress := sprite.frame_progress
	var saw_movement := false

	while elapsed < timeout_sec:
		await get_tree().physics_frame
		await get_tree().process_frame

		var moved := resident.global_position.distance_to(previous_position) > 0.5
		if moved:
			saw_movement = true
			var frame_changed := sprite.frame != previous_frame
			var progress_changed := !is_equal_approx(sprite.frame_progress, previous_progress)
			if frame_changed or progress_changed:
				return

		previous_position = resident.global_position
		previous_frame = sprite.frame
		previous_progress = sprite.frame_progress
		elapsed += get_process_delta_time()

	if !saw_movement:
		_assert(false, "%s did not start moving within %.1f seconds." % [resident.name, timeout_sec])
		return

	_assert(false, "%s moved, but the walk animation never advanced within %.1f seconds." % [resident.name, timeout_sec])


func _wait_for_tunnel_state(resident: HumanBody2D, tunnel: Tunnel, expected_inside: bool, timeout_sec: float) -> void:
	var elapsed := 0.0
	while elapsed < timeout_sec:
		if tunnel.contains_actor_interior(resident) == expected_inside:
			await _settle()
			return
		await get_tree().physics_frame
		await get_tree().process_frame
		elapsed += get_process_delta_time()

	_assert(false, "%s did not reach expected tunnel state=%s within %.1f seconds." % [resident.name, str(expected_inside), timeout_sec])


func _resident_node(residents_root: Node2D, resident_id: String) -> HumanBody2D:
	var display_name = _app_state().get_resident_display_name(resident_id)
	var resident := residents_root.get_node_or_null(display_name) as HumanBody2D
	_assert(resident != null, "Resident '%s' did not spawn." % resident_id)
	return resident


func _resident_sprite(resident: HumanBody2D) -> AnimatedSprite2D:
	if resident == null:
		return null

	var sprite_root := resident.get_node_or_null("universal_lpc_sprite")
	if sprite_root == null:
		return null

	var sprite_nodes := sprite_root.find_children("*", "AnimatedSprite2D", true, false)
	if sprite_nodes.is_empty():
		return null

	return sprite_nodes[0] as AnimatedSprite2D


func _resolve_portal_center(tunnel: Tunnel, resident: HumanBody2D, portal_anchor: Node2D) -> Vector2:
	var portal_node := _portal_node(portal_anchor)
	if portal_node != null:
		return tunnel.snap_actor_to_walkable_position(resident, portal_node.global_position)
	return tunnel.snap_actor_to_walkable_position(resident, portal_anchor.global_position)


func _portal_direction_vector(portal_anchor: Node2D) -> Vector2:
	var portal_node := _portal_node(portal_anchor)
	if portal_node == null:
		return Vector2.ZERO

	var collision_shape := portal_node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null:
		return collision_shape.global_transform.x.normalized()

	return portal_node.global_transform.x.normalized()


func _portal_lateral_vector(portal_anchor: Node2D) -> Vector2:
	var portal_node := _portal_node(portal_anchor)
	if portal_node == null:
		return Vector2.ZERO

	var collision_shape := portal_node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null:
		return collision_shape.global_transform.y.normalized()

	return portal_node.global_transform.y.normalized()


func _portal_tunnel_side_sign(tunnel: Tunnel, portal_anchor: Node2D) -> float:
	var portal_node := _portal_node(portal_anchor)
	if portal_node == null or tunnel == null:
		return 1.0

	var tunnel_mask := LevelRegistry.resolve_level_collision_mask(tunnel.get_resolved_level_id())
	if (int(portal_node.get("mask1")) & tunnel_mask) != 0:
		return -1.0
	if (int(portal_node.get("mask2")) & tunnel_mask) != 0:
		return 1.0
	return 1.0


func _portal_node(portal_anchor: Node2D) -> Portal:
	if portal_anchor == null:
		return null

	var direct_portal := portal_anchor as Portal
	if direct_portal != null:
		return direct_portal

	for child in portal_anchor.get_children():
		var portal_child := child as Portal
		if portal_child != null:
			return portal_child

	return null


func _find_route_point_index(route_points: Array[Dictionary], target_position: Vector2, tolerance: float) -> int:
	return _find_route_point_index_in_range(route_points, target_position, 0, route_points.size() - 1, tolerance)


func _find_route_point_index_in_range(
	route_points: Array[Dictionary],
	target_position: Vector2,
	start_index: int,
	end_index: int,
	tolerance: float
) -> int:
	if route_points.is_empty():
		return -1

	var clamped_start := maxi(start_index, 0)
	var clamped_end := mini(end_index, route_points.size() - 1)
	for i in range(clamped_start, clamped_end + 1):
		var route_position: Vector2 = route_points[i].get("position", Vector2.ZERO)
		if route_position.distance_to(target_position) <= tolerance:
			return i

	return -1


func _assert_route_contains_point_after(
	route_points: Array[Dictionary],
	target_position: Vector2,
	tolerance: float,
	message: String
) -> void:
	var target_index := _find_route_point_index(route_points, target_position, tolerance)
	_assert(target_index >= 0, message)


func _settle() -> void:
	await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().process_frame


func _assert(condition: bool, message: String) -> void:
	if condition:
		return

	push_error(message)
	get_tree().quit(1)
