@tool
class_name Door
extends IsometricBlock

@export var open_sprites  : Array[Node2D]
@export var close_sprites : Array[Node2D]
@export var hot_areas : Array[Area2D]

@export var is_open := false:
	set(new_is_open):
		if is_open == new_is_open:
			return
		is_open = new_is_open
		_update_open()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super._ready()
	if is_instance_of(self, Area2D) and !hot_areas.has(self):
		hot_areas.append(self)
	for area in hot_areas:
		area.body_entered.connect(self._on_body_entered)
		area.body_exited.connect(self._on_body_exited)
	_update_open()

func _update_open() -> void:
	for node in open_sprites:
		node.visible = is_open
		
	for node in close_sprites:
		node.visible = !is_open
		

func _on_body_entered(body: Node2D) -> void:
	is_open = true


func _on_body_exited(body: Node2D) -> void:
	is_open = false
