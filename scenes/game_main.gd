# @tool is required so that @onready node references resolve correctly when the
# scene is open in the Godot editor (e.g. for terrain authoring and landmark
# inspection). All runtime-only code paths (resident spawning, signal wiring,
# location syncing) are guarded by Engine.is_editor_hint() checks or by the
# m_is_ready flag so they do not execute during edit-time.
@tool
extends Node2D

const LANDMARK_SYNC_DISTANCE := 1600.0
const NPC_SCENE: PackedScene = preload("res://characters/resident_npc.tscn")
const LEVEL_REGISTRY := preload("res://common/level_registry.gd")
const APP_RUNTIME := preload("res://game/app_runtime.gd")
const BGM_MANAGER_SCRIPT := preload("res://game/bgm_manager.gd")
const ROUTE_RESOLVER_SCRIPT := preload("res://scenes/route_resolver.gd")
const RESIDENT_SPAWNER_SCRIPT := preload("res://scenes/resident_spawner.gd")
const TUNNEL_CONTEXT_SCRIPT := preload("res://scenes/tunnel_context.gd")
const NPC_ROUTE_DEBUG_DRAWER_SCRIPT := preload("res://scenes/npc_route_debug_drawer.gd")
const TUNNEL_ENTRY_FRONT_APPROACH_DISTANCE := 96.0
const TUNNEL_PORTAL_SUFFIX := " Portal"
const DIRECTIONAL_PORTAL_MIN_OFFSET_DISTANCE := 16.0
const LANDMARK_CUE_FILES := {
	"piano_ferry": "res://resources/audio/sfx/landmark_cues/piano_ferry_refrain.ogg",
	"trinity_church": "res://resources/audio/sfx/landmark_cues/trinity_chime.ogg",
	"bi_shan_tunnel": "res://resources/audio/sfx/landmark_cues/bi_shan_echo.ogg",
	"long_shan_tunnel": "res://resources/audio/sfx/landmark_cues/long_shan_route.ogg",
	"bagua_tower": "res://resources/audio/sfx/landmark_cues/bagua_synthesis.ogg",
	"festival_stage": "res://resources/audio/sfx/landmark_cues/festival_stage.ogg",
}
const LANDMARK_CUE_VOLUME_DB := -4.0
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
		_sync_debug_drawer_config()

@export var debug_npc_route_filter: String = "":
	set(value):
		var normalized_value := value.strip_edges()
		if debug_npc_route_filter == normalized_value:
			return
		debug_npc_route_filter = normalized_value
		_sync_debug_drawer_config()

@export var debug_draw_npc_route_labels: bool = true:
	set(value):
		if debug_draw_npc_route_labels == value:
			return
		debug_draw_npc_route_labels = value
		_sync_debug_drawer_config()

var m_is_ready := false
var m_player_controller: PlayerController = null
var m_closest_object: Node2D = null
var m_landmark_nodes: Dictionary = {}
var m_spawn_anchor_nodes: Dictionary = {}
var m_tunnel_nodes: Array[Tunnel] = []
var m_resident_root: Node2D = null
var m_bgm_manager: Node = null
var m_landmark_cue_player: AudioStreamPlayer = null
var m_landmark_cue_stream_cache: Dictionary = {}
var m_route_resolver: RefCounted = null
var m_resident_spawner: RefCounted = null
var m_tunnel_context: Node = null
var m_debug_route_drawer: Node2D = null


func _app_state():
	return APP_RUNTIME.get_app_state(self)


func _ensure_scene_helpers() -> void:
	if m_route_resolver == null:
		m_route_resolver = ROUTE_RESOLVER_SCRIPT.new(m_spawn_anchor_nodes)
	else:
		m_route_resolver.update_spawn_anchor_nodes(m_spawn_anchor_nodes)

	if m_resident_spawner == null:
		m_resident_spawner = RESIDENT_SPAWNER_SCRIPT.new()

	if !is_instance_valid(m_tunnel_context):
		m_tunnel_context = TUNNEL_CONTEXT_SCRIPT.new()
		m_tunnel_context.name = "TunnelContext"
		add_child(m_tunnel_context)

	if !is_instance_valid(m_debug_route_drawer):
		m_debug_route_drawer = NPC_ROUTE_DEBUG_DRAWER_SCRIPT.new()
		m_debug_route_drawer.name = "NpcRouteDebugDrawer"
		add_child(m_debug_route_drawer)
	_sync_debug_drawer_config()


