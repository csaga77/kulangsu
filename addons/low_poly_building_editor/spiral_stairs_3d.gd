@tool
class_name SpiralStairs3D
extends "res://addons/low_poly_building_editor/turning_stairs_3d.gd"

@export_range(45.0, 1080.0, 1.0) var spiral_turn_degrees := 360.0:
	set(value):
		var clamped_value := clampf(value, 45.0, 1080.0)
		if is_equal_approx(spiral_turn_degrees, clamped_value):
			return
		spiral_turn_degrees = clamped_value
		_request_rebuild()


func _append_stair_layout_geometry(
	width: float,
	depth: float,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	_append_layout_geometry(
		_build_layout_plan(width, depth), vertices, normals, colors, indices
	)


func _build_layout_plan(width: float, depth: float) -> Dictionary:
	var fw := _clamped_layout_flight_width(
		width, depth, minf(width, depth) * 0.5 - 0.05
	)
	var outer_radius := minf(width, depth) * 0.5
	var inner_radius := clampf(outer_radius - fw, 0.05, outer_radius - 0.05)
	var minimum_steps := ceili(
		spiral_turn_degrees / SPIRAL_MAX_TREAD_ANGLE_DEGREES
	)
	var steps := maxi(_effective_step_count(), minimum_steps)
	var rise := maxf(stair_height, 0.05) / float(maxi(steps, 1))
	var margin := minf(rail_edge_margin, fw * 0.45)
	var turn_radians := deg_to_rad(spiral_turn_degrees)
	var center := Vector2(width * 0.5, depth * 0.5)
	var segments: Array[Dictionary] = [{
		"kind": SegmentKind.SEGMENT_SPIRAL,
		"origin": Vector3.ZERO,
		"run_axis": Vector3.BACK,
		"width_axis": Vector3.UP.cross(Vector3.BACK).normalized(),
		"width": width,
		"run": depth,
		"steps": steps,
		"rise": rise,
		"center": center,
		"outer_radius": outer_radius,
		"inner_radius": inner_radius,
		"turn_radians": turn_radians,
		"turn_sign": 1.0,
	}]
	var rail_radius := maxf(outer_radius - margin, inner_radius + 0.02)
	var rail_length := rail_radius * turn_radians
	var spiral_rail := {
		"side": RAIL_SIDE_LEFT,
		"center": center,
		"radius": rail_radius,
		"turn_radians": turn_radians,
		"turn_sign": 1.0,
		"length": rail_length,
		"rise": maxf(stair_height, 0.05),
		"steps": steps,
		"post_layout": _build_rail_post_layout(
			rail_length,
			maxf(stair_height, 0.05),
			steps,
			lower_newel_enabled,
			upper_newel_enabled,
			middle_newel_post_count,
			lower_newel_placement,
			upper_newel_placement
		),
	}
	var plan := {
		"segments": segments,
		"rail_runs": [] as Array[Dictionary],
		"spiral_rail": spiral_rail,
		"flight_width": fw,
		"total_steps": steps,
		"rise": rise,
	}
	if turn_direction == TurnDirection.LEFT:
		_mirror_layout_plan(plan, width)
	return plan


func _configure_specific_stair_layout(
	_winder_turn: int,
	new_spiral_turn_degrees: float
) -> void:
	spiral_turn_degrees = new_spiral_turn_degrees


func _layout_spiral_turn_degrees() -> float:
	return spiral_turn_degrees


func _layout_mesh_source_signature_values() -> Array:
	var values := super()
	values.append(spiral_turn_degrees)
	return values


func _validate_property(property: Dictionary) -> void:
	var property_name := StringName(property.get("name", &""))
	if property_name == &"tread_style":
		property["hint"] = PROPERTY_HINT_ENUM
		property["hint_string"] = "Closed,Open"
	elif property_name == &"nosing_depth":
		property["usage"] = int(property.get("usage", 0)) & ~PROPERTY_USAGE_EDITOR
