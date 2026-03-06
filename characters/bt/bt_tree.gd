class_name BTTree
extends RefCounted

func get_root() -> BTNode:
	return m_root

func set_root(new_root: BTNode):
	m_root = new_root

func tick(ctx, delta: float) -> int:
	if m_root == null:
		return BTTypes.Status.FAILURE
	var res = m_root.tick(ctx, delta)
	
	if m_debug_enabled:
		m_last_executed_path = str(self) + ":"
		if m_root:
			m_last_executed_path += m_root.get_last_executed_path()
	return res
	
func set_debug_enabled(is_enabled: bool) -> void:
	m_debug_enabled = is_enabled
	m_last_executed_path = ""

func get_last_executed_path() -> String:
	return m_last_executed_path

# --- private ---
var m_root: BTNode
var m_last_executed_path: String
var m_debug_enabled: bool

func _init(root: BTNode = null):
	m_root = root

func _to_string() -> String:
	return "BTTree"
