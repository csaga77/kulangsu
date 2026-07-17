extends Node3D

# Low-poly 3D runtime world scene.
#
# This is the production overworld selected by main.gd. It boots a playable
# low-poly island with LowPolyTerrain3D, HumanBody3D, PlayerController3D,
# Camera3DController, authored landmark scenes, and stable tunnel anchors. It
# carries the runtime-integration duties main.gd expects from a game root:
#   - it is a drop-in for main.gd's GAME_SCENE contract (visible flag,
#     sync_ui_state(), set_prompt_bgm_ducked())
#   - it resolves the shared AppState through AppRuntime and keeps location,
#     landmark, and resident lists in sync
#   - it applies the story resume anchor on entry and falls back to the catalog default
#
# Runtime correctness is covered by scenes/tests/test_game_world_3d.tscn, with
# focused terrain, street, actor-collision, camera, and building tests owning the
# lower-level subsystem regressions.

const APP_RUNTIME := preload("res://game/app_runtime.gd")
const WEATHER_RUNTIME := preload("res://weather/weather_runtime.gd")
const WATER_WIND_ADAPTER := preload("res://terrain/low_poly_water_wind_adapter.gd")
const WEATHER_RIG_3D_SCRIPT := preload("res://weather/weather_rig_3d.gd")
const BGM_MANAGER_SCRIPT := preload("res://game/bgm_manager.gd")
const LANDMARK_CATALOG_SCRIPT := preload("res://game/landmarks/landmark_catalog.gd")
const ActorSurfaceFollowerScript = preload("res://game/world/actor_surface_follower.gd")
const StoryInteractionCoordinatorScript = preload(
	"res://game/world/story_interaction_coordinator.gd"
)
const LowPolyWorldCoordinates3DScript = preload("res://terrain/low_poly_world_coordinates_3d.gd")
const LowPolyArtStyle3DScript = preload("res://terrain/low_poly_art_style_3d.gd")
const RESIDENT_FACTORY := preload("res://characters/resident_factory.gd")
const CHARACTER_MODEL_CATALOG_3D := preload("res://characters/character_model_catalog_3d.gd")
const AUDIO_SETTINGS_SERVICE := preload("res://game/audio_settings_service.gd")

const LANDMARK_MASK_META := &"low_poly_landmark_mask_pixel"
const ISLAND_PATHS_LABEL := "Island Paths"
# Player is treated as "at" a landmark when within this XZ distance of its proxy.
# Sized for the scaled-up world and the large stylized building footprints.
const LANDMARK_LOCATION_RADIUS := 14.0

const LANDMARK_CUE_VOLUME_DB := -4.0
const WEATHER_HOLD_DURATION_MIN := 20.0
const WEATHER_HOLD_DURATION_MAX := 38.0
const WEATHER_TRANSITION_DURATION_MIN := 9.0
const WEATHER_TRANSITION_DURATION_MAX := 18.0

@onready var m_terrain: LowPolyTerrain3D = $LowPolyTerrain3D
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
# Tests may disable only automatic playback while still validating that the
# runtime audio owners and signal wiring are created.
@export var audio_autoplay := true
# Show an on-screen performance overlay (FPS, frame time, draw calls, primitives,
# video memory) for the QA performance-capture gate. Off in normal play.
@export var show_debug_stats := false

var m_coordinates: LowPolyWorldCoordinates3DScript = LowPolyWorldCoordinates3DScript.new()
var m_landmark_nodes: Dictionary = {}
var m_weather_manager: WeatherManager = null
var m_wind_adapter: LowPolyWaterWindAdapter = null
var m_weather_rig_3d: Node3D = null
var m_previous_weather_cycles_enabled := true
var m_weather_cycles_overridden := false
var m_is_ready := false
var m_last_location := ""
var m_resident_root: Node3D = null
var m_stats_label: Label = null
var m_bgm_manager: Node = null
var m_landmark_cue_player: AudioStreamPlayer = null
var m_actor_surface_follower: ActorSurfaceFollowerScript = null
var m_story_interaction_coordinator: StoryInteractionCoordinatorScript = null


func _app_state():
	return APP_RUNTIME.get_app_state(self)


func _ready() -> void:
	_apply_art_style()
	if is_instance_valid(m_camera):
		m_camera.current = true

	_cache_landmarks()
	_configure_world()
	_setup_actor_surface_follower()
	_snap_camera_controller()
	# Resolving AppState / WeatherManager can add service nodes to the current scene,
	# which fails while the scene tree is still instantiating this scene (e.g. when the
	# world is a child of another scene). Defer everything that touches shared services
	# until the tree is unblocked.
	call_deferred("_initialize_runtime")


func _initialize_runtime() -> void:
	if !is_inside_tree():
		return
	_setup_weather_wind()
	_setup_audio()
	_setup_player_appearance()
	if generate_landmark_collision:
		_generate_landmark_collision()
	_spawn_residents()
	_setup_story_interaction_coordinator()
	_apply_story_resume_anchor_if_needed()
	if show_debug_stats:
		_setup_debug_stats()
	m_is_ready = true
	sync_ui_state()


