class_name PlayerController
extends Node

@export var player :Player

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if player != null:
		var new_direction_vector = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		if new_direction_vector.is_zero_approx():
			player.is_walking = false
			player.velocity = Vector2.ZERO
		else:
			player.direction = rad_to_deg(-new_direction_vector.angle())
			player.is_walking = true
			player.is_running = Input.is_action_pressed("ui_run")
			player.velocity = new_direction_vector * (200 if player.is_running else 100)
			player.move_and_slide()
