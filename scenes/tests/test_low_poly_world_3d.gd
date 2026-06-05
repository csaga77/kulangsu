@tool
extends Node3D

const LowPolyWorldCoordinates3DScript = preload("res://terrain/low_poly_world_coordinates_3d.gd")
const BaseController3DScript = preload("res://characters/control/base_controller_3d.gd")
const LowPolyArtStyle3DScript = preload("res://terrain/low_poly_art_style_3d.gd")
const LowPolyLandmarkProxy3DScript = preload("res://architecture/low_poly/low_poly_landmark_proxy_3d.gd")
const LANDMARK_MASK_META := &"low_poly_landmark_mask_pixel"
const TERRAIN_KIND_WATER := 0
const LANDMARK_PLACEMENTS := [
	{
		"path": "Landmarks/PianoFerryProxy",
		"isometric_position": Vector2(5248.0, 9376.0),
	},
	{
		"path": "Landmarks/TrinityChurchProxy",
		"isometric_position": Vector2(-1120.0, 7888.0),
	},
	{
		"path": "Landmarks/BiShanTunnelProxy",
		"isometric_position": Vector2(-992.0, 7824.0),
	},
	{
		"path": "Landmarks/LongShanTunnelProxy",
		"isometric_position": Vector2(3360.0, 7536.0),
	},
	{
		"path": "Landmarks/BaguaTowerProxy",
		"isometric_position": Vector2(3360.0, 6160.0),
	},
]

@onready var m_terrain: Node3D = $LowPolyTerrain3D
@onready var m_actor: CharacterBody3D = $human_body_3d
@onready var m_camera: Camera3D = $Camera3D
@onready var m_camera_controller: Node = $Camera3DController
@onready var m_sun: DirectionalLight3D = $Sun
@onready var m_landmarks_root: Node3D = $Landmarks

@export var art_style: LowPolyArtStyle3DScript
@export_range(0.0, 1.0, 0.01) var actor_terrain_clearance := 0.04

var m_coordinates: LowPolyWorldCoordinates3DScript = LowPolyWorldCoordinates3DScript.new()
var m_spawn_mask_pixel := Vector2i.ZERO


func _ready() -> void:
	_apply_art_style()
	if is_instance_valid(m_camera):
		m_camera.current = true

	if Engine.is_editor_hint():
		return

	_connect_actor_terrain_elevation()
	call_deferred("_run_smoke_checks")


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_apply_actor_terrain_elevation()


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
	var fallback_land_height: float = float(m_terrain.get("land_height"))
	var spawn_height := _get_terrain_sample_height(sample_cell, fallback_land_height)
	m_actor.global_position = m_coordinates.sample_cell_to_world_center(sample_cell, spawn_height + actor_terrain_clearance)
	_place_landmarks(image, profile, fallback_land_height)
	_apply_actor_terrain_elevation()

	_snap_camera_controller()


