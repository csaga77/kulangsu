@tool
extends Node3D

const BaseController3DScript = preload("res://characters/control/base_controller_3d.gd")
const PlayerController3DScript = preload("res://characters/control/player_controller_3d.gd")
const REQUIRED_ACTION_FALLBACKS: Array[String] = [
	"generated_fallbacks/fallback_carry_hold",
	"generated_fallbacks/fallback_object_brace",
	"generated_fallbacks/fallback_sit_enter",
	"generated_fallbacks/fallback_sit_idle",
	"generated_fallbacks/fallback_sit_exit",
]
const REQUIRED_PLAYER_MODEL_PATHS: Array[String] = [
	"res://assets/characters/male.glb",
	"res://assets/characters/female.glb",
	"res://assets/characters/boy.glb",
]
const REMOVED_ACCESSORY_PROPERTIES: Array[StringName] = [
	&"use_hair_model",
	&"hair_model_scene",
	&"use_pants_model",
	&"pants_model_scene",
	&"pants_skinned",
	&"use_jacket_model",
	&"jacket_model_scene",
]
const REMOVED_ACCESSORY_NODES: Array[String] = [
	"HairAttachment",
	"HairModel",
	"PantsAttachment",
	"PantsModel",
	"PantsSkinnedMesh",
	"JacketAttachment",
	"JacketModel",
]

@onready var m_actor: CharacterBody3D = $human_body_3d
@onready var m_camera: Camera3D = $human_body_3d/Camera3D


func _ready() -> void:
	if is_instance_valid(m_camera):
		m_camera.look_at(Vector3(0.0, 0.9, 0.0), Vector3.UP)

	if Engine.is_editor_hint():
		return

	call_deferred("_run_smoke_checks")


func _run_smoke_checks() -> void:
	await get_tree().physics_frame

	var failures: Array[String] = []
	if !is_instance_valid(m_actor):
		failures.append("missing HumanBody3D actor")
	else:
		_validate_actor_api(failures)
		_validate_required_action_fallbacks_for_all_models(failures)

	if failures.is_empty():
		print("PASS: HumanBody3D adapter smoke test")
	else:
		for failure in failures:
			push_error(failure)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if failures.is_empty() else 1)


