class_name PlayerRecoveryController3D
extends Resource

## Scene-local safe-transform tracker for HumanBody3D.
##
## This resource owns no story or AppState data. The actor supplies grounded/free
## observations after its single physics integration and performs the actual
## recovery transition when this controller reports an out-of-bounds condition.

@export_range(0.0, 2.0, 0.01) var stable_seconds := 0.25
@export_range(0.0, 20.0, 0.1) var drop_distance := 4.00
@export_range(0.0, 10.0, 0.1) var unsupported_seconds := 2.50
@export_range(0.0, 5.0, 0.1) var stable_vertical_speed := 0.50

var m_actor: Node3D = null
var m_has_safe_transform := false
var m_safe_transform := Transform3D.IDENTITY
var m_stable_timer := 0.0
var m_unsupported_timer := 0.0


func setup(actor: Node3D) -> void:
	m_actor = actor
	if is_instance_valid(m_actor) and !m_has_safe_transform:
		set_safe_transform(m_actor.global_transform)


func teardown() -> void:
	reset_transient_tracking()
	m_actor = null


func set_safe_transform(safe_transform: Transform3D) -> void:
	m_safe_transform = safe_transform
	m_has_safe_transform = true
	m_stable_timer = 0.0


func get_safe_transform() -> Transform3D:
	return m_safe_transform


func has_safe_transform() -> bool:
	return m_has_safe_transform


func update_after_motion(
	delta: float,
	is_grounded: bool,
	is_free: bool,
	vertical_speed: float
) -> bool:
	if !is_instance_valid(m_actor):
		return false
	if is_grounded:
		m_unsupported_timer = 0.0
	else:
		m_unsupported_timer += maxf(delta, 0.0)

	if is_grounded and is_free and absf(vertical_speed) <= stable_vertical_speed:
		m_stable_timer += maxf(delta, 0.0)
		if m_stable_timer >= stable_seconds:
			set_safe_transform(m_actor.global_transform)
	else:
		m_stable_timer = 0.0

	if !m_has_safe_transform:
		return false
	if m_actor.global_position.y <= m_safe_transform.origin.y - drop_distance:
		return true
	return m_unsupported_timer >= unsupported_seconds


func reset_transient_tracking() -> void:
	m_stable_timer = 0.0
	m_unsupported_timer = 0.0
