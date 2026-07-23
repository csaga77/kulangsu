extends Node

# Headless smoke test for the low-poly 3D runtime world (Phase A/B acceptance of
# docs/plan/low_poly_3d_replacement.md). It boots scenes/game_world_3d.tscn and
# asserts the world builds and the shared interaction path works:
#   - terrain/water/streets generated, player spawned and terrain-following
#   - runtime camera/controller wiring and authored landmark collision
#   - five stable landmark anchors placed through the coordinate adapter
#   - residents spawned from the shared AppState roster
#   - story subjects registered for proximity selection
#   - resident talk dispatches through controller input and the interaction coordinator
#   - legacy Vector2 and production Vector3 spatial contexts produce the same story result/state
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
const BASE_CONTROLLER_3D_SCRIPT := preload("res://characters/control/base_controller_3d.gd")
const ActorSurfaceFollowerScript = preload("res://game/world/actor_surface_follower.gd")
const StoryInteractionCoordinatorScript = preload(
	"res://game/world/story_interaction_coordinator.gd"
)
const APO_HOUSEHOLD_SCRIPT := preload(
	"res://architecture/apo_household/apo_household_courtyard_3d.gd"
)
const TERRAIN_KIND_WATER := 0
const ACTOR_GROUND_TOLERANCE := 0.2
const MAX_ACTOR_WADE_DEPTH := 0.5
const EXPECTED_WORLD_SUBJECT_IDS: Array[String] = [
	"inspectable:bagua_railings",
	"inspectable:church_stone_bench",
	"inspectable:family_household_courtyard",
	"inspectable:harbor_lantern_lines",
	"inspectable:harbor_notice_board",
	"inspectable:postcard_display_rack",
	"landmark:bagua_tower.synthesis_chamber",
	"landmark:bi_shan_tunnel.chamber",
	"landmark:bi_shan_tunnel.echo_a",
	"landmark:bi_shan_tunnel.echo_b",
	"landmark:bi_shan_tunnel.echo_c",
	"landmark:festival_stage.harbor_stage",
	"landmark:family_household.arrival",
	"landmark:family_household.courtyard_care",
	"landmark:long_shan_tunnel.light_pocket_north",
	"landmark:long_shan_tunnel.light_pocket_south",
	"landmark:long_shan_tunnel.tunnel_entry",
	"landmark:long_shan_tunnel.tunnel_exit",
	"landmark:piano_ferry.harbor_refrain",
	"landmark:trinity_church.choir_chime",
	"landmark:trinity_church.garden",
	"landmark:trinity_church.steps",
	"landmark:trinity_church.yard",
]

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
	_check_lighting(failures)
	_check_terrain(failures)
	_check_player(failures)
	_check_player_surface_follow(failures)
	_check_camera(failures)
	_check_player_appearance_mapping(failures)
	_check_landmarks(failures)
	_check_residents(failures)
	_check_story_subjects(failures)
	_check_household_courtyard(failures)
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
		return
	var surface_follower := (
		m_world.get_node_or_null("ActorSurfaceFollower") as ActorSurfaceFollowerScript
	)
	if surface_follower == null or !surface_follower.is_configured():
		failures.append("world did not configure ActorSurfaceFollower")
	var interaction_coordinator := (
		m_world.get_node_or_null("StoryInteractionCoordinator") as StoryInteractionCoordinatorScript
	)
	if interaction_coordinator == null or !interaction_coordinator.is_configured():
		failures.append("world did not configure StoryInteractionCoordinator")


func _check_lighting(failures: Array[String]) -> void:
	if !is_instance_valid(m_world):
		return
	var world_environment := m_world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_environment == null or world_environment.environment == null:
		failures.append("world is missing its configured environment")
		return
	if (
		world_environment.environment.ambient_light_source
		!= Environment.AMBIENT_SOURCE_COLOR
	):
		failures.append(
			"world ambient lighting does not use its configured color; horizontal street colors will render black"
		)