func _validate_actor_api(failures: Array[String]) -> void:
	var controller: Variant = m_actor.get("controller")
	if controller == null:
		failures.append("HumanBody3D test scene is missing PlayerController3D")
	elif !(controller is BaseController3DScript):
		failures.append("HumanBody3D controller does not extend BaseController3D")

	var sample_configuration := {
		"body_type": "male",
		"selections": {
			"body/body": "light",
			"feet/shoes/feet_shoes_basic": "brown",
		},
	}

	m_actor.set_configuration(sample_configuration)
	if m_actor.get_configuration() != sample_configuration:
		failures.append("configuration round trip failed")

	m_actor.set("body_height", 1.84)
	m_actor.set("body_radius", 0.32)
	var local_box: AABB = m_actor.get_local_bounding_box()
	if !is_equal_approx(local_box.size.y, 1.84):
		failures.append("body height export did not update local bounding box")
	if !is_equal_approx(local_box.size.x, 0.64):
		failures.append("body radius export did not update local bounding box")

	var collision_shape := m_actor.get_node_or_null("CollisionShape3D") as CollisionShape3D
	var capsule: CapsuleShape3D = null
	if collision_shape != null:
		capsule = collision_shape.shape as CapsuleShape3D
	if capsule == null:
		failures.append("HumanBody3D did not configure capsule collision")
	else:
		if !is_equal_approx(capsule.radius, 0.32):
			failures.append("body radius export did not update capsule radius")
		if !is_equal_approx(capsule.height, 1.84):
			failures.append("body height export did not update capsule height")

	var visual_root := m_actor.get_node_or_null("VisualRoot") as Node3D
	if visual_root == null:
		failures.append("HumanBody3D did not create VisualRoot")
	elif visual_root.get_node_or_null("DebugBox") == null:
		failures.append("HumanBody3D did not create the DebugBox under VisualRoot")

	m_actor.set_direction_vector(Vector3(0.0, 0.0, 1.0))
	m_actor.is_walking = true
	m_actor.is_running = false
	if !_matches_model_animation(m_actor.get_current_animation_name(), "walk"):
		failures.append("expected walk model animation")

	m_actor.is_running = true
	if !_matches_model_animation(m_actor.get_current_animation_name(), "run"):
		failures.append("expected run model animation")

	if visual_root != null:
		if not is_equal_approx(visual_root.position.y, 0.0):
			failures.append("VisualRoot should rest at y=0 while walking (no procedural bob)")
		_validate_character_model(failures, visual_root)

	m_actor.move_with_speed(Vector3(1.0, 0.0, 0.0), 2.0)
	if m_actor.velocity.x <= 0.0:
		failures.append("move_with_speed did not apply positive x velocity")

	_validate_player_controller_input_order(failures, controller)

	m_actor.velocity.y = -1.6
	m_actor.jump()
	if m_actor.is_grounded():
		failures.append("jump should suspend the grounded state")
	if !is_zero_approx(m_actor.velocity.y):
		failures.append("jump should clear the downward grounding velocity")
	m_actor.call("_process_jump", 0.275)
	if visual_root != null and visual_root.position.y < 0.47:
		failures.append("jump should visibly reach its configured apex")
	if (
		collision_shape != null
		and !is_equal_approx(collision_shape.position.y, float(m_actor.get("body_height")) * 0.5)
	):
		failures.append("jump should keep the grounded collision capsule planted")

	var ground_rect: Rect2 = m_actor.get_ground_rect()
	if ground_rect.size.x <= 0.0 or ground_rect.size.y <= 0.0:
		failures.append("ground rect has invalid size")
	if !is_equal_approx(ground_rect.size.x, 0.64) or !is_equal_approx(ground_rect.size.y, 0.64):
		failures.append("ground rect did not reflect tuned body radius")


func _validate_character_model(failures: Array[String], visual_root: Node3D) -> void:
	var model := visual_root.get_node_or_null("CharacterModel") as Node3D
	if model == null:
		failures.append("HumanBody3D did not instance the CharacterModel")
		return
	if not model.visible:
		failures.append("HumanBody3D character model is not visible")
	if model.get_child_count() == 0:
		failures.append("HumanBody3D character model has no instanced scene")
		return

	var mesh_instance := _find_mesh_instance(model)
	if mesh_instance == null or mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() <= 0:
		failures.append("HumanBody3D character model has no renderable mesh")
	elif mesh_instance.get_active_material(0) == null:
		failures.append("HumanBody3D character model is missing its material")

	var anim := _find_animation_player(model)
	if anim == null:
		failures.append("HumanBody3D character model has no AnimationPlayer")
	else:
		for clip in ["idle", "walk", "run"]:
			if not anim.has_animation(clip):
				failures.append("HumanBody3D character model is missing the %s animation" % clip)

	var skeleton := _find_skeleton(model)
	if skeleton == null:
		failures.append("HumanBody3D character model has no Skeleton3D")
		return
	_validate_single_model_visual(failures, model)
	_validate_skeleton_debug(failures, skeleton)


