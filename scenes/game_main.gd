# @tool is required so that @onready node references resolve correctly when the
# scene is open in the Godot editor (e.g. for terrain authoring and landmark
# inspection). All runtime-only code paths (resident spawning, signal wiring,
# location syncing) are guarded by Engine.is_editor_hint() checks or by the
# m_is_ready flag so they do not execute during edit-time.
@tool
extends Node2D

const LANDMARK_SYNC_DISTANCE := 1600.0
const NPC_SCENE: PackedScene = preload("res://characters/human_body_2d.tscn")
const LEVEL_REGISTRY := preload("res://common/level_registry.gd")
const TUNNEL_ENTRY_FRONT_APPROACH_DISTANCE := 96.0
const TUNNEL_PORTAL_SUFFIX := " Portal"
const DIRECTIONAL_PORTAL_MIN_OFFSET_DISTANCE := 16.0
const STORY_SAFE_RESUME_ANCHOR_IDS := [
	"Piano Ferry",
	"Trinity Church",
	"Bagua Tower",
	"Bi Shan Tunnel South",
	"Bi Shan Tunnel North",
	"Long Shan Tunnel South",
	"Long Shan Tunnel North",
]

@onready var m_actor_root: Node2D = $actors
@onready var m_player :HumanBody2D = $actors/player
@onready var m_terrain: Terrain = $terrain
@onready var m_bagua_tower: Node2D = $terrain/ground/buildings/BaguaTower
@onready var m_trinity_church: Node2D = $terrain/ground/buildings/TrinityChurch
@onready var m_piano_ferry: Node2D = $terrain/ground/buildings/piano_ferry
@onready var m_long_shan_tunnel: Node2D = $terrain/long_shan_tunnel
@onready var m_bi_shan_tunnel: Node2D = $terrain/bi_shan_tunnel
@onready var m_bi_shan_tunnel_entry_south: Node2D = $terrain/ground/bi_shan_tunnel_entries/entry_south
@onready var m_bi_shan_tunnel_entry_north: Node2D = $terrain/ground/bi_shan_tunnel_entries/entry_north
@onready var m_long_shan_tunnel_entry_south: Node2D = $terrain/ground/long_shan_tunnel_entries/entry_south
@onready var m_long_shan_tunnel_entry_north: Node2D = $terrain/ground/long_shan_tunnel_entries/entry_north
@onready var m_bi_shan_tunnel_portal_south: Node2D = $terrain/bi_shan_tunnel/exit_south
@onready var m_bi_shan_tunnel_portal_north: Node2D = $terrain/bi_shan_tunnel/exit_north
@onready var m_long_shan_tunnel_portal_south: Node2D = $terrain/long_shan_tunnel/exit_south
@onready var m_long_shan_tunnel_portal_north: Node2D = $terrain/long_shan_tunnel/exit_north

@export var debug_draw_npc_routes: bool = false:
	set(value):
		if debug_draw_npc_routes == value:
			return
		debug_draw_npc_routes = value
		queue_redraw()

@export var debug_npc_route_filter: String = "":
	set(value):
		var normalized_value := value.strip_edges()
		if debug_npc_route_filter == normalized_value:
			return
		debug_npc_route_filter = normalized_value
		queue_redraw()

@export var debug_draw_npc_route_labels: bool = true:
	set(value):
		if debug_draw_npc_route_labels == value:
			return
		debug_draw_npc_route_labels = value
		queue_redraw()

var m_is_ready := false
var m_player_controller: PlayerController = null
var m_closest_object: Node2D = null
var m_landmark_nodes: Dictionary = {}
var m_spawn_anchor_nodes: Dictionary = {}
var m_tunnel_nodes: Array[Tunnel] = []
var m_resident_root: Node2D = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	m_is_ready = true
	if is_instance_valid(m_terrain):
		m_terrain.player = m_player
	GameGlobal.get_instance().set_player(m_player)
	_cache_landmarks()
	_cache_spawn_anchors()
	_apply_story_resume_anchor_if_needed()
	_cache_tunnels()
	_spawn_catalog_residents()
	_connect_ui_signals()
	sync_ui_state()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if !m_is_ready:
		return
	_sync_tunnel_resident_visibility()
	if debug_draw_npc_routes:
		queue_redraw()


