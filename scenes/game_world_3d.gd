extends Node3D

# Low-poly 3D runtime world scene.
#
# This is the Phase D deliverable of docs/plan/low_poly_3d_replacement.md: the 3D
# counterpart of scenes/game_main.gd. It boots a playable low-poly island on the
# existing 3D sidecar (LowPolyTerrain3D, HumanBody3D, PlayerController3D,
# Camera3DController, LowPolyLandmarkProxy3D) and carries the runtime-integration
# duties main.gd expects from a game root:
#   - it is a drop-in for main.gd's GAME_SCENE contract (visible flag,
#     sync_ui_state(), set_prompt_bgm_ducked())
#   - it resolves the shared AppState through AppRuntime and keeps location,
#     landmark, and resident lists in sync
#   - it applies the story resume anchor on entry and falls back to Piano Ferry
#
# The terrain-generation, actor placement, and terrain-elevation-follow logic is
# lifted from the validated scenes/tests/test_low_poly_world_3d.gd so runtime
# behavior matches the green combined-world smoke scene. The smoke-test assertions
# are intentionally dropped here; that scene remains the correctness owner.
#
# NOT YET PORTED (later phases of the replacement plan, tracked in that doc):
#   - Phase E: 3D residents, tunnels/multi-level interiors + portals, 3D-space
#     weather passes, world-anchored speech balloons, Area3D story subjects
#   - Phase F: story/resident/save parity in the full 3D world
#   - Phase G: repoint main.tscn to this scene and delete the 2D render stack
# Until Phase G, main.tscn still boots scenes/game_main.tscn; nothing here is
# wired into the runtime yet, so adding this scene changes no existing behavior.

const APP_RUNTIME := preload("res://game/app_runtime.gd")
const WEATHER_RUNTIME := preload("res://weather/weather_runtime.gd")
const WATER_WIND_ADAPTER := preload("res://terrain/low_poly_water_wind_adapter.gd")
const LowPolyWorldCoordinates3DScript = preload("res://terrain/low_poly_world_coordinates_3d.gd")
const LowPolyArtStyle3DScript = preload("res://terrain/low_poly_art_style_3d.gd")
const LowPolyLandmarkProxy3DScript = preload("res://architecture/low_poly/low_poly_landmark_proxy_3d.gd")
const RESIDENT_PRESENTER_3D := preload("res://characters/resident_presenter_3d.gd")

const LANDMARK_MASK_META := &"low_poly_landmark_mask_pixel"
const DEFAULT_RESUME_ANCHOR := "Piano Ferry"
const ISLAND_PATHS_LABEL := "Island Paths"
# Player is treated as "at" a landmark when within this XZ distance of its proxy.
# Sized for the scaled-up world and the large stylized building footprints.
const LANDMARK_LOCATION_RADIUS := 14.0

# Authored island placements mirror the validated combined-world scene. Landmark
# display names match the 2D game_main landmark dictionary so AppState, the journal,
# and the story layer keep reading the same canonical names.
const LANDMARK_PLACEMENTS := [
	{
		"name": "Piano Ferry",
		"path": "Landmarks/PianoFerryProxy",
		"isometric_position": Vector2(5248.0, 9376.0),
	},
	{
		"name": "Trinity Church",
		"path": "Landmarks/TrinityChurchProxy",
		"isometric_position": Vector2(-1120.0, 7888.0),
	},
	{
		"name": "Bi Shan Tunnel",
		"path": "Landmarks/BiShanTunnelProxy",
		"isometric_position": Vector2(-992.0, 7824.0),
	},
	{
		"name": "Long Shan Tunnel",
		"path": "Landmarks/LongShanTunnelProxy",
		"isometric_position": Vector2(3360.0, 7536.0),
	},
	{
		"name": "Bagua Tower",
		"path": "Landmarks/BaguaTowerProxy",
		"isometric_position": Vector2(3360.0, 6160.0),
	},
]

const ACTOR_GROUND_PROBE_UP := 0.72
const ACTOR_GROUND_PROBE_DOWN := 2.5
const MAX_ACTOR_WADE_DEPTH := 0.5

