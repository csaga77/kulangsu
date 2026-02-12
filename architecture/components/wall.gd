@tool
class_name Wall
extends IsometricBlock

@export var offset = Vector2i.ZERO:
	set(new_offset):
		if offset == new_offset:
			return
		offset = new_offset
		_update_tiles()
		
@export var height = 1:
	set(new_size):
		if height == new_size or new_size < 0:
			return
		height = new_size
		_update_tiles()
		
@export_enum("Full", "Half", "Quarter") var size = 0:
	set(new_size):
		if size == new_size:
			return
		size = new_size
		_update_tiles()
		
@export_range(0, 32, 1) var pattern = 0:
	set(new_pattern):
		if pattern == new_pattern:
			return
		pattern = new_pattern
		_update_tiles()
		
@export var is_south_east_visible = true:
	set(new_visible):
		if is_south_east_visible == new_visible:
			return
		is_south_east_visible = new_visible
		_update_tiles()

@export var is_south_west_visible = true:
	set(new_visible):
		if is_south_west_visible == new_visible:
			return
		is_south_west_visible = new_visible
		_update_tiles()
		
@export var mask :Array[bool]:
	set(new_mask):
		if mask == new_mask:
			return
		mask = new_mask
		_update_tiles()

@onready var m_wall_block = $wall_block

var m_atlas_texture :Texture2D = preload("res://resources/sprites/architecture/components/wall_templates_0.png")
var m_is_updating := false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super._ready()
	_update_tiles()

func _update_tiles() -> void:
	if m_is_updating:
		return
	m_is_updating = true
	call_deferred("_do_update_tiles")
	
func _do_update_tiles() -> void:
	m_is_updating = false
	if m_wall_block == null:
		return
	
	var mat :ShaderMaterial = m_wall_block.material
	mat.set_shader_parameter("is_top_visible", height == 1)
	mat.set_shader_parameter("is_south_east_visible", is_south_east_visible)
	mat.set_shader_parameter("is_south_west_visible", is_south_west_visible)
	var cap_mat :ShaderMaterial = mat.duplicate()
	cap_mat.set_shader_parameter("is_top_visible", true)
	
	var region :Rect2 = Rect2(pattern * 64, size * 128, 64, 64)
	var origin :Vector2 = Vector2(0, -16)
	m_wall_block.position = origin + Vector2(8.0, -4.0) * offset.y + Vector2(-8.0, -4.0) * offset.x
	for child in m_wall_block.get_children():
		child.queue_free()

	for level in range(0, height):
		var maskBit = true
		if mask.size() > level:
			maskBit = mask.get(level)
		if maskBit:
			var sprite := Sprite2D.new()
			sprite.texture = AtlasTexture.new()
			sprite.texture.atlas = m_atlas_texture
			sprite.texture.region = region
			sprite.position.y = level * -32
			var next_level = level + 1
			var need_cap = (level == height - 1)
			
			if next_level < mask.size():
				if !mask.get(next_level):
					need_cap = true
				
			if need_cap:
				sprite.material = cap_mat
			else:
				sprite.use_parent_material = true
			m_wall_block.add_child(sprite)
