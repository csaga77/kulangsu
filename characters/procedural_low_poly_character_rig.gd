@tool
class_name ProceduralLowPolyCharacterRig
extends Node3D

const DEFAULT_SEED := "kulangsu_player"
const BODY_SURFACE_NAME := "BodySurface"
const HEAD_ATTACHMENT_NAME := "HeadAttachment"
const LEFT_HAND_ATTACHMENT_NAME := "LeftHandAttachment"
const RIGHT_HAND_ATTACHMENT_NAME := "RightHandAttachment"

const BONE_HIPS := "Hips"
const BONE_SPINE := "Spine"
const BONE_HEAD := "Head"
const BONE_LEFT_UPPER_ARM := "LeftUpperArm"
const BONE_LEFT_FOREARM := "LeftForearm"
const BONE_LEFT_HAND := "LeftHand"
const BONE_RIGHT_UPPER_ARM := "RightUpperArm"
const BONE_RIGHT_FOREARM := "RightForearm"
const BONE_RIGHT_HAND := "RightHand"
const BONE_LEFT_UPPER_LEG := "LeftUpperLeg"
const BONE_LEFT_LOWER_LEG := "LeftLowerLeg"
const BONE_LEFT_FOOT := "LeftFoot"
const BONE_RIGHT_UPPER_LEG := "RightUpperLeg"
const BONE_RIGHT_LOWER_LEG := "RightLowerLeg"
const BONE_RIGHT_FOOT := "RightFoot"

const BONE_NAMES := [
	BONE_HIPS,
	BONE_SPINE,
	BONE_HEAD,
	BONE_LEFT_UPPER_ARM,
	BONE_LEFT_FOREARM,
	BONE_LEFT_HAND,
	BONE_RIGHT_UPPER_ARM,
	BONE_RIGHT_FOREARM,
	BONE_RIGHT_HAND,
	BONE_LEFT_UPPER_LEG,
	BONE_LEFT_LOWER_LEG,
	BONE_LEFT_FOOT,
	BONE_RIGHT_UPPER_LEG,
	BONE_RIGHT_LOWER_LEG,
	BONE_RIGHT_FOOT,
]

@export var seed_text := DEFAULT_SEED:
	set(value):
		var normalized_value := value
		if normalized_value.is_empty():
			normalized_value = DEFAULT_SEED
		if seed_text == normalized_value:
			return
		seed_text = normalized_value
		rebuild()

var m_config: LowPolyCharacterConfig = LowPolyCharacterConfig.from_seed(DEFAULT_SEED)
var m_body_height := 1.72
var m_body_radius := 0.28
var m_motion_time := 0.0
var m_locomotion_blend := 0.0
var m_left_leg_pitch := 0.0
var m_right_leg_pitch := 0.0
var m_left_arm_pitch := 0.0
var m_right_arm_pitch := 0.0

var m_skeleton: Skeleton3D = null
var m_body_surface: MeshInstance3D = null
var m_head_attachment: BoneAttachment3D = null
var m_left_hand_attachment: BoneAttachment3D = null
var m_right_hand_attachment: BoneAttachment3D = null
var m_material: StandardMaterial3D = null


func _ready() -> void:
	rebuild()


func configure_from_seed(seed_value: Variant, body_height_value: float, body_radius_value: float) -> void:
	var normalized_seed := str(seed_value)
	if normalized_seed.is_empty():
		normalized_seed = DEFAULT_SEED
	seed_text = normalized_seed
	m_config = LowPolyCharacterConfig.from_seed(normalized_seed)
	m_body_height = maxf(body_height_value, 0.8)
	m_body_radius = maxf(body_radius_value, 0.12)
	rebuild()


func get_config_snapshot() -> Dictionary:
	return m_config.to_dictionary()


func get_motion_snapshot() -> Dictionary:
	return {
		"locomotion_blend": snappedf(m_locomotion_blend, 0.0001),
		"left_leg_pitch": snappedf(m_left_leg_pitch, 0.0001),
		"right_leg_pitch": snappedf(m_right_leg_pitch, 0.0001),
		"left_arm_pitch": snappedf(m_left_arm_pitch, 0.0001),
		"right_arm_pitch": snappedf(m_right_arm_pitch, 0.0001),
	}


func rebuild() -> void:
	if !is_inside_tree():
		return
	_ensure_nodes()
	_rebuild_skeleton()
	_rebuild_body_mesh()
	_reset_pose()