func _validate_world(failures: Array[String]) -> void:
	if !is_instance_valid(m_terrain) or !is_instance_valid(m_actor):
		return

	if m_coordinates.resolve_source_size() == Vector2i.ZERO:
		failures.append("coordinate adapter did not resolve a source size")
	elif m_terrain.has_method("get_source_size"):
		var terrain_source_size := Vector2i(m_terrain.call("get_source_size"))
		if terrain_source_size != Vector2i.ZERO and m_coordinates.resolve_source_size() != terrain_source_size:
			failures.append("coordinate adapter did not follow LowPolyTerrain3D source size")

	if m_terrain.get_node_or_null("LandMesh") == null:
		failures.append("LowPolyTerrain3D did not generate LandMesh")
	if m_terrain.get_node_or_null("WaterMesh") == null:
		var water_context := "heightmap-level" if _terrain_expands_heightmap_land() else "mask-clipped"
		failures.append("LowPolyTerrain3D did not generate %s WaterMesh" % water_context)
	if m_terrain.get_node_or_null("WaterSurfaceLayerMesh") == null:
		failures.append("LowPolyTerrain3D did not generate WaterSurfaceLayerMesh")
	if m_terrain.get_node_or_null("WaterShorelineMesh") == null:
		failures.append("LowPolyTerrain3D did not generate WaterShorelineMesh")
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

	var isometric_probe := Vector2(3360.0, 6160.0)
	var isometric_mask_pixel := m_coordinates.isometric_position_to_mask_pixel(isometric_probe)
	var isometric_round_trip := m_coordinates.mask_pixel_to_isometric_position(isometric_mask_pixel)
	if isometric_probe.distance_to(isometric_round_trip) > 0.001:
		failures.append("coordinate adapter isometric/mask round trip drifted")

	var actor_cell := m_coordinates.world_position_to_sample_cell(m_actor.global_position)
	if actor_cell != m_coordinates.mask_pixel_to_sample_cell(m_spawn_mask_pixel):
		failures.append("HumanBody3D did not spawn in the expected terrain sample cell")
	_validate_actor_terrain_elevation(failures)
	_validate_actor_water_cell_terrain_elevation(failures)

	if float(m_actor.get("body_height")) <= 0.0:
		failures.append("HumanBody3D body height tuning is invalid")
	if float(m_actor.get("body_radius")) <= 0.0:
		failures.append("HumanBody3D body radius tuning is invalid")
	if m_actor.get_node_or_null("ContactShadow") == null:
		failures.append("HumanBody3D did not create a contact shadow")
	if m_actor.get_node_or_null("VisualRoot/DirectionMarker") == null:
		failures.append("HumanBody3D did not create a direction marker")

	_validate_landmark_proxies(failures)

	var original_position := m_actor.global_position
	m_actor.move_with_speed(Vector3.RIGHT, 0.5)
	if m_actor.velocity.x <= 0.0:
		failures.append("HumanBody3D did not apply movement velocity in combined world scene")
	m_actor.global_position = original_position
	m_actor.move_with_speed(Vector3.ZERO, 0.0)
	_apply_actor_terrain_elevation()

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
		_validate_camera_rotation(failures)


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


func _place_landmarks(image: Image, profile: TerrainGenerationProfile, land_height: float) -> void:
	if !is_instance_valid(m_landmarks_root):
		return

	for placement: Dictionary in LANDMARK_PLACEMENTS:
		var proxy := get_node_or_null(String(placement["path"])) as Node3D
		if !is_instance_valid(proxy):
			continue

		var isometric_position := placement["isometric_position"] as Vector2
		var mask_pixel := m_coordinates.isometric_position_to_mask_pixel(isometric_position)
		var snapped_mask_pixel := _find_nearest_land_pixel(
			image,
			profile,
			Vector2i(roundi(mask_pixel.x), roundi(mask_pixel.y))
		)
		var landmark_cell := m_coordinates.mask_pixel_to_sample_cell(snapped_mask_pixel)
		var landmark_height := _get_terrain_sample_height(landmark_cell, land_height)
		proxy.global_position = m_coordinates.sample_cell_to_world_center(landmark_cell, landmark_height)
		proxy.set_meta(LANDMARK_MASK_META, snapped_mask_pixel)


func _validate_landmark_proxies(failures: Array[String]) -> void:
	if !is_instance_valid(m_landmarks_root):
		failures.append("missing low-poly landmark root")
		return

	var seen_landmark_ids: Dictionary = {}
	for placement: Dictionary in LANDMARK_PLACEMENTS:
		var proxy_name := String(placement["path"]).get_file()
		var proxy := get_node_or_null(String(placement["path"])) as Node3D
		if !is_instance_valid(proxy):
			failures.append("missing %s" % proxy_name)
			continue

		if !(proxy is LowPolyLandmarkProxy3DScript):
			failures.append("%s does not use LowPolyLandmarkProxy3D" % proxy_name)

		var landmark_id := String(proxy.get("landmark_id"))
		if landmark_id.is_empty():
			failures.append("%s is missing landmark_id" % proxy_name)
		elif seen_landmark_ids.has(landmark_id):
			failures.append("duplicate low-poly landmark_id: %s" % landmark_id)
		else:
			seen_landmark_ids[landmark_id] = true

		if proxy.get_node_or_null("BuildingBody") == null:
			failures.append("%s did not generate landmark body" % proxy_name)

		if !proxy.has_meta(LANDMARK_MASK_META):
			failures.append("%s was not placed through LowPolyWorldCoordinates3D" % proxy_name)
			continue

		var mask_pixel_value: Variant = proxy.get_meta(LANDMARK_MASK_META)
		if !(mask_pixel_value is Vector2i):
			failures.append("%s stored an invalid landmark mask pixel" % proxy_name)
			continue

		var mask_pixel := Vector2i(mask_pixel_value)
		if !m_coordinates.is_mask_pixel_inside(Vector2(float(mask_pixel.x), float(mask_pixel.y))):
			failures.append("%s placed outside the terrain mask" % proxy_name)