func _draw() -> void:
	if !debug_draw_npc_routes:
		return
	if !is_instance_valid(m_resident_root):
		return

	var font: Font = ThemeDB.fallback_font
	var font_size: int = maxi(12, ThemeDB.fallback_font_size - 2)
	for child in m_resident_root.get_children():
		var resident := child as HumanBody2D
		if resident == null:
			continue

		var controller := resident.controller as NPCController
		if controller == null or controller.m_route_points.size() < 2:
			continue
		if !_npc_route_matches_debug_filter(resident, controller):
			continue

		_draw_npc_route_debug(resident, controller, font, font_size)


func _draw_npc_route_debug(
	resident: HumanBody2D,
	controller: NPCController,
	font: Font,
	font_size: int
) -> void:
	var route_points: Array[Dictionary] = controller.m_route_points
	if route_points.size() < 2:
		return

	var resident_id: String = controller.get_resident_id()
	var display_name: String = String(resident.name)
	if !resident_id.is_empty():
		display_name = AppState.get_resident_display_name(resident_id)

	var color_key: String = resident_id if !resident_id.is_empty() else display_name
	var base_color: Color = _npc_route_debug_color(color_key)
	var line_color := Color(base_color.r, base_color.g, base_color.b, 0.78)
	var fill_color := Color(base_color.r, base_color.g, base_color.b, 0.22)
	var bypass_color := Color(1.0, 0.72, 0.28, 0.95)

	for i in range(route_points.size() - 1):
		var from_position: Vector2 = route_points[i].get("position", Vector2.ZERO)
		var to_position: Vector2 = route_points[i + 1].get("position", Vector2.ZERO)
		draw_line(to_local(from_position), to_local(to_position), line_color, 3.0, true)

	if !controller.m_route_ping_pong and route_points.size() > 2:
		var loop_start: Vector2 = route_points[0].get("position", Vector2.ZERO)
		var loop_end: Vector2 = route_points[route_points.size() - 1].get("position", Vector2.ZERO)
		draw_line(
			to_local(loop_end),
			to_local(loop_start),
			Color(base_color.r, base_color.g, base_color.b, 0.35),
			2.0,
			true
		)

	for i in range(route_points.size()):
		var route_point := route_points[i]
		var point_position: Vector2 = route_point.get("position", Vector2.ZERO)
		var point_local := to_local(point_position)
		var is_active_point := i == controller.m_route_index
		var radius := 11.0 if is_active_point else 8.0
		draw_circle(point_local, radius, fill_color)
		draw_arc(point_local, radius, 0.0, TAU, 32, base_color, 2.0)

		if bool(route_point.get("allow_collision_bypass", false)):
			draw_arc(point_local, radius + 4.0, 0.0, TAU, 24, bypass_color, 1.5)

		if debug_draw_npc_route_labels and font != null:
			draw_string(
				font,
				point_local + Vector2(radius + 4.0, -6.0),
				str(i),
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				font_size,
				Color.WHITE
			)

	var resident_local := to_local(resident.global_position)
	draw_circle(resident_local, 6.0, Color(1.0, 1.0, 1.0, 0.92))
	draw_arc(resident_local, 10.0, 0.0, TAU, 32, base_color, 2.0)

	if controller.m_route_index >= 0 and controller.m_route_index < route_points.size():
		var active_position: Vector2 = route_points[controller.m_route_index].get("position", resident.global_position)
		draw_line(resident_local, to_local(active_position), Color(1.0, 1.0, 1.0, 0.78), 2.0, true)

	if debug_draw_npc_route_labels and font != null:
		var label := "%s [%d]" % [display_name, controller.m_route_index]
		draw_string(
			font,
			resident_local + Vector2(14.0, -12.0),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			Color.WHITE
		)


