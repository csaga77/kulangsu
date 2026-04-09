class_name WeatherCycleController
extends Node

enum CyclePhase {
	HOLD,
	TRANSITION,
}

const DEFAULT_PRESET_ID := "scene_default"
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

@export var rain_overlay_path: NodePath
@export var fog_overlay_path: NodePath
@export var cloud_shadow_overlay_path: NodePath

@export var cycles_enabled := true
@export_range(5.0, 120.0, 1.0) var hold_duration_min: float = 18.0
@export_range(5.0, 180.0, 1.0) var hold_duration_max: float = 34.0
@export_range(2.0, 90.0, 1.0) var transition_duration_min: float = 8.0
@export_range(2.0, 120.0, 1.0) var transition_duration_max: float = 16.0

var m_rng := RandomNumberGenerator.new()
var m_rain_overlay: RainOverlay = null
var m_fog_overlay: FogOverlay = null
var m_cloud_shadow_overlay: Node = null
var m_current_weather: Dictionary = {}
var m_source_weather: Dictionary = {}
var m_target_weather: Dictionary = {}
var m_current_preset_id := DEFAULT_PRESET_ID
var m_phase: CyclePhase = CyclePhase.HOLD
var m_phase_elapsed := 0.0
var m_phase_duration := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return

	m_rng.randomize()
	_resolve_weather_nodes()
	_try_initialize_weather_state()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not cycles_enabled:
		return

	_resolve_weather_nodes()
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


func _resolve_weather_nodes() -> void:
	var next_rain_overlay: RainOverlay = null
	if has_node(rain_overlay_path):
		next_rain_overlay = get_node(rain_overlay_path) as RainOverlay
	m_rain_overlay = next_rain_overlay

	var next_fog_overlay: FogOverlay = null
	if has_node(fog_overlay_path):
		next_fog_overlay = get_node(fog_overlay_path) as FogOverlay
	m_fog_overlay = next_fog_overlay

	var next_cloud_shadow_overlay: Node = null
	if has_node(cloud_shadow_overlay_path):
		next_cloud_shadow_overlay = get_node(cloud_shadow_overlay_path)
	m_cloud_shadow_overlay = next_cloud_shadow_overlay


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
		weather["wind_angle_degrees"] = m_rain_overlay.wind_angle_degrees
		weather["wind_strength"] = m_rain_overlay.wind_strength
		weather["drop_speed"] = m_rain_overlay.drop_speed
		weather["drop_size"] = m_rain_overlay.drop_size

	if is_instance_valid(m_fog_overlay):
		weather["fog_density"] = m_fog_overlay.density
		weather["fog_height_ratio"] = m_fog_overlay.height_ratio
		weather["fog_drift_speed"] = m_fog_overlay.drift_speed
		if not is_instance_valid(m_rain_overlay):
			weather["wind_angle_degrees"] = m_fog_overlay.wind_angle_degrees
			weather["wind_strength"] = m_fog_overlay.wind_strength

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
		m_rain_overlay.wind_angle_degrees = wind_angle_degrees
		m_rain_overlay.wind_strength = wind_strength
		m_rain_overlay.drop_speed = float(weather.get("drop_speed", m_rain_overlay.drop_speed))
		m_rain_overlay.drop_size = float(weather.get("drop_size", m_rain_overlay.drop_size))

	if is_instance_valid(m_fog_overlay):
		m_fog_overlay.density = float(weather.get("fog_density", m_fog_overlay.density))
		m_fog_overlay.height_ratio = float(weather.get("fog_height_ratio", m_fog_overlay.height_ratio))
		m_fog_overlay.drift_speed = float(weather.get("fog_drift_speed", m_fog_overlay.drift_speed))
		m_fog_overlay.wind_angle_degrees = wind_angle_degrees
		m_fog_overlay.wind_strength = wind_strength

	if is_instance_valid(m_cloud_shadow_overlay):
		m_cloud_shadow_overlay.wind_angle_degrees = wind_angle_degrees
		m_cloud_shadow_overlay.wind_strength = wind_strength


func _random_duration(min_value: float, max_value: float) -> float:
	var safe_min := minf(min_value, max_value)
	var safe_max := maxf(min_value, max_value)
	if is_equal_approx(safe_min, safe_max):
		return safe_min
	return m_rng.randf_range(safe_min, safe_max)
