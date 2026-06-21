@tool
extends Node3D

const BaseController3DScript = preload("res://characters/control/base_controller_3d.gd")
const PlayerController3DScript = preload("res://characters/control/player_controller_3d.gd")
const STEP_FIXTURE_HEIGHT := 0.30
const STEP_UP_START := Vector3(11.65, 0.0, 0.0)
const STEP_UP_MOTION := Vector3(0.80, 0.0, 0.0)
const BLOCKED_STEP_START := Vector3(31.65, 0.0, 0.0)
const BLOCKED_STEP_MOTION := Vector3(0.80, 0.0, 0.0)
const BLOCKED_STEP_TARGET := BLOCKED_STEP_START + BLOCKED_STEP_MOTION + Vector3(0.0, STEP_FIXTURE_HEIGHT, 0.0)
const STEP_DOWN_START := Vector3(42.0, STEP_FIXTURE_HEIGHT, 0.0)
const STEP_DOWN_MOTION := Vector3(0.90, 0.0, 0.0)

@onready var m_actor: CharacterBody3D = $human_body_3d
@onready var m_camera: Camera3D = $human_body_3d/Camera3D


func _ready() -> void:
	if is_instance_valid(m_camera):
		m_camera.look_at(Vector3(0.0, 0.9, 0.0), Vector3.UP)

	if Engine.is_editor_hint():
		return

	_ensure_navigation_fixtures()
	call_deferred("_run_smoke_checks")


func _run_smoke_checks() -> void:
	await get_tree().physics_frame

	var failures: Array[String] = []
	if !is_instance_valid(m_actor):
		failures.append("missing HumanBody3D actor")
	else:
		_validate_actor_api(failures)

	if failures.is_empty():
		print("PASS: HumanBody3D adapter smoke test")
	else:
		for failure in failures:
			push_error(failure)


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
			"hair/short/hair_bangs": "chestnut",
			"legs/pants/legs_pants": "charcoal",
			"torso/shirts/longsleeve/torso_clothes_longsleeve": "teal",
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
	if m_actor.get_current_animation_name() != "walk-s":
		failures.append("expected walk-s animation state")

	m_actor.is_running = true
	if m_actor.get_current_animation_name() != "run-s":
		failures.append("expected run-s animation state")

	if visual_root != null:
		if not is_equal_approx(visual_root.position.y, 0.0):
			failures.append("VisualRoot should rest at y=0 while walking (no procedural bob)")
		_validate_character_model(failures, visual_root)

	m_actor.move_with_speed(Vector3(1.0, 0.0, 0.0), 2.0)
	if m_actor.velocity.x <= 0.0:
		failures.append("move_with_speed did not apply positive x velocity")

	_validate_player_controller_input_order(failures, controller)
	_validate_step_navigation(failures)

	m_actor.jump()
	if !m_actor.get_current_animation_name().begins_with("jump-"):
		failures.append("jump did not switch animation state")

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

	_validate_hair_model(failures, model)


func _validate_hair_model(failures: Array[String], model: Node3D) -> void:
	if not bool(m_actor.get("use_hair_model")):
		failures.append("HumanBody3D should default to using the hair model")

	var skeleton := _find_skeleton(model)
	if skeleton == null:
		failures.append("HumanBody3D character model has no Skeleton3D for hair attachment")
		return

	var attach_bone := String(m_actor.get("hair_attach_bone"))
	if skeleton.find_bone(attach_bone) < 0:
		failures.append("HumanBody3D hair attach bone '%s' is missing from the skeleton" % attach_bone)
		return

	var attachment := skeleton.get_node_or_null("HairAttachment") as BoneAttachment3D
	if attachment == null:
		failures.append("HumanBody3D did not create the hair BoneAttachment3D")
		return
	if attachment.bone_name != attach_bone:
		failures.append("HumanBody3D hair attachment is bound to the wrong bone")

	var hair_model := attachment.get_node_or_null("HairModel") as Node3D
	if hair_model == null:
		failures.append("HumanBody3D did not create the separate HairModel node")
		return
	if not hair_model.visible:
		failures.append("HumanBody3D hair model is not visible")
	if hair_model.get_child_count() == 0:
		failures.append("HumanBody3D hair model has no instanced scene")
		return
	if _find_mesh_instance(hair_model) == null:
		failures.append("HumanBody3D hair model has no renderable mesh")

	# Toggling use_hair_model off should hide the hair node.
	m_actor.set("use_hair_model", false)
	if hair_model.visible:
		failures.append("HumanBody3D did not hide the hair model when use_hair_model is off")
	m_actor.set("use_hair_model", true)
	if not hair_model.visible:
		failures.append("HumanBody3D did not re-show the hair model when use_hair_model is on")

	_validate_pants_model(failures, model, skeleton)
	_validate_jacket_model(failures, model, skeleton)
	_validate_skeleton_debug(failures, skeleton)


