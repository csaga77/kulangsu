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
const STEP_FLOOR_PROBE_MARGIN := 0.08
const STEP_FLOOR_SIDE_PROBE_SCALE := 0.72
const STEP_FLOOR_FORWARD_FAR_SCALE := 2.0
const STEP_FLOOR_CAST_MARGIN := 0.16
const WALL_SLIDE_INPUT_DOT_THRESHOLD := 0.05
const MIN_STEP_FLOOR_ADJUSTMENT := 0.002
const MIN_STEP_BLOCKED_PROGRESS_RATIO := 0.35
const MAX_STEP_LATERAL_DRIFT_RATIO := 0.1
const PLACEMENT_QUERY_FLOOR_CLEARANCE := 0.01
# The placement overlap test shrinks a copy of the capsule by this much so resting
# floor contact at the lifted candidate height is not mistaken for a blocking overlap
# (which would reject a valid step), while still catching genuine wall/body interpenetration.
const PLACEMENT_QUERY_SHAPE_SHRINK := 0.01
const FLOOR_SAMPLE_MISSING := -INF
const BaseController3DScript = preload("res://characters/control/base_controller_3d.gd")
# Default character model. Alternate models (female.glb, male.glb) live alongside
# it in assets/characters and can be assigned through character_model_scene.
const CharacterModelScene: PackedScene = preload("res://assets/characters/boy.glb")
const DEFAULT_CHARACTER_MODEL_HEIGHT := 0.998
# Default hair model attached to the character model's head bone. Swap it per
# instance through hair_model_scene; alternate hair GLBs live in assets/characters.
const HairModelScene: PackedScene = preload("res://assets/characters/spiky_hair.glb")
const DEFAULT_HAIR_ATTACH_BONE := "Head"
# Default pants model attached to the character model's pelvis bone. Swap it per
# instance through pants_model_scene; alternate pants GLBs live in assets/characters.
const PantsModelScene: PackedScene = preload("res://assets/characters/pants.glb")
const DEFAULT_PANTS_ATTACH_BONE := "Pelvis"
# Spatial-hash settings for transferring body skin weights onto pants vertices.
const SKIN_TRANSFER_CELL_SIZE := 0.04
const SKIN_TRANSFER_MAX_RING := 8
# Default jacket model attached to the character model's upper-spine bone. Swap it
# per instance through jacket_model_scene; alternate jacket GLBs live in assets/characters.
const JacketModelScene: PackedScene = preload("res://assets/characters/jacket.glb")
const DEFAULT_JACKET_ATTACH_BONE := "Spine02"

@export var draw_bounding_box := false:
	set(value):
		if draw_bounding_box == value:
			return
		draw_bounding_box = value
		_sync_debug_box()

# Draws the character model's skeleton as bone lines for rig debugging (e.g.
# verifying the hair attach bone). Updated every frame so it tracks animation.
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
@export_range(0.0, 1.0, 0.01) var max_step_height := 0.72
@export_range(0.0, 2.0, 0.01) var floor_snap_distance := 0.72:
	set(value):
		floor_snap_distance = maxf(value, 0.0)
		floor_snap_length = floor_snap_distance
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

@export_group("Hair Model")
# Hair lives in its own node attached to the character model's head bone, so it
# rides along with head animation and can be swapped independently of the body.
@export var use_hair_model := true:
	set(value):
		if use_hair_model == value:
			return
		use_hair_model = value
		_sync_hair_model()

@export var hair_model_scene: PackedScene = HairModelScene:
	set(value):
		if hair_model_scene == value:
			return
		hair_model_scene = value
		_rebuild_hair_model()

# Bone on the character model's Skeleton3D that the hair node tracks.
@export var hair_attach_bone := DEFAULT_HAIR_ATTACH_BONE:
	set(value):
		if hair_attach_bone == value:
			return
		hair_attach_bone = value
		_rebuild_hair_model()

@export_range(0.05, 5.0, 0.001) var hair_model_scale := 1.0:
	set(value):
		hair_model_scale = maxf(value, 0.01)
		_sync_hair_model()

# Fine placement of the hair relative to the attach bone (bone-local space).
@export var hair_model_offset := Vector3.ZERO:
	set(value):
		hair_model_offset = value
		_sync_hair_model()

@export_range(-180.0, 180.0, 1.0) var hair_model_yaw_offset := 0.0:
	set(value):
		hair_model_yaw_offset = value
		_sync_hair_model()

@export_group("Pants Model")
# Pants live in their own node attached to the character model's pelvis bone, so
# they ride along with lower-body motion and can be swapped independently of the body.
@export var use_pants_model := true:
	set(value):
		if use_pants_model == value:
			return
		use_pants_model = value
		_sync_pants_model()

@export var pants_model_scene: PackedScene = PantsModelScene:
	set(value):
		if pants_model_scene == value:
			return
		pants_model_scene = value
		_rebuild_pants_model()

# When true, the pants mesh is skinned to the character skeleton's lower-body
# bones at runtime so it deforms with the legs, instead of riding rigidly on a
# single bone. The attach-bone / offset / scale / yaw fields below are reused as
# the rest-pose alignment that seats the unskinned source mesh before weighting.
@export var pants_skinned := true:
	set(value):
		if pants_skinned == value:
			return
		pants_skinned = value
		_rebuild_pants_model()

# Bone on the character model's Skeleton3D that the pants node tracks in rigid mode
# (pants_skinned = false). Unused in skinned mode, which maps the source mesh straight
# into the body's bind space and transfers the body's own per-vertex bone weights.
@export var pants_attach_bone := DEFAULT_PANTS_ATTACH_BONE:
	set(value):
		if pants_attach_bone == value:
			return
		pants_attach_bone = value
		_rebuild_pants_model()

