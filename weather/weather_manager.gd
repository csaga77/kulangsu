class_name WeatherManager
extends Node


class WeatherRig:
	extends RefCounted

	var owner: Node = null
	var weather_layer: CanvasLayer = null
	var rain_overlay: RainOverlay = null
	var fog_overlay: FogOverlay = null
	var cloud_shadow_overlay: CloudShadowOverlay = null
	var ground_impacts: RainGroundImpacts = null


enum CyclePhase {
	HOLD,
	TRANSITION,
}

const DEFAULT_PRESET_ID := "scene_default"
const WEATHER_LAYER_NAME := "WeatherLayer"
const RAIN_OVERLAY_NAME := "RainOverlay"
const FOG_OVERLAY_NAME := "FogOverlay"
const CLOUD_SHADOW_NAME := "CloudShadows"
const GROUND_IMPACTS_NAME := "GroundImpacts"
const RAIN_OVERLAY_SCENE := preload("res://weather/rain_overlay.tscn")
const FOG_OVERLAY_SCENE := preload("res://weather/fog_overlay.tscn")
const CLOUD_SHADOW_SCENE := preload("res://weather/cloud_shadow_overlay.tscn")
const GROUND_IMPACTS_SCRIPT := preload("res://weather/rain_ground_impacts.gd")
const WEATHER_PRESETS: Array[Dictionary] = [
	{
		"id": "harbor_haze",
		"weight": 1.3,
		"rain_density": 0.0,
		"fog_density": 0.18,
		"fog_height_ratio": 0.5,
		"fog_drift_speed": 0.045,
		"wind_angle_degrees": 58.0,
		"wind_strength": 140.0,
		"drop_speed": 220.0,
		"drop_size": 0.09,
	},
	{
		"id": "misty_breeze",
		"weight": 1.1,
		"rain_density": 0.00018,
		"fog_density": 0.34,
		"fog_height_ratio": 0.62,
		"fog_drift_speed": 0.07,
		"wind_angle_degrees": 66.0,
		"wind_strength": 210.0,
		"drop_speed": 235.0,
		"drop_size": 0.095,
	},
	{
		"id": "light_rain",
		"weight": 1.0,
		"rain_density": 0.00055,
		"fog_density": 0.28,
		"fog_height_ratio": 0.54,
		"fog_drift_speed": 0.085,
		"wind_angle_degrees": 72.0,
		"wind_strength": 300.0,
		"drop_speed": 245.0,
		"drop_size": 0.1,
	},
	{
		"id": "steady_rain",
		"weight": 0.95,
		"rain_density": 0.0012,
		"fog_density": 0.42,
		"fog_height_ratio": 0.58,
		"fog_drift_speed": 0.11,
		"wind_angle_degrees": 72.0,
		"wind_strength": 460.0,
		"drop_speed": 250.0,
		"drop_size": 0.1,
	},
	{
		"id": "gusty_shower",
		"weight": 0.55,
		"rain_density": 0.00165,
		"fog_density": 0.36,
		"fog_height_ratio": 0.6,
		"fog_drift_speed": 0.14,
		"wind_angle_degrees": 62.0,
		"wind_strength": 620.0,
		"drop_speed": 310.0,
		"drop_size": 0.115,
	},
]

@export var cycles_enabled := true
@export_range(5.0, 120.0, 1.0) var hold_duration_min: float = 20.0
@export_range(5.0, 180.0, 1.0) var hold_duration_max: float = 38.0
@export_range(2.0, 90.0, 1.0) var transition_duration_min: float = 9.0
@export_range(2.0, 120.0, 1.0) var transition_duration_max: float = 18.0

var m_rng := RandomNumberGenerator.new()
var m_target_owner: Node = null
var m_registered_rig: WeatherRig = null
var m_rain_overlay: RainOverlay = null
var m_fog_overlay: FogOverlay = null
var m_cloud_shadow_overlay: CloudShadowOverlay = null
var m_ground_impacts: RainGroundImpacts = null
var m_weather_layer: CanvasLayer = null
var m_sync_rain_with_wind := true
var m_sync_fog_with_wind := true
var m_sync_cloud_with_wind := true
var m_current_weather: Dictionary = {}
var m_source_weather: Dictionary = {}
var m_target_weather: Dictionary = {}
var m_current_preset_id := DEFAULT_PRESET_ID
var m_phase: CyclePhase = CyclePhase.HOLD
var m_phase_elapsed := 0.0
var m_phase_duration := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if Engine.is_editor_hint():
		set_process(false)
		return

	m_rng.randomize()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not cycles_enabled:
		return

	_resolve_weather_targets()
	if not _try_initialize_weather_state():
		return

	m_phase_elapsed += delta
	if m_phase == CyclePhase.HOLD:
		if m_phase_elapsed >= m_phase_duration:
			_begin_random_transition()
		return

	var progress := clampf(m_phase_elapsed / maxf(m_phase_duration, 0.001), 0.0, 1.0)
	var eased_progress := progress * progress * (3.0 - 2.0 * progress)
	_apply_weather(_interpolate_weather(m_source_weather, m_target_weather, eased_progress))
	if progress >= 1.0:
		m_current_weather = m_target_weather.duplicate(true)
		m_current_preset_id = String(m_current_weather.get("id", DEFAULT_PRESET_ID))
		_schedule_hold()


