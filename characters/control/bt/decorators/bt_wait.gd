class_name BTWait
extends BTDecorator

var duration := 0.0
var start := 0.0

func _init(new_duration: float = 0.0, new_child: BTNode = null) -> void:
	super._init(new_child)
	duration = new_duration

func _open(ctx: BaseController) -> void:
	start = ctx.get_time_stamp()

func _type_name() -> String:
	return "BTWait"

func _tick(ctx: BaseController, delta: float) -> BTTypes.Status:
	if not child:
		return BTTypes.Status.FAILURE

	if ctx.get_time_stamp() - start < duration:
		return BTTypes.Status.RUNNING
		
	return child.tick(ctx, delta)