@export_range(0.05, 5.0, 0.001) var pants_model_scale := 1.0:
	set(value):
		pants_model_scale = maxf(value, 0.01)
		# Scale is baked into the skinned mesh, so invalidate it to force a re-bake.
		_invalidate_pants_skin()
		_sync_pants_model()

# Fine placement of the pants relative to the attach bone (bone-local space).
@export var pants_model_offset := Vector3.ZERO:
	set(value):
		pants_model_offset = value
		# Offset is baked into the skinned mesh, so invalidate it to force a re-bake.
		_invalidate_pants_skin()
		_sync_pants_model()

@export_range(-180.0, 180.0, 1.0) var pants_model_yaw_offset := 0.0:
	set(value):
		pants_model_yaw_offset = value
		# Yaw is baked into the skinned mesh, so invalidate it to force a re-bake.
		_invalidate_pants_skin()
		_sync_pants_model()

@export_group("Jacket Model")
# The jacket lives in its own node attached to the character model's upper-spine
# bone, so it rides along with torso motion and can be swapped independently of the body.
@export var use_jacket_model := true:
	set(value):
		if use_jacket_model == value:
			return
		use_jacket_model = value
		_sync_jacket_model()

@export var jacket_model_scene: PackedScene = JacketModelScene:
	set(value):
		if jacket_model_scene == value:
			return
		jacket_model_scene = value
		_rebuild_jacket_model()

# Bone on the character model's Skeleton3D that the jacket node tracks.
@export var jacket_attach_bone := DEFAULT_JACKET_ATTACH_BONE:
	set(value):
		if jacket_attach_bone == value:
			return
		jacket_attach_bone = value
		_rebuild_jacket_model()

@export_range(0.05, 5.0, 0.001) var jacket_model_scale := 1.0:
	set(value):
		jacket_model_scale = maxf(value, 0.01)
		_sync_jacket_model()

# Fine placement of the jacket relative to the attach bone (bone-local space).
@export var jacket_model_offset := Vector3.ZERO:
	set(value):
		jacket_model_offset = value
		_sync_jacket_model()

@export_range(-180.0, 180.0, 1.0) var jacket_model_yaw_offset := 0.0:
	set(value):
		jacket_model_yaw_offset = value
		_sync_jacket_model()

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
var m_last_step_direction := Vector3.ZERO
var m_step_snap_grounded := false

var m_visual_root: Node3D = null
var m_debug_box_part: MeshInstance3D = null
var m_collision_shape: CollisionShape3D = null
var m_character_model: Node3D = null
var m_model_animation_player: AnimationPlayer = null
var m_hair_model: Node3D = null
var m_hair_attachment: BoneAttachment3D = null
var m_pants_model: Node3D = null
var m_pants_attachment: BoneAttachment3D = null
var m_pants_skinned_mesh: MeshInstance3D = null
var m_jacket_model: Node3D = null
var m_jacket_attachment: BoneAttachment3D = null
var m_skeleton_debug_part: MeshInstance3D = null
var m_skeleton_debug_material: StandardMaterial3D = null


func _ready() -> void:
	floor_snap_length = floor_snap_distance
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
	var can_reacquire_floor := !m_is_currently_jumping and (grounded_before_move or velocity.y <= 0.0)
	var start_position := global_position
	var horizontal_motion := Vector3(velocity.x, 0.0, velocity.z) * get_physics_process_delta_time()
	var step_direction := Vector3.ZERO
	if horizontal_motion.length_squared() > 0.000001:
		step_direction = horizontal_motion.normalized()
		m_last_step_direction = step_direction
	elif velocity.y < -MIN_STEP_FLOOR_ADJUSTMENT and m_last_step_direction.length_squared() > 0.000001:
		step_direction = m_last_step_direction
	move_and_slide()
	var has_blocking_wall_contact := _has_blocking_wall_contact(step_direction)
	m_step_snap_grounded = is_on_floor()
	if can_reacquire_floor and step_direction.length_squared() > 0.000001:
		var preserve_slide_motion := has_blocking_wall_contact
		if _snap_to_walkable_step_floor(
			start_position,
			horizontal_motion,
			step_direction,
			!preserve_slide_motion
		):
			m_step_snap_grounded = true


func _has_blocking_wall_contact(horizontal_direction: Vector3) -> bool:
	var flat_direction := Vector3(horizontal_direction.x, 0.0, horizontal_direction.z)
	if flat_direction.length_squared() <= 0.000001:
		return false
	flat_direction = flat_direction.normalized()
	var min_floor_normal_y := cos(floor_max_angle)
	for collision_index in range(get_slide_collision_count()):
		var collision := get_slide_collision(collision_index)
		if collision == null:
			continue
		var normal := collision.get_normal()
		if normal.y >= min_floor_normal_y:
			continue
		var flat_normal := Vector3(normal.x, 0.0, normal.z)
		if flat_normal.length_squared() <= 0.000001:
			continue
		flat_normal = flat_normal.normalized()
		if flat_direction.dot(flat_normal) < -WALL_SLIDE_INPUT_DOT_THRESHOLD:
			return true
	return false


