@tool
class_name RainOverlay
extends Node2D

@export var density: float = 0.002:
	set(v):
		density = max(v, 0.0)
		_update_density()

@export var max_particles: int = 12000:
	set(v):
		max_particles = maxi(v, 0)
		_update_density()

@export var direction_randomness_degrees: float = 6.0:
	set(v):
		direction_randomness_degrees = max(v, 0.0)
		_update_direction_randomness()

# Wind control
@export var wind_angle_degrees: float = 90.0:
	set(v):
		wind_angle_degrees = v
		_update_wind()

@export var wind_strength: float = 400.0:
	set(v):
		wind_strength = max(v, 0.0)
		_update_wind()

# Size
@export var drop_size: float = 0.1:
	set(v):
		drop_size = max(v, 0.0001)
		_update_drop_size()

@export var size_randomness: float = 0.3:
	set(v):
		size_randomness = clamp(v, 0.0, 1.0)
		_update_drop_size()

# Speed
@export var drop_speed: float = 250.0:
	set(v):
		drop_speed = max(v, 0.0)
		_update_speed()

@export var speed_randomness: float = 0.2:
	set(v):
		speed_randomness = clamp(v, 0.0, 1.0)
		_update_speed()

# Lifetime
@export var drop_lifetime: float = 1.2:
	set(v):
		drop_lifetime = max(v, 0.01)
		_update_lifetime()

@export var lifetime_randomness: float = 0.2:
	set(v):
		lifetime_randomness = clamp(v, 0.0, 1.0)
		_update_lifetime()


@onready var m_rain: GPUParticles2D = $particles
var m_rain_particle_process_material: ParticleProcessMaterial

var m_last_viewport_size: Vector2 = Vector2.ZERO
var m_last_zoom: Vector2 = Vector2.ONE
var m_last_extents: Vector2 = Vector2(256.0, 256.0)


func _ready() -> void:
	if m_rain:
		m_rain_particle_process_material = m_rain.process_material as ParticleProcessMaterial
		m_rain.local_coords = false

	_update_direction_randomness()
	_update_drop_size()
	_update_speed()
	_update_lifetime()
	_update_wind()
	_update_density()


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return

	var viewport := get_viewport()
	var camera: Camera2D = null
	if viewport:
		camera = viewport.get_camera_2d()

	var viewport_size := Vector2(256.0, 256.0)
	var zoom := Vector2.ONE

	if viewport and camera:
		viewport_size = Vector2(viewport.size)
		zoom = camera.zoom

	if viewport_size != m_last_viewport_size or zoom != m_last_zoom:
		m_last_viewport_size = viewport_size
		m_last_zoom = zoom

		var s := viewport_size / zoom
		m_last_extents = s

		if m_rain_particle_process_material:
			m_rain_particle_process_material.emission_box_extents = Vector3(s.x, s.y, 1.0)

		_update_density()

	_update_wind()


func _update_density() -> void:
	_update_density_with_extents(m_last_extents)


func _update_density_with_extents(s: Vector2) -> void:
	if m_rain == null:
		return

	var area: float = max(0.0, s.x) * max(0.0, s.y)
	var target := int(area * density)

	if max_particles > 0:
		target = clampi(target, 0, max_particles)
	else:
		target = max(target, 0)

	m_rain.amount = target


func _update_direction_randomness() -> void:
	if m_rain_particle_process_material:
		m_rain_particle_process_material.spread = direction_randomness_degrees


func _update_drop_size() -> void:
	if m_rain_particle_process_material == null:
		return

	var min_scale := drop_size * (1.0 - size_randomness)
	var max_scale := drop_size * (1.0 + size_randomness)

	min_scale = max(min_scale, 0.0001)
	max_scale = max(max_scale, min_scale)

	m_rain_particle_process_material.scale_min = min_scale
	m_rain_particle_process_material.scale_max = max_scale


func _update_speed() -> void:
	if m_rain_particle_process_material == null:
		return

	var min_v := drop_speed * (1.0 - speed_randomness)
	var max_v := drop_speed * (1.0 + speed_randomness)

	min_v = max(min_v, 0.0)
	max_v = max(max_v, min_v)

	m_rain_particle_process_material.initial_velocity_min = min_v
	m_rain_particle_process_material.initial_velocity_max = max_v


func _update_lifetime() -> void:
	if m_rain == null:
		return

	# Base lifetime is on the particles node
	m_rain.lifetime = drop_lifetime

	# Randomness is on the process material (0..1)
	if m_rain_particle_process_material:
		m_rain_particle_process_material.lifetime_randomness = lifetime_randomness


func _update_wind() -> void:
	if m_rain_particle_process_material == null:
		return

	var vec := Vector2.RIGHT.rotated(deg_to_rad(wind_angle_degrees)).normalized()
	m_rain_particle_process_material.direction = Vector3(vec.x, vec.y, 0)
	m_rain_particle_process_material.gravity = Vector3(vec.x, vec.y, 0) * wind_strength
