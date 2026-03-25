@tool
extends Resource
class_name LevelProfile

@export var level_id: int = 0
@export var physics_atlas_column: int = 0
@export_flags_2d_physics var collision_mask := 0
@export var z_index: int = 0

func apply_to(actor: Node2D) -> void:
	if actor == null:
		return
	actor.collision_mask = collision_mask
	actor.z_index = z_index
