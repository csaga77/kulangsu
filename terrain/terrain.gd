@tool
class_name Terrain
extends IsometricBlock

const TERRAIN_TILESET := preload("res://resources/tilesets/terrain_0_tiles.tres")
const PAVEMENT_TILESET := preload("res://resources/tilesets/pavement_0_tilesets.tres")
const SYMBOLS_TILESET := preload("res://resources/tilesets/symbols_0_tiles.tres")
const WATER_MATERIAL := preload("res://resources/materials/water.tres")
const ISO_TILEMAP_SCRIPT := preload("res://common/isometric_block.gd")
const TERRAIN_GENERATION_PROFILE_SCRIPT := preload("res://terrain/terrain_generation_profile.gd")

@export var reload: bool = false:
	set(new_reload):
		if not new_reload:
			return # only react to clicking it on
		call_deferred("_reload_terrain")

@export_file_path("*.png") var mask_file: String:
	set(new_mask_file):
		if mask_file == new_mask_file:
			return
		mask_file = new_mask_file
		call_deferred("_reload_terrain")

@export var generation_profile: TerrainGenerationProfile

@export var player :HumanBody2D:
	get:
		return m_player
	set(new_player):
		if m_player == new_player:
			return
		if is_instance_valid(m_player):
			m_player.global_position_changed.disconnect(self._on_player_moved)
		m_player = new_player
		_on_player_changed()

		
var m_base: TileMapLayer
var m_streets: TileMapLayer
var m_water: TileMapLayer
var m_building_mask: TileMapLayer
var m_is_ready := false
var m_player :HumanBody2D

func _ready() -> void:
	m_is_ready = true
	_ensure_generated_layers()
	if _should_generate_terrain():
		_paint_terrain_from_mask()
	if m_player:
		if !m_player.global_position_changed.is_connected(self._on_player_moved):
			m_player.global_position_changed.connect(self._on_player_moved)
		_on_player_moved()
		
func _on_player_changed():
	if m_player:
		if !m_player.global_position_changed.is_connected(self._on_player_moved):
			m_player.global_position_changed.connect(self._on_player_moved)
		_on_player_moved()

func _reload_terrain() -> void:
	if not m_is_ready:
		return

	_ensure_generated_layers()
	_paint_terrain_from_mask()

func _tile_map_is_empty(layer: TileMapLayer) -> bool:
	if not is_instance_valid(layer):
		return true
	return layer.get_used_rect().size == Vector2i.ZERO

func _should_generate_terrain() -> bool:
	if mask_file.is_empty():
		return false
	return _tile_map_is_empty(m_base) or _tile_map_is_empty(m_streets) or _tile_map_is_empty(m_water) or _tile_map_is_empty(m_building_mask)

func _find_generated_layer(parent: Node, layer_name: String) -> TileMapLayer:
	for child in parent.get_children(true):
		if child is TileMapLayer and child.name == layer_name:
			return child as TileMapLayer
	return null

func _reset_water_layer_state(layer: TileMapLayer) -> void:
	layer.name = "water"
	layer.visible = true
	layer.enabled = true
	layer.y_sort_enabled = true
	layer.z_index = 0
	layer.position = Vector2.ZERO
	layer.rotation = 0.0
	layer.scale = Vector2.ONE
	layer.modulate = Color.WHITE
	layer.self_modulate = Color.WHITE
	layer.material = WATER_MATERIAL
	layer.use_parent_material = false
	layer.show_behind_parent = false
	layer.top_level = false
	layer.tile_set = TERRAIN_TILESET
	layer.set_script(null)

func _configure_generated_layer(layer: TileMapLayer, layer_name: String, parent: Node, index: int) -> TileMapLayer:
	if not is_instance_valid(layer):
		layer = TileMapLayer.new()
		layer.name = layer_name
		parent.add_child(layer)
		parent.move_child(layer, min(index, parent.get_child_count() - 1))
	if Engine.is_editor_hint():
		layer.owner = null
	return layer

func _ensure_generated_layers() -> void:
	var ground := $ground as Node

	m_base = _configure_generated_layer(_find_generated_layer(ground, "base"), "base", ground, 0)
	m_base.tile_set = TERRAIN_TILESET

	m_streets = _configure_generated_layer(_find_generated_layer(ground, "streets"), "streets", ground, 1)
	m_streets.tile_set = PAVEMENT_TILESET

	m_water = _configure_generated_layer(_find_generated_layer(self, "water"), "water", self, 1)
	_reset_water_layer_state(m_water)

	m_building_mask = _configure_generated_layer(_find_generated_layer(self, "building_mask"), "building_mask", self, 2)
	m_building_mask.y_sort_enabled = true
	m_building_mask.tile_set = SYMBOLS_TILESET
	m_building_mask.set_script(ISO_TILEMAP_SCRIPT)
	m_building_mask.only_shown_in_editor = true

