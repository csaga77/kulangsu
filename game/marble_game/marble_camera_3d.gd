@tool
class_name MarbleGameCamera3D
extends Camera3D

@export var look_target: Vector3 = Vector3(6.8, 0.0, 4.4):
	set(value):
		look_target = value
		_update_orientation()


func _ready() -> void:
	_update_orientation()


func _update_orientation() -> void:
	if is_inside_tree() and global_position.distance_squared_to(look_target) > 0.0001:
		look_at(look_target, Vector3.UP)
