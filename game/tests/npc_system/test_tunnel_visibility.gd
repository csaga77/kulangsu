@tool
extends Node

const GAME_MAIN_SCENE := preload("res://scenes/game_main.tscn")
const APP_RUNTIME := preload("res://game/app_runtime.gd")
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
	var ground := game_main.get_node("terrain/ground") as AutoVisibilityNode2D
	var bi_shan_tunnel := game_main.get_node("terrain/bi_shan_tunnel") as Tunnel
	var long_shan_tunnel := game_main.get_node("terrain/long_shan_tunnel") as Tunnel
	var initial_player_z := player.z_index
	var initial_player_collision_mask := player.collision_mask
	var tunnels: Array[Tunnel] = [bi_shan_tunnel, long_shan_tunnel]

	_assert(player != null, "Player did not load.")
	_assert(residents_root != null, "Resident root did not load.")
	_assert(ground != null, "Ground visibility node did not load.")
	_assert(bi_shan_tunnel != null, "Bi Shan Tunnel did not load.")
	_assert(long_shan_tunnel != null, "Long Shan Tunnel did not load.")

	ground.smooth_visibility_change = false
	ground._update_visibility()

	_assert_group_in_tunnel(residents_root, bi_shan_tunnel, BI_SHAN_RESIDENT_IDS)
	_assert_group_in_tunnel(residents_root, long_shan_tunnel, LONG_SHAN_RESIDENT_IDS)
	_assert_group_on_tunnel_level(residents_root, bi_shan_tunnel, BI_SHAN_RESIDENT_IDS)
	_assert_group_on_tunnel_level(residents_root, long_shan_tunnel, LONG_SHAN_RESIDENT_IDS)
	_assert_group_spacing(residents_root, BI_SHAN_RESIDENT_IDS, MIN_TUNNEL_SPACING)
	_assert_group_spacing(residents_root, LONG_SHAN_RESIDENT_IDS, MIN_TUNNEL_SPACING)
	_assert_visibility_matches_player_context(player, residents_root, tunnels, "Initial outside state should match tunnel context.")
	_assert(ground.visible, "Ground should stay visible while the player is outside.")

	_move_player_over_tunnel_surface(player, _resident_node(residents_root, BI_SHAN_RESIDENT_IDS[0]), initial_player_z, initial_player_collision_mask)
	await get_tree().process_frame
	await get_tree().process_frame
	_assert(bi_shan_tunnel.contains_actor(player), "Surface overlap case should still place the player over the Bi Shan tunnel footprint.")
	_assert(!bi_shan_tunnel.contains_actor_interior(player), "Surface overlap case should not count as being inside Bi Shan Tunnel.")
	_assert_visibility_matches_player_context(player, residents_root, tunnels, "Surface overlap should still use outside tunnel visibility.")
	_assert(ground.visible, "Ground should stay visible while the player only overlaps the tunnel footprint on the surface.")

	_move_player_into_tunnel(player, bi_shan_tunnel, _resident_node(residents_root, BI_SHAN_RESIDENT_IDS[0]), initial_player_z, initial_player_collision_mask)
	await get_tree().process_frame
	await get_tree().process_frame
	_assert_visibility_matches_player_context(player, residents_root, tunnels, "Bi Shan tunnel state should match tunnel context.")
	_assert(ground.visible == false, "Ground should hide while the player is inside Bi Shan Tunnel.")

	_move_player_outside(player, initial_player_z, initial_player_collision_mask)
	await get_tree().process_frame
	await get_tree().process_frame
	_assert_visibility_matches_player_context(player, residents_root, tunnels, "Returning outside should restore outside context visibility.")
	_assert(ground.visible, "Ground should reappear after leaving the tunnel.")

	_move_player_into_tunnel(player, long_shan_tunnel, _resident_node(residents_root, LONG_SHAN_RESIDENT_IDS[0]), initial_player_z, initial_player_collision_mask)
	await get_tree().process_frame
	await get_tree().process_frame
	_assert_visibility_matches_player_context(player, residents_root, tunnels, "Long Shan tunnel state should match tunnel context.")
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


func _assert_visibility_matches_player_context(player: HumanBody2D, residents_root: Node2D, tunnels: Array[Tunnel], message: String) -> void:
	var player_tunnel := _find_tunnel_for_actor(player, tunnels)
	for child in residents_root.get_children():
		var resident := child as HumanBody2D
		if resident == null:
			continue
		var resident_tunnel := _find_tunnel_for_actor(resident, tunnels)
		var should_be_visible := resident_tunnel == player_tunnel
		_assert(
			resident.visible == should_be_visible,
			"%s %s Expected visible=%s, got %s." % [resident.name, message, str(should_be_visible), str(resident.visible)]
		)


func _find_tunnel_for_actor(actor: HumanBody2D, tunnels: Array[Tunnel]) -> Tunnel:
	if actor == null:
		return null

	for tunnel in tunnels:
		if tunnel != null and tunnel.contains_actor_interior(actor):
			return tunnel
	return null


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
