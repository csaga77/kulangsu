@tool
extends Node3D

const LowPolyWorldCoordinates3DScript = preload("res://terrain/low_poly_world_coordinates_3d.gd")
const BaseController3DScript = preload("res://characters/control/base_controller_3d.gd")
const LowPolyArtStyle3DScript = preload("res://terrain/low_poly_art_style_3d.gd")

@onready var m_terrain: Node3D = $LowPolyTerrain3D
@onready var m_actor: CharacterBody3D = $human_body_3d
@onready var m_camera: Camera3D = $Camera3D
@onready var m_camera_controller: Node = $Camera3DController
@onready var m_sun: DirectionalLight3D = $Sun
@onready var m_landmark: Node3D = $PianoFerryProxy

@export var art_style: LowPolyArtStyle3DScript

var m_coordinates: LowPolyWorldCoordinates3DScript = LowPolyWorldCoordinates3DScript.new()
var m_spawn_mask_pixel := Vector2i.ZERO
var m_landmark_mask_pixel := Vector2i.ZERO


func _ready() -> void:
	_apply_art_style()
	if is_instance_valid(m_camera):
		m_camera.current = true

	if Engine.is_editor_hint():
		return

	call_deferred("_run_smoke_checks")


func _run_smoke_checks() -> void:
	var failures: Array[String] = []
	_configure_world(failures)
	_validate_world(failures)

	if failures.is_empty():
		print("PASS: LowPolyWorld3D smoke test")
	else:
		for failure in failures:
			push_error(failure)


func _configure_world(failures: Array[String]) -> void:
	if !is_instance_valid(m_terrain):
		failures.append("missing LowPolyTerrain3D")
		return
	if !is_instance_valid(m_actor):
		failures.append("missing HumanBody3D actor")
		return

	m_coordinates.configure_from_terrain(m_terrain)

	var profile := _resolve_generation_profile(failures)
	var image := _load_mask_image(failures)
	if profile == null or image == null:
		return

	m_spawn_mask_pixel = _find_land_spawn_pixel(image, profile)
	var sample_cell := m_coordinates.mask_pixel_to_sample_cell(m_spawn_mask_pixel)
	var land_height: float = float(m_terrain.get("land_height"))
	m_actor.global_position = m_coordinates.sample_cell_to_world_center(sample_cell, land_height + 0.04)
	m_landmark_mask_pixel = _find_nearest_land_pixel(image, profile, m_spawn_mask_pixel + Vector2i(-32, -24))
	_place_landmark(land_height)

	_snap_camera_controller()


func _validate_world(failures: Array[String]) -> void:
	if !is_instance_valid(m_terrain) or !is_instance_valid(m_actor):
		return

	if m_coordinates.resolve_source_size() == Vector2i.ZERO:
		failures.append("coordinate adapter did not resolve a source size")

	if m_terrain.get_node_or_null("LandMesh") == null:
		failures.append("LowPolyTerrain3D did not generate LandMesh")
	if m_terrain.get_node_or_null("TerrainCollision") == null:
		failures.append("LowPolyTerrain3D did not generate TerrainCollision")

	var controller: Variant = m_actor.get("controller")
	if controller == null:
		failures.append("HumanBody3D is missing PlayerController3D")
	elif !(controller is BaseController3DScript):
		failures.append("HumanBody3D controller does not extend BaseController3D")

	var sample_mask_pixel := Vector2(float(m_spawn_mask_pixel.x), float(m_spawn_mask_pixel.y))
	var sample_world := m_coordinates.mask_pixel_to_world_position(sample_mask_pixel, 0.0)
	var round_tripped_pixel := m_coordinates.world_position_to_mask_pixel(sample_world)
	if sample_mask_pixel.distance_to(round_tripped_pixel) > 0.001:
		failures.append("coordinate adapter mask/world round trip drifted")

	var flat_world := m_coordinates.world2d_to_world3d(sample_mask_pixel, 0.25)
	var flat_round_trip := m_coordinates.world3d_to_world2d(flat_world)
	if sample_mask_pixel.distance_to(flat_round_trip) > 0.001:
		failures.append("coordinate adapter 2D/3D round trip drifted")

	var actor_cell := m_coordinates.world_position_to_sample_cell(m_actor.global_position)
	if actor_cell != m_coordinates.mask_pixel_to_sample_cell(m_spawn_mask_pixel):
		failures.append("HumanBody3D did not spawn in the expected terrain sample cell")

	if !is_instance_valid(m_landmark):
		failures.append("missing PianoFerryProxy")
	elif m_landmark.get_node_or_null("BuildingBody") == null:
		failures.append("PianoFerryProxy did not generate postcard landmark body")

	var original_position := m_actor.global_position
	m_actor.move_with_speed(Vector3.RIGHT, 0.5)
	if m_actor.velocity.x <= 0.0:
		failures.append("HumanBody3D did not apply movement velocity in combined world scene")
	m_actor.global_position = original_position
	m_actor.move_with_speed(Vector3.ZERO, 0.0)

	if !is_instance_valid(m_camera):
		failures.append("missing Camera3D")
	elif m_camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
		failures.append("LowPolyWorld3D camera should be orthographic")

	if !is_instance_valid(m_camera_controller):
		failures.append("missing Camera3DController")
	else:
		if m_camera_controller.get("camera") != m_camera:
			failures.append("Camera3DController is not targeting Camera3D")
		if m_camera_controller.get("target_node") != m_actor:
			failures.append("Camera3DController is not following HumanBody3D")


