@tool
class_name TerrainWaterLayerSetup
extends RefCounted

const WATER_TILESET := preload("res://resources/tilesets/terrain_0_tiles.tres")
const WATER_MATERIAL := preload("res://resources/materials/water.tres")


static func configure_layer(layer: TileMapLayer, position: Vector2 = Vector2.ZERO) -> void:
	if not is_instance_valid(layer):
		return

	layer.visible = true
	layer.enabled = true
	layer.y_sort_enabled = true
	layer.z_index = 0
	layer.position = position
	layer.rotation = 0.0
	layer.scale = Vector2.ONE
	layer.modulate = Color.WHITE
	layer.self_modulate = Color.WHITE
	layer.material = WATER_MATERIAL
	layer.use_parent_material = false
	layer.show_behind_parent = false
	layer.top_level = false
	layer.tile_set = WATER_TILESET
	layer.set_script(null)