# Story subjects register here so the world can pick one active target by proximity.
const STORY_SUBJECT_GROUP := "story_subject_3d"
# How long a resident holds still and faces the player after being talked to.
const RESIDENT_TALK_PAUSE_SEC := 4.0

@onready var m_terrain: Node3D = $LowPolyTerrain3D
@onready var m_actor: CharacterBody3D = $human_body_3d
@onready var m_camera: Camera3D = $Camera3D
@onready var m_camera_controller: Node = $Camera3DController
@onready var m_sun: DirectionalLight3D = $Sun
@onready var m_landmarks_root: Node3D = $Landmarks

@export var art_style: LowPolyArtStyle3DScript
@export_range(0.0, 1.0, 0.01) var actor_terrain_clearance := 0.0
# Generate static collision for the authored stylized landmark buildings (which ship
# without collision) so the player cannot walk through them. Disable if the trimesh
# generation cost at load becomes a problem.
@export var generate_landmark_collision := true
# Show an on-screen performance overlay (FPS, frame time, draw calls, primitives,
# video memory) for the QA performance-capture gate. Off in normal play.
@export var show_debug_stats := false

var m_coordinates: LowPolyWorldCoordinates3DScript = LowPolyWorldCoordinates3DScript.new()
var m_landmark_nodes: Dictionary = {}
var m_weather_manager: WeatherManager = null
var m_wind_adapter: LowPolyWaterWindAdapter = null
var m_is_ready := false
var m_last_location := ""
var m_subjects: Array[StorySubject3D] = []
var m_closest_subject: StorySubject3D = null
var m_resident_root: Node3D = null
var m_stats_label: Label = null


func _app_state():
	return APP_RUNTIME.get_app_state(self)


func _ready() -> void:
	_apply_art_style()
	if is_instance_valid(m_camera):
		m_camera.current = true

	_cache_landmarks()
	_configure_world()
	_connect_actor_terrain_elevation()
	# Resolving AppState / WeatherManager can add service nodes to the current scene,
	# which fails while the scene tree is still instantiating this scene (e.g. when the
	# world is a child of another scene). Defer everything that touches shared services
	# until the tree is unblocked.
	call_deferred("_initialize_runtime")


func _initialize_runtime() -> void:
	if !is_inside_tree():
		return
	_setup_weather_wind()
	if generate_landmark_collision:
		_generate_landmark_collision()
	_spawn_residents()
	_gather_story_subjects()
	_connect_inspect()
	_apply_story_resume_anchor_if_needed()
	if show_debug_stats:
		_setup_debug_stats()
	m_is_ready = true
	sync_ui_state()
	_update_interaction_target()


func _physics_process(_delta: float) -> void:
	# Terrain elevation follow raycasts the physics space, so it must run inside a
	# physics frame where direct_space_state is accessible.
	_apply_actor_terrain_elevation()


func _process(_delta: float) -> void:
	if !m_is_ready:
		return
	_sync_location_from_player()
	_update_interaction_target()
	_update_debug_stats()


func _setup_debug_stats() -> void:
	var layer := CanvasLayer.new()
	layer.name = "DebugStatsLayer"
	layer.layer = 20
	add_child(layer)
	m_stats_label = Label.new()
	m_stats_label.position = Vector2(16.0, 60.0)
	m_stats_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	m_stats_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	m_stats_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(m_stats_label)


func _update_debug_stats() -> void:
	if m_stats_label == null:
		return
	var fps := Performance.get_monitor(Performance.TIME_FPS)
	var frame_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var draw_calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var primitives := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var objects := Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	var video_mem_mib := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	var static_mem_mib := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	m_stats_label.text = "FPS: %d\nProcess: %.2f ms\nDraw calls: %d\nPrimitives: %d\nObjects: %d\nVideo mem: %.1f MiB\nStatic mem: %.1f MiB" % [
		int(fps), frame_ms, int(draw_calls), int(primitives), int(objects), video_mem_mib, static_mem_mib
	]


# --- main.gd game-root contract -------------------------------------------------