func _snap_to_walkable_step_floor(
	start_position: Vector3,
	horizontal_motion: Vector3,
	horizontal_direction: Vector3,
	allow_horizontal_reposition: bool = true
) -> bool:
	if max_step_height <= 0.0 and floor_snap_distance <= 0.0:
		return false

	horizontal_direction = Vector3(horizontal_direction.x, 0.0, horizontal_direction.z)
	if horizontal_direction.length_squared() <= 0.000001:
		return false
	horizontal_direction = horizontal_direction.normalized()

	var reference_top_y := maxf(start_position.y, global_position.y)
	var reference_bottom_y := minf(start_position.y, global_position.y)
	var snap_position := global_position
	var floor_y := _find_walkable_step_floor_y(snap_position, horizontal_direction, reference_top_y, reference_bottom_y)
	var requested_distance := horizontal_motion.length()
	var actual_motion := Vector3(
		global_position.x - start_position.x,
		0.0,
		global_position.z - start_position.z
	)
	var actual_forward_distance := actual_motion.dot(horizontal_direction)
	var actual_lateral_motion := actual_motion - (horizontal_direction * actual_forward_distance)
	var target_position_blocked := false
	var target_position := Vector3(
		start_position.x + horizontal_motion.x,
		global_position.y,
		start_position.z + horizontal_motion.z
	)
	var target_floor_y := NAN
	if allow_horizontal_reposition and requested_distance > 0.0:
		target_floor_y = _find_walkable_step_floor_y(target_position, horizontal_direction, reference_top_y, reference_bottom_y)

	if !is_nan(target_floor_y):
		var should_use_target_position := is_nan(floor_y)
		should_use_target_position = should_use_target_position or absf(target_floor_y - floor_y) > MIN_STEP_FLOOR_ADJUSTMENT
		should_use_target_position = should_use_target_position or actual_forward_distance < requested_distance * MIN_STEP_BLOCKED_PROGRESS_RATIO
		should_use_target_position = should_use_target_position or actual_lateral_motion.length() > requested_distance * MAX_STEP_LATERAL_DRIFT_RATIO
		if should_use_target_position:
			var target_floor_delta_from_start := target_floor_y - start_position.y
			if (
				target_floor_delta_from_start <= max_step_height + MIN_STEP_FLOOR_ADJUSTMENT
				and target_floor_delta_from_start >= -(floor_snap_distance + MIN_STEP_FLOOR_ADJUSTMENT)
			):
				var target_snap_position := Vector3(target_position.x, target_floor_y, target_position.z)
				if _can_place_body_at(target_snap_position):
					snap_position = target_snap_position
					floor_y = target_floor_y
				else:
					target_position_blocked = true

	if (
		allow_horizontal_reposition
		and is_nan(floor_y)
		and requested_distance > 0.0
		and actual_forward_distance < requested_distance * MIN_STEP_BLOCKED_PROGRESS_RATIO
	):
		target_floor_y = _find_walkable_step_floor_y(target_position, horizontal_direction, reference_top_y, reference_bottom_y)
		if !is_nan(target_floor_y):
			var target_snap_position := Vector3(target_position.x, target_floor_y, target_position.z)
			if _can_place_body_at(target_snap_position):
				snap_position = target_snap_position
				floor_y = target_floor_y
			else:
				target_position_blocked = true

	if target_position_blocked and actual_forward_distance < requested_distance * MIN_STEP_BLOCKED_PROGRESS_RATIO:
		return false

	if is_nan(floor_y):
		var start_floor_y := _find_walkable_step_floor_y(start_position, horizontal_direction, reference_top_y, reference_bottom_y)
		if !is_nan(start_floor_y):
			var would_drop_to_older_floor := (
				requested_distance > MIN_STEP_FLOOR_ADJUSTMENT
				and actual_forward_distance >= requested_distance * MIN_STEP_BLOCKED_PROGRESS_RATIO
				and start_floor_y < start_position.y - MIN_STEP_FLOOR_ADJUSTMENT
			)
			if !would_drop_to_older_floor:
				var start_snap_position := Vector3(start_position.x, start_floor_y, start_position.z)
				if _can_place_body_at(start_snap_position):
					global_position = start_snap_position
					velocity.x = 0.0
					velocity.z = 0.0
					velocity.y = minf(velocity.y, 0.0)
					_refresh_floor_state_after_manual_snap()
					return true
		return false

	var floor_delta_from_start := floor_y - start_position.y
	if floor_delta_from_start > max_step_height + MIN_STEP_FLOOR_ADJUSTMENT:
		return false
	if floor_delta_from_start < -(floor_snap_distance + MIN_STEP_FLOOR_ADJUSTMENT):
		return false

	var vertical_adjustment := floor_y - global_position.y
	var horizontal_adjustment := Vector3(
		snap_position.x - global_position.x,
		0.0,
		snap_position.z - global_position.z
	)
	if (
		absf(vertical_adjustment) <= MIN_STEP_FLOOR_ADJUSTMENT
		and horizontal_adjustment.length_squared() <= 0.000001
	):
		return false

	var final_snap_position := Vector3(snap_position.x, floor_y, snap_position.z)
	if !_can_place_body_at(final_snap_position):
		return false

	global_position = final_snap_position
	if vertical_adjustment > 0.0:
		velocity.y = 0.0
	else:
		velocity.y = minf(velocity.y, 0.0)
	_refresh_floor_state_after_manual_snap()
	return true


func _refresh_floor_state_after_manual_snap() -> void:
	if floor_snap_length <= 0.0 or m_is_currently_jumping:
		return
	apply_floor_snap()


