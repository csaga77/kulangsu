class_name WeatherRig3D
extends Node3D

const MAX_RAIN_PARTICLES := 900
const RAIN_DENSITY_TO_AMOUNT := 480000.0
const WEATHER_WIND_REFERENCE := 620.0

var rain_density := 0.0
var fog_density := 0.18
var fog_height_ratio := 0.5
var fog_drift_speed := 0.045
var wind_angle_degrees := 58.0
var wind_strength := 140.0
var drop_speed := 220.0
var drop_size := 0.09

var m_target: Node3D = null
var m_world_environment: WorldEnvironment = null
var m_sun: DirectionalLight3D = null
var m_rain: GPUParticles3D = null
var m_rain_material: ParticleProcessMaterial = null
var m_rain_mesh: BoxMesh = null
var m_base_fog_density := 0.0025
var m_base_fog_light_energy := 1.0
var m_base_sun_energy := 1.0
var m_weather_visible := true
var m_cloud_phase := 0.0


func configure(
	target: Node3D,
	world_environment: WorldEnvironment,
	sun: DirectionalLight3D
) -> void:
	m_target = target
	m_world_environment = world_environment
	m_sun = sun
	if is_instance_valid(m_world_environment) and m_world_environment.environment != null:
		m_base_fog_density = m_world_environment.environment.fog_density
		m_base_fog_light_energy = m_world_environment.environment.fog_light_energy
	if is_instance_valid(m_sun):
		m_base_sun_energy = m_sun.light_energy
	_ensure_rain()
	_apply_visual_state()


func _process(delta: float) -> void:
	if is_instance_valid(m_target):
		global_position = m_target.global_position + Vector3.UP * 15.0
	m_cloud_phase += delta * (0.08 + fog_drift_speed * 0.7) * lerpf(
		0.45,
		1.6,
		clampf(wind_strength / WEATHER_WIND_REFERENCE, 0.0, 1.0)
	)
	_apply_cloud_light()


func apply_weather(weather: Dictionary) -> void:
	rain_density = maxf(float(weather.get("rain_density", rain_density)), 0.0)
	fog_density = clampf(float(weather.get("fog_density", fog_density)), 0.0, 1.0)
	fog_height_ratio = clampf(float(weather.get("fog_height_ratio", fog_height_ratio)), 0.0, 1.0)
	fog_drift_speed = maxf(float(weather.get("fog_drift_speed", fog_drift_speed)), 0.0)
	drop_speed = maxf(float(weather.get("drop_speed", drop_speed)), 1.0)
	drop_size = maxf(float(weather.get("drop_size", drop_size)), 0.01)
	set_wind(
		float(weather.get("wind_angle_degrees", wind_angle_degrees)),
		float(weather.get("wind_strength", wind_strength))
	)
	_apply_visual_state()


func capture_weather_state() -> Dictionary:
	return {
		"rain_density": rain_density,
		"fog_density": fog_density,
		"fog_height_ratio": fog_height_ratio,
		"fog_drift_speed": fog_drift_speed,
		"wind_angle_degrees": wind_angle_degrees,
		"wind_strength": wind_strength,
		"drop_speed": drop_speed,
		"drop_size": drop_size,
	}


func set_wind(angle_degrees: float, strength: float) -> void:
	wind_angle_degrees = wrapf(angle_degrees, 0.0, 360.0)
	wind_strength = maxf(strength, 0.0)
	_apply_rain_motion()


func set_weather_visible(is_visible: bool) -> void:
	m_weather_visible = is_visible
	visible = is_visible
	_apply_visual_state()


func is_raining() -> bool:
	return is_instance_valid(m_rain) and m_rain.emitting


func _ensure_rain() -> void:
	if is_instance_valid(m_rain):
		return
	m_rain = GPUParticles3D.new()
	m_rain.name = "Rain3D"
	m_rain.amount = 1
	m_rain.lifetime = 1.35
	m_rain.randomness = 0.35
	m_rain.visibility_aabb = AABB(Vector3(-38.0, -22.0, -38.0), Vector3(76.0, 44.0, 76.0))
	add_child(m_rain)

	m_rain_material = ParticleProcessMaterial.new()
	m_rain_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m_rain_material.emission_box_extents = Vector3(32.0, 1.0, 32.0)
	m_rain_material.spread = 4.0
	m_rain.process_material = m_rain_material

	m_rain_mesh = BoxMesh.new()
	m_rain_mesh.size = Vector3(0.025, 0.85, 0.025)
	var rain_material := StandardMaterial3D.new()
	rain_material.albedo_color = Color(0.74, 0.88, 1.0, 0.52)
	rain_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rain_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m_rain_mesh.material = rain_material
	m_rain.draw_pass_1 = m_rain_mesh


func _apply_visual_state() -> void:
	_ensure_rain()
	var rain_amount := clampi(
		roundi(rain_density * RAIN_DENSITY_TO_AMOUNT),
		0,
		MAX_RAIN_PARTICLES
	)
	m_rain.amount = maxi(rain_amount, 1)
	m_rain.emitting = m_weather_visible and rain_amount > 0
	m_rain_mesh.size = Vector3(
		maxf(drop_size * 0.24, 0.018),
		maxf(drop_size * 7.5, 0.5),
		maxf(drop_size * 0.24, 0.018)
	)
	_apply_rain_motion()
	_apply_environment_fog()
	_apply_cloud_light()


func _apply_rain_motion() -> void:
	if m_rain_material == null:
		return
	var radians := deg_to_rad(wind_angle_degrees)
	var wind_normalized := clampf(wind_strength / WEATHER_WIND_REFERENCE, 0.0, 1.0)
	var horizontal := Vector3(cos(radians), 0.0, sin(radians)) * lerpf(0.5, 8.0, wind_normalized)
	m_rain_material.direction = (Vector3.DOWN + horizontal * 0.045).normalized()
	m_rain_material.initial_velocity_min = drop_speed * 0.045
	m_rain_material.initial_velocity_max = drop_speed * 0.06
	m_rain_material.gravity = Vector3(horizontal.x, -drop_speed * 0.05, horizontal.z)


func _apply_environment_fog() -> void:
	if !is_instance_valid(m_world_environment) or m_world_environment.environment == null:
		return
	var environment := m_world_environment.environment
	if !m_weather_visible:
		environment.fog_density = m_base_fog_density
		environment.fog_light_energy = m_base_fog_light_energy
		return
	environment.fog_enabled = true
	environment.fog_density = lerpf(0.0015, 0.012, fog_density)
	environment.fog_light_energy = lerpf(1.05, 0.72, fog_density)


func _apply_cloud_light() -> void:
	if !is_instance_valid(m_sun):
		return
	if !m_weather_visible:
		m_sun.light_energy = m_base_sun_energy
		return
	var rain_cover := clampf(rain_density / 0.00165, 0.0, 1.0)
	var cover := clampf(fog_density * 0.65 + rain_cover * 0.35, 0.0, 1.0)
	var moving_shadow := 0.5 + 0.5 * sin(m_cloud_phase)
	var shadow_strength := cover * lerpf(0.08, 0.24, moving_shadow)
	m_sun.light_energy = m_base_sun_energy * (1.0 - shadow_strength)