func _snap_camera_controller() -> void:
	if !is_instance_valid(m_camera_controller):
		return
	if m_camera_controller.has_method("snap_to_target"):
		m_camera_controller.call("snap_to_target")


func _connect_actor_terrain_elevation() -> void:
	if !is_instance_valid(m_actor):
		return
	if !m_actor.has_signal("global_position_changed"):
		return
	var callback := Callable(self, "_on_actor_global_position_changed")
	if m_actor.is_connected("global_position_changed", callback):
		return
	m_actor.connect("global_position_changed", callback)


func _on_actor_global_position_changed() -> void:
	_apply_actor_terrain_elevation()


func _apply_actor_terrain_elevation() -> void:
	if !is_instance_valid(m_actor) or !is_instance_valid(m_terrain):
		return
	if m_coordinates.resolve_source_size() == Vector2i.ZERO:
		return

	var sample_cell := m_coordinates.world_position_to_sample_cell(m_actor.global_position)
	var fallback_land_height: float = float(m_terrain.get("land_height"))
	var terrain_height := _get_terrain_world_height(m_actor.global_position, sample_cell, fallback_land_height)
	var position := m_actor.global_position
	var target_y := terrain_height + actor_terrain_clearance
	if is_equal_approx(position.y, target_y):
		return
	position.y = target_y
	m_actor.global_position = position


func _validate_actor_terrain_elevation(failures: Array[String]) -> void:
	var original_position := m_actor.global_position
	var probe_cell := _find_terrain_height_probe_cell()
	var fallback_land_height: float = float(m_terrain.get("land_height"))
	var probe_position := m_coordinates.sample_cell_to_world_center(probe_cell, -3.0) + Vector3(0.21, 0.0, -0.17)
	var expected_height := _get_terrain_world_height(probe_position, probe_cell, fallback_land_height) + actor_terrain_clearance
	m_actor.global_position = probe_position
	_apply_actor_terrain_elevation()
	if !is_equal_approx(m_actor.global_position.y, expected_height):
		failures.append("HumanBody3D did not follow LowPolyTerrain3D elevation")
	m_actor.global_position = original_position


func _validate_actor_water_cell_terrain_elevation(failures: Array[String]) -> void:
	if !_terrain_expands_heightmap_land():
		return
	if !m_terrain.has_method("get_sample_cell_kind"):
		return

	var water_cell := _find_heightmap_water_probe_cell()
	if water_cell == Vector2i(-1, -1):
		failures.append("LowPolyWorld3D could not find a heightmap water cell with land elevation")
		return

	var fallback_land_height: float = float(m_terrain.get("land_height"))
	var water_height: float = float(m_terrain.get("water_height"))
	var terrain_height := _get_terrain_sample_height(water_cell, fallback_land_height)
	if terrain_height >= water_height - 0.005:
		failures.append("LowPolyTerrain3D water cells did not expose land elevation for actor placement")
		return

	var original_position := m_actor.global_position
	var probe_position := m_coordinates.sample_cell_to_world_center(water_cell, -3.0)
	var expected_height := _get_terrain_world_height(probe_position, water_cell, fallback_land_height) + actor_terrain_clearance
	if expected_height >= water_height + actor_terrain_clearance - 0.005:
		failures.append("HumanBody3D water-cell terrain target used water height instead of land elevation")
		m_actor.global_position = original_position
		return

	m_actor.global_position = probe_position
	_apply_actor_terrain_elevation()
	if !is_equal_approx(m_actor.global_position.y, expected_height):
		failures.append("HumanBody3D did not follow land elevation in heightmap water")
	m_actor.global_position = original_position