# reference_top_y bounds how far up a step crest may sit (max_step_height above it);
# reference_bottom_y bounds how far down the cast reaches (floor_snap_distance below
# it). Passing the lower of start/current y as the bottom reference keeps a floor that
# the body just climbed away from -- but is still within snap range -- inside the cast
# window, so undulating terrain does not drop re-grounding after move_and_slide nudges
# the body upward.
func _find_walkable_step_floor_y(
	body_position: Vector3,
	horizontal_direction: Vector3,
	reference_top_y: float,
	reference_bottom_y: float
) -> float:
	var side_direction := Vector3(-horizontal_direction.z, 0.0, horizontal_direction.x)
	var forward_reach := body_radius + STEP_FLOOR_PROBE_MARGIN
	var side_reach := body_radius * STEP_FLOOR_SIDE_PROBE_SCALE
	var cast_top_y := reference_top_y + max_step_height + STEP_FLOOR_CAST_MARGIN
	var cast_bottom_y := reference_bottom_y - floor_snap_distance - STEP_FLOOR_CAST_MARGIN
	var min_floor_normal_y := cos(floor_max_angle)

	var center_floor_y := _sample_walkable_floor_y(
		body_position,
		cast_top_y,
		cast_bottom_y,
		min_floor_normal_y
	)
	var side_floor_y := maxf(
		_sample_walkable_floor_y(
			body_position + (side_direction * side_reach),
			cast_top_y,
			cast_bottom_y,
			min_floor_normal_y
		),
		_sample_walkable_floor_y(
			body_position - (side_direction * side_reach),
			cast_top_y,
			cast_bottom_y,
			min_floor_normal_y
		)
	)

	var body_support_y := maxf(center_floor_y, side_floor_y)
	var forward_near_floor_y := _sample_walkable_floor_y(
		body_position + (horizontal_direction * forward_reach),
		cast_top_y,
		cast_bottom_y,
		min_floor_normal_y
	)
	var forward_far_floor_y := _sample_walkable_floor_y(
		body_position + (horizontal_direction * forward_reach * STEP_FLOOR_FORWARD_FAR_SCALE),
		cast_top_y,
		cast_bottom_y,
		min_floor_normal_y
	)
	var forward_floor_y := _resolve_forward_step_floor_y(
		forward_near_floor_y,
		forward_far_floor_y,
		body_support_y
	)
	if body_support_y == FLOOR_SAMPLE_MISSING:
		# Nothing under the body's own footprint (center or either side) within step /
		# snap range: the actor is standing over a hole or a drop too deep to step down,
		# so it must fall. Do NOT reach forward to a floor across the gap -- returning the
		# forward sample here would re-plant the body at that height while it hovers over
		# the hole. A real step-up keeps the body supported (the center cast reaches up to
		# max_step_height), so this never blocks climbing.
		return NAN

	if forward_floor_y > body_support_y + MIN_STEP_FLOOR_ADJUSTMENT:
		return forward_floor_y

	if center_floor_y < body_support_y - MIN_STEP_FLOOR_ADJUSTMENT:
		if forward_floor_y < body_support_y - MIN_STEP_FLOOR_ADJUSTMENT:
			return center_floor_y
		return body_support_y

	return body_support_y


func _sample_walkable_floor_y(
	sample_position: Vector3,
	cast_top_y: float,
	cast_bottom_y: float,
	min_floor_normal_y: float
) -> float:
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(sample_position.x, cast_top_y, sample_position.z),
		Vector3(sample_position.x, cast_bottom_y, sample_position.z)
	)
	# Probe only the layers the body actually collides with, matching
	# _can_place_body_at. Casting against all layers (the ray default) would let
	# the sampler snap onto -- or be blocked by -- surfaces the capsule never
	# touches (water/area-style colliders, other characters, decorative bodies),
	# and a non-walkable first hit on an unrelated layer would mask real ground
	# just below it.
	query.collision_mask = collision_mask
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return FLOOR_SAMPLE_MISSING

	var hit_normal: Vector3 = hit.get("normal", Vector3.ZERO)
	if hit_normal.y < min_floor_normal_y:
		return FLOOR_SAMPLE_MISSING

	var hit_position: Vector3 = hit.get("position", Vector3.ZERO)
	return hit_position.y


func _resolve_forward_step_floor_y(near_floor_y: float, far_floor_y: float, body_support_y: float) -> float:
	if near_floor_y == FLOOR_SAMPLE_MISSING:
		return far_floor_y
	if far_floor_y == FLOOR_SAMPLE_MISSING:
		return near_floor_y
	if body_support_y == FLOOR_SAMPLE_MISSING:
		return maxf(near_floor_y, far_floor_y)

	if near_floor_y > body_support_y + MIN_STEP_FLOOR_ADJUSTMENT:
		return near_floor_y
	if far_floor_y < body_support_y - MIN_STEP_FLOOR_ADJUSTMENT:
		return far_floor_y
	if near_floor_y < body_support_y - MIN_STEP_FLOOR_ADJUSTMENT:
		return far_floor_y
	return maxf(near_floor_y, far_floor_y)


func _can_place_body_at(candidate_position: Vector3) -> bool:
	var candidate_transform := global_transform
	candidate_transform.origin = candidate_position
	if !is_inside_tree():
		return !test_move(candidate_transform, Vector3.ZERO)
	if !is_instance_valid(m_collision_shape):
		return !test_move(candidate_transform, Vector3.ZERO)
	if m_collision_shape.disabled or m_collision_shape.shape == null:
		return !test_move(candidate_transform, Vector3.ZERO)

	var world := get_world_3d()
	if world == null:
		return !test_move(candidate_transform, Vector3.ZERO)

	var probe_shape := _build_placement_probe_shape()
	if probe_shape == null:
		return !test_move(candidate_transform, Vector3.ZERO)

	# Lift by at least the body's collision safe margin so the floor we would rest on
	# is not counted as an overlap on coarse terrain triangles where a fixed 1 cm nudge
	# is not enough to clear the contact.
	candidate_transform.origin.y += maxf(safe_margin, PLACEMENT_QUERY_FLOOR_CLEARANCE)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = probe_shape
	query.transform = candidate_transform * m_collision_shape.transform
	query.margin = 0.0
	query.collision_mask = collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [get_rid()]

	var overlaps: Array[Dictionary] = world.direct_space_state.intersect_shape(query, 1)
	return overlaps.is_empty()


