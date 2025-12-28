extends Node2D

@onready var m_wall_back := $wall_back
@onready var m_wall_front := $wall_front
@onready var m_roof := $roof
@onready var m_floor :TileMapLayer = $floor
@onready var m_roof_top :Sprite2D = $roof/roof_top
@onready var m_wall_mask :TileMapLayer = $wall_mask

var m_trans_rect :Rect2

func set_trans_rect(rect):
	m_trans_rect = rect
	m_trans_rect.position -= rect.size / 2
	m_trans_rect.position.y -= 32
	m_trans_rect.size = m_trans_rect.size * 2
	
	var cells = Utils.get_cells_intersecting_rect_global(m_floor, rect)
	var is_roof_visible = true
	for cell in cells.data:
		#var tile_data :TileData = m_floor.get_cell_tile_data(cell)
		var atlas_coords := m_floor.get_cell_atlas_coords(cell)
		if atlas_coords == Vector2i(1, 0):
			is_roof_visible = false
			break
	m_roof.visible = is_roof_visible
	if is_roof_visible:
		m_wall_front.modulate.a = 1.0
		var c :Set = Utils.get_cells_intersecting_rect_global(m_wall_mask, rect)
		if c.is_empty():
			m_trans_rect.size = Vector2i.ZERO
			m_wall_back.modulate.a = 1.0
		else:
			m_wall_back.modulate.a = 0.5
	else:
		m_wall_back.modulate.a = 1.0
		m_wall_front.modulate.a = 0.5
	#m_wall.notify_runtime_tile_data_update()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var shader_material :ShaderMaterial = m_roof_top.material
	shader_material.set_shader_parameter("trans_rect_pos", m_trans_rect.position)
	shader_material.set_shader_parameter("trans_rect_size", m_trans_rect.size)
	
	var shader_material2 :ShaderMaterial = m_roof.material
	shader_material2.set_shader_parameter("trans_rect_pos", m_trans_rect.position)
	shader_material2.set_shader_parameter("trans_rect_size", m_trans_rect.size)
