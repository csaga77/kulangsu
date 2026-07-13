@tool
class_name CharacterPreview3D
extends Node3D

const HUMAN_BODY_SCENE: PackedScene = preload("res://characters/human_body_3d.tscn")
const MODEL_CATALOG := preload("res://characters/character_model_catalog_3d.gd")

var m_profile: Dictionary = {}
var m_actor: HumanBody3D = null


func _ready() -> void:
	_build_preview_world()
	_apply_profile()


func set_profile(profile: Dictionary) -> void:
	m_profile = profile.duplicate(true)
	_apply_profile()


func get_actor() -> HumanBody3D:
	return m_actor


func _build_preview_world() -> void:
	if get_node_or_null("Actor") != null:
		m_actor = get_node("Actor") as HumanBody3D
		return

	var environment_node := WorldEnvironment.new()
	environment_node.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.0, 0.0, 0.0, 0.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.82, 0.88, 0.92, 1.0)
	environment.ambient_light_energy = 1.1
	environment_node.environment = environment
	add_child(environment_node)

	var key_light := DirectionalLight3D.new()
	key_light.name = "KeyLight"
	key_light.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	key_light.light_color = Color(1.0, 0.88, 0.72, 1.0)
	key_light.light_energy = 1.7
	add_child(key_light)

	var fill_light := DirectionalLight3D.new()
	fill_light.name = "FillLight"
	fill_light.rotation_degrees = Vector3(-28.0, 145.0, 0.0)
	fill_light.light_color = Color(0.58, 0.72, 1.0, 1.0)
	fill_light.light_energy = 0.65
	add_child(fill_light)

	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.position = Vector3(2.6, 1.65, 4.2)
	camera.fov = 28.0
	camera.current = true
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.92, 0.0), Vector3.UP)

	m_actor = HUMAN_BODY_SCENE.instantiate() as HumanBody3D
	if m_actor == null:
		return
	m_actor.name = "Actor"
	m_actor.controller = null
	m_actor.draw_bounding_box = false
	m_actor.draw_skeleton_bones = false
	add_child(m_actor)
	m_actor.set_process(false)
	m_actor.set_physics_process(false)


func _apply_profile() -> void:
	if not is_instance_valid(m_actor):
		return
	m_actor.character_model_scene = MODEL_CATALOG.resolve_player_model(m_profile)
	m_actor.direction = 90.0
	m_actor.is_walking = false
	m_actor.is_running = false
