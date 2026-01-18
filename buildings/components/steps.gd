@tool
class_name Steps
extends IsometricBlock

@export_flags_2d_physics var layer1 := 0:
	set(new_layer):
		if layer1 == new_layer:
			return
		layer1 = new_layer
		_update_mask()
		
@export_flags_2d_physics var collision_layer := 0:
	set(new_layer):
		if collision_layer == new_layer:
			return
		collision_layer = new_layer
		_update_mask()
		
@export_flags_2d_physics var layer2 := 0:
	set(new_layer):
		if layer2 == new_layer:
			return
		layer2 = new_layer
		_update_mask()

@onready var m_body :CollisionObject2D = $"steps body"
@onready var m_portal1 :Portal = $portal
@onready var m_portal2 :Portal = $portal2

func _update_mask() -> void:
	if m_body:
		m_body.collision_layer = collision_layer
	if m_portal1:
		m_portal1.mask1 = layer1
		m_portal1.mask2 = collision_layer
	if m_portal2:
		m_portal2.mask1 = collision_layer
		m_portal2.mask2 = layer2
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super._ready()
	_update_mask()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
	#super._process(delta)
