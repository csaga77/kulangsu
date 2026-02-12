@tool
class_name WindowBlock
extends IsometricBlock

@export var offset = Vector2i.ZERO:
	set(new_offset):
		if offset == new_offset:
			return
		offset = new_offset
		_reload()
		
@export var header_size = 1:
	set(new_size):
		if header_size == new_size or new_size < 0:
			return
		header_size = new_size
		_reload()
		
@export var stool_size = 1:
	set(new_height):
		if stool_size == new_height or new_height < 0:
			return
		stool_size = new_height
		_reload()
		
@export var indent = 0:
	set(new_indent):
		if indent == new_indent:
			return
		indent = new_indent
		if is_instance_valid(m_window):
			m_window.indent = indent
		
@export_enum("Full", "Half", "Quarter") var wall_size = 0:
	set(new_size):
		if wall_size == new_size:
			return
		wall_size = new_size
		_reload()
		
@export_enum("SE", "SW") var facing = 0:
	set(new_facing):
		if facing == new_facing:
			return
		facing = new_facing
		_reload()
		
@export var is_south_east_visible = true:
	set(new_visible):
		if is_south_east_visible == new_visible:
			return
		is_south_east_visible = new_visible
		_reload()

@export var is_south_west_visible = true:
	set(new_visible):
		if is_south_west_visible == new_visible:
			return
		is_south_west_visible = new_visible
		_reload()
		
@export var is_open := false:
	set(new_is_open):
		if is_open == new_is_open:
			return
		is_open = new_is_open
		if is_instance_valid(m_window):
			m_window.is_open = is_open
			

@onready var m_wall_block :Node2D = $base_block

var m_is_reloading := false
var m_window :Door

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super._ready()
	_reload()

func _reload() -> void:
	if m_is_reloading:
		return
	m_is_reloading = true
	call_deferred("_do_reload")
	
func _do_reload() -> void:
	#print("WindowBlock._do_reload()")
	m_is_reloading = false
	if m_wall_block == null:
		return
	for child in m_wall_block.get_children():
		child.queue_free()
		
	var window_height = 2 #determined by window type
	var window_width = 2 #determined by window type
	var total_height = stool_size + window_height + header_size
	
	if total_height > 0:
		if stool_size > 0:
			for i in range(window_width):
				var stool :Wall = preload("res://architecture/components/wall.tscn").instantiate()
				match facing:
					0: #SE 
						stool.position = Vector2(32, -16) * i
						stool.is_south_east_visible = is_south_east_visible
						stool.is_south_west_visible = (is_south_west_visible and i == 0)
						stool.pattern = 6 
					1: #SW
						stool.position = Vector2(-32, -16) * i
						stool.is_south_east_visible = (is_south_east_visible and i == 0)
						stool.is_south_west_visible = is_south_west_visible
						stool.pattern = 5
				stool.size = wall_size
				stool.height = stool_size
				stool.offset = offset
				m_wall_block.add_child(stool)
		
		if window_height > 0:
			m_window = preload("res://architecture/components/window_se.tscn").instantiate()
			m_window.stool_height = stool_size
			m_window.is_open = is_open
			m_window.indent = indent
			m_wall_block.add_child(m_window)
		
		if header_size > 0:
			var wall_mask :Array[bool]
			for i in range(total_height):
				if i >= stool_size + window_height:
					wall_mask.append(true)
				else:
					wall_mask.append(false)
			for i in range(window_width):
				var header :Wall = preload("res://architecture/components/wall.tscn").instantiate()
				match facing:
					0: #SE 
						header.position = Vector2(32, -16) * i
						header.is_south_east_visible = is_south_east_visible
						header.is_south_west_visible = (is_south_west_visible and i == 0)
						header.pattern = 6 
					1: #SW
						header.position = Vector2(-32, -16) * i
						header.is_south_east_visible = (is_south_east_visible and i == 0)
						header.is_south_west_visible = is_south_west_visible
						header.pattern = 5
				header.size = wall_size
				header.height = total_height
				header.offset = offset
				header.mask = wall_mask
				m_wall_block.add_child(header)
