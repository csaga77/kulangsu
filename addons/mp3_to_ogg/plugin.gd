@tool
extends EditorPlugin

const _DOCK_SLOT := EditorDock.DOCK_SLOT_RIGHT_UL

var _dock: Control
var _editor_dock: EditorDock


func _enter_tree() -> void:
	var dock_script: GDScript = load("res://addons/mp3_to_ogg/mp3_to_ogg_dock.gd")
	_dock = dock_script.new()
	if _dock.has_method("setup"):
		_dock.setup(get_editor_interface())
	_dock.name = "MP3 to OGG"
	_editor_dock = EditorDock.new()
	_editor_dock.name = "MP3 to OGG Converter"
	_editor_dock.title = "MP3 to OGG Converter"
	_editor_dock.default_slot = _DOCK_SLOT
	_editor_dock.layout_key = "mp3_to_ogg_converter"
	_editor_dock.add_child(_dock)
	add_dock(_editor_dock)


func _exit_tree() -> void:
	if _editor_dock:
		remove_dock(_editor_dock)
		_editor_dock.queue_free()
		_editor_dock = null
		_dock = null
	elif _dock:
		_dock.queue_free()
		_dock = null
