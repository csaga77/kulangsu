extends Node2D

const BAGUA_TOWER_SCENE: PackedScene = preload("res://architecture/bagua_tower/bagua_tower.tscn")
const PLAYER_SCENE: PackedScene = preload("res://characters/human_body_2d.tscn")

const PORTAL_SWEEP_DISTANCE := 56.0
const TRAVEL_STEPS := 12

var m_failures := PackedStringArray()
var m_tower: Node2D = null
var m_player: CharacterBody2D = null
var m_upper_level: Node2D = null
var m_ground_floor: TileMapLayer = null
var m_upper_floor: TileMapLayer = null
var m_stairs: Node = null
var m_ground_portal: Node2D = null
var m_upper_portal: Node2D = null
var m_ground_mask := 0
var m_upper_mask := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	m_tower = BAGUA_TOWER_SCENE.instantiate() as Node2D
	add_child(m_tower)

	m_player = PLAYER_SCENE.instantiate() as CharacterBody2D
	m_player.name = "TestPlayer"
	m_player.add_to_group("player")
	add_child(m_player)

	m_upper_level = m_tower.get_node("base/ground_level/upper_level") as Node2D
	m_ground_floor = m_tower.get_node("base/ground_level/ground_level_floor") as TileMapLayer
	m_upper_floor = m_tower.get_node("base/ground_level/upper_level/upper_floor") as TileMapLayer
	m_stairs = m_tower.get_node("base/ground_level/stairs_se_to_ne_4_0")
	m_ground_portal = m_stairs.get_node("portal_base_stairs_se") as Node2D
	m_upper_portal = m_stairs.get_node("portal_base_stairs_ne") as Node2D
	m_ground_mask = int(m_stairs.get("layer1"))
	m_upper_mask = int(m_stairs.get("layer2"))

	m_upper_level.set("smooth_visibility_change", false)
	m_player.collision_mask = m_ground_mask
	m_player.z_index = 2

	await _settle()

	if await _probe_visibility(m_ground_floor, false, "Upper level hides while player is on the ground floor"):
		_assert_equal("Upper level starts hidden from the ground floor", m_upper_level.visible, false)

	await _walk_stairs_up()
	_assert_equal("Player reaches the upper-level collision mask after climbing stairs", m_player.collision_mask, m_upper_mask)
	_assert_equal("Player z_index increases onto the upper level", m_player.z_index, 4)

	if await _probe_visibility(m_upper_floor, true, "Upper level becomes visible after the player reaches the upper floor"):
		_assert_equal("Upper level stays visible while the player is on the upper floor", m_upper_level.visible, true)

	await _walk_stairs_down()
	_assert_equal("Player returns to the ground-level collision mask after descending stairs", m_player.collision_mask, m_ground_mask)
	_assert_equal("Player z_index returns to the ground level", m_player.z_index, 2)

	if await _probe_visibility(m_ground_floor, false, "Upper level hides again after the player returns to the ground floor"):
		_assert_equal("Upper level is hidden again on the ground floor", m_upper_level.visible, false)

	if m_failures.is_empty():
		print("PASS: Bagua stairs visibility integration")
	else:
		for failure in m_failures:
			push_error(failure)
		push_error("Bagua stairs visibility integration failed with %d issue(s)." % m_failures.size())

	await get_tree().create_timer(5.0).timeout
	get_tree().quit(0 if m_failures.is_empty() else 1)

func _walk_stairs_up() -> void:
	await _move_player(m_ground_portal.to_global(Vector2(-PORTAL_SWEEP_DISTANCE, 0.0)))
	await _sweep_portal(m_ground_portal, -PORTAL_SWEEP_DISTANCE, PORTAL_SWEEP_DISTANCE)
	await _move_between(
		m_ground_portal.to_global(Vector2(PORTAL_SWEEP_DISTANCE, 0.0)),
		m_upper_portal.to_global(Vector2(-PORTAL_SWEEP_DISTANCE, 0.0))
	)
	await _sweep_portal(m_upper_portal, -PORTAL_SWEEP_DISTANCE, PORTAL_SWEEP_DISTANCE)

func _walk_stairs_down() -> void:
	await _move_player(m_upper_portal.to_global(Vector2(PORTAL_SWEEP_DISTANCE, 0.0)))
	await _sweep_portal(m_upper_portal, PORTAL_SWEEP_DISTANCE, -PORTAL_SWEEP_DISTANCE)
	await _move_between(
		m_upper_portal.to_global(Vector2(-PORTAL_SWEEP_DISTANCE, 0.0)),
		m_ground_portal.to_global(Vector2(PORTAL_SWEEP_DISTANCE, 0.0))
	)
	await _sweep_portal(m_ground_portal, PORTAL_SWEEP_DISTANCE, -PORTAL_SWEEP_DISTANCE)

func _probe_visibility(tile_map: TileMapLayer, expected_visible: bool, label: String) -> bool:
	for cell in tile_map.get_used_cells():
		var probe_position := tile_map.to_global(tile_map.map_to_local(cell))
		await _move_player(probe_position)
		if m_upper_level.visible == expected_visible:
			print("PASS: %s" % label)
			return true

	m_failures.append("%s." % label)
	return false

func _sweep_portal(portal: Node2D, from_local_x: float, to_local_x: float) -> void:
	for step in range(TRAVEL_STEPS + 1):
		var weight := float(step) / float(TRAVEL_STEPS)
		var local_position := Vector2(lerpf(from_local_x, to_local_x, weight), 0.0)
		await _move_player(portal.to_global(local_position))

func _move_between(from_position: Vector2, to_position: Vector2) -> void:
	for step in range(TRAVEL_STEPS + 1):
		var weight := float(step) / float(TRAVEL_STEPS)
		await _move_player(from_position.lerp(to_position, weight))

func _move_player(target_position: Vector2) -> void:
	m_player.global_position = target_position
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
