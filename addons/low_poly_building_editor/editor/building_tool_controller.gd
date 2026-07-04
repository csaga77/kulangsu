@tool
extends RefCounted

## Abstract base for per-tool editor controllers — stage 3+ of the plugin
## split (see `../docs/plugin_split_plan.md`). A concrete controller owns its
## tool's dock settings, preview, hover highlight, and drag state, and
## receives viewport input while its mode is active. Controllers are
## plugin-lifetime objects created in `_enter_tree`, so undo/redo actions may
## bind controller or context methods. Internal and path-extended; not an
## editor-creatable type.

const BuildingToolContextScript = preload("res://addons/low_poly_building_editor/editor/building_tool_context.gd")

var m_context: BuildingToolContextScript


func _init(context: BuildingToolContextScript) -> void:
	m_context = context


## Viewport input while this controller's mode is active (both the direct
## `_forward_3d_gui_input` path and the viewport-overlay path). Returns an
## `EditorPlugin.AFTER_GUI_INPUT_*` value.
func handle_input(_camera: Camera3D, _event: InputEvent) -> int:
	return EditorPlugin.AFTER_GUI_INPUT_PASS


## New tool defaults pushed from the dock's `<tool>_settings_changed` signal.
func apply_settings(_settings: Dictionary) -> void:
	pass


## Cancels any in-progress draw preview, hover highlight, and drag, restoring
## authored state. Called on Escape/right-click, on tool-mode changes, and on
## plugin exit; must be safe to call at any time.
func cancel_preview() -> void:
	pass
