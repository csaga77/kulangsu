extends Node3D

const STATE_ORDER: Array[String] = ["idle", "walk", "run", "jump"]
const STATE_SECONDS := 1.35
const MODEL_NATIVE_HEIGHT := 0.998

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
	if not is_instance_valid(m_primary_actor):
		return

	m_state_time += delta
	if m_state_time >= STATE_SECONDS:
		m_state_time = 0.0
		m_state_index = (m_state_index + 1) % STATE_ORDER.size()
		_apply_preview_state(m_primary_actor, STATE_ORDER[m_state_index])

	for i in range(m_variant_actors.size()):
		var actor := m_variant_actors[i]
		if not is_instance_valid(actor):
			continue
		actor.direction = fposmod(actor.direction + delta * (18.0 + i * 4.0), 360.0)


func _cache_variant_actors() -> void:
	m_variant_actors.clear()
	if not is_instance_valid(m_variant_line):
		return

	for i in range(4):
		var actor := m_variant_line.get_node_or_null("SeedVariant%d" % (i + 1)) as HumanBody3D
		if actor != null:
			m_variant_actors.append(actor)


func _initialize_preview_actors() -> void:
	if is_instance_valid(m_primary_actor):
		m_primary_actor.use_character_model = true
		_apply_preview_state(m_primary_actor, STATE_ORDER[m_state_index])

	for i in range(m_variant_actors.size()):
		var actor := m_variant_actors[i]
		if not is_instance_valid(actor):
			continue
		actor.use_character_model = true
		actor.is_walking = true
		actor.is_running = false
		actor.direction = 90.0


func _apply_preview_state(actor: HumanBody3D, state_name: String) -> void:
	if not is_instance_valid(actor):
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
	for actor in m_variant_actors:
		_validate_preview_actor(failures, actor)
	if m_variant_actors.size() != 4:
		failures.append("low-poly character preview did not create every variant actor")

	if failures.is_empty():
		print("PASS: LowPolyCharacter3D model preview")
	else:
		for failure in failures:
			push_error(failure)


func _validate_preview_actor(failures: Array[String], actor: HumanBody3D) -> void:
	if not is_instance_valid(actor):
		failures.append("low-poly character preview is missing a HumanBody3D actor")
		return
	if not bool(actor.get("use_character_model")):
		failures.append("%s does not have character-model mode enabled" % actor.name)

	var visual_root := actor.get_node_or_null("VisualRoot") as Node3D
	if visual_root == null:
		failures.append("%s is missing VisualRoot" % actor.name)
		return

	var legacy_body := visual_root.get_node_or_null("Body") as MeshInstance3D
	if legacy_body != null and legacy_body.visible:
		failures.append("%s still shows the legacy block body" % actor.name)

	var rig := visual_root.get_node_or_null("ProceduralLowPolyCharacterRig") as Node3D
	if rig != null and rig.visible:
		failures.append("%s should hide the procedural rig in model mode" % actor.name)

	var model := visual_root.get_node_or_null("CharacterModel") as Node3D
	if model == null:
		failures.append("%s is missing the CharacterModel node" % actor.name)
		return
	if not model.visible:
		failures.append("%s character model is not visible" % actor.name)
	if model.get_child_count() == 0:
		failures.append("%s character model has no instanced scene" % actor.name)
		return

	var mesh_instance := _find_mesh_instance(model)
	if mesh_instance == null:
		failures.append("%s character model has no MeshInstance3D" % actor.name)
		return
	if mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() <= 0:
		failures.append("%s character model mesh is empty" % actor.name)
		return
	if mesh_instance.get_active_material(0) == null:
		failures.append("%s character model is missing its material" % actor.name)

	var model_height := float(actor.get("character_model_height"))
	if model_height <= 0.0:
		model_height = MODEL_NATIVE_HEIGHT
	var expected_scale := float(actor.get("body_height")) / model_height
	if absf(model.scale.y - expected_scale) > maxf(expected_scale * 0.05, 0.001):
		failures.append("%s character model is not scaled to body_height" % actor.name)


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _find_mesh_instance(child)
		if found != null:
			return found
	return null
