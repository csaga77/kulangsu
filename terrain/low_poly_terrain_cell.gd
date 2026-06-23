@tool
class_name LowPolyTerrainCell
extends RefCounted

## A single coarse terrain sample produced by LowPolyTerrainSampler and consumed by
## LowPolyTerrain3D mesh building and surface-height queries.

enum Kind {
	WATER,
	LAND,
	STREET,
	BUILDING,
}

var kind: int
var height: float


func _init(cell_kind: int, cell_height: float) -> void:
	kind = cell_kind
	height = cell_height
