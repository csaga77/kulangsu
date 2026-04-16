@tool
extends Node

const GAME_MAIN_SCENE := preload("res://scenes/game_main.tscn")
const APP_RUNTIME := preload("res://game/app_runtime.gd")
const StorySubjectArea2D = preload("res://game/story_subject_area.gd")
const BI_SHAN_RESIDENT_IDS := [
	"echo_sketcher_yan",
	"mural_restorer_cai",
	"tunnel_listener_nuo",
]
const LONG_SHAN_RESIDENT_IDS := [
	"tunnel_guide",
	"raincoat_child_xiu",
	"storyteller_wen",
	"rope_handler_qiu",
	"porter_shan",
	"light_watcher_he",
]
const TUNNEL_MANAGED_RESIDENT_IDS := BI_SHAN_RESIDENT_IDS + LONG_SHAN_RESIDENT_IDS
const MIN_TUNNEL_SPACING := 220.0
const OUTSIDE_PLAYER_POSITION := Vector2(-263.0, 8541.0)


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

	await get_tree().process_frame
	await get_tree().process_frame

	var player := game_main.get_node("actors/player") as HumanBody2D
	var residents_root := game_main.get_node("actors/Residents") as Node2D
	var terrain := game_main.get_node("terrain") as Node2D
	var ground := game_main.get_node("terrain/ground") as AutoVisibilityNode2D
	var bi_shan_tunnel := game_main.get_node("terrain/bi_shan_tunnel") as Tunnel
	var long_shan_tunnel := game_main.get_node("terrain/long_shan_tunnel") as Tunnel
	var initial_player_z := player.z_index
	var initial_player_collision_mask := player.collision_mask
	var tunnels: Array[Tunnel] = [bi_shan_tunnel, long_shan_tunnel]

	_assert(player != null, "Player did not load.")
	_assert(residents_root != null, "Resident root did not load.")
	_assert(terrain != null, "Terrain root did not load.")
	_assert(ground != null, "Ground visibility node did not load.")
	_assert(bi_shan_tunnel != null, "Bi Shan Tunnel did not load.")
	_assert(long_shan_tunnel != null, "Long Shan Tunnel did not load.")

	ground.smooth_visibility_change = false
	ground._update_visibility()

	_assert_tunnel_trigger_ownership(terrain, bi_shan_tunnel, long_shan_tunnel)
	_assert_group_in_tunnel(residents_root, bi_shan_tunnel, BI_SHAN_RESIDENT_IDS)
	_assert_group_in_tunnel(residents_root, long_shan_tunnel, LONG_SHAN_RESIDENT_IDS)
	_assert_group_on_tunnel_level(residents_root, bi_shan_tunnel, BI_SHAN_RESIDENT_IDS)
	_assert_group_on_tunnel_level(residents_root, long_shan_tunnel, LONG_SHAN_RESIDENT_IDS)
	_assert_group_spacing(residents_root, BI_SHAN_RESIDENT_IDS, MIN_TUNNEL_SPACING)
	_assert_group_spacing(residents_root, LONG_SHAN_RESIDENT_IDS, MIN_TUNNEL_SPACING)
	var non_tunnel_snapshots := _capture_non_tunnel_resident_state(residents_root)
	_assert_visibility_matches_player_context(
		player,
		residents_root,
		tunnels,
		non_tunnel_snapshots,
		"Initial outside state should match tunnel context."
	)
	_assert_tunnel_presentation(bi_shan_tunnel, false, "Initial outside state should keep Bi Shan on its exterior presentation.")
	_assert_tunnel_presentation(long_shan_tunnel, false, "Initial outside state should keep Long Shan on its exterior presentation.")
	_assert(ground.visible, "Ground should stay visible while the player is outside.")

	_move_player_over_tunnel_surface(player, _resident_node(residents_root, BI_SHAN_RESIDENT_IDS[0]), initial_player_z, initial_player_collision_mask)
	await get_tree().process_frame
	await get_tree().process_frame
	_assert(bi_shan_tunnel.contains_actor(player), "Surface overlap case should still place the player over the Bi Shan tunnel footprint.")
	_assert(!bi_shan_tunnel.contains_actor_interior(player), "Surface overlap case should not count as being inside Bi Shan Tunnel.")
	_assert_visibility_matches_player_context(
		player,
		residents_root,
		tunnels,
		non_tunnel_snapshots,
		"Surface overlap should still use outside tunnel visibility."
	)
	_assert_tunnel_presentation(bi_shan_tunnel, false, "Surface overlap should not switch Bi Shan to its interior presentation.")
	_assert_tunnel_presentation(long_shan_tunnel, false, "Surface overlap should not affect Long Shan presentation.")
	_assert(ground.visible, "Ground should stay visible while the player only overlaps the tunnel footprint on the surface.")

	_move_player_into_tunnel(player, bi_shan_tunnel, _resident_node(residents_root, BI_SHAN_RESIDENT_IDS[0]), initial_player_z, initial_player_collision_mask)
	await get_tree().process_frame
	await get_tree().process_frame
	_assert_visibility_matches_player_context(
		player,
		residents_root,
		tunnels,
		non_tunnel_snapshots,
		"Bi Shan tunnel state should match tunnel context."
	)
	_assert_tunnel_presentation(bi_shan_tunnel, true, "Bi Shan should switch to its interior presentation once the player enters.")
	_assert_tunnel_presentation(long_shan_tunnel, false, "Long Shan should stay on its exterior presentation while Bi Shan is active.")
	_assert(ground.visible == false, "Ground should hide while the player is inside Bi Shan Tunnel.")

	_move_player_outside(player, initial_player_z, initial_player_collision_mask)
	await get_tree().process_frame
	await get_tree().process_frame
	_assert_visibility_matches_player_context(
		player,
		residents_root,
		tunnels,
		non_tunnel_snapshots,
		"Returning outside should restore outside context visibility."
	)
	_assert_tunnel_presentation(bi_shan_tunnel, false, "Leaving Bi Shan should restore its exterior presentation.")
	_assert_tunnel_presentation(long_shan_tunnel, false, "Leaving Bi Shan should leave Long Shan on its exterior presentation.")
	_assert(ground.visible, "Ground should reappear after leaving the tunnel.")

	_move_player_into_tunnel(player, long_shan_tunnel, _resident_node(residents_root, LONG_SHAN_RESIDENT_IDS[0]), initial_player_z, initial_player_collision_mask)
	await get_tree().process_frame
	await get_tree().process_frame
	_assert_visibility_matches_player_context(
		player,
		residents_root,
		tunnels,
		non_tunnel_snapshots,
		"Long Shan tunnel state should match tunnel context."
	)
	_assert_tunnel_presentation(bi_shan_tunnel, false, "Bi Shan should stay on its exterior presentation while Long Shan is active.")
	_assert_tunnel_presentation(long_shan_tunnel, true, "Long Shan should switch to its interior presentation once the player enters.")
	_assert(ground.visible == false, "Ground should hide while the player is inside Long Shan Tunnel.")

	print("Tunnel NPC visibility regression passed.")
	get_tree().quit(0)