func _npc_route_matches_debug_filter(resident: HumanBody2D, controller: NPCController) -> bool:
	if debug_npc_route_filter.is_empty():
		return true

	var filter_text := debug_npc_route_filter.to_lower()
	var resident_id := controller.get_resident_id().to_lower()
	var display_name := resident.name.to_lower()
	return resident_id.contains(filter_text) or display_name.contains(filter_text)


func _npc_route_debug_color(color_key: String) -> Color:
	var hue_seed := absi(color_key.hash()) % 1024
	return Color.from_hsv(float(hue_seed) / 1024.0, 0.72, 1.0, 0.95)


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
		"Bi Shan Tunnel": m_bi_shan_tunnel,
		"Long Shan Tunnel": m_long_shan_tunnel,
		"Bi Shan Tunnel South": m_bi_shan_tunnel_entry_south,
		"Bi Shan Tunnel North": m_bi_shan_tunnel_entry_north,
		"Long Shan Tunnel South": m_long_shan_tunnel_entry_south,
		"Long Shan Tunnel North": m_long_shan_tunnel_entry_north,
		"Bi Shan Tunnel South Portal": m_bi_shan_tunnel_portal_south,
		"Bi Shan Tunnel North Portal": m_bi_shan_tunnel_portal_north,
		"Long Shan Tunnel South Portal": m_long_shan_tunnel_portal_south,
		"Long Shan Tunnel North Portal": m_long_shan_tunnel_portal_north,
	}


func _apply_story_resume_anchor_if_needed() -> void:
	if !is_instance_valid(m_player):
		return
	if AppState.mode not in ["Story", "Postgame"]:
		return

	var anchor_id := AppState.get_story_resume_anchor_id()
	if anchor_id.is_empty():
		anchor_id = "Piano Ferry"

	var anchor_node := m_spawn_anchor_nodes.get(anchor_id) as Node2D
	if !is_instance_valid(anchor_node):
		anchor_node = m_spawn_anchor_nodes.get("Piano Ferry") as Node2D
	if !is_instance_valid(anchor_node):
		return

	m_player.global_position = _resolve_actor_anchor_position(m_player, anchor_node, Vector2.ZERO)
	_apply_anchor_level_to_actor(m_player, anchor_node)


func _update_story_resume_checkpoint() -> void:
	if AppState.mode not in ["Story", "Postgame"]:
		return

	var anchor_id := _find_story_resume_anchor_id()
	if anchor_id.is_empty():
		return

	var location_label := AppState.location
	if location_label.is_empty() or location_label == "Island Paths":
		location_label = _resume_location_for_anchor(anchor_id)

	AppState.set_story_resume_checkpoint(anchor_id, location_label)


func _find_story_resume_anchor_id() -> String:
	var player_tunnel := _find_player_tunnel()
	if player_tunnel == m_bi_shan_tunnel:
		return _find_nearest_anchor_id(["Bi Shan Tunnel South", "Bi Shan Tunnel North"])
	if player_tunnel == m_long_shan_tunnel:
		return _find_nearest_anchor_id(["Long Shan Tunnel South", "Long Shan Tunnel North"])
	return _find_nearest_anchor_id(STORY_SAFE_RESUME_ANCHOR_IDS)


func _find_nearest_anchor_id(anchor_ids: Array) -> String:
	if !is_instance_valid(m_player):
		return ""

	var best_anchor_id := ""
	var best_distance_sq := INF
	for anchor_value in anchor_ids:
		var anchor_id := String(anchor_value)
		var anchor_node := m_spawn_anchor_nodes.get(anchor_id) as Node2D
		if !is_instance_valid(anchor_node):
			continue

		var distance_sq := m_player.global_position.distance_squared_to(anchor_node.global_position)
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			best_anchor_id = anchor_id

	return best_anchor_id