func _validate_pants_model(failures: Array[String], _model: Node3D, skeleton: Skeleton3D) -> void:
	if not bool(m_actor.get("use_pants_model")):
		failures.append("HumanBody3D should default to using the pants model")
	if not bool(m_actor.get("pants_skinned")):
		failures.append("HumanBody3D pants should default to skinned so they animate with the legs")

	var skinned := skeleton.get_node_or_null("PantsSkinnedMesh") as MeshInstance3D
	if skinned == null:
		failures.append("HumanBody3D did not create the skinned PantsSkinnedMesh under the skeleton")
		return
	if not skinned.visible:
		failures.append("HumanBody3D skinned pants mesh is not visible")

	var pants_mesh := skinned.mesh
	if pants_mesh == null or pants_mesh.get_surface_count() <= 0:
		failures.append("HumanBody3D skinned pants mesh has no surfaces")
		return
	if (pants_mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_BONES) == 0:
		failures.append("HumanBody3D skinned pants mesh has no per-vertex bone weights")
	if (pants_mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_WEIGHTS) == 0:
		failures.append("HumanBody3D skinned pants mesh has no per-vertex weights")

	var skin := skinned.skin
	if skin == null or skin.get_bind_count() <= 0:
		failures.append("HumanBody3D skinned pants mesh has no skin binds")
		return

	var bound_to_legs := false
	for bind_index in range(skin.get_bind_count()):
		var bind_name := String(skin.get_bind_name(bind_index))
		if bind_name == "":
			var bone_index := skin.get_bind_bone(bind_index)
			if bone_index >= 0:
				bind_name = skeleton.get_bone_name(bone_index)
		if bind_name in ["L_Thigh", "R_Thigh", "L_Calf", "R_Calf"]:
			bound_to_legs = true
	if not bound_to_legs:
		failures.append("HumanBody3D skinned pants are not bound to any leg bones")

	# Toggling use_pants_model off should hide the skinned pants.
	m_actor.set("use_pants_model", false)
	if skinned.visible:
		failures.append("HumanBody3D did not hide the skinned pants when use_pants_model is off")
	m_actor.set("use_pants_model", true)
	var skinned_again := skeleton.get_node_or_null("PantsSkinnedMesh") as MeshInstance3D
	if skinned_again == null or not skinned_again.visible:
		failures.append("HumanBody3D did not re-show the skinned pants when use_pants_model is on")


func _validate_jacket_model(failures: Array[String], _model: Node3D, skeleton: Skeleton3D) -> void:
	if not bool(m_actor.get("use_jacket_model")):
		failures.append("HumanBody3D should default to using the jacket model")

	var attach_bone := String(m_actor.get("jacket_attach_bone"))
	if skeleton.find_bone(attach_bone) < 0:
		failures.append("HumanBody3D jacket attach bone '%s' is missing from the skeleton" % attach_bone)
		return

	var attachment := skeleton.get_node_or_null("JacketAttachment") as BoneAttachment3D
	if attachment == null:
		failures.append("HumanBody3D did not create the jacket BoneAttachment3D")
		return
	if attachment.bone_name != attach_bone:
		failures.append("HumanBody3D jacket attachment is bound to the wrong bone")

	var jacket_model := attachment.get_node_or_null("JacketModel") as Node3D
	if jacket_model == null:
		failures.append("HumanBody3D did not create the separate JacketModel node")
		return
	if not jacket_model.visible:
		failures.append("HumanBody3D jacket model is not visible")
	if jacket_model.get_child_count() == 0:
		failures.append("HumanBody3D jacket model has no instanced scene")
		return
	if _find_mesh_instance(jacket_model) == null:
		failures.append("HumanBody3D jacket model has no renderable mesh")

	# Toggling use_jacket_model off should hide the jacket node.
	m_actor.set("use_jacket_model", false)
	if jacket_model.visible:
		failures.append("HumanBody3D did not hide the jacket model when use_jacket_model is off")
	m_actor.set("use_jacket_model", true)
	if not jacket_model.visible:
		failures.append("HumanBody3D did not re-show the jacket model when use_jacket_model is on")


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