func _get_generation_profile() -> TerrainGenerationProfile:
	if generation_profile == null:
		generation_profile = TERRAIN_GENERATION_PROFILE_SCRIPT.new()
	else:
		generation_profile.ensure_defaults()
	return generation_profile

func _paint_terrain_from_mask() -> void:
	m_base.clear()
	m_water.clear()
	m_streets.clear()
	m_building_mask.clear()

	if mask_file.is_empty():
		push_warning("mask_file is empty.")
		return

	var img := Image.new()
	var err := img.load(mask_file)
	if err != OK:
		push_error("Failed to load mask image: %s (err=%d)" % [mask_file, err])
		return

	# Ensure predictable pixel access
	if img.is_compressed():
		img.decompress()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)

	var width := img.get_width()
	var height := img.get_height()
	var profile: Variant = _get_generation_profile()

	for y in range(height):
		for x in range(width):
			var tile_pos := Vector2i(x, y)
			var pixel: Color = img.get_pixel(x, y)
			_paint_mask_cell(tile_pos, pixel, profile)
	print("_reload_terrain: painted %dx%d from %s" % [width, height, mask_file])

func _paint_mask_cell(tile_pos: Vector2i, pixel: Color, profile) -> void:
	if profile.is_water_pixel(pixel):
		_paint_water_cell(tile_pos, profile)
		return

	var rule: Variant = profile.resolve_rule_for_pixel(pixel)
	if rule == null:
		return

	if rule.paint_base:
		_paint_base_cell(tile_pos, rule, profile)
	if rule.paint_street:
		_paint_street_cell(tile_pos, profile)
	if rule.paint_building_mask:
		_paint_building_mask_cell(tile_pos, rule, profile)

func _paint_base_cell(tile_pos: Vector2i, rule, profile) -> void:
	m_base.set_cell(
		tile_pos,
		_resolve_base_source_id(rule, profile),
		_resolve_base_tile_coords(rule, profile),
		_resolve_base_tile_alternative(rule, profile)
	)

func _paint_street_cell(tile_pos: Vector2i, profile) -> void:
	m_streets.set_cells_terrain_connect(
		profile.build_street_cells(tile_pos),
		profile.street_terrain_set,
		profile.street_terrain
	)

func _paint_building_mask_cell(tile_pos: Vector2i, rule, profile) -> void:
	m_building_mask.set_cell(
		tile_pos,
		_resolve_building_mask_source_id(rule, profile),
		_resolve_building_mask_tile_coords(rule, profile),
		_resolve_building_mask_tile_alternative(rule, profile)
	)

func _paint_water_cell(tile_pos: Vector2i, profile) -> void:
	m_water.set_cell(
		tile_pos,
		profile.water_source_id,
		profile.water_tile_coords,
		profile.water_tile_alternative
	)

func _resolve_base_source_id(rule, profile) -> int:
	if rule.has_base_source_override():
		return rule.base_source_id_override
	return profile.base_source_id

func _resolve_base_tile_coords(rule, profile) -> Vector2i:
	if rule.has_base_tile_coords_override():
		return rule.base_tile_coords_override
	return profile.base_tile_coords

func _resolve_base_tile_alternative(rule, profile) -> int:
	if rule.has_base_tile_alternative_override():
		return rule.base_tile_alternative_override
	return profile.base_tile_alternative

func _resolve_building_mask_source_id(rule, profile) -> int:
	if rule.has_building_mask_source_override():
		return rule.building_mask_source_id_override
	return profile.building_mask_source_id

func _resolve_building_mask_tile_coords(rule, profile) -> Vector2i:
	if rule.has_building_mask_tile_coords_override():
		return rule.building_mask_tile_coords_override
	return profile.building_mask_tile_coords

func _resolve_building_mask_tile_alternative(rule, profile) -> int:
	if rule.has_building_mask_tile_alternative_override():
		return rule.building_mask_tile_alternative_override
	return profile.building_mask_tile_alternative

func _on_player_moved() -> void:
	if !is_instance_valid(m_player):
		return
	var bounding_rect := m_player.get_bounding_rect()
	var shader_material :ShaderMaterial = material
	if shader_material:
		shader_material.set_shader_parameter("trans_rect_pos", bounding_rect.position)
		shader_material.set_shader_parameter("trans_rect_size", bounding_rect.size)
