# MarbleDampingArea.gd
@tool
class_name MarbleDampingArea
extends Area2D

## Linear damping contribution while a MarbleBall is inside this area.
@export var linear_damp_contribution: float = 3.0

## Angular damping contribution while a MarbleBall is inside this area.
@export var angular_damp_contribution: float = 3.0

## If true, prints enter/exit contribution events.
@export var print_debug: bool = false


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	var ball := body as MarbleBall
	if ball == null:
		return

	var area_id := int(get_instance_id())
	ball.add_damping_contribution(area_id, linear_damp_contribution, angular_damp_contribution)

	if print_debug:
		print("[MarbleDampingArea] Enter ", ball.name,
			" +(", linear_damp_contribution, ", ", angular_damp_contribution, ") area=", name)


func _on_body_exited(body: Node2D) -> void:
	var ball := body as MarbleBall
	if ball == null:
		return

	var area_id := int(get_instance_id())
	ball.remove_damping_contribution(area_id)

	if print_debug:
		print("[MarbleDampingArea] Exit  ", ball.name, " area=", name)
