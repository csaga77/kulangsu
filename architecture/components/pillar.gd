@tool
class_name Pillar
extends AutoVisibilityNode2D

@export var size := 2:
	set(new_size):
		if size == new_size or new_size < 2:
			return
		size = new_size
		_update_pillar()
		
@export var base_texture: Texture2D:
	set(new_texture):
		if base_texture == new_texture:
			return
		base_texture = new_texture
		_update_pillar()
		
@export var mid_texture: Texture2D:
	set(new_texture):
		if mid_texture == new_texture:
			return
		mid_texture = new_texture
		_update_pillar()
		
@export var top_texture: Texture2D:
	set(new_texture):
		if top_texture == new_texture:
			return
		top_texture = new_texture
		_update_pillar()

@onready var m_base :Sprite2D = $base
@onready var m_top  :Sprite2D = $top
@onready var m_mid  := $mid

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super._ready()
	_update_pillar()

func _update_pillar() -> void:
	if m_top == null:
		return
	m_top.position.y = -iso_tile_size.y * size + iso_tile_size.y / 2
	m_top.texture = top_texture
	m_top.z_index = size / 2
	m_base.texture = base_texture
	for child in m_mid.get_children():
		child.queue_free()
	if size > 2:
		for i in size - 2:
			var mid_sprite := Sprite2D.new()
			mid_sprite.texture = mid_texture
			mid_sprite.z_index = size / 2
			m_mid.add_child(mid_sprite)
			mid_sprite.position.y = -iso_tile_size.y * (i + 2)
