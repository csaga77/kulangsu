@tool
extends Node3D

const BaseController3DScript = preload(
	"res://characters/control/base_controller_3d.gd"
)

@export var building_scene: PackedScene = preload(
	"res://architecture/bagua_tower/bagua_tower_stylized_3d.tscn"
):
	set(value):
		building_scene = value
		_queue_building_refresh()

@export var building_transform := Transform3D.IDENTITY:
	set(value):
		building_transform = value
		_queue_building_refresh()

@export var player_spawn := Vector3(0.0, 0.08, -7.0):
	set(value):
		player_spawn = value
		if is_instance_valid(m_player):
			m_player.global_position = player_spawn

@onready var m_building_container: Node3D = $BuildingContainer
@onready var m_player: CharacterBody3D = $Player
@onready var m_camera: Camera3D = $Camera3D
@onready var m_camera_controller: Node = $Camera3DController

var m_building_instance: Node3D = null
var m_building_refresh_queued := false


func _ready() -> void:
	_rebuild_building()
	m_player.global_position = player_spawn
	m_camera.current = true
	if Engine.is_editor_hint():
		return
	# Run after Camera3DController so the test keeps its orbit/zoom behavior but
	# does not move the entire frame vertically when the player jumps.
	process_priority = 1
	m_camera_controller.call_deferred("snap_to_target")
	call_deferred("_run_smoke_check")


func _process(_delta: float) -> void:
	_lock_camera_vertical_follow()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
		get_viewport().set_input_as_handled()


func _queue_building_refresh() -> void:
	if !is_inside_tree() or m_building_refresh_queued:
		return
	m_building_refresh_queued = true
	call_deferred("_rebuild_building")


func _rebuild_building() -> void:
	m_building_refresh_queued = false
	if !is_instance_valid(m_building_container):
		return
	for child in m_building_container.get_children():
		m_building_container.remove_child(child)
		child.queue_free()
	m_building_instance = null
	if building_scene == null:
		return
	var instance := building_scene.instantiate() as Node3D
	if instance == null:
		push_error("Environment fixture root must inherit Node3D.")
		return
	instance.name = "BuildingUnderTest"
	instance.transform = building_transform
	m_building_container.add_child(instance)
	m_building_instance = instance


func _lock_camera_vertical_follow() -> void:
	if Engine.is_editor_hint():
		return
	if (
		!is_instance_valid(m_player)
		or !is_instance_valid(m_camera)
		or !is_instance_valid(m_camera_controller)
	):
		return
	var follow_offset: Vector3 = m_camera_controller.get("follow_offset")
	var look_at_offset: Vector3 = m_camera_controller.get("look_at_offset")
	var camera_position := m_camera.global_position
	camera_position.y = player_spawn.y + follow_offset.y
	m_camera.global_position = camera_position
	var look_at_position := m_player.global_position
	look_at_position.y = player_spawn.y
	m_camera.look_at(look_at_position + look_at_offset, Vector3.UP)


func _run_smoke_check() -> void:
	var failures: Array[String] = []
	if !is_instance_valid(m_building_instance):
		failures.append("missing building under test")
	if !is_instance_valid(m_player):
		failures.append("missing HumanBody3D player")
	elif !(m_player.get("controller") is BaseController3DScript):
		failures.append("player is missing PlayerController3D")
	if !is_instance_valid(m_camera) or !m_camera.current:
		failures.append("environment test camera is not active")
	if $Ground/StaticBody3D/CollisionShape3D.shape == null:
		failures.append("environment test ground is missing collision")

	if failures.is_empty():
		print(
			"PASS: Environment test scene (%s)"
			% building_scene.resource_path
		)
		if DisplayServer.get_name() == "headless":
			get_tree().quit(0)
		return
	for failure in failures:
		push_error(failure)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1)