func _resume_location_for_anchor(anchor_id: String) -> String:
	if anchor_id.begins_with("Bi Shan Tunnel"):
		return "Bi Shan Tunnel"
	if anchor_id.begins_with("Long Shan Tunnel"):
		return "Long Shan Tunnel"
	if anchor_id == "Piano Ferry" and AppState.mode == "Postgame":
		return "Ferry Plaza"
	return anchor_id


func _cache_tunnels() -> void:
	m_tunnel_nodes.clear()

	for tunnel_node in [m_bi_shan_tunnel, m_long_shan_tunnel]:
		var tunnel := tunnel_node as Tunnel
		if tunnel != null:
			m_tunnel_nodes.append(tunnel)


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

	_sync_tunnel_resident_visibility()

	if _is_landmark(m_closest_object):
		AppState.set_location(_display_name_for_node(m_closest_object))
		_update_story_resume_checkpoint()
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

	_update_story_resume_checkpoint()


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
		var consumed := AppState.activate_landmark_trigger(
			landmark_trigger.landmark_id,
			landmark_trigger.trigger_id,
			landmark_trigger.display_name,
			landmark_trigger.melody_hint
		)
		if consumed:
			landmark_trigger.collect()
		_update_hint_text(m_closest_object)
		return

	var display_name := _display_name_for_node(m_closest_object)
	AppState.set_save_status("Inspect: %s" % display_name)


func _update_hint_text(target: Node2D) -> void:
	if !is_instance_valid(target):
		AppState.set_hint(AppState.build_input_hint("R Inspect"))
		return

	var landmark_trigger := _get_landmark_trigger(target)
	if landmark_trigger != null:
		if landmark_trigger.is_collected():
			AppState.set_hint(AppState.build_input_hint("R Inspect"))
		elif landmark_trigger.landmark_id == "festival_stage":
			AppState.set_hint(AppState.build_input_hint("R Perform %s" % landmark_trigger.display_name))
		else:
			AppState.set_hint(AppState.build_input_hint("R Collect %s" % landmark_trigger.display_name))
		return

	var display_name := _display_name_for_node(target)
	if _get_resident_controller(target) != null:
		AppState.set_hint(AppState.build_input_hint("R Talk to %s" % display_name))
		return
	AppState.set_hint(AppState.build_input_hint("R Inspect %s" % display_name))


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
		var resident_profile := AppState.get_resident_profile(resident_id)
		var spawn_config: Dictionary = resident_profile.get("spawn", {})
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
		npc.global_position = _resolve_actor_anchor_position(npc, anchor_node, spawn_offset)
		_apply_anchor_level_to_actor(npc, anchor_node)

		var movement_config := _build_resident_movement_config(resident_id, npc, resident_profile.get("movement", {}))
		if !movement_config.is_empty():
			controller.configure_movement(movement_config)

		if !npc.global_position_changed.is_connected(_sync_tunnel_resident_visibility):
			npc.global_position_changed.connect(_sync_tunnel_resident_visibility)

	_sync_tunnel_resident_visibility()


func _sync_tunnel_resident_visibility() -> void:
	if !is_instance_valid(m_resident_root):
		return

	var active_tunnel := _find_player_tunnel()
	for child in m_resident_root.get_children():
		var resident := child as HumanBody2D
		if resident == null:
			continue

		var resident_tunnel := _find_resident_tunnel(resident)
		if resident_tunnel != null:
			LEVEL_REGISTRY.apply_level_to_actor(resident_tunnel.get_resolved_level_id(), resident)
			resident.visible = resident_tunnel == active_tunnel
			continue

		LEVEL_REGISTRY.apply_level_to_actor(0, resident)
		resident.visible = active_tunnel == null


func _find_player_tunnel() -> Tunnel:
	return _find_tunnel_for_actor(m_player, true)


