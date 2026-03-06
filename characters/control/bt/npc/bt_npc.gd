class_name BTNPC
extends Resource

class TurningCircle extends BTNode:

	@export var angular_speed: float = 1.2 # radians per second

	func _type_name() -> String:
		return "TurningCircle"

	func _tick(ctx: BaseController, delta: float) -> BTTypes.Status:
		if ctx.is_talking():
			ctx.stop_moving()
			return BTTypes.Status.RUNNING

		var dir: Vector2 = ctx.get_direction_vector()
		if dir.is_zero_approx():
			dir = Vector2.RIGHT

		var angle: float = dir.angle()
		angle += angular_speed * delta

		var new_dir: Vector2 = Vector2.RIGHT.rotated(angle)
		ctx.set_running(false)
		ctx.set_target_direction(new_dir)
		ctx.move_forward()

		return BTTypes.Status.RUNNING
