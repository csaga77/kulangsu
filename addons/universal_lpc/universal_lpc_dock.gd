@tool
extends VBoxContainer

const MANIFEST_PATH: String = "res://addons/universal_lpc/universal_lpc_metadata.json"
const SOURCE_ROOT: String = "res://3rdparty/Universal-LPC-Spritesheet-Character-Generator"
const SPRITE_GENERATOR_SCENE: String = "res://addons/universal_lpc/tests/test_universal_lpc_sprite_generator.tscn"
const ASSET_AUDIT_SCENE: String = "res://addons/universal_lpc/tests/test_universal_lpc_asset_audit.tscn"

var m_editor_interface: EditorInterface
var m_status_label: Label
var m_open_generator_button: Button
var m_run_audit_button: Button


func setup(editor_interface: EditorInterface) -> void:
	m_editor_interface = editor_interface
	_build_ui()
	_refresh_status()


func _build_ui() -> void:
	if m_status_label != null:
		return

	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title_label := Label.new()
	title_label.text = "Universal LPC 2D"
	add_child(title_label)

	var description_label := Label.new()
	description_label.text = "Compose layered LPC characters and validate the upstream source catalog."
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(description_label)

	m_status_label = Label.new()
	m_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(m_status_label)

	m_open_generator_button = Button.new()
	m_open_generator_button.text = "Open Sprite Composer"
	m_open_generator_button.tooltip_text = "Open the metadata and layered-sprite composition scene."
	m_open_generator_button.pressed.connect(_on_open_generator_pressed)
	add_child(m_open_generator_button)

	m_run_audit_button = Button.new()
	m_run_audit_button.text = "Run Source Asset Audit"
	m_run_audit_button.tooltip_text = "Run the focused audit scene and print its report to the Output panel."
	m_run_audit_button.pressed.connect(_on_run_audit_pressed)
	add_child(m_run_audit_button)

	var refresh_button := Button.new()
	refresh_button.text = "Refresh Status"
	refresh_button.pressed.connect(_refresh_status)
	add_child(refresh_button)


func _refresh_status() -> void:
	if m_status_label == null:
		return

	var manifest_ready := FileAccess.file_exists(MANIFEST_PATH)
	var source_ready := DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SOURCE_ROOT))
	m_status_label.text = "Manifest: %s\nUpstream source: %s" % [
		"ready" if manifest_ready else "missing",
		"ready" if source_ready else "missing",
	]
	m_open_generator_button.disabled = !manifest_ready
	m_run_audit_button.disabled = !source_ready


func _on_open_generator_pressed() -> void:
	if m_editor_interface == null:
		return
	m_editor_interface.open_scene_from_path(SPRITE_GENERATOR_SCENE)


func _on_run_audit_pressed() -> void:
	if m_editor_interface == null:
		return
	m_editor_interface.play_custom_scene(ASSET_AUDIT_SCENE)
