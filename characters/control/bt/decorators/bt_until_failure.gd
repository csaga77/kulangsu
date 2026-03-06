class_name BTUntilFailure
extends BTDecorator

func _type_name() -> String:
	return "BTUntilFailure"

func _tick(ctx, delta: float) -> BTTypes.Status:
	if not child:
		return BTTypes.Status.FAILURE

	var st := child.tick(ctx, delta)
	# Keep running until child returns FAILURE
	match st:
		BTTypes.Status.FAILURE:
			return BTTypes.Status.SUCCESS   # finished loop
		BTTypes.Status.RUNNING, BTTypes.Status.SUCCESS:
			return BTTypes.Status.RUNNING

	return BTTypes.Status.FAILURE
