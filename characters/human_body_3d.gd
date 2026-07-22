@tool
class_name HumanBody3D
extends CharacterBody3D

signal global_position_changed()
signal configuration_changed(cfg: Dictionary)

const DEFAULT_WALK_SPEED := 4.0
const DEFAULT_RUN_SPEED := 7.5
const JUMP_DURATION := 0.55
const JUMP_HEIGHT := 0.48
# Downward acceleration applied while the body is airborne (off the floor and not
# in a cosmetic jump), so a character spawned or walked off an edge above the floor
# falls and lands instead of hovering. MAX_FALL_SPEED caps the descent.
const GRAVITY := 16.0
const MAX_FALL_SPEED := 12.0
const DEFAULT_BODY_HEIGHT := 1.72
const DEFAULT_BODY_RADIUS := 0.28
const RIGID_BODY_PUSH_INPUT_DOT_THRESHOLD := 0.05
const RIGID_BODY_PUSH_SPEED_FACTOR := 0.35
const RIGID_BODY_PUSH_MAX_EFFECTIVE_MASS := 1.0
const RIGID_BODY_PUSH_MAX_IMPULSE := 1.2
const MIN_RIGID_BODY_PUSH_SPEED_DELTA := 0.002
const BaseController3DScript = preload("res://characters/control/base_controller_3d.gd")
# Default character model. Alternate models (boy.glb, female.glb) live alongside
# it in assets/characters and can be assigned through character_model_scene.
const CharacterModelScene: PackedScene = preload("res://assets/characters/male.glb")
const DEFAULT_CHARACTER_MODEL_HEIGHT := 0.998

@export var draw_bounding_box := false:
	set(value):
		if draw_bounding_box == value:
			return
		draw_bounding_box = value
		_sync_debug_box()

# Draws the character model's skeleton as bone lines for rig debugging.
# Updated every frame so it tracks animation.
@export var draw_skeleton_bones := false:
	set(value):
		if draw_skeleton_bones == value:
			return
		draw_skeleton_bones = value
		_sync_skeleton_debug()

@export var skeleton_debug_color := Color(0.1, 1.0, 0.45, 1.0):
	set(value):
		skeleton_debug_color = value
		if is_instance_valid(m_skeleton_debug_material):
			m_skeleton_debug_material.albedo_color = value
		if draw_skeleton_bones:
			_update_skeleton_debug()

@export var direction: float = 90.0:
	set(value):
		if is_equal_approx(direction, value):
			return
		direction = value
		_update_state()

@export var is_walking := false:
	set(value):
		if is_walking == value:
			return
		is_walking = value
		_update_state()

@export var is_running := false:
	set(value):
		if is_running == value:
			return
		is_running = value
		_update_state()

@export var walk_speed := DEFAULT_WALK_SPEED
@export var run_speed := DEFAULT_RUN_SPEED

@export_range(0.8, 3.0, 0.01) var body_height := DEFAULT_BODY_HEIGHT:
	set(value):
		var clamped_height := maxf(value, 0.8)
		if is_equal_approx(body_height, clamped_height):
			return
		body_height = clamped_height
		_sync_body_profile()

@export_range(0.12, 1.0, 0.01) var body_radius := DEFAULT_BODY_RADIUS:
	set(value):
		var clamped_radius := maxf(value, 0.12)
		if is_equal_approx(body_radius, clamped_radius):
			return
		body_radius = clamped_radius
		_sync_body_profile()

@export_group("3D Navigation")
@export_range(0.0, 5.0, 0.05) var grounding_speed := 1.6

@export_group("Character Model")
@export var character_model_scene: PackedScene = CharacterModelScene:
	set(value):
		if character_model_scene == value:
			return
		character_model_scene = value
		_rebuild_character_model()

@export_range(0.1, 4.0, 0.001) var character_model_height := DEFAULT_CHARACTER_MODEL_HEIGHT:
	set(value):
		character_model_height = maxf(value, 0.1)
		_sync_character_model()

