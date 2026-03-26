@tool
extends Node

const GAME_MAIN_SCENE := preload("res://scenes/game_main.tscn")
const ROUTED_RESIDENT_ID := "tunnel_guide"
const INSIDE_REFERENCE_RESIDENT_ID := "storyteller_wen"
const WAIT_TIMEOUT_SEC := 12.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	call_deferred("_run")


func _run() -> void:
	AppState.configure_new_game()
	var game_main := GAME_MAIN_SCENE.instantiate()
	add_child(game_main)

	await _settle()

	var player := game_main.get_node("actors/player") as HumanBody2D
	var residents_root := game_main.get_node("actors/Residents") as Node2D
	var long_shan_tunnel := game_main.get_node("terrain/long_shan_tunnel") as Tunnel
	var routed_resident := _resident_node(residents_root, ROUTED_RESIDENT_ID)
	var inside_reference := _resident_node(residents_root, INSIDE_REFERENCE_RESIDENT_ID)
	var outside_level_id := 0
	var outside_collision_mask := LevelRegistry.resolve_level_collision_mask(outside_level_id)
	var initial_player_z := player.z_index
	var initial_player_collision_mask := player.collision_mask

	_assert(player != null, "Player did not load.")
	_assert(residents_root != null, "Resident root did not load.")
	_assert(long_shan_tunnel != null, "Long Shan Tunnel did not load.")
	_assert(routed_resident != null, "Routed resident did not load.")
	_assert(inside_reference != null, "Inside reference resident did not load.")
	_assert(long_shan_tunnel.contains_actor(routed_resident), "%s should start inside Long Shan Tunnel." % routed_resident.name)
	_assert(!routed_resident.visible, "%s should start hidden while the player is outside." % routed_resident.name)

	await _wait_for_tunnel_state(routed_resident, long_shan_tunnel, false, WAIT_TIMEOUT_SEC)
	_assert(routed_resident.visible, "%s should be visible once they walk outside while the player is outside." % routed_resident.name)
	_assert(CommonUtils.get_absolute_z_index(routed_resident) == outside_level_id, "%s should resolve back to outside z %d." % [routed_resident.name, outside_level_id])
	_assert(routed_resident.collision_mask == outside_collision_mask, "%s should resolve back to outside collision mask %d." % [routed_resident.name, outside_collision_mask])

	_move_player_into_tunnel(player, long_shan_tunnel, inside_reference, initial_player_z, initial_player_collision_mask)
	await _settle()
	_assert(!routed_resident.visible, "%s should hide while outside if the player is inside Long Shan Tunnel." % routed_resident.name)

	await _wait_for_tunnel_state(routed_resident, long_shan_tunnel, true, WAIT_TIMEOUT_SEC)
	_assert(routed_resident.visible, "%s should reappear after re-entering Long Shan Tunnel." % routed_resident.name)
	_assert(
		CommonUtils.get_absolute_z_index(routed_resident) == long_shan_tunnel.get_resolved_level_id(),
		"%s should resolve to tunnel z %d after re-entering." % [routed_resident.name, long_shan_tunnel.get_resolved_level_id()]
	)
	_assert(
		routed_resident.collision_mask == LevelRegistry.resolve_level_collision_mask(long_shan_tunnel.get_resolved_level_id()),
		"%s should resolve to the tunnel collision mask after re-entering." % routed_resident.name
	)

	print("Tunnel NPC travel regression passed.")
	get_tree().quit(0)


func _wait_for_tunnel_state(resident: HumanBody2D, tunnel: Tunnel, expected_inside: bool, timeout_sec: float) -> void:
	var elapsed := 0.0
	while elapsed < timeout_sec:
		if tunnel.contains_actor(resident) == expected_inside:
			await _settle()
			return
		await get_tree().physics_frame
		await get_tree().process_frame
		elapsed += get_process_delta_time()

	_assert(false, "%s did not reach expected tunnel state=%s within %.1f seconds." % [resident.name, str(expected_inside), timeout_sec])


func _move_player_into_tunnel(player: HumanBody2D, tunnel: Tunnel, resident: HumanBody2D, initial_player_z: int, initial_player_collision_mask: int) -> void:
	if player == null or tunnel == null or resident == null:
		return

	player.z_index = initial_player_z
	player.collision_mask = initial_player_collision_mask
	player.global_position = resident.global_position
	LevelRegistry.apply_level_to_actor(tunnel.get_resolved_level_id(), player)


func _resident_node(residents_root: Node2D, resident_id: String) -> HumanBody2D:
	var display_name := AppState.get_resident_display_name(resident_id)
	var resident := residents_root.get_node_or_null(display_name) as HumanBody2D
	_assert(resident != null, "Resident '%s' did not spawn." % resident_id)
	return resident


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
