@tool
class_name WinderStairs3D
extends "res://addons/low_poly_building_editor/turning_stairs_3d.gd"

@export_enum("90 Degrees", "180 Degrees") var winder_turn: int = WinderTurn.TURN_90:
	set(value):
		var clamped_value := clampi(value, WinderTurn.TURN_90, WinderTurn.TURN_180)
		if winder_turn == clamped_value:
			return
		winder_turn = clamped_value
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
	if winder_turn == WinderTurn.TURN_180:
		return _build_180_degree_winder_plan(width, depth)
	return _build_90_degree_winder_plan(width, depth)


func _build_90_degree_winder_plan(width: float, depth: float) -> Dictionary:
	var fw := _clamped_layout_flight_width(
		width, depth, minf(width, depth) * 0.5
	)
	var r1 := depth - fw
	var r2 := width - fw
	var context := _create_turning_plan_context(
		PackedFloat32Array([r1, r2]), WINDER_TREADS_90
	)
	var flight_steps: PackedInt32Array = context["flight_steps"]
	var rise: float = context["rise"]
	var middle_shares: PackedInt32Array = context["middle_shares"]
	var post_spacing: float = context["post_spacing"]
	var segments: Array[Dictionary] = context["segments"]
	var rail_runs: Array[Dictionary] = context["rail_runs"]
	var margin := minf(rail_edge_margin, fw * 0.45)
	var n1 := flight_steps[0]
	var n2 := flight_steps[1]
	var h1 := rise * float(n1)
	var hw := rise * float(WINDER_TREADS_90)
	var turn_height := h1 + hw
	var no_extra_walls: Array[Dictionary] = []

	segments.append(_make_flight_segment(
		Vector3.ZERO, Vector3.BACK, fw, r1, n1, rise
	))
	segments.append(_make_winder_segment(
		Vector3(0.0, h1, r1), Vector3.BACK, fw, fw,
		WINDER_TREADS_90, rise,
		Vector2(fw, 0.0),
		PackedVector2Array([
			Vector2(0.0, 0.0),
			Vector2(0.0, fw),
			Vector2(fw, fw),
		]),
		no_extra_walls
	))
	segments.append(_make_flight_segment(
		Vector3(fw, turn_height, depth), Vector3.RIGHT, fw, r2, n2, rise
	))
	rail_runs.append(_make_flight_rail_run(
		RAIL_SIDE_LEFT, Vector3(margin, 0.0, 0.0), Vector3.BACK,
		r1, h1, n1, true, false, middle_shares[0]
	))
	rail_runs.append(_make_flight_rail_run(
		RAIL_SIDE_RIGHT, Vector3(fw - margin, 0.0, 0.0), Vector3.BACK,
		r1, h1, n1, true, false, middle_shares[0]
	))
	_add_raked_path_rail_runs(
		rail_runs, RAIL_SIDE_LEFT,
		[
			Vector2(margin, r1),
			Vector2(margin, depth - margin),
			Vector2(fw, depth - margin),
		],
		h1, hw, WINDER_TREADS_90, rise, post_spacing
	)
	rail_runs.append(_make_flight_rail_run(
		RAIL_SIDE_LEFT, Vector3(fw, turn_height, depth - margin), Vector3.RIGHT,
		r2, rise * float(n2), n2, false, true, middle_shares[1]
	))
	_add_raked_path_rail_runs(
		rail_runs, RAIL_SIDE_RIGHT,
		[
			Vector2(fw - margin, r1),
			Vector2(fw - margin, r1 + margin),
			Vector2(fw, r1 + margin),
		],
		h1, hw, 0, rise, post_spacing
	)
	rail_runs.append(_make_flight_rail_run(
		RAIL_SIDE_RIGHT, Vector3(fw, turn_height, r1 + margin), Vector3.RIGHT,
		r2, rise * float(n2), n2, false, true, middle_shares[1]
	))
	return _finish_turning_plan(context, width, fw)