func register_weather_host(host_owner: Node, host_config: Dictionary = {}) -> Dictionary:
	if host_owner == null:
		return {}

	if m_target_owner != null and host_owner != m_target_owner:
		_clear_weather_targets()

	_clear_weather_targets()

	var rig := _build_weather_rig(host_owner, host_config)
	if rig == null:
		return {}

	m_target_owner = host_owner
	m_registered_rig = rig
	m_weather_layer = rig.weather_layer
	m_rain_overlay = rig.rain_overlay
	m_fog_overlay = rig.fog_overlay
	m_cloud_shadow_overlay = rig.cloud_shadow_overlay
	m_ground_impacts = rig.ground_impacts
	m_sync_rain_with_wind = bool(host_config.get("sync_rain_with_wind", true))
	m_sync_fog_with_wind = bool(host_config.get("sync_fog_with_wind", true))
	m_sync_cloud_with_wind = bool(host_config.get("sync_cloud_with_wind", true))

	if m_current_weather.is_empty():
		if _try_initialize_weather_state():
			_apply_weather(m_current_weather)
	else:
		_apply_weather(m_current_weather)

	return get_registered_weather_nodes(host_owner)


func get_registered_weather_nodes(host_owner: Node = null) -> Dictionary:
	if host_owner != null and host_owner != m_target_owner:
		return {}
	_resolve_weather_targets()
	return {
		"weather_layer": m_weather_layer,
		"rain_overlay": m_rain_overlay,
		"fog_overlay": m_fog_overlay,
		"cloud_shadow_overlay": m_cloud_shadow_overlay,
		"ground_impacts": m_ground_impacts,
	}


func set_target_sync(sync_rain_with_wind: bool, sync_fog_with_wind: bool, sync_cloud_with_wind: bool) -> void:
	m_sync_rain_with_wind = sync_rain_with_wind
	m_sync_fog_with_wind = sync_fog_with_wind
	m_sync_cloud_with_wind = sync_cloud_with_wind

	var wind_state := _get_registered_wind_state()
	_apply_synced_wind(
		float(wind_state.get("wind_angle_degrees", 72.0)),
		float(wind_state.get("wind_strength", 0.0))
	)


func set_registered_wind(wind_angle_degrees: float, wind_strength: float) -> void:
	if m_current_weather.is_empty():
		m_current_weather = _capture_current_weather()
	if m_current_weather.is_empty():
		m_current_weather = {"id": DEFAULT_PRESET_ID}

	m_current_weather["wind_angle_degrees"] = wrapf(wind_angle_degrees, 0.0, 360.0)
	m_current_weather["wind_strength"] = maxf(wind_strength, 0.0)
	_apply_synced_wind(
		float(m_current_weather.get("wind_angle_degrees", 72.0)),
		float(m_current_weather.get("wind_strength", 0.0))
	)


func set_registered_visibility(is_visible: bool) -> void:
	_resolve_weather_targets()
	if is_instance_valid(m_weather_layer):
		m_weather_layer.visible = is_visible
	if is_instance_valid(m_cloud_shadow_overlay):
		m_cloud_shadow_overlay.visible = is_visible
	if is_instance_valid(m_ground_impacts):
		if not is_visible:
			m_ground_impacts.clear_impacts()
		m_ground_impacts.visible = is_visible


func unregister_weather_targets(host_owner: Node) -> void:
	if host_owner != null and host_owner != m_target_owner:
		return
	_clear_weather_targets()


