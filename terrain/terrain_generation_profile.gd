@tool
class_name TerrainGenerationProfile
extends Resource

const TERRAIN_MASK_RULE_SCRIPT := preload("res://terrain/terrain_mask_rule.gd")

@export var base_source_id := 8
@export var base_tile_coords := Vector2i(1, 0)
@export var base_tile_alternative := 0
@export var water_source_id := 8
@export var water_tile_coords := Vector2i(4, 16)
@export var water_tile_alternative := 0
@export var building_mask_source_id := 0
@export var building_mask_tile_coords := Vector2i(1, 0)
@export var building_mask_tile_alternative := 0
@export var street_terrain_set := 1
@export var street_terrain := 0
@export var street_neighbor_offsets: Array[Vector2i] = []
@export var color_rules: Array[Resource] = []
@export var default_land_rule: Resource


func _init() -> void:
	ensure_defaults()

func ensure_defaults() -> void:
	if street_neighbor_offsets.is_empty():
		street_neighbor_offsets = _build_default_street_neighbor_offsets()
	if color_rules.is_empty():
		color_rules = _build_default_color_rules()
	if default_land_rule == null:
		default_land_rule = _make_rule(
			&"land",
			"Land",
			Color.WHITE,
			true,
			false,
			false
		)


func is_water_pixel(pixel: Color) -> bool:
	return pixel.a <= 0.0


func resolve_rule_for_pixel(pixel: Color):
	for rule in color_rules:
		if rule == null:
			continue
		if rule.matches_mask_color(pixel):
			return rule
	return default_land_rule


func build_street_cells(tile_pos: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for offset: Vector2i in street_neighbor_offsets:
		cells.append(tile_pos + offset)
	return cells


static func _build_default_color_rules() -> Array[Resource]:
	var rules: Array[Resource] = []
	rules.append(_make_rule(
		&"building_mask",
		"Building Mask",
		Color.RED,
		true,
		false,
		true
	))
	rules.append(_make_rule(
		&"street",
		"Street",
		Color.BLUE,
		true,
		true,
		false
	))
	return rules


static func _make_rule(
	new_rule_id: StringName,
	new_display_name: String,
	new_mask_color: Color,
	new_paint_base: bool,
	new_paint_street: bool,
	new_paint_building_mask: bool
):
	var rule = TERRAIN_MASK_RULE_SCRIPT.new()
	rule.rule_id = new_rule_id
	rule.display_name = new_display_name
	rule.mask_color = new_mask_color
	rule.paint_base = new_paint_base
	rule.paint_street = new_paint_street
	rule.paint_building_mask = new_paint_building_mask
	return rule


static func _build_default_street_neighbor_offsets() -> Array[Vector2i]:
	var offsets: Array[Vector2i] = []
	offsets.append(Vector2i(0, -1))
	offsets.append(Vector2i(-1, 0))
	offsets.append(Vector2i.ZERO)
	offsets.append(Vector2i(1, 0))
	offsets.append(Vector2i(0, 1))
	return offsets