func _refresh_tunnel_context_config() -> void:
	if !is_instance_valid(m_tunnel_context):
		return
	m_tunnel_context.configure(m_player, m_resident_root, m_tunnel_nodes)


func _sync_debug_drawer_config() -> void:
	if !is_instance_valid(m_debug_route_drawer):
		return
	m_debug_route_drawer.app_state = _app_state()
	m_debug_route_drawer.resident_root = m_resident_root
	m_debug_route_drawer.debug_draw_npc_routes = debug_draw_npc_routes
	m_debug_route_drawer.debug_npc_route_filter = debug_npc_route_filter
	m_debug_route_drawer.debug_draw_npc_route_labels = debug_draw_npc_route_labels


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	_app_state()


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	m_is_ready = true
	if is_instance_valid(m_terrain):
		m_terrain.player = m_player
	_cache_landmarks()
	_cache_spawn_anchors()
	_ensure_scene_helpers()
	_apply_story_resume_anchor_if_needed()
	_cache_tunnels()
	_setup_landmark_audio_feedback()
	_spawn_catalog_residents()
	_connect_ui_signals()
	if !Engine.is_editor_hint():
		_setup_bgm()
	_refresh_tunnel_context_config()
	_sync_debug_drawer_config()
	sync_ui_state()


func _exit_tree() -> void:
	m_is_ready = false
	m_bgm_manager = null
	m_route_resolver = null
	m_resident_spawner = null
	m_tunnel_context = null
	m_debug_route_drawer = null


func _process(_delta: float) -> void:
	pass


func _draw() -> void:
	pass


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
		display_name = _app_state().get_resident_display_name(resident_id)

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

	_app_state().set_landmarks(PackedStringArray(m_landmark_nodes.keys()))
	_app_state().set_residents(_app_state().get_known_resident_names())
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
	if m_route_resolver != null:
		m_route_resolver.update_spawn_anchor_nodes(m_spawn_anchor_nodes)


func _apply_story_resume_anchor_if_needed() -> void:
	if !is_instance_valid(m_player):
		return
	if _app_state().mode not in ["Story", "Postgame"]:
		return

	var anchor_id = _app_state().get_story_resume_anchor_id()
	if anchor_id.is_empty():
		anchor_id = "Piano Ferry"

	var anchor_node := m_spawn_anchor_nodes.get(anchor_id) as Node2D
	if !is_instance_valid(anchor_node):
		anchor_node = m_spawn_anchor_nodes.get("Piano Ferry") as Node2D
	if !is_instance_valid(anchor_node):
		return

	m_player.global_position = m_route_resolver.resolve_actor_anchor_position(m_player, anchor_node, Vector2.ZERO)
	m_route_resolver.apply_anchor_level_to_actor(m_player, anchor_node)


func _update_story_resume_checkpoint() -> void:
	if _app_state().mode not in ["Story", "Postgame"]:
		return

	var anchor_id := _find_story_resume_anchor_id()
	if anchor_id.is_empty():
		return

	var location_label = _app_state().location
	if location_label.is_empty() or location_label == "Island Paths":
		location_label = _resume_location_for_anchor(anchor_id)

	_app_state().set_story_resume_checkpoint(anchor_id, location_label)


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
	if anchor_id == "Piano Ferry" and _app_state().mode == "Postgame":
		return "Ferry Plaza"
	return anchor_id