func _exit_tree() -> void:
	if m_wind_adapter != null:
		m_wind_adapter.unbind()
	m_wind_adapter = null
	if is_instance_valid(m_weather_manager):
		m_weather_manager.unregister_weather_targets(self)
	if is_instance_valid(m_weather_manager) and m_weather_cycles_overridden:
		m_weather_manager.cycles_enabled = m_previous_weather_cycles_enabled
	m_weather_cycles_overridden = false
	m_weather_manager = null


func _process(_delta: float) -> void:
	if !m_is_ready:
		return
	_sync_location_from_player()
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
	_sync_location_from_player()


func set_prompt_bgm_ducked(ducked: bool) -> void:
	if !is_instance_valid(m_bgm_manager):
		return
	if m_bgm_manager.has_method("set_ducked"):
		m_bgm_manager.call("set_ducked", ducked)


# --- world setup ----------------------------------------------------------------

func _cache_landmarks() -> void:
	m_landmark_nodes.clear()
	for definition: LandmarkDefinition in LANDMARK_CATALOG_SCRIPT.world_definitions():
		var proxy := get_node_or_null(definition.world_node_path) as Node3D
		if is_instance_valid(proxy):
			m_landmark_nodes[definition.display_name] = proxy


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


func _setup_actor_surface_follower() -> void:
	if is_instance_valid(m_actor_surface_follower):
		return
	m_actor_surface_follower = ActorSurfaceFollowerScript.new() as ActorSurfaceFollowerScript
	m_actor_surface_follower.name = "ActorSurfaceFollower"
	m_actor_surface_follower.terrain_clearance = actor_terrain_clearance
	add_child(m_actor_surface_follower)
	m_actor_surface_follower.configure(m_actor, m_terrain, m_coordinates)
	m_actor_surface_follower.settle_now()


func _place_landmarks(image: Image, profile: TerrainGenerationProfile, land_height: float) -> void:
	if !is_instance_valid(m_landmarks_root):
		return

	for definition: LandmarkDefinition in LANDMARK_CATALOG_SCRIPT.world_definitions():
		var proxy := get_node_or_null(definition.world_node_path) as Node3D
		if !is_instance_valid(proxy):
			continue

		var mask_pixel := m_coordinates.isometric_position_to_mask_pixel(
			definition.isometric_position
		)
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
	m_previous_weather_cycles_enabled = m_weather_manager.cycles_enabled
	m_weather_cycles_overridden = true
	m_weather_manager.cycles_enabled = true
	m_weather_manager.hold_duration_min = WEATHER_HOLD_DURATION_MIN
	m_weather_manager.hold_duration_max = WEATHER_HOLD_DURATION_MAX
	m_weather_manager.transition_duration_min = WEATHER_TRANSITION_DURATION_MIN
	m_weather_manager.transition_duration_max = WEATHER_TRANSITION_DURATION_MAX
	m_weather_rig_3d = WEATHER_RIG_3D_SCRIPT.new()
	m_weather_rig_3d.name = "WeatherRig3D"
	add_child(m_weather_rig_3d)
	m_weather_rig_3d.configure(
		m_actor,
		get_node_or_null("WorldEnvironment") as WorldEnvironment,
		m_sun
	)
	m_weather_manager.register_weather_host(self, {
		"weather_state_target": m_weather_rig_3d,
	})
	m_wind_adapter = WATER_WIND_ADAPTER.new()
	m_wind_adapter.bind(m_weather_manager, m_terrain)


func _setup_audio() -> void:
	_setup_bgm()
	_setup_landmark_audio_feedback()
	var app_state = _app_state()
	if !app_state.landmark_audio_cue_requested.is_connected(_on_landmark_audio_cue_requested):
		app_state.landmark_audio_cue_requested.connect(_on_landmark_audio_cue_requested)
	if !app_state.state_committed.is_connected(_on_state_committed):
		app_state.state_committed.connect(_on_state_committed)


func _setup_bgm() -> void:
	if is_instance_valid(m_bgm_manager):
		return
	m_bgm_manager = BGM_MANAGER_SCRIPT.new()
	m_bgm_manager.name = "BGMManager"
	m_bgm_manager.set("autoplay", audio_autoplay)
	add_child(m_bgm_manager)


func _setup_landmark_audio_feedback() -> void:
	if is_instance_valid(m_landmark_cue_player):
		return
	m_landmark_cue_player = AudioStreamPlayer.new()
	m_landmark_cue_player.name = "LandmarkCuePlayer"
	m_landmark_cue_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(m_landmark_cue_player)
	_apply_prompt_volume()


func _on_landmark_audio_cue_requested(cue_id: String, _context: Dictionary) -> void:
	_play_landmark_audio_cue(cue_id)


func _on_state_committed(changes: AppStateChangeSet) -> void:
	if changes.has_domain(AppStateChangeSet.Domain.SETTINGS):
		_apply_prompt_volume()
	if changes.has_domain(AppStateChangeSet.Domain.PLAYER):
		_apply_player_appearance(_app_state().get_projection().player_profile)


