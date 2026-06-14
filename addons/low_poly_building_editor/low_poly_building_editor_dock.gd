@tool
extends VBoxContainer

signal tool_mode_changed(mode: String)
signal wall_settings_changed(settings: Dictionary)
signal prop_settings_changed(settings: Dictionary)
signal window_settings_changed(settings: Dictionary)
signal create_coordinator_requested()

const MODE_SELECT := "select"
const MODE_WALL := "wall"
const MODE_PROP := "prop"
const MODE_WINDOW := "window"
const MAX_PALETTE_ITEMS := 120
const DEFAULT_PROP_PALETTE_ROOT := "res://assets"
const PROP_SCENE_EXTENSIONS := [".tscn", ".scn", ".gltf", ".glb"]
const PROJECT_METADATA_SECTION := "low_poly_building_editor"
const PROJECT_METADATA_KEY := "dock_state"
const SHORTCUTS_SELECT_TEXT := "Shortcuts\nSelect: normal Godot editor selection and transform tools are active."
const SHORTCUTS_WALL_TEXT := "Shortcuts\nDrag empty space to draw a wall.\nDrag wall body to move it.\nDrag endpoint or joint to edit.\nShift-click wall body to add joint.\nOption/Alt-drag shared joint to disconnect.\nEsc or right-click cancels."
const SHORTCUTS_PROP_TEXT := "Shortcuts\nSelect a palette item, then click to place.\nR rotates the preview by 90 degrees.\nEsc or right-click cancels."
const SHORTCUTS_WINDOW_TEXT := "Shortcuts\nClick a wall to place a window.\nDrag window center to move.\nDrag window edge to resize.\nEsc or right-click cancels."

var m_editor_interface: EditorInterface
var m_mode_option: OptionButton
var m_shortcuts_label: Label
var m_status_label: Label
var m_grid_spin: SpinBox
var m_wall_height_spin: SpinBox
var m_wall_thickness_spin: SpinBox
var m_wall_color_picker: ColorPickerButton
var m_lock_8_way_check: CheckBox
var m_palette_root_edit: LineEdit
var m_prop_path_edit: LineEdit
var m_prop_clearance_spin: SpinBox
var m_palette_list: ItemList
var m_palette_root_dialog: EditorFileDialog
var m_scene_dialog: EditorFileDialog
var m_window_width_spin: SpinBox
var m_window_height_spin: SpinBox
var m_window_frame_spin: SpinBox
var m_window_sill_spin: SpinBox
var m_palette_paths: PackedStringArray = PackedStringArray()


func setup(editor_interface: EditorInterface) -> void:
	m_editor_interface = editor_interface


func _ready() -> void:
	if get_child_count() > 0:
		return
	_build_ui()
	_load_persisted_settings()
	_scan_palette()
	_emit_all_settings()


func _exit_tree() -> void:
	_save_persisted_settings()


func set_status(text: String) -> void:
	if m_status_label != null:
		m_status_label.text = text


func set_active_coordinator_path(path_text: String) -> void:
	pass


func _build_ui() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	m_shortcuts_label = Label.new()
	m_shortcuts_label.text = _shortcut_text_for_mode(MODE_SELECT)
	m_shortcuts_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(m_shortcuts_label)

	m_status_label = Label.new()
	m_status_label.text = "Select a tool."
	m_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(m_status_label)

	content.add_child(HSeparator.new())

	var mode_row := HBoxContainer.new()
	var mode_label := Label.new()
	mode_label.text = "Tool:"
	mode_row.add_child(mode_label)

	m_mode_option = OptionButton.new()
	m_mode_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_mode_option.add_item("Select", 0)
	m_mode_option.set_item_metadata(0, MODE_SELECT)
	m_mode_option.add_item("Wall", 1)
	m_mode_option.set_item_metadata(1, MODE_WALL)
	m_mode_option.add_item("Prop", 2)
	m_mode_option.set_item_metadata(2, MODE_PROP)
	m_mode_option.add_item("Window", 3)
	m_mode_option.set_item_metadata(3, MODE_WINDOW)
	m_mode_option.item_selected.connect(_on_mode_selected)
	mode_row.add_child(m_mode_option)
	content.add_child(mode_row)

	var coordinator_button := Button.new()
	coordinator_button.text = "Create Coordinator"
	coordinator_button.pressed.connect(_on_create_coordinator)
	content.add_child(coordinator_button)

	content.add_child(HSeparator.new())
	_build_wall_controls(content)
	content.add_child(HSeparator.new())
	_build_prop_controls(content)
	content.add_child(HSeparator.new())
	_build_window_controls(content)

	m_scene_dialog = EditorFileDialog.new()
	m_scene_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	m_scene_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	m_scene_dialog.title = "Select 3D prop scene"
	m_scene_dialog.add_filter("*.tscn,*.scn,*.gltf,*.glb ; 3D scene assets")
	m_scene_dialog.file_selected.connect(_on_scene_selected)
	add_child(m_scene_dialog)

	m_palette_root_dialog = EditorFileDialog.new()
	m_palette_root_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	m_palette_root_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	m_palette_root_dialog.title = "Select prop palette folder"
	m_palette_root_dialog.dir_selected.connect(_on_palette_root_selected)
	add_child(m_palette_root_dialog)