func _validate_required_action_fallbacks_for_all_models(
	failures: Array[String]
) -> void:
	for model_path in REQUIRED_PLAYER_MODEL_PATHS:
		var model_scene := load(model_path) as PackedScene
		if model_scene == null:
			failures.append("could not load required player model %s" % model_path)
			continue
		m_actor.set("character_model_scene", model_scene)
		var model_root := m_actor.get_node_or_null(
			"VisualRoot/CharacterModel"
		) as Node3D
		var animation_player := _find_animation_player(model_root)
		if animation_player == null:
			failures.append("%s has no AnimationPlayer for action fallbacks" % model_path)
			continue
		for fallback_path in REQUIRED_ACTION_FALLBACKS:
			if !animation_player.has_animation(fallback_path):
				failures.append(
					"%s is missing required action fallback %s"
					% [model_path, fallback_path]
				)
				continue
			var fallback := animation_player.get_animation(fallback_path)
			if fallback == null or fallback.get_track_count() == 0:
				failures.append(
					"%s fallback %s contains no skeleton tracks"
					% [model_path, fallback_path]
				)
		var sit_entry := animation_player.get_animation(
			"generated_fallbacks/fallback_sit_enter"
		)
		var sit_exit := animation_player.get_animation(
			"generated_fallbacks/fallback_sit_exit"
		)
		if sit_entry == null or !is_equal_approx(sit_entry.length, 0.35):
			failures.append("%s sit entry fallback is not exactly 0.35 s" % model_path)
		if sit_exit == null or !is_equal_approx(sit_exit.length, 0.30):
			failures.append("%s sit exit fallback is not exactly 0.30 s" % model_path)


func _validate_single_model_visual(failures: Array[String], model: Node3D) -> void:
	var property_names: Dictionary[StringName, bool] = {}
	for property_data in m_actor.get_property_list():
		property_names[StringName(property_data.get("name", ""))] = true
	for property_name in REMOVED_ACCESSORY_PROPERTIES:
		if property_names.has(property_name):
			failures.append("HumanBody3D still exposes removed accessory property %s" % property_name)
	for node_name in REMOVED_ACCESSORY_NODES:
		if model.find_child(node_name, true, false) != null:
			failures.append("HumanBody3D still creates removed accessory node %s" % node_name)


func _validate_skeleton_debug(failures: Array[String], skeleton: Skeleton3D) -> void:
	if bool(m_actor.get("draw_skeleton_bones")):
		failures.append("HumanBody3D should not draw skeleton bones by default")

	m_actor.set("draw_skeleton_bones", true)
	var debug_part := skeleton.get_node_or_null("SkeletonDebug") as MeshInstance3D
	if debug_part == null:
		failures.append("HumanBody3D did not create the SkeletonDebug node when enabled")
	else:
		if not debug_part.visible:
			failures.append("HumanBody3D skeleton debug draw is not visible when enabled")
		var debug_mesh := debug_part.mesh as ImmediateMesh
		if debug_mesh == null or debug_mesh.get_surface_count() <= 0:
			failures.append("HumanBody3D skeleton debug draw produced no bone lines")
		m_actor.set("draw_skeleton_bones", false)
		if debug_part.visible:
			failures.append("HumanBody3D did not hide skeleton debug draw when disabled")


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _find_mesh_instance(child)
		if found != null:
			return found
	return null


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _matches_model_animation(actual_name: String, expected_name: String) -> bool:
	var actual_lower := actual_name.to_lower()
	var expected_lower := expected_name.to_lower()
	return actual_lower == expected_lower or actual_lower.ends_with("/" + expected_lower)


func _validate_player_controller_input_order(failures: Array[String], controller: Variant) -> void:
	if !(controller is PlayerController3DScript):
		return

	var original_position := m_actor.global_position
	var original_velocity := m_actor.velocity
	var original_is_walking := bool(m_actor.get("is_walking"))
	var original_is_running := bool(m_actor.get("is_running"))

	controller.call("stop_moving")
	m_actor.global_position = Vector3(0.0, 0.0, 0.0)
	m_actor.velocity = Vector3.ZERO
	Input.action_release("ui_right")

	Input.action_press("ui_right")
	controller.call("process", 1.0 / 60.0)
	var started_velocity := m_actor.velocity
	Input.action_release("ui_right")
	controller.call("process", 1.0 / 60.0)
	var stopped_velocity := m_actor.velocity

	if started_velocity.x <= 0.0:
		failures.append("PlayerController3D did not apply current-frame input before movement")
	if stopped_velocity.length_squared() > 0.000001:
		failures.append("PlayerController3D did not stop movement on current-frame release")

	controller.call("stop_moving")
	m_actor.global_position = original_position
	m_actor.velocity = original_velocity
	m_actor.set("is_walking", original_is_walking)
	m_actor.set("is_running", original_is_running)
