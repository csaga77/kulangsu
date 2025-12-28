extends Node2D

@onready var m_ferry := $ferry
@onready var m_character :Character = $Character
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var rect :Rect2
	#rect.position = m_character.global_position - Vector2(16, 48)
	#rect.size = Vector2(32, 64)
	
	rect.position = m_character.global_position - Vector2(16, 4)
	rect.size = Vector2(32, 32)
	m_ferry.set_trans_rect(rect)
