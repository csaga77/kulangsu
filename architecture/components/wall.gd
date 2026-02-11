@tool
class_name Wall
extends IsometricBlock

@export var offset = 0:
	set(new_offset):
		if offset == new_offset:
			return
		offset = new_offset
		_update_tiles()
		
@export var levels = 1:
	set(new_levels):
		if levels == new_levels or new_levels < 1:
			return
		levels = new_levels
		_update_tiles()
		
@export_range(0, 3, 1) var pattern = 0:
	set(new_pattern):
		if pattern == new_pattern:
			return
		pattern = new_pattern
		_update_tiles()
		
@export var is_front_visible = true:
	set(new_visible):
		if is_front_visible == new_visible:
			return
		is_front_visible = new_visible
		_update_tiles()
@export var is_left_visible = true:
	set(new_visible):
		if is_left_visible == new_visible:
			return
		is_left_visible = new_visible
		_update_tiles()

@onready var m_wall_block = $wall_block

var m_wall_patterns := [
	{
		"region": Rect2i(0, 0, 64, 64), 
		"origin": Vector2(0, -16)
	},
	{
		"region": Rect2i(80, 16, 32, 48), 
		"origin": Vector2(0, -8)
	},
	{
		"region": Rect2i(128, 0, 48, 64), 
		"origin": Vector2(-8, -16)
	},
	{
		"region": Rect2i(768, 13, 40, 52), 
		"origin": Vector2(-12, -9.0)
	}
]
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
	mat.set_shader_parameter("is_top_visible", levels == 1)
	mat.set_shader_parameter("is_front_visible", is_front_visible)
	mat.set_shader_parameter("is_left_visible", is_left_visible)
	
	var wall_template = m_wall_patterns[pattern]
	m_wall_block.texture.atlas = m_atlas_texture
	m_wall_block.texture.region = wall_template.region
	m_wall_block.position = wall_template.origin + Vector2(8.0, -4.0) * offset
	for child in m_wall_block.get_children():
		child.queue_free()

	if levels > 1:
		for level in range(1, levels):
			var sprite := Sprite2D.new()
			sprite.texture = AtlasTexture.new()
			sprite.texture.atlas = m_atlas_texture
			sprite.texture.region = wall_template.region
			sprite.position.y = level * -32
			if level == levels - 1:
				var sub_mat :ShaderMaterial = mat.duplicate()
				sub_mat.set_shader_parameter("is_top_visible", true)
				sprite.material = sub_mat
			else:
				sprite.use_parent_material = true
			m_wall_block.add_child(sprite)