func _find_resident_tunnel(actor: HumanBody2D) -> Tunnel:
	return _find_tunnel_for_actor(actor, true)


func _find_tunnel_for_actor(actor: HumanBody2D, require_interior_level: bool) -> Tunnel:
	if !is_instance_valid(actor):
		return null

	for tunnel in m_tunnel_nodes:
		if !is_instance_valid(tunnel):
			continue
		if require_interior_level and tunnel.contains_actor_interior(actor):
			return tunnel
		if !require_interior_level and tunnel.contains_actor(actor):
			return tunnel

	return null


func _build_resident_movement_config(resident_id: String, actor: HumanBody2D, movement_config: Dictionary) -> Dictionary:
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
		var resolved_position := _resolve_route_anchor_position(actor, anchor_id, anchor_node, route_offset)
		var route_tunnel := _find_tunnel_ancestor(anchor_node)
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
			var transition_points := _build_tunnel_boundary_transition_points(
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


func _resolve_actor_anchor_position(actor: HumanBody2D, anchor_node: Node2D, offset: Vector2) -> Vector2:
	if !is_instance_valid(anchor_node):
		return offset

	var desired_position := anchor_node.global_position + offset
	var tunnel_anchor := _find_tunnel_ancestor(anchor_node)
	if tunnel_anchor == null:
		return desired_position

	return tunnel_anchor.snap_actor_to_walkable_position(actor, desired_position)


func _resolve_route_anchor_position(actor: HumanBody2D, anchor_id: String, anchor_node: Node2D, offset: Vector2) -> Vector2:
	if anchor_id.ends_with(TUNNEL_PORTAL_SUFFIX):
		return _resolve_directional_portal_route_position(actor, anchor_id, anchor_node, offset)
	return _resolve_actor_anchor_position(actor, anchor_node, offset)


func _resolve_directional_portal_route_position(
	actor: HumanBody2D,
	portal_anchor_id: String,
	portal_anchor_node: Node2D,
	offset: Vector2
) -> Vector2:
	var entry_anchor_id := _get_tunnel_entry_anchor_id_for_portal(portal_anchor_id)
	if entry_anchor_id.is_empty():
		return _resolve_actor_anchor_position(actor, portal_anchor_node, offset)

	var entry_anchor_node := m_spawn_anchor_nodes.get(entry_anchor_id) as Node2D
	if !is_instance_valid(entry_anchor_node):
		return _resolve_actor_anchor_position(actor, portal_anchor_node, offset)

	var portal_center := _resolve_portal_center_position(actor, portal_anchor_node)
	var portal_direction := _get_portal_direction_vector(portal_anchor_node)
	if portal_direction.length_squared() <= 0.001:
		return _resolve_actor_anchor_position(actor, portal_anchor_node, offset)
	var portal_lateral := _get_portal_lateral_vector(portal_anchor_node)

	var tunnel_side_sign := _get_portal_tunnel_side_sign(portal_anchor_node)
	var portal_distance := maxf(absf(offset.x), DIRECTIONAL_PORTAL_MIN_OFFSET_DISTANCE)
	var lateral_offset := offset.y

	return portal_center + portal_direction * tunnel_side_sign * portal_distance + portal_lateral * lateral_offset


func _build_tunnel_boundary_transition_points(
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

	if _get_tunnel_entry_anchor_id_for_portal(previous_anchor_id) == current_anchor_id:
		portal_anchor_id = previous_anchor_id
		portal_anchor_node = previous_anchor_node
	elif _get_tunnel_entry_anchor_id_for_portal(current_anchor_id) == previous_anchor_id:
		portal_anchor_id = current_anchor_id
		portal_anchor_node = current_anchor_node
	else:
		return []

	if !is_instance_valid(portal_anchor_node):
		return []

	var entry_anchor_id := _get_tunnel_entry_anchor_id_for_portal(portal_anchor_id)
	var entry_anchor_node := m_spawn_anchor_nodes.get(entry_anchor_id) as Node2D
	if !is_instance_valid(entry_anchor_node):
		return []

	var portal_center := _resolve_portal_center_position(actor, portal_anchor_node)
	var portal_direction := _get_portal_direction_vector(portal_anchor_node)
	if portal_direction.length_squared() <= 0.001:
		return []

	var transition_points: Array[Dictionary] = []
	var outside_side_sign := -_get_portal_tunnel_side_sign(portal_anchor_node)
	var portal_target_position := current_position if portal_anchor_id == current_anchor_id else previous_position
	var relative_to_portal := portal_target_position - portal_center
	var lateral_component := relative_to_portal - portal_direction * relative_to_portal.dot(portal_direction)
	_append_unique_transition_point(
		transition_points,
		portal_center + portal_direction * outside_side_sign * TUNNEL_ENTRY_FRONT_APPROACH_DISTANCE + lateral_component
	)

	return transition_points


func _append_unique_transition_point(points: Array[Dictionary], candidate: Vector2) -> void:
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


func _get_tunnel_entry_anchor_id_for_portal(anchor_id: String) -> String:
	if !anchor_id.ends_with(TUNNEL_PORTAL_SUFFIX):
		return ""
	return anchor_id.left(anchor_id.length() - TUNNEL_PORTAL_SUFFIX.length())


func _resolve_portal_center_position(actor: HumanBody2D, portal_anchor_node: Node2D) -> Vector2:
	var portal_node := _get_portal_for_anchor(portal_anchor_node)
	if portal_node != null:
		return _resolve_actor_anchor_position(actor, portal_node, Vector2.ZERO)
	return _resolve_actor_anchor_position(actor, portal_anchor_node, Vector2.ZERO)


func _get_portal_direction_vector(portal_anchor_node: Node2D) -> Vector2:
	var portal_node := _get_portal_for_anchor(portal_anchor_node)
	if portal_node == null:
		return Vector2.ZERO

	var collision_shape := portal_node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null:
		return collision_shape.global_transform.x.normalized()

	return portal_node.global_transform.x.normalized()


func _get_portal_lateral_vector(portal_anchor_node: Node2D) -> Vector2:
	var portal_node := _get_portal_for_anchor(portal_anchor_node)
	if portal_node == null:
		return Vector2.ZERO

	var collision_shape := portal_node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null:
		return collision_shape.global_transform.y.normalized()

	return portal_node.global_transform.y.normalized()


func _get_portal_tunnel_side_sign(portal_anchor_node: Node2D) -> float:
	var portal_node := _get_portal_for_anchor(portal_anchor_node)
	var tunnel_anchor := _find_tunnel_ancestor(portal_anchor_node)
	if portal_node == null or tunnel_anchor == null:
		return 1.0

	var tunnel_mask := LEVEL_REGISTRY.resolve_level_collision_mask(tunnel_anchor.get_resolved_level_id())
	if (int(portal_node.get("mask1")) & tunnel_mask) != 0:
		return -1.0
	if (int(portal_node.get("mask2")) & tunnel_mask) != 0:
		return 1.0
	return 1.0


func _get_portal_for_anchor(anchor_node: Node2D) -> Portal:
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


func _apply_anchor_level_to_actor(actor: HumanBody2D, anchor_node: Node) -> void:
	if !is_instance_valid(actor):
		return

	var level_node := _find_level_node(anchor_node)
	if level_node == null:
		return

	LEVEL_REGISTRY.apply_level_to_actor(int(level_node.call("get_resolved_level_id")), actor)


func _find_tunnel_ancestor(start_node: Node) -> Tunnel:
	var current := start_node
	while current != null:
		var tunnel := current as Tunnel
		if tunnel != null:
			return tunnel
		current = current.get_parent()
	return null


func _find_level_node(start_node: Node) -> Node:
	var current := start_node
	while current != null:
		if current.has_method("get_resolved_level_id"):
			return current
		current = current.get_parent()
	return null


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