func _check_terrain(failures: Array[String]) -> void:
	if !is_instance_valid(m_world):
		return
	var terrain := m_world.get_node_or_null("LowPolyTerrain3D")
	if terrain == null:
		failures.append("world is missing LowPolyTerrain3D")
		return
	if terrain.get_node_or_null("LandMesh") == null:
		failures.append("LowPolyTerrain3D did not generate LandMesh")
	if terrain.get_node_or_null("WaterMesh") == null:
		failures.append("LowPolyTerrain3D did not generate WaterMesh")
	if terrain.get_node_or_null("WaterSurfaceLayerMesh") == null:
		failures.append("LowPolyTerrain3D did not generate WaterSurfaceLayerMesh")
	if terrain.get_node_or_null("WaterShorelineMesh") == null:
		failures.append("LowPolyTerrain3D did not generate WaterShorelineMesh")
	if terrain.get_node_or_null("TerrainCollision") == null:
		failures.append("LowPolyTerrain3D did not generate TerrainCollision")

	if terrain.get_node_or_null("StreetMesh") != null:
		failures.append("runtime terrain retained the obsolete mask-derived StreetMesh")
	var generated_streets := terrain.get_node_or_null("GeneratedStreets")
	if generated_streets == null:
		failures.append("runtime terrain is missing its generated street-network assembly")
	else:
		var visible_street_count := _count_visible_street_meshes(generated_streets)
		if visible_street_count <= 0:
			failures.append("runtime terrain generated no visible street-network meshes")


func _count_visible_street_meshes(node: Node) -> int:
	var count := 0
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		count += 1
	for child in node.get_children():
		count += _count_visible_street_meshes(child)
	return count


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
	if float(player.get("body_height")) <= 0.0 or float(player.get("body_radius")) <= 0.0:
		failures.append("player body dimensions are invalid")
	if player.get_node_or_null("VisualRoot/CharacterModel") == null:
		failures.append("player did not instance its character model")
	var controller: Variant = player.get("controller")
	if controller == null or !(controller is BASE_CONTROLLER_3D_SCRIPT):
		failures.append("player controller does not extend BaseController3D")


func _check_player_surface_follow(failures: Array[String]) -> void:
	if !is_instance_valid(m_world):
		return
	var terrain := m_world.get_node_or_null("LowPolyTerrain3D")
	var player := m_world.get_node_or_null("human_body_3d") as CharacterBody3D
	var coordinates: LowPolyWorldCoordinates3D = m_world.get("m_coordinates") as LowPolyWorldCoordinates3D
	var surface_follower := (
		m_world.get_node_or_null("ActorSurfaceFollower") as ActorSurfaceFollowerScript
	)
	if terrain == null or player == null or coordinates == null or surface_follower == null:
		failures.append("terrain-follow check is missing runtime world nodes")
		return

	var original_position := player.global_position
	var dry_cell := _find_surface_probe_cell(terrain, coordinates, false)
	if dry_cell == Vector2i(-1, -1):
		failures.append("runtime terrain has no dry cell for player settling")
	else:
		var dry_position := coordinates.sample_cell_to_world_center(dry_cell, 0.0) + Vector3(0.21, 0.0, -0.17)
		var dry_height := float(terrain.call("get_world_surface_height", dry_position))
		player.global_position = Vector3(dry_position.x, dry_height + 0.5, dry_position.z)
		surface_follower.settle_now()
		if absf(player.global_position.y - dry_height) > ACTOR_GROUND_TOLERANCE:
			failures.append("player did not settle onto the runtime terrain surface")

	var water_cell := _find_surface_probe_cell(terrain, coordinates, true)
	if water_cell == Vector2i(-1, -1):
		failures.append("runtime terrain has no submerged cell for player wading")
	else:
		var water_position := coordinates.sample_cell_to_world_center(water_cell, 0.0)
		var seabed_height := float(terrain.call("get_world_surface_height", water_position))
		var water_surface := float(terrain.call("get_world_water_surface_height", water_position))
		var expected_wade_height := maxf(seabed_height, water_surface - MAX_ACTOR_WADE_DEPTH)
		player.global_position = Vector3(water_position.x, water_surface + 0.5, water_position.z)
		surface_follower.settle_now()
		if absf(player.global_position.y - expected_wade_height) > ACTOR_GROUND_TOLERANCE:
			failures.append("player did not wade at the expected runtime water depth")
		if player.global_position.y > water_surface + ACTOR_GROUND_TOLERANCE:
			failures.append("player stood on top of runtime water instead of wading")

	player.global_position = original_position
	surface_follower.settle_now()


