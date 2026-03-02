@tool
class_name BoardRules
extends Resource

# Base interface for grid board rules.
# Implementations must be deterministic and side-effect free except their own internal state
# (used for superko etc.). Undo/redo snapshot logic is in GoGame; rules only export/import state.

func reset(_board: PackedInt32Array, _board_size: int) -> void:
	pass

func simulate_move(
	_board: PackedInt32Array,
	_board_size: int,
	_color: int,
	_cell: Vector2i,
	_out_info: Dictionary
) -> bool:
	return false

func compute_move(
	_board: PackedInt32Array,
	_board_size: int,
	_color: int,
	_cell: Vector2i
) -> Dictionary:
	return {"ok": false}

# --- Needed for GoGame undo/redo snapshots (NOT undo logic) ---
func export_state() -> Dictionary:
	return {}

func import_state(_state: Dictionary) -> void:
	pass
