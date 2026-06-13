extends Node3D

const PRIMARY_SEED := "kulangsu-player-preview"
const VARIANT_SEEDS: Array[String] = [
	"harbor-hero-42",
	"piano-island-guide",
	"bagua-stair-runner",
	"ferry-arrival-summer",
]
const STATE_ORDER: Array[String] = ["idle", "walk", "run", "jump"]
const STATE_SECONDS := 1.35

@onready var m_primary_actor: HumanBody3D = $AnimatedProceduralCharacter
@onready var m_variant_line: Node3D = $VariantLine

var m_variant_actors: Array[HumanBody3D] = []
var m_state_index := 0
var m_state_time := 0.0


func _ready() -> void:
	_cache_variant_actors()
	_initialize_preview_actors()
	call_deferred("_run_smoke_checks")


func _process(delta: float) -> void:
	if !is_instance_valid(m_primary_actor):
		return

	m_state_time += delta
	if m_state_time >= STATE_SECONDS:
		m_state_time = 0.0
		m_state_index = (m_state_index + 1) % STATE_ORDER.size()
		_apply_preview_state(m_primary_actor, STATE_ORDER[m_state_index])

	for i in range(m_variant_actors.size()):
		var actor := m_variant_actors[i]
		if !is_instance_valid(actor):
			continue
		actor.direction = fposmod(actor.direction + delta * (18.0 + i * 4.0), 360.0)


func _cache_variant_actors() -> void:
	m_variant_actors.clear()
	if !is_instance_valid(m_variant_line):
		return

	for i in range(VARIANT_SEEDS.size()):
		var actor := m_variant_line.get_node_or_null("SeedVariant%d" % (i + 1)) as HumanBody3D
		if actor != null:
			m_variant_actors.append(actor)


func _initialize_preview_actors() -> void:
	if is_instance_valid(m_primary_actor):
		m_primary_actor.procedural_seed = PRIMARY_SEED
		m_primary_actor.use_procedural_rig = true
		_apply_preview_state(m_primary_actor, STATE_ORDER[m_state_index])

	for i in range(m_variant_actors.size()):
		var actor := m_variant_actors[i]
		if !is_instance_valid(actor):
			continue
		actor.procedural_seed = VARIANT_SEEDS[i]
		actor.use_procedural_rig = true
		actor.is_walking = true
		actor.is_running = false
		actor.direction = 90.0


func _apply_preview_state(actor: HumanBody3D, state_name: String) -> void:
	if !is_instance_valid(actor):
		return

	actor.is_walking = state_name == "walk" or state_name == "run"
	actor.is_running = state_name == "run"
	if state_name == "jump":
		actor.jump()
	actor.direction = [90.0, 0.0, 270.0, 180.0][m_state_index]


func _run_smoke_checks() -> void:
	await get_tree().process_frame

	var failures: Array[String] = []
	_validate_preview_actor(failures, m_primary_actor)
	if m_variant_actors.size() != VARIANT_SEEDS.size():
		failures.append("low-poly character preview did not create every seed variant")

	var snapshots: Array[Dictionary] = []
	for actor in m_variant_actors:
		_validate_preview_actor(failures, actor)
		var rig := _get_actor_rig(actor)
		if rig != null:
			snapshots.append(rig.call("get_config_snapshot"))

	if snapshots.size() >= 2 and snapshots[0] == snapshots[1]:
		failures.append("low-poly character seed variants produced identical config snapshots")

	if failures.is_empty():
		print("PASS: LowPolyCharacter3D smoke test")
	else:
		for failure in failures:
			push_error(failure)


