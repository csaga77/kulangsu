
class_name BTCooldown
extends BTDecorator

@export var key := "cooldown_generic"
@export var duration := 1.0

func _type_name() -> String:
	return "BTCooldown"

func _tick(ctx, delta: float) -> BTTypes.Status:
	if ctx.blackboard.get_time_since(key, ctx.get_time_stamp(), INF) < max(0.0, duration):
		return BTTypes.Status.FAILURE
	var status := (child.tick(ctx, delta) if child else BTTypes.Status.FAILURE)
	if status == BTTypes.Status.SUCCESS:
		ctx.blackboard.stamp(key, ctx.get_time_stamp())
	return status