# A copy of the body capsule shrunk by the safe margin, used only for the placement
# overlap test. Shrinking keeps resting floor/wall contact from registering as a
# blocking overlap (a fixed lift alone can leave the supporting surface inside the
# shape on steep or coarse geometry) while still detecting real interpenetration.
func _build_placement_probe_shape() -> Shape3D:
	if !is_instance_valid(m_collision_shape):
		return null
	var capsule := m_collision_shape.shape as CapsuleShape3D
	if capsule == null:
		return m_collision_shape.shape
	var shrink := maxf(safe_margin, PLACEMENT_QUERY_SHAPE_SHRINK)
	var probe := CapsuleShape3D.new()
	probe.radius = maxf(capsule.radius - shrink, 0.01)
	probe.height = maxf(capsule.height - shrink * 2.0, probe.radius * 2.0)
	return probe


func jump() -> void:
	if m_is_currently_jumping:
		return
	m_is_currently_jumping = true
	m_step_snap_grounded = false
	m_jump_timer = 0.0
	_update_state()


func is_grounded() -> bool:
	return !m_is_currently_jumping and (is_on_floor() or m_step_snap_grounded)


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
	m_step_snap_grounded = is_on_floor()


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


func _apply_visual_offset() -> void:
	if !is_instance_valid(m_visual_root):
		return
	var jump_y := 0.0
	if m_is_currently_jumping:
		var t := clampf(m_jump_timer / JUMP_DURATION, 0.0, 1.0)
		var parabola := 1.0 - pow(2.0 * t - 1.0, 2.0)
		jump_y = JUMP_HEIGHT * parabola
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
	# The hair node and skeleton debug draw live under the model's skeleton, so
	# they are freed alongside it.
	m_hair_model = null
	m_hair_attachment = null
	m_pants_model = null
	m_pants_attachment = null
	m_pants_skinned_mesh = null
	m_jacket_model = null
	m_jacket_attachment = null
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
	_sync_hair_model()
	_sync_pants_model()
	_sync_jacket_model()
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


func _rebuild_hair_model() -> void:
	if is_instance_valid(m_hair_model):
		m_hair_model.queue_free()
		m_hair_model = null
	if is_inside_tree():
		_sync_hair_model()


func _sync_hair_model() -> void:
	if not use_hair_model or hair_model_scene == null:
		_hide_hair_model()
		return
	if not is_instance_valid(m_character_model):
		_hide_hair_model()
		return
	var attachment := _ensure_hair_attachment()
	if attachment == null:
		_hide_hair_model()
		return
	_ensure_hair_model(attachment)
	if not is_instance_valid(m_hair_model):
		return
	m_hair_model.visible = true
	m_hair_model.position = hair_model_offset
	m_hair_model.rotation = Vector3(0.0, deg_to_rad(hair_model_yaw_offset), 0.0)
	m_hair_model.scale = Vector3.ONE * hair_model_scale


func _hide_hair_model() -> void:
	if is_instance_valid(m_hair_model):
		m_hair_model.visible = false


func _ensure_hair_attachment() -> BoneAttachment3D:
	var skeleton := _find_skeleton(m_character_model)
	if skeleton == null:
		return null
	if skeleton.find_bone(hair_attach_bone) < 0:
		return null
	if is_instance_valid(m_hair_attachment) and m_hair_attachment.get_parent() != skeleton:
		m_hair_attachment = null
	if not is_instance_valid(m_hair_attachment):
		m_hair_attachment = skeleton.get_node_or_null("HairAttachment") as BoneAttachment3D
	if not is_instance_valid(m_hair_attachment):
		m_hair_attachment = BoneAttachment3D.new()
		m_hair_attachment.name = "HairAttachment"
		skeleton.add_child(m_hair_attachment)
		if Engine.is_editor_hint():
			m_hair_attachment.owner = null
	m_hair_attachment.bone_name = hair_attach_bone
	return m_hair_attachment


func _ensure_hair_model(parent: Node3D) -> void:
	if is_instance_valid(m_hair_model) and m_hair_model.get_parent() != parent:
		m_hair_model.queue_free()
		m_hair_model = null
	if not is_instance_valid(m_hair_model):
		m_hair_model = parent.get_node_or_null("HairModel") as Node3D
	if not is_instance_valid(m_hair_model):
		m_hair_model = Node3D.new()
		m_hair_model.name = "HairModel"
		parent.add_child(m_hair_model)
		if Engine.is_editor_hint():
			m_hair_model.owner = null
	if m_hair_model.get_child_count() == 0 and hair_model_scene != null:
		var instance := hair_model_scene.instantiate()
		m_hair_model.add_child(instance)
		if Engine.is_editor_hint():
			instance.owner = null


func _rebuild_pants_model() -> void:
	if is_instance_valid(m_pants_model):
		m_pants_model.queue_free()
		m_pants_model = null
	if is_instance_valid(m_pants_skinned_mesh):
		m_pants_skinned_mesh.free()
		m_pants_skinned_mesh = null
	if is_inside_tree():
		_sync_pants_model()


func _sync_pants_model() -> void:
	if not use_pants_model or pants_model_scene == null:
		_hide_pants_model()
		return
	if not is_instance_valid(m_character_model):
		_hide_pants_model()
		return
	if pants_skinned:
		_sync_pants_skinned()
	else:
		_sync_pants_rigid()


func _hide_pants_model() -> void:
	if is_instance_valid(m_pants_model):
		m_pants_model.visible = false
	if is_instance_valid(m_pants_skinned_mesh):
		m_pants_skinned_mesh.visible = false


