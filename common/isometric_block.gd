@tool
class_name IsometricBlock
extends Node2D

@export var only_shown_in_editor := false
@export var snap_in_editor := true
@export var iso_tile_size := Vector2(64, 32) # diamond tile: 64w x 32h
@export var iso_tile_offset := Vector2.ZERO

var _snapping := false

func _ready() -> void:
	set_notify_local_transform(true)
	if only_shown_in_editor:
		visible = Engine.is_editor_hint()

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
		var snapped_pos := TileMapUtils.snap_to_iso_grid(position - iso_tile_offset, iso_tile_size) + iso_tile_offset
		#print(global_position)
		#print(snapped_pos)
		# Avoid infinite notification loops
		if snapped_pos != position:
			position = snapped_pos
		_snapping = false
