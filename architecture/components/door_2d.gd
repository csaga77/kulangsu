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
		_update()
		
@export var indent = 0:
	set(new_indent):
		if indent == new_indent:
			return
		indent = new_indent
		_update()

@export var is_open := false:
	set(new_is_open):
		if is_open == new_is_open:
			return
		is_open = new_is_open
		_update_open()

@export var align_parts :Array[Node2D]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super._ready()
	if is_instance_of(self, Area2D) and !hot_areas.has(self):
		hot_areas.append(self)
	for area in hot_areas:
		if !area.body_entered.is_connected(self._on_body_entered):
			area.body_entered.connect(self._on_body_entered)
		if !area.body_exited.is_connected(self._on_body_exited):
			area.body_exited.connect(self._on_body_exited)
	_update()
	_update_open()
	
func _update() -> void:
	for part in align_parts:
		part.position = Vector2(0, -32 * stool_height) + Vector2(-2, -1) * indent

func _update_open() -> void:
	for node in open_sprites:
		node.visible = is_open
		
	for node in close_sprites:
		node.visible = !is_open
		

func _on_body_entered(body: Node2D) -> void:
	is_open = true


func _on_body_exited(body: Node2D) -> void:
	is_open = false
