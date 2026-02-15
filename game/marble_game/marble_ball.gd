# MarbleBall.gd
class_name MarbleBall
extends RigidBody2D

## Emitted when this ball is kicked by its controller.
signal kicked(ball: MarbleBall)

## Emitted when this ball collides with another body.
signal body_hit(ball: MarbleBall, other_body: Node)

## Emitted when the ball enters or exits the hole.
signal hole_state_changed(ball: MarbleBall, in_hole: bool)

## The controller Resource that drives this ball (Player, AI, etc).
@export var controller: MarbleBallController

## If true, the ball will sum damping contributions from overlapping MarbleDampingArea nodes.
@export var enable_area_damping: bool = true

## Clamp to prevent extreme damping values (optional but recommended).
@export var max_linear_damp: float = 50.0

## Clamp to prevent extreme damping values (optional but recommended).
@export var max_angular_damp: float = 50.0

## The game that owns this ball (assigned by MarbleGame).
var m_game: MarbleGame = null

## True if this ball is currently inside the hole.
var m_in_hole: bool = false

# -----------------------
# Damping contribution system (ball resolves final damping)
# -----------------------
var m_base_linear_damp: float = 0.0
var m_base_angular_damp: float = 0.0

# area_id -> {"linear": float, "angular": float}
var m_damping_contrib: Dictionary = {}


func _ready() -> void:
	# Ensure collision signals actually fire for a RigidBody2D.
	contact_monitor = true
	max_contacts_reported = 8

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if is_instance_valid(controller):
		controller.set_ball(self)

	# Capture baseline damping after any initial setup.
	m_base_linear_damp = linear_damp
	m_base_angular_damp = angular_damp
	_recompute_damping()


func set_game(game: MarbleGame) -> void:
	m_game = game
	if is_instance_valid(controller):
		controller.set_game(game)


func set_controller_active(is_active: bool) -> void:
	if is_instance_valid(controller):
		controller.set_allowed(is_active)


func notify_kicked() -> void:
	kicked.emit(self)


func set_in_hole(in_hole: bool) -> void:
	if m_in_hole == in_hole:
		return
	m_in_hole = in_hole
	hole_state_changed.emit(self, m_in_hole)


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(controller):
		controller.handle_input(event)


func _physics_process(delta: float) -> void:
	if is_instance_valid(controller):
		controller.physics_tick(delta)


func _on_body_entered(body: Node) -> void:
	body_hit.emit(self, body)


# --------------------------------------------------------------------
# Public API for damping areas (SUM combine rule)
# --------------------------------------------------------------------

## Capture current damping as the baseline. Call this if you intentionally change base damping at runtime.
func capture_base_damping() -> void:
	m_base_linear_damp = linear_damp
	m_base_angular_damp = angular_damp
	_recompute_damping()


## Add/update one damping contribution (from a MarbleDampingArea).
func add_damping_contribution(area_id: int, linear: float, angular: float) -> void:
	if not enable_area_damping:
		return
	m_damping_contrib[area_id] = {"linear": float(linear), "angular": float(angular)}
	_recompute_damping()


## Remove one damping contribution (when exiting a MarbleDampingArea).
func remove_damping_contribution(area_id: int) -> void:
	if not enable_area_damping:
		return
	if m_damping_contrib.erase(area_id):
		_recompute_damping()


## Clear all damping contributions (useful on restart/respawn).
func clear_damping_contributions() -> void:
	m_damping_contrib.clear()
	_recompute_damping()


# --------------------------------------------------------------------
# Internal
# --------------------------------------------------------------------
func _recompute_damping() -> void:
	if not enable_area_damping:
		return

	var lin := m_base_linear_damp
	var ang := m_base_angular_damp

	# SUM combine rule: final = base + Σ(contributions)
	for k in m_damping_contrib.keys():
		var d: Dictionary = m_damping_contrib[k]
		lin += float(d.get("linear", 0.0))
		ang += float(d.get("angular", 0.0))

	lin = clamp(lin, 0.0, max_linear_damp)
	ang = clamp(ang, 0.0, max_angular_damp)

	linear_damp = lin
	angular_damp = ang