func _sync_pants_rigid() -> void:
	if is_instance_valid(m_pants_skinned_mesh):
		m_pants_skinned_mesh.visible = false
	var attachment := _ensure_pants_attachment()
	if attachment == null:
		if is_instance_valid(m_pants_model):
			m_pants_model.visible = false
		return
	_ensure_pants_model(attachment)
	if not is_instance_valid(m_pants_model):
		return
	m_pants_model.visible = true
	m_pants_model.position = pants_model_offset
	m_pants_model.rotation = Vector3(0.0, deg_to_rad(pants_model_yaw_offset), 0.0)
	m_pants_model.scale = Vector3.ONE * pants_model_scale


func _sync_pants_skinned() -> void:
	if is_instance_valid(m_pants_model):
		m_pants_model.visible = false
	# The bake is expensive (per-vertex weight transfer), so reuse an already-baked
	# mesh and only rebuild when it has been invalidated. Inputs that change the bake
	# (source mesh, scale/offset/yaw) clear m_pants_skinned_mesh via
	# _invalidate_pants_skin / _rebuild_pants_model; a model swap nulls it in
	# _rebuild_character_model. Cheap syncs (visibility, body height) just re-show it.
	if is_instance_valid(m_pants_skinned_mesh):
		m_pants_skinned_mesh.visible = true
		return
	var skeleton := _find_skeleton(m_character_model)
	if skeleton == null:
		_hide_pants_model()
		return
	var stale := skeleton.get_node_or_null("PantsSkinnedMesh")
	if stale != null:
		stale.free()
	m_pants_skinned_mesh = _build_pants_skinned_mesh(skeleton)
	if is_instance_valid(m_pants_skinned_mesh):
		m_pants_skinned_mesh.visible = true


# Drops the baked skinned-pants mesh so the next sync re-bakes it. Call after
# changing any input that the bake depends on (alignment scale/offset/yaw).
func _invalidate_pants_skin() -> void:
	if is_instance_valid(m_pants_skinned_mesh):
		m_pants_skinned_mesh.free()
		m_pants_skinned_mesh = null


# Bakes the unskinned pants source mesh into the body mesh's local (bind) space and
# skins it by transferring the body mesh's own bone weights onto each pants vertex
# (nearest point on the body surface), so the pants wrap and deform exactly like the
# legs they cover. Returns a skinned MeshInstance3D parented under the skeleton.
func _build_pants_skinned_mesh(skeleton: Skeleton3D) -> MeshInstance3D:
	# Source of truth for skinning: the body's authored weights and skin binds.
	var body_mesh_instance := _find_skinned_mesh_instance(m_character_model)
	if body_mesh_instance == null:
		return null
	var body_samples := _gather_body_skin_samples(body_mesh_instance)
	var body_positions: PackedVector3Array = body_samples["positions"]
	if body_positions.is_empty():
		return null
	var body_bones: PackedInt32Array = body_samples["bones"]
	var body_weights: PackedFloat32Array = body_samples["weights"]
	var bones_per_vertex: int = body_samples["bpv"]
	var body_hash := _build_point_hash(body_positions)

	# Reuse the body's skin so transferred bone indices map to the same binds.
	var skin := _clone_body_skin(body_mesh_instance, skeleton)
	if skin == null or skin.get_bind_count() <= 0:
		return null

	# The pants source mesh is authored in the character model's space (same as the
	# body), so it maps straight in -- no bone anchor. Only yaw / scale / manual offset.
	var offset_basis := Basis(Vector3.UP, deg_to_rad(pants_model_yaw_offset)).scaled(Vector3.ONE * pants_model_scale)
	var align := Transform3D(offset_basis, pants_model_offset)

	# A skinned mesh's vertices must live in the body mesh's local (bind) space, so the
	# cloned skin's bind poses apply correctly. Map the character-model-space placement
	# into the body mesh's local space. Use local (not global) transforms so this is
	# correct even when built during _ready before global transforms have propagated.
	var model_to_body_local := _transform_relative_to(body_mesh_instance, m_character_model).affine_inverse()
	align = model_to_body_local * align

	var source := pants_model_scene.instantiate()
	var mesh_instances: Array[MeshInstance3D] = []
	_collect_mesh_instances(source, mesh_instances)
	var skinned_mesh := ArrayMesh.new()
	for mesh_instance in mesh_instances:
		var source_mesh := mesh_instance.mesh
		if source_mesh == null:
			continue
		var full := align * _relative_transform(mesh_instance, source)
		var normal_basis := full.basis
		for surface_index in range(source_mesh.get_surface_count()):
			var arrays := source_mesh.surface_get_arrays(surface_index)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			if vertices.is_empty():
				continue
			var normals_in: Variant = arrays[Mesh.ARRAY_NORMAL]
			var has_normals := normals_in is PackedVector3Array and (normals_in as PackedVector3Array).size() == vertices.size()
			var baked_vertices := PackedVector3Array()
			baked_vertices.resize(vertices.size())
			var baked_normals := PackedVector3Array()
			if has_normals:
				baked_normals.resize(vertices.size())
			var bone_indices := PackedInt32Array()
			var bone_weights := PackedFloat32Array()
			bone_indices.resize(vertices.size() * bones_per_vertex)
			bone_weights.resize(vertices.size() * bones_per_vertex)
			for vertex_index in range(vertices.size()):
				var baked := full * vertices[vertex_index]
				# Match the closest body-surface point in rest pose for weighting.
				var nearest := _nearest_point_index(baked, body_positions, body_hash)
				if has_normals:
					baked_normals[vertex_index] = (normal_basis * (normals_in as PackedVector3Array)[vertex_index]).normalized()
				baked_vertices[vertex_index] = baked
				var out_base := vertex_index * bones_per_vertex
				if nearest >= 0:
					var in_base := nearest * bones_per_vertex
					for k in range(bones_per_vertex):
						bone_indices[out_base + k] = body_bones[in_base + k]
						bone_weights[out_base + k] = body_weights[in_base + k]
				else:
					bone_indices[out_base] = 0
					bone_weights[out_base] = 1.0
			arrays[Mesh.ARRAY_VERTEX] = baked_vertices
			if has_normals:
				arrays[Mesh.ARRAY_NORMAL] = baked_normals
			arrays[Mesh.ARRAY_BONES] = bone_indices
			arrays[Mesh.ARRAY_WEIGHTS] = bone_weights
			var surface_flags := 0
			if bones_per_vertex == 8:
				surface_flags = Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
			skinned_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, surface_flags)
			var material := source_mesh.surface_get_material(surface_index)
			if material == null:
				material = mesh_instance.get_active_material(surface_index)
			if material != null:
				skinned_mesh.surface_set_material(skinned_mesh.get_surface_count() - 1, material)
	source.queue_free()

	if skinned_mesh.get_surface_count() == 0:
		return null

	var skinned_instance := MeshInstance3D.new()
	skinned_instance.name = "PantsSkinnedMesh"
	skinned_instance.mesh = skinned_mesh
	skeleton.add_child(skinned_instance)
	skinned_instance.skin = skin
	skinned_instance.skeleton = NodePath("..")
	if Engine.is_editor_hint():
		skinned_instance.owner = null
	return skinned_instance


