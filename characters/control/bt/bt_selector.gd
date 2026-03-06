# BTSelector.gd
# Standard Selector: returns SUCCESS on first child SUCCESS.
# If a child is RUNNING, selector returns RUNNING and remembers that child.
class_name BTSelector
extends BTComposite

func get_last_executed_path() -> String:
	return str(self) + ("/" + m_last_child.get_last_executed_path()) if m_last_child else ""

var m_last_child: BTNode = null

func _type_name() -> String:
	return "BTSelector"

func _open(_ctx) -> void:
	m_running_child = -1

func _tick(ctx, delta: float) -> BTTypes.Status:
	m_last_child = null
	for i in range(children.size()):
		var st := children[i].tick(ctx, delta)
		m_last_child = children[i]
		match st:
			BTTypes.Status.SUCCESS:
				if m_running_child != -1 and m_running_child != i:
					children[m_running_child].abort(ctx)
				m_running_child = -1
				return BTTypes.Status.SUCCESS
			BTTypes.Status.RUNNING:
				if m_running_child != -1 and m_running_child != i:
					children[m_running_child].abort(ctx)
				m_running_child = i
				return BTTypes.Status.RUNNING
			_:
				# FAILURE -> keep trying others
				pass

	# all failed
	if m_running_child != -1:
		children[m_running_child].abort(ctx)
		m_running_child = -1
	return BTTypes.Status.FAILURE
