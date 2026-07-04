@tool
extends "res://addons/low_poly_building_editor/stairs_3d.gd"

@export_group("Layout")
@export_enum("Left", "Right") var turn_direction: int = TurnDirection.RIGHT:
	set(value):
		var clamped_value := clampi(value, TurnDirection.LEFT, TurnDirection.RIGHT)
		if turn_direction == clamped_value:
			return
		turn_direction = clamped_value
		_request_rebuild()

@export_range(0.2, 8.0, 0.01, "or_greater") var flight_width := 1.2:
	set(value):
		var clamped_value := maxf(value, 0.2)
		if is_equal_approx(flight_width, clamped_value):
			return
		flight_width = clamped_value
		_request_rebuild()


func configure_stair_layout(
	new_turn_direction: int,
	new_winder_turn: int,
	new_flight_width: float,
	new_spiral_turn_degrees: float
) -> void:
	turn_direction = new_turn_direction
	flight_width = new_flight_width
	_configure_specific_stair_layout(new_winder_turn, new_spiral_turn_degrees)


func _configure_specific_stair_layout(
	_winder_turn: int,
	_spiral_turn_degrees: float
) -> void:
	pass


func _layout_turn_direction() -> int:
	return turn_direction


func _layout_flight_width() -> float:
	return flight_width


func _layout_mesh_source_signature_values() -> Array:
	var values := super()
	values.append(turn_direction)
	values.append(flight_width)
	return values


func _clamped_layout_flight_width(
	width: float,
	depth: float,
	maximum_width: float
) -> float:
	return maxf(
		minf(maxf(flight_width, 0.2), minf(maximum_width, minf(width, depth))),
		0.05
	)


func _create_turning_plan_context(
	run_lengths: PackedFloat32Array,
	winder_treads: int
) -> Dictionary:
	var allocation := _allocate_layout_steps(run_lengths, winder_treads)
	var flight_steps: PackedInt32Array = allocation["flights"]
	var total_steps: int = allocation["total"]
	var rise := maxf(stair_height, 0.05) / float(maxi(total_steps, 1))
	var total_flight_run := 0.0
	var total_flight_steps := 0
	for index in range(run_lengths.size()):
		total_flight_run += run_lengths[index]
		total_flight_steps += flight_steps[index]
	return {
		"allocation": allocation,
		"flight_steps": flight_steps,
		"total_steps": total_steps,
		"rise": rise,
		"middle_shares": _distribute_middle_newels(flight_steps),
		"post_spacing": clampf(
			total_flight_run / float(maxi(total_flight_steps, 1)), 0.3, 2.0
		),
		"segments": [] as Array[Dictionary],
		"rail_runs": [] as Array[Dictionary],
	}


func _finish_turning_plan(
	context: Dictionary,
	width: float,
	effective_flight_width: float
) -> Dictionary:
	var plan := {
		"segments": context["segments"],
		"rail_runs": context["rail_runs"],
		"flight_width": effective_flight_width,
		"total_steps": context["total_steps"],
		"rise": context["rise"],
	}
	if turn_direction == TurnDirection.LEFT:
		_mirror_layout_plan(plan, width)
	return plan


func _total_rising_step_count() -> int:
	var size := get_stair_size()
	return int(_build_layout_plan(size.x, size.y)["total_steps"])


func _add_side_wall_collision_shapes(body: StaticBody3D) -> void:
	var size := get_stair_size()
	if size.x <= 0.001 or size.y <= 0.001:
		return
	_add_layout_side_wall_collision_shapes(body, size.x, size.y)
