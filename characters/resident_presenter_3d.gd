class_name ResidentPresenter3D
extends RefCounted

# Phase E of docs/plan/low_poly_3d_replacement.md: the 3D resident presenter.
#
# It spawns one HumanBody3D per resident from the SAME shared AppState resident
# data the 2D ResidentSpawner uses (get_resident_ids / get_resident_definition /
# get_resident_spawn_config). It does NOT introduce a parallel resident data
# format, identity, dialogue, or routine model. Each resident carries an
# `npc:<id>` StorySubject3D so talking routes through the exact same
# AppState.activate_story_subject(...) path as every other 3D subject.
#
# NOT YET PORTED (later items): authored routed movement/behavior trees,
# tunnel-interior visibility, and model-per-resident customization. Residents
# currently wander locally around their landmark anchor and use a Label3D balloon.

const HUMAN_BODY_3D_SCENE: PackedScene = preload("res://characters/human_body_3d.tscn")
const STORY_SUBJECT_3D := preload("res://game/story_subject_3d.gd")
const SPEECH_BALLOON_3D := preload("res://common/gui/speech_balloon_3d.gd")
const RESIDENT_CONTROLLER_3D := preload("res://characters/control/resident_controller_3d.gd")
const CHARACTER_MODEL_CATALOG := preload("res://characters/character_model_catalog_3d.gd")
const STORY_SUBJECT_GROUP := "story_subject_3d"
# Node name the world scene looks up to surface a resident's dialogue line.
const BALLOON_NODE_NAME := "Balloon3D"

# Resident talk range (XZ), used by the world scene's proximity picker.
const RESIDENT_TALK_RADIUS := 2.6
# Calm stroll pace and how far residents wander from their spawn anchor.
const RESIDENT_WALK_SPEED := 4.0
const RESIDENT_WANDER_RADIUS := 5.0


func spawn_residents(world_root: Node3D, app_state: Node, landmark_nodes: Dictionary) -> Node3D:
	if Engine.is_editor_hint():
		return null
	if !is_instance_valid(world_root) or app_state == null:
		return null

	var resident_root := Node3D.new()
	resident_root.name = "Residents"
	world_root.add_child(resident_root)

	# Fan residents that share an anchor around a small ring so they do not overlap.
	var anchor_counts: Dictionary = {}

	for resident_id_value in app_state.get_resident_ids():
		var resident_id := String(resident_id_value)
		var resident_definition = app_state.get_resident_definition(resident_id)
		if resident_definition == null:
			continue

		var spawn_config: Dictionary = app_state.get_resident_spawn_config(resident_id)
		var anchor_id := String(spawn_config.get("anchor_id", ""))
		var anchor_node := _resolve_anchor_landmark(anchor_id, landmark_nodes)
		if !is_instance_valid(anchor_node):
			continue

		var npc := HUMAN_BODY_3D_SCENE.instantiate() as HumanBody3D
		if npc == null:
			continue
		npc.name = "Resident_%s" % resident_id
		if "direction" in npc:
			npc.set("direction", float(spawn_config.get("direction", 0.0)))

		resident_root.add_child(npc)
		npc.character_model_scene = CHARACTER_MODEL_CATALOG.resolve_resident_model(resident_definition)

		var ring_index := int(anchor_counts.get(anchor_id, 0))
		anchor_counts[anchor_id] = ring_index + 1
		npc.global_position = anchor_node.global_position + _ring_offset(ring_index)

		_attach_wander_controller(npc)
		_attach_talk_subject(npc, resident_id, app_state)
		_attach_speech_balloon(npc)

	return resident_root


# Resident anchors are landmark names ("Piano Ferry") or landmark-scoped points
# ("Bi Shan Tunnel South Portal"). Match the base landmark by longest name prefix
# so tunnel entry/portal anchors cluster at their tunnel proxy until 3D tunnel
# interiors exist.
func _resolve_anchor_landmark(anchor_id: String, landmark_nodes: Dictionary) -> Node3D:
	if landmark_nodes.has(anchor_id):
		return landmark_nodes[anchor_id] as Node3D

	var best_name := ""
	for landmark_name in landmark_nodes.keys():
		var name_string := String(landmark_name)
		if anchor_id.begins_with(name_string) and name_string.length() > best_name.length():
			best_name = name_string
	if best_name.is_empty():
		return landmark_nodes.get("Piano Ferry") as Node3D
	return landmark_nodes[best_name] as Node3D


func _ring_offset(index: int) -> Vector3:
	if index <= 0:
		return Vector3(1.4, 0.0, 1.4)
	var angle := deg_to_rad(40.0 * float(index))
	var radius := 2.0 + 0.35 * float(index)
	return Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)


func _attach_talk_subject(npc: Node3D, resident_id: String, app_state: Node) -> void:
	var subject := STORY_SUBJECT_3D.new() as Area3D
	subject.name = "TalkSubject"
	subject.set("subject_id", "npc:%s" % resident_id)
	subject.set("story_action", "talk")
	subject.set("display_name", app_state.get_resident_display_name(resident_id))
	subject.set("interaction_radius", RESIDENT_TALK_RADIUS)
	npc.add_child(subject)
	subject.add_to_group(STORY_SUBJECT_GROUP)


func _attach_wander_controller(npc: Node3D) -> void:
	if "walk_speed" in npc:
		npc.set("walk_speed", RESIDENT_WALK_SPEED)
	var controller := RESIDENT_CONTROLLER_3D.new()
	# Assigning the controller runs HumanBody3D._setup_controller, binding m_character.
	npc.set("controller", controller)
	if controller.has_method("configure"):
		controller.configure(npc.global_position, RESIDENT_WANDER_RADIUS)


func _attach_speech_balloon(npc: Node3D) -> void:
	var balloon := SPEECH_BALLOON_3D.new() as Node3D
	balloon.name = BALLOON_NODE_NAME
	npc.add_child(balloon)
	# Float above the resident's head; body_height defaults to ~1.6.
	balloon.position = Vector3(0.0, 2.2, 0.0)
