extends Node2D

const PORTAL_SCENE: PackedScene = preload("res://architecture/components/portal.tscn")
const MASK_LEFT := 1 << 1
const MASK_RIGHT := 1 << 2
const DELTA_Z := 3

var m_failures: PackedStringArray = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var portal := PORTAL_SCENE.instantiate() as Portal
	add_child(portal)
	portal.mask1 = MASK_LEFT
	portal.mask2 = MASK_RIGHT
	portal.delta_z = DELTA_Z

	var actor_a := _make_body("ActorA", MASK_LEFT, 10)
	var actor_b := _make_body("ActorB", MASK_RIGHT, 20)
	add_child(actor_a)
	add_child(actor_b)

	actor_a.global_position = Vector2(-8, 0)
	portal._on_body_entered(actor_a)
	_assert_equal("ActorA widens collision mask on enter", actor_a.collision_mask, MASK_LEFT | MASK_RIGHT)

	actor_b.global_position = Vector2(8, 0)
	portal._on_body_entered(actor_b)
	_assert_equal("ActorB widens collision mask on enter", actor_b.collision_mask, MASK_LEFT | MASK_RIGHT)

	actor_a.global_position = Vector2(8, 0)
	portal._on_body_exited(actor_a)
	_assert_equal("ActorA resolves to destination mask", actor_a.collision_mask, MASK_RIGHT)
	_assert_equal("ActorA keeps its own upward z transition", actor_a.z_index, 10 + DELTA_Z)

	actor_b.global_position = Vector2(-8, 0)
	portal._on_body_exited(actor_b)
	_assert_equal("ActorB resolves to destination mask", actor_b.collision_mask, MASK_LEFT)
	_assert_equal("ActorB keeps its own downward z transition", actor_b.z_index, 20 - DELTA_Z)
	_assert_equal("Portal clears per-body transition state", portal.m_transition_state_by_body.size(), 0)

	if m_failures.is_empty():
		print("PASS: portal overlap validation")
	else:
		for failure in m_failures:
			push_error(failure)
		push_error("Portal overlap validation failed with %d issue(s)." % m_failures.size())

	await get_tree().create_timer(5.0).timeout
	get_tree().quit(0 if m_failures.is_empty() else 1)

func _make_body(node_name: String, initial_mask: int, initial_z: int) -> CharacterBody2D:
	var body := CharacterBody2D.new()
	body.name = node_name
	body.collision_mask = initial_mask
	body.z_index = initial_z
	return body

func _assert_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual == expected:
		print("PASS: %s" % label)
		return
	m_failures.append("%s. Expected %s, got %s." % [label, str(expected), str(actual)])
