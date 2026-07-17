class_name ActorSurfaceFollower
extends Node

## Seats one runtime actor on the solid world surface beneath it. The component
## owns grounding and shallow-water policy; the world scene owns its lifecycle
## and supplies the actor, terrain, and coordinate adapter explicitly.

@export_range(0.0, 1.0, 0.01) var terrain_clearance := 0.0
@export_range(0.0, 5.0, 0.05) var ground_probe_up := 0.72
@export_range(0.0, 10.0, 0.05) var ground_probe_down := 2.5
@export_range(0.0, 2.0, 0.05) var max_wade_depth := 0.5

var m_actor: CharacterBody3D = null
var m_terrain: LowPolyTerrain3D = null
var m_coordinates: LowPolyWorldCoordinates3D = null


func _ready() -> void:
	set_physics_process(is_configured())


func configure(
	actor: CharacterBody3D,
	terrain: LowPolyTerrain3D,
	coordinates: LowPolyWorldCoordinates3D
) -> void:
	_disconnect_actor()
	m_actor = actor
	m_terrain = terrain
	m_coordinates = coordinates
	_connect_actor()
	set_physics_process(is_configured())


func _exit_tree() -> void:
	_disconnect_actor()


func _physics_process(_delta: float) -> void:
	settle_now()


func is_configured() -> bool:
	return (
		is_instance_valid(m_actor)
		and is_instance_valid(m_terrain)
		and m_coordinates != null
	)


func settle_now() -> void:
	if !is_configured():
		return
	if m_coordinates.resolve_source_size() == Vector2i.ZERO:
		return

	var ground_height := _resolve_surface_height()
	if is_nan(ground_height):
		return
	var actor_position := m_actor.global_position
	var target_y := ground_height + terrain_clearance
	if is_equal_approx(actor_position.y, target_y):
		return
	actor_position.y = target_y
	m_actor.global_position = actor_position


func _connect_actor() -> void:
	if !is_instance_valid(m_actor) or !m_actor.has_signal("global_position_changed"):
		return
	var callback := Callable(self, "_on_actor_global_position_changed")
	if !m_actor.is_connected("global_position_changed", callback):
		m_actor.connect("global_position_changed", callback)


func _disconnect_actor() -> void:
	if !is_instance_valid(m_actor) or !m_actor.has_signal("global_position_changed"):
		return
	var callback := Callable(self, "_on_actor_global_position_changed")
	if m_actor.is_connected("global_position_changed", callback):
		m_actor.disconnect("global_position_changed", callback)


func _on_actor_global_position_changed() -> void:
	settle_now()


func _resolve_surface_height() -> float:
	if Engine.is_in_physics_frame():
		var world := m_actor.get_world_3d()
		if world != null:
			var space_state := world.direct_space_state
			if space_state != null:
				var origin := m_actor.global_position
				var query := PhysicsRayQueryParameters3D.create(
					origin + Vector3.UP * ground_probe_up,
					origin + Vector3.DOWN * ground_probe_down
				)
				query.collision_mask = m_actor.collision_mask
				query.collide_with_areas = false
				query.exclude = [m_actor.get_rid()]
				var hit := space_state.intersect_ray(query)
				if !hit.is_empty():
					return float((hit["position"] as Vector3).y)
	return _resolve_terrain_height()


func _resolve_terrain_height() -> float:
	if !is_configured():
		return NAN
	var sample_cell := m_coordinates.world_position_to_sample_cell(m_actor.global_position)
	var seabed_height := m_terrain.get_world_surface_height(m_actor.global_position)
	if !is_finite(seabed_height):
		seabed_height = m_terrain.get_sample_cell_height(sample_cell)
	var water_surface := m_terrain.get_world_water_surface_height(m_actor.global_position)
	return maxf(seabed_height, water_surface - max_wade_depth)
