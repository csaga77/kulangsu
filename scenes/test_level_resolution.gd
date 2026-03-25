extends Node

const LEVEL_NODE_SCRIPT := preload("res://common/level_node_2d.gd")
const LEVEL_REGISTRY := preload("res://common/level_registry.gd")

var m_failures := PackedStringArray()

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var parent_level: Node = LEVEL_NODE_SCRIPT.new()
	parent_level.name = "ParentLevel"
	parent_level.set("level_id", 2)
	add_child(parent_level)

	var child_room: Node = LEVEL_NODE_SCRIPT.new()
	child_room.name = "ChildRoom"
	child_room.set("level_id_mode", LEVEL_REGISTRY.LevelIdMode.RELATIVE_TO_PARENT)
	child_room.set("level_id", 2)
	parent_level.add_child(child_room)

	var grandchild_room: Node = LEVEL_NODE_SCRIPT.new()
	grandchild_room.name = "GrandchildRoom"
	grandchild_room.set("level_id_mode", LEVEL_REGISTRY.LevelIdMode.RELATIVE_TO_PARENT)
	grandchild_room.set("level_id", 0)
	child_room.add_child(grandchild_room)

	var relative_portal := Portal.new()
	relative_portal.name = "RelativePortal"
	relative_portal.level_id_mode = LEVEL_REGISTRY.LevelIdMode.RELATIVE_TO_PARENT
	relative_portal.level_from = 0
	relative_portal.level_to = 2
	child_room.add_child(relative_portal)

	await get_tree().process_frame
	_assert_equal("Parent keeps its absolute level_id", parent_level.call("get_resolved_level_id"), 2)
	_assert_equal("Child room resolves its relative level_id from the closest parent", child_room.call("get_resolved_level_id"), 4)
	_assert_equal("Grandchild keeps the same resolved level with a zero relative offset", grandchild_room.call("get_resolved_level_id"), 4)
	_assert_equal("Relative portal resolves its own level from the closest level-aware parent", relative_portal.get_resolved_level_id(), 4)
	_assert_equal("Relative portal resolves its source mask from the parent-relative from level", relative_portal.mask1, 8388608)
	_assert_equal("Relative portal resolves its destination mask from the parent-relative to level", relative_portal.mask2, 33554432)

	parent_level.set("level_id", 0)
	await get_tree().process_frame
	_assert_equal("Child follows parent changes when it uses relative level ids", child_room.call("get_resolved_level_id"), 2)
	_assert_equal("Grandchild still follows the closest level-aware parent after the parent changes", grandchild_room.call("get_resolved_level_id"), 2)
	_assert_equal("Relative portal updates its own resolved level after the parent changes", relative_portal.get_resolved_level_id(), 2)
	_assert_equal("Relative portal updates its source mask after the parent changes", relative_portal.mask1, 2097152)
	_assert_equal("Relative portal updates its destination mask after the parent changes", relative_portal.mask2, 8388608)

	if m_failures.is_empty():
		print("PASS: level resolution validation")
	else:
		for failure in m_failures:
			push_error(failure)
		push_error("Level resolution validation failed with %d issue(s)." % m_failures.size())

	await get_tree().create_timer(5.0).timeout
	get_tree().quit(0 if m_failures.is_empty() else 1)

func _assert_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual == expected:
		print("PASS: %s" % label)
		return
	m_failures.append("%s. Expected %s, got %s." % [label, str(expected), str(actual)])
