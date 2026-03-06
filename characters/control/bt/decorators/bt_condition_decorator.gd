class_name BTConditionDecorator
extends BTDecorator

var child_condition: BTNode

func _type_name() -> String:
	return "BTCooldown"

func _tick(ctx, delta: float) -> BTTypes.Status:
	if child == null:
		return BTTypes.Status.FAILURE
	if child_condition:
		var condition_status = child_condition.tick(ctx, delta)
		if condition_status != BTTypes.Status.SUCCESS:
			return condition_status
	return child.tick(ctx, delta)
