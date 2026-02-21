@tool
class_name Terrain
extends IsometricBlock

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
		#call_deferred("_reload_terrain")
		
@export var tile_source_id := 8
@export var building_tile_source_id := 0
@export var building_tile_coords := Vector2i(1, 0)
@export var mask_tile_coords := Vector2i(1, 0)
@export var water_tile_coords := Vector2i(4, 16)
@export var tile_alternative  := 0

@export var player :Player:
	get:
		return m_player
	set(new_player):
		if m_player == new_player:
			return
		if is_instance_valid(m_player):
			m_player.global_position_changed.disconnect(self._on_player_moved)
		m_player = new_player
		_on_player_changed()

		
@onready var m_base    :TileMapLayer = $ground/base
@onready var m_streets :TileMapLayer = $ground/streets
@onready var m_water   :TileMapLayer = $water
@onready var m_building_mask :TileMapLayer = $building_mask
var m_is_ready := false
var m_player :Player

func _ready() -> void:
	m_is_ready = true
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
	if not Engine.is_editor_hint():
		return
		
	if not m_is_ready:
		return

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

	for y in range(height):
		for x in range(width):
			var c :Color = img.get_pixel(x, y)
			if c.a > 0.0:
				if c == Color.RED:
					m_base.set_cell(
						Vector2i(x, y),
						tile_source_id,
						mask_tile_coords,
						tile_alternative
					)
					m_building_mask.set_cell(
						Vector2i(x, y),
						building_tile_source_id,
						building_tile_coords,
						tile_alternative
					)
				elif c == Color.BLUE:
					#m_streets.set_terrain(Vector2i(x, y), 1)
					m_base.set_cell(
						Vector2i(x, y),
						tile_source_id,
						mask_tile_coords,
						tile_alternative
					)
					m_streets.set_cells_terrain_connect(
						[Vector2i(x - 1, y - 1), Vector2i(x, y - 1), Vector2i(x + 1, y - 1), 
						 Vector2i(x - 1, y), Vector2i(x, y), Vector2i(x + 1, y),
						 Vector2i(x - 1, y + 1), Vector2i(x, y + 1), Vector2i(x + 1, y + 1)],
						0, 
						0)
					#m_streets.set_cell(
						#Vector2i(x, y),
						#1,
						#Vector2i(5, 0),
						#0
					#)
				else:
					m_base.set_cell(
						Vector2i(x, y),
						tile_source_id,
						mask_tile_coords,
						tile_alternative
					)
					#m_base.set_cells_terrain_connect(
						#[Vector2i(x - 1, y - 1), Vector2i(x, y - 1), Vector2i(x + 1, y - 1), 
						 #Vector2i(x - 1, y), Vector2i(x, y), Vector2i(x + 1, y),
						 #Vector2i(x - 1, y + 1), Vector2i(x, y + 1), Vector2i(x + 1, y + 1)], 
						#0,
						#0
					#)
			else:
				m_water.set_cell(
						Vector2i(x, y),
						tile_source_id,
						water_tile_coords,
						tile_alternative
					)

	print("_reload_terrain: painted %dx%d from %s" % [width, height, mask_file])

func _on_player_moved() -> void:
	if !is_instance_valid(m_player):
		return
	var bounding_rect := m_player.get_bounding_rect()
	var shader_material :ShaderMaterial = material
	if shader_material:
		shader_material.set_shader_parameter("trans_rect_pos", bounding_rect.position)
		shader_material.set_shader_parameter("trans_rect_size", bounding_rect.size)
