class_name AppRuntime
extends RefCounted

const APP_STATE_GROUP := &"app_state_service"
const APP_STATE_SCRIPT := preload("res://game/app_state.gd")


static func get_app_state(context: Node):
	var tree := _resolve_tree(context)
	if tree == null:
		return null

	var existing := tree.get_first_node_in_group(APP_STATE_GROUP)
	if existing != null and is_instance_valid(existing):
		return existing

	var state = APP_STATE_SCRIPT.new()
	state.name = "AppState"
	var parent := _resolve_service_parent(context, tree)
	parent.add_child(state)
	return state


static func get_player(context: Node):
	var tree := _resolve_tree(context)
	if tree == null:
		return null

	var player := tree.get_first_node_in_group("player") as HumanBody2D
	if player != null and is_instance_valid(player):
		return player
	return null


static func _resolve_tree(context: Node) -> SceneTree:
	if context != null and context.get_tree() != null:
		return context.get_tree()

	var main_loop := Engine.get_main_loop()
	return main_loop as SceneTree


static func _resolve_service_parent(context: Node, tree: SceneTree) -> Node:
	if tree == null:
		return null

	var current_scene := tree.current_scene
	if current_scene != null and is_instance_valid(current_scene):
		return current_scene

	if context != null and context.is_inside_tree():
		var scene_root := context
		while scene_root.get_parent() != null and scene_root.get_parent() != tree.root:
			scene_root = scene_root.get_parent()
		return scene_root

	return tree.root