# The GLB faces along the X axis in its own space; -90° about Y turns it to the rig's +Z forward.
@export_range(-180.0, 180.0, 1.0) var character_model_yaw_offset := -90.0:
	set(value):
		character_model_yaw_offset = value
		_sync_character_model()

# Auto-plant the model's lowest point at the foot origin; this nudge lifts/lowers it further.
@export var character_model_auto_ground := true:
	set(value):
		character_model_auto_ground = value
		_sync_character_model()

@export_range(-0.5, 0.5, 0.001) var character_model_y_offset := 0.0:
	set(value):
		character_model_y_offset = value
		_sync_character_model()

@export var model_idle_animation := "idle"
@export var model_walk_animation := "walk"
@export var model_run_animation := "run"

@export var configuration: Dictionary:
	get:
		return get_configuration()
	set(value):
		set_configuration(value)

@export var controller: BaseController3DScript:
	set(value):
		if controller == value:
			return
		_teardown_controller()
		controller = value
		_setup_controller()

var m_cached_configuration: Dictionary = {}
var m_has_ready := false
var m_last_global_position := Vector3.ZERO
var m_did_move_this_frame := false
var m_is_currently_jumping := false
var m_jump_timer := 0.0

var m_visual_root: Node3D = null
var m_debug_box_part: MeshInstance3D = null
var m_collision_shape: CollisionShape3D = null
var m_character_model: Node3D = null
var m_model_animation_player: AnimationPlayer = null
var m_skeleton_debug_part: MeshInstance3D = null
var m_skeleton_debug_material: StandardMaterial3D = null


func _ready() -> void:
	_ensure_collision_shape()
	_ensure_visual_nodes()
	_update_state()
	_sync_debug_box()
	m_has_ready = true
	m_last_global_position = global_position
	_setup_controller()


func _exit_tree() -> void:
	_teardown_controller()


func get_configuration() -> Dictionary:
	return m_cached_configuration.duplicate(true)


func set_configuration(new_configuration: Dictionary) -> void:
	if m_cached_configuration == new_configuration:
		return
	m_cached_configuration = new_configuration.duplicate(true)
	configuration_changed.emit(get_configuration())


func move(direction_vector: Vector3) -> void:
	var movement_speed := run_speed if is_running else walk_speed
	move_with_speed(direction_vector, movement_speed)


func move_with_speed(direction_vector: Vector3, movement_speed: float) -> void:
	var flat_direction := Vector3(direction_vector.x, 0.0, direction_vector.z)
	if flat_direction.length_squared() > 0.000001:
		flat_direction = flat_direction.normalized()
	velocity.x = flat_direction.x * movement_speed
	velocity.z = flat_direction.z * movement_speed
	m_did_move_this_frame = true
	var grounded_before_move := is_grounded()
	if grounded_before_move and !m_is_currently_jumping:
		velocity.y = -grounding_speed
	elif !m_is_currently_jumping:
		# Airborne and not in a cosmetic jump: accumulate gravity so the body falls
		# to the floor instead of walking through the air.
		velocity.y = maxf(velocity.y - GRAVITY * get_physics_process_delta_time(), -MAX_FALL_SPEED)
	move_and_slide()
	_apply_rigid_body_pushes(flat_direction, movement_speed)


