extends Node3D

const CAMERA_CONTROLLER_SCRIPT := preload("res://godot_common/scenes/camera_3d_controller.gd")
const FADE_AMOUNT := 0.65

var m_failures: Array[String] = []
var m_camera: Camera3D
var m_target: StaticBody3D
var m_target_mesh: MeshInstance3D
var m_controller: Camera3DController
var m_front_occluder: StaticBody3D
var m_front_mesh: MeshInstance3D
var m_rear_occluder: StaticBody3D
var m_rear_mesh: MeshInstance3D


func _ready() -> void:
	_build_test_world()
	call_deferred("_run")


func _build_test_world() -> void:
	m_target = _create_box_body("Target", Vector3.ZERO, Vector3.ONE)
	m_target_mesh = m_target.get_node("Mesh") as MeshInstance3D

	m_front_occluder = _create_box_body(
		"FrontOccluder",
		Vector3(0.0, 0.5, 6.0),
		Vector3(3.0, 3.0, 0.5)
	)
	m_front_mesh = m_front_occluder.get_node("Mesh") as MeshInstance3D

	m_rear_occluder = _create_box_body(
		"RearOccluder",
		Vector3(0.0, 0.25, 3.0),
		Vector3(2.0, 2.0, 0.5)
	)
	m_rear_mesh = m_rear_occluder.get_node("Mesh") as MeshInstance3D
	m_rear_mesh.transparency = 0.2

	m_camera = Camera3D.new()
	m_camera.name = "Camera3D"
	m_camera.current = true
	add_child(m_camera)

	m_controller = CAMERA_CONTROLLER_SCRIPT.new()
	m_controller.name = "Camera3DController"
	m_controller.camera = m_camera
	m_controller.target_node = m_target
	m_controller.follow_offset = Vector3(0.0, 1.0, 10.0)
	m_controller.look_at_offset = Vector3.ZERO
	m_controller.can_pan = false
	m_controller.can_zoom = false
	m_controller.can_rotate = false
	m_controller.occluder_transparency = FADE_AMOUNT
	m_controller.occluder_fade_duration = 0.0
	m_controller.occluder_restore_duration = 0.0
	add_child(m_controller)
	m_controller.snap_to_target()


func _create_box_body(body_name: String, position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = body_name
	body.position = position
	add_child(body)

	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	body.add_child(mesh)

	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	collision_shape.shape = box_shape
	body.add_child(collision_shape)
	return body


func _run() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame

	_assert_float("front blocker fades", m_front_mesh.transparency, FADE_AMOUNT)
	_assert_float("rear blocker also fades", m_rear_mesh.transparency, FADE_AMOUNT)
	_assert_float("target geometry stays opaque", m_target_mesh.transparency, 0.0)

	m_front_occluder.position.x = 5.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	_assert_float("cleared blocker restores its original transparency", m_front_mesh.transparency, 0.0)
	_assert_float("remaining blocker stays faded", m_rear_mesh.transparency, FADE_AMOUNT)

	m_controller.auto_transparency_enabled = false
	await get_tree().physics_frame
	_assert_float("disabling restores pre-transparent geometry", m_rear_mesh.transparency, 0.2)

	m_controller.auto_transparency_enabled = true
	await get_tree().physics_frame
	_assert_float("re-enabling fades the blocker again", m_rear_mesh.transparency, FADE_AMOUNT)

	var alternate_camera := Camera3D.new()
	alternate_camera.name = "AlternateCamera3D"
	add_child(alternate_camera)
	alternate_camera.current = true
	await get_tree().physics_frame
	_assert_float("an inactive camera restores its blockers", m_rear_mesh.transparency, 0.2)

	if m_failures.is_empty():
		print("PASS: Camera3DController occlusion transparency")
	else:
		for failure in m_failures:
			push_error(failure)
	get_tree().quit(0 if m_failures.is_empty() else 1)


func _assert_float(label: String, actual: float, expected: float) -> void:
	if is_equal_approx(actual, expected):
		print("PASS: %s" % label)
		return
	m_failures.append("%s. Expected %0.3f, got %0.3f." % [label, expected, actual])
