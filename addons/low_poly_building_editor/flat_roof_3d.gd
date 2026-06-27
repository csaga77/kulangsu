@tool
class_name FlatRoof3D
extends "res://addons/low_poly_building_editor/roof_3d.gd"

const StyleGeometry := preload("res://addons/low_poly_building_editor/roof_style_geometry_3d.gd")


func get_roof_style() -> String:
	return STYLE_FLAT


func _get_style_geometry() -> RefCounted:
	return StyleGeometry.new()
