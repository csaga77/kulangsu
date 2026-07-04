@tool
extends RefCounted

const STYLE_FLAT := "flat"
const STYLE_SHED := "shed"
const STYLE_GABLE := "gable"
const STYLE_HIP := "hip"
const STYLE_DOME := "dome"

const FlatGeometry := preload("res://addons/low_poly_building_editor/roof_style_geometry_3d.gd")
const ShedGeometry := preload("res://addons/low_poly_building_editor/shed_roof_geometry_3d.gd")
const GableGeometry := preload("res://addons/low_poly_building_editor/gable_roof_geometry_3d.gd")
const HipGeometry := preload("res://addons/low_poly_building_editor/hip_roof_geometry_3d.gd")
const DomeGeometry := preload("res://addons/low_poly_building_editor/dome_roof_geometry_3d.gd")


static func create(style: String) -> RefCounted:
	match style.strip_edges().to_lower():
		STYLE_FLAT:
			return FlatGeometry.new()
		STYLE_SHED:
			return ShedGeometry.new()
		STYLE_GABLE:
			return GableGeometry.new()
		STYLE_HIP:
			return HipGeometry.new()
		STYLE_DOME:
			return DomeGeometry.new()
	push_error("Unsupported roof geometry style: %s" % style)
	return null


static func roof_height_for_angle_degrees(run: float, angle_degrees: float) -> float:
	return FlatGeometry.roof_height_for_angle(run, angle_degrees)


static func sloped_parameters(angle_degrees: float) -> Dictionary:
	return {"angle_degrees": angle_degrees}


static func hip_parameters(
	angle_degrees: float,
	gable_height_from_peak: float
) -> Dictionary:
	return {
		"angle_degrees": angle_degrees,
		"gable_height_from_peak": gable_height_from_peak,
	}


static func shed_height_for_angle_degrees(
	depth: float,
	overhang: float,
	angle_degrees: float
) -> float:
	return ShedGeometry.new().generated_height(
		Vector2(0.0, depth), overhang, sloped_parameters(angle_degrees)
	)


static func shed_roof_run_for_depth(depth: float, overhang: float) -> float:
	return ShedGeometry.new().roof_run(Vector2(0.0, depth), overhang)


static func gable_height_for_angle_degrees(
	depth: float,
	overhang: float,
	angle_degrees: float
) -> float:
	return GableGeometry.new().generated_height(
		Vector2(0.0, depth), overhang, sloped_parameters(angle_degrees)
	)


static func gable_roof_run_for_depth(depth: float, overhang: float) -> float:
	return GableGeometry.new().roof_run(Vector2(0.0, depth), overhang)


static func hip_height_for_angle_degrees(
	size: Vector2,
	overhang: float,
	angle_degrees: float
) -> float:
	return HipGeometry.new().generated_height(
		size, overhang, sloped_parameters(angle_degrees)
	)


static func hip_roof_run_for_size(size: Vector2, overhang: float) -> float:
	return HipGeometry.new().roof_run(size, overhang)


static func dome_height_for_angle_degrees(
	size: Vector2,
	overhang: float,
	angle_degrees: float
) -> float:
	return DomeGeometry.new().generated_height(
		size, overhang, sloped_parameters(angle_degrees)
	)


static func dome_roof_run_for_size(size: Vector2, overhang: float) -> float:
	return DomeGeometry.new().roof_run(size, overhang)


static func hip_roof_ridge_points_for_size(
	size: Vector2,
	overhang: float,
	angle_degrees: float,
	gable_height_from_peak: float = 0.0
) -> PackedVector3Array:
	return HipGeometry.new().ridge_points(
		size, overhang, angle_degrees, gable_height_from_peak
	)


static func roof_generated_height_for_style(
	style: String,
	size: Vector2,
	overhang: float,
	parameters: Dictionary = {}
) -> float:
	var geometry := create(style)
	return (
		geometry.generated_height(size, overhang, parameters)
		if geometry != null
		else 0.0
	)


static func roof_surface_height_for_style(
	style: String,
	size: Vector2,
	overhang: float,
	local_render_point: Vector2,
	parameters: Dictionary = {}
) -> float:
	var geometry := create(style)
	if geometry == null:
		return 0.0
	return geometry.surface_height(
		size,
		overhang,
		local_render_point,
		parameters
	)


static func roof_top_triangles_for_style(
	style: String,
	full_size: Vector2,
	overhang: float,
	parameters: Dictionary = {}
) -> Array[PackedVector3Array]:
	var geometry := create(style)
	if geometry == null:
		return []
	return geometry.top_triangles(
		full_size,
		overhang,
		parameters
	)


static func roof_top_faces_for_style(
	style: String,
	full_size: Vector2,
	overhang: float,
	parameters: Dictionary = {}
) -> Array[Dictionary]:
	var geometry := create(style)
	if geometry == null:
		return []
	return geometry.top_faces(
		full_size,
		overhang,
		parameters
	)
