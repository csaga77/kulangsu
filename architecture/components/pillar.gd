@tool
class_name Pillar
extends IsometricBlock

@export var size := 2:
	set(new_size):
		if size == new_size or new_size < 2:
			return
		size = new_size
		_reload()
		
@export var base_texture: Texture2D:
	set(new_texture):
		if base_texture == new_texture:
			return
		base_texture = new_texture
		_reload()
		
@export var mid_texture: Texture2D:
	set(new_texture):
		if mid_texture == new_texture:
			return
		mid_texture = new_texture
		_reload()
		
@export var top_texture: Texture2D:
	set(new_texture):
		if top_texture == new_texture:
			return
		top_texture = new_texture
		_reload()

@onready var m_base :Sprite2D = $base
@onready var m_top  :Sprite2D = $mid/top
@onready var m_mid  := $mid
@onready var m_mask :TileMapLayer = $mask

var m_is_reloading = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super._ready()
	# no need to _reload() during _ready()
	# It is already loaded from a scene file, no need to duplicate loading.
	_reload()

func _reload() -> void:
	if m_is_reloading:
		return
	m_is_reloading = true
	call_deferred("_do_reload")
	
func _do_reload() -> void:
	m_is_reloading = false
	if m_top == null:
		return
	#dprint("Pillar._reload()")
	m_mask.clear()
	m_mask.set_cell(Vector2i(-2, -1), 0, Vector2i(0, 0))
	m_top.position.y = -iso_tile_size.y * size + iso_tile_size.y / 2
	m_top.texture = top_texture
	m_top.z_index = size / 4
	m_base.texture = base_texture
	for child in m_mid.get_children():
		if child == m_top:
			continue
		child.queue_free()
	if size > 2:
		for i in size - 2:
			var mid_sprite := Sprite2D.new()
			mid_sprite.texture = mid_texture
			mid_sprite.z_index = i / 4
			m_mid.add_child(mid_sprite)
			mid_sprite.position.y = -iso_tile_size.y * (i + 2)
			m_mask.set_cell(Vector2i(-2, -1) + Vector2i(-1, -1) * (i + 1), 0, Vector2i(0, 0))
