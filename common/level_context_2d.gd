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

func has_level_slot(level_slot: int) -> bool:
	return level_slot >= 0 and level_slot < runtime_levels.size()

func resolve_level_slot(level_slot: int, fallback_level: int = 0) -> int:
	if !has_level_slot(level_slot):
		return fallback_level
	return runtime_levels[level_slot]