func _validate_step_navigation(failures: Array[String]) -> void:
	var original_position := m_actor.global_position
	var original_velocity := m_actor.velocity
	var original_max_step_height := float(m_actor.get("max_step_height"))
	var original_floor_snap_distance := float(m_actor.get("floor_snap_distance"))

	m_actor.set("max_step_height", 0.45)
	m_actor.set("floor_snap_distance", 0.50)
	m_actor.velocity = Vector3.ZERO

	if !bool(m_actor.call("_can_place_body_at", STEP_UP_START)):
		failures.append("HumanBody3D placement query rejected a clear floor position")
	if bool(m_actor.call("_can_place_body_at", BLOCKED_STEP_TARGET)):
		failures.append("HumanBody3D placement query accepted an occupied step position")

	m_actor.global_position = STEP_UP_START
	var stepped_up := bool(m_actor.call("_snap_to_walkable_step_floor", STEP_UP_START, STEP_UP_MOTION, Vector3.RIGHT))
	if !stepped_up:
		failures.append("HumanBody3D did not snap up onto a walkable low step")
	elif absf(m_actor.global_position.y - STEP_FIXTURE_HEIGHT) > 0.02:
		failures.append("HumanBody3D step-up snap used the wrong floor height")

	m_actor.global_position = BLOCKED_STEP_START
	var blocked_step := bool(m_actor.call(
		"_snap_to_walkable_step_floor",
		BLOCKED_STEP_START,
		BLOCKED_STEP_MOTION,
		Vector3.RIGHT
	))
	if blocked_step or m_actor.global_position.y > 0.05:
		failures.append("HumanBody3D snapped into or onto an occupied step target")

	m_actor.global_position = STEP_DOWN_START
	var stepped_down := bool(m_actor.call("_snap_to_walkable_step_floor", STEP_DOWN_START, STEP_DOWN_MOTION, Vector3.RIGHT))
	if !stepped_down:
		failures.append("HumanBody3D did not snap down to a walkable lower floor")
	elif absf(m_actor.global_position.y) > 0.02:
		failures.append("HumanBody3D step-down snap used the wrong floor height")
	if m_actor.has_method("is_grounded") and !bool(m_actor.call("is_grounded")):
		failures.append("HumanBody3D did not report grounded after a manual step-down snap")

	m_actor.global_position = original_position
	m_actor.velocity = original_velocity
	m_actor.set("max_step_height", original_max_step_height)
	m_actor.set("floor_snap_distance", original_floor_snap_distance)


func _ensure_navigation_fixtures() -> void:
	if get_node_or_null("NavigationFixtures") != null:
		return

	var root := Node3D.new()
	root.name = "NavigationFixtures"
	add_child(root)

	_add_static_box_fixture(root, "StepUpBaseFloor", Vector3(6.0, 0.10, 3.0), Vector3(12.0, -0.05, 0.0))
	_add_static_box_fixture(root, "StepUpBlock", Vector3(1.40, STEP_FIXTURE_HEIGHT, 2.0), Vector3(12.75, STEP_FIXTURE_HEIGHT * 0.5, 0.0))
	_add_static_box_fixture(root, "BlockedBaseFloor", Vector3(6.0, 0.10, 3.0), Vector3(32.0, -0.05, 0.0))
	_add_static_box_fixture(root, "BlockedStepBlock", Vector3(1.40, STEP_FIXTURE_HEIGHT, 2.0), Vector3(32.75, STEP_FIXTURE_HEIGHT * 0.5, 0.0))
	_add_static_box_fixture(root, "BlockedSideObstacle", Vector3(0.90, 1.60, 0.40), Vector3(32.45, 0.80, 0.35))
	_add_static_box_fixture(root, "StepDownBaseFloor", Vector3(6.0, 0.10, 3.0), Vector3(42.0, -0.05, 0.0))
	_add_static_box_fixture(root, "StepDownPlatform", Vector3(1.20, STEP_FIXTURE_HEIGHT, 2.0), Vector3(41.85, STEP_FIXTURE_HEIGHT * 0.5, 0.0))


func _add_static_box_fixture(parent: Node, fixture_name: String, box_size: Vector3, center_position: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = fixture_name
	body.position = center_position
	parent.add_child(body)

	var shape := BoxShape3D.new()
	shape.size = box_size

	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	collision_shape.shape = shape
	body.add_child(collision_shape)
