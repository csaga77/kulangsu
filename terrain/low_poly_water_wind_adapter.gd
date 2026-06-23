class_name LowPolyWaterWindAdapter
extends RefCounted

## Integration-layer glue that drives low-poly 3D water wind from a weather
## source, keeping LowPolyTerrain3D itself decoupled from the weather system.
##
## It connects to a weather source's `wind_changed(angle_degrees, raw_strength)`
## signal (and/or polls `get_current_wind()`), normalizes the raw weather wind
## strength into 0..1, and calls `terrain.set_wind(angle_degrees, strength_01)`.
## Both ends are duck-typed, so this carries no hard dependency on a concrete
## WeatherManager or terrain class.

var m_terrain: Node = null
var m_source: Node = null
var m_reference_strength := 0.0


## terrain must expose set_wind(angle_degrees, normalized_strength). weather_source
## may expose wind_changed signal, get_current_wind() and
## get_reference_wind_strength(). reference_strength <= 0 means auto-resolve from
## the source (falling back to 1.0). Applies the current wind immediately.
func bind(weather_source: Node, terrain: Node, reference_strength := 0.0) -> void:
	unbind()
	m_source = weather_source
	m_terrain = terrain
	m_reference_strength = reference_strength

	if m_source != null and m_source.has_signal(&"wind_changed"):
		if not m_source.is_connected(&"wind_changed", _on_wind_changed):
			m_source.connect(&"wind_changed", _on_wind_changed)

	apply_now()


func unbind() -> void:
	if m_source != null and is_instance_valid(m_source) and m_source.has_signal(&"wind_changed"):
		if m_source.is_connected(&"wind_changed", _on_wind_changed):
			m_source.disconnect(&"wind_changed", _on_wind_changed)
	m_source = null
	m_terrain = null


## Push the source's current wind to the terrain once (useful right after bind or
## when polling instead of relying on the signal).
func apply_now() -> void:
	if m_source == null or not m_source.has_method(&"get_current_wind"):
		return
	var wind: Dictionary = m_source.get_current_wind()
	_drive(float(wind.get("wind_angle_degrees", 72.0)), float(wind.get("wind_strength", 0.0)))


func _on_wind_changed(wind_angle_degrees: float, wind_strength: float) -> void:
	_drive(wind_angle_degrees, wind_strength)


func _drive(angle_degrees: float, raw_strength: float) -> void:
	if m_terrain == null or not is_instance_valid(m_terrain) or not m_terrain.has_method(&"set_wind"):
		return

	var reference := m_reference_strength
	if reference <= 0.0 and m_source != null and m_source.has_method(&"get_reference_wind_strength"):
		reference = float(m_source.get_reference_wind_strength())
	if reference <= 0.0:
		reference = 1.0

	m_terrain.set_wind(angle_degrees, clampf(raw_strength / reference, 0.0, 1.0))