func _assert_group_in_tunnel(residents_root: Node2D, tunnel: Tunnel, resident_ids: Array) -> void:
	for resident_id in resident_ids:
		var resident := _resident_node(residents_root, resident_id)
		_assert(tunnel.contains_actor(resident), "%s should spawn inside %s." % [resident.name, tunnel.name])


func _assert_group_spacing(residents_root: Node2D, resident_ids: Array, min_spacing: float) -> void:
	for i in range(resident_ids.size()):
		var resident_a := _resident_node(residents_root, resident_ids[i])
		for j in range(i + 1, resident_ids.size()):
			var resident_b := _resident_node(residents_root, resident_ids[j])
			var distance := resident_a.global_position.distance_to(resident_b.global_position)
			_assert(distance >= min_spacing, "%s and %s are too close together (%.1f)." % [resident_a.name, resident_b.name, distance])


func _assert_group_on_tunnel_level(residents_root: Node2D, tunnel: Tunnel, resident_ids: Array) -> void:
	var expected_z := tunnel.get_resolved_level_id()
	var expected_mask := LevelRegistry.resolve_level_collision_mask(expected_z)
	for resident_id in resident_ids:
		var resident := _resident_node(residents_root, resident_id)
		_assert(CommonUtils.get_absolute_z_index(resident) == expected_z, "%s should start on tunnel z %d." % [resident.name, expected_z])
		_assert(resident.collision_mask == expected_mask, "%s should start on tunnel collision mask %d." % [resident.name, expected_mask])


