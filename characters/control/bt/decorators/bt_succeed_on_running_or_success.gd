class_name BTSucceedOnRunningOrSuccess
extends BTDecorator

func _type_name() -> String:
	return "BTSucceedOnRunningOrSuccess"

func _tick(ctx, delta) -> BTTypes.Status:
	if not child:
		return BTTypes.Status.FAILURE
	var status := child.tick(ctx, delta)
	if status == BTTypes.Status.FAILURE:
		return BTTypes.Status.FAILURE
	else:
		# Treat RUNNING and SUCCESS as SUCCESS
		return BTTypes.Status.SUCCESS
