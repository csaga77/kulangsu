class_name CharacterController
extends Node

@export var character :Character

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if character != null:
		var new_direction_vector = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		if new_direction_vector.is_zero_approx():
			character.is_walking = false
			character.velocity = Vector2.ZERO
		else:
			character.direction = rad_to_deg(-new_direction_vector.angle())
			character.is_walking = true
			character.is_running = Input.is_action_pressed("ui_run")
			character.velocity = new_direction_vector * (200 if character.is_running else 100)
			character.move_and_slide()
