@tool
class_name CloudShadowOverlay
extends Node2D

@export var enabled := true:
	set(value):
		enabled = value
		_sync_enabled_state()

@export var shadow_color: Color = Color(0.74, 0.78, 0.82, 0.68):
	set(value):
		shadow_color = value
		_update_material()

@export_range(0.0, 3.0, 0.01) var shadow_strength: float = 1.84:
	set(value):
		shadow_strength = clampf(value, 0.0, 3.0)
		_update_material()

@export_range(0.0, 1.0, 0.01) var coverage: float = 0.43:
	set(value):
		coverage = clampf(value, 0.0, 1.0)
		_update_material()

@export_range(0.01, 0.4, 0.01) var softness: float = 0.24:
	set(value):
		softness = clampf(value, 0.01, 0.4)
		_update_material()

@export var noise_scale: Vector2 = Vector2(0.00105, 0.00082):
	set(value):
		noise_scale = Vector2(maxf(value.x, 0.00001), maxf(value.y, 0.00001))
		_update_material()

@export var detail_scale: Vector2 = Vector2(0.00195, 0.00148):
	set(value):
		detail_scale = Vector2(maxf(value.x, 0.00001), maxf(value.y, 0.00001))
		_update_material()

@export_range(0.5, 4.0, 0.05) var cloud_size: float = 1.0:
	set(value):
		cloud_size = clampf(value, 0.5, 4.0)
		_update_material()

@export_range(1.0, 2.0, 0.05) var coverage_scale: float = 1.2:
	set(value):
		coverage_scale = clampf(value, 1.0, 2.0)
		_update_rect(m_last_visible_size)

@export_range(0.0, 0.2, 0.005) var drift_speed: float = 0.06:
	set(value):
		drift_speed = clampf(value, 0.0, 0.2)
		_update_material()

@export_range(0.0, 6.0, 0.05) var speed_gain: float = 1.0:
	set(value):
		speed_gain = clampf(value, 0.0, 6.0)
		_update_material()

@export var wind_angle_degrees: float = 72.0:
	set(value):
		wind_angle_degrees = value
		_update_material()

@export_range(0.0, 900.0, 1.0) var wind_strength: float = 460.0:
	set(value):
		wind_strength = clampf(value, 0.0, 900.0)
		_update_material()

@onready var m_shadow_rect: ColorRect = $shadow
var m_shader_material: ShaderMaterial = null
var m_last_visible_size := Vector2(1024.0, 768.0)
var m_last_zoom := Vector2.ONE
var m_drift_offset := Vector2.ZERO


func _ready() -> void:
	set_process(true)
	if is_instance_valid(m_shadow_rect):
		m_shader_material = m_shadow_rect.material as ShaderMaterial
	_sync_enabled_state()
	_update_material()
	_update_rect(m_last_visible_size)


func _process(delta: float) -> void:
	if not is_visible_in_tree() or not enabled:
		return

	var viewport := get_viewport()
	if viewport == null:
		return

	var camera := viewport.get_camera_2d()
	if camera == null:
		return

	var visible_size := Vector2(viewport.size) / camera.zoom
	var should_sync_transform := not Engine.is_editor_hint()
	if should_sync_transform:
		global_position = camera.global_position

	if visible_size != m_last_visible_size or camera.zoom != m_last_zoom:
		m_last_visible_size = visible_size
		m_last_zoom = camera.zoom
		_update_rect(visible_size)

	_sync_world_origin()
	_advance_drift(delta)


func _update_rect(visible_size: Vector2) -> void:
	if not is_instance_valid(m_shadow_rect):
		return

	var size := Vector2(
		maxf(visible_size.x * coverage_scale, 1.0),
		maxf(visible_size.y * coverage_scale, 1.0)
	)
	m_shadow_rect.position = -size * 0.5
	m_shadow_rect.size = size

	if m_shader_material != null:
		m_shader_material.set_shader_parameter("visible_world_size", size)


func _update_material() -> void:
	if m_shader_material == null and is_instance_valid(m_shadow_rect):
		m_shader_material = m_shadow_rect.material as ShaderMaterial
	if m_shader_material == null:
		return

	m_shader_material.set_shader_parameter("shadow_color", shadow_color)
	m_shader_material.set_shader_parameter("shadow_strength", shadow_strength)
	m_shader_material.set_shader_parameter("coverage", coverage)
	m_shader_material.set_shader_parameter("softness", softness)
	m_shader_material.set_shader_parameter("noise_scale", _get_effective_cloud_scale(noise_scale))
	m_shader_material.set_shader_parameter("detail_scale", _get_effective_cloud_scale(detail_scale))
	m_shader_material.set_shader_parameter("drift_speed", drift_speed)
	m_shader_material.set_shader_parameter("speed_gain", speed_gain)
	m_shader_material.set_shader_parameter("wind_direction", _get_wind_direction())
	m_shader_material.set_shader_parameter("wind_strength_factor", clampf(wind_strength / 900.0, 0.0, 1.0))
	m_shader_material.set_shader_parameter("drift_offset", m_drift_offset)
	_sync_world_origin()


func _sync_world_origin() -> void:
	if m_shader_material == null:
		return

	var rect_size := Vector2(
		maxf(m_last_visible_size.x * coverage_scale, 1.0),
		maxf(m_last_visible_size.y * coverage_scale, 1.0)
	)
	m_shader_material.set_shader_parameter("world_origin", global_position - rect_size * 0.5)
	m_shader_material.set_shader_parameter("visible_world_size", rect_size)


func _advance_drift(delta: float) -> void:
	if m_shader_material == null:
		return

	var pixels_per_second := drift_speed * speed_gain * wind_strength
	m_drift_offset += _get_wind_direction() * pixels_per_second * delta
	m_drift_offset.x = wrapf(m_drift_offset.x, -8192.0, 8192.0)
	m_drift_offset.y = wrapf(m_drift_offset.y, -8192.0, 8192.0)
	m_shader_material.set_shader_parameter("drift_offset", m_drift_offset)


func _get_wind_direction() -> Vector2:
	var wind_direction := Vector2.RIGHT.rotated(deg_to_rad(wind_angle_degrees))
	if wind_direction.length_squared() <= 0.0001:
		return Vector2.RIGHT
	return wind_direction.normalized()


func _get_effective_cloud_scale(base_scale: Vector2) -> Vector2:
	return base_scale / maxf(cloud_size, 0.001)


func _sync_enabled_state() -> void:
	if is_instance_valid(m_shadow_rect):
		m_shadow_rect.visible = enabled
