class_name WeatherManager
extends Node


class WeatherRig:
	extends RefCounted

	var owner: Node = null
	var weather_state_target: Node = null


## Emitted whenever the live applied wind changes (during transitions or via
## set_registered_wind). Consumers such as the low-poly water can follow this
## without coupling back into the weather system.
signal wind_changed(wind_angle_degrees: float, wind_strength: float)

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

@export var cycles_enabled := true
@export_range(5.0, 120.0, 1.0) var hold_duration_min: float = 20.0
@export_range(5.0, 180.0, 1.0) var hold_duration_max: float = 38.0
@export_range(2.0, 90.0, 1.0) var transition_duration_min: float = 9.0
@export_range(2.0, 120.0, 1.0) var transition_duration_max: float = 18.0

var m_rng := RandomNumberGenerator.new()
var m_target_owner: Node = null
var m_registered_rig: WeatherRig = null
var m_weather_state_target: Node = null
var m_current_weather: Dictionary = {}
var m_source_weather: Dictionary = {}
var m_target_weather: Dictionary = {}
var m_current_preset_id := DEFAULT_PRESET_ID
var m_phase: CyclePhase = CyclePhase.HOLD
var m_phase_elapsed := 0.0
var m_phase_duration := 0.0
var m_applied_wind_angle_degrees := 72.0
var m_applied_wind_strength := 0.0


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
	m_weather_state_target = rig.weather_state_target

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
		"weather_state_target": m_weather_state_target,
	}


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
	if is_instance_valid(m_weather_state_target):
		if m_weather_state_target.has_method("set_weather_visible"):
			m_weather_state_target.call("set_weather_visible", is_visible)
		else:
			m_weather_state_target.visible = is_visible


func unregister_weather_targets(host_owner: Node) -> void:
	if host_owner != null and host_owner != m_target_owner:
		return
	_clear_weather_targets()


func _build_weather_rig(host_owner: Node, host_config: Dictionary) -> WeatherRig:
	var weather_state_target := host_config.get("weather_state_target") as Node

	var rig := WeatherRig.new()
	rig.owner = host_owner
	rig.weather_state_target = weather_state_target

	return rig


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

	if m_registered_rig.weather_state_target != null and not is_instance_valid(m_registered_rig.weather_state_target):
		m_registered_rig.weather_state_target = null

	m_weather_state_target = m_registered_rig.weather_state_target

	if not _has_weather_targets():
		m_target_owner = null
		m_registered_rig = null


func _clear_invalid_node_refs() -> void:
	if m_weather_state_target != null and not is_instance_valid(m_weather_state_target):
		m_weather_state_target = null


func _clear_weather_targets() -> void:
	m_target_owner = null
	m_registered_rig = null
	m_weather_state_target = null


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
	return is_instance_valid(m_weather_state_target)


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

	if is_instance_valid(m_weather_state_target) and m_weather_state_target.has_method("capture_weather_state"):
		weather.merge(m_weather_state_target.call("capture_weather_state"), true)

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

	if is_instance_valid(m_weather_state_target) and m_weather_state_target.has_method("apply_weather"):
		m_weather_state_target.call("apply_weather", weather)

	_apply_synced_wind(wind_angle_degrees, wind_strength)


func _apply_synced_wind(wind_angle_degrees: float, wind_strength: float) -> void:
	if is_instance_valid(m_weather_state_target) and m_weather_state_target.has_method("set_wind"):
		m_weather_state_target.call("set_wind", wind_angle_degrees, wind_strength)

	# Publish the live applied wind so low-poly water can follow the 3D rig.
	if (
		not is_equal_approx(m_applied_wind_angle_degrees, wind_angle_degrees)
		or not is_equal_approx(m_applied_wind_strength, wind_strength)
	):
		m_applied_wind_angle_degrees = wind_angle_degrees
		m_applied_wind_strength = wind_strength
		wind_changed.emit(wind_angle_degrees, wind_strength)


## Live applied wind: { "wind_angle_degrees": float, "wind_strength": float }.
## wind_strength is the raw weather magnitude; normalize with
## get_reference_wind_strength() before driving 0..1 consumers.
func get_current_wind() -> Dictionary:
	return {
		"wind_angle_degrees": m_applied_wind_angle_degrees,
		"wind_strength": m_applied_wind_strength,
	}


## Largest wind_strength across the weather presets, a stable reference for
## normalizing raw wind into 0..1.
func get_reference_wind_strength() -> float:
	var reference := 0.0
	for preset in WEATHER_PRESETS:
		reference = maxf(reference, float(preset.get("wind_strength", 0.0)))
	return maxf(reference, 1.0)


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
