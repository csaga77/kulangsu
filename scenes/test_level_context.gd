extends Node

const LEVEL_NODE_SCRIPT := preload("res://common/level_node_2d.gd")

var m_failures := PackedStringArray()

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var level_context := LevelContext2D.new()
	level_context.set("runtime_levels", PackedInt32Array([2, 4, 6]))
	add_child(level_context)

	var parent_level: Node = LEVEL_NODE_SCRIPT.new()
	parent_level.name = "ParentLevel"
	parent_level.set("level_source", LEVEL_NODE_SCRIPT.LevelSource.CONTEXT_SLOT)
	parent_level.set("level_slot", 1)
	level_context.add_child(parent_level)

	var child_room: Node = LEVEL_NODE_SCRIPT.new()
	child_room.name = "ChildRoom"
	child_room.set("level_source", LEVEL_NODE_SCRIPT.LevelSource.INHERIT_PARENT)
	parent_level.add_child(child_room)

	await get_tree().process_frame
	_assert_equal("Parent resolves runtime level from context slot", parent_level.call("get_resolved_level"), 4)
	_assert_equal("Child room inherits resolved parent level", child_room.call("get_resolved_level"), 4)

	level_context.set("runtime_levels", PackedInt32Array([2, 8, 10]))
	await get_tree().process_frame
	_assert_equal("Parent reacts to context runtime level changes", parent_level.call("get_resolved_level"), 8)
	_assert_equal("Child follows parent after context change", child_room.call("get_resolved_level"), 8)

	parent_level.set("level_source", LEVEL_NODE_SCRIPT.LevelSource.EXPLICIT)
	parent_level.set("level", 5)
	await get_tree().process_frame
	_assert_equal("Parent can switch back to explicit levels", parent_level.call("get_resolved_level"), 5)
	_assert_equal("Child still inherits after parent switches source", child_room.call("get_resolved_level"), 5)

	if m_failures.is_empty():
		print("PASS: level context validation")
	else:
		for failure in m_failures:
			push_error(failure)
		push_error("Level context validation failed with %d issue(s)." % m_failures.size())

	await get_tree().create_timer(5.0).timeout
	get_tree().quit(0 if m_failures.is_empty() else 1)

func _assert_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual == expected:
		print("PASS: %s" % label)
		return
	m_failures.append("%s. Expected %s, got %s." % [label, str(expected), str(actual)])