func process_motion(delta: float, is_walking: bool, is_running: bool, is_jumping: bool) -> void:
	if !is_instance_valid(m_skeleton):
		return

	var target_blend := 0.0
	if is_walking:
		target_blend = 1.0
	if is_running:
		target_blend = 1.65
	m_locomotion_blend = lerpf(m_locomotion_blend, target_blend, clampf(delta * 9.0, 0.0, 1.0))

	var cadence := lerpf(2.2, 5.4, clampf(m_locomotion_blend / 1.65, 0.0, 1.0))
	m_motion_time = fposmod(m_motion_time + delta * TAU * cadence, TAU)
	var stride := sin(m_motion_time)
	var counter_stride := sin(m_motion_time + PI)
	var lift := (sin((m_motion_time * 2.0) - (PI * 0.5)) + 1.0) * 0.5
	var run_factor := clampf(m_locomotion_blend - 1.0, 0.0, 1.0)
	var swing_limit := deg_to_rad(18.0 + 16.0 * run_factor) * m_locomotion_blend

	m_left_leg_pitch = stride * swing_limit
	m_right_leg_pitch = counter_stride * swing_limit
	m_left_arm_pitch = counter_stride * swing_limit * 0.72
	m_right_arm_pitch = stride * swing_limit * 0.72

	var breathing := sin(Time.get_ticks_msec() * 0.0016) * deg_to_rad(1.4)
	var forward_lean := deg_to_rad(7.0) * run_factor
	var hip_bob := -lift * 0.045 * m_locomotion_blend
	if is_jumping:
		hip_bob += 0.04

	_set_bone_pose(BONE_HIPS, Vector3(0.0, hip_bob, 0.0), Quaternion.IDENTITY)
	_set_bone_pose(BONE_SPINE, Vector3.ZERO, Quaternion(Vector3.RIGHT, breathing - forward_lean))
	_set_bone_pose(BONE_LEFT_UPPER_LEG, Vector3.ZERO, Quaternion(Vector3.RIGHT, m_left_leg_pitch))
	_set_bone_pose(BONE_RIGHT_UPPER_LEG, Vector3.ZERO, Quaternion(Vector3.RIGHT, m_right_leg_pitch))
	_set_bone_pose(BONE_LEFT_LOWER_LEG, Vector3.ZERO, Quaternion(Vector3.RIGHT, maxf(0.0, -m_left_leg_pitch) * 0.62))
	_set_bone_pose(BONE_RIGHT_LOWER_LEG, Vector3.ZERO, Quaternion(Vector3.RIGHT, maxf(0.0, -m_right_leg_pitch) * 0.62))
	_set_bone_pose(BONE_LEFT_UPPER_ARM, Vector3.ZERO, Quaternion(Vector3.RIGHT, m_left_arm_pitch))
	_set_bone_pose(BONE_RIGHT_UPPER_ARM, Vector3.ZERO, Quaternion(Vector3.RIGHT, m_right_arm_pitch))
	_set_bone_pose(BONE_LEFT_FOREARM, Vector3.ZERO, Quaternion(Vector3.RIGHT, m_left_arm_pitch * -0.28))
	_set_bone_pose(BONE_RIGHT_FOREARM, Vector3.ZERO, Quaternion(Vector3.RIGHT, m_right_arm_pitch * -0.28))


func get_skeleton() -> Skeleton3D:
	return m_skeleton


func get_body_surface() -> MeshInstance3D:
	return m_body_surface


func _ensure_nodes() -> void:
	m_skeleton = get_node_or_null("Skeleton3D") as Skeleton3D
	if m_skeleton == null:
		m_skeleton = Skeleton3D.new()
		m_skeleton.name = "Skeleton3D"
		add_child(m_skeleton)
		_assign_editor_owner(m_skeleton)

	m_body_surface = m_skeleton.get_node_or_null(BODY_SURFACE_NAME) as MeshInstance3D
	if m_body_surface == null:
		m_body_surface = MeshInstance3D.new()
		m_body_surface.name = BODY_SURFACE_NAME
		m_skeleton.add_child(m_body_surface)
		_assign_editor_owner(m_body_surface)
	m_body_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	m_head_attachment = _ensure_attachment(HEAD_ATTACHMENT_NAME, BONE_HEAD)
	m_left_hand_attachment = _ensure_attachment(LEFT_HAND_ATTACHMENT_NAME, BONE_LEFT_HAND)
	m_right_hand_attachment = _ensure_attachment(RIGHT_HAND_ATTACHMENT_NAME, BONE_RIGHT_HAND)