func sync_ui_state() -> void:
	if !m_is_ready:
		return
	_app_state().set_landmarks(PackedStringArray(m_landmark_nodes.keys()))
	_app_state().set_residents(_app_state().get_known_resident_names())
	_sync_location_from_player()


func set_prompt_bgm_ducked(_ducked: bool) -> void:
	# BGM ownership is ported to the 3D world in Phase E of the replacement plan.
	# Kept as a safe no-op so the main.gd melody-prompt duck call never errors when
	# this scene becomes the game root.
	pass


# --- world setup ----------------------------------------------------------------

func _cache_landmarks() -> void:
	m_landmark_nodes.clear()
	for placement: Dictionary in LANDMARK_PLACEMENTS:
		var proxy := get_node_or_null(String(placement["path"])) as Node3D
		if is_instance_valid(proxy):
			m_landmark_nodes[String(placement["name"])] = proxy


func _configure_world() -> void:
	if !is_instance_valid(m_terrain) or !is_instance_valid(m_actor):
		return

	m_coordinates.configure_from_terrain(m_terrain)

	var profile := _resolve_generation_profile()
	var image := _load_mask_image()
	if profile == null or image == null:
		return

	var spawn_mask_pixel := _find_land_spawn_pixel(image, profile)
	var sample_cell := m_coordinates.mask_pixel_to_sample_cell(spawn_mask_pixel)
	var fallback_land_height: float = float(m_terrain.get("land_height"))
	var spawn_height := _get_terrain_sample_height(sample_cell, fallback_land_height)
	m_actor.global_position = m_coordinates.sample_cell_to_world_center(
		sample_cell, spawn_height + actor_terrain_clearance
	)
	_place_landmarks(image, profile, fallback_land_height)
	_apply_actor_terrain_elevation()
	_snap_camera_controller()


func _place_landmarks(image: Image, profile: TerrainGenerationProfile, land_height: float) -> void:
	if !is_instance_valid(m_landmarks_root):
		return

	for placement: Dictionary in LANDMARK_PLACEMENTS:
		var proxy := get_node_or_null(String(placement["path"])) as Node3D
		if !is_instance_valid(proxy):
			continue

		var isometric_position := placement["isometric_position"] as Vector2
		var mask_pixel := m_coordinates.isometric_position_to_mask_pixel(isometric_position)
		var snapped_mask_pixel := _find_nearest_land_pixel(
			image,
			profile,
			Vector2i(roundi(mask_pixel.x), roundi(mask_pixel.y))
		)
		var landmark_cell := m_coordinates.mask_pixel_to_sample_cell(snapped_mask_pixel)
		var landmark_height := _get_terrain_sample_height(landmark_cell, land_height)
		proxy.global_position = m_coordinates.sample_cell_to_world_center(landmark_cell, landmark_height)
		proxy.set_meta(LANDMARK_MASK_META, snapped_mask_pixel)


func _apply_art_style() -> void:
	if art_style == null:
		return

	if is_instance_valid(m_camera):
		m_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		m_camera.size = art_style.camera_orthographic_size

	if is_instance_valid(m_camera_controller):
		m_camera_controller.set("follow_offset", art_style.camera_follow_offset)
		m_camera_controller.set("look_at_offset", art_style.camera_look_at_offset)
		m_camera_controller.set("orthographic_size", art_style.camera_orthographic_size)
		m_camera_controller.set("min_orthographic_size", art_style.min_camera_orthographic_size)
		m_camera_controller.set("max_orthographic_size", art_style.max_camera_orthographic_size)

	if is_instance_valid(m_sun):
		m_sun.global_position = art_style.sun_position
		m_sun.light_color = art_style.sun_color
		m_sun.light_energy = art_style.sun_energy
		m_sun.shadow_enabled = art_style.sun_shadows_enabled
		m_sun.look_at(art_style.sun_look_at, Vector3.UP)


func _setup_weather_wind() -> void:
	if !is_instance_valid(m_terrain):
		return
	m_weather_manager = WEATHER_RUNTIME.get_weather_manager(self) as WeatherManager
	if m_weather_manager == null:
		return
	# 3D-space weather overlays are Phase E work; until then the manager only drives
	# the water wind through the decoupled adapter and does not cycle 2D overlays.
	m_weather_manager.cycles_enabled = false
	m_wind_adapter = WATER_WIND_ADAPTER.new()
	m_wind_adapter.bind(m_weather_manager, m_terrain)


