@tool
class_name Door
extends IsometricBlock

@export var open_sprites  : Array[Node2D]
@export var close_sprites : Array[Node2D]
@export var hot_areas : Array[Area2D]

@export var stool_height = 0:
	set(new_height):
		if stool_height == new_height:
			return
		stool_height = new_height
		_update_height()
		
@export_enum("SE", "SW") var facing = 0:
	set(new_facing):
		if facing == new_facing:
			return
		facing = new_facing
		m_indent_factor = -1.0 if facing == 0 else 1.0
		_update_height()
		
@export var indent = 0:
	set(new_indent):
		if indent == new_indent:
			return
		indent = new_indent
		_update_height()
		
@export var offset = Vector2i.ZERO:
	set(new_offset):
		if offset == new_offset:
			return
		offset = new_offset
		_update_height()

@export var is_open := false:
	set(new_is_open):
		if is_open == new_is_open:
			return
		is_open = new_is_open
		_update_open()

@export var align_parts :Array[Node2D]

var m_is_updating = false
var m_indent_factor = -1.0

func _ready() -> void:
	super._ready()
	if is_instance_of(self, Area2D) and !hot_areas.has(self):
		hot_areas.append(self)
	for area in hot_areas:
		if !area.body_entered.is_connected(self._on_body_entered):
			area.body_entered.connect(self._on_body_entered)
		if !area.body_exited.is_connected(self._on_body_exited):
			area.body_exited.connect(self._on_body_exited)
	_update_open()
	_update_height()
	
func _update_height() -> void:
	if m_is_updating:
		return
	m_is_updating = true
	call_deferred("_do_update_height")
	
func _do_update_height() -> void:
	m_is_updating = false
	#print("Door._update_height()")
	for part in align_parts:
		part.position = Vector2(0, -32 * stool_height) + Vector2(2 * m_indent_factor, -1) * indent + Vector2(8.0, -4.0) * offset.y + Vector2(-8.0, -4.0) * offset.x

func _update_open() -> void:
	for node in open_sprites:
		node.visible = is_open
		
	for node in close_sprites:
		node.visible = !is_open
		

func _on_body_entered(_body: Node2D) -> void:
	is_open = true


func _on_body_exited(_body: Node2D) -> void:
	is_open = false
