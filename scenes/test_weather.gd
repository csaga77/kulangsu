@tool
extends Node2D

const TERRAIN_TILESET := preload("res://resources/tilesets/terrain_0_tiles.tres")
const WATER_MATERIAL := preload("res://resources/materials/water.tres")

const PIER_POLYGON := [
	Vector2(-110.0, 566.0),
	Vector2(1180.0, 470.0),
	Vector2(1370.0, 620.0),
	Vector2(60.0, 756.0),
]
const BACKDROP_ISLAND_POLYGON := [
	Vector2(-120.0, 350.0),
	Vector2(40.0, 280.0),
	Vector2(190.0, 298.0),
	Vector2(320.0, 224.0),
	Vector2(420.0, 254.0),
	Vector2(575.0, 198.0),
	Vector2(720.0, 246.0),
	Vector2(885.0, 182.0),
	Vector2(1020.0, 260.0),
	Vector2(1180.0, 214.0),
	Vector2(1360.0, 330.0),
	Vector2(1360.0, 450.0),
	Vector2(-120.0, 450.0),
]

const TERRAIN_SOURCE_ID := 8
const TERRAIN_TILE_VARIANTS := [
	Vector2i(0, 0),
	Vector2i(1, 0),
	Vector2i(2, 0),
	Vector2i(3, 0),
	Vector2i(4, 0),
	Vector2i(5, 0),
	Vector2i(6, 0),
	Vector2i(7, 0),
	Vector2i(8, 0),
	Vector2i(9, 0),
	Vector2i(0, 2),
	Vector2i(1, 2),
	Vector2i(2, 2),
	Vector2i(3, 2),
	Vector2i(4, 2),
	Vector2i(5, 2),
	Vector2i(6, 2),
	Vector2i(7, 2),
	Vector2i(8, 2),
	Vector2i(9, 2),
]
const WATER_TILE_COORDS := Vector2i(4, 16)
const WATER_TILE_ALTERNATIVE := 0
const WATER_FILL_MARGIN := Vector2(320.0, 240.0)

@export var rebuild_environment: bool = false:
	set(value):
		if not value:
			return
		rebuild_environment = false
		if is_node_ready():
			_rebuild_environment()

@export var rebuild_ground: bool = false:
	set(value):
		if not value:
			return
		rebuild_ground = false
		if is_node_ready():
			_rebuild_ground()

var m_player_controller: PlayerController = null
var m_closest_object: Node2D = null

@onready var m_water: TileMapLayer = $Water
@onready var m_backdrop_terrain: TileMapLayer = $BackdropTerrain
@onready var m_ground: TileMapLayer = $Ground
@onready var m_player: HumanBody2D = $Actors/Player


func _ready() -> void:
	_rebuild_environment()
	_rebuild_ground()
	if Engine.is_editor_hint():
		return

	GameGlobal.get_instance().set_player(m_player)
	if !AppState.player_appearance_changed.is_connected(_on_player_appearance_changed):
		AppState.player_appearance_changed.connect(_on_player_appearance_changed)

	m_player_controller = m_player.controller as PlayerController
	_apply_player_costume()
	if m_player_controller != null:
		if !m_player_controller.closest_object_changed.is_connected(_on_closest_object_changed):
			m_player_controller.closest_object_changed.connect(_on_closest_object_changed)
		if !m_player_controller.inspect_requested.is_connected(_on_player_inspect_requested):
			m_player_controller.inspect_requested.connect(_on_player_inspect_requested)
	AppState.set_residents(AppState.get_known_resident_names())


func _rebuild_environment() -> void:
	_rebuild_water()
	_rebuild_backdrop_terrain()


func _rebuild_water() -> void:
	if not is_instance_valid(m_water):
		return

	m_water.tile_set = TERRAIN_TILESET
	m_water.material = WATER_MATERIAL
	m_water.y_sort_enabled = false
	m_water.clear()

	var scene_bounds := _get_scene_bounds()
	var water_bounds := Rect2(
		scene_bounds.position - WATER_FILL_MARGIN,
		scene_bounds.size + WATER_FILL_MARGIN * 2.0
	)
	_fill_rect_layer(m_water, water_bounds, TERRAIN_SOURCE_ID, WATER_TILE_COORDS, WATER_TILE_ALTERNATIVE)


func _rebuild_backdrop_terrain() -> void:
	if not is_instance_valid(m_backdrop_terrain):
		return

	m_backdrop_terrain.tile_set = TERRAIN_TILESET
	m_backdrop_terrain.material = null
	m_backdrop_terrain.y_sort_enabled = false
	m_backdrop_terrain.clear()
	_fill_polygon_with_variants(
		m_backdrop_terrain,
		BACKDROP_ISLAND_POLYGON,
		TERRAIN_SOURCE_ID,
		TERRAIN_TILE_VARIANTS
	)


