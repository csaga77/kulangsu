class_name CarryPlacementTarget3D
extends Node3D

## Authored socket for one deterministic carry placement. The active carryable
## discovers these nodes directly, so placement targets never compete with normal
## contextual targets while the actor is free.

const PLACEMENT_TARGET_GROUP := &"carry_placement_target_3d"
const DEFAULT_MINIMUM_FORWARD_REACH := 0.65
const DEFAULT_MAXIMUM_FORWARD_REACH := 1.35
const DEFAULT_MAXIMUM_VERTICAL_DELTA := 0.60
const DEFAULT_MAXIMUM_LATERAL_OFFSET := 0.60

@export var placement_id: StringName = &""
@export var placement_label := "Place"
@export_range(-100, 100, 1) var placement_priority := 0
@export var accepted_action_ids: Array[StringName] = []
@export var placement_enabled := true
@export var placement_anchor_path: NodePath
@export_range(0.0, 2.0, 0.01) var minimum_forward_reach := (
	DEFAULT_MINIMUM_FORWARD_REACH
)
@export_range(0.0, 3.0, 0.01) var maximum_forward_reach := (
	DEFAULT_MAXIMUM_FORWARD_REACH
)
@export_range(0.0, 2.0, 0.01) var maximum_vertical_delta := (
	DEFAULT_MAXIMUM_VERTICAL_DELTA
)
@export_range(0.0, 2.0, 0.01) var maximum_lateral_offset := (
	DEFAULT_MAXIMUM_LATERAL_OFFSET
)
@export var require_support := true

## Deterministic authoring probes. Negative support values ask the carryable to
## derive support from physics rays; non-negative values are useful for generated
## fixtures whose precise support fraction is part of the acceptance boundary.
@export_group("Authored Validation")
@export_range(0.0, 1.0, 0.01) var authored_position_error := 0.0
@export_range(0.0, 180.0, 0.1) var authored_yaw_error_degrees := 0.0
@export_range(-1.0, 1.0, 0.01) var authored_support_coverage := -1.0
@export_range(-1.0, 90.0, 0.1) var authored_support_slope_degrees := -1.0


func _enter_tree() -> void:
	add_to_group(PLACEMENT_TARGET_GROUP)


func _exit_tree() -> void:
	remove_from_group(PLACEMENT_TARGET_GROUP)


func get_placement_transform() -> Transform3D:
	if !placement_anchor_path.is_empty():
		var authored_anchor := get_node_or_null(placement_anchor_path) as Node3D
		if is_instance_valid(authored_anchor):
			return authored_anchor.global_transform
	return global_transform


func get_placement_label() -> String:
	return placement_label.strip_edges()


func get_placement_priority() -> int:
	return placement_priority


func accepts_action(action_id: StringName) -> bool:
	return (
		accepted_action_ids.is_empty()
		or accepted_action_ids.has(action_id)
	)


func is_reachable(
	actor: CharacterBody3D,
	socket_transform: Transform3D
) -> bool:
	if !placement_enabled or !is_instance_valid(actor):
		return false
	var actor_forward := _resolve_actor_forward(actor)
	var to_anchor := get_placement_transform().origin - actor.global_position
	var flat_delta := Vector3(to_anchor.x, 0.0, to_anchor.z)
	var forward_distance := flat_delta.dot(actor_forward)
	var lateral_delta := flat_delta - actor_forward * forward_distance
	if (
		forward_distance + 0.00001 < minimum_forward_reach
		or forward_distance - 0.00001 > maximum_forward_reach
		or lateral_delta.length() - 0.00001 > maximum_lateral_offset
	):
		return false
	return (
		absf(get_placement_transform().origin.y - socket_transform.origin.y)
		<= maximum_vertical_delta + 0.00001
	)


func has_accepted_authored_tolerances() -> bool:
	if authored_position_error > 0.10 + 0.00001:
		return false
	if authored_yaw_error_degrees > 10.0 + 0.00001:
		return false
	if (
		authored_support_slope_degrees >= 0.0
		and authored_support_slope_degrees > 10.0 + 0.00001
	):
		return false
	if (
		authored_support_coverage >= 0.0
		and authored_support_coverage + 0.00001 < 0.80
	):
		return false
	return true


func _resolve_actor_forward(actor: CharacterBody3D) -> Vector3:
	if actor.has_method("get_direction_vector"):
		var direction_value: Variant = actor.call("get_direction_vector")
		if direction_value is Vector3:
			var authored_direction := direction_value as Vector3
			authored_direction.y = 0.0
			if authored_direction.length_squared() > 0.000001:
				return authored_direction.normalized()
	var fallback := actor.global_basis.z
	fallback.y = 0.0
	if fallback.length_squared() <= 0.000001:
		return Vector3.FORWARD
	return fallback.normalized()
