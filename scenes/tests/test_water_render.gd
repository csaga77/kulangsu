@tool
extends Node2D

const WATER_TILESET := preload("res://resources/tilesets/terrain_0_tiles.tres")
const WATER_MATERIAL := preload("res://resources/materials/water.tres")

@export var rebuild: bool = false:
	set(value):
		if not value:
			return
		rebuild = false
		if is_node_ready():
			_rebuild_water()
			queue_redraw()

@export var water_size := Vector2i(22, 14)
@export var water_origin := Vector2i(-11, -7)
@export var water_source_id := 8
@export var water_tile_coords := Vector2i(4, 16)
@export var water_alternative := 0
@export var water_position := Vector2(640, 190)

@onready var m_water := $Water as TileMapLayer

func _ready() -> void:
	_rebuild_water()
	queue_redraw()

func _rebuild_water() -> void:
	if not is_instance_valid(m_water):
		return

	m_water.tile_set = WATER_TILESET
	m_water.material = WATER_MATERIAL
	m_water.y_sort_enabled = true
	m_water.position = water_position

	m_water.clear()
	for y in range(water_size.y):
		for x in range(water_size.x):
			var tile_pos := water_origin + Vector2i(x, y)
			m_water.set_cell(
				tile_pos,
				water_source_id,
				water_tile_coords,
				water_alternative
			)

	print("test_water_render: rebuilt %dx%d water field" % [water_size.x, water_size.y])

func _draw() -> void:
	var rect := get_viewport_rect()
	draw_rect(rect.grow(96.0), Color(0.929412, 0.898039, 0.807843), true)

	# Warm horizontal bands make refraction easy to spot.
	for i in range(9):
		var stripe_y := 60.0 + float(i) * 62.0
		var stripe_color := Color(0.917647, 0.788235, 0.611765, 0.95)
		if i % 2 == 0:
			stripe_color = Color(0.807843, 0.894118, 0.937255, 0.92)
		draw_rect(Rect2(-40.0, stripe_y, rect.size.x + 80.0, 26.0), stripe_color, true)

	# Vertical pilings and warm pier colors create strong distortion references.
	for i in range(6):
		var piling_x := 160.0 + float(i) * 150.0
		draw_rect(Rect2(piling_x, 120.0, 24.0, 470.0), Color(0.47451, 0.376471, 0.294118, 0.96), true)
		draw_rect(Rect2(piling_x + 24.0, 120.0, 12.0, 470.0), Color(0.721569, 0.603922, 0.470588, 0.85), true)

	var pier := PackedVector2Array([
		Vector2(120.0, 430.0),
		Vector2(520.0, 330.0),
		Vector2(990.0, 430.0),
		Vector2(1160.0, 570.0),
		Vector2(930.0, 680.0),
		Vector2(300.0, 700.0)
	])
	draw_colored_polygon(pier, Color(0.756863, 0.627451, 0.482353, 0.93))

	for i in range(5):
		var buoy_pos := Vector2(230.0 + float(i) * 185.0, 220.0 + float(i % 2) * 82.0)
		draw_circle(buoy_pos, 20.0, Color(0.952941, 0.470588, 0.305882, 0.92))
		draw_circle(buoy_pos + Vector2(0.0, 7.0), 9.0, Color(1.0, 0.964706, 0.870588, 0.96))
