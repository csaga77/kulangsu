@tool
class_name TerrainMaskRule
extends Resource

const UNSET_TILE_COORDS := Vector2i(-1, -1)

@export var rule_id: StringName = &"land"
@export var display_name: String = "Land"
@export var mask_color: Color = Color.WHITE
@export var paint_base := true
@export var paint_street := false
@export var paint_building_mask := false
@export var base_source_id_override := -1
@export var base_tile_coords_override := UNSET_TILE_COORDS
@export var base_tile_alternative_override := -1
@export var building_mask_source_id_override := -1
@export var building_mask_tile_coords_override := UNSET_TILE_COORDS
@export var building_mask_tile_alternative_override := -1


func matches_mask_color(color: Color) -> bool:
	return _quantize_mask_color(color) == _quantize_mask_color(mask_color)


func has_base_source_override() -> bool:
	return base_source_id_override >= 0


func has_base_tile_coords_override() -> bool:
	return base_tile_coords_override != UNSET_TILE_COORDS


func has_base_tile_alternative_override() -> bool:
	return base_tile_alternative_override >= 0


func has_building_mask_source_override() -> bool:
	return building_mask_source_id_override >= 0


func has_building_mask_tile_coords_override() -> bool:
	return building_mask_tile_coords_override != UNSET_TILE_COORDS


func has_building_mask_tile_alternative_override() -> bool:
	return building_mask_tile_alternative_override >= 0


static func _quantize_mask_color(color: Color) -> Vector3i:
	return Vector3i(
		_quantize_mask_channel(color.r),
		_quantize_mask_channel(color.g),
		_quantize_mask_channel(color.b)
	)


static func _quantize_mask_channel(channel: float) -> int:
	return clampi(roundi(channel * 255.0), 0, 255)
