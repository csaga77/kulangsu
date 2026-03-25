@tool
class_name LevelContext2D
extends Node

signal runtime_levels_changed

@export var runtime_levels := PackedInt32Array():
	set(new_runtime_levels):
		if runtime_levels == new_runtime_levels:
			return
		runtime_levels = new_runtime_levels
		runtime_levels_changed.emit()

@export var level_profiles: Array[Resource] = []:
	set(new_level_profiles):
		level_profiles = new_level_profiles
		runtime_levels_changed.emit()

static func find_from(node: Node) -> LevelContext2D:
	var current := node
	while current != null:
		if current is LevelContext2D:
			return current as LevelContext2D
		for child in current.get_children():
			if child is LevelContext2D:
				return child as LevelContext2D
		current = current.get_parent()
	return null

func has_level_slot(level_slot: int) -> bool:
	return level_slot >= 0 and level_slot < runtime_levels.size()

func resolve_level_slot(level_slot: int, fallback_level: int = 0) -> int:
	if !has_level_slot(level_slot):
		return fallback_level
	return runtime_levels[level_slot]

func resolve_level_profile(level_id: int) -> Resource:
	for level_profile in level_profiles:
		if level_profile == null:
			continue
		if int(level_profile.get("level_id")) == level_id:
			return level_profile
	return null

func resolve_level_physics_atlas_column(level_id: int, fallback_column: int = 0) -> int:
	var level_profile := resolve_level_profile(level_id)
	if level_profile == null:
		return fallback_column
	return int(level_profile.get("physics_atlas_column"))

func resolve_level_collision_mask(level_id: int, fallback_mask: int = 0) -> int:
	var level_profile := resolve_level_profile(level_id)
	if level_profile == null:
		return fallback_mask
	return int(level_profile.get("collision_mask"))

func resolve_level_z_index(level_id: int, fallback_z_index: int = 0) -> int:
	var level_profile := resolve_level_profile(level_id)
	if level_profile == null:
		return fallback_z_index
	return int(level_profile.get("z_index"))

func apply_level_to_actor(level_id: int, actor: Node2D) -> bool:
	var level_profile := resolve_level_profile(level_id)
	if level_profile == null:
		return false
	level_profile.call("apply_to", actor)
	return true
