@tool
extends RefCounted

const FlatGeometry := preload("res://addons/low_poly_building_editor/roof_style_geometry_3d.gd")
const ShedGeometry := preload("res://addons/low_poly_building_editor/shed_roof_geometry_3d.gd")
const GableGeometry := preload("res://addons/low_poly_building_editor/gable_roof_geometry_3d.gd")
const HipGeometry := preload("res://addons/low_poly_building_editor/hip_roof_geometry_3d.gd")


static func create(style: String) -> RefCounted:
	match style.strip_edges().to_lower():
		"shed":
			return ShedGeometry.new()
		"gable":
			return GableGeometry.new()
		"hip":
			return HipGeometry.new()
	return FlatGeometry.new()
