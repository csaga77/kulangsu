extends Node

const OUTPUT_PATH := "res://design/qa/low_poly_3d/weather_steady_rain.png"

@onready var m_world: Node3D = $game_world_3d


func _ready() -> void:
	call_deferred("_run_capture")


func _run_capture() -> void:
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().process_frame

	var rig := m_world.get_node_or_null("WeatherRig3D")
	var manager: WeatherManager = m_world.get("m_weather_manager") as WeatherManager
	var actor := m_world.get_node_or_null("human_body_3d") as Node3D
	var camera := m_world.get_node_or_null("Camera3D") as Camera3D
	var camera_controller := m_world.get_node_or_null("Camera3DController")
	var landmarks: Dictionary = m_world.get("m_landmark_nodes")
	var ferry := landmarks.get("Piano Ferry") as Node3D
	if rig == null or manager == null or actor == null or camera == null or ferry == null:
		push_error("Weather3D capture could not resolve the runtime weather/world nodes.")
		get_tree().quit(1)
		return

	actor.global_position = ferry.global_position + Vector3(0.0, 0.0, 7.0)
	camera.size = 22.0
	camera_controller.set("orthographic_size", 22.0)
	camera_controller.call("snap_to_target")
	manager._apply_weather({
		"rain_density": 0.0012,
		"fog_density": 0.42,
		"fog_height_ratio": 0.58,
		"fog_drift_speed": 0.11,
		"wind_angle_degrees": 72.0,
		"wind_strength": 460.0,
		"drop_speed": 250.0,
		"drop_size": 0.1,
	})

	for _frame in range(120):
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(OUTPUT_PATH)
	if error != OK:
		push_error("Weather3D capture failed to save (error %d)." % error)
		get_tree().quit(1)
		return
	if !bool(rig.call("is_raining")):
		push_error("Weather3D steady-rain preset did not emit particles.")
		get_tree().quit(1)
		return
	print("PASS: WeatherRig3D steady-rain capture")
	get_tree().quit(0)
