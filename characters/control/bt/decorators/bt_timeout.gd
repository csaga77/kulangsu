
class_name BTTimeout
extends BTDecorator

@export var seconds := 1.5
var m_start := -1.0

func _type_name() -> String:
	return "BTTimeout"

func _open(ctx) -> void:
	m_start = ctx.get_time_stamp()

func _tick(ctx, delta: float) -> BTTypes.Status:
	if child == null:
		return BTTypes.Status.FAILURE
	if ctx.get_time_stamp() - m_start > max(0.0, seconds):
		child.close(ctx, BTTypes.Status.FAILURE)
		m_start = -1.0
		return BTTypes.Status.FAILURE
	var res = child.tick(ctx, delta)
	return res
