extends Node

const OUTPUT_DIR := "res://design/qa/low_poly_3d"
const WARMUP_SECONDS := 5.0
const CAPTURE_SECONDS := 60.0
const VARIANT_SECONDS := 1.0

@onready var m_world: Node3D = $game_world_3d
@onready var m_actor: Node3D = $game_world_3d/human_body_3d
@onready var m_camera: Camera3D = $game_world_3d/Camera3D
@onready var m_camera_controller: Node = $game_world_3d/Camera3DController


func _ready() -> void:
	call_deferred("_run_capture")


func _run_capture() -> void:
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	await _capture_fixed_views()
	await get_tree().create_timer(WARMUP_SECONDS).timeout

	var report := {
		"captured_at_unix": Time.get_unix_time_from_system(),
		"engine": Engine.get_version_info(),
		"renderer": RenderingServer.get_current_rendering_driver_name(),
		"viewport_logical_size": [
			get_viewport().get_visible_rect().size.x,
			get_viewport().get_visible_rect().size.y,
		],
		"render_pixel_size": [
			get_viewport().get_texture().get_image().get_width(),
			get_viewport().get_texture().get_image().get_height(),
		],
		"build": "editor_debug",
		"warmup_seconds": WARMUP_SECONDS,
		"capture_seconds": CAPTURE_SECONDS,
		"baseline": await _sample_performance(CAPTURE_SECONDS),
		"variants": {},
		"cold_terrain_rebuild_ms": float(m_world.get_node("LowPolyTerrain3D").get("last_rebuild_duration_ms")),
	}

	var resident_root := m_world.get_node_or_null("Residents") as Node3D
	if resident_root != null:
		resident_root.visible = false
		report["variants"]["residents_hidden"] = await _sample_performance(VARIANT_SECONDS)
		resident_root.visible = true

	var landmark_nodes: Dictionary = m_world.get("m_landmark_nodes")
	for landmark_name in ["Piano Ferry", "Trinity Church", "Bagua Tower"]:
		var landmark := landmark_nodes.get(landmark_name) as Node3D
		if landmark == null:
			continue
		landmark.visible = false
		report["variants"]["%s_hidden" % landmark_name.to_snake_case()] = await _sample_performance(
			VARIANT_SECONDS
		)
		landmark.visible = true

	var report_path := "%s/performance_latest.json" % OUTPUT_DIR
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % report_path)
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("QA_CAPTURE_REPORT %s" % JSON.stringify(report))
	get_tree().quit(0)


func _capture_fixed_views() -> void:
	var landmark_nodes: Dictionary = m_world.get("m_landmark_nodes")
	await _capture_view("world_overview.png", m_actor.global_position, 72.0)
	await _capture_view("player_scale.png", m_actor.global_position, 18.0)

	var ferry := landmark_nodes.get("Piano Ferry") as Node3D
	if ferry != null:
		await _capture_view(
			"landmark_approach.png",
			ferry.global_position + Vector3(0.0, 0.0, 6.0),
			26.0
		)
		await _capture_view(
			"water_shoreline.png",
			ferry.global_position + Vector3(0.0, 0.0, 10.0),
			32.0
		)

	var bagua := landmark_nodes.get("Bagua Tower") as Node3D
	if bagua != null:
		var follow_offset: Vector3 = m_camera_controller.get("follow_offset")
		var blocker_direction := Vector3(follow_offset.x, 0.0, follow_offset.z).normalized()
		await _capture_view(
			"camera_occlusion.png",
			bagua.global_position - blocker_direction * 6.0,
			24.0
		)


func _capture_view(file_name: String, actor_position: Vector3, camera_size: float) -> void:
	m_actor.global_position = actor_position
	m_camera.size = camera_size
	m_camera_controller.set("orthographic_size", camera_size)
	m_camera_controller.call("snap_to_target")
	for _frame in range(12):
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png("%s/%s" % [OUTPUT_DIR, file_name])
	if error != OK:
		push_error("Could not save %s (error %d)" % [file_name, error])


func _sample_performance(duration_seconds: float) -> Dictionary:
	var frame_times_ms: Array[float] = []
	var draw_calls: Array[float] = []
	var primitives: Array[float] = []
	var objects: Array[float] = []
	var started_usec := Time.get_ticks_usec()
	var previous_usec := started_usec
	while float(Time.get_ticks_usec() - started_usec) / 1000000.0 < duration_seconds:
		await get_tree().process_frame
		var now_usec := Time.get_ticks_usec()
		frame_times_ms.append(float(now_usec - previous_usec) / 1000.0)
		previous_usec = now_usec
		draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		objects.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	frame_times_ms.sort()
	return {
		"sample_count": frame_times_ms.size(),
		"frame_ms_p95": _percentile(frame_times_ms, 0.95),
		"frame_ms_worst": frame_times_ms.back() if !frame_times_ms.is_empty() else 0.0,
		"fps_average": 1000.0 / _average(frame_times_ms),
		"draw_calls_average": _average(draw_calls),
		"draw_calls_max": _maximum(draw_calls),
		"primitives_average": _average(primitives),
		"primitives_max": _maximum(primitives),
		"objects_average": _average(objects),
		"video_memory_mib": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		"static_memory_mib": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
	}


func _percentile(values: Array[float], fraction: float) -> float:
	if values.is_empty():
		return 0.0
	var index := clampi(ceili(float(values.size()) * fraction) - 1, 0, values.size() - 1)
	return values[index]


func _average(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += value
	return total / float(values.size())


func _maximum(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var result := values[0]
	for value in values:
		result = maxf(result, value)
	return result