func _build_weather_rig(host_owner: Node, host_config: Dictionary) -> WeatherRig:
	var overlay_parent := host_config.get("overlay_parent") as Node
	var cloud_parent := host_config.get("cloud_parent") as Node
	var impacts_parent := host_config.get("impacts_parent") as Node
	var spawn_layer := host_config.get("spawn_layer") as TileMapLayer
	var overlay_layer := int(host_config.get("overlay_layer", 2))
	var cloud_z_index := int(host_config.get("cloud_z_index", 0))
	var impacts_z_index := int(host_config.get("impacts_z_index", 0))
	var rain_properties: Dictionary = host_config.get("rain_properties", {})
	var fog_properties: Dictionary = host_config.get("fog_properties", {})
	var cloud_properties: Dictionary = host_config.get("cloud_properties", {})
	var impact_properties: Dictionary = host_config.get("impact_properties", {})

	var rig := WeatherRig.new()
	rig.owner = host_owner

	if is_instance_valid(overlay_parent):
		rig.weather_layer = CanvasLayer.new()
		rig.weather_layer.name = WEATHER_LAYER_NAME
		rig.weather_layer.layer = overlay_layer
		overlay_parent.add_child(rig.weather_layer)

		rig.fog_overlay = FOG_OVERLAY_SCENE.instantiate() as FogOverlay
		rig.fog_overlay.name = FOG_OVERLAY_NAME
		rig.weather_layer.add_child(rig.fog_overlay)
		_apply_node_properties(rig.fog_overlay, fog_properties)

		rig.rain_overlay = RAIN_OVERLAY_SCENE.instantiate() as RainOverlay
		rig.rain_overlay.name = RAIN_OVERLAY_NAME
		rig.weather_layer.add_child(rig.rain_overlay)
		_apply_node_properties(rig.rain_overlay, rain_properties)

	if is_instance_valid(cloud_parent):
		rig.cloud_shadow_overlay = CLOUD_SHADOW_SCENE.instantiate() as CloudShadowOverlay
		rig.cloud_shadow_overlay.name = CLOUD_SHADOW_NAME
		rig.cloud_shadow_overlay.z_index = cloud_z_index
		cloud_parent.add_child(rig.cloud_shadow_overlay)
		_apply_node_properties(rig.cloud_shadow_overlay, cloud_properties)

	if is_instance_valid(impacts_parent):
		rig.ground_impacts = GROUND_IMPACTS_SCRIPT.new() as RainGroundImpacts
		rig.ground_impacts.name = GROUND_IMPACTS_NAME
		rig.ground_impacts.z_index = impacts_z_index
		impacts_parent.add_child(rig.ground_impacts)
		_apply_node_properties(rig.ground_impacts, impact_properties)
		rig.ground_impacts.set_rain_overlay(rig.rain_overlay)
		rig.ground_impacts.set_spawn_layer(spawn_layer)

	return rig


func _apply_node_properties(node: Object, properties: Dictionary) -> void:
	if node == null:
		return
	for property_name in properties.keys():
		node.set(StringName(property_name), properties[property_name])


func _resolve_weather_targets() -> void:
	if m_target_owner != null and not is_instance_valid(m_target_owner):
		_clear_weather_targets()
		return

	if m_registered_rig == null:
		_clear_invalid_node_refs()
		return

	if m_registered_rig.owner != null and not is_instance_valid(m_registered_rig.owner):
		_clear_weather_targets()
		return

	if m_registered_rig.weather_layer != null and not is_instance_valid(m_registered_rig.weather_layer):
		m_registered_rig.weather_layer = null
	if m_registered_rig.rain_overlay != null and not is_instance_valid(m_registered_rig.rain_overlay):
		m_registered_rig.rain_overlay = null
	if m_registered_rig.fog_overlay != null and not is_instance_valid(m_registered_rig.fog_overlay):
		m_registered_rig.fog_overlay = null
	if m_registered_rig.cloud_shadow_overlay != null and not is_instance_valid(m_registered_rig.cloud_shadow_overlay):
		m_registered_rig.cloud_shadow_overlay = null
	if m_registered_rig.ground_impacts != null and not is_instance_valid(m_registered_rig.ground_impacts):
		m_registered_rig.ground_impacts = null

	m_weather_layer = m_registered_rig.weather_layer
	m_rain_overlay = m_registered_rig.rain_overlay
	m_fog_overlay = m_registered_rig.fog_overlay
	m_cloud_shadow_overlay = m_registered_rig.cloud_shadow_overlay
	m_ground_impacts = m_registered_rig.ground_impacts

	if not _has_weather_targets():
		m_target_owner = null
		m_registered_rig = null