func _build_wall_controls(parent: VBoxContainer) -> void:
	var header := Label.new()
	header.text = "Wall"
	parent.add_child(header)

	m_grid_spin = _make_spin(0.05, 8.0, 0.05, 0.5)
	_add_labeled_control(parent, "Grid:", m_grid_spin)
	m_grid_spin.value_changed.connect(_on_wall_setting_changed)

	m_wall_height_spin = _make_spin(0.1, 20.0, 0.01, 2.4)
	_add_labeled_control(parent, "Height:", m_wall_height_spin)
	m_wall_height_spin.value_changed.connect(_on_wall_setting_changed)

	m_wall_thickness_spin = _make_spin(0.03, 4.0, 0.01, 0.22)
	_add_labeled_control(parent, "Thickness:", m_wall_thickness_spin)
	m_wall_thickness_spin.value_changed.connect(_on_wall_setting_changed)

	m_wall_color_picker = ColorPickerButton.new()
	m_wall_color_picker.color = Color(0.78, 0.68, 0.54, 1.0)
	m_wall_color_picker.color_changed.connect(_on_wall_color_changed)
	_add_labeled_control(parent, "Color:", m_wall_color_picker)

	m_lock_8_way_check = CheckBox.new()
	m_lock_8_way_check.text = "8-way lock"
	m_lock_8_way_check.button_pressed = true
	m_lock_8_way_check.toggled.connect(_on_wall_lock_changed)
	parent.add_child(m_lock_8_way_check)


func _build_prop_controls(parent: VBoxContainer) -> void:
	var header := Label.new()
	header.text = "Prop Palette"
	parent.add_child(header)

	var palette_root_row := HBoxContainer.new()
	var palette_root_label := Label.new()
	palette_root_label.text = "Folder:"
	palette_root_label.custom_minimum_size = Vector2(84.0, 0.0)
	palette_root_row.add_child(palette_root_label)

	m_palette_root_edit = LineEdit.new()
	m_palette_root_edit.text = DEFAULT_PROP_PALETTE_ROOT
	m_palette_root_edit.placeholder_text = DEFAULT_PROP_PALETTE_ROOT
	m_palette_root_edit.tooltip_text = "Resource folder scanned by the prop palette."
	m_palette_root_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_palette_root_edit.text_submitted.connect(_on_palette_root_submitted)
	m_palette_root_edit.focus_exited.connect(_on_palette_root_focus_exited)
	palette_root_row.add_child(m_palette_root_edit)

	var palette_root_browse := Button.new()
	palette_root_browse.text = "Browse"
	palette_root_browse.pressed.connect(_on_browse_palette_root)
	palette_root_row.add_child(palette_root_browse)
	parent.add_child(palette_root_row)

	var scene_row := HBoxContainer.new()
	m_prop_path_edit = LineEdit.new()
	m_prop_path_edit.placeholder_text = DEFAULT_PROP_PALETTE_ROOT.path_join("...")
	m_prop_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_prop_path_edit.text_changed.connect(_on_prop_setting_changed)
	scene_row.add_child(m_prop_path_edit)

	var browse_button := Button.new()
	browse_button.text = "Browse"
	browse_button.pressed.connect(_on_browse_scene)
	scene_row.add_child(browse_button)
	parent.add_child(scene_row)

	var scan_button := Button.new()
	scan_button.text = "Rescan Palette"
	scan_button.pressed.connect(_scan_palette)
	parent.add_child(scan_button)

	m_palette_list = ItemList.new()
	m_palette_list.custom_minimum_size = Vector2(0, 180)
	m_palette_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m_palette_list.item_selected.connect(_on_palette_item_selected)
	parent.add_child(m_palette_list)

	m_prop_clearance_spin = _make_spin(0.0, 5.0, 0.05, 0.25)
	_add_labeled_control(parent, "Clearance:", m_prop_clearance_spin)
	m_prop_clearance_spin.value_changed.connect(_on_prop_clearance_changed)


