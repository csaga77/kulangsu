@tool
extends Node2D

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
		
@export var tile_source_id := 3
@export var building_tile_coords := Vector2i(1, 0)
@export var mask_tile_coords := Vector2i(7, 0)
@export var tile_alternative  := 0

@onready var m_base :TileMapLayer = $Base
@onready var m_ferry :Ferry = $Ferry
@onready var m_player :Player = $Character
var m_is_ready := false

func _reload_terrain() -> void:
	if not Engine.is_editor_hint():
		return
		
	if not m_is_ready:
		return

	m_base.clear()

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
						building_tile_coords,
						tile_alternative
					)
				else:
					m_base.set_cell(
						Vector2i(x, y),
						tile_source_id,
						mask_tile_coords,
						tile_alternative
					)

	print("_reload_terrain: painted %dx%d from %s" % [width, height, mask_file])

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	m_is_ready = true
	GameGlobal.get_instance().set_player(m_player)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	var rect :Rect2
	#rect.position = m_player.global_position - Vector2(16, 48)
	#rect.size = Vector2(32, 64)
	
	rect.position = m_player.global_position - Vector2(16, 4)
	rect.size = Vector2(32, 32)
	m_ferry.set_trans_rect(rect)
