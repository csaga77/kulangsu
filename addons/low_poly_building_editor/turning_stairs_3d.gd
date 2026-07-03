@tool
class_name TurningStairs3D
extends Stairs3D

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


func _total_rising_step_count() -> int:
	var size := get_stair_size()
	var allocation := _layout_step_allocation(size.x, size.y)
	return int(allocation["total"])


func _add_side_wall_collision_shapes(body: StaticBody3D) -> void:
	var size := get_stair_size()
	if size.x <= 0.001 or size.y <= 0.001:
		return
	_add_layout_side_wall_collision_shapes(body, size.x, size.y)
