@tool
class_name GableRoof3D
extends "res://addons/low_poly_building_editor/sloped_roof_3d.gd"

const StyleGeometry := preload("res://addons/low_poly_building_editor/gable_roof_geometry_3d.gd")


func get_roof_style() -> String:
	return STYLE_GABLE


func _get_style_geometry() -> RefCounted:
	return StyleGeometry.new()