func _apply_rigid_body_pushes(horizontal_direction: Vector3, movement_speed: float) -> void:
	if movement_speed <= 0.0:
		return
	var flat_direction := Vector3(horizontal_direction.x, 0.0, horizontal_direction.z)
	if flat_direction.length_squared() <= 0.000001:
		return
	flat_direction = flat_direction.normalized()
	for collision_index in range(get_slide_collision_count()):
		var collision := get_slide_collision(collision_index)
		if collision == null:
			continue
		var rigid_body := collision.get_collider() as RigidBody3D
		if rigid_body == null or rigid_body.freeze:
			continue
		var normal := collision.get_normal()
		var flat_normal := Vector3(normal.x, 0.0, normal.z)
		if flat_normal.length_squared() <= 0.000001:
			continue
		flat_normal = flat_normal.normalized()
		var push_alignment := flat_direction.dot(-flat_normal)
		if push_alignment <= RIGID_BODY_PUSH_INPUT_DOT_THRESHOLD:
			continue
		var current_speed := rigid_body.linear_velocity.dot(flat_direction)
		var target_speed_delta := maxf(movement_speed - current_speed, 0.0)
		if target_speed_delta <= MIN_RIGID_BODY_PUSH_SPEED_DELTA:
			continue
		var effective_mass := minf(maxf(rigid_body.mass, 0.01), RIGID_BODY_PUSH_MAX_EFFECTIVE_MASS)
		var impulse_strength := minf(
			effective_mass * target_speed_delta * RIGID_BODY_PUSH_SPEED_FACTOR * push_alignment,
			RIGID_BODY_PUSH_MAX_IMPULSE
		)
		rigid_body.apply_central_impulse(flat_direction * impulse_strength)


func jump() -> void:
	if m_is_currently_jumping:
		return
	# Grounded movement keeps a small downward velocity so the capsule stays planted.
	# Clear it at takeoff so the stable capsule does not pull the visual jump downward.
	if is_grounded():
		velocity.y = 0.0
	m_is_currently_jumping = true
	m_jump_timer = 0.0
	_update_state()


func is_grounded() -> bool:
	return !m_is_currently_jumping and is_on_floor()


func get_direction_vector() -> Vector3:
	var radians := deg_to_rad(direction)
	return Vector3(cos(radians), 0.0, sin(radians)).normalized()


func set_direction_vector(vector: Vector3) -> void:
	var flat_vector := Vector3(vector.x, 0.0, vector.z)
	if flat_vector.length_squared() <= 0.000001:
		return
	direction = rad_to_deg(atan2(flat_vector.z, flat_vector.x))


func get_flat_position() -> Vector2:
	return Vector2(global_position.x, global_position.z)


func set_flat_position(flat_position: Vector2) -> void:
	global_position.x = flat_position.x
	global_position.z = flat_position.y


func get_local_bounding_box() -> AABB:
	return AABB(
		Vector3(-body_radius, 0.0, -body_radius),
		Vector3(body_radius * 2.0, body_height, body_radius * 2.0)
	)


func get_bounding_box() -> AABB:
	var local_box := get_local_bounding_box()
	local_box.position += global_position
	return local_box


func get_local_ground_rect() -> Rect2:
	return Rect2(
		Vector2(-body_radius, -body_radius),
		Vector2(body_radius * 2.0, body_radius * 2.0)
	)


func get_ground_rect() -> Rect2:
	var rect := get_local_ground_rect()
	rect.position += get_flat_position()
	return rect


func get_current_animation_name() -> String:
	if is_instance_valid(m_model_animation_player):
		return m_model_animation_player.current_animation
	return ""


func _process(delta: float) -> void:
	_process_jump(delta)
	if draw_skeleton_bones:
		_update_skeleton_debug()
	if !m_last_global_position.is_equal_approx(global_position):
		m_last_global_position = global_position
		global_position_changed.emit()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	m_did_move_this_frame = false
	_process_controller(delta)
	# When a controlled body was not actively moved this frame (idle, or a controller
	# that issued no move), keep advancing its vertical physics so gravity settles it
	# onto the floor instead of leaving it hovering. Skipped when there is no
	# controller (e.g. manually driven test probes) so we never double-step physics.
	if controller != null and not m_did_move_this_frame:
		_apply_passive_vertical_motion(delta)


