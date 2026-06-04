@tool
extends Node3D

const BaseController3DScript = preload("res://characters/control/base_controller_3d.gd")

@onready var m_actor: CharacterBody3D = $human_body_3d
@onready var m_camera: Camera3D = $Camera3D


func _ready() -> void:
	if is_instance_valid(m_camera):
		m_camera.look_at(Vector3(0.0, 0.9, 0.0), Vector3.UP)

	if Engine.is_editor_hint():
		return

	call_deferred("_run_smoke_checks")


func _run_smoke_checks() -> void:
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
	m_actor.set("contact_shadow_radius", 0.44)
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
	else:
		for part_name in ["LeftArm", "RightArm", "FaceMarker", "DirectionMarker"]:
			if visual_root.get_node_or_null(part_name) == null:
				failures.append("HumanBody3D did not create %s" % part_name)
	if m_actor.get_node_or_null("ContactShadow") == null:
		failures.append("HumanBody3D did not create ContactShadow")

	m_actor.set_direction_vector(Vector3(0.0, 0.0, 1.0))
	m_actor.is_walking = true
	m_actor.is_running = false
	if m_actor.get_current_animation_name() != "walk-s":
		failures.append("expected walk-s animation state")

	m_actor.is_running = true
	if m_actor.get_current_animation_name() != "run-s":
		failures.append("expected run-s animation state")

	if visual_root != null:
		m_actor.call("_process_visual_motion", 0.11)
		if visual_root.position.y <= 0.0:
			failures.append("procedural movement bob did not lift VisualRoot")
		var left_leg := visual_root.get_node_or_null("LeftLeg") as MeshInstance3D
		if left_leg == null or is_equal_approx(left_leg.rotation.x, 0.0):
			failures.append("procedural movement did not swing the legs")

	m_actor.move_with_speed(Vector3(1.0, 0.0, 0.0), 2.0)
	if m_actor.velocity.x <= 0.0:
		failures.append("move_with_speed did not apply positive x velocity")

	m_actor.jump()
	if !m_actor.get_current_animation_name().begins_with("jump-"):
		failures.append("jump did not switch animation state")

	var ground_rect: Rect2 = m_actor.get_ground_rect()
	if ground_rect.size.x <= 0.0 or ground_rect.size.y <= 0.0:
		failures.append("ground rect has invalid size")
	if !is_equal_approx(ground_rect.size.x, 0.64) or !is_equal_approx(ground_rect.size.y, 0.64):
		failures.append("ground rect did not reflect tuned body radius")
