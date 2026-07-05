class_name ResidentController3D
extends "res://characters/control/base_controller_3d.gd"

# Phase E of docs/plan/low_poly_3d_replacement.md: lightweight 3D resident movement.
#
# The 2D resident routes are tied to the tunnel/portal/level anchor graph, which the
# 3D world does not have yet. Until authored 3D routes exist, this controller gives
# each resident a calm local wander around its home anchor: pick a random nearby
# point, stroll to it (walk animation, facing the direction of travel), pause, repeat.
# Gravity, floor contact, and wall sliding come from HumanBody3D + the world colliders,
# so residents stay grounded and slide off buildings instead of clipping through.

@export var wander_radius := 4.0
@export var arrive_distance := 0.5
@export var wait_min := 1.5
@export var wait_max := 5.0
# Give up on an unreachable point (e.g. blocked by a wall) after this long moving.
@export var move_timeout := 5.0

var m_home := Vector3.ZERO
var m_target := Vector3.ZERO
var m_waiting := true
var m_wait_remaining := 0.0
var m_move_time := 0.0
var m_initialized := false


func configure(home: Vector3, radius: float) -> void:
	m_home = home
	wander_radius = radius
	m_target = home
	m_waiting = true
	m_wait_remaining = randf_range(0.0, wait_max)
	m_initialized = true


func _process(delta: float) -> void:
	if !is_instance_valid(m_character):
		return

	if !m_initialized:
		m_home = m_character.global_position
		m_target = m_home
		m_wait_remaining = randf_range(0.0, wait_max)
		m_initialized = true

	if m_waiting:
		m_wait_remaining -= delta
		stop_moving()
		m_character.set("is_walking", false)
		if m_wait_remaining <= 0.0:
			_pick_next_waypoint()
		return

	var flat_position := m_character.global_position
	var to_target := m_target - flat_position
	to_target.y = 0.0

	m_move_time += delta
	if to_target.length() < arrive_distance or m_move_time >= move_timeout:
		_begin_wait()
		return

	set_running(false)
	set_target_direction(to_target.normalized())
	move_forward()
	super._process(delta)


func _pick_next_waypoint() -> void:
	var angle := randf() * TAU
	var distance := randf() * wander_radius
	m_target = m_home + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
	m_waiting = false
	m_move_time = 0.0


func _begin_wait() -> void:
	m_waiting = true
	m_wait_remaining = randf_range(wait_min, wait_max)
	m_move_time = 0.0
	stop_moving()
	if is_instance_valid(m_character):
		m_character.set("is_walking", false)