func _ensure_attachment(attachment_name: String, bone_name: String) -> BoneAttachment3D:
	var attachment := m_skeleton.get_node_or_null(attachment_name) as BoneAttachment3D
	if attachment == null:
		attachment = BoneAttachment3D.new()
		attachment.name = attachment_name
		m_skeleton.add_child(attachment)
		_assign_editor_owner(attachment)
	if m_skeleton.find_bone(bone_name) >= 0:
		attachment.set("bone_name", bone_name)
	return attachment


func _sync_attachment_bones() -> void:
	if is_instance_valid(m_head_attachment):
		m_head_attachment.set("bone_name", BONE_HEAD)
	if is_instance_valid(m_left_hand_attachment):
		m_left_hand_attachment.set("bone_name", BONE_LEFT_HAND)
	if is_instance_valid(m_right_hand_attachment):
		m_right_hand_attachment.set("bone_name", BONE_RIGHT_HAND)


func _rebuild_skeleton() -> void:
	if !is_instance_valid(m_skeleton):
		return

	m_skeleton.clear_bones()
	for bone_name in BONE_NAMES:
		m_skeleton.add_bone(bone_name)

	_set_parent(BONE_SPINE, BONE_HIPS)
	_set_parent(BONE_HEAD, BONE_SPINE)
	_set_parent(BONE_LEFT_UPPER_ARM, BONE_SPINE)
	_set_parent(BONE_LEFT_FOREARM, BONE_LEFT_UPPER_ARM)
	_set_parent(BONE_LEFT_HAND, BONE_LEFT_FOREARM)
	_set_parent(BONE_RIGHT_UPPER_ARM, BONE_SPINE)
	_set_parent(BONE_RIGHT_FOREARM, BONE_RIGHT_UPPER_ARM)
	_set_parent(BONE_RIGHT_HAND, BONE_RIGHT_FOREARM)
	_set_parent(BONE_LEFT_UPPER_LEG, BONE_HIPS)
	_set_parent(BONE_LEFT_LOWER_LEG, BONE_LEFT_UPPER_LEG)
	_set_parent(BONE_LEFT_FOOT, BONE_LEFT_LOWER_LEG)
	_set_parent(BONE_RIGHT_UPPER_LEG, BONE_HIPS)
	_set_parent(BONE_RIGHT_LOWER_LEG, BONE_RIGHT_UPPER_LEG)
	_set_parent(BONE_RIGHT_FOOT, BONE_RIGHT_LOWER_LEG)

	var proportions := _resolve_proportions()
	var hip_y := float(proportions["hip_y"])
	var torso_height := float(proportions["torso_height"])
	var shoulder_width := float(proportions["shoulder_width"])
	var hip_width := float(proportions["hip_width"])
	var upper_arm_length := float(proportions["upper_arm_length"])
	var forearm_length := float(proportions["forearm_length"])
	var upper_leg_length := float(proportions["upper_leg_length"])
	var lower_leg_length := float(proportions["lower_leg_length"])
	_set_rest(BONE_HIPS, Vector3(0.0, hip_y, 0.0))
	_set_rest(BONE_SPINE, Vector3(0.0, torso_height * 0.45, 0.0))
	_set_rest(BONE_HEAD, Vector3(0.0, torso_height * 0.56, 0.0))
	_set_rest(BONE_LEFT_UPPER_ARM, Vector3(-shoulder_width * 0.5, torso_height * 0.32, 0.0))
	_set_rest(BONE_LEFT_FOREARM, Vector3(0.0, -upper_arm_length, 0.0))
	_set_rest(BONE_LEFT_HAND, Vector3(0.0, -forearm_length, 0.0))
	_set_rest(BONE_RIGHT_UPPER_ARM, Vector3(shoulder_width * 0.5, torso_height * 0.32, 0.0))
	_set_rest(BONE_RIGHT_FOREARM, Vector3(0.0, -upper_arm_length, 0.0))
	_set_rest(BONE_RIGHT_HAND, Vector3(0.0, -forearm_length, 0.0))
	_set_rest(BONE_LEFT_UPPER_LEG, Vector3(-hip_width * 0.32, 0.0, 0.0))
	_set_rest(BONE_LEFT_LOWER_LEG, Vector3(0.0, -upper_leg_length, 0.0))
	_set_rest(BONE_LEFT_FOOT, Vector3(0.0, -lower_leg_length, 0.08))
	_set_rest(BONE_RIGHT_UPPER_LEG, Vector3(hip_width * 0.32, 0.0, 0.0))
	_set_rest(BONE_RIGHT_LOWER_LEG, Vector3(0.0, -upper_leg_length, 0.0))
	_set_rest(BONE_RIGHT_FOOT, Vector3(0.0, -lower_leg_length, 0.08))
	_sync_attachment_bones()


