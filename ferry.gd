@tool
class_name Ferry
extends Node2D

@onready var m_wall_back := $wall_back
@onready var m_wall_front := $wall_front
@onready var m_roof := $roof
@onready var m_floor :TileMapLayer = $floor
@onready var m_roof_top :Sprite2D = $roof/roof_top
@onready var m_wall_mask  :TileMapLayer = $wall_back/wall_mask
@onready var m_floor_internal :TileMapLayer = $floor/floor_internal

var m_trans_rect :Rect2

func set_trans_rect(rect):
	m_trans_rect = rect
	m_trans_rect.position -= rect.size / 2
	m_trans_rect.position.y -= 32
	m_trans_rect.size = m_trans_rect.size * 2
	
	var is_roof_visible = !Utils.intersects_rect_global(m_floor_internal, rect)
	m_roof.visible = is_roof_visible
	if is_roof_visible:
		m_wall_front.modulate.a = 1.0
		if Utils.intersects_rect_global(m_wall_mask, rect):
			m_wall_back.modulate.a = 0.5
		else:
			m_trans_rect.size = Vector2i.ZERO
			m_wall_back.modulate.a = 1.0
	else:
		m_wall_back.modulate.a = 1.0
		m_wall_front.modulate.a = 0.5
	#m_wall.notify_runtime_tile_data_update()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if Engine.is_editor_hint():
		m_wall_mask.visible = true
	else:
		m_wall_mask.visible = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var shader_material :ShaderMaterial = m_roof_top.material
	shader_material.set_shader_parameter("trans_rect_pos", m_trans_rect.position)
	shader_material.set_shader_parameter("trans_rect_size", m_trans_rect.size)
	
	var shader_material2 :ShaderMaterial = m_roof.material
	shader_material2.set_shader_parameter("trans_rect_pos", m_trans_rect.position)
	shader_material2.set_shader_parameter("trans_rect_size", m_trans_rect.size)
