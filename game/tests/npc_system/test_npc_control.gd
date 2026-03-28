@tool
extends Node

const GAME_MAIN_SCENE := preload("res://scenes/game_main.tscn")
const ROUTED_RESIDENT_ID := "tunnel_guide"
const WAIT_TIMEOUT_SEC := 18.0
const OUTSIDE_PLAYER_POSITION := Vector2(-263.0, 8541.0)


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
	var controller := routed_resident.controller as NPCController

	_assert(player != null, "Player did not load.")
	_assert(residents_root != null, "Resident root did not load.")
	_assert(long_shan_tunnel != null, "Long Shan Tunnel did not load.")
	_assert(routed_resident != null, "Routed resident did not load.")
	_assert(controller != null, "Routed resident controller did not load.")
	_assert(long_shan_tunnel.contains_actor_interior(routed_resident), "%s should start inside Long Shan Tunnel interior." % routed_resident.name)

	await _assert_animation_advances_while_moving(routed_resident, WAIT_TIMEOUT_SEC)

	LevelRegistry.apply_level_to_actor(long_shan_tunnel.get_resolved_level_id(), player)
	player.global_position = routed_resident.global_position + Vector2(24.0, 0.0)
	await _wait_for_player_target(controller, player, WAIT_TIMEOUT_SEC)
	_assert(routed_resident.visible, "%s should be visible when the player shares the same tunnel interior." % routed_resident.name)
	_assert(!controller.is_moving(), "%s should pause its route while the player is nearby." % routed_resident.name)
	_assert(!routed_resident.is_walking, "%s should stop walking while paused for talk." % routed_resident.name)
	_assert(String(controller._get_speech(player)) == "...", "%s should show an unrevealed nearby cue before talk." % routed_resident.name)

	var interaction := AppState.interact_with_resident(ROUTED_RESIDENT_ID)
	var line := String(interaction.get("line", ""))
	_assert(!line.is_empty(), "%s should return a dialogue line on talk." % routed_resident.name)
	controller.reveal_dialogue(line)
	await _settle()

	var expected_speech := "%s: %s" % [AppState.get_resident_display_name(ROUTED_RESIDENT_ID), line]
	_assert(String(controller._get_speech(player)) == expected_speech, "%s should reveal its current dialogue line after talk." % routed_resident.name)

	LevelRegistry.apply_level_to_actor(0, player)
	player.global_position = OUTSIDE_PLAYER_POSITION
	await _wait_for_player_target(controller, null, WAIT_TIMEOUT_SEC)
	_assert(controller.m_revealed_dialogue_line.is_empty(), "%s should clear the revealed line after the player leaves range." % routed_resident.name)
	await _assert_animation_advances_while_moving(routed_resident, WAIT_TIMEOUT_SEC)

	print("NPC control regression passed.")
	get_tree().quit(0)


func _assert_animation_advances_while_moving(resident: HumanBody2D, timeout_sec: float) -> void:
	var sprite := _resident_sprite(resident)
	_assert(sprite != null, "%s should expose an AnimatedSprite2D for animation checks." % resident.name)

	var elapsed := 0.0
	var previous_position := resident.global_position
	var previous_frame := sprite.frame
	var previous_progress := sprite.frame_progress
	var previous_animation := String(sprite.animation)
	var saw_movement := false

	while elapsed < timeout_sec:
		await get_tree().physics_frame
		await get_tree().process_frame

		var moved := resident.global_position.distance_to(previous_position) > 0.5
		if moved:
			saw_movement = true
			var frame_changed := sprite.frame != previous_frame
			var progress_changed := !is_equal_approx(sprite.frame_progress, previous_progress)
			var animation_changed := String(sprite.animation) != previous_animation
			if frame_changed or progress_changed or animation_changed:
				return

		previous_position = resident.global_position
		previous_frame = sprite.frame
		previous_progress = sprite.frame_progress
		previous_animation = String(sprite.animation)
		elapsed += get_process_delta_time()

	if !saw_movement:
		_assert(false, "%s did not start moving within %.1f seconds." % [resident.name, timeout_sec])
		return

	_assert(false, "%s moved, but the walk animation never advanced within %.1f seconds." % [resident.name, timeout_sec])


func _wait_for_player_target(controller: NPCController, expected_target: Node2D, timeout_sec: float) -> void:
	var elapsed := 0.0
	while elapsed < timeout_sec:
		if controller.m_target == expected_target:
			await _settle()
			return
		await get_tree().physics_frame
		await get_tree().process_frame
		elapsed += get_process_delta_time()

	var expected_name: String = "null" if expected_target == null else String(expected_target.name)
	_assert(false, "Controller did not reach expected target %s within %.1f seconds." % [expected_name, timeout_sec])


func _resident_node(residents_root: Node2D, resident_id: String) -> HumanBody2D:
	var display_name := AppState.get_resident_display_name(resident_id)
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