func _build_180_degree_winder_plan(width: float, depth: float) -> Dictionary:
	var fw := _clamped_layout_flight_width(
		width, depth, minf(width * 0.5, depth * 0.5)
	)
	var r1 := depth - fw
	var context := _create_turning_plan_context(
		PackedFloat32Array([r1, r1]), WINDER_TREADS_180
	)
	var flight_steps: PackedInt32Array = context["flight_steps"]
	var rise: float = context["rise"]
	var middle_shares: PackedInt32Array = context["middle_shares"]
	var post_spacing: float = context["post_spacing"]
	var segments: Array[Dictionary] = context["segments"]
	var rail_runs: Array[Dictionary] = context["rail_runs"]
	var margin := minf(rail_edge_margin, fw * 0.45)
	var n1 := flight_steps[0]
	var n2 := flight_steps[1]
	var h1 := rise * float(n1)
	var hw := rise * float(WINDER_TREADS_180)
	var turn_height := h1 + hw
	var extra_walls: Array[Dictionary] = [
		{
			"a": Vector2(fw, 0.0),
			"b": Vector2(width * 0.5, 0.0),
			"top": 0.0,
			"normal": Vector2(0.0, -1.0),
		},
		{
			"a": Vector2(width * 0.5, 0.0),
			"b": Vector2(width - fw, 0.0),
			"top": hw,
			"normal": Vector2(0.0, -1.0),
		},
	]

	segments.append(_make_flight_segment(
		Vector3.ZERO, Vector3.BACK, fw, r1, n1, rise
	))
	segments.append(_make_winder_segment(
		Vector3(0.0, h1, r1), Vector3.BACK, width, fw,
		WINDER_TREADS_180, rise,
		Vector2(width * 0.5, 0.0),
		PackedVector2Array([
			Vector2(0.0, 0.0),
			Vector2(0.0, fw),
			Vector2(width, fw),
			Vector2(width, 0.0),
		]),
		extra_walls
	))
	segments.append(_make_flight_segment(
		Vector3(width, turn_height, r1), Vector3.FORWARD, fw, r1, n2, rise
	))
	rail_runs.append(_make_flight_rail_run(
		RAIL_SIDE_LEFT, Vector3(margin, 0.0, 0.0), Vector3.BACK,
		r1, h1, n1, true, false, middle_shares[0]
	))
	rail_runs.append(_make_flight_rail_run(
		RAIL_SIDE_RIGHT, Vector3(fw - margin, 0.0, 0.0), Vector3.BACK,
		r1, h1, n1, true, false, middle_shares[0]
	))
	_add_raked_path_rail_runs(
		rail_runs, RAIL_SIDE_LEFT,
		[
			Vector2(margin, r1),
			Vector2(margin, depth - margin),
			Vector2(width - margin, depth - margin),
			Vector2(width - margin, r1),
		],
		h1, hw, WINDER_TREADS_180, rise, post_spacing
	)
	rail_runs.append(_make_flight_rail_run(
		RAIL_SIDE_LEFT, Vector3(width - margin, turn_height, r1), Vector3.FORWARD,
		r1, rise * float(n2), n2, false, true, middle_shares[1]
	))
	_add_raked_path_rail_runs(
		rail_runs, RAIL_SIDE_RIGHT,
		[
			Vector2(fw - margin, r1),
			Vector2(fw - margin, r1 + margin),
			Vector2(width - fw + margin, r1 + margin),
			Vector2(width - fw + margin, r1),
		],
		h1, hw, 0, rise, post_spacing
	)
	rail_runs.append(_make_flight_rail_run(
		RAIL_SIDE_RIGHT, Vector3(width - fw + margin, turn_height, r1), Vector3.FORWARD,
		r1, rise * float(n2), n2, false, true, middle_shares[1]
	))
	return _finish_turning_plan(context, width, fw)


func _configure_specific_stair_layout(
	new_winder_turn: int,
	_spiral_turn_degrees: float
) -> void:
	winder_turn = new_winder_turn


func _layout_winder_turn() -> int:
	return winder_turn


func _layout_mesh_source_signature_values() -> Array:
	var values := super()
	values.append(winder_turn)
	return values
