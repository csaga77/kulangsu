@tool
class_name Window3D
extends BuildingOpening3D


# Concrete window styles own their generated panes and detailing. Window3D only
# establishes behavior shared by every window opening.
func _build_opening_content() -> void:
	pass