func _snap_camera_controller() -> void:
	if !is_instance_valid(m_camera_controller):
		return
	if m_camera_controller.has_method("snap_to_target"):
		m_camera_controller.call("snap_to_target")


# --- AppState integration -------------------------------------------------------

func _apply_story_resume_anchor_if_needed() -> void:
	if !is_instance_valid(m_actor):
		return
	if _app_state().mode != "Story":
		return

	var anchor_id: String = _app_state().get_story_resume_anchor_id()
	if anchor_id.is_empty():
		anchor_id = DEFAULT_RESUME_ANCHOR

	var anchor_node := m_landmark_nodes.get(anchor_id) as Node3D
	if !is_instance_valid(anchor_node):
		anchor_node = m_landmark_nodes.get(DEFAULT_RESUME_ANCHOR) as Node3D
	if !is_instance_valid(anchor_node):
		return

	var anchor_origin := anchor_node.global_position
	# Drop the actor just in front of the landmark on XZ; the elevation follow seats
	# it onto the surface on the next physics frame.
	m_actor.global_position = Vector3(anchor_origin.x, m_actor.global_position.y, anchor_origin.z + 1.5)
	_apply_actor_terrain_elevation()


func _sync_location_from_player() -> void:
	if !is_instance_valid(m_actor):
		return

	var best_name := ISLAND_PATHS_LABEL
	var best_distance_sq := INF
	var actor_flat := _flatten(m_actor.global_position)

	for landmark_name in m_landmark_nodes.keys():
		var landmark_node: Node3D = m_landmark_nodes[landmark_name]
		if !is_instance_valid(landmark_node):
			continue
		var distance_sq := actor_flat.distance_squared_to(_flatten(landmark_node.global_position))
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			best_name = String(landmark_name)

	var resolved := best_name
	if best_distance_sq > LANDMARK_LOCATION_RADIUS * LANDMARK_LOCATION_RADIUS:
		resolved = ISLAND_PATHS_LABEL

	if resolved == m_last_location:
		return
	m_last_location = resolved
	_app_state().set_location(resolved)
	_update_story_resume_checkpoint(resolved)


# Mirror scenes/game_main.gd: while in Story mode, keep the resume checkpoint at the
# last landmark the player reached so Continue restores near where they were. The
# landmark display names double as stable safe-resume anchor ids.
func _update_story_resume_checkpoint(resolved_location: String) -> void:
	if _app_state().mode != "Story":
		return
	if resolved_location.is_empty() or resolved_location == ISLAND_PATHS_LABEL:
		return
	if !m_landmark_nodes.has(resolved_location):
		return
	_app_state().set_story_resume_checkpoint(resolved_location, resolved_location)


func _flatten(position: Vector3) -> Vector2:
	return Vector2(position.x, position.z)


# --- terrain elevation follow (mirrors the validated combined-world scene) -------

func _connect_actor_terrain_elevation() -> void:
	if !is_instance_valid(m_actor):
		return
	if !m_actor.has_signal("global_position_changed"):
		return
	var callback := Callable(self, "_on_actor_global_position_changed")
	if m_actor.is_connected("global_position_changed", callback):
		return
	m_actor.connect("global_position_changed", callback)


func _on_actor_global_position_changed() -> void:
	_apply_actor_terrain_elevation()


func _apply_actor_terrain_elevation() -> void:
	if !is_instance_valid(m_actor) or !is_instance_valid(m_terrain):
		return
	if m_coordinates.resolve_source_size() == Vector2i.ZERO:
		return

	var ground_height := _resolve_actor_surface_height()
	if is_nan(ground_height):
		return
	var position := m_actor.global_position
	var target_y := ground_height + actor_terrain_clearance
	if is_equal_approx(position.y, target_y):
		return
	position.y = target_y
	m_actor.global_position = position


