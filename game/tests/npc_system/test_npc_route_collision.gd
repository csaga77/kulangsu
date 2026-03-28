@tool
extends Node

const NPC_SCENE := preload("res://characters/human_body_2d.tscn")
const START_POSITION := Vector2(-96.0, 0.0)
const TARGET_POSITION := Vector2(96.0, 0.0)
const WALL_COLLISION_LAYER := 1
const WALL_SHAPE_SIZE := Vector2(24.0, 128.0)
const WALL_SHAPE_POSITION := Vector2(0.0, -7.0)
const WAIT_TIMEOUT_SEC := 2.5


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	call_deferred("_run")


func _run() -> void:
	var wall := StaticBody2D.new()
	wall.name = "Wall"
	wall.collision_layer = WALL_COLLISION_LAYER
	wall.collision_mask = 0

	var wall_shape := CollisionShape2D.new()
	var wall_rect := RectangleShape2D.new()
	wall_rect.size = WALL_SHAPE_SIZE
	wall_shape.shape = wall_rect
	wall_shape.position = WALL_SHAPE_POSITION
	wall.add_child(wall_shape)
	add_child(wall)

	var controller := NPCController.new()
	controller.use_json_bt = false
	controller.interaction_radius = 0.0
	controller.configure_movement({
		"route_points": [
			{
				"position": START_POSITION,
				"wait_min_sec": 0.0,
				"wait_max_sec": 0.0,
			},
			{
				"position": TARGET_POSITION,
				"wait_min_sec": 0.0,
				"wait_max_sec": 0.0,
			},
		],
		"arrival_radius": 8.0,
		"wait_min_sec": 0.0,
		"wait_max_sec": 0.0,
		"ping_pong": false,
	})

	var npc := NPC_SCENE.instantiate() as HumanBody2D
	npc.name = "Route Collision NPC"
	npc.global_position = START_POSITION
	npc.collision_mask = WALL_COLLISION_LAYER
	npc.controller = controller
	add_child(npc)

	await _wait_for_route_attempt(npc, WAIT_TIMEOUT_SEC)

	_assert(
		npc.global_position.x > START_POSITION.x + 8.0,
		"%s should attempt to move toward the blocked route target." % npc.name
	)
	_assert(
		npc.global_position.x < -4.0,
		"%s should stop at the wall instead of passing through it." % npc.name
	)

	print("NPC route collision regression passed.")
	get_tree().quit(0)


func _wait_for_route_attempt(npc: HumanBody2D, timeout_sec: float) -> void:
	var elapsed := 0.0
	while elapsed < timeout_sec:
		if npc.global_position.distance_to(START_POSITION) > 8.0:
			await _settle()
			return

		await get_tree().physics_frame
		await get_tree().process_frame
		elapsed += get_process_delta_time()

	_assert(false, "%s did not begin route movement within %.1f seconds." % [npc.name, timeout_sec])


func _settle() -> void:
	await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().process_frame


func _assert(condition: bool, message: String) -> void:
	if condition:
		return

	push_error(message)
	get_tree().quit(1)