func _apply_prompt_volume() -> void:
	if !is_instance_valid(m_landmark_cue_player):
		return
	var projection := _app_state().get_projection()
	m_landmark_cue_player.volume_db = AUDIO_SETTINGS_SERVICE.new().get_prompt_volume_db(
		projection.prompt_volume_percent,
		LANDMARK_CUE_VOLUME_DB
	)


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
	return LANDMARK_CATALOG_SCRIPT.get_audio_cue(StringName(cue_id))


func _setup_player_appearance() -> void:
	var app_state = _app_state()
	if !app_state.state_committed.is_connected(_on_state_committed):
		app_state.state_committed.connect(_on_state_committed)
	_apply_player_appearance(app_state.get_projection().player_profile)


func _apply_player_appearance(profile: Dictionary) -> void:
	if !is_instance_valid(m_actor):
		return
	m_actor.set("character_model_scene", _resolve_player_model_scene(profile))


func _resolve_player_model_scene(profile: Dictionary) -> PackedScene:
	return CHARACTER_MODEL_CATALOG_3D.resolve_player_model(profile)


func _snap_camera_controller() -> void:
	if !is_instance_valid(m_camera_controller):
		return
	if m_camera_controller.has_method("snap_to_target"):
		m_camera_controller.call("snap_to_target")


# --- AppState integration -------------------------------------------------------

func _apply_story_resume_anchor_if_needed() -> void:
	if !is_instance_valid(m_actor):
		return
	var projection := _app_state().get_projection()
	if projection.mode_id != AppStateSnapshot.MODE_STORY:
		return

	var default_resume_anchor := LANDMARK_CATALOG_SCRIPT.default_resume_display_name()
	var anchor_id: String = projection.story_resume_anchor_id
	if anchor_id.is_empty():
		anchor_id = default_resume_anchor

	var anchor_node := m_landmark_nodes.get(anchor_id) as Node3D
	if !is_instance_valid(anchor_node):
		anchor_node = m_landmark_nodes.get(default_resume_anchor) as Node3D
	if !is_instance_valid(anchor_node):
		return

	var anchor_origin := anchor_node.global_position
	# Drop the actor just in front of the landmark on XZ; the elevation follow seats
	# it onto the surface on the next physics frame.
	m_actor.global_position = Vector3(anchor_origin.x, m_actor.global_position.y, anchor_origin.z + 1.5)
	if is_instance_valid(m_actor_surface_follower):
		m_actor_surface_follower.settle_now()


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
	_app_state().update_world_context({"location": resolved})
	_update_story_resume_checkpoint(resolved)


# While in Story mode, keep the resume checkpoint at the
# last landmark the player reached so Continue restores near where they were. The
# landmark display names double as stable safe-resume anchor ids.
func _update_story_resume_checkpoint(resolved_location: String) -> void:
	if _app_state().get_projection().mode_id != AppStateSnapshot.MODE_STORY:
		return
	if resolved_location.is_empty() or resolved_location == ISLAND_PATHS_LABEL:
		return
	if !m_landmark_nodes.has(resolved_location):
		return
	_app_state().update_resume_checkpoint(resolved_location, resolved_location)


func _flatten(position: Vector3) -> Vector2:
	return Vector2(position.x, position.z)


func _get_terrain_sample_height(sample_cell: Vector2i, fallback: float) -> float:
	if !is_instance_valid(m_terrain):
		return fallback
	return m_terrain.get_sample_cell_height(sample_cell)


# --- terrain mask helpers --------------------------------------------------------

func _resolve_generation_profile() -> TerrainGenerationProfile:
	var terrain_profile: Variant = m_terrain.get("generation_profile")
	var profile := terrain_profile as TerrainGenerationProfile
	if profile == null:
		profile = TerrainGenerationProfile.create_default_profile() as TerrainGenerationProfile
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


# --- resident and interaction component setup -----------------------------------

func _spawn_residents() -> void:
	var factory := RESIDENT_FACTORY.new()
	m_resident_root = factory.spawn_residents(
		self,
		_app_state().get_projection(),
		m_landmark_nodes
	)


func _setup_story_interaction_coordinator() -> void:
	if is_instance_valid(m_story_interaction_coordinator):
		m_story_interaction_coordinator.refresh_subjects()
		return
	var app_state := _app_state() as AppStateService
	if app_state == null:
		return
	m_story_interaction_coordinator = (
		StoryInteractionCoordinatorScript.new() as StoryInteractionCoordinatorScript
	)
	m_story_interaction_coordinator.name = "StoryInteractionCoordinator"
	add_child(m_story_interaction_coordinator)
	m_story_interaction_coordinator.configure(self, m_actor, app_state)


func _generate_landmark_collision() -> void:
	for definition: LandmarkDefinition in LANDMARK_CATALOG_SCRIPT.world_definitions():
		var node := get_node_or_null(definition.world_node_path) as Node3D
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
