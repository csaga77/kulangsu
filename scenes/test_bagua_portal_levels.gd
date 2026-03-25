extends Node2D

const BAGUA_TOWER_SCENE: PackedScene = preload("res://architecture/bagua_tower/bagua_tower.tscn")
const PLAYER_SCENE: PackedScene = preload("res://characters/human_body_2d.tscn")

const MOVE_FRAMES := 90
const ARRIVAL_RADIUS := 16.0

var m_failures := PackedStringArray()
var m_tower: Node2D = null
var m_player: CharacterBody2D = null
var m_portal: Node2D = null
var m_level_context: Node = null

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	m_tower = BAGUA_TOWER_SCENE.instantiate() as Node2D
	add_child(m_tower)

	m_player = PLAYER_SCENE.instantiate() as CharacterBody2D
	m_player.name = "TestPlayer"
	add_child(m_player)
	GameGlobal.get_instance().set_player(m_player)

	m_level_context = m_tower.get_node("base/level_context")
	m_portal = m_tower.get_node("base/portal_ne_0") as Node2D

	var base_mask := int(m_level_context.call("resolve_level_collision_mask", 0, 0))
	var ground_mask := int(m_level_context.call("resolve_level_collision_mask", 2, 0))
	var base_z := int(m_level_context.call("resolve_level_z_index", 0, -1))
	var ground_z := int(m_level_context.call("resolve_level_z_index", 2, 0))
	var ground_portal_mask := int(m_portal.get("mask2"))

	_assert_equal("Context resolves the base collision mask", base_mask, 524288)
	_assert_equal("Context resolves the ground collision mask", ground_mask, 2097152)
	_assert_equal("Context resolves the base z_index", base_z, 0)
	_assert_equal("Context resolves the ground z_index", ground_z, 2)
	_assert_equal("Portal destination mask resolves to the ground floor", ground_portal_mask, ground_mask)
	_assert_equal("Context applies the base level to the player", m_level_context.call("apply_level_to_actor", 0, m_player), true)

	m_player.global_position = m_portal.to_global(Vector2(-56.0, 0.0))
	await _settle()

	await _walk_to(m_portal.to_global(Vector2(56.0, 0.0)))
	_assert_equal("Direct Bagua portal reaches the ground collision mask", m_player.collision_mask, ground_mask)
	_assert_equal("Direct Bagua portal reaches the ground z_index", m_player.z_index, ground_z)

	await _walk_to(m_portal.to_global(Vector2(-56.0, 0.0)))
	_assert_equal("Direct Bagua portal returns to the base collision mask", m_player.collision_mask, base_mask)
	_assert_equal("Direct Bagua portal returns to the base z_index", m_player.z_index, base_z)

	if m_failures.is_empty():
		print("PASS: Bagua direct portal level integration")
	else:
		for failure in m_failures:
			push_error(failure)
		push_error("Bagua direct portal level integration failed with %d issue(s)." % m_failures.size())

	await get_tree().create_timer(3.0).timeout
	get_tree().quit(0 if m_failures.is_empty() else 1)

func _walk_to(target_position: Vector2) -> void:
	for _frame in range(MOVE_FRAMES):
		var to_target := target_position - m_player.global_position
		if to_target.length() <= ARRIVAL_RADIUS:
			break
		m_player.move(to_target)
		await get_tree().physics_frame
		await get_tree().process_frame
	await _settle()

func _settle() -> void:
	await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().process_frame

func _assert_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual == expected:
		print("PASS: %s" % label)
		return
	m_failures.append("%s. Expected %s, got %s." % [label, str(expected), str(actual)])
