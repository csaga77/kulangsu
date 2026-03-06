
class_name BTSucceeder
extends BTDecorator

func _type_name() -> String:
	return "BTSucceeder"

func _tick(ctx, delta: float) -> BTTypes.Status:
	if child == null:
		return BTTypes.Status.SUCCESS
	child.tick(ctx, delta)
	return BTTypes.Status.SUCCESS
