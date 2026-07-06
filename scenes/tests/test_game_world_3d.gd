extends Node

# Headless smoke test for the low-poly 3D runtime world (Phase A/B acceptance of
# docs/plan/low_poly_3d_replacement.md). It boots scenes/game_world_3d.tscn and
# asserts the world builds and the shared interaction path works:
#   - terrain generated, player spawned, five landmark proxies placed
#   - residents spawned from the shared AppState roster
#   - story subjects registered for proximity selection
#   - resident talk dispatches through controller input and the 3D adapter
#   - equivalent fresh 2D/3D resident dispatches produce the same story result/state
#   - shared BGM and landmark-cue owners are present
#   - WeatherManager registers/cycles the 3D rain/fog/cloud-light target and propagates wind
#
# Run:
#   "/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . \
#       --scene res://scenes/tests/test_game_world_3d.tscn
# Success logs "PASS: game_world_3d smoke test" and returns process status 0;
# assertion failures push errors and return nonzero.

const APP_RUNTIME := preload("res://game/app_runtime.gd")
const APP_STATE_SCRIPT := preload("res://game/app_state.gd")

@onready var m_world: Node3D = $game_world_3d


func _ready() -> void:
	call_deferred("_run_smoke_checks")


func _run_smoke_checks() -> void:
	# Let the instanced world finish _ready plus a physics frame so terrain elevation
	# and resident placement settle.
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().process_frame

	var failures: Array[String] = []
	_check_world(failures)
	_check_terrain(failures)
	_check_player(failures)
	_check_player_appearance_mapping(failures)
	_check_landmarks(failures)
	_check_residents(failures)
	_check_story_subjects(failures)
	_check_audio(failures)
	_check_weather_3d(failures)
	_check_talk_dispatch(failures)
	_check_subject_contract(failures)
	_check_dimension_neutral_result_parity(failures)
	_check_resume_anchor(failures)

	if failures.is_empty():
		print("PASS: game_world_3d smoke test")
	else:
		for failure in failures:
			push_error(failure)
	if DisplayServer.get_name() == "headless":
		if is_instance_valid(m_world):
			m_world.queue_free()
			await get_tree().process_frame
			await get_tree().process_frame
		get_tree().quit(0 if failures.is_empty() else 1)


func _check_world(failures: Array[String]) -> void:
	if !is_instance_valid(m_world):
		failures.append("game_world_3d did not instance")


func _check_terrain(failures: Array[String]) -> void:
	if !is_instance_valid(m_world):
		return
	var terrain := m_world.get_node_or_null("LowPolyTerrain3D")
	if terrain == null:
		failures.append("world is missing LowPolyTerrain3D")
		return
	if terrain.get_node_or_null("LandMesh") == null:
		failures.append("LowPolyTerrain3D did not generate LandMesh")
	if terrain.get_node_or_null("TerrainCollision") == null:
		failures.append("LowPolyTerrain3D did not generate TerrainCollision")


func _check_player(failures: Array[String]) -> void:
	if !is_instance_valid(m_world):
		return
	var player := m_world.get_node_or_null("human_body_3d") as Node3D
	if player == null:
		failures.append("world is missing the human_body_3d player")
		return
	if !player.is_in_group("player"):
		failures.append("player is not in the 'player' group")
	if not is_finite(player.global_position.y):
		failures.append("player spawned with a non-finite height")


func _check_landmarks(failures: Array[String]) -> void:
	if !is_instance_valid(m_world):
		return
	var landmark_nodes: Dictionary = m_world.get("m_landmark_nodes")
	if landmark_nodes.size() != 5:
		failures.append("expected 5 landmark proxies, found %d" % landmark_nodes.size())


func _check_player_appearance_mapping(failures: Array[String]) -> void:
	var expectations := {
		"res://assets/characters/male.glb": {
			"body_frame_id": "adult",
			"presentation_id": "masculine",
		},
		"res://assets/characters/female.glb": {
			"body_frame_id": "adult",
			"presentation_id": "feminine",
		},
		"res://assets/characters/boy.glb": {
			"body_frame_id": "teen",
			"presentation_id": "masculine",
		},
	}
	for expected_path in expectations:
		var model_scene: PackedScene = m_world._resolve_player_model_scene(expectations[expected_path])
		if model_scene == null or model_scene.resource_path != expected_path:
			failures.append("3D player profile did not map to '%s'" % expected_path)


