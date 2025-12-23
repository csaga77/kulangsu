extends Node2D

@onready var m_character := $Character

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	var new_direction_vector = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if new_direction_vector.is_zero_approx():
		m_character.is_walking = false
		m_character.velocity = Vector2.ZERO
	else:
		m_character.direction = rad_to_deg(-new_direction_vector.angle())
		m_character.is_walking = true
		m_character.is_running = Input.is_action_pressed("ui_run")
		m_character.velocity = new_direction_vector * (200 if m_character.is_running else 100)
		m_character.move_and_slide()
