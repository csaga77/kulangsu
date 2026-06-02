@tool
extends Node3D

@onready var m_camera: Camera3D = $Camera3D
@onready var m_sun: DirectionalLight3D = $Sun


func _ready() -> void:
	if is_instance_valid(m_camera):
		m_camera.look_at(Vector3.ZERO, Vector3.UP)
	if is_instance_valid(m_sun):
		m_sun.look_at(Vector3(-20.0, -18.0, -8.0), Vector3.UP)