func _find_heightmap_water_probe_cell() -> Vector2i:
	var grid_size := m_coordinates.get_grid_size()
	if grid_size == Vector2i.ZERO:
		return Vector2i(-1, -1)

	var fallback_land_height: float = float(m_terrain.get("land_height"))
	var water_height: float = float(m_terrain.get("water_height"))
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var sample_cell := Vector2i(x, y)
			if int(m_terrain.call("get_sample_cell_kind", sample_cell)) != TERRAIN_KIND_WATER:
				continue
			var terrain_height := _get_terrain_sample_height(sample_cell, fallback_land_height)
			if terrain_height < water_height - 0.02:
				return sample_cell
	return Vector2i(-1, -1)


func _find_terrain_height_probe_cell() -> Vector2i:
	var grid_size := m_coordinates.get_grid_size()
	if grid_size == Vector2i.ZERO:
		return Vector2i.ZERO

	var fallback_land_height: float = float(m_terrain.get("land_height"))
	var origin_cell := m_coordinates.world_position_to_sample_cell(m_actor.global_position)
	var origin_height := _get_terrain_sample_height(origin_cell, fallback_land_height)
	var probe_cells: Array[Vector2i] = [
		origin_cell,
		Vector2i(grid_size.x - 1, grid_size.y - 1),
		Vector2i(grid_size.x / 2, grid_size.y / 2),
		Vector2i(grid_size.x - 1, 0),
		Vector2i(0, grid_size.y - 1),
	]
	for probe_cell in probe_cells:
		var clamped_cell := Vector2i(
			clampi(probe_cell.x, 0, grid_size.x - 1),
			clampi(probe_cell.y, 0, grid_size.y - 1)
		)
		var probe_height := _get_terrain_sample_height(clamped_cell, fallback_land_height)
		if absf(probe_height - origin_height) > 0.05:
			return clamped_cell
	return origin_cell


func _validate_camera_rotation(failures: Array[String]) -> void:
	if !m_camera_controller.has_method("rotate_yaw"):
		failures.append("Camera3DController is missing orbit rotation support")
		return

	var original_yaw := float(m_camera_controller.get("orbit_yaw_degrees"))
	m_camera_controller.call("rotate_yaw", 12.0)
	var rotated_yaw := float(m_camera_controller.get("orbit_yaw_degrees"))
	if !is_equal_approx(rotated_yaw, wrapf(original_yaw + 12.0, -180.0, 180.0)):
		failures.append("Camera3DController did not apply orbit yaw rotation")
	m_camera_controller.set("orbit_yaw_degrees", original_yaw)


func _get_terrain_sample_height(sample_cell: Vector2i, fallback: float) -> float:
	if !is_instance_valid(m_terrain):
		return fallback
	if !m_terrain.has_method("get_sample_cell_height"):
		return fallback
	return float(m_terrain.call("get_sample_cell_height", sample_cell))


func _get_terrain_world_height(world_position: Vector3, sample_cell: Vector2i, fallback: float) -> float:
	if !is_instance_valid(m_terrain):
		return fallback
	if m_terrain.has_method("get_world_surface_height"):
		return float(m_terrain.call("get_world_surface_height", world_position))
	return _get_terrain_sample_height(sample_cell, fallback)


func _terrain_expands_heightmap_land() -> bool:
	if !is_instance_valid(m_terrain):
		return false
	var heightmap_file_value: Variant = m_terrain.get("heightmap_file")
	var heightmap_file := String(heightmap_file_value)
	return bool(m_terrain.get("heightmap_expands_land_to_source")) and !heightmap_file.is_empty()


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
