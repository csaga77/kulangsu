extends Node2D

const BAGUA_TOWER_SCENE: PackedScene = preload("res://architecture/bagua_tower/bagua_tower.tscn")
const PLAYER_SCENE: PackedScene = preload("res://characters/human_body_2d.tscn")

const MOVE_FRAMES := 120
const SETTLE_FRAMES := 10
const ARRIVAL_RADIUS := 18.0

var m_failures := PackedStringArray()
var m_tower: Node2D = null
var m_player: CharacterBody2D = null
var m_stairs: Node2D = null
var m_ground_portal: Node2D = null
var m_upper_portal: Node2D = null
var m_roof_stairs: Node2D = null
var m_upper_roof_portal: Node2D = null
var m_roof_portal: Node2D = null
var m_ground_mask := 0
var m_upper_mask := 0
var m_roof_mask := 0
var m_roof_transition_mask := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	m_tower = BAGUA_TOWER_SCENE.instantiate() as Node2D
	add_child(m_tower)

	m_player = PLAYER_SCENE.instantiate() as CharacterBody2D
	m_player.name = "TestPlayer"
	m_player.add_to_group("player")
	add_child(m_player)

	m_stairs = m_tower.get_node("base/ground_level/stairs_se_to_ne_4_0") as Node2D
	m_ground_portal = m_stairs.get_node("portal_base_stairs_se") as Node2D
	m_upper_portal = m_stairs.get_node("portal_base_stairs_ne") as Node2D
	m_roof_stairs = m_tower.get_node("base/ground_level/upper_level/stairs_se_to_ne_4_1") as Node2D
	m_upper_roof_portal = m_roof_stairs.get_node("portal_base_stairs_se") as Node2D
	m_roof_portal = m_roof_stairs.get_node("portal_base_stairs_ne") as Node2D
	m_ground_mask = int(m_stairs.get("layer1"))
	m_upper_mask = int(m_stairs.get("layer2"))
	m_roof_transition_mask = int(m_roof_stairs.get("collision_layer"))
	m_roof_mask = int(m_roof_stairs.get("layer2"))

	_assert_equal("Roof stairs entry portal resolves upper mask", int(m_upper_roof_portal.get("mask1")), m_upper_mask)
	_assert_equal("Roof stairs entry portal resolves transition mask", int(m_upper_roof_portal.get("mask2")), m_roof_transition_mask)
	_assert_equal("Roof stairs exit portal resolves transition mask", int(m_roof_portal.get("mask1")), m_roof_transition_mask)
	_assert_equal("Roof stairs exit portal resolves roof mask", int(m_roof_portal.get("mask2")), m_roof_mask)

	m_player.collision_mask = m_ground_mask
	m_player.z_index = 2
	m_player.global_position = m_ground_portal.to_global(Vector2(-48.0, 8.0))

	await _settle()
	await _walk_to(m_ground_portal.to_global(Vector2(36.0, -4.0)))
	await _walk_to(m_upper_portal.to_global(Vector2(-28.0, 10.0)))
	await _walk_to(m_upper_portal.to_global(Vector2(48.0, 0.0)))

	_assert_equal("Player can physically climb from ground to upper stairs exit", m_player.collision_mask, m_upper_mask)
	_assert_equal("Player reaches upper z after physical stair climb", m_player.z_index, 4)

	m_player.global_position = m_upper_roof_portal.to_global(Vector2(-48.0, 8.0))
	await _settle()
	await _walk_to(m_upper_roof_portal.to_global(Vector2(36.0, -4.0)))
	await _walk_to(m_roof_portal.to_global(Vector2(-28.0, 10.0)))
	await _walk_to(m_roof_portal.to_global(Vector2(48.0, 0.0)))

	_assert_equal("Player can physically climb from upper to roof stairs exit", m_player.collision_mask, m_roof_mask)
	_assert_equal("Player reaches roof z after physical stair climb", m_player.z_index, 6)

	if m_failures.is_empty():
		print("PASS: Bagua stairs physical walk integration")
	else:
		for failure in m_failures:
			push_error(failure)
		push_error("Bagua stairs physical walk integration failed with %d issue(s)." % m_failures.size())

	await get_tree().create_timer(2.0).timeout
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
	for _frame in range(SETTLE_FRAMES):
		await get_tree().physics_frame
		await get_tree().process_frame

func _assert_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual == expected:
		print("PASS: %s" % label)
		return
	m_failures.append("%s. Expected %s, got %s." % [label, str(expected), str(actual)])
