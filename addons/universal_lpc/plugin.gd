@tool
extends EditorPlugin

const DOCK_SLOT: EditorDock.DockSlot = EditorDock.DOCK_SLOT_RIGHT_UL
const UNIVERSAL_LPC_DOCK_SCRIPT: GDScript = preload("res://addons/universal_lpc/universal_lpc_dock.gd")

var m_dock: Control
var m_editor_dock: EditorDock


func _enter_tree() -> void:
	m_dock = UNIVERSAL_LPC_DOCK_SCRIPT.new()
	m_dock.setup(get_editor_interface())
	m_dock.name = "Universal LPC 2D"

	m_editor_dock = EditorDock.new()
	m_editor_dock.name = "Universal LPC 2D Character"
	m_editor_dock.title = "Universal LPC 2D Character"
	m_editor_dock.default_slot = DOCK_SLOT
	m_editor_dock.layout_key = "universal_lpc_2d_character"
	m_editor_dock.add_child(m_dock)
	add_dock(m_editor_dock)


func _exit_tree() -> void:
	if m_editor_dock != null:
		remove_dock(m_editor_dock)
		m_editor_dock.queue_free()
		m_editor_dock = null
		m_dock = null
	elif m_dock != null:
		m_dock.queue_free()
		m_dock = null
