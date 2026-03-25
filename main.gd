# @tool is required so that @onready node references resolve correctly when the
# scene is open in the Godot editor (e.g. for terrain authoring and landmark
# inspection). All runtime-only code paths (resident spawning, signal wiring,
# location syncing) are guarded by Engine.is_editor_hint() checks or by the
# m_is_ready flag so they do not execute during edit-time.
@tool
extends Node2D

const DEFAULT_HINT := "R Inspect   J Journal   Esc Pause"
const LANDMARK_SYNC_DISTANCE := 1600.0
const NPC_SCENE: PackedScene = preload("res://characters/human_body_2d.tscn")

@onready var m_actor_root: Node2D = $actors
@onready var m_player :HumanBody2D = $actors/player
@onready var m_terrain: Terrain = $terrain
@onready var m_bagua_tower: Node2D = $terrain/ground/buildings/BaguaTower
@onready var m_trinity_church: Node2D = $terrain/ground/buildings/TrinityChurch
@onready var m_piano_ferry: Node2D = $terrain/ground/buildings/piano_ferry
@onready var m_long_shan_tunnel: Node2D = $terrain/long_shan_tunnel
@onready var m_bi_shan_tunnel: Node2D = $terrain/bi_shan_tunnel
@onready var m_bi_shan_tunnel_entry_south: Node2D = $terrain/ground/bi_shan_tunnel_entries/entry_south
@onready var m_long_shan_tunnel_entry_south: Node2D = $terrain/ground/long_shan_tunnel_entries/entry_south

var m_is_ready := false
var m_player_controller: PlayerController = null
var m_closest_object: Node2D = null
var m_landmark_nodes: Dictionary = {}
var m_spawn_anchor_nodes: Dictionary = {}
var m_resident_root: Node2D = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	m_is_ready = true
	if is_instance_valid(m_terrain):
		m_terrain.player = m_player
	GameGlobal.get_instance().set_player(m_player)
	_cache_landmarks()
	_cache_spawn_anchors()
	_spawn_catalog_residents()
	_connect_ui_signals()
	sync_ui_state()


func sync_ui_state() -> void:
	if !m_is_ready:
		return

	AppState.set_landmarks(PackedStringArray(m_landmark_nodes.keys()))
	AppState.set_residents(AppState.get_known_resident_names())
	_sync_location_from_player()
	_update_hint_text(m_closest_object)


func _cache_landmarks() -> void:
	m_landmark_nodes = {
		"Piano Ferry": m_piano_ferry,
		"Trinity Church": m_trinity_church,
		"Bagua Tower": m_bagua_tower,
		"Long Shan Tunnel": m_long_shan_tunnel,
		"Bi Shan Tunnel": m_bi_shan_tunnel,
	}


func _cache_spawn_anchors() -> void:
	m_spawn_anchor_nodes = {
		"Piano Ferry": m_piano_ferry,
		"Trinity Church": m_trinity_church,
		"Bagua Tower": m_bagua_tower,
		"Bi Shan Tunnel South": m_bi_shan_tunnel_entry_south,
		"Long Shan Tunnel South": m_long_shan_tunnel_entry_south,
	}


func _connect_ui_signals() -> void:
	if !is_instance_valid(m_player):
		return

	if !AppState.player_appearance_changed.is_connected(_on_player_appearance_changed):
		AppState.player_appearance_changed.connect(_on_player_appearance_changed)

	if !m_player.global_position_changed.is_connected(_sync_location_from_player):
		m_player.global_position_changed.connect(_sync_location_from_player)

	m_player_controller = m_player.controller as PlayerController
	_apply_player_costume()
	if m_player_controller == null:
		return

	if !m_player_controller.closest_object_changed.is_connected(_on_closest_object_changed):
		m_player_controller.closest_object_changed.connect(_on_closest_object_changed)
	if !m_player_controller.inspect_requested.is_connected(_on_inspect_requested):
		m_player_controller.inspect_requested.connect(_on_inspect_requested)


func _sync_location_from_player() -> void:
	if !is_instance_valid(m_player):
		return

	if _is_landmark(m_closest_object):
		AppState.set_location(_display_name_for_node(m_closest_object))
		return

	var best_name := "Island Paths"
	var best_distance_sq := INF

	for landmark_name in m_landmark_nodes.keys():
		var landmark_node: Node2D = m_landmark_nodes[landmark_name]
		if !is_instance_valid(landmark_node):
			continue

		var distance_sq := m_player.global_position.distance_squared_to(landmark_node.global_position)
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			best_name = landmark_name

	if best_distance_sq <= LANDMARK_SYNC_DISTANCE * LANDMARK_SYNC_DISTANCE:
		AppState.set_location(best_name)
	else:
		AppState.set_location("Island Paths")


func _on_closest_object_changed(new_object: Node2D) -> void:
	m_closest_object = new_object

	if _is_landmark(new_object):
		AppState.set_location(_display_name_for_node(new_object))

	_update_hint_text(new_object)