func _resolve_actor_surface_height() -> float:
	if Engine.is_in_physics_frame():
		var world := m_actor.get_world_3d()
		if world != null:
			var space_state := world.direct_space_state
			if space_state != null:
				var origin := m_actor.global_position
				var query := PhysicsRayQueryParameters3D.create(
					origin + Vector3.UP * ACTOR_GROUND_PROBE_UP,
					origin + Vector3.DOWN * ACTOR_GROUND_PROBE_DOWN
				)
				query.collision_mask = m_actor.collision_mask
				query.collide_with_areas = false
				query.exclude = [m_actor.get_rid()]
				var hit := space_state.intersect_ray(query)
				if !hit.is_empty():
					return float((hit["position"] as Vector3).y)
	return _resolve_terrain_sample_height()


func _resolve_terrain_sample_height() -> float:
	var fallback_land_height: float = float(m_terrain.get("land_height"))
	if !is_instance_valid(m_terrain):
		return fallback_land_height
	var sample_cell := m_coordinates.world_position_to_sample_cell(m_actor.global_position)
	var seabed_height := _get_terrain_world_height(m_actor.global_position, sample_cell, fallback_land_height)
	if !m_terrain.has_method("get_world_water_surface_height"):
		return seabed_height
	var water_surface := float(m_terrain.call("get_world_water_surface_height", m_actor.global_position))
	return maxf(seabed_height, water_surface - MAX_ACTOR_WADE_DEPTH)


func _get_terrain_sample_height(sample_cell: Vector2i, fallback: float) -> float:
	if !is_instance_valid(m_terrain):
		return fallback
	if !m_terrain.has_method("get_sample_cell_height"):
		return fallback
	return float(m_terrain.call("get_sample_cell_height", sample_cell))


func _get_terrain_world_height(world_position: Vector3, sample_cell: Vector2i, fallback: float) -> float:
	if !is_instance_valid(m_terrain):
		return fallback
	if m_terrain.has_method("get_world_surface_height"):
		return float(m_terrain.call("get_world_surface_height", world_position))
	return _get_terrain_sample_height(sample_cell, fallback)


# --- terrain mask helpers (mirror the validated combined-world scene) ------------

func _resolve_generation_profile() -> TerrainGenerationProfile:
	var terrain_profile: Variant = m_terrain.get("generation_profile")
	var profile := terrain_profile as TerrainGenerationProfile
	if profile == null:
		profile = TerrainGenerationProfile.create_default_profile()
	profile.ensure_defaults()
	if !profile.is_valid_profile():
		return null
	return profile


func _load_mask_image() -> Image:
	var mask_file_value: Variant = m_terrain.get("mask_file")
	var mask_file := String(mask_file_value)
	if mask_file.is_empty():
		return null

	var image := Image.new()
	var load_error := image.load(mask_file)
	if load_error != OK:
		return null

	if image.is_compressed():
		image.decompress()
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return image


func _find_land_spawn_pixel(image: Image, profile: TerrainGenerationProfile) -> Vector2i:
	var source_size := image.get_size()
	var center := Vector2i(source_size.x / 2, source_size.y / 2)
	var step: int = maxi(int(m_terrain.get("sample_stride")), 1)
	var max_radius := maxi(source_size.x, source_size.y)

	for radius in range(0, max_radius, step):
		var min_x: int = maxi(center.x - radius, 0)
		var max_x: int = mini(center.x + radius, source_size.x - 1)
		var min_y: int = maxi(center.y - radius, 0)
		var max_y: int = mini(center.y + radius, source_size.y - 1)

		for y in range(min_y, max_y + 1, step):
			for x in range(min_x, max_x + 1, step):
				var is_edge := x == min_x or x == max_x or y == min_y or y == max_y
				if !is_edge:
					continue
				var pixel := image.get_pixel(x, y)
				if !profile.is_water_pixel(pixel):
					return Vector2i(x, y)

	return center


