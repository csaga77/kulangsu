extends Node2D

@onready var m_wall := $wall

func set_trans_rect(rect):
	m_wall.trans_rect = rect
	#m_wall.notify_runtime_tile_data_update()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