func _rebuild_body_mesh() -> void:
	if !is_instance_valid(m_body_surface):
		return

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var proportions := _resolve_proportions()
	var hip_y := float(proportions["hip_y"])
	var torso_height := float(proportions["torso_height"])
	var hip_width := float(proportions["hip_width"])
	var shoulder_width := float(proportions["shoulder_width"])
	var depth := float(proportions["depth"])
	var head_y := float(proportions["head_y"])
	var head_width := float(proportions["head_width"])
	var head_height := float(proportions["head_height"])
	var head_depth := float(proportions["head_depth"])
	var upper_leg_center_y := float(proportions["upper_leg_center_y"])
	var lower_leg_center_y := float(proportions["lower_leg_center_y"])
	var upper_leg_length := float(proportions["upper_leg_length"])
	var lower_leg_length := float(proportions["lower_leg_length"])
	var arm_length := float(proportions["arm_length"])
	var limb_width := float(proportions["limb_width"])
	var mirrored_left_width := limb_width * m_config.left_limb_scale
	var mirrored_right_width := limb_width * m_config.right_limb_scale
	var left_limb_color := m_config.accent_color if m_config.left_accent_flag else m_config.main_color
	var right_limb_color := m_config.accent_color if m_config.right_accent_flag else m_config.main_color

	_add_box(vertices, normals, colors, Vector3(0.0, hip_y + torso_height * 0.24, 0.0), Vector3(hip_width, torso_height * 0.48, depth), m_config.main_color.darkened(0.08))
	_add_box(vertices, normals, colors, Vector3(0.0, hip_y + torso_height * 0.63, 0.0), Vector3(shoulder_width, torso_height * 0.62, depth * 1.04), m_config.main_color)
	_add_box(vertices, normals, colors, Vector3(0.0, head_y, 0.02), Vector3(head_width, head_height, head_depth), m_config.skin_color)
	_add_box(vertices, normals, colors, Vector3(0.0, head_y + head_height * 0.45, -0.01), Vector3(head_width * 1.08, head_height * 0.24, head_depth * 1.05), m_config.hair_color)
	_add_box(vertices, normals, colors, Vector3(0.0, head_y, head_depth * 0.54), Vector3(head_width * 0.46, head_height * 0.12, 0.035), Color(0.08, 0.07, 0.06, 1.0))
	_add_box(vertices, normals, colors, Vector3(0.0, head_y - head_height * 0.28, head_depth * 0.55), Vector3(head_width * 0.14, head_height * 0.22, 0.04), m_config.accent_color)

	_add_box(vertices, normals, colors, Vector3(-shoulder_width * 0.62, hip_y + torso_height * 0.44, 0.0), Vector3(mirrored_left_width, arm_length, mirrored_left_width * 0.86), left_limb_color)
	_add_box(vertices, normals, colors, Vector3(shoulder_width * 0.62, hip_y + torso_height * 0.44, 0.0), Vector3(mirrored_right_width, arm_length, mirrored_right_width * 0.86), right_limb_color)
	_add_box(vertices, normals, colors, Vector3(-hip_width * 0.28, upper_leg_center_y, 0.0), Vector3(mirrored_left_width * 1.08, upper_leg_length, mirrored_left_width), left_limb_color.darkened(0.12))
	_add_box(vertices, normals, colors, Vector3(hip_width * 0.28, upper_leg_center_y, 0.0), Vector3(mirrored_right_width * 1.08, upper_leg_length, mirrored_right_width), right_limb_color.darkened(0.12))
	_add_box(vertices, normals, colors, Vector3(-hip_width * 0.28, lower_leg_center_y, 0.0), Vector3(mirrored_left_width * 0.92, lower_leg_length, mirrored_left_width * 0.9), left_limb_color.darkened(0.22))
	_add_box(vertices, normals, colors, Vector3(hip_width * 0.28, lower_leg_center_y, 0.0), Vector3(mirrored_right_width * 0.92, lower_leg_length, mirrored_right_width * 0.9), right_limb_color.darkened(0.22))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	m_body_surface.mesh = mesh
	m_body_surface.material_override = _get_material()


func _reset_pose() -> void:
	for bone_name in BONE_NAMES:
		_set_bone_pose(bone_name, Vector3.ZERO, Quaternion.IDENTITY)


