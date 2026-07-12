@tool
class_name MarbleDampingArea
extends Area3D

@export var linear_damp_contribution: float = 2.4
@export var angular_damp_contribution: float = 2.0
@export var debug_logging_enabled: bool = false


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	var ball := body as MarbleBall
	if ball == null:
		return
	var area_id: int = int(get_instance_id())
	ball.add_damping_contribution(area_id, linear_damp_contribution, angular_damp_contribution)
	if debug_logging_enabled:
		print("[MarbleDampingArea] Enter ", ball.name, " area=", name)


func _on_body_exited(body: Node3D) -> void:
	var ball := body as MarbleBall
	if ball == null:
		return
	var area_id: int = int(get_instance_id())
	ball.remove_damping_contribution(area_id)
	if debug_logging_enabled:
		print("[MarbleDampingArea] Exit ", ball.name, " area=", name)
