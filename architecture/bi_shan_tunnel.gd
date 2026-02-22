@tool
class_name Tunnel
extends LevelNode2D

@onready var m_path_layer :TileMapLayer = $path

func mask_player(player_node: Node2D, bounding_rect: Rect2) -> bool:
	if player_node == null:
		return false
		
	if m_path_layer == null:
		return false
	
	# Player above this layer => ignore masking
	if CommonUtils.get_absolute_z_index(player_node) > CommonUtils.get_absolute_z_index(m_path_layer):
		return false

	return TileMapUtils.intersects_iso_grid_rect_global(m_path_layer, bounding_rect)

func _ready() -> void:
	super._ready()

func _process(delta: float) -> void:
	pass