# First MeshInstance3D under node whose mesh carries per-vertex bone weights.
func _find_skinned_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		var candidate := node as MeshInstance3D
		var mesh := candidate.mesh
		if mesh != null:
			for surface_index in range(mesh.get_surface_count()):
				if (mesh.surface_get_format(surface_index) & Mesh.ARRAY_FORMAT_BONES) != 0:
					return candidate
	for child in node.get_children():
		var found := _find_skinned_mesh_instance(child)
		if found != null:
			return found
	return null


# Collects the body mesh's vertices (in skeleton space) with their bone indices and
# weights so they can be transferred to nearby pants vertices.
func _gather_body_skin_samples(body_mesh_instance: MeshInstance3D) -> Dictionary:
	# Keep body vertices in the mesh's own local (bind) space -- the space the skin's
	# bind poses are authored for, and the space we bake the pants into for matching.
	var mesh := body_mesh_instance.mesh
	var positions := PackedVector3Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var bones_per_vertex := 4
	for surface_index in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var surface_bones: Variant = arrays[Mesh.ARRAY_BONES]
		var surface_weights: Variant = arrays[Mesh.ARRAY_WEIGHTS]
		if vertices.is_empty() or not (surface_bones is PackedInt32Array) or not (surface_weights is PackedFloat32Array):
			continue
		var typed_bones: PackedInt32Array = surface_bones
		var typed_weights: PackedFloat32Array = surface_weights
		bones_per_vertex = typed_bones.size() / vertices.size()
		positions.append_array(vertices)
		bones.append_array(typed_bones)
		weights.append_array(typed_weights)
	return {"positions": positions, "bones": bones, "weights": weights, "bpv": bones_per_vertex}


# Duplicate the body's skin (or derive one from the skeleton rest) so transferred
# bone indices resolve to identical bind poses.
func _clone_body_skin(body_mesh_instance: MeshInstance3D, skeleton: Skeleton3D) -> Skin:
	var body_skin := body_mesh_instance.skin
	if body_skin != null and body_skin.get_bind_count() > 0:
		var cloned := Skin.new()
		var bind_count := body_skin.get_bind_count()
		cloned.set_bind_count(bind_count)
		for bind_index in range(bind_count):
			cloned.set_bind_pose(bind_index, body_skin.get_bind_pose(bind_index))
			# Imported skins bind by name (skins/use_named_skins); preserve whichever
			# the source used so every bind still resolves to a bone.
			var bind_name := body_skin.get_bind_name(bind_index)
			if String(bind_name) != "":
				cloned.set_bind_name(bind_index, bind_name)
			else:
				cloned.set_bind_bone(bind_index, body_skin.get_bind_bone(bind_index))
		return cloned
	return skeleton.create_skin_from_rest_transforms()


func _build_point_hash(positions: PackedVector3Array) -> Dictionary:
	var cell_hash: Dictionary = {}
	for index in range(positions.size()):
		var key := _point_cell_key(positions[index])
		if not cell_hash.has(key):
			cell_hash[key] = PackedInt32Array()
		(cell_hash[key] as PackedInt32Array).append(index)
	return cell_hash


func _point_cell_key(point: Vector3) -> Vector3i:
	return Vector3i(
		int(floor(point.x / SKIN_TRANSFER_CELL_SIZE)),
		int(floor(point.y / SKIN_TRANSFER_CELL_SIZE)),
		int(floor(point.z / SKIN_TRANSFER_CELL_SIZE))
	)