func _find_surface_probe_cell(terrain: Node, coordinates: LowPolyWorldCoordinates3D, find_water: bool) -> Vector2i:
	var grid_size := coordinates.get_grid_size()
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var sample_cell := Vector2i(x, y)
			var is_water := int(terrain.call("get_sample_cell_kind", sample_cell)) == TERRAIN_KIND_WATER
			if is_water != find_water:
				continue
			if find_water:
				var position := coordinates.sample_cell_to_world_center(sample_cell, 0.0)
				var seabed := float(terrain.call("get_world_surface_height", position))
				var water_surface := float(terrain.call("get_world_water_surface_height", position))
				if seabed >= water_surface - 0.02:
					continue
			return sample_cell
	return Vector2i(-1, -1)


func _check_camera(failures: Array[String]) -> void:
	if !is_instance_valid(m_world):
		return
	var camera := m_world.get_node_or_null("Camera3D") as Camera3D
	var player := m_world.get_node_or_null("human_body_3d") as Node3D
	var controller := m_world.get_node_or_null("Camera3DController")
	if camera == null or controller == null:
		failures.append("runtime world is missing Camera3D or Camera3DController")
		return
	if camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
		failures.append("runtime world camera is not orthographic")
	if controller.get("camera") != camera or controller.get("target_node") != player:
		failures.append("Camera3DController is not wired to the runtime camera and player")
	if !controller.has_method("rotate_yaw"):
		failures.append("Camera3DController is missing orbit rotation support")
		return
	var original_yaw := float(controller.get("orbit_yaw_degrees"))
	controller.call("rotate_yaw", 12.0)
	var expected_yaw := wrapf(original_yaw + 12.0, -180.0, 180.0)
	if !is_equal_approx(float(controller.get("orbit_yaw_degrees")), expected_yaw):
		failures.append("Camera3DController did not apply orbit yaw rotation")
	controller.set("orbit_yaw_degrees", original_yaw)


func _check_landmarks(failures: Array[String]) -> void:
	if !is_instance_valid(m_world):
		return
	var landmark_nodes: Dictionary = m_world.get("m_landmark_nodes")
	if landmark_nodes.size() != 5:
		failures.append("expected 5 landmark anchors, found %d" % landmark_nodes.size())
	var coordinates: LowPolyWorldCoordinates3D = m_world.get("m_coordinates") as LowPolyWorldCoordinates3D
	for landmark_name in landmark_nodes:
		var landmark := landmark_nodes[landmark_name] as Node3D
		if landmark == null or !landmark.has_meta(&"low_poly_landmark_mask_pixel"):
			failures.append("%s was not placed through LowPolyWorldCoordinates3D" % landmark_name)
			continue
		var mask_pixel: Variant = landmark.get_meta(&"low_poly_landmark_mask_pixel")
		if !(mask_pixel is Vector2i) or coordinates == null or !coordinates.is_mask_pixel_inside(Vector2(mask_pixel)):
			failures.append("%s has an invalid terrain-mask placement" % landmark_name)

	for authored_path in [
		"Landmarks/TrinityChurchProxy",
		"Landmarks/BaguaTowerProxy",
	]:
		var authored_landmark := m_world.get_node_or_null(authored_path)
		if authored_landmark == null or !_has_static_collision(authored_landmark):
			failures.append("%s did not generate runtime landmark collision" % authored_path)


func _has_static_collision(node: Node) -> bool:
	if node is StaticBody3D:
		return true
	for child in node.get_children():
		if _has_static_collision(child):
			return true
	return false


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
	var expected_count: int = app_state.get_projection().resident_ids.size() if app_state != null else 0
	if resident_count != expected_count:
		failures.append(
			"world spawned %d residents, expected the shared roster's %d" % [resident_count, expected_count]
		)


func _check_story_subjects(failures: Array[String]) -> void:
	var subjects := get_tree().get_nodes_in_group("story_subject_3d")
	if subjects.is_empty():
		failures.append("no StorySubject3D nodes registered for interaction")
		return
	var authored_subject_ids: Array[String] = []
	for subject in subjects:
		if !(subject is StorySubject3D) or !m_world.is_ancestor_of(subject):
			continue
		var subject_id := String(subject.get("subject_id"))
		if subject_id.begins_with("landmark:") or subject_id.begins_with("inspectable:"):
			authored_subject_ids.append(subject_id)
	authored_subject_ids.sort()
	var expected_subject_ids: Array[String] = EXPECTED_WORLD_SUBJECT_IDS.duplicate()
	expected_subject_ids.sort()
	if authored_subject_ids != expected_subject_ids:
		failures.append(
			"authored 3D world subjects differ: expected %s, found %s"
			% [expected_subject_ids, authored_subject_ids]
		)


