class_name BTSequence
extends BTComposite

func get_last_executed_path() -> String:
	return str(self) + ("/" + m_last_child.get_last_executed_path()) if m_last_child else ""

var m_last_child: BTNode

func _type_name() -> String:
	return "BTSequence"

func _open(_ctx) -> void:
	m_running_child = -1

func _tick(ctx, delta: float) -> BTTypes.Status:
	m_last_child = null
	var start: int = max(m_running_child, 0)
	for i in range(start, children.size()):
		var status := children[i].tick(ctx, delta)
		m_last_child = children[i]
		if status == BTTypes.Status.RUNNING:
			m_running_child = i
			return BTTypes.Status.RUNNING
		elif status == BTTypes.Status.FAILURE:
			m_running_child = -1
			m_last_child = children[i]
			return BTTypes.Status.FAILURE
	m_running_child = -1
	return BTTypes.Status.SUCCESS
