
class_name BTInverter
extends BTDecorator

func _type_name() -> String:
	return "BTInverter"

func _tick(ctx, delta: float) -> BTTypes.Status:
	if child == null:
		return BTTypes.Status.FAILURE
	var status := child.tick(ctx, delta)
	match status:
		BTTypes.Status.SUCCESS:
			return BTTypes.Status.FAILURE
		BTTypes.Status.FAILURE:
			return BTTypes.Status.SUCCESS
		_:
			return BTTypes.Status.RUNNING
