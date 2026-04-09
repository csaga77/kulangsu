@tool
class_name TerrainGenerationProfile
extends Resource

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
@export var color_rules: Array[TerrainMaskRule] = []
@export var default_land_rule: TerrainMaskRule


func _init() -> void:
	ensure_defaults()


func ensure_defaults() -> void:
	if street_neighbor_offsets.is_empty():
		street_neighbor_offsets = _build_default_street_neighbor_offsets()
	if default_land_rule == null:
		default_land_rule = _build_default_land_rule()
	if color_rules.is_empty():
		color_rules = _build_default_color_rules()
	else:
		_sanitize_color_rules()


func _sanitize_color_rules() -> void:
	var valid_rules: Array[TerrainMaskRule] = []
	for rule: TerrainMaskRule in color_rules:
		if rule == null:
			push_warning("TerrainGenerationProfile ignored a null TerrainMaskRule.")
			continue
		valid_rules.append(rule)
	color_rules = valid_rules
	if color_rules.is_empty():
		color_rules = _build_default_color_rules()


func is_valid_profile() -> bool:
	if default_land_rule == null:
		push_error("TerrainGenerationProfile is missing default_land_rule.")
		return false
	for rule: TerrainMaskRule in color_rules:
		if rule == null:
			push_error("TerrainGenerationProfile contains a null TerrainMaskRule.")
			return false
	return true


func is_water_pixel(pixel: Color) -> bool:
	return pixel.a <= 0.0


func resolve_rule_for_pixel(pixel: Color) -> TerrainMaskRule:
	for rule: TerrainMaskRule in color_rules:
		if rule.matches_mask_color(pixel):
			return rule
	return default_land_rule


func build_street_cells(tile_pos: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for offset: Vector2i in street_neighbor_offsets:
		cells.append(tile_pos + offset)
	return cells


static func create_default_profile() -> TerrainGenerationProfile:
	var profile := TerrainGenerationProfile.new()
	profile.base_source_id = 8
	profile.base_tile_coords = Vector2i(1, 0)
	profile.base_tile_alternative = 0
	profile.water_source_id = 8
	profile.water_tile_coords = Vector2i(4, 16)
	profile.water_tile_alternative = 0
	profile.building_mask_source_id = 0
	profile.building_mask_tile_coords = Vector2i(1, 0)
	profile.building_mask_tile_alternative = 0
	profile.street_terrain_set = 1
	profile.street_terrain = 0
	profile.street_neighbor_offsets = _build_default_street_neighbor_offsets()
	profile.default_land_rule = _build_default_land_rule()
	profile.color_rules = _build_default_color_rules()
	return profile


static func _build_default_land_rule() -> TerrainMaskRule:
	var rule := TerrainMaskRule.new()
	rule.rule_id = &"land"
	rule.display_name = "Land"
	rule.mask_color = Color.WHITE
	rule.paint_base = true
	rule.paint_street = false
	rule.paint_building_mask = false
	return rule


static func _build_default_color_rules() -> Array[TerrainMaskRule]:
	var building_mask_rule := TerrainMaskRule.new()
	building_mask_rule.rule_id = &"building_mask"
	building_mask_rule.display_name = "Building Mask"
	building_mask_rule.mask_color = Color.RED
	building_mask_rule.paint_base = true
	building_mask_rule.paint_street = false
	building_mask_rule.paint_building_mask = true

	var street_rule := TerrainMaskRule.new()
	street_rule.rule_id = &"street"
	street_rule.display_name = "Street"
	street_rule.mask_color = Color.BLUE
	street_rule.paint_base = true
	street_rule.paint_street = true
	street_rule.paint_building_mask = false

	var rules: Array[TerrainMaskRule] = []
	rules.append(building_mask_rule)
	rules.append(street_rule)
	return rules


static func _build_default_street_neighbor_offsets() -> Array[Vector2i]:
	var offsets: Array[Vector2i] = []
	offsets.append(Vector2i(0, -1))
	offsets.append(Vector2i(-1, 0))
	offsets.append(Vector2i.ZERO)
	offsets.append(Vector2i(1, 0))
	offsets.append(Vector2i(0, 1))
	return offsets
