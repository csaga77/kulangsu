@tool
class_name Room
extends AutoVisibilityNode2D

@export var level := 0:
	set(new_level):
		if level == new_level:
			return
		level = new_level
		_update_level()
		
@export var physics_layers : Array [TileMapLayer]
@export var rooms : Array [Room]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super._ready()
	_update_level()

func _update_level() -> void:
	for physics_layer in physics_layers:
		for cell in physics_layer.get_used_cells():
			var source_id = physics_layer.get_cell_source_id(cell)
			var alternative_tile = physics_layer.get_cell_alternative_tile(cell)
			var coords = physics_layer.get_cell_atlas_coords(cell)
			coords.x = level
			physics_layer.set_cell(cell, source_id, coords, alternative_tile)
	var ancestors_to_remove := []
	for room in rooms:
		if CommonUtils.is_ancestor(room, self):
			ancestors_to_remove.append(room)
			continue
		room.level = level
	if !ancestors_to_remove.is_empty():
		print("Warning: do not assign acestor rooms to children rooms! " + self.name)
		for ancestor in ancestors_to_remove:
			rooms.erase(ancestor)
