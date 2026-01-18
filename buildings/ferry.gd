@tool
class_name Ferry
extends IsometricBlock

@onready var m_wall_back := $wall_back
@onready var m_wall_front := $wall_front
@onready var m_roof := $roof
@onready var m_floor :TileMapLayer = $floor
@onready var m_roof_top :Sprite2D = $roof/roof_top
@onready var m_wall_mask  :TileMapLayer = $wall_back/wall_mask
@onready var m_floor_internal :TileMapLayer = $floor/floor_internal

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		m_wall_mask.visible = true
	else:
		m_wall_mask.visible = false