# Nearest body point to the query, searching outward through hash cells.
func _nearest_point_index(point: Vector3, positions: PackedVector3Array, cell_hash: Dictionary) -> int:
	if positions.is_empty():
		return -1
	var base := _point_cell_key(point)
	var best := -1
	var best_distance := INF
	var radius := 0
	while radius <= SKIN_TRANSFER_MAX_RING:
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				for dz in range(-radius, radius + 1):
					# Only scan the new shell added at this radius.
					if absi(dx) != radius and absi(dy) != radius and absi(dz) != radius:
						continue
					var key := base + Vector3i(dx, dy, dz)
					if not cell_hash.has(key):
						continue
					for index in (cell_hash[key] as PackedInt32Array):
						var distance := point.distance_squared_to(positions[index])
						if distance < best_distance:
							best_distance = distance
							best = index
		# Found something and scanned one extra ring for safety: accept it.
		if best >= 0 and radius >= 2:
			return best
		radius += 1
	if best >= 0:
		return best
	# Fallback to a full scan if the hash search came up empty.
	for index in range(positions.size()):
		var distance := point.distance_squared_to(positions[index])
		if distance < best_distance:
			best_distance = distance
			best = index
	return best


func _relative_transform(node: Node3D, root: Node) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current is Node3D:
		result = (current as Node3D).transform * result
		if current == root:
			break
		current = current.get_parent()
	return result


# Transform of node expressed in ancestor's local space (node-local -> ancestor-local),
# multiplying local transforms up to but NOT including ancestor. Valid before global
# transforms have propagated.
func _transform_relative_to(node: Node3D, ancestor: Node) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current is Node3D and current != ancestor:
		result = (current as Node3D).transform * result
		current = current.get_parent()
	return result


func _ensure_pants_attachment() -> BoneAttachment3D:
	var skeleton := _find_skeleton(m_character_model)
	if skeleton == null:
		return null
	if skeleton.find_bone(pants_attach_bone) < 0:
		return null
	if is_instance_valid(m_pants_attachment) and m_pants_attachment.get_parent() != skeleton:
		m_pants_attachment = null
	if not is_instance_valid(m_pants_attachment):
		m_pants_attachment = skeleton.get_node_or_null("PantsAttachment") as BoneAttachment3D
	if not is_instance_valid(m_pants_attachment):
		m_pants_attachment = BoneAttachment3D.new()
		m_pants_attachment.name = "PantsAttachment"
		skeleton.add_child(m_pants_attachment)
		if Engine.is_editor_hint():
			m_pants_attachment.owner = null
	m_pants_attachment.bone_name = pants_attach_bone
	return m_pants_attachment


func _ensure_pants_model(parent: Node3D) -> void:
	if is_instance_valid(m_pants_model) and m_pants_model.get_parent() != parent:
		m_pants_model.queue_free()
		m_pants_model = null
	if not is_instance_valid(m_pants_model):
		m_pants_model = parent.get_node_or_null("PantsModel") as Node3D
	if not is_instance_valid(m_pants_model):
		m_pants_model = Node3D.new()
		m_pants_model.name = "PantsModel"
		parent.add_child(m_pants_model)
		if Engine.is_editor_hint():
			m_pants_model.owner = null
	if m_pants_model.get_child_count() == 0 and pants_model_scene != null:
		var instance := pants_model_scene.instantiate()
		m_pants_model.add_child(instance)
		if Engine.is_editor_hint():
			instance.owner = null


func _rebuild_jacket_model() -> void:
	if is_instance_valid(m_jacket_model):
		m_jacket_model.queue_free()
		m_jacket_model = null
	if is_inside_tree():
		_sync_jacket_model()


func _sync_jacket_model() -> void:
	if not use_jacket_model or jacket_model_scene == null:
		_hide_jacket_model()
		return
	if not is_instance_valid(m_character_model):
		_hide_jacket_model()
		return
	var attachment := _ensure_jacket_attachment()
	if attachment == null:
		_hide_jacket_model()
		return
	_ensure_jacket_model(attachment)
	if not is_instance_valid(m_jacket_model):
		return
	m_jacket_model.visible = true
	m_jacket_model.position = jacket_model_offset
	m_jacket_model.rotation = Vector3(0.0, deg_to_rad(jacket_model_yaw_offset), 0.0)
	m_jacket_model.scale = Vector3.ONE * jacket_model_scale


func _hide_jacket_model() -> void:
	if is_instance_valid(m_jacket_model):
		m_jacket_model.visible = false


func _ensure_jacket_attachment() -> BoneAttachment3D:
	var skeleton := _find_skeleton(m_character_model)
	if skeleton == null:
		return null
	if skeleton.find_bone(jacket_attach_bone) < 0:
		return null
	if is_instance_valid(m_jacket_attachment) and m_jacket_attachment.get_parent() != skeleton:
		m_jacket_attachment = null
	if not is_instance_valid(m_jacket_attachment):
		m_jacket_attachment = skeleton.get_node_or_null("JacketAttachment") as BoneAttachment3D
	if not is_instance_valid(m_jacket_attachment):
		m_jacket_attachment = BoneAttachment3D.new()
		m_jacket_attachment.name = "JacketAttachment"
		skeleton.add_child(m_jacket_attachment)
		if Engine.is_editor_hint():
			m_jacket_attachment.owner = null
	m_jacket_attachment.bone_name = jacket_attach_bone
	return m_jacket_attachment


func _ensure_jacket_model(parent: Node3D) -> void:
	if is_instance_valid(m_jacket_model) and m_jacket_model.get_parent() != parent:
		m_jacket_model.queue_free()
		m_jacket_model = null
	if not is_instance_valid(m_jacket_model):
		m_jacket_model = parent.get_node_or_null("JacketModel") as Node3D
	if not is_instance_valid(m_jacket_model):
		m_jacket_model = Node3D.new()
		m_jacket_model.name = "JacketModel"
		parent.add_child(m_jacket_model)
		if Engine.is_editor_hint():
			m_jacket_model.owner = null
	if m_jacket_model.get_child_count() == 0 and jacket_model_scene != null:
		var instance := jacket_model_scene.instantiate()
		m_jacket_model.add_child(instance)
		if Engine.is_editor_hint():
			instance.owner = null


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