func _check_residents(failures: Array[String]) -> void:
	if !is_instance_valid(m_world):
		return
	var resident_root := m_world.get_node_or_null("Residents")
	if resident_root == null:
		failures.append("world did not spawn a Residents root")
		return
	var resident_count := 0
	for child in resident_root.get_children():
		if child is CharacterBody3D:
			resident_count += 1
	var app_state = APP_RUNTIME.get_app_state(self)
	var expected_count: int = app_state.get_resident_ids().size() if app_state != null else 0
	if resident_count != expected_count:
		failures.append(
			"world spawned %d residents, expected the shared roster's %d" % [resident_count, expected_count]
		)


func _check_story_subjects(failures: Array[String]) -> void:
	var subjects := get_tree().get_nodes_in_group("story_subject_3d")
	if subjects.is_empty():
		failures.append("no StorySubject3D nodes registered for interaction")


func _check_audio(failures: Array[String]) -> void:
	if !is_instance_valid(m_world):
		return
	if m_world.get_node_or_null("BGMManager") == null:
		failures.append("3D world did not create the shared BGMManager")
	if m_world.get_node_or_null("LandmarkCuePlayer") == null:
		failures.append("3D world did not create the landmark cue player")


func _check_weather_3d(failures: Array[String]) -> void:
	if !is_instance_valid(m_world):
		return
	var rig := m_world.get_node_or_null("WeatherRig3D")
	var manager: WeatherManager = m_world.get("m_weather_manager") as WeatherManager
	if rig == null:
		failures.append("3D world did not create WeatherRig3D")
		return
	if manager == null:
		failures.append("3D world did not resolve WeatherManager")
		return
	var registered: Dictionary = manager.get_registered_weather_nodes(m_world)
	if registered.get("weather_state_target") != rig:
		failures.append("WeatherManager did not register the 3D weather state target")
	if !manager.cycles_enabled:
		failures.append("3D overworld weather cycling is disabled")

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
	if !bool(rig.call("is_raining")):
		failures.append("steady-rain weather did not enable 3D rain particles")
	if !is_equal_approx(float(rig.get("wind_strength")), 460.0):
		failures.append("WeatherManager did not propagate wind into WeatherRig3D")
	var initial_preset_id := String(manager.get("m_current_preset_id"))
	manager._begin_random_transition()
	if int(manager.get("m_phase")) != WeatherManager.CyclePhase.TRANSITION:
		failures.append("WeatherManager did not begin a 3D weather transition")
	else:
		manager._process(float(manager.get("m_phase_duration")))
		if String(manager.get("m_current_preset_id")) == initial_preset_id:
			failures.append("WeatherManager did not complete a new 3D weather preset")


func _check_talk_dispatch(failures: Array[String]) -> void:
	var app_state = APP_RUNTIME.get_app_state(self)
	if app_state == null:
		failures.append("could not resolve AppState")
		return

	var player := m_world.get_node_or_null("human_body_3d") as Node3D
	var resident_subject: StorySubject3D = null
	for subject in get_tree().get_nodes_in_group("story_subject_3d"):
		if String(subject.get("subject_id")).begins_with("npc:"):
			resident_subject = subject as StorySubject3D
			break
	if player == null or resident_subject == null:
		failures.append("3D interaction path is missing a player or resident subject")
		return

	player.global_position = resident_subject.global_position
	m_world._update_interaction_target()
	var selected_subject := m_world.get("m_closest_subject") as StorySubject3D
	if selected_subject == null or !selected_subject.subject_id.begins_with("npc:"):
		failures.append("resident proximity did not select a resident StorySubject3D")
		return

	var controller: Variant = player.get("controller")
	if controller == null or !controller.has_signal("inspect_requested"):
		failures.append("3D player controller has no inspect_requested signal")
		return
	app_state.set_save_status("")
	controller.emit_signal("inspect_requested")
	if String(app_state.save_status).is_empty():
		failures.append("resident inspect input did not dispatch through the 3D world adapter")


