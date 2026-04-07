class_name ResidentSpawner
extends RefCounted

const NPC_SCENE: PackedScene = preload("res://characters/resident_npc.tscn")


func spawn_catalog_residents(
	actor_root: Node2D,
	app_state: Node,
	route_resolver: RefCounted,
	tunnel_sync_callback: Callable = Callable()
) -> Node2D:
	if Engine.is_editor_hint():
		return null
	if !is_instance_valid(actor_root):
		return null

	var resident_root := Node2D.new()
	resident_root.name = "Residents"
	resident_root.y_sort_enabled = true
	actor_root.add_child(resident_root)

	for resident_id_value in app_state.get_resident_ids():
		var resident_id := String(resident_id_value)
		var resident_definition = app_state.get_resident_definition(resident_id)
		if resident_definition == null:
			push_warning("Missing resident definition for resident '%s'." % resident_id)
			continue

		var spawn_config = resident_definition.get_spawn_config()
		var anchor_id := String(spawn_config.get("anchor_id", ""))
		var anchor_node := route_resolver.m_spawn_anchor_nodes.get(anchor_id) as Node2D
		if !is_instance_valid(anchor_node):
			push_warning("Missing NPC spawn anchor '%s' for resident '%s'." % [anchor_id, resident_id])
			continue

		var npc := NPC_SCENE.instantiate() as HumanBody2D
		if npc == null:
			continue
		if npc.has_method("apply_definition"):
			npc.call("apply_definition", resident_definition, resident_id)

		var controller := NPCController.new()
		controller.use_json_bt = false
		controller.resident_id = StringName(resident_id)
		controller.interaction_radius = float(spawn_config.get("interaction_radius", 72.0))

		npc.controller = controller
		npc.direction = float(spawn_config.get("direction", 0.0))
		npc.facial_mood = int(spawn_config.get("mood", HumanBody2D.FacialMoodEnum.NORMAL)) as HumanBody2D.FacialMoodEnum

		resident_root.add_child(npc)
		var spawn_offset: Vector2 = spawn_config.get("offset", Vector2.ZERO)
		npc.global_position = route_resolver.resolve_actor_anchor_position(npc, anchor_node, spawn_offset)
		route_resolver.apply_anchor_level_to_actor(npc, anchor_node)

		var movement_config: Dictionary = route_resolver.build_resident_movement_config(
			resident_id,
			npc,
			resident_definition.get_movement_config()
		)
		if !movement_config.is_empty():
			controller.configure_movement(movement_config)

		if tunnel_sync_callback.is_valid() and !npc.global_position_changed.is_connected(tunnel_sync_callback):
			npc.global_position_changed.connect(tunnel_sync_callback)

	return resident_root