func _assert_tunnel_trigger_ownership(terrain: Node2D, bi_shan_tunnel: Tunnel, long_shan_tunnel: Tunnel) -> void:
	var bi_shan_echo_a := terrain.get_node_or_null("bi_shan_tunnel/interior_triggers/EchoA") as StorySubjectArea2D
	var bi_shan_chamber := terrain.get_node_or_null("bi_shan_tunnel/interior_triggers/Chamber") as StorySubjectArea2D
	var long_shan_entry := terrain.get_node_or_null("long_shan_tunnel/surface_triggers/TunnelEntry") as StorySubjectArea2D
	var long_shan_exit := terrain.get_node_or_null("long_shan_tunnel/surface_triggers/TunnelExit") as StorySubjectArea2D
	var long_shan_pocket_south := terrain.get_node_or_null("long_shan_tunnel/interior_triggers/LightPocketSouth") as StorySubjectArea2D
	var long_shan_pocket_north := terrain.get_node_or_null("long_shan_tunnel/interior_triggers/LightPocketNorth") as StorySubjectArea2D
	_assert(bi_shan_echo_a != null, "Bi Shan echo triggers should live under the Bi Shan terrain instance.")
	_assert(bi_shan_chamber != null, "Bi Shan chamber trigger should live under the Bi Shan terrain instance.")
	_assert(long_shan_entry != null, "Long Shan entry trigger should live under the Long Shan terrain instance.")
	_assert(long_shan_exit != null, "Long Shan exit trigger should live under the Long Shan terrain instance.")
	_assert(long_shan_pocket_south != null, "Long Shan south light pocket should live under the Long Shan terrain instance.")
	_assert(long_shan_pocket_north != null, "Long Shan north light pocket should live under the Long Shan terrain instance.")
	_assert(
		bi_shan_echo_a != null and bi_shan_echo_a.get_parent().get_parent() == bi_shan_tunnel,
		"Bi Shan tunnel triggers should hang directly off the Bi Shan landmark instance in terrain."
	)
	_assert(
		long_shan_pocket_south != null and long_shan_pocket_south.get_parent().get_parent() == long_shan_tunnel,
		"Long Shan tunnel triggers should hang directly off the Long Shan landmark instance in terrain."
	)
	_assert(
		CommonUtils.get_absolute_z_index(long_shan_entry) == 0,
		"Long Shan entry trigger should stay on the outside surface layer."
	)
	_assert(
		CommonUtils.get_absolute_z_index(long_shan_exit) == 0,
		"Long Shan exit trigger should stay on the outside surface layer."
	)
	_assert(
		long_shan_entry.get_resolved_level_id() == 0,
		"Long Shan entry trigger should keep its outside resolved level."
	)
	_assert(
		long_shan_exit.get_resolved_level_id() == 0,
		"Long Shan exit trigger should keep its outside resolved level."
	)
	_assert(
		bi_shan_echo_a.get_resolved_level_id() == bi_shan_tunnel.get_resolved_level_id(),
		"Bi Shan interior triggers should resolve their level from the tunnel context."
	)
	_assert(
		long_shan_pocket_south.get_resolved_level_id() == long_shan_tunnel.get_resolved_level_id(),
		"Long Shan light-pocket triggers should resolve their level from the tunnel context."
	)
	_assert(
		CommonUtils.get_absolute_z_index(bi_shan_echo_a) == bi_shan_tunnel.get_resolved_level_id(),
		"Bi Shan interior triggers should stay on the tunnel interior layer."
	)
	_assert(
		CommonUtils.get_absolute_z_index(long_shan_pocket_south) == long_shan_tunnel.get_resolved_level_id(),
		"Long Shan light-pocket triggers should stay on the tunnel interior layer."
	)


func _assert_tunnel_presentation(tunnel: Tunnel, expected_inside: bool, message: String) -> void:
	_assert(tunnel != null, "Tunnel presentation check requires a valid tunnel.")
	var exterior := tunnel.get_node_or_null("exterior") as IsometricBlock
	var interior := tunnel.get_node_or_null("interior") as IsometricBlock
	_assert(exterior != null, "%s should expose an exterior IsometricBlock node." % tunnel.name)
	_assert(interior != null, "%s should expose an interior IsometricBlock node." % tunnel.name)
	_assert(
		exterior.visible == !expected_inside,
		"%s %s Expected exterior visible=%s, got %s." % [tunnel.name, message, str(!expected_inside), str(exterior.visible)]
	)
	_assert(
		interior.visible == expected_inside,
		"%s %s Expected interior visible=%s, got %s." % [tunnel.name, message, str(expected_inside), str(interior.visible)]
	)
	_assert(
		tunnel.is_player_inside() == expected_inside,
		"%s %s Expected tunnel context inside=%s, got %s." % [tunnel.name, message, str(expected_inside), str(tunnel.is_player_inside())]
	)