func _apply_art_style() -> void:
	if art_style == null:
		return

	if is_instance_valid(m_camera):
		m_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		m_camera.size = art_style.camera_orthographic_size

	if is_instance_valid(m_camera_controller):
		m_camera_controller.set("follow_offset", art_style.camera_follow_offset)
		m_camera_controller.set("look_at_offset", art_style.camera_look_at_offset)
		m_camera_controller.set("orthographic_size", art_style.camera_orthographic_size)
		m_camera_controller.set("min_orthographic_size", art_style.min_camera_orthographic_size)
		m_camera_controller.set("max_orthographic_size", art_style.max_camera_orthographic_size)

	if is_instance_valid(m_sun):
		m_sun.global_position = art_style.sun_position
		m_sun.light_color = art_style.sun_color
		m_sun.light_energy = art_style.sun_energy
		m_sun.shadow_enabled = art_style.sun_shadows_enabled
		m_sun.look_at(art_style.sun_look_at, Vector3.UP)


func _place_landmark(land_height: float) -> void:
	if !is_instance_valid(m_landmark):
		return

	var landmark_cell := m_coordinates.mask_pixel_to_sample_cell(m_landmark_mask_pixel)
	m_landmark.global_position = m_coordinates.sample_cell_to_world_center(landmark_cell, land_height)


func _snap_camera_controller() -> void:
	if !is_instance_valid(m_camera_controller):
		return
	if m_camera_controller.has_method("snap_to_target"):
		m_camera_controller.call("snap_to_target")


func _resolve_generation_profile(failures: Array[String]) -> TerrainGenerationProfile:
	var terrain_profile: Variant = m_terrain.get("generation_profile")
	var profile := terrain_profile as TerrainGenerationProfile
	if profile == null:
		profile = TerrainGenerationProfile.create_default_profile()

	profile.ensure_defaults()
	if !profile.is_valid_profile():
		failures.append("terrain generation profile is invalid")
		return null
	return profile


func _load_mask_image(failures: Array[String]) -> Image:
	var mask_file_value: Variant = m_terrain.get("mask_file")
	var mask_file := String(mask_file_value)
	if mask_file.is_empty():
		failures.append("LowPolyTerrain3D is missing mask_file")
		return null

	var image := Image.new()
	var load_error := image.load(mask_file)
	if load_error != OK:
		failures.append("failed to load terrain mask: %s" % mask_file)
		return null

	if image.is_compressed():
		image.decompress()
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return image


func _find_land_spawn_pixel(image: Image, profile: TerrainGenerationProfile) -> Vector2i:
	var source_size := image.get_size()
	var center := Vector2i(source_size.x / 2, source_size.y / 2)
	var step: int = maxi(int(m_terrain.get("sample_stride")), 1)
	var max_radius := maxi(source_size.x, source_size.y)

	for radius in range(0, max_radius, step):
		var min_x: int = maxi(center.x - radius, 0)
		var max_x: int = mini(center.x + radius, source_size.x - 1)
		var min_y: int = maxi(center.y - radius, 0)
		var max_y: int = mini(center.y + radius, source_size.y - 1)

		for y in range(min_y, max_y + 1, step):
			for x in range(min_x, max_x + 1, step):
				var is_edge := x == min_x or x == max_x or y == min_y or y == max_y
				if !is_edge:
					continue
				var pixel := image.get_pixel(x, y)
				if !profile.is_water_pixel(pixel):
					return Vector2i(x, y)

	return center


func _find_nearest_land_pixel(image: Image, profile: TerrainGenerationProfile, target_pixel: Vector2i) -> Vector2i:
	var source_size := image.get_size()
	var clamped_target := Vector2i(
		clampi(target_pixel.x, 0, source_size.x - 1),
		clampi(target_pixel.y, 0, source_size.y - 1)
	)
	if !profile.is_water_pixel(image.get_pixel(clamped_target.x, clamped_target.y)):
		return clamped_target

	var step: int = maxi(int(m_terrain.get("sample_stride")), 1)
	var max_radius := maxi(source_size.x, source_size.y)
	for radius in range(step, max_radius, step):
		var min_x: int = maxi(clamped_target.x - radius, 0)
		var max_x: int = mini(clamped_target.x + radius, source_size.x - 1)
		var min_y: int = maxi(clamped_target.y - radius, 0)
		var max_y: int = mini(clamped_target.y + radius, source_size.y - 1)

		for y in range(min_y, max_y + 1, step):
			for x in range(min_x, max_x + 1, step):
				var is_edge := x == min_x or x == max_x or y == min_y or y == max_y
				if !is_edge:
					continue
				if !profile.is_water_pixel(image.get_pixel(x, y)):
					return Vector2i(x, y)

	return clamped_target
