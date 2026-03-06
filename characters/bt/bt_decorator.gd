
class_name BTDecorator
extends BTNode

var child: BTNode

func get_last_executed_path() -> String:
	return str(self) + ("/" + child.get_last_executed_path()) if child else ""
	
func set_child(node: BTNode) -> void:
	child = node

func _type_name() -> String:
	return "BTDecorator"

func _init(new_child: BTNode = null):
	set_child(new_child)