func _rebuild_ground() -> void:
	if not is_instance_valid(m_ground):
		return

	m_ground.tile_set = TERRAIN_TILESET
	m_ground.y_sort_enabled = false
	m_ground.clear()
	_fill_polygon_with_variants(m_ground, PIER_POLYGON, TERRAIN_SOURCE_ID, TERRAIN_TILE_VARIANTS)


func _fill_polygon_with_variants(
	layer: TileMapLayer,
	polygon_world: Array,
	source_id: int,
	tile_variants: Array
) -> void:
	if polygon_world.is_empty() or tile_variants.is_empty():
		return

	var polygon_map := PackedVector2Array()
	for point: Vector2 in polygon_world:
		polygon_map.append(_world_to_iso_map_coords(layer, point))

	var bounds := Rect2(polygon_map[0], Vector2.ZERO)
	for point in polygon_map:
		bounds = bounds.expand(point)

	var min_cell := Vector2i(floori(bounds.position.x) - 2, floori(bounds.position.y) - 2)
	var max_cell := Vector2i(ceili(bounds.end.x) + 2, ceili(bounds.end.y) + 2)

	for y in range(min_cell.y, max_cell.y + 1):
		for x in range(min_cell.x, max_cell.x + 1):
			var cell := Vector2i(x, y)
			var cell_center := Vector2(float(x), float(y))
			if not Geometry2D.is_point_in_polygon(cell_center, polygon_map):
				continue
			var index := posmod(cell.x * 3 + cell.y * 5, tile_variants.size())
			layer.set_cell(cell, source_id, tile_variants[index], 0)


func _fill_rect_layer(
	layer: TileMapLayer,
	world_rect: Rect2,
	source_id: int,
	tile_coords: Vector2i,
	alternative: int
) -> void:
	var top_left := layer.local_to_map(layer.to_local(world_rect.position))
	var top_right := layer.local_to_map(layer.to_local(Vector2(world_rect.end.x, world_rect.position.y)))
	var bottom_left := layer.local_to_map(layer.to_local(Vector2(world_rect.position.x, world_rect.end.y)))
	var bottom_right := layer.local_to_map(layer.to_local(world_rect.end))

	var min_x := mini(mini(top_left.x, top_right.x), mini(bottom_left.x, bottom_right.x))
	var max_x := maxi(maxi(top_left.x, top_right.x), maxi(bottom_left.x, bottom_right.x))
	var min_y := mini(mini(top_left.y, top_right.y), mini(bottom_left.y, bottom_right.y))
	var max_y := maxi(maxi(top_left.y, top_right.y), maxi(bottom_left.y, bottom_right.y))

	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			layer.set_cell(Vector2i(x, y), source_id, tile_coords, alternative)


func _get_scene_bounds() -> Rect2:
	var bounds := Rect2(PIER_POLYGON[0], Vector2.ZERO)
	for point: Vector2 in PIER_POLYGON:
		bounds = bounds.expand(point)
	for point: Vector2 in BACKDROP_ISLAND_POLYGON:
		bounds = bounds.expand(point)
	return bounds


func _world_to_iso_map_coords(layer: TileMapLayer, world_pos: Vector2) -> Vector2:
	var local_pos := layer.to_local(world_pos)
	var tile_size := Vector2.ONE
	if layer.tile_set != null:
		tile_size = Vector2(layer.tile_set.tile_size)
	else:
		tile_size = Vector2(64.0, 32.0)

	var tile_width := maxf(tile_size.x, 1.0)
	var tile_height := maxf(tile_size.y, 1.0)
	var map_x := local_pos.x / tile_width + local_pos.y / tile_height
	var map_y := local_pos.y / tile_height - local_pos.x / tile_width
	return Vector2(map_x, map_y)


func _on_player_appearance_changed(_profile: Dictionary, _appearance_config: Dictionary) -> void:
	_apply_player_costume()


func _apply_player_costume() -> void:
	if !is_instance_valid(m_player):
		return

	var appearance_config := AppState.get_player_appearance_config()
	if appearance_config.is_empty():
		return

	m_player.set_configuration(appearance_config)


func _on_closest_object_changed(new_object: Node2D) -> void:
	m_closest_object = new_object


func _on_player_inspect_requested() -> void:
	var resident_controller := _get_resident_controller(m_closest_object)
	if resident_controller == null:
		return

	var resident_id := resident_controller.get_resident_id()
	var interaction := AppState.interact_with_resident(resident_id)
	var dialogue_line := String(interaction.get("line", ""))
	resident_controller.reveal_dialogue(dialogue_line)
	AppState.set_residents(AppState.get_known_resident_names())


func _get_resident_controller(target: Node2D) -> NPCController:
	var human := target as HumanBody2D
	if human == null:
		return null
	return human.controller as NPCController
