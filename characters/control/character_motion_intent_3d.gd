class_name CharacterMotionIntent3D
extends RefCounted

## One physics-tick request from a character controller to HumanBody3D.
## Controllers describe intent only; HumanBody3D remains the sole velocity and
## move_and_slide() owner.

var direction := Vector3.ZERO
var movement_speed := 0.0


func _init(requested_direction := Vector3.ZERO, requested_speed := 0.0) -> void:
	var flat_direction := Vector3(requested_direction.x, 0.0, requested_direction.z)
	direction = flat_direction.normalized() if !flat_direction.is_zero_approx() else Vector3.ZERO
	movement_speed = maxf(requested_speed, 0.0)


func is_moving() -> bool:
	return movement_speed > 0.0 and !direction.is_zero_approx()