func _find_nearest_land_pixel(image: Image, profile: TerrainGenerationProfile, target_pixel: Vector2i) -> Vector2i:
	var source_size := image.get_size()
	var clamped_target := Vector2i(
		clampi(target_pixel.x, 0, source_size.x - 1),
		clampi(target_pixel.y, 0, source_size.y - 1)
	)
	if !profile.is_water_pixel(image.get_pixel(clamped_target.x, clamped_target.y)):
		return clamped_target

	var step: int = maxi(int(m_terrain.get("sample_stride")), 1)
	var max_radius := maxi(source_size.x, source_size.y)
	for radius in range(step, max_radius, step):
		var min_x: int = maxi(clamped_target.x - radius, 0)
		var max_x: int = mini(clamped_target.x + radius, source_size.x - 1)
		var min_y: int = maxi(clamped_target.y - radius, 0)
		var max_y: int = mini(clamped_target.y + radius, source_size.y - 1)

		for y in range(min_y, max_y + 1, step):
			for x in range(min_x, max_x + 1, step):
				var is_edge := x == min_x or x == max_x or y == min_y or y == max_y
				if !is_edge:
					continue
				if !profile.is_water_pixel(image.get_pixel(x, y)):
					return Vector2i(x, y)

	return clamped_target


# --- story-subject interaction (mirrors scenes/game_main.gd's subject path) -------

func _spawn_residents() -> void:
	var presenter := RESIDENT_PRESENTER_3D.new()
	m_resident_root = presenter.spawn_residents(self, _app_state(), m_landmark_nodes)


func _generate_landmark_collision() -> void:
	for placement: Dictionary in LANDMARK_PLACEMENTS:
		var node := get_node_or_null(String(placement["path"])) as Node3D
		if is_instance_valid(node):
			_add_trimesh_collision_recursive(node)


# Stylized landmark scenes are visual-only meshes. Add a concave static collider per
# building mesh so walls block the actor. Roofs sit above the ground-probe reach, so
# this blocks walking through walls without snapping the actor up onto rooftops.
func _add_trimesh_collision_recursive(node: Node) -> void:
	for child in node.get_children():
		var mesh_instance := child as MeshInstance3D
		if mesh_instance != null and mesh_instance.mesh != null:
			mesh_instance.create_trimesh_collision()
		_add_trimesh_collision_recursive(child)


func _gather_story_subjects() -> void:
	m_subjects.clear()
	for node in get_tree().get_nodes_in_group(STORY_SUBJECT_GROUP):
		var subject := node as StorySubject3D
		if subject != null:
			m_subjects.append(subject)


func _connect_inspect() -> void:
	var controller: Variant = m_actor.get("controller") if is_instance_valid(m_actor) else null
	if controller == null:
		return
	if !(controller is Object) or !controller.has_signal("inspect_requested"):
		return
	if !controller.is_connected("inspect_requested", _on_inspect_requested):
		controller.connect("inspect_requested", _on_inspect_requested)


func _update_interaction_target() -> void:
	m_closest_subject = _resolve_closest_subject()
	_update_hint_text(m_closest_subject)


# Deterministic proximity pick: nearest targetable subject inside its own radius,
# tie-broken by interaction priority so collect/perform win over inspect.
func _resolve_closest_subject() -> StorySubject3D:
	if !is_instance_valid(m_actor):
		return null
	var actor_flat := _flatten(m_actor.global_position)
	var best: StorySubject3D = null
	var best_distance := INF
	var best_priority := 2147483647
	for subject in m_subjects:
		if !is_instance_valid(subject) or !subject.is_targetable():
			continue
		var distance := actor_flat.distance_to(_flatten(subject.global_position))
		if distance > subject.interaction_radius:
			continue
		var priority := subject.get_interaction_priority()
		if priority < best_priority or (priority == best_priority and distance < best_distance):
			best = subject
			best_distance = distance
			best_priority = priority
	return best