func _validate_preview_actor(failures: Array[String], actor: HumanBody3D) -> void:
	if !is_instance_valid(actor):
		failures.append("low-poly character preview is missing a HumanBody3D actor")
		return
	if !bool(actor.get("use_procedural_rig")):
		failures.append("%s does not have procedural rig mode enabled" % actor.name)

	var visual_root := actor.get_node_or_null("VisualRoot") as Node3D
	if visual_root == null:
		failures.append("%s is missing VisualRoot" % actor.name)
		return

	var legacy_body := visual_root.get_node_or_null("Body") as MeshInstance3D
	if legacy_body != null and legacy_body.visible:
		failures.append("%s still shows the legacy block body" % actor.name)

	var rig := _get_actor_rig(actor)
	if rig == null:
		failures.append("%s is missing ProceduralLowPolyCharacterRig" % actor.name)
		return

	var skeleton := rig.get_node_or_null("Skeleton3D") as Skeleton3D
	if skeleton == null:
		failures.append("%s rig is missing Skeleton3D" % actor.name)
	else:
		for bone_name in ["Hips", "Spine", "Head", "LeftHand", "RightHand"]:
			if skeleton.find_bone(bone_name) < 0:
				failures.append("%s rig is missing bone %s" % [actor.name, bone_name])

	for attachment_path in [
		"Skeleton3D/HeadAttachment",
		"Skeleton3D/LeftHandAttachment",
		"Skeleton3D/RightHandAttachment",
	]:
		if rig.get_node_or_null(attachment_path) == null:
			failures.append("%s rig is missing %s" % [actor.name, attachment_path])

	var body_surface := rig.get_node_or_null("Skeleton3D/BodySurface") as MeshInstance3D
	if body_surface == null or body_surface.mesh == null:
		failures.append("%s rig is missing BodySurface mesh" % actor.name)
		return
	if body_surface.mesh.get_surface_count() <= 0:
		failures.append("%s rig generated no mesh surfaces" % actor.name)
		return

	var arrays := body_surface.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	if vertices.is_empty():
		failures.append("%s rig generated an empty mesh" % actor.name)
	elif vertices.size() < 1000:
		failures.append("%s rig generated too little geometry for the stylized model" % actor.name)
	if colors.size() != vertices.size():
		failures.append("%s rig did not assign per-vertex colors" % actor.name)
	elif _get_max_color_luminance(colors) <= 0.08:
		failures.append("%s rig generated black or near-black vertex colors" % actor.name)
	elif _get_unique_color_count(colors) < 8:
		failures.append("%s rig generated too few color regions for the stylized model" % actor.name)
	if normals.size() != vertices.size():
		failures.append("%s rig did not assign flat normals" % actor.name)
	else:
		_validate_renderer_facing_winding(failures, actor.name, vertices, normals)

	var material := body_surface.get_active_material(0) as StandardMaterial3D
	if material == null:
		failures.append("%s rig is missing StandardMaterial3D" % actor.name)
	else:
		if !material.vertex_color_use_as_albedo:
			failures.append("%s rig material does not use vertex color albedo" % actor.name)
		if material.albedo_color.get_luminance() < 0.95:
			failures.append("%s rig material albedo is darkening vertex colors" % actor.name)
		if material.cull_mode != BaseMaterial3D.CULL_BACK:
			failures.append("%s rig material should cull backfaces" % actor.name)

	rig.call("process_motion", 0.18, true, false, false)
	var motion_snapshot: Dictionary = rig.call("get_motion_snapshot")
	if absf(float(motion_snapshot.get("left_leg_pitch", 0.0))) <= 0.001:
		failures.append("%s rig did not produce walk motion" % actor.name)


func _get_max_color_luminance(colors: PackedColorArray) -> float:
	var max_luminance := 0.0
	for color in colors:
		max_luminance = maxf(max_luminance, color.get_luminance())
	return max_luminance


func _get_unique_color_count(colors: PackedColorArray) -> int:
	var unique_colors := {}
	for color in colors:
		unique_colors[color.to_html()] = true
	return unique_colors.size()


func _validate_renderer_facing_winding(
	failures: Array[String],
	actor_name: String,
	vertices: PackedVector3Array,
	normals: PackedVector3Array
) -> void:
	for triangle_start in range(0, vertices.size(), 3):
		if triangle_start + 2 >= vertices.size():
			failures.append("%s rig generated an incomplete triangle" % actor_name)
			return

		var a := vertices[triangle_start]
		var b := vertices[triangle_start + 1]
		var c := vertices[triangle_start + 2]
		var generated_normal := (b - a).cross(c - a).normalized()
		if generated_normal.dot(normals[triangle_start].normalized()) > -0.98:
			failures.append("%s rig generated renderer-back-facing triangle winding" % actor_name)
			return


func _get_actor_rig(actor: HumanBody3D) -> Node3D:
	if !is_instance_valid(actor):
		return null
	var visual_root := actor.get_node_or_null("VisualRoot") as Node3D
	if visual_root == null:
		return null
	return visual_root.get_node_or_null("ProceduralLowPolyCharacterRig") as Node3D
