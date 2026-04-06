@tool
extends EditorPlugin

var _dock: Control


func _enter_tree() -> void:
	var dock_script: GDScript = load("res://addons/mp3_to_ogg/mp3_to_ogg_dock.gd")
	_dock = dock_script.new()
	if _dock.has_method("setup"):
		_dock.setup(get_editor_interface())
	_dock.name = "MP3 to OGG"
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)


func _exit_tree() -> void:
	if _dock:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