func _on_inspect_requested() -> void:
	if !is_instance_valid(m_closest_object):
		AppState.set_save_status("Inspect: nothing nearby")
		return

	var resident_controller := _get_resident_controller(m_closest_object)
	if resident_controller != null:
		var resident_id := resident_controller.get_resident_id()
		var interaction := AppState.interact_with_resident(resident_id)
		var resident_name := AppState.get_resident_display_name(resident_id)
		var dialogue_line := String(interaction.get("line", ""))

		if interaction.is_empty():
			AppState.set_save_status("Talked with %s" % resident_name)

		resident_controller.reveal_dialogue(dialogue_line)
		# Note: set_residents is not called here because interact_with_resident
		# already calls _sync_known_residents() internally.
		_update_hint_text(m_closest_object)
		return

	var landmark_trigger := _get_landmark_trigger(m_closest_object)
	if landmark_trigger != null:
		AppState.activate_landmark_trigger(
			landmark_trigger.landmark_id,
			landmark_trigger.trigger_id,
			landmark_trigger.display_name
		)
		landmark_trigger.collect()
		_update_hint_text(m_closest_object)
		return

	var display_name := _display_name_for_node(m_closest_object)
	AppState.set_save_status("Inspect: %s" % display_name)


func _update_hint_text(target: Node2D) -> void:
	if !is_instance_valid(target):
		AppState.set_hint(DEFAULT_HINT)
		return

	var landmark_trigger := _get_landmark_trigger(target)
	if landmark_trigger != null:
		if landmark_trigger.is_collected():
			AppState.set_hint(DEFAULT_HINT)
		else:
			AppState.set_hint("R Collect %s   J Journal   Esc Pause" % landmark_trigger.display_name)
		return

	var display_name := _display_name_for_node(target)
	if _get_resident_controller(target) != null:
		AppState.set_hint("R Talk to %s   J Journal   Esc Pause" % display_name)
		return
	AppState.set_hint("R Inspect %s   J Journal   Esc Pause" % display_name)


func _is_landmark(target: Node2D) -> bool:
	if !is_instance_valid(target):
		return false

	for landmark_node in m_landmark_nodes.values():
		if target == landmark_node:
			return true

	return false


func _display_name_for_node(target: Node2D) -> String:
	if !is_instance_valid(target):
		return ""

	var resident_controller := _get_resident_controller(target)
	if resident_controller != null:
		return AppState.get_resident_display_name(resident_controller.get_resident_id())

	for landmark_name in m_landmark_nodes.keys():
		if target == m_landmark_nodes[landmark_name]:
			return landmark_name

	var raw_name := String(target.name).replace("_", " ").strip_edges()
	if raw_name.is_empty():
		return "nearby object"

	var output := ""
	for i in range(raw_name.length()):
		var current_char := raw_name.substr(i, 1)
		var previous_char := raw_name.substr(i - 1, 1) if i > 0 else ""
		if i > 0 and current_char == current_char.to_upper() and previous_char != " " and previous_char != previous_char.to_upper():
			output += " "
		output += current_char

	return output


func _spawn_catalog_residents() -> void:
	if Engine.is_editor_hint():
		return
	if m_resident_root != null and is_instance_valid(m_resident_root):
		return

	m_resident_root = Node2D.new()
	m_resident_root.name = "Residents"
	m_resident_root.y_sort_enabled = true
	m_actor_root.add_child(m_resident_root)

	for resident_id in AppState.get_resident_ids():
		var spawn_config := AppState.get_resident_spawn_config(resident_id)
		var anchor_id := String(spawn_config.get("anchor_id", ""))
		var anchor_node := m_spawn_anchor_nodes.get(anchor_id) as Node2D
		if !is_instance_valid(anchor_node):
			push_warning("Missing NPC spawn anchor '%s' for resident '%s'." % [anchor_id, resident_id])
			continue

		var npc := NPC_SCENE.instantiate() as HumanBody2D
		if npc == null:
			continue

		var controller := NPCController.new()
		controller.use_json_bt = false
		controller.resident_id = StringName(resident_id)
		controller.interaction_radius = float(spawn_config.get("interaction_radius", 72.0))

		npc.name = AppState.get_resident_display_name(resident_id)
		npc.controller = controller
		npc.direction = float(spawn_config.get("direction", 0.0))
		npc.facial_mood = int(spawn_config.get("mood", HumanBody2D.FacialMoodEnum.NORMAL)) as HumanBody2D.FacialMoodEnum

		m_resident_root.add_child(npc)
		var spawn_offset: Vector2 = spawn_config.get("offset", Vector2.ZERO)
		npc.global_position = anchor_node.global_position + spawn_offset


func _on_player_appearance_changed(_profile: Dictionary, _appearance_config: Dictionary) -> void:
	_apply_player_costume()


func _apply_player_costume() -> void:
	if !is_instance_valid(m_player):
		return

	var appearance_config := AppState.get_player_appearance_config()
	if appearance_config.is_empty():
		return

	m_player.set_configuration(appearance_config)


func _get_resident_controller(target: Node2D) -> NPCController:
	var human := target as HumanBody2D
	if human == null:
		return null
	return human.controller as NPCController


func _get_landmark_trigger(target: Node2D) -> LandmarkTrigger:
	return target as LandmarkTrigger