func _build_window_controls(parent: VBoxContainer) -> void:
	var header := Label.new()
	header.text = "Window Opening"
	parent.add_child(header)

	m_window_width_spin = _make_spin(0.1, 8.0, 0.01, 1.0)
	_add_labeled_control(parent, "Width:", m_window_width_spin)
	m_window_width_spin.value_changed.connect(_on_window_setting_changed)

	m_window_height_spin = _make_spin(0.1, 8.0, 0.01, 1.0)
	_add_labeled_control(parent, "Height:", m_window_height_spin)
	m_window_height_spin.value_changed.connect(_on_window_setting_changed)

	m_window_frame_spin = _make_spin(0.01, 1.0, 0.01, 0.08)
	_add_labeled_control(parent, "Frame:", m_window_frame_spin)
	m_window_frame_spin.value_changed.connect(_on_window_setting_changed)

	m_window_sill_spin = _make_spin(0.0, 10.0, 0.01, 0.9)
	m_window_sill_spin.tooltip_text = "Height of the opening's bottom edge above the wall base."
	_add_labeled_control(parent, "Sill:", m_window_sill_spin)
	m_window_sill_spin.value_changed.connect(_on_window_setting_changed)


func _make_spin(min_value: float, max_value: float, step: float, value: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	spin.value = value
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spin


func _add_labeled_control(parent: VBoxContainer, label_text: String, control: Control) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(84.0, 0.0)
	row.add_child(label)
	row.add_child(control)
	parent.add_child(row)


func _on_mode_selected(index: int) -> void:
	var mode := String(m_mode_option.get_item_metadata(index))
	_update_shortcuts_for_mode(mode)
	tool_mode_changed.emit(mode)


func _update_shortcuts_for_mode(mode: String) -> void:
	if m_shortcuts_label == null:
		return
	m_shortcuts_label.text = _shortcut_text_for_mode(mode)


func _shortcut_text_for_mode(mode: String) -> String:
	match mode:
		MODE_WALL:
			return SHORTCUTS_WALL_TEXT
		MODE_PROP:
			return SHORTCUTS_PROP_TEXT
		MODE_WINDOW:
			return SHORTCUTS_WINDOW_TEXT
		_:
			return SHORTCUTS_SELECT_TEXT


func _on_create_coordinator() -> void:
	create_coordinator_requested.emit()


func _on_browse_scene() -> void:
	m_scene_dialog.current_dir = _get_resolved_palette_root()["path"]
	m_scene_dialog.popup_centered(Vector2i(720, 520))


func _on_browse_palette_root() -> void:
	m_palette_root_dialog.current_dir = _get_resolved_palette_root()["path"]
	m_palette_root_dialog.popup_centered(Vector2i(720, 520))


func _on_palette_root_selected(dir: String) -> void:
	m_palette_root_edit.text = dir
	_save_persisted_settings()
	_scan_palette()


func _on_palette_root_submitted(_text: String) -> void:
	_save_persisted_settings()
	_scan_palette()


func _on_palette_root_focus_exited() -> void:
	_save_persisted_settings()


func _on_scene_selected(path: String) -> void:
	m_prop_path_edit.text = path
	_on_prop_setting_changed(path)


func _on_palette_item_selected(index: int) -> void:
	if index < 0 or index >= m_palette_paths.size():
		return
	var path := m_palette_paths[index]
	m_prop_path_edit.text = path
	_on_prop_setting_changed(path)


func _on_wall_setting_changed(_value: float) -> void:
	_emit_wall_settings()


func _on_wall_color_changed(_color: Color) -> void:
	_emit_wall_settings()


func _on_wall_lock_changed(_pressed: bool) -> void:
	_emit_wall_settings()


func _on_prop_setting_changed(_value: String) -> void:
	_emit_prop_settings()


func _on_prop_clearance_changed(_value: float) -> void:
	_emit_prop_settings()


func _on_window_setting_changed(_value: float) -> void:
	_emit_window_settings()


func _emit_all_settings() -> void:
	_emit_wall_settings()
	_emit_prop_settings()
	_emit_window_settings()


func _emit_wall_settings() -> void:
	wall_settings_changed.emit({
		"grid_step": float(m_grid_spin.value),
		"height": float(m_wall_height_spin.value),
		"thickness": float(m_wall_thickness_spin.value),
		"color": m_wall_color_picker.color,
		"lock_8_way": m_lock_8_way_check.button_pressed,
	})


func _emit_prop_settings() -> void:
	prop_settings_changed.emit({
		"scene_path": m_prop_path_edit.text.strip_edges(),
		"clearance": float(m_prop_clearance_spin.value),
	})


func _emit_window_settings() -> void:
	window_settings_changed.emit({
		"width": float(m_window_width_spin.value),
		"height": float(m_window_height_spin.value),
		"frame_thickness": float(m_window_frame_spin.value),
		"sill_height": float(m_window_sill_spin.value),
	})


func _scan_palette() -> void:
	m_palette_paths.clear()
	var root_state := _get_resolved_palette_root()
	var palette_root := String(root_state["path"])
	_collect_scene_paths(palette_root, m_palette_paths)
	m_palette_paths.sort()
	if m_palette_list == null:
		return
	m_palette_list.clear()
	var scene_icon := get_theme_icon(&"PackedScene", &"EditorIcons")
	for path in m_palette_paths:
		var label := path.get_file().get_basename()
		m_palette_list.add_item(label, scene_icon)
		m_palette_list.set_item_tooltip(m_palette_list.get_item_count() - 1, path)


func _collect_scene_paths(path: String, results: PackedStringArray) -> void:
	if results.size() >= MAX_PALETTE_ITEMS:
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while !file_name.is_empty():
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue
		var child_path := path.path_join(file_name)
		if dir.current_is_dir():
			if !["addons", "3rdparty", "godot_common", "godot_tilemap", "agent_tools"].has(file_name):
				_collect_scene_paths(child_path, results)
		elif _is_prop_scene_file(file_name):
			results.append(child_path)
		if results.size() >= MAX_PALETTE_ITEMS:
			break
		file_name = dir.get_next()
	dir.list_dir_end()


func _is_prop_scene_file(file_name: String) -> bool:
	var lower_name := file_name.to_lower()
	for extension in PROP_SCENE_EXTENSIONS:
		if lower_name.ends_with(extension):
			return true
	return false


func _get_configured_palette_root() -> String:
	if m_palette_root_edit == null:
		return DEFAULT_PROP_PALETTE_ROOT
	var configured := m_palette_root_edit.text.strip_edges()
	if configured.is_empty():
		return DEFAULT_PROP_PALETTE_ROOT
	return configured


func _get_resolved_palette_root() -> Dictionary:
	var configured := _get_configured_palette_root()
	if DirAccess.dir_exists_absolute(configured):
		return {
			"path": configured,
			"warning": "",
		}
	if configured != DEFAULT_PROP_PALETTE_ROOT and !configured.is_empty():
		var fallback := DEFAULT_PROP_PALETTE_ROOT if DirAccess.dir_exists_absolute(DEFAULT_PROP_PALETTE_ROOT) else "res://"
		return {
			"path": fallback,
			"warning": "Palette folder not found: %s." % configured,
		}
	return {
		"path": "res://",
		"warning": "",
	}


func _get_editor_settings() -> EditorSettings:
	if m_editor_interface != null:
		return m_editor_interface.get_editor_settings()
	return EditorInterface.get_editor_settings()


func _load_persisted_settings() -> void:
	var editor_settings := _get_editor_settings()
	if editor_settings == null:
		return

	var state_variant: Variant = editor_settings.get_project_metadata(PROJECT_METADATA_SECTION, PROJECT_METADATA_KEY, {})
	if typeof(state_variant) != TYPE_DICTIONARY:
		return

	var state: Dictionary = state_variant
	m_palette_root_edit.text = str(state.get("prop_palette_root", m_palette_root_edit.text))
	m_window_sill_spin.value = float(state.get("window_sill_height", m_window_sill_spin.value))


func _save_persisted_settings() -> void:
	var editor_settings := _get_editor_settings()
	if editor_settings == null:
		return

	editor_settings.set_project_metadata(PROJECT_METADATA_SECTION, PROJECT_METADATA_KEY, {
		"prop_palette_root": _get_configured_palette_root(),
		"window_sill_height": float(m_window_sill_spin.value) if m_window_sill_spin != null else 0.9,
	})
