@tool
class_name Steps
extends IsometricBlock

@export var layer1_nodes :Array[Portal]

@export_flags_2d_physics var layer1 := 0:
	set(new_layer):
		if layer1 == new_layer:
			return
		layer1 = new_layer
		_update_mask()
		
@export var body_nodes :Array[CollisionObject2D]

@export_flags_2d_physics var collision_layer := 0:
	set(new_layer):
		if collision_layer == new_layer:
			return
		collision_layer = new_layer
		_update_mask()
		
@export var layer2_nodes :Array[Portal]
		
@export_flags_2d_physics var layer2 := 0:
	set(new_layer):
		if layer2 == new_layer:
			return
		layer2 = new_layer
		_update_mask()

func _update_mask() -> void:
	# Apply to body nodes (CollisionObject2D): set collision_layer bits
	for body in body_nodes:
		if is_instance_valid(body):
			body.collision_layer = collision_layer

	# Apply to portal1 nodes: mask1 = layer1, mask2 = collision_layer
	for p1 in layer1_nodes:
		if is_instance_valid(p1):
			p1.mask1 = layer1
			p1.mask2 = collision_layer

	# Apply to portal2 nodes: mask1 = collision_layer, mask2 = layer2
	for p2 in layer2_nodes:
		if is_instance_valid(p2):
			p2.mask1 = collision_layer
			p2.mask2 = layer2
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super._ready()
	_update_mask()
