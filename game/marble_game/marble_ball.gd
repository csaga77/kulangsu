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

# --------------------------------------------------------------------
# Rolling shader integration
# --------------------------------------------------------------------

## If true, drives the marble rolling shader parameters each frame.
@export var enable_rolling_shader: bool = true

## Marble radius in pixels (used for correct no-slip rolling: roll_delta = distance / radius).
## Also drives sprite + collision sizes so visuals/physics stay in sync.
@export var marble_radius_px: float = 32.0:
	set(v):
		marble_radius_px = max(v, 0.001)
		_apply_radius_to_nodes()
		_update_rolling_shader(0.0, true)

## Clamp roll speed to avoid insane spins when velocity spikes.
@export var max_roll_radians_per_sec: float = 40.0

## If true, uses travel distance (speed*dt/radius) to drive roll angle.
## If false, uses angular_velocity to drive roll angle.
@export var roll_use_linear_velocity: bool = true

## If true, invert the rolling direction (useful if your shader mapping appears reversed).
@export var invert_roll_direction: bool = true

## Shader parameter name for roll angle (radians).
@export var shader_param_roll_angle: StringName = &"roll_angle"

## Shader parameter name for roll axis in UV plane.
@export var shader_param_roll_axis_uv: StringName = &"roll_axis_uv"

@onready var m_marble_sprite: CanvasItem = $marble_sprite
@onready var m_collision_shape: CollisionShape2D = $collision_shape

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

# -----------------------
# Rolling shader runtime state
# -----------------------
var m_roll_angle: float = 0.0
var m_last_valid_roll_axis: Vector2 = Vector2.UP


func _ready() -> void:
	# Ensure collision signals actually fire for a RigidBody2D.
	contact_monitor = true
	max_contacts_reported = 8

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if is_instance_valid(controller):
		controller.set_ball(self)

	# Apply initial radius to sprite/collision.
	_apply_radius_to_nodes()

	# Capture baseline damping after any initial setup.
	m_base_linear_damp = linear_damp
	m_base_angular_damp = angular_damp
	_recompute_damping()

	# Initialize shader params if present.
	_update_rolling_shader(0.0, true)


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

	_update_rolling_shader(delta, false)


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
# Internal: Damping
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


# --------------------------------------------------------------------
# Internal: Apply radius to visuals + collision so they stay in sync
# --------------------------------------------------------------------
func _apply_radius_to_nodes() -> void:
	if not is_node_ready():
		return

	# --- Collision shape ---
	if is_instance_valid(m_collision_shape) and is_instance_valid(m_collision_shape.shape):
		var s := m_collision_shape.shape
		if s is CircleShape2D:
			var c := s as CircleShape2D
			c.radius = marble_radius_px
		else:
			push_warning("MarbleBall: collision_shape.shape is not CircleShape2D; cannot auto-sync radius.")

	# --- Sprite alignment + size ---
	if is_instance_valid(m_marble_sprite):
		if m_marble_sprite is Sprite2D:
			var sp := m_marble_sprite as Sprite2D

			# ⭐ FORCE CENTER ALIGNMENT
			sp.centered = true
			sp.offset = Vector2.ZERO
			sp.position = Vector2.ZERO

			var tex := sp.texture
			if tex != null:
				var tex_w := float(tex.get_width())
				var tex_h := float(tex.get_height())
				var target_d := marble_radius_px * 2.0

				var sx = target_d / max(tex_w, 0.001)
				var sy = target_d / max(tex_h, 0.001)

				var smin = min(sx, sy)
				sp.scale = Vector2(smin, smin)

		elif "size" in m_marble_sprite:
			# Control-based node fallback (rare case)
			var target_d2 := marble_radius_px * 2.0
			m_marble_sprite.position = -Vector2(target_d2, target_d2) / 2.0
			m_marble_sprite.size = Vector2(target_d2, target_d2)

# --------------------------------------------------------------------
# Internal: Rolling shader driver (roll around axis in UV plane, not Z)
# Uses correct no-slip rolling: roll_delta = distance / radius
# --------------------------------------------------------------------
func _update_rolling_shader(delta: float, force: bool) -> void:
	if not enable_rolling_shader:
		return
	if not is_instance_valid(m_marble_sprite):
		return

	var mat := m_marble_sprite.material
	if mat == null:
		return
	if not (mat is ShaderMaterial):
		return

	var sm := mat as ShaderMaterial

	var v: Vector2 = linear_velocity
	var speed := v.length()

	var axis_uv := m_last_valid_roll_axis

	if speed > 0.001:
		# Rolling axis = perpendicular to travel direction in UV plane
		axis_uv = Vector2(-v.y, v.x)
		if invert_roll_direction:
			axis_uv = -axis_uv

		if axis_uv.length() > 0.001:
			axis_uv = axis_uv.normalized()
			m_last_valid_roll_axis = axis_uv

	# Advance roll angle
	if not force:
		if roll_use_linear_velocity:
			# No-slip: radians = distance / radius
			var distance := speed * delta
			var radius = max(marble_radius_px, 0.001)

			var roll_delta = distance / radius

			# Clamp by max rad/s
			var max_delta := max_roll_radians_per_sec * delta
			roll_delta = clamp(roll_delta, -max_delta, max_delta)

			m_roll_angle += roll_delta
		else:
			var roll_delta2 := angular_velocity * delta
			var max_delta2 := max_roll_radians_per_sec * delta
			roll_delta2 = clamp(roll_delta2, -max_delta2, max_delta2)

			m_roll_angle += roll_delta2

	# Push params to shader
	sm.set_shader_parameter(shader_param_roll_axis_uv, axis_uv)
	sm.set_shader_parameter(shader_param_roll_angle, m_roll_angle)