func _cache_tunnels() -> void:
	m_tunnel_nodes.clear()

	for tunnel_node in [m_bi_shan_tunnel, m_long_shan_tunnel]:
		var tunnel := tunnel_node as Tunnel
		if tunnel != null:
			m_tunnel_nodes.append(tunnel)
	_refresh_tunnel_context_config()


func _connect_ui_signals() -> void:
	if !is_instance_valid(m_player):
		return

	if !_app_state().player_appearance_changed.is_connected(_on_player_appearance_changed):
		_app_state().player_appearance_changed.connect(_on_player_appearance_changed)
	if !_app_state().story_milestone.is_connected(_on_story_milestone):
		_app_state().story_milestone.connect(_on_story_milestone)
	if !_app_state().landmark_audio_cue_requested.is_connected(_on_landmark_audio_cue_requested):
		_app_state().landmark_audio_cue_requested.connect(_on_landmark_audio_cue_requested)
	if !_app_state().prompt_volume_changed.is_connected(_on_prompt_volume_changed):
		_app_state().prompt_volume_changed.connect(_on_prompt_volume_changed)

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


func _setup_bgm() -> void:
	if is_instance_valid(m_bgm_manager):
		return

	m_bgm_manager = BGM_MANAGER_SCRIPT.new()
	m_bgm_manager.name = "BGMManager"
	add_child(m_bgm_manager)


func _setup_landmark_audio_feedback() -> void:
	if Engine.is_editor_hint():
		return
	if is_instance_valid(m_landmark_cue_player):
		return

	m_landmark_cue_player = AudioStreamPlayer.new()
	m_landmark_cue_player.name = "LandmarkCuePlayer"
	m_landmark_cue_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(m_landmark_cue_player)
	_apply_prompt_volume()


func set_prompt_bgm_ducked(ducked: bool) -> void:
	if !is_instance_valid(m_bgm_manager):
		return
	if m_bgm_manager.has_method("set_ducked"):
		m_bgm_manager.call("set_ducked", ducked)


func _on_landmark_audio_cue_requested(cue_id: String, _context: Dictionary) -> void:
	_play_landmark_audio_cue(cue_id)


func _on_prompt_volume_changed(_volume_percent: float) -> void:
	_apply_prompt_volume()


func _apply_prompt_volume() -> void:
	if !is_instance_valid(m_landmark_cue_player):
		return

	m_landmark_cue_player.volume_db = _app_state().get_prompt_volume_db(LANDMARK_CUE_VOLUME_DB)


func _play_landmark_audio_cue(cue_id: String) -> void:
	if cue_id.is_empty():
		return
	if !is_instance_valid(m_landmark_cue_player):
		_setup_landmark_audio_feedback()
	if !is_instance_valid(m_landmark_cue_player):
		return

	var stream := _get_landmark_cue_stream(cue_id)
	if stream == null:
		push_warning("Landmark cue %s is missing or failed to load." % cue_id)
		return

	var cue_duration := maxf(stream.get_length(), 0.75)
	if is_instance_valid(m_bgm_manager) and m_bgm_manager.has_method("duck_for_cue"):
		m_bgm_manager.call("duck_for_cue", cue_duration)

	m_landmark_cue_player.stop()
	m_landmark_cue_player.stream = stream
	m_landmark_cue_player.play()


func _get_landmark_cue_stream(cue_id: String) -> AudioStream:
	var file_path := String(LANDMARK_CUE_FILES.get(cue_id, ""))
	if file_path.is_empty():
		return null
	if m_landmark_cue_stream_cache.has(file_path):
		return m_landmark_cue_stream_cache.get(file_path) as AudioStream
	if !ResourceLoader.exists(file_path):
		return null

	var stream := load(file_path) as AudioStream
	if stream == null:
		return null

	m_landmark_cue_stream_cache[file_path] = stream
	return stream


func _sync_location_from_player() -> void:
	if !is_instance_valid(m_player):
		return

	_sync_tunnel_resident_visibility()

	if _is_landmark(m_closest_object):
		_app_state().set_location(_display_name_for_node(m_closest_object))
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
		_app_state().set_location(best_name)
	else:
		_app_state().set_location("Island Paths")

	_update_story_resume_checkpoint()


