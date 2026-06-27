@tool
class_name GlazedGridDoor3D
extends Door3D


func _init() -> void:
	super()
	door_glazing_ratio = 0.55
	pane_grid_rows = 2
	pane_grid_cols = 1
