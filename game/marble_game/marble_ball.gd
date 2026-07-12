# MarbleBall.gd
class_name MarbleBall
extends RigidBody3D

signal kicked(ball: MarbleBall)
signal body_hit(ball: MarbleBall, other_body: Node)
signal hole_state_changed(ball: MarbleBall, in_hole: bool)

@export var controller: MarbleBallController

@export var marble_radius: float = 0.25:
	set(value):
		marble_radius = maxf(value, 0.01)
		_apply_radius_to_nodes()

@export var marble_color: Color = Color("#75b9ee"):
	set(value):
		marble_color = value
		_apply_color_to_mesh()

@export var enable_area_damping: bool = true
@export var max_linear_damp: float = 12.0
@export var max_angular_damp: float = 12.0

@export var hit_min_speed: float = 0.2
@export var hit_max_speed: float = 5.0
@export var hit_cooldown_sec: float = 0.06
@export var hit_volume_db_slow: float = -30.0
@export var hit_volume_db_fast: float = -6.0
@export var hit_pitch_slow: float = 0.95
@export var hit_pitch_fast: float = 1.05

@onready var m_marble_mesh: MeshInstance3D = $marble_mesh
@onready var m_collision_shape: CollisionShape3D = $collision_shape
@onready var m_hit_sfx: AudioStreamPlayer3D = $hit_sfx

var m_hit_cooldown: float = 0.0
var m_game: MarbleGame = null
var m_in_hole: bool = false
var m_base_linear_damp: float = 0.0
var m_base_angular_damp: float = 0.0
var m_damping_contrib: Dictionary = {}


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 8

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if is_instance_valid(controller):
		controller.set_ball(self)

	_apply_radius_to_nodes()
	_apply_color_to_mesh()
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
	if m_hit_cooldown > 0.0:
		m_hit_cooldown = maxf(0.0, m_hit_cooldown - delta)


func _on_body_entered(body: Node) -> void:
	body_hit.emit(self, body)
	_play_hit_sfx(body)


func _play_hit_sfx(body: Node) -> void:
	if m_hit_sfx == null or m_hit_cooldown > 0.0 or not (body is MarbleBall):
		return

	var other := body as MarbleBall
	if other == null or not is_instance_valid(other):
		return

	var relative_speed: float = (linear_velocity - other.linear_velocity).length()
	if relative_speed < hit_min_speed:
		return

	var amount: float = clampf(inverse_lerp(hit_min_speed, hit_max_speed, relative_speed), 0.0, 1.0)
	var cubic_amount: float = amount * amount * amount
	m_hit_sfx.volume_db = lerpf(hit_volume_db_slow, hit_volume_db_fast, cubic_amount)
	m_hit_sfx.pitch_scale = lerpf(hit_pitch_slow, hit_pitch_fast, cubic_amount) * randf_range(0.98, 1.02)
	m_hit_sfx.play()
	m_hit_cooldown = hit_cooldown_sec


func capture_base_damping() -> void:
	m_base_linear_damp = linear_damp
	m_base_angular_damp = angular_damp
	_recompute_damping()


func add_damping_contribution(area_id: int, linear: float, angular: float) -> void:
	if not enable_area_damping:
		return
	m_damping_contrib[area_id] = {"linear": linear, "angular": angular}
	_recompute_damping()


func remove_damping_contribution(area_id: int) -> void:
	if enable_area_damping and m_damping_contrib.erase(area_id):
		_recompute_damping()


func clear_damping_contributions() -> void:
	m_damping_contrib.clear()
	_recompute_damping()


func _recompute_damping() -> void:
	if not enable_area_damping:
		return

	var combined_linear: float = m_base_linear_damp
	var combined_angular: float = m_base_angular_damp
	for key: Variant in m_damping_contrib.keys():
		var contribution: Dictionary = m_damping_contrib[key]
		combined_linear += float(contribution.get("linear", 0.0))
		combined_angular += float(contribution.get("angular", 0.0))

	linear_damp = clampf(combined_linear, 0.0, max_linear_damp)
	angular_damp = clampf(combined_angular, 0.0, max_angular_damp)


func _apply_radius_to_nodes() -> void:
	if not is_node_ready():
		return

	if is_instance_valid(m_collision_shape) and m_collision_shape.shape is SphereShape3D:
		(m_collision_shape.shape as SphereShape3D).radius = marble_radius
	if is_instance_valid(m_marble_mesh) and m_marble_mesh.mesh is SphereMesh:
		var sphere := m_marble_mesh.mesh as SphereMesh
		sphere.radius = marble_radius
		sphere.height = marble_radius * 2.0


func _apply_color_to_mesh() -> void:
	if not is_node_ready() or not is_instance_valid(m_marble_mesh):
		return

	var material := m_marble_mesh.material_override as StandardMaterial3D
	if material == null:
		material = StandardMaterial3D.new()
		material.roughness = 0.34
		m_marble_mesh.material_override = material
	elif not material.resource_local_to_scene:
		material = material.duplicate() as StandardMaterial3D
		m_marble_mesh.material_override = material
	material.albedo_color = marble_color
