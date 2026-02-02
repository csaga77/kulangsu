@tool
class_name Room
extends AutoVisibilityNode2D

@export var level := 0:
	set(new_level):
		if level == new_level:
			return
		level = new_level
		_update_level()

@onready var m_physics_layer :TileMapLayer = $physics_layer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super._ready()
	_update_level()

func _update_level() -> void:
	if m_physics_layer == null:
		return
	for cell in m_physics_layer.get_used_cells():
		var source_id = m_physics_layer.get_cell_source_id(cell)
		var alternative_tile = m_physics_layer.get_cell_alternative_tile(cell)
		var coords = m_physics_layer.get_cell_atlas_coords(cell)
		coords.x = level
		m_physics_layer.set_cell(cell, source_id, coords, alternative_tile)
