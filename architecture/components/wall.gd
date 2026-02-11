@tool
class_name Wall
extends IsometricBlock

@export var offset = 0:
	set(new_offset):
		if offset == new_offset:
			return
		offset = new_offset
		_update_tiles()

@onready var m_wall_block = $wall_block

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super._ready()
	_update_tiles()

func _update_tiles() -> void:
	if m_wall_block == null:
		return
	m_wall_block.position = Vector2(-12.0, -9.0) + Vector2(8.0, -4.0) * offset
