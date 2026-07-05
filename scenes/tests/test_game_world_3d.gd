extends Node

# Headless smoke test for the low-poly 3D runtime world (Phase A/B acceptance of
# docs/plan/low_poly_3d_replacement.md). It boots scenes/game_world_3d.tscn and
# asserts the world builds and the shared interaction path works:
#   - terrain generated, player spawned, five landmark proxies placed
#   - residents spawned from the shared AppState roster
#   - story subjects registered for proximity selection
#   - a resident talk dispatches through AppState.activate_story_subject without error
#
# Run:
#   "/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . \
#       --scene res://scenes/tests/test_game_world_3d.tscn
# Success logs "PASS: game_world_3d smoke test" and returns process status 0;
# assertion failures push errors and return nonzero.

const APP_RUNTIME := preload("res://game/app_runtime.gd")

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
	_check_landmarks(failures)
	_check_residents(failures)
	_check_story_subjects(failures)
	_check_talk_dispatch(failures)
	_check_subject_contract(failures)
	_check_resume_anchor(failures)

	if failures.is_empty():
		print("PASS: game_world_3d smoke test")
	else:
		for failure in failures:
			push_error(failure)
	if DisplayServer.get_name() == "headless":
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
	if resident_count <= 0:
		failures.append("world spawned no residents")


func _check_story_subjects(failures: Array[String]) -> void:
	var subjects := get_tree().get_nodes_in_group("story_subject_3d")
	if subjects.is_empty():
		failures.append("no StorySubject3D nodes registered for interaction")


func _check_talk_dispatch(failures: Array[String]) -> void:
	var app_state = APP_RUNTIME.get_app_state(self)
	if app_state == null:
		failures.append("could not resolve AppState")
		return
	var resident_ids: PackedStringArray = app_state.get_resident_ids()
	if resident_ids.is_empty():
		failures.append("AppState exposed no residents to talk to")
		return
	var resident_id := String(resident_ids[0])
	var result = app_state.activate_story_subject("npc:%s" % resident_id, "talk", {})
	if not (result is Dictionary):
		failures.append("resident talk dispatch did not return a result dictionary")


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


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
