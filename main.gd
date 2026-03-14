@tool
extends Node2D

const DEFAULT_HINT := "R Inspect   J Journal   Esc Pause"
const LANDMARK_SYNC_DISTANCE := 1600.0

@onready var m_player :HumanBody2D = $player
@onready var m_terrain: Terrain = $terrain
@onready var m_bagua_tower: Node2D = $terrain/ground/buildings/BaguaTower
@onready var m_trinity_church: Node2D = $terrain/ground/buildings/TrinityChurch
@onready var m_piano_ferry: Node2D = $terrain/ground/buildings/piano_ferry
@onready var m_long_shan_tunnel: Node2D = $terrain/long_shan_tunnel
@onready var m_bi_shan_tunnel: Node2D = $terrain/bi_shan_tunnel

var m_is_ready := false
var m_player_controller: PlayerController = null
var m_closest_object: Node2D = null
var m_landmark_nodes: Dictionary = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	m_is_ready = true
	if is_instance_valid(m_terrain):
		m_terrain.player = m_player
	GameGlobal.get_instance().set_player(m_player)
	_cache_landmarks()
	_connect_ui_signals()
	sync_ui_state()


func sync_ui_state() -> void:
	if !m_is_ready:
		return

	AppState.set_landmarks(PackedStringArray(m_landmark_nodes.keys()))
	AppState.set_residents(PackedStringArray([
		"Caretaker",
		"Ferry Worker",
		"Tunnel Guide",
		"Tower Keeper",
	]))
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


func _connect_ui_signals() -> void:
	if !is_instance_valid(m_player):
		return

	if !m_player.global_position_changed.is_connected(_sync_location_from_player):
		m_player.global_position_changed.connect(_sync_location_from_player)

	m_player_controller = m_player.controller as PlayerController
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

	var display_name := _display_name_for_node(m_closest_object)
	AppState.set_save_status("Inspect: %s" % display_name)


func _update_hint_text(target: Node2D) -> void:
	if !is_instance_valid(target):
		AppState.set_hint(DEFAULT_HINT)
		return

	var display_name := _display_name_for_node(target)
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