# The 3D interaction adapter must build the SAME stable request the shared story
# service consumes: authored subject_id, a resolved action, and a dimension-neutral
# context. No 3D-only story fork. Proximity selection must deterministically pick one.
func _check_subject_contract(failures: Array[String]) -> void:
	if !is_instance_valid(m_world):
		return

	var landmark_subjects: Array = []
	for node in get_tree().get_nodes_in_group("story_subject_3d"):
		if String(node.get("subject_id")).begins_with("landmark:"):
			landmark_subjects.append(node)

	if landmark_subjects.size() < 3:
		failures.append("expected landmark story subjects, found %d" % landmark_subjects.size())
		return

	# Some landmark subjects are story-gated in a fresh state (no resolved action yet).
	# For every request the adapter DOES build, it must be well-formed and dimension
	# neutral; at least one landmark subject must resolve so the path is exercised.
	var valid_request_count := 0
	for subject in landmark_subjects:
		var subject_id := String(subject.get("subject_id"))
		var request: Dictionary = m_world._build_story_interaction_request(subject)
		if request.is_empty():
			continue
		valid_request_count += 1
		if String(request.get("subject_id", "")) != subject_id:
			failures.append("interaction request subject_id mismatch for '%s'" % subject_id)
		var context: Dictionary = request.get("context", {})
		for key in ["location", "world_position", "level_id"]:
			if not context.has(key):
				failures.append("interaction context for '%s' missing key '%s'" % [subject_id, key])
	if valid_request_count == 0:
		failures.append("no landmark subject produced a valid interaction request")

	# Proximity selection: standing on a known-targetable subject must resolve exactly
	# that active subject, deterministically.
	var player := m_world.get_node_or_null("human_body_3d") as Node3D
	var probe_subject: Node3D = null
	for subject in get_tree().get_nodes_in_group("story_subject_3d"):
		if subject.has_method("is_targetable") and subject.call("is_targetable"):
			probe_subject = subject
			break
	if is_instance_valid(player) and is_instance_valid(probe_subject):
		player.global_position = probe_subject.global_position
		m_world._update_interaction_target()
		if m_world.get("m_closest_subject") == null:
			failures.append("proximity selection found no active subject on a targetable subject")


func _check_resume_anchor(failures: Array[String]) -> void:
	if !is_instance_valid(m_world):
		return
	var app_state = APP_RUNTIME.get_app_state(self)
	if app_state == null:
		return
	var landmark_nodes: Dictionary = m_world.get("m_landmark_nodes")
	var player := m_world.get_node_or_null("human_body_3d") as Node3D
	if player == null or landmark_nodes.size() < 5:
		failures.append("resume-anchor check is missing world nodes")
		return

	app_state.mode = "Story"

	# A known anchor should place the player near that landmark.
	app_state.set_story_resume_checkpoint("Bagua Tower", "Bagua Tower")
	m_world._apply_story_resume_anchor_if_needed()
	var bagua := landmark_nodes.get("Bagua Tower") as Node3D
	if is_instance_valid(bagua) and _flat_distance(player.global_position, bagua.global_position) > 4.0:
		failures.append("resume anchor did not place the player near Bagua Tower")

	# A missing anchor should fall back to the Piano Ferry entry anchor.
	app_state.set_story_resume_checkpoint("Nonexistent Place", "Nonexistent Place")
	m_world._apply_story_resume_anchor_if_needed()
	var ferry := landmark_nodes.get("Piano Ferry") as Node3D
	if is_instance_valid(ferry) and _flat_distance(player.global_position, ferry.global_position) > 4.0:
		failures.append("resume fallback did not place the player at Piano Ferry")


func _check_dimension_neutral_result_parity(failures: Array[String]) -> void:
	var resident_ids: PackedStringArray = APP_RUNTIME.get_app_state(self).get_resident_ids()
	if resident_ids.is_empty():
		failures.append("cannot compare 2D/3D dispatch results without a resident")
		return
	var resident_id := String(resident_ids[0])
	var subject_id := "npc:%s" % resident_id
	var state_2d := APP_STATE_SCRIPT.new() as AppStateService
	var state_3d := APP_STATE_SCRIPT.new() as AppStateService
	var result_2d: Dictionary = state_2d.activate_story_subject(subject_id, "talk", {
		"resident_id": resident_id,
		"location": "Piano Ferry",
		"world_position": Vector2.ZERO,
		"level_id": 0,
	})
	var result_3d: Dictionary = state_3d.activate_story_subject(subject_id, "talk", {
		"resident_id": resident_id,
		"location": "Piano Ferry",
		"world_position": Vector3.ZERO,
		"level_id": 0,
	})
	if _dimension_neutral_result(result_2d) != _dimension_neutral_result(result_3d):
		failures.append("equivalent 2D/3D resident dispatches produced different story results")
	var state_keys := [
		"objective",
		"hint",
		"story_flags",
		"route_progress",
		"landmark_progress",
		"melody_progress",
		"resident_profiles",
	]
	for key in state_keys:
		if state_2d.get(key) != state_3d.get(key):
			failures.append("equivalent 2D/3D resident dispatches diverged in '%s'" % key)
	state_2d.free()
	state_3d.free()


func _dimension_neutral_result(result: Dictionary) -> Dictionary:
	var normalized := result.duplicate(true)
	var context: Dictionary = normalized.get("context", {})
	context.erase("world_position")
	normalized["context"] = context
	return normalized


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
