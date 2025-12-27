extends TileMapLayer
@export var trans_rect :Rect2

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var shader_material :ShaderMaterial = material
	shader_material.set_shader_parameter("trans_rect_pos", trans_rect.position)
	shader_material.set_shader_parameter("trans_rect_size", trans_rect.size)

func _use_tile_data_runtime_update(coords: Vector2i) -> bool:
	return false

func _tile_data_runtime_update(coords: Vector2i, tile_data: TileData) -> void:
	if trans_rect.has_point(to_global(map_to_local(coords))):
		tile_data.modulate = Color(1, 1, 1, 0.5)
	else:
		tile_data.modulate = Color(1, 1, 1, 1.0)
