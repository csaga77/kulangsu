@tool
class_name ProceduralLowPolyCharacterRig
extends Node3D

const DEFAULT_SEED := "kulangsu_player"
const BODY_SURFACE_NAME := "BodySurface"
const HEAD_ATTACHMENT_NAME := "HeadAttachment"
const LEFT_HAND_ATTACHMENT_NAME := "LeftHandAttachment"
const RIGHT_HAND_ATTACHMENT_NAME := "RightHandAttachment"
const STYLE_MODEL_ID := "stylized_low_poly_avatar_v1"
const STYLE_FACE_DETAIL_PRIMITIVES := 3
const PROFILE_SIDES := 8

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
var m_profile := PackedVector2Array()


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


func get_style_snapshot() -> Dictionary:
	var proportions := _resolve_proportions()
	var effective_height := float(proportions["effective_height"])
	return {
		"model_id": STYLE_MODEL_ID,
		"anatomy": "simplified",
		"proportions": "stylized_realistic",
		"silhouette": "simple_readable",
		"face_detail_primitives": STYLE_FACE_DETAIL_PRIMITIVES,
		"material_profile": "flat_vertex_color",
		"uses_external_assets": false,
		"head_height_ratio": snappedf(float(proportions["head_height"]) / effective_height, 0.0001),
		"torso_height_ratio": snappedf(float(proportions["torso_height"]) / effective_height, 0.0001),
		"leg_height_ratio": snappedf(float(proportions["leg_height"]) / effective_height, 0.0001),
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
	var upper_arm_length := float(proportions["upper_arm_length"])
	var forearm_length := float(proportions["forearm_length"])
	var limb_width := float(proportions["limb_width"])
	var left_width := limb_width * m_config.left_limb_scale
	var right_width := limb_width * m_config.right_limb_scale
	var leg_height := float(proportions["leg_height"])
	var face_front_z := head_depth * 0.55
	var shoulder_y := hip_y + torso_height * 0.74

	# Outfit palette derived from the casual adult-male reference design.
	var jacket_color := m_config.main_color
	var jacket_dark := jacket_color.darkened(0.14)
	var jacket_light := jacket_color.lightened(0.16)
	var tee_color := m_config.accent_color
	var pants_color := m_config.pants_color
	var pants_cuff := pants_color.lightened(0.14)
	var boots_color := m_config.boots_color
	var boots_sole := boots_color.darkened(0.24)
	var skin_color := m_config.skin_color
	var hair_color := m_config.hair_color
	var hair_dark := hair_color.darkened(0.14)
	var brow_color := hair_color.darkened(0.05)
	var eye_color := Color(0.08, 0.065, 0.05, 1.0)
	var nose_color := skin_color.darkened(0.05)
	var mouth_color := skin_color.darkened(0.32)

	# --- Pelvis / pants seat (faceted octagonal prism) ---
	_add_loft(vertices, normals, colors, [
		_ring(hip_y - leg_height * 0.02, 0.0, 0.0, hip_width * 0.50, depth * 0.52),
		_ring(hip_y + torso_height * 0.06, 0.0, 0.0, hip_width * 0.55, depth * 0.58),
		_ring(hip_y + torso_height * 0.20, 0.0, 0.0, hip_width * 0.50, depth * 0.54),
	], pants_color, true, false)

	# --- Fitted jacket torso (lofted shell, clean crew neckline) ---
	_add_loft(vertices, normals, colors, [
		_ring(hip_y + torso_height * 0.20, 0.0, 0.0, hip_width * 0.52, depth * 0.56),
		_ring(hip_y + torso_height * 0.42, 0.0, 0.0, shoulder_width * 0.46, depth * 0.60),
		_ring(hip_y + torso_height * 0.62, 0.0, 0.0, shoulder_width * 0.52, depth * 0.64),
		_ring(hip_y + torso_height * 0.78, 0.0, 0.0, shoulder_width * 0.56, depth * 0.58),
		_ring(hip_y + torso_height * 0.92, 0.0, 0.0, shoulder_width * 0.30, depth * 0.38),
	], jacket_color, false, true)

	# --- Flush cream tee V at the open neckline ---
	_add_outward_quad(vertices, normals, colors,
		Vector3(-shoulder_width * 0.10, hip_y + torso_height * 0.55, depth * 0.66),
		Vector3(shoulder_width * 0.10, hip_y + torso_height * 0.55, depth * 0.66),
		Vector3(shoulder_width * 0.20, hip_y + torso_height * 0.90, depth * 0.60),
		Vector3(-shoulder_width * 0.20, hip_y + torso_height * 0.90, depth * 0.60),
		Vector3.BACK, tee_color)

	# --- Short faceted neck (overlaps the jacket neckline) ---
	_add_limb(vertices, normals, colors, 0.0, 0.0, head_y - head_height * 0.30, hip_y + torso_height * 0.90, head_width * 0.26, head_width * 0.30, skin_color, false, false)

	# --- Faceted head (lofted skull, compressed lower face) ---
	_add_loft(vertices, normals, colors, [
		_ring(head_y - head_height * 0.34, 0.0, 0.01, head_width * 0.32, head_depth * 0.36),
		_ring(head_y - head_height * 0.18, 0.0, 0.02, head_width * 0.44, head_depth * 0.47),
		_ring(head_y + head_height * 0.00, 0.0, 0.02, head_width * 0.50, head_depth * 0.50),
		_ring(head_y + head_height * 0.18, 0.0, 0.01, head_width * 0.50, head_depth * 0.50),
		_ring(head_y + head_height * 0.34, 0.0, 0.00, head_width * 0.46, head_depth * 0.47),
		_ring(head_y + head_height * 0.48, 0.0, 0.00, head_width * 0.32, head_depth * 0.34),
	], skin_color, true, true)
	for s in [-1.0, 1.0]:
		_add_box(vertices, normals, colors, Vector3(s * head_width * 0.50, head_y - head_height * 0.02, 0.0), Vector3(head_width * 0.08, head_height * 0.20, head_depth * 0.30), skin_color)

	# --- Faceted hair: shell, fringe, spiky tufts ---
	_add_loft(vertices, normals, colors, [
		_ring(head_y + head_height * 0.10, 0.0, -0.005, head_width * 0.52, head_depth * 0.52),
		_ring(head_y + head_height * 0.34, 0.0, -0.005, head_width * 0.50, head_depth * 0.50),
		_ring(head_y + head_height * 0.50, 0.0, -0.01, head_width * 0.34, head_depth * 0.36),
	], hair_color, false, false)
	_add_outward_quad(vertices, normals, colors,
		Vector3(-head_width * 0.40, head_y + head_height * 0.10, head_depth * 0.42),
		Vector3(head_width * 0.40, head_y + head_height * 0.10, head_depth * 0.42),
		Vector3(head_width * 0.42, head_y + head_height * 0.30, head_depth * 0.30),
		Vector3(-head_width * 0.42, head_y + head_height * 0.30, head_depth * 0.30),
		Vector3.BACK, hair_color)
	var spikes := [
		[-0.22, 0.55, 0.10, hair_color],
		[0.0, 0.62, -0.02, hair_color],
		[0.24, 0.54, 0.06, hair_dark],
		[-0.05, 0.50, 0.30, hair_color],
		[0.34, 0.40, 0.0, hair_dark],
		[-0.34, 0.42, 0.0, hair_color],
	]
	for spike in spikes:
		var sx: float = spike[0]
		var sy: float = spike[1]
		var sz: float = spike[2]
		var spike_color: Color = spike[3]
		var bx := sx * head_width
		var by := head_y + head_height * sy
		var bz := sz * head_depth
		var spike_w := head_width * 0.20
		var spike_d := head_depth * 0.20
		_add_pyramid(vertices, normals, colors,
			Vector3(bx + sx * head_width * 0.25, by + head_height * 0.26, bz + sz * head_depth * 0.20),
			Vector3(bx - spike_w, by - head_height * 0.05, bz - spike_d),
			Vector3(bx + spike_w, by - head_height * 0.05, bz - spike_d),
			Vector3(bx + spike_w, by - head_height * 0.05, bz + spike_d),
			Vector3(bx - spike_w, by - head_height * 0.05, bz + spike_d),
			spike_color)

	# --- Face features (flat decals on the face surface, not protruding boxes) ---
	var decal_z := face_front_z + 0.004
	for s in [-1.0, 1.0]:
		_add_face_decal(vertices, normals, colors, s * head_width * 0.17, head_y + head_height * 0.06, head_width * 0.10, head_height * 0.05, decal_z, eye_color)
		_add_face_decal(vertices, normals, colors, s * head_width * 0.16, head_y + head_height * 0.17, head_width * 0.12, head_height * 0.025, decal_z, brow_color)
	_add_pyramid(vertices, normals, colors,
		Vector3(0.0, head_y - head_height * 0.03, face_front_z + 0.028),
		Vector3(-head_width * 0.05, head_y - head_height * 0.13, face_front_z),
		Vector3(head_width * 0.05, head_y - head_height * 0.13, face_front_z),
		Vector3(head_width * 0.04, head_y - head_height * 0.03, face_front_z),
		Vector3(-head_width * 0.04, head_y - head_height * 0.03, face_front_z),
		nose_color)
	_add_face_decal(vertices, normals, colors, 0.0, head_y - head_height * 0.20, head_width * 0.15, head_height * 0.03, decal_z, mouth_color)

	# --- Arms (jacket sleeves rolled to the forearm) ---
	_add_arm(vertices, normals, colors, -shoulder_width * 0.50, left_width, shoulder_y, upper_arm_length, forearm_length, jacket_color, jacket_dark, jacket_light, skin_color)
	_add_arm(vertices, normals, colors, shoulder_width * 0.50, right_width, shoulder_y, upper_arm_length, forearm_length, jacket_color, jacket_dark, jacket_light, skin_color)

	# --- Legs (pants, rolled cuffs, boots) ---
	_add_leg(vertices, normals, colors, -hip_width * 0.30, left_width, upper_leg_center_y, lower_leg_center_y, upper_leg_length, lower_leg_length, pants_color, pants_cuff, boots_color, boots_sole)
	_add_leg(vertices, normals, colors, hip_width * 0.30, right_width, upper_leg_center_y, lower_leg_center_y, upper_leg_length, lower_leg_length, pants_color, pants_cuff, boots_color, boots_sole)

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
	var head_t := inverse_lerp(
		LowPolyCharacterConfig.MIN_HEAD_SCALE,
		LowPolyCharacterConfig.MAX_HEAD_SCALE,
		m_config.head_scale
	)
	var torso_t := inverse_lerp(
		LowPolyCharacterConfig.MIN_TORSO_MASS,
		LowPolyCharacterConfig.MAX_TORSO_MASS,
		m_config.torso_mass
	)
	var limb_t := inverse_lerp(
		LowPolyCharacterConfig.MIN_LIMB_THICKNESS,
		LowPolyCharacterConfig.MAX_LIMB_THICKNESS,
		m_config.limb_thickness
	)
	# Slimmer adult-male proportions (~6.3 heads tall) matching the reference sheet.
	var cartoon_head_scale := lerpf(0.88, 1.18, clampf(head_t, 0.0, 1.0))
	var torso_height := effective_height * 0.34
	var leg_height := effective_height * 0.46
	var head_height := effective_height * 0.145 * cartoon_head_scale
	var hip_y := leg_height
	var shoulder_width := m_body_radius * lerpf(1.45, 1.88, clampf(torso_t, 0.0, 1.0))
	var hip_width := m_body_radius * 1.18
	var limb_width := m_body_radius * lerpf(0.34, 0.58, clampf(limb_t, 0.0, 1.0))
	var head_width := maxf(m_body_radius * 1.02 * cartoon_head_scale, shoulder_width * 0.50)
	var head_depth := maxf(m_body_radius * 0.92 * cartoon_head_scale, m_body_radius * 0.84)
	return {
		"effective_height": effective_height,
		"hip_y": hip_y,
		"leg_height": leg_height,
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
		"head_width": head_width,
		"head_depth": head_depth,
		"shoulder_width": shoulder_width,
		"hip_width": hip_width,
		"limb_width": limb_width,
		"depth": m_body_radius * 1.16,
	}


func _add_arm(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	arm_x: float,
	limb: float,
	shoulder_y: float,
	upper_arm_length: float,
	forearm_length: float,
	sleeve_color: Color,
	sleeve_shade: Color,
	cuff_color: Color,
	skin: Color
) -> void:
	var elbow_y := shoulder_y - upper_arm_length
	# Upper sleeve (jacket).
	_add_limb(vertices, normals, colors, arm_x, 0.0, shoulder_y, elbow_y, limb * 0.62, limb * 0.52, sleeve_color, false, true)
	# Lower sleeve, rolled short (jacket shade).
	_add_limb(vertices, normals, colors, arm_x, 0.0, elbow_y, elbow_y - forearm_length * 0.40, limb * 0.52, limb * 0.48, sleeve_shade, false, false)
	# Rolled cuff band (lighter, flared).
	_add_loft(vertices, normals, colors, [
		_ring(elbow_y - forearm_length * 0.52, arm_x, 0.0, limb * 0.56, limb * 0.56),
		_ring(elbow_y - forearm_length * 0.40, arm_x, 0.0, limb * 0.50, limb * 0.50),
	], cuff_color, false, false)
	# Bare forearm (skin) below the roll.
	_add_limb(vertices, normals, colors, arm_x, 0.0, elbow_y - forearm_length * 0.52, elbow_y - forearm_length * 0.86, limb * 0.46, limb * 0.40, skin, false, false)
	# Hand (skin).
	_add_limb(vertices, normals, colors, arm_x, 0.01, elbow_y - forearm_length * 0.86, elbow_y - forearm_length * 1.02, limb * 0.44, limb * 0.42, skin, true, true)


func _add_leg(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	leg_x: float,
	limb: float,
	upper_leg_center_y: float,
	lower_leg_center_y: float,
	upper_leg_length: float,
	lower_leg_length: float,
	pants_color: Color,
	cuff_color: Color,
	boots_color: Color,
	sole_color: Color
) -> void:
	var ankle_y := lower_leg_center_y - lower_leg_length * 0.5
	# Thigh (pants).
	_add_limb(vertices, normals, colors, leg_x, 0.0, upper_leg_center_y + upper_leg_length * 0.5, upper_leg_center_y - upper_leg_length * 0.5, limb * 0.66, limb * 0.56, pants_color, false, false)
	# Shin (pants), from the knee down to above the ankle (meets the thigh).
	_add_limb(vertices, normals, colors, leg_x, 0.0, lower_leg_center_y + lower_leg_length * 0.52, lower_leg_center_y - lower_leg_length * 0.20, limb * 0.56, limb * 0.48, pants_color, false, false)
	# Rolled cuff at the bottom of the pant leg.
	_add_loft(vertices, normals, colors, [
		_ring(lower_leg_center_y - lower_leg_length * 0.32, leg_x, 0.0, limb * 0.60, limb * 0.58),
		_ring(lower_leg_center_y - lower_leg_length * 0.20, leg_x, 0.0, limb * 0.52, limb * 0.50),
	], cuff_color, false, false)
	# Boot shaft over the ankle.
	_add_limb(vertices, normals, colors, leg_x, 0.02, ankle_y + lower_leg_length * 0.20, ankle_y - lower_leg_length * 0.02, limb * 0.56, limb * 0.58, boots_color, false, true)
	# Boot foot extending forward.
	_add_box(vertices, normals, colors, Vector3(leg_x, ankle_y - lower_leg_length * 0.08, 0.07), Vector3(limb * 1.25, lower_leg_length * 0.16, limb * 1.55), boots_color)
	# Sole.
	_add_box(vertices, normals, colors, Vector3(leg_x, ankle_y - lower_leg_length * 0.14, 0.07), Vector3(limb * 1.28, lower_leg_length * 0.06, limb * 1.60), sole_color)


func _get_profile() -> PackedVector2Array:
	if m_profile.size() == PROFILE_SIDES:
		return m_profile
	m_profile = PackedVector2Array()
	for i in range(PROFILE_SIDES):
		var angle := deg_to_rad(22.5 + 45.0 * float(i))
		m_profile.append(Vector2(cos(angle), sin(angle)))
	return m_profile


func _ring(y: float, cx: float, cz: float, rx: float, rz: float) -> PackedVector3Array:
	var ring := PackedVector3Array()
	for direction in _get_profile():
		ring.append(Vector3(cx + direction.x * rx, y, cz + direction.y * rz))
	return ring


func _ring_center(ring: PackedVector3Array) -> Vector3:
	if ring.is_empty():
		return Vector3.ZERO
	var center := Vector3.ZERO
	for point in ring:
		center += point
	return center / float(ring.size())


func _add_loft(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	rings: Array,
	color: Color,
	cap_bottom: bool,
	cap_top: bool
) -> void:
	if rings.is_empty():
		return
	var sides := PROFILE_SIDES
	for r in range(rings.size() - 1):
		var lower: PackedVector3Array = rings[r]
		var upper: PackedVector3Array = rings[r + 1]
		for i in range(sides):
			var j := (i + 1) % sides
			_add_face(vertices, normals, colors, lower[i], upper[i], upper[j], lower[j], Vector3.UP, color)
	if cap_bottom:
		var first_ring: PackedVector3Array = rings[0]
		var bottom_center := _ring_center(first_ring)
		for i in range(sides):
			var j := (i + 1) % sides
			_add_outward_tri(vertices, normals, colors, bottom_center, first_ring[i], first_ring[j], Vector3.DOWN, color)
	if cap_top:
		var last_ring: PackedVector3Array = rings[rings.size() - 1]
		var top_center := _ring_center(last_ring)
		for i in range(sides):
			var j := (i + 1) % sides
			_add_outward_tri(vertices, normals, colors, top_center, last_ring[i], last_ring[j], Vector3.UP, color)


func _add_limb(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	x: float,
	z: float,
	y_top: float,
	y_bottom: float,
	r_top: float,
	r_bottom: float,
	color: Color,
	cap_bottom: bool,
	cap_top: bool
) -> void:
	_add_loft(vertices, normals, colors, [
		_ring(y_bottom, x, z, r_bottom, r_bottom),
		_ring(y_top, x, z, r_top, r_top),
	], color, cap_bottom, cap_top)


func _add_tri(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	color: Color
) -> void:
	var face_normal := (b - a).cross(c - a).normalized()
	if face_normal.length_squared() <= 0.000001:
		face_normal = Vector3.UP
	for vertex in [a, c, b]:
		vertices.append(vertex)
		normals.append(face_normal)
		colors.append(color)


func _add_outward_tri(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	outward: Vector3,
	color: Color
) -> void:
	if (b - a).cross(c - a).dot(outward) < 0.0:
		_add_tri(vertices, normals, colors, a, c, b, color)
	else:
		_add_tri(vertices, normals, colors, a, b, c, color)


func _add_outward_quad(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	outward: Vector3,
	color: Color
) -> void:
	if (b - a).cross(c - a).dot(outward) < 0.0:
		_add_face(vertices, normals, colors, a, d, c, b, outward, color)
	else:
		_add_face(vertices, normals, colors, a, b, c, d, outward, color)


func _add_face_decal(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	cx: float,
	cy: float,
	w: float,
	h: float,
	z: float,
	color: Color
) -> void:
	_add_outward_quad(vertices, normals, colors,
		Vector3(cx - w * 0.5, cy - h * 0.5, z),
		Vector3(cx + w * 0.5, cy - h * 0.5, z),
		Vector3(cx + w * 0.5, cy + h * 0.5, z),
		Vector3(cx - w * 0.5, cy + h * 0.5, z),
		Vector3.BACK, color)


func _add_pyramid(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	apex: Vector3,
	b0: Vector3,
	b1: Vector3,
	b2: Vector3,
	b3: Vector3,
	color: Color
) -> void:
	var base := [b0, b1, b2, b3]
	var base_center := (b0 + b1 + b2 + b3) * 0.25
	for i in range(4):
		var p0: Vector3 = base[i]
		var p1: Vector3 = base[(i + 1) % 4]
		var triangle_center := (apex + p0 + p1) / 3.0
		_add_outward_tri(vertices, normals, colors, apex, p0, p1, triangle_center - base_center, color)
	_add_outward_quad(vertices, normals, colors, b0, b1, b2, b3, base_center - apex, color)


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


func _add_tapered_box(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	center: Vector3,
	bottom_size: Vector2,
	top_size: Vector2,
	height: float,
	color: Color
) -> void:
	var bottom_half := bottom_size * 0.5
	var top_half := top_size * 0.5
	var bottom_y := center.y - height * 0.5
	var top_y := center.y + height * 0.5
	var corners := [
		Vector3(center.x - bottom_half.x, bottom_y, center.z - bottom_half.y),
		Vector3(center.x + bottom_half.x, bottom_y, center.z - bottom_half.y),
		Vector3(center.x + top_half.x, top_y, center.z - top_half.y),
		Vector3(center.x - top_half.x, top_y, center.z - top_half.y),
		Vector3(center.x - bottom_half.x, bottom_y, center.z + bottom_half.y),
		Vector3(center.x + bottom_half.x, bottom_y, center.z + bottom_half.y),
		Vector3(center.x + top_half.x, top_y, center.z + top_half.y),
		Vector3(center.x - top_half.x, top_y, center.z + top_half.y),
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
	var face_normal := (b - a).cross(c - a).normalized()
	if face_normal.length_squared() <= 0.000001:
		face_normal = normal.normalized()
	for vertex in [a, c, b, a, d, c]:
		vertices.append(vertex)
		normals.append(face_normal)
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
