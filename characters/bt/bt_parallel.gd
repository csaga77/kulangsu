# BTParallel.gd
# Ticks all children each frame.
# Success/Failure determined by configured policies.
class_name BTParallel
extends BTComposite

@export var success_policy := BTTypes.ParallelSuccessPolicy.REQUIRE_ALL
@export var failure_policy := BTTypes.ParallelFailurePolicy.REQUIRE_ANY

func _type_name() -> String:
	return "BTParallel"

func _open(_ctx) -> void:
	m_running_child = -1

func _tick(ctx, delta: float) -> BTTypes.Status:
	if children.is_empty():
		return BTTypes.Status.SUCCESS

	#var any_running := false
	var success_count := 0
	var failure_count := 0

	for i in range(children.size()):
		var st := children[i].tick(ctx, delta)
		match st:
			BTTypes.Status.RUNNING:
				#any_running = true
				pass
			BTTypes.Status.SUCCESS:
				success_count += 1
			BTTypes.Status.FAILURE:
				failure_count += 1

	# Evaluate failure policy first (common in BT Parallel)
	if failure_policy == BTTypes.ParallelFailurePolicy.REQUIRE_ANY and failure_count > 0:
		# abort any running children to clean up
		for c in children:
			c.abort(ctx)
		return BTTypes.Status.FAILURE
	elif failure_policy == BTTypes.ParallelFailurePolicy.REQUIRE_ALL and failure_count == children.size():
		return BTTypes.Status.FAILURE

	# Evaluate success policy
	if success_policy == BTTypes.ParallelSuccessPolicy.REQUIRE_ALL and success_count == children.size():
		return BTTypes.Status.SUCCESS
	elif success_policy == BTTypes.ParallelSuccessPolicy.REQUIRE_ANY and success_count > 0:
		for c in children:
			c.abort(ctx)
		return BTTypes.Status.SUCCESS

	# Any is running
	return BTTypes.Status.RUNNING