func _check_household_courtyard(failures: Array[String]) -> void:
	if !is_instance_valid(m_world):
		return
	var ferry := m_world.get_node_or_null("Landmarks/PianoFerryProxy") as Node3D
	var household := m_world.get_node_or_null(
		"Landmarks/PianoFerryProxy/APosHouseholdCourtyard"
	) as APO_HOUSEHOLD_SCRIPT
	if household == null:
		failures.append("production world is missing A Po's household courtyard")
		return
	if ferry == null or _flat_distance(household.global_position, ferry.global_position) > 18.0:
		failures.append("A Po's household courtyard is not placed near the ferry district")

	for subject_contract in [
		["ArrivalSubject", "landmark:family_household.arrival"],
		["CareSubject", "landmark:family_household.courtyard_care"],
		["ReflectionSubject", "inspectable:family_household_courtyard"],
	]:
		var subject := household.get_node_or_null(String(subject_contract[0])) as StorySubject3D
		if subject == null or subject.subject_id != String(subject_contract[1]):
			failures.append(
				"household subject %s is missing semantic id %s"
				% [subject_contract[0], subject_contract[1]]
			)

	household.apply_story_flags({"family_household_care_seen": true})
	if (
		household.get_presentation_state() != "cared_for"
		or !household.get_node("House/WarmWindow").visible
		or !household.get_node("Courtyard/TendedProps").visible
	):
		failures.append("seen household care did not render its warm, tended state")

	household.apply_story_flags({"family_household_care_missed": true})
	if (
		household.get_presentation_state() != "untended"
		or household.get_node("House/WarmWindow").visible
		or !household.get_node("Courtyard/UntendedProps").visible
	):
		failures.append("missed household care did not render its cold, untended state")


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
	var reference_wind := manager.get_reference_wind_strength()
	manager.set_registered_wind(95.0, 0.0)
	manager.set_registered_wind(95.0, reference_wind)
	var water_mesh := m_world.get_node_or_null("LowPolyTerrain3D/WaterMesh") as MeshInstance3D
	var water_material := water_mesh.material_override as ShaderMaterial if water_mesh != null else null
	if water_material == null:
		failures.append("runtime water is missing its wind-aware ShaderMaterial")
	elif !is_equal_approx(float(water_material.get_shader_parameter(&"wind_strength")), 1.0):
		failures.append("WeatherManager wind did not reach runtime water through the adapter")
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
	var coordinator := (
		m_world.get_node_or_null("StoryInteractionCoordinator") as StoryInteractionCoordinatorScript
	)
	var resident_subject: StorySubject3D = null
	for subject in get_tree().get_nodes_in_group("story_subject_3d"):
		if String(subject.get("subject_id")).begins_with("npc:"):
			resident_subject = subject as StorySubject3D
			break
	if player == null or resident_subject == null or coordinator == null:
		failures.append("interaction path is missing its player, coordinator, or resident subject")
		return

	player.global_position = resident_subject.global_position
	coordinator.update_target()
	var selected_subject := coordinator.get_active_subject()
	if selected_subject == null or !selected_subject.subject_id.begins_with("npc:"):
		failures.append("resident proximity did not select a resident StorySubject3D")
		return

	var controller: Variant = player.get("controller")
	if controller == null or !controller.has_signal("inspect_requested"):
		failures.append("3D player controller has no inspect_requested signal")
		return
	app_state.update_world_context({"status": ""})
	controller.emit_signal("inspect_requested")
	if String(app_state.get_projection().save_status).is_empty():
		failures.append("resident inspect input did not dispatch through the interaction coordinator")


