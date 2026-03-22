@tool
class_name FogOverlay
extends Node2D

@export_range(0.0, 1.0, 0.01) var density: float = 0.42:
	set(value):
		density = clampf(value, 0.0, 1.0)
		_update_material()

@export_range(0.1, 1.0, 0.01) var height_ratio: float = 0.56:
	set(value):
		height_ratio = clampf(value, 0.1, 1.0)
		_update_material()

@export_range(0.01, 0.8, 0.01) var softness: float = 0.3:
	set(value):
		softness = clampf(value, 0.01, 0.8)
		_update_material()

@export_range(0.0, 1.0, 0.01) var haze_strength: float = 0.42:
	set(value):
		haze_strength = clampf(value, 0.0, 1.0)
		_update_material()

@export_range(0.0, 1.0, 0.01) var wisp_strength: float = 0.62:
	set(value):
		wisp_strength = clampf(value, 0.0, 1.0)
		_update_material()

@export_range(0.0, 0.6, 0.01) var edge_brightness: float = 0.22:
	set(value):
		edge_brightness = clampf(value, 0.0, 0.6)
		_update_material()

@export_range(0.0, 0.4, 0.005) var drift_speed: float = 0.11:
	set(value):
		drift_speed = clampf(value, 0.0, 0.4)
		_update_material()

@export var wind_angle_degrees: float = 72.0:
	set(value):
		wind_angle_degrees = value
		_update_material()

@export_range(0.0, 900.0, 1.0) var wind_strength: float = 460.0:
	set(value):
		wind_strength = clampf(value, 0.0, 900.0)
		_update_material()

@export var fog_color: Color = Color(0.831373, 0.894118, 0.941176, 0.56):
	set(value):
		fog_color = value
		_update_material()

@export var noise_scale: Vector2 = Vector2(4.2, 2.0):
	set(value):
		noise_scale = Vector2(maxf(value.x, 0.1), maxf(value.y, 0.1))
		_update_material()

@onready var m_fog: ColorRect = $fog
var m_shader_material: ShaderMaterial = null

var m_last_viewport_size := Vector2.ZERO
var m_last_zoom := Vector2.ONE
var m_last_visible_size := Vector2.ZERO
var m_last_screen_space := false
var m_drift_offset := Vector2.ZERO


func _ready() -> void:
	set_process(true)
	if is_instance_valid(m_fog):
		m_shader_material = m_fog.material as ShaderMaterial
	_update_material()
	_update_rect(Vector2(512.0, 512.0))


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return

	var viewport := get_viewport()
	var viewport_size := Vector2(256.0, 256.0)
	var zoom := Vector2.ONE
	var visible_size := viewport_size
	var use_screen_space := _uses_viewport_space()

	if viewport != null:
		viewport_size = Vector2(viewport.size)
		visible_size = viewport_size

	if use_screen_space:
		position = viewport_size * 0.5
	else:
		var camera: Camera2D = null
		if viewport != null:
			camera = viewport.get_camera_2d()
		if viewport != null and camera != null:
			zoom = camera.zoom
			visible_size = viewport_size / zoom
			global_position = camera.global_position

	if (
		viewport_size != m_last_viewport_size
		or zoom != m_last_zoom
		or visible_size != m_last_visible_size
		or use_screen_space != m_last_screen_space
	):
		m_last_viewport_size = viewport_size
		m_last_zoom = zoom
		m_last_visible_size = visible_size
		m_last_screen_space = use_screen_space
		_update_rect(visible_size)

	_advance_drift(delta, visible_size)


func _update_rect(visible_size: Vector2) -> void:
	if not is_instance_valid(m_fog):
		return

	var size := Vector2(maxf(visible_size.x, 1.0), maxf(visible_size.y, 1.0))
	m_fog.position = -size * 0.5
	m_fog.size = size


func _update_material() -> void:
	if m_shader_material == null and is_instance_valid(m_fog):
		m_shader_material = m_fog.material as ShaderMaterial
	if m_shader_material == null:
		return

	m_shader_material.set_shader_parameter("density", density)
	m_shader_material.set_shader_parameter("fog_height", height_ratio)
	m_shader_material.set_shader_parameter("softness", softness)
	m_shader_material.set_shader_parameter("haze_strength", haze_strength)
	m_shader_material.set_shader_parameter("wisp_strength", wisp_strength)
	m_shader_material.set_shader_parameter("edge_brightness", edge_brightness)
	m_shader_material.set_shader_parameter("drift_speed", drift_speed)
	m_shader_material.set_shader_parameter("fog_color", fog_color)
	m_shader_material.set_shader_parameter("noise_scale", noise_scale)
	var wind_direction := _get_wind_direction()
	m_shader_material.set_shader_parameter("wind_direction", wind_direction)
	m_shader_material.set_shader_parameter("wind_strength_factor", clampf(wind_strength / 900.0, 0.0, 1.0))
	m_shader_material.set_shader_parameter("drift_offset", m_drift_offset)


func _advance_drift(delta: float, visible_size: Vector2) -> void:
	if m_shader_material == null:
		return

	var width := maxf(visible_size.x, 1.0)
	var height := maxf(visible_size.y, 1.0)
	var strength_factor := clampf(wind_strength / 900.0, 0.0, 1.0)
	var pixels_per_second := drift_speed * lerpf(180.0, 1320.0, strength_factor)
	var wind_direction := _get_wind_direction()
	var uv_velocity := Vector2(
		wind_direction.x * pixels_per_second / width,
		wind_direction.y * pixels_per_second / height
	)
	m_drift_offset += uv_velocity * delta
	m_drift_offset.x = wrapf(m_drift_offset.x, -8.0, 8.0)
	m_drift_offset.y = wrapf(m_drift_offset.y, -8.0, 8.0)
	m_shader_material.set_shader_parameter("drift_offset", m_drift_offset)


func _get_wind_direction() -> Vector2:
	var wind_direction := Vector2.RIGHT.rotated(deg_to_rad(wind_angle_degrees))
	if wind_direction.length_squared() <= 0.0001:
		return Vector2.RIGHT
	return wind_direction.normalized()


func _uses_viewport_space() -> bool:
	var node: Node = self
	while node != null:
		if node is CanvasLayer:
			return true
		node = node.get_parent()
	return false