# Vertical-only physics step for an idle controlled body: hold horizontal velocity
# at zero and either keep the gentle grounding press while on the floor or apply
# gravity while airborne, so the character drops onto and rests on the floor
# beneath it without any horizontal input.
func _apply_passive_vertical_motion(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	var grounded_before_move := is_grounded()
	if grounded_before_move and !m_is_currently_jumping:
		velocity.y = -grounding_speed
	elif !m_is_currently_jumping:
		velocity.y = maxf(velocity.y - GRAVITY * delta, -MAX_FALL_SPEED)
	move_and_slide()


func _setup_controller() -> void:
	if !is_inside_tree():
		return
	if controller == null:
		return
	controller.setup(self)


func _teardown_controller() -> void:
	if controller == null:
		return
	controller.teardown()


func _process_controller(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if controller == null:
		return
	controller.process(delta)


func _process_jump(delta: float) -> void:
	if !m_is_currently_jumping:
		return

	m_jump_timer += delta
	if m_jump_timer >= JUMP_DURATION:
		m_jump_timer = 0.0
		m_is_currently_jumping = false
		_update_state()
		return

	_apply_visual_offset()


func _update_state() -> void:
	_sync_visual_rotation()
	_apply_visual_offset()
	_sync_model_animation()


func _get_jump_offset_y() -> float:
	if !m_is_currently_jumping:
		return 0.0
	var t := clampf(m_jump_timer / JUMP_DURATION, 0.0, 1.0)
	var parabola := 1.0 - pow(2.0 * t - 1.0, 2.0)
	return JUMP_HEIGHT * parabola


func _apply_visual_offset() -> void:
	var jump_y := _get_jump_offset_y()
	if is_instance_valid(m_visual_root):
		m_visual_root.position = Vector3(0.0, jump_y, 0.0)


func _sync_visual_rotation() -> void:
	if !is_instance_valid(m_visual_root):
		return
	m_visual_root.rotation.y = (PI * 0.5) - deg_to_rad(direction)


func _ensure_collision_shape() -> void:
	m_collision_shape = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if m_collision_shape == null:
		m_collision_shape = CollisionShape3D.new()
		m_collision_shape.name = "CollisionShape3D"
		add_child(m_collision_shape)
		if Engine.is_editor_hint():
			m_collision_shape.owner = null

	var capsule := m_collision_shape.shape as CapsuleShape3D
	if capsule == null:
		capsule = CapsuleShape3D.new()
		m_collision_shape.shape = capsule
	_sync_collision_shape()


func _ensure_visual_nodes() -> void:
	m_visual_root = get_node_or_null("VisualRoot") as Node3D
	if m_visual_root == null:
		m_visual_root = Node3D.new()
		m_visual_root.name = "VisualRoot"
		add_child(m_visual_root)
		if Engine.is_editor_hint():
			m_visual_root.owner = null

	m_debug_box_part = _ensure_debug_box_part()
	_sync_body_profile()


func _ensure_debug_box_part() -> MeshInstance3D:
	var parent := m_visual_root if is_instance_valid(m_visual_root) else self
	var part := parent.get_node_or_null("DebugBox") as MeshInstance3D
	if part == null:
		part = MeshInstance3D.new()
		part.name = "DebugBox"
		part.mesh = BoxMesh.new()
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(part)
		if Engine.is_editor_hint():
			part.owner = null
	return part


func _ensure_character_model() -> Node3D:
	var parent := m_visual_root if is_instance_valid(m_visual_root) else self
	var model := parent.get_node_or_null("CharacterModel") as Node3D
	if model == null:
		model = Node3D.new()
		model.name = "CharacterModel"
		parent.add_child(model)
		if Engine.is_editor_hint():
			model.owner = null
	if model.get_child_count() == 0 and character_model_scene != null:
		var instance := character_model_scene.instantiate()
		model.add_child(instance)
		if Engine.is_editor_hint():
			instance.owner = null
	return model


func _rebuild_character_model() -> void:
	if is_instance_valid(m_character_model):
		m_character_model.queue_free()
		m_character_model = null
	# The skeleton debug draw lives under the model's skeleton and is freed with it.
	m_skeleton_debug_part = null
	if is_inside_tree():
		_sync_character_model()


func _sync_character_model() -> void:
	if not is_instance_valid(m_character_model):
		if not is_instance_valid(m_visual_root):
			return
		m_character_model = _ensure_character_model()
	if not is_instance_valid(m_character_model):
		return
	m_character_model.visible = true
	var scale_factor := body_height / maxf(character_model_height, 0.01)
	m_character_model.scale = Vector3.ONE * scale_factor
	m_character_model.rotation.y = deg_to_rad(character_model_yaw_offset)
	m_character_model.position = Vector3.ZERO
	_align_model_feet()
	if not is_instance_valid(m_model_animation_player):
		m_model_animation_player = _find_animation_player(m_character_model)
	_sync_model_animation()
	_sync_skeleton_debug()


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null


func _sync_skeleton_debug() -> void:
	var skeleton: Skeleton3D = null
	if is_instance_valid(m_character_model):
		skeleton = _find_skeleton(m_character_model)
	if skeleton == null or not draw_skeleton_bones:
		if is_instance_valid(m_skeleton_debug_part):
			m_skeleton_debug_part.visible = false
		return
	if not is_instance_valid(m_skeleton_debug_part) or m_skeleton_debug_part.get_parent() != skeleton:
		m_skeleton_debug_part = _ensure_skeleton_debug_part(skeleton)
	m_skeleton_debug_part.visible = true
	_update_skeleton_debug()


func _ensure_skeleton_debug_part(skeleton: Skeleton3D) -> MeshInstance3D:
	var part := skeleton.get_node_or_null("SkeletonDebug") as MeshInstance3D
	if part == null:
		part = MeshInstance3D.new()
		part.name = "SkeletonDebug"
		part.mesh = ImmediateMesh.new()
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		skeleton.add_child(part)
		if Engine.is_editor_hint():
			part.owner = null
	if m_skeleton_debug_material == null:
		m_skeleton_debug_material = StandardMaterial3D.new()
		m_skeleton_debug_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m_skeleton_debug_material.vertex_color_use_as_albedo = true
		m_skeleton_debug_material.no_depth_test = true
		m_skeleton_debug_material.albedo_color = skeleton_debug_color
	part.material_override = m_skeleton_debug_material
	return part


func _update_skeleton_debug() -> void:
	if not is_instance_valid(m_skeleton_debug_part):
		return
	var mesh := m_skeleton_debug_part.mesh as ImmediateMesh
	if mesh == null:
		return
	var skeleton := m_skeleton_debug_part.get_parent() as Skeleton3D
	if skeleton == null:
		return
	mesh.clear_surfaces()
	var bone_count := skeleton.get_bone_count()
	if bone_count <= 0:
		return
	# Bone poses are in skeleton-local space; the debug mesh is a child of the
	# skeleton with an identity transform, so they map directly to mesh vertices.
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for bone_index in range(bone_count):
		var parent_index := skeleton.get_bone_parent(bone_index)
		if parent_index < 0:
			continue
		var parent_origin := skeleton.get_bone_global_pose(parent_index).origin
		var child_origin := skeleton.get_bone_global_pose(bone_index).origin
		mesh.surface_set_color(skeleton_debug_color)
		mesh.surface_add_vertex(parent_origin)
		mesh.surface_set_color(skeleton_debug_color)
		mesh.surface_add_vertex(child_origin)
	mesh.surface_end()


func _collect_mesh_instances(node: Node, into: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		into.append(node)
	for child in node.get_children():
		_collect_mesh_instances(child, into)


# Plant the model so its lowest rendered point sits at the foot origin (+ manual nudge).
func _align_model_feet() -> void:
	if not is_instance_valid(m_character_model):
		return
	if not character_model_auto_ground:
		m_character_model.position.y = character_model_y_offset
		return
	if not is_inside_tree() or not is_instance_valid(m_visual_root):
		return
	var meshes: Array[MeshInstance3D] = []
	_collect_mesh_instances(m_character_model, meshes)
	if meshes.is_empty():
		m_character_model.position.y = character_model_y_offset
		return
	var inv_root := m_visual_root.global_transform.affine_inverse()
	var lowest := INF
	for mesh_instance in meshes:
		var to_root := inv_root * mesh_instance.global_transform
		# Measure the true lowest rendered vertex rather than MeshInstance3D.get_aabb().
		# Imported skinned meshes carry an AABB padded below the feet (headroom for
		# animation/culling); aligning that padded floor to the foot origin would seat
		# the bones above the ground and leave the character visibly hovering. The rest-
		# pose vertices give the real sole position, so the feet land on the floor.
		var mesh := mesh_instance.mesh
		var measured := false
		if mesh != null:
			for surface_index in range(mesh.get_surface_count()):
				var arrays := mesh.surface_get_arrays(surface_index)
				if arrays.size() <= Mesh.ARRAY_VERTEX:
					continue
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				for vertex in vertices:
					lowest = minf(lowest, (to_root * vertex).y)
					measured = true
		if not measured:
			# Fall back to the (possibly padded) AABB when vertex data is unavailable.
			var aabb := mesh_instance.get_aabb()
			for i in range(8):
				var corner := aabb.position + Vector3(
					aabb.size.x * float(i & 1),
					aabb.size.y * float((i >> 1) & 1),
					aabb.size.z * float((i >> 2) & 1))
				lowest = minf(lowest, (to_root * corner).y)
	if lowest == INF:
		lowest = 0.0
	m_character_model.position.y = character_model_y_offset - lowest


func _sync_model_animation() -> void:
	if not is_instance_valid(m_model_animation_player):
		return
	var target := _match_model_animation(_desired_model_animation())
	if target.is_empty():
		return
	var animation := m_model_animation_player.get_animation(target)
	if animation != null and animation.loop_mode == Animation.LOOP_NONE:
		animation.loop_mode = Animation.LOOP_LINEAR
	if m_model_animation_player.current_animation != target:
		m_model_animation_player.play(target, 0.15)


func _desired_model_animation() -> String:
	if is_walking and is_running:
		return model_run_animation
	if is_walking:
		return model_walk_animation
	return model_idle_animation


func _match_model_animation(animation_name: String) -> String:
	if animation_name.is_empty() or not is_instance_valid(m_model_animation_player):
		return ""
	if m_model_animation_player.has_animation(animation_name):
		return animation_name
	var lowered := animation_name.to_lower()
	for entry in m_model_animation_player.get_animation_list():
		var candidate := String(entry)
		var candidate_lower := candidate.to_lower()
		if candidate_lower == lowered or candidate_lower.ends_with("/" + lowered):
			return candidate
	return ""


func _sync_body_profile() -> void:
	_sync_collision_shape()
	_sync_debug_box()
	_sync_character_model()


func _sync_collision_shape() -> void:
	if !is_instance_valid(m_collision_shape):
		return
	var capsule := m_collision_shape.shape as CapsuleShape3D
	if capsule == null:
		return
	capsule.radius = body_radius
	capsule.height = body_height
	m_collision_shape.position = Vector3(0.0, body_height * 0.5, 0.0)


func _sync_debug_box() -> void:
	if !is_instance_valid(m_debug_box_part):
		return
	m_debug_box_part.visible = draw_bounding_box
	var debug_color := Color(0.2, 0.75, 1.0, 0.18)
	var box_mesh := m_debug_box_part.mesh as BoxMesh
	if box_mesh != null:
		box_mesh.size = Vector3(body_radius * 2.0, body_height, body_radius * 2.0)
	m_debug_box_part.position = Vector3(0.0, body_height * 0.5, 0.0)
	_apply_material(m_debug_box_part, debug_color, true)


func _apply_material(part: MeshInstance3D, color: Color, transparent: bool = false) -> void:
	if !is_instance_valid(part):
		return

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	if transparent or color.a < 0.99:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	part.material_override = material
