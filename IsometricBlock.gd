@tool
class_name IsometricBlock
extends Node2D

@export var snap_in_editor := true
@export var iso_tile_size := Vector2(64, 32) # diamond tile: 64w x 32h

var _snapping := false

func _ready() -> void:
	set_notify_local_transform(true)

func _notification(what: int) -> void:
	if not Engine.is_editor_hint():
		return
	if not snap_in_editor:
		return

	# Fires when you drag the node or change its position in the inspector
	if what == CanvasItem.NOTIFICATION_LOCAL_TRANSFORM_CHANGED:
		#print(global_position)
		if _snapping:
			return

		_snapping = true
		var snapped := snap_to_iso_grid(position, iso_tile_size)
		#print(global_position)
		print(snapped)
		# Avoid infinite notification loops
		if snapped != position:
			position = snapped
		_snapping = false

static func snap_to_iso_grid(world_pos: Vector2, tile: Vector2) -> Vector2:
	# World -> iso grid (continuous)
	var gx := (world_pos.x / tile.x + world_pos.y / tile.y)
	var gy := (world_pos.y / tile.y - world_pos.x / tile.x)

	# Snap to nearest cell
	gx = round(gx) - 1
	gy = round(gy)
	#print(Vector2(gx, gy))
	
	# Iso grid -> world
	return Vector2(
		(gx + 1 - gy) * tile.x * 0.5,
		(gx + 1 + gy) * tile.y * 0.5
	)
