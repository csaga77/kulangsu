# MarbleBall.gd
class_name MarbleBall
extends RigidBody2D

signal kicked(ball: MarbleBall)
signal body_hit(ball: MarbleBall, other_body: Node)
signal hole_state_changed(ball: MarbleBall, in_hole: bool)

@export var controller: MarbleBallController

@export var marble_texture: Texture2D:
	set(v):
		marble_texture = v
		_apply_texture_to_sprite()
		_apply_radius_to_nodes()
		_update_rolling_shader(0.0, true)

@export var enable_area_damping: bool = true
@export var max_linear_damp: float = 50.0
@export var max_angular_damp: float = 50.0

@export var enable_rolling_shader: bool = true

@export var marble_radius_px: float = 32.0:
	set(v):
		marble_radius_px = max(v, 0.001)
		_apply_radius_to_nodes()
		_update_rolling_shader(0.0, true)

@export var max_roll_radians_per_sec: float = 40.0
@export var roll_use_linear_velocity: bool = true
@export var invert_roll_direction: bool = true

@export var shader_param_roll_angle: StringName = &"roll_angle"
@export var shader_param_roll_axis_uv: StringName = &"roll_axis_uv"

@export var shader_param_roll_rot: StringName = &"roll_rot"

@onready var m_marble_sprite: CanvasItem = $marble_sprite
@onready var m_collision_shape: CollisionShape2D = $collision_shape

var m_game: MarbleGame = null
var m_in_hole: bool = false

var m_base_linear_damp: float = 0.0
var m_base_angular_damp: float = 0.0
var m_damping_contrib: Dictionary = {}

var m_last_valid_roll_axis: Vector2 = Vector2.UP
var m_roll_q: Quaternion = Quaternion()

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 8

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if is_instance_valid(controller):
		controller.set_ball(self)

	_apply_texture_to_sprite()
	_apply_radius_to_nodes()

	m_base_linear_damp = linear_damp
	m_base_angular_damp = angular_damp
	_recompute_damping()

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

func capture_base_damping() -> void:
	m_base_linear_damp = linear_damp
	m_base_angular_damp = angular_damp
	_recompute_damping()

func add_damping_contribution(area_id: int, linear: float, angular: float) -> void:
	if not enable_area_damping:
		return
	m_damping_contrib[area_id] = {"linear": float(linear), "angular": float(angular)}
	_recompute_damping()

func remove_damping_contribution(area_id: int) -> void:
	if not enable_area_damping:
		return
	if m_damping_contrib.erase(area_id):
		_recompute_damping()

func clear_damping_contributions() -> void:
	m_damping_contrib.clear()
	_recompute_damping()

func _recompute_damping() -> void:
	if not enable_area_damping:
		return

	var lin := m_base_linear_damp
	var ang := m_base_angular_damp

	for k in m_damping_contrib.keys():
		var d: Dictionary = m_damping_contrib[k]
		lin += float(d.get("linear", 0.0))
		ang += float(d.get("angular", 0.0))

	lin = clamp(lin, 0.0, max_linear_damp)
	ang = clamp(ang, 0.0, max_angular_damp)

	linear_damp = lin
	angular_damp = ang

func _apply_texture_to_sprite() -> void:
	if not is_node_ready():
		return
	if not is_instance_valid(m_marble_sprite):
		return

	if m_marble_sprite is Sprite2D:
		var sp2 := m_marble_sprite as Sprite2D
		if marble_texture != null:
			sp2.texture = marble_texture

	elif m_marble_sprite is TextureRect:
		var tr := m_marble_sprite as TextureRect
		if marble_texture != null:
			tr.texture = marble_texture

func _apply_radius_to_nodes() -> void:
	if not is_node_ready():
		return

	if is_instance_valid(m_collision_shape) and is_instance_valid(m_collision_shape.shape):
		var s := m_collision_shape.shape
		if s is CircleShape2D:
			(s as CircleShape2D).radius = marble_radius_px
		else:
			push_warning("MarbleBall: collision_shape.shape is not CircleShape2D; cannot auto-sync radius.")

	if is_instance_valid(m_marble_sprite):
		if m_marble_sprite is Sprite2D:
			var sp := m_marble_sprite as Sprite2D
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
			var target_d2 := marble_radius_px * 2.0
			m_marble_sprite.position = -Vector2(target_d2, target_d2) / 2.0
			m_marble_sprite.size = Vector2(target_d2, target_d2)

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
		axis_uv = Vector2(-v.y, v.x)
		if invert_roll_direction:
			axis_uv = -axis_uv

		if axis_uv.length() > 0.001:
			axis_uv = axis_uv.normalized()
			m_last_valid_roll_axis = axis_uv

	if not force:
		var roll_delta := 0.0

		if roll_use_linear_velocity:
			var distance := speed * delta
			var radius = max(marble_radius_px, 0.001)
			roll_delta = distance / radius
		else:
			roll_delta = angular_velocity * delta

		var max_delta := max_roll_radians_per_sec * delta
		roll_delta = clamp(roll_delta, -max_delta, max_delta)

		if absf(roll_delta) > 0.000001:
			var axis3 := Vector3(axis_uv.x, axis_uv.y, 0.0)
			if axis3.length() < 0.000001:
				axis3 = Vector3(0.0, 1.0, 0.0)
			else:
				axis3 = axis3.normalized()

			var dq := Quaternion(axis3, roll_delta)
			m_roll_q = (dq * m_roll_q).normalized()

	var basis := Basis(m_roll_q)
	sm.set_shader_parameter(shader_param_roll_rot, basis)

	sm.set_shader_parameter(shader_param_roll_axis_uv, axis_uv)
	sm.set_shader_parameter(shader_param_roll_angle, 0.0)
