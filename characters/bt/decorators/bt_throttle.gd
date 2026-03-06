
class_name BTThrottle
extends BTDecorator

@export var interval := 0.2
var m_last := -INF

func _type_name() -> String:
	return "BTThrottle"

func _tick(ctx, delta: float) -> BTTypes.Status:
	var now = ctx.get_time_stamp()
	if now - m_last < max(0.0, interval):
		return BTTypes.Status.RUNNING
	m_last = now
	return child.tick(ctx, delta) if child else BTTypes.Status.FAILURE
