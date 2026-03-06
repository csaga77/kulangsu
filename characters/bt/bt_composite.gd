# BTComposite.gd
class_name BTComposite
extends BTNode

var children: Array[BTNode] = []
var m_running_child := -1

func _type_name() -> String:
	return "BTComposite"

func _init(new_children: Array[BTNode] = []):
	children = new_children

func add_child_node(node: BTNode) -> void:
	children.append(node)

func _close(ctx) -> void:
	if m_running_child != -1:
		children[m_running_child].abort(ctx)
		m_running_child = -1