func _clear_invalid_node_refs() -> void:
	if m_weather_layer != null and not is_instance_valid(m_weather_layer):
		m_weather_layer = null
	if m_rain_overlay != null and not is_instance_valid(m_rain_overlay):
		m_rain_overlay = null
	if m_fog_overlay != null and not is_instance_valid(m_fog_overlay):
		m_fog_overlay = null
	if m_cloud_shadow_overlay != null and not is_instance_valid(m_cloud_shadow_overlay):
		m_cloud_shadow_overlay = null
	if m_ground_impacts != null and not is_instance_valid(m_ground_impacts):
		m_ground_impacts = null


func _clear_weather_targets() -> void:
	if m_registered_rig != null:
		_free_rig_node(m_registered_rig.ground_impacts)
		_free_rig_node(m_registered_rig.cloud_shadow_overlay)
		_free_rig_node(m_registered_rig.weather_layer)

	m_target_owner = null
	m_registered_rig = null
	m_weather_layer = null
	m_rain_overlay = null
	m_fog_overlay = null
	m_cloud_shadow_overlay = null
	m_ground_impacts = null


func _free_rig_node(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.queue_free()


func _try_initialize_weather_state() -> bool:
	if not _has_weather_targets():
		return false
	if not m_current_weather.is_empty():
		return true

	m_current_weather = _capture_current_weather()
	if m_current_weather.is_empty():
		return false

	m_current_preset_id = String(m_current_weather.get("id", DEFAULT_PRESET_ID))
	_schedule_hold()
	return true


func _has_weather_targets() -> bool:
	return (
		is_instance_valid(m_rain_overlay)
		or is_instance_valid(m_fog_overlay)
		or is_instance_valid(m_cloud_shadow_overlay)
		or is_instance_valid(m_ground_impacts)
	)


func _capture_current_weather() -> Dictionary:
	var weather := {
		"id": DEFAULT_PRESET_ID,
		"rain_density": 0.0,
		"fog_density": 0.0,
		"fog_height_ratio": 0.56,
		"fog_drift_speed": 0.11,
		"wind_angle_degrees": 72.0,
		"wind_strength": 0.0,
		"drop_speed": 250.0,
		"drop_size": 0.1,
	}

	if is_instance_valid(m_rain_overlay):
		weather["rain_density"] = m_rain_overlay.density
		weather["drop_speed"] = m_rain_overlay.drop_speed
		weather["drop_size"] = m_rain_overlay.drop_size
		if not is_instance_valid(m_fog_overlay) and not is_instance_valid(m_cloud_shadow_overlay):
			weather["wind_angle_degrees"] = m_rain_overlay.wind_angle_degrees
			weather["wind_strength"] = m_rain_overlay.wind_strength

	if is_instance_valid(m_fog_overlay):
		weather["fog_density"] = m_fog_overlay.density
		weather["fog_height_ratio"] = m_fog_overlay.height_ratio
		weather["fog_drift_speed"] = m_fog_overlay.drift_speed
		weather["wind_angle_degrees"] = m_fog_overlay.wind_angle_degrees
		weather["wind_strength"] = m_fog_overlay.wind_strength

	if is_instance_valid(m_cloud_shadow_overlay) and not is_instance_valid(m_fog_overlay):
		weather["wind_angle_degrees"] = m_cloud_shadow_overlay.wind_angle_degrees
		weather["wind_strength"] = m_cloud_shadow_overlay.wind_strength

	return weather


func _schedule_hold() -> void:
	m_phase = CyclePhase.HOLD
	m_phase_elapsed = 0.0
	m_phase_duration = _random_duration(hold_duration_min, hold_duration_max)


func _begin_random_transition() -> void:
	var next_weather := _choose_next_weather()
	if next_weather.is_empty():
		_schedule_hold()
		return

	m_source_weather = m_current_weather.duplicate(true)
	m_target_weather = next_weather
	m_phase = CyclePhase.TRANSITION
	m_phase_elapsed = 0.0
	m_phase_duration = _random_duration(transition_duration_min, transition_duration_max)


func _choose_next_weather() -> Dictionary:
	var total_weight := 0.0
	for preset in WEATHER_PRESETS:
		if String(preset.get("id", "")) == m_current_preset_id:
			continue
		total_weight += maxf(float(preset.get("weight", 1.0)), 0.0)

	if total_weight <= 0.0:
		return {}

	var roll := m_rng.randf() * total_weight
	var running_weight := 0.0
	for preset in WEATHER_PRESETS:
		if String(preset.get("id", "")) == m_current_preset_id:
			continue
		running_weight += maxf(float(preset.get("weight", 1.0)), 0.0)
		if roll <= running_weight:
			return preset.duplicate(true)

	return WEATHER_PRESETS[0].duplicate(true)


func _interpolate_weather(from_weather: Dictionary, to_weather: Dictionary, t: float) -> Dictionary:
	var safe_t := clampf(t, 0.0, 1.0)
	return {
		"id": String(to_weather.get("id", String(from_weather.get("id", DEFAULT_PRESET_ID)))),
		"rain_density": lerpf(
			float(from_weather.get("rain_density", 0.0)),
			float(to_weather.get("rain_density", 0.0)),
			safe_t
		),
		"fog_density": lerpf(
			float(from_weather.get("fog_density", 0.0)),
			float(to_weather.get("fog_density", 0.0)),
			safe_t
		),
		"fog_height_ratio": lerpf(
			float(from_weather.get("fog_height_ratio", 0.56)),
			float(to_weather.get("fog_height_ratio", 0.56)),
			safe_t
		),
		"fog_drift_speed": lerpf(
			float(from_weather.get("fog_drift_speed", 0.11)),
			float(to_weather.get("fog_drift_speed", 0.11)),
			safe_t
		),
		"wind_angle_degrees": rad_to_deg(
			lerp_angle(
				deg_to_rad(float(from_weather.get("wind_angle_degrees", 72.0))),
				deg_to_rad(float(to_weather.get("wind_angle_degrees", 72.0))),
				safe_t
			)
		),
		"wind_strength": lerpf(
			float(from_weather.get("wind_strength", 0.0)),
			float(to_weather.get("wind_strength", 0.0)),
			safe_t
		),
		"drop_speed": lerpf(
			float(from_weather.get("drop_speed", 250.0)),
			float(to_weather.get("drop_speed", 250.0)),
			safe_t
		),
		"drop_size": lerpf(
			float(from_weather.get("drop_size", 0.1)),
			float(to_weather.get("drop_size", 0.1)),
			safe_t
		),
	}


func _apply_weather(weather: Dictionary) -> void:
	var wind_angle_degrees := float(weather.get("wind_angle_degrees", 72.0))
	var wind_strength := float(weather.get("wind_strength", 0.0))

	if is_instance_valid(m_rain_overlay):
		m_rain_overlay.density = float(weather.get("rain_density", m_rain_overlay.density))
		m_rain_overlay.drop_speed = float(weather.get("drop_speed", m_rain_overlay.drop_speed))
		m_rain_overlay.drop_size = float(weather.get("drop_size", m_rain_overlay.drop_size))

	if is_instance_valid(m_fog_overlay):
		m_fog_overlay.density = float(weather.get("fog_density", m_fog_overlay.density))
		m_fog_overlay.height_ratio = float(weather.get("fog_height_ratio", m_fog_overlay.height_ratio))
		m_fog_overlay.drift_speed = float(weather.get("fog_drift_speed", m_fog_overlay.drift_speed))

	_apply_synced_wind(wind_angle_degrees, wind_strength)


func _apply_synced_wind(wind_angle_degrees: float, wind_strength: float) -> void:
	if is_instance_valid(m_rain_overlay) and m_sync_rain_with_wind:
		m_rain_overlay.wind_angle_degrees = wind_angle_degrees
		m_rain_overlay.wind_strength = wind_strength

	if is_instance_valid(m_fog_overlay) and m_sync_fog_with_wind:
		m_fog_overlay.wind_angle_degrees = wind_angle_degrees
		m_fog_overlay.wind_strength = wind_strength

	if is_instance_valid(m_cloud_shadow_overlay) and m_sync_cloud_with_wind:
		m_cloud_shadow_overlay.wind_angle_degrees = wind_angle_degrees
		m_cloud_shadow_overlay.wind_strength = wind_strength


func _get_registered_wind_state() -> Dictionary:
	if not m_current_weather.is_empty():
		return {
			"wind_angle_degrees": float(m_current_weather.get("wind_angle_degrees", 72.0)),
			"wind_strength": float(m_current_weather.get("wind_strength", 0.0)),
		}

	var captured_weather := _capture_current_weather()
	if captured_weather.is_empty():
		return {
			"wind_angle_degrees": 72.0,
			"wind_strength": 0.0,
		}

	return {
		"wind_angle_degrees": float(captured_weather.get("wind_angle_degrees", 72.0)),
		"wind_strength": float(captured_weather.get("wind_strength", 0.0)),
	}


func _random_duration(min_value: float, max_value: float) -> float:
	var safe_min := minf(min_value, max_value)
	var safe_max := maxf(min_value, max_value)
	if is_equal_approx(safe_min, safe_max):
		return safe_min
	return m_rng.randf_range(safe_min, safe_max)
