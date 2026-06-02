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

	m_actor.set_direction_vector(Vector3(0.0, 0.0, 1.0))
	m_actor.is_walking = true
	m_actor.is_running = false
	if m_actor.get_current_animation_name() != "walk-s":
		failures.append("expected walk-s animation state")

	m_actor.is_running = true
	if m_actor.get_current_animation_name() != "run-s":
		failures.append("expected run-s animation state")

	m_actor.move_with_speed(Vector3(1.0, 0.0, 0.0), 2.0)
	if m_actor.velocity.x <= 0.0:
		failures.append("move_with_speed did not apply positive x velocity")

	m_actor.jump()
	if !m_actor.get_current_animation_name().begins_with("jump-"):
		failures.append("jump did not switch animation state")

	var ground_rect: Rect2 = m_actor.get_ground_rect()
	if ground_rect.size.x <= 0.0 or ground_rect.size.y <= 0.0:
		failures.append("ground rect has invalid size")