func _resolve_proportions() -> Dictionary:
	var effective_height := m_body_height * m_config.height_modifier
	var radius_scale := m_body_radius / 0.28
	var torso_height := effective_height * 0.42
	var leg_height := effective_height * 0.40
	var head_height := effective_height * 0.18 * m_config.head_scale
	var hip_y := leg_height
	var shoulder_width := m_body_radius * 1.9 * m_config.torso_mass
	var hip_width := m_body_radius * 1.35
	var limb_width := m_body_radius * 0.46 * m_config.limb_thickness
	return {
		"effective_height": effective_height,
		"hip_y": hip_y,
		"torso_height": torso_height,
		"upper_leg_length": leg_height * 0.52,
		"lower_leg_length": leg_height * 0.48,
		"upper_leg_center_y": hip_y - (leg_height * 0.26),
		"lower_leg_center_y": hip_y - (leg_height * 0.76),
		"arm_length": effective_height * 0.34,
		"upper_arm_length": effective_height * 0.17,
		"forearm_length": effective_height * 0.17,
		"head_y": hip_y + torso_height + head_height * 0.45,
		"head_height": head_height,
		"head_width": m_body_radius * 1.18 * m_config.head_scale * radius_scale,
		"head_depth": m_body_radius * 1.02 * m_config.head_scale * radius_scale,
		"shoulder_width": shoulder_width,
		"hip_width": hip_width,
		"limb_width": limb_width,
		"depth": m_body_radius * 1.16,
	}


func _add_box(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	center: Vector3,
	size: Vector3,
	color: Color
) -> void:
	var half := size * 0.5
	var corners := [
		center + Vector3(-half.x, -half.y, -half.z),
		center + Vector3(half.x, -half.y, -half.z),
		center + Vector3(half.x, half.y, -half.z),
		center + Vector3(-half.x, half.y, -half.z),
		center + Vector3(-half.x, -half.y, half.z),
		center + Vector3(half.x, -half.y, half.z),
		center + Vector3(half.x, half.y, half.z),
		center + Vector3(-half.x, half.y, half.z),
	]
	_add_face(vertices, normals, colors, corners[4], corners[5], corners[6], corners[7], Vector3.BACK, color)
	_add_face(vertices, normals, colors, corners[1], corners[0], corners[3], corners[2], Vector3.FORWARD, color)
	_add_face(vertices, normals, colors, corners[0], corners[4], corners[7], corners[3], Vector3.LEFT, color)
	_add_face(vertices, normals, colors, corners[5], corners[1], corners[2], corners[6], Vector3.RIGHT, color)
	_add_face(vertices, normals, colors, corners[3], corners[7], corners[6], corners[2], Vector3.UP, color)
	_add_face(vertices, normals, colors, corners[0], corners[1], corners[5], corners[4], Vector3.DOWN, color)


func _add_face(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	normal: Vector3,
	color: Color
) -> void:
	for vertex in [a, c, b, a, d, c]:
		vertices.append(vertex)
		normals.append(normal)
		colors.append(color)


func _get_material() -> StandardMaterial3D:
	if m_material == null:
		m_material = StandardMaterial3D.new()
		m_material.albedo_color = Color.WHITE
		m_material.vertex_color_use_as_albedo = true
		m_material.cull_mode = BaseMaterial3D.CULL_BACK
		m_material.roughness = 1.0
		m_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		m_material.disable_receive_shadows = true
	return m_material


func _set_parent(child_name: String, parent_name: String) -> void:
	var child_idx := m_skeleton.find_bone(child_name)
	var parent_idx := m_skeleton.find_bone(parent_name)
	if child_idx >= 0 and parent_idx >= 0:
		m_skeleton.set_bone_parent(child_idx, parent_idx)


func _set_rest(bone_name: String, local_position: Vector3) -> void:
	var bone_idx := m_skeleton.find_bone(bone_name)
	if bone_idx < 0:
		return
	m_skeleton.set_bone_rest(bone_idx, Transform3D(Basis.IDENTITY, local_position))


func _set_bone_pose(bone_name: String, local_position: Vector3, local_rotation: Quaternion) -> void:
	var bone_idx := m_skeleton.find_bone(bone_name)
	if bone_idx < 0:
		return
	m_skeleton.set_bone_pose_position(bone_idx, local_position)
	m_skeleton.set_bone_pose_rotation(bone_idx, local_rotation)


func _assign_editor_owner(node: Node) -> void:
	if Engine.is_editor_hint():
		node.owner = null