func _on_closest_object_changed(new_object: Node2D) -> void:
	m_closest_object = new_object

	if _is_landmark(new_object):
		_app_state().set_location(_display_name_for_node(new_object))

	_update_hint_text(new_object)


func _on_inspect_requested() -> void:
	if !is_instance_valid(m_closest_object):
		_app_state().set_save_status("Inspect: nothing nearby")
		return

	var resident_controller := _get_resident_controller(m_closest_object)
	if resident_controller != null:
		var resident_id := resident_controller.get_resident_id()
		var interaction = _app_state().interact_with_resident(resident_id)
		var resident_name = _app_state().get_resident_display_name(resident_id)
		var dialogue_line := String(interaction.get("line", ""))

		if interaction.is_empty():
			_app_state().set_save_status("Talked with %s" % resident_name)

		resident_controller.reveal_dialogue(dialogue_line)
		# Note: set_residents is not called here because interact_with_resident
		# already calls _sync_known_residents() internally.
		_update_hint_text(m_closest_object)
		return

	var landmark_trigger := _get_landmark_trigger(m_closest_object)
	if landmark_trigger != null:
		var consumed = _app_state().activate_landmark_trigger(
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
	_app_state().set_save_status("Inspect: %s" % display_name)


func _update_hint_text(target: Node2D) -> void:
	if !is_instance_valid(target):
		_app_state().set_hint(_app_state().build_input_hint("R Inspect"))
		return

	var landmark_trigger := _get_landmark_trigger(target)
	if landmark_trigger != null:
		if landmark_trigger.is_collected():
			_app_state().set_hint(_app_state().build_input_hint("R Inspect"))
		elif landmark_trigger.landmark_id == "festival_stage":
			_app_state().set_hint(_app_state().build_input_hint("R Perform %s" % landmark_trigger.display_name))
		elif landmark_trigger.landmark_id == "trinity_church" and landmark_trigger.trigger_id == "choir_chime":
			_app_state().set_hint(_app_state().build_input_hint("R Perform %s" % landmark_trigger.display_name))
		else:
			_app_state().set_hint(_app_state().build_input_hint("R Collect %s" % landmark_trigger.display_name))
		return

	var display_name := _display_name_for_node(target)
	if _get_resident_controller(target) != null:
		_app_state().set_hint(_app_state().build_input_hint("R Talk to %s" % display_name))
		return
	_app_state().set_hint(_app_state().build_input_hint("R Inspect %s" % display_name))


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
		return _app_state().get_resident_display_name(resident_controller.get_resident_id())

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
	m_resident_root = m_resident_spawner.spawn_catalog_residents(
		m_actor_root,
		_app_state(),
		m_route_resolver,
		_sync_tunnel_resident_visibility
	)
	_refresh_tunnel_context_config()
	_sync_debug_drawer_config()
	_sync_tunnel_resident_visibility()


func _sync_tunnel_resident_visibility() -> void:
	if is_instance_valid(m_tunnel_context):
		m_tunnel_context.sync()


func _find_player_tunnel() -> Tunnel:
	if !is_instance_valid(m_tunnel_context):
		return null
	return m_tunnel_context.find_player_tunnel()


func _find_resident_tunnel(actor: HumanBody2D) -> Tunnel:
	if !is_instance_valid(m_tunnel_context):
		return null
	return m_tunnel_context.find_resident_tunnel(actor)


func _find_tunnel_for_actor(actor: HumanBody2D, require_interior_level: bool) -> Tunnel:
	if !is_instance_valid(m_tunnel_context):
		return null
	return m_tunnel_context.find_tunnel_for_actor(actor, require_interior_level)


func _build_resident_movement_config(resident_id: String, actor: HumanBody2D, movement_config: Dictionary) -> Dictionary:
	return m_route_resolver.build_resident_movement_config(resident_id, actor, movement_config)


func _resolve_actor_anchor_position(actor: HumanBody2D, anchor_node: Node2D, offset: Vector2) -> Vector2:
	return m_route_resolver.resolve_actor_anchor_position(actor, anchor_node, offset)


func _resolve_route_anchor_position(actor: HumanBody2D, anchor_id: String, anchor_node: Node2D, offset: Vector2) -> Vector2:
	return m_route_resolver.resolve_route_anchor_position(actor, anchor_id, anchor_node, offset)


func _resolve_directional_portal_route_position(
	actor: HumanBody2D,
	portal_anchor_id: String,
	portal_anchor_node: Node2D,
	offset: Vector2
) -> Vector2:
	return m_route_resolver.resolve_directional_portal_route_position(
		actor,
		portal_anchor_id,
		portal_anchor_node,
		offset
	)


func _build_tunnel_boundary_transition_points(
	actor: HumanBody2D,
	previous_anchor_id: String,
	previous_anchor_node: Node2D,
	previous_position: Vector2,
	current_anchor_id: String,
	current_anchor_node: Node2D,
	current_position: Vector2
) -> Array[Dictionary]:
	return m_route_resolver.build_tunnel_boundary_transition_points(
		actor,
		previous_anchor_id,
		previous_anchor_node,
		previous_position,
		current_anchor_id,
		current_anchor_node,
		current_position
	)


func _append_unique_transition_point(points: Array[Dictionary], candidate: Vector2) -> void:
	m_route_resolver.append_unique_transition_point(points, candidate)


func _get_tunnel_entry_anchor_id_for_portal(anchor_id: String) -> String:
	return m_route_resolver.get_tunnel_entry_anchor_id_for_portal(anchor_id)


func _resolve_portal_center_position(actor: HumanBody2D, portal_anchor_node: Node2D) -> Vector2:
	return m_route_resolver.resolve_portal_center_position(actor, portal_anchor_node)


func _get_portal_direction_vector(portal_anchor_node: Node2D) -> Vector2:
	return m_route_resolver.get_portal_direction_vector(portal_anchor_node)


func _get_portal_lateral_vector(portal_anchor_node: Node2D) -> Vector2:
	return m_route_resolver.get_portal_lateral_vector(portal_anchor_node)


func _get_portal_tunnel_side_sign(portal_anchor_node: Node2D) -> float:
	return m_route_resolver.get_portal_tunnel_side_sign(portal_anchor_node)


func _get_portal_for_anchor(anchor_node: Node2D) -> Portal:
	return m_route_resolver.get_portal_for_anchor(anchor_node)


func _apply_anchor_level_to_actor(actor: HumanBody2D, anchor_node: Node) -> void:
	m_route_resolver.apply_anchor_level_to_actor(actor, anchor_node)


func _find_tunnel_ancestor(start_node: Node) -> Tunnel:
	return m_route_resolver.find_tunnel_ancestor(start_node)


func _find_level_node(start_node: Node) -> Node:
	return m_route_resolver.find_level_node(start_node)


func _on_player_appearance_changed(_profile: Dictionary, _appearance_config: Dictionary) -> void:
	_apply_player_costume()


func _on_story_milestone(milestone_id: String, context: Dictionary) -> void:
	if _app_state().mode != "Story":
		return

	match milestone_id:
		"fragment_restored":
			if String(context.get("source_id", "")) == "bi_shan_echo":
				call_deferred("_apply_story_milestone_status", "The Bi Shan crossing feels calmer now that its mural route has answered.")
		"festival_ready":
			call_deferred("_apply_story_milestone_status", "Across the island, lamps and harbor ropes turn back toward the plaza.")


func _apply_story_milestone_status(text: String) -> void:
	if _app_state().mode != "Story":
		return
	if text.is_empty():
		return
	_app_state().set_save_status(text)


func _apply_player_costume() -> void:
	if !is_instance_valid(m_player):
		return

	var appearance_config = _app_state().get_player_appearance_config()
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