func _assert_visibility_matches_player_context(
	player: HumanBody2D,
	residents_root: Node2D,
	tunnels: Array[Tunnel],
	non_tunnel_snapshots: Dictionary,
	message: String
) -> void:
	var player_tunnel := _find_tunnel_for_actor(player, tunnels)
	for child in residents_root.get_children():
		var resident := child as HumanBody2D
		if resident == null:
			continue
		var resident_id := String(resident.get("resident_id"))
		var resident_tunnel := _find_tunnel_for_actor(resident, tunnels)
		if TUNNEL_MANAGED_RESIDENT_IDS.has(resident_id):
			var should_be_visible := resident_tunnel == player_tunnel
			_assert(
				resident.visible == should_be_visible,
				"%s %s Expected visible=%s, got %s." % [resident.name, message, str(should_be_visible), str(resident.visible)]
			)
			continue

		var snapshot: Dictionary = non_tunnel_snapshots.get(resident_id, {})
		_assert(!snapshot.is_empty(), "%s should have a baseline non-tunnel snapshot." % resident.name)
		_assert(
			resident.visible == bool(snapshot.get("visible", resident.visible)),
			"%s %s Non-tunnel visibility should remain unchanged." % [resident.name, message]
		)
		_assert(
			CommonUtils.get_absolute_z_index(resident) == int(snapshot.get("z_index", resident.z_index)),
			"%s %s Non-tunnel z level should remain unchanged." % [resident.name, message]
		)
		_assert(
			resident.collision_mask == int(snapshot.get("collision_mask", resident.collision_mask)),
			"%s %s Non-tunnel collision mask should remain unchanged." % [resident.name, message]
		)


func _find_tunnel_for_actor(actor: HumanBody2D, tunnels: Array[Tunnel]) -> Tunnel:
	if actor == null:
		return null

	for tunnel in tunnels:
		if tunnel != null and tunnel.contains_actor_interior(actor):
			return tunnel
	return null


func _capture_non_tunnel_resident_state(residents_root: Node2D) -> Dictionary:
	var snapshots: Dictionary = {}
	for child in residents_root.get_children():
		var resident := child as HumanBody2D
		if resident == null:
			continue
		var resident_id := String(resident.get("resident_id"))
		if TUNNEL_MANAGED_RESIDENT_IDS.has(resident_id):
			continue
		snapshots[resident_id] = {
			"visible": resident.visible,
			"z_index": CommonUtils.get_absolute_z_index(resident),
			"collision_mask": resident.collision_mask,
		}
	return snapshots


func _assert_group_visible(residents_root: Node2D, resident_ids: Array, message: String) -> void:
	for resident_id in resident_ids:
		var resident := _resident_node(residents_root, resident_id)
		_assert(resident.visible, "%s %s" % [resident.name, message])


func _assert_group_hidden(residents_root: Node2D, resident_ids: Array, message: String) -> void:
	for resident_id in resident_ids:
		var resident := _resident_node(residents_root, resident_id)
		_assert(!resident.visible, "%s %s" % [resident.name, message])


func _move_player_into_tunnel(player: HumanBody2D, tunnel: Tunnel, resident: HumanBody2D, initial_player_z: int, initial_player_collision_mask: int) -> void:
	if player == null or tunnel == null or resident == null:
		return

	player.z_index = initial_player_z
	player.collision_mask = initial_player_collision_mask
	player.global_position = resident.global_position
	LevelRegistry.apply_level_to_actor(tunnel.get_resolved_level_id(), player)


func _move_player_over_tunnel_surface(player: HumanBody2D, resident: HumanBody2D, initial_player_z: int, initial_player_collision_mask: int) -> void:
	if player == null or resident == null:
		return

	player.global_position = resident.global_position
	player.z_index = initial_player_z
	player.collision_mask = initial_player_collision_mask


func _move_player_outside(player: HumanBody2D, initial_player_z: int, initial_player_collision_mask: int) -> void:
	if player == null:
		return

	player.global_position = OUTSIDE_PLAYER_POSITION
	player.z_index = initial_player_z
	player.collision_mask = initial_player_collision_mask


func _resident_node(residents_root: Node2D, resident_id: String) -> HumanBody2D:
	var display_name = _app_state().get_resident_display_name(resident_id)
	var resident := residents_root.get_node_or_null(display_name) as HumanBody2D
	_assert(resident != null, "Resident '%s' did not spawn." % resident_id)
	return resident


func _assert(condition: bool, message: String) -> void:
	if condition:
		return

	push_error(message)
	get_tree().quit(1)
