
class_name BTCondition
extends BTNode

func test(_ctx) -> bool:
	return false

func _type_name() -> String:
	return "BTCondition"

func _tick(ctx, _delta: float) -> BTTypes.Status:
	return (BTTypes.Status.SUCCESS if test(ctx) else BTTypes.Status.FAILURE)