func _on_inspect_requested() -> void:
	if !is_instance_valid(m_closest_subject):
		_app_state().set_save_status("Inspect: nothing nearby")
		return

	var interaction_request := _build_story_interaction_request(m_closest_subject)
	if interaction_request.is_empty():
		_app_state().set_save_status("Inspect: %s" % m_closest_subject.get_display_name())
		return

	var interaction_context: Dictionary = interaction_request.get("context", {})
	var interaction: Dictionary = _app_state().activate_story_subject(
		String(interaction_request.get("subject_id", "")),
		String(interaction_request.get("action", "")),
		interaction_context
	)

	var request_action := String(interaction_request.get("action", ""))
	var subject_display_name := String(interaction_request.get("display_name", ""))
	if request_action == "talk":
		# Resident dialogue shows in a world-anchored balloon above the resident and
		# also surfaces through the shared save-status channel.
		var line := String(interaction.get("line", ""))
		if line.is_empty():
			line = "Talked with %s" % subject_display_name
		_show_resident_balloon(m_closest_subject, line)
		_pause_and_face_resident(m_closest_subject)
		_app_state().set_save_status(line)
	elif request_action == "inspect":
		_app_state().set_save_status(
			String(interaction.get("text", "Inspect: %s" % subject_display_name))
		)

	_update_hint_text(m_closest_subject)


func _build_story_interaction_request(subject: StorySubject3D) -> Dictionary:
	if !is_instance_valid(subject):
		return {}
	var subject_id := subject.get_story_subject_id()
	var action := subject.get_story_action()
	if subject_id.is_empty() or action.is_empty():
		return {}
	return {
		"subject_id": subject_id,
		"action": action,
		"display_name": subject.get_display_name(),
		"context": _build_story_subject_context(subject, subject.build_story_subject_context()),
	}


func _build_story_subject_context(subject: StorySubject3D, extra_context: Dictionary = {}) -> Dictionary:
	var context := extra_context.duplicate(true)
	context["location"] = _app_state().location
	if is_instance_valid(subject):
		context["display_name"] = context.get("display_name", subject.get_display_name())
		context["world_position"] = subject.global_position
		context["level_id"] = 0
	return context


func _update_hint_text(subject: StorySubject3D) -> void:
	if !is_instance_valid(subject):
		_app_state().set_hint(_app_state().build_input_hint("R Inspect"))
		return

	var interaction_request := _build_story_interaction_request(subject)
	if interaction_request.is_empty():
		_app_state().set_hint(_app_state().build_input_hint("R Inspect %s" % subject.get_display_name()))
		return

	var action := String(interaction_request.get("action", ""))
	var display_name := String(interaction_request.get("display_name", ""))
	if action == "talk":
		_app_state().set_hint(_app_state().build_input_hint("R Talk to %s" % display_name))
		return

	var description: Dictionary = _app_state().describe_story_subject(
		String(interaction_request.get("subject_id", "")),
		action,
		interaction_request.get("context", {})
	)
	var prompt_text := String(description.get("prompt", "")).strip_edges()
	if prompt_text.is_empty():
		prompt_text = "%s %s" % [_interaction_verb_for_action(action), display_name]
	_app_state().set_hint(_app_state().build_input_hint("R %s" % prompt_text))


func _show_resident_balloon(subject: StorySubject3D, line: String) -> void:
	if !is_instance_valid(subject):
		return
	var resident := subject.get_parent()
	if resident == null:
		return
	var balloon := resident.get_node_or_null("Balloon3D")
	if balloon != null and balloon.has_method("show_line"):
		balloon.call("show_line", line)


# Match the 2D reveal-dialogue behaviour: the talked-to resident turns to face the
# player and holds still for a moment before resuming its wander.
func _pause_and_face_resident(subject: StorySubject3D) -> void:
	if !is_instance_valid(subject) or !is_instance_valid(m_actor):
		return
	var resident := subject.get_parent() as Node3D
	if !is_instance_valid(resident):
		return

	var to_player := m_actor.global_position - resident.global_position
	to_player.y = 0.0
	if to_player.length() > 0.01 and resident.has_method("set_direction_vector"):
		resident.call("set_direction_vector", to_player.normalized())

	var controller: Variant = resident.get("controller")
	if controller != null and controller is Object and controller.has_method("pause_for"):
		controller.call("pause_for", RESIDENT_TALK_PAUSE_SEC)


func _interaction_verb_for_action(action: String) -> String:
	match action:
		"perform":
			return "Perform"
		"collect":
			return "Collect"
		"talk":
			return "Talk to"
		_:
			return "Inspect"
