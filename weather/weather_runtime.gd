class_name WeatherRuntime
extends RefCounted

const WEATHER_MANAGER_GROUP := &"weather_manager_service"
const WEATHER_MANAGER_SCRIPT := preload("res://weather/weather_manager.gd")


static func get_weather_manager(context: Node) -> WeatherManager:
	var tree := _resolve_tree(context)
	if tree == null:
		return null

	var existing := tree.get_first_node_in_group(WEATHER_MANAGER_GROUP) as WeatherManager
	if existing != null and is_instance_valid(existing):
		return existing

	var manager := WEATHER_MANAGER_SCRIPT.new() as WeatherManager
	manager.name = "WeatherManager"
	var parent := _resolve_service_parent(context, tree)
	if parent == null:
		return null
	parent.add_child(manager)
	manager.add_to_group(WEATHER_MANAGER_GROUP)
	return manager


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