# The interaction coordinator must build the SAME stable request the shared story
# service consumes: authored subject_id, a resolved action, and a dimension-neutral
# context. No 3D-only story fork. Proximity selection must deterministically pick one.
func _check_subject_contract(failures: Array[String]) -> void:
	if !is_instance_valid(m_world):
		return
	var coordinator := (
		m_world.get_node_or_null("StoryInteractionCoordinator") as StoryInteractionCoordinatorScript
	)
	if coordinator == null:
		failures.append("subject contract check is missing StoryInteractionCoordinator")
		return

	var landmark_subjects: Array = []
	for node in get_tree().get_nodes_in_group("story_subject_3d"):
		if String(node.get("subject_id")).begins_with("landmark:"):
			landmark_subjects.append(node)

	var expected_landmark_count := 0
	for subject_id in EXPECTED_WORLD_SUBJECT_IDS:
		if subject_id.begins_with("landmark:"):
			expected_landmark_count += 1
	if landmark_subjects.size() != expected_landmark_count:
		failures.append(
			"expected %d landmark story subjects, found %d"
			% [expected_landmark_count, landmark_subjects.size()]
		)
		return

	# Some landmark subjects are story-gated in a fresh state (no resolved action yet).
	# For every request the adapter DOES build, it must be well-formed and dimension
	# neutral; at least one landmark subject must resolve so the path is exercised.
	var valid_request_count := 0
	for subject in landmark_subjects:
		var subject_id := String(subject.get("subject_id"))
		var request: Dictionary = coordinator.build_story_interaction_request(subject)
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
		coordinator.update_target()
		if coordinator.get_active_subject() == null:
			failures.append("proximity selection found no active subject on a targetable subject")

	# A coordinator only owns subjects below its configured world root. This keeps
	# another loaded world or test fixture from competing for the active target.
	var external_subject := StorySubject3D.new()
	external_subject.name = "ExternalStorySubject"
	external_subject.subject_id = "inspectable:harbor_notice_board"
	add_child(external_subject)
	external_subject.add_to_group("story_subject_3d")
	coordinator.refresh_subjects()
	if coordinator.get_subjects().has(external_subject):
		failures.append("interaction coordinator captured a subject outside its world root")
	external_subject.queue_free()
	coordinator.refresh_subjects()


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

	app_state.start_new_story()

	# A known anchor should place the player near that landmark.
	app_state.update_resume_checkpoint("Bagua Tower", "Bagua Tower")
	m_world._apply_story_resume_anchor_if_needed()
	var bagua := landmark_nodes.get("Bagua Tower") as Node3D
	if is_instance_valid(bagua) and _flat_distance(player.global_position, bagua.global_position) > 4.0:
		failures.append("resume anchor did not place the player near Bagua Tower")

	# A missing anchor should fall back to the Piano Ferry entry anchor.
	app_state.update_resume_checkpoint("Nonexistent Place", "Nonexistent Place")
	m_world._apply_story_resume_anchor_if_needed()
	var ferry := landmark_nodes.get("Piano Ferry") as Node3D
	if is_instance_valid(ferry) and _flat_distance(player.global_position, ferry.global_position) > 4.0:
		failures.append("resume fallback did not place the player at Piano Ferry")


func _check_dimension_neutral_result_parity(failures: Array[String]) -> void:
	var resident_ids: PackedStringArray = APP_RUNTIME.get_app_state(self).get_projection().resident_ids
	if resident_ids.is_empty():
		failures.append("cannot compare spatial-context dispatch results without a resident")
		return
	var resident_id := String(resident_ids[0])
	var subject_id := "npc:%s" % resident_id
	var vector2_context_state := APP_STATE_SCRIPT.new() as AppStateService
	var vector3_context_state := APP_STATE_SCRIPT.new() as AppStateService
	vector2_context_state.start_new_story()
	vector3_context_state.start_new_story()
	var vector2_context_result: Dictionary = vector2_context_state.activate_story_subject(subject_id, "talk", {
		"resident_id": resident_id,
		"location": "Piano Ferry",
		"world_position": Vector2.ZERO,
		"level_id": 0,
	})
	var vector3_context_result: Dictionary = vector3_context_state.activate_story_subject(subject_id, "talk", {
		"resident_id": resident_id,
		"location": "Piano Ferry",
		"world_position": Vector3.ZERO,
		"level_id": 0,
	})
	if _dimension_neutral_result(vector2_context_result) != _dimension_neutral_result(vector3_context_result):
		failures.append("Vector2/Vector3 context payloads produced different story results")
	if vector2_context_state.get_snapshot().canonical_dictionary() != vector3_context_state.get_snapshot().canonical_dictionary():
		failures.append("Vector2/Vector3 context payloads diverged in canonical state")
	if vector2_context_state.get_projection().route_progress != vector3_context_state.get_projection().route_progress:
		failures.append("Vector2/Vector3 context payloads diverged in route projection")
	vector2_context_state.free()
	vector3_context_state.free()


func _dimension_neutral_result(result: Dictionary) -> Dictionary:
	var normalized := result.duplicate(true)
	var context: Dictionary = normalized.get("context", {})
	context.erase("world_position")
	normalized["context"] = context
	return normalized


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
