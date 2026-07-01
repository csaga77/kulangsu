@tool
extends VBoxContainer

signal tool_mode_changed(mode: String)
signal wall_settings_changed(settings: Dictionary)
signal floor_settings_changed(settings: Dictionary)
signal stair_settings_changed(settings: Dictionary)
signal pillar_settings_changed(settings: Dictionary)
signal roof_settings_changed(settings: Dictionary)
signal prop_settings_changed(settings: Dictionary)
signal window_settings_changed(settings: Dictionary)
signal door_settings_changed(settings: Dictionary)
signal display_settings_changed(settings: Dictionary)
signal create_coordinator_requested()

const MODE_SELECT := "select"
const MODE_WALL := "wall"
const MODE_FLOOR := "floor"
const MODE_STAIRS := "stairs"
const MODE_PILLAR := "pillar"
const MODE_ROOF := "roof"
const MODE_PROP := "prop"
const MODE_WINDOW := "window"
const MODE_DOOR := "door"
const MAX_PALETTE_ITEMS := 120
const DEFAULT_PROP_PALETTE_ROOT := "res://assets"
const PROP_SCENE_EXTENSIONS := [".tscn", ".scn", ".gltf", ".glb"]
const PROJECT_METADATA_SECTION := "low_poly_building_editor"
const PROJECT_METADATA_KEY := "dock_state"
const DEFAULT_ROOF_ANGLE_DEGREES := 40.0
const LEGACY_ROOF_VALUE_MAX := 8.0
const WALL_TYPE_WALL := "wall"
const WALL_TYPE_ROOM := "room"
const FLOOR_TYPE_SOLID := "solid"
const FLOOR_TYPE_HOLE := "hole"
const FLOOR_STYLE_RECTANGLE := "rectangle"
const FLOOR_STYLE_POLYGON := "polygon"
const COLOR_SWATCH_ICON_SIZE := 16
const COLOR_SWATCH_MIN_WIDTH := 34.0
const SHORTCUTS_SELECT_TEXT := "Shortcuts\nSelect: normal Godot editor selection and transform tools are active."
const SHORTCUTS_WALL_TEXT := "Shortcuts\nUse Wall Type to choose a single wall or enclosed room.\nDrag empty space to draw a wall span or room rectangle.\nClick once, then click the endpoint or opposite room corner.\nDrag a room side to resize in one direction.\nOption/Alt-drag a room to move the whole room.\nDrag other wall bodies to move them.\nDrag endpoint or joint to edit.\nShift-click wall body to add joint.\nOption/Alt-drag shared joint to disconnect.\nEsc or right-click cancels."
const SHORTCUTS_FLOOR_TEXT := "Shortcuts\nRectangle and Polygon only change how a floor is created.\nRectangle: drag, or click two opposite corners.\nPolygon: click each vertex; click the first vertex or press Enter to close.\nFor either style, drag any vertex to reshape.\nDrag any edge to move its two vertices.\nShift-click an edge to add a vertex.\nOption/Alt-click a vertex to remove it.\nDrag the floor body to move it.\nEsc or right-click cancels."
const SHORTCUTS_STAIRS_TEXT := "Shortcuts\nDrag empty space to draw a stair rectangle.\nClick one corner, then click the opposite corner to place.\nR rotates the preview or hovered stairs by 90 degrees.\nShift+R rotates the opposite direction.\nDrag stairs body to move it.\nDrag stairs edge or corner to resize.\nEsc or right-click cancels."
const SHORTCUTS_PILLAR_TEXT := "Shortcuts\nClick empty space to place a pillar.\nDrag pillar body to move it.\nDrag pillar edge to resize its radius.\nEsc or right-click cancels."
const SHORTCUTS_ROOF_TEXT := "Shortcuts\nFlat roofs can be created as Rectangle or Polygon footprints.\nRectangle: drag, or click two opposite corners.\nPolygon: click each vertex; click the first vertex or press Enter to close.\nFor either Flat footprint, drag any vertex or edge to reshape.\nShift-click an edge to add a vertex.\nOption/Alt-click a vertex to remove it.\nDrag the roof body to move it.\nR rotates rectangular or pitched roofs by 90 degrees.\nEsc or right-click cancels."
const SHORTCUTS_PROP_TEXT := "Shortcuts\nSelect a palette item, then click to place.\nR rotates the preview by 90 degrees.\nEsc or right-click cancels."
const SHORTCUTS_WINDOW_TEXT := "Shortcuts\nClick a wall to place a window.\nDrag window center to move.\nDrag window edge to resize.\nEsc or right-click cancels."
const SHORTCUTS_DOOR_TEXT := "Shortcuts\nSelect a door style, then click a wall to place.\nDrag door center to move.\nDrag door edge to resize.\nEsc or right-click cancels."

var m_editor_interface: EditorInterface
var m_mode_option: OptionButton
var m_status_label: Label
var m_debug_wireframe_check: CheckBox
var m_debug_wireframe_xray_check: CheckBox
var m_debug_wireframe_color_picker: ColorPickerButton
var m_wall_section: VBoxContainer
var m_floor_section: VBoxContainer
var m_stair_section: VBoxContainer
var m_pillar_section: VBoxContainer
var m_roof_section: VBoxContainer
var m_prop_section: VBoxContainer
var m_window_section: VBoxContainer
var m_door_section: VBoxContainer
var m_wall_type_option: OptionButton
var m_grid_spin: SpinBox
var m_wall_base_height_spin: SpinBox
var m_wall_height_spin: SpinBox
var m_wall_thickness_spin: SpinBox
var m_wall_color_picker: ColorPickerButton
var m_lock_8_way_check: CheckBox
var m_floor_type_option: OptionButton
var m_floor_style_option: OptionButton
var m_floor_grid_spin: SpinBox
var m_floor_base_height_spin: SpinBox
var m_floor_thickness_spin: SpinBox
var m_floor_color_picker: ColorPickerButton
var m_stair_grid_spin: SpinBox
var m_stair_base_height_spin: SpinBox
var m_stair_height_spin: SpinBox
var m_stair_step_count_spin: SpinBox
var m_stair_thickness_spin: SpinBox
var m_stair_rotation_spin: SpinBox
var m_stair_color_picker: ColorPickerButton
var m_pillar_grid_spin: SpinBox
var m_pillar_style_option: OptionButton
var m_pillar_base_height_spin: SpinBox
var m_pillar_radius_spin: SpinBox
var m_pillar_upper_radius_spin: SpinBox
var m_pillar_height_spin: SpinBox
var m_pillar_sides_spin: SpinBox
var m_pillar_lower_rim_height_spin: SpinBox
var m_pillar_lower_rim_outset_spin: SpinBox
var m_pillar_upper_rim_height_spin: SpinBox
var m_pillar_upper_rim_outset_spin: SpinBox
var m_pillar_color_picker: ColorPickerButton
var m_pillar_style_header: Label
var m_pillar_sides_row: HBoxContainer
var m_roof_grid_spin: SpinBox
var m_roof_style_option: OptionButton
var m_roof_footprint_option: OptionButton
var m_roof_footprint_row: HBoxContainer
var m_roof_base_height_spin: SpinBox
var m_roof_height_spin: SpinBox
var m_roof_thickness_spin: SpinBox
var m_roof_overhang_spin: SpinBox
var m_roof_hip_gable_height_spin: SpinBox
var m_roof_rotation_spin: SpinBox
var m_roof_color_picker: ColorPickerButton
var m_roof_style_header: Label
var m_roof_angle_row: HBoxContainer
var m_roof_hip_gable_height_row: HBoxContainer
var m_palette_root_edit: LineEdit
var m_prop_path_edit: LineEdit
var m_prop_clearance_spin: SpinBox
var m_palette_list: ItemList
var m_palette_root_dialog: EditorFileDialog
var m_scene_dialog: EditorFileDialog
var m_window_style_option: OptionButton
var m_window_width_spin: SpinBox
var m_window_height_spin: SpinBox
var m_window_frame_spin: SpinBox
var m_window_frame_protrusion_spin: SpinBox
var m_window_frame_color_picker: ColorPickerButton
var m_window_sill_spin: SpinBox
var m_window_frame_sides_option: OptionButton
var m_window_style_header: Label
var m_window_style_rows: Dictionary = {}
var m_window_pane_depth_spin: SpinBox
var m_window_pane_color_picker: ColorPickerButton
var m_window_grid_rows_spin: SpinBox
var m_window_grid_cols_spin: SpinBox
var m_window_muntin_thickness_spin: SpinBox
var m_window_louver_count_spin: SpinBox
var m_window_louver_depth_spin: SpinBox
var m_window_transom_ratio_spin: SpinBox
var m_window_transom_rail_spin: SpinBox
var m_window_arch_steps_spin: SpinBox
var m_door_style_option: OptionButton
var m_door_width_spin: SpinBox
var m_door_height_spin: SpinBox
var m_door_frame_spin: SpinBox
var m_door_frame_protrusion_spin: SpinBox
var m_door_frame_color_picker: ColorPickerButton
var m_door_frame_sides_option: OptionButton
var m_door_style_header: Label
var m_door_style_rows: Dictionary = {}
var m_door_panel_depth_spin: SpinBox
var m_door_panel_color_picker: ColorPickerButton
var m_door_glazing_ratio_spin: SpinBox
var m_door_glass_depth_spin: SpinBox
var m_door_glass_color_picker: ColorPickerButton
var m_door_grid_rows_spin: SpinBox
var m_door_grid_cols_spin: SpinBox
var m_door_muntin_thickness_spin: SpinBox
var m_door_inset_rows_spin: SpinBox
var m_door_inset_cols_spin: SpinBox
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


func set_active_coordinator_path(_path_text: String) -> void:
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
	m_mode_option.tooltip_text = _shortcut_text_for_mode(MODE_SELECT)
	m_mode_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_mode_option.add_item("Select", 0)
	m_mode_option.set_item_metadata(0, MODE_SELECT)
	m_mode_option.add_item("Wall", 1)
	m_mode_option.set_item_metadata(1, MODE_WALL)
	m_mode_option.add_item("Floor", 2)
	m_mode_option.set_item_metadata(2, MODE_FLOOR)
	m_mode_option.add_item("Stairs", 3)
	m_mode_option.set_item_metadata(3, MODE_STAIRS)
	m_mode_option.add_item("Pillar", 4)
	m_mode_option.set_item_metadata(4, MODE_PILLAR)
	m_mode_option.add_item("Roof", 5)
	m_mode_option.set_item_metadata(5, MODE_ROOF)
	m_mode_option.add_item("Prop", 6)
	m_mode_option.set_item_metadata(6, MODE_PROP)
	m_mode_option.add_item("Door", 7)
	m_mode_option.set_item_metadata(7, MODE_DOOR)
	m_mode_option.add_item("Window", 8)
	m_mode_option.set_item_metadata(8, MODE_WINDOW)
	m_mode_option.item_selected.connect(_on_mode_selected)
	mode_row.add_child(m_mode_option)
	content.add_child(mode_row)

	var coordinator_button := Button.new()
	coordinator_button.text = "Add Building"
	coordinator_button.tooltip_text = "Add and select a new Building3D root."
	coordinator_button.pressed.connect(_on_create_coordinator)
	content.add_child(coordinator_button)

	_build_display_controls(content)

	m_wall_section = _make_tool_section(content)
	_build_wall_controls(m_wall_section)
	m_floor_section = _make_tool_section(content)
	_build_floor_controls(m_floor_section)
	m_stair_section = _make_tool_section(content)
	_build_stair_controls(m_stair_section)
	m_pillar_section = _make_tool_section(content)
	_build_pillar_controls(m_pillar_section)
	m_roof_section = _make_tool_section(content)
	_build_roof_controls(m_roof_section)
	m_prop_section = _make_tool_section(content)
	_build_prop_controls(m_prop_section)
	m_door_section = _make_tool_section(content)
	_build_door_controls(m_door_section)
	m_window_section = _make_tool_section(content)
	_build_window_controls(m_window_section)
	_update_visible_tool_section(MODE_SELECT)

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


func _make_tool_section(parent: VBoxContainer) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_child(HSeparator.new())
	parent.add_child(section)
	return section


func _build_display_controls(parent: VBoxContainer) -> void:
	parent.add_child(HSeparator.new())
	var header := Label.new()
	header.text = "Debug Display"
	parent.add_child(header)
	m_debug_wireframe_check = CheckBox.new()
	m_debug_wireframe_check.text = "Wireframe"
	m_debug_wireframe_check.tooltip_text = (
		"Show deduplicated triangle edges for generated building blocks and previews."
	)
	m_debug_wireframe_check.toggled.connect(_on_debug_wireframe_changed)
	parent.add_child(m_debug_wireframe_check)
	m_debug_wireframe_xray_check = CheckBox.new()
	m_debug_wireframe_xray_check.text = "X-ray wireframe"
	m_debug_wireframe_xray_check.tooltip_text = (
		"Draw hidden wireframe edges through geometry. Disabled is lighter and less cluttered."
	)
	m_debug_wireframe_xray_check.toggled.connect(_on_debug_wireframe_changed)
	parent.add_child(m_debug_wireframe_xray_check)
	m_debug_wireframe_color_picker = _make_color_picker(
		Color(0.05, 0.95, 1.0, 1.0)
	)
	m_debug_wireframe_color_picker.color_changed.connect(
		_on_debug_wireframe_color_changed
	)
	_add_labeled_control(
		parent,
		"Wire Color:",
		m_debug_wireframe_color_picker
	)
	_update_debug_wireframe_controls()


func _build_wall_controls(parent: VBoxContainer) -> void:
	var header := Label.new()
	header.text = "Wall Defaults"
	parent.add_child(header)

	m_wall_type_option = OptionButton.new()
	m_wall_type_option.add_item("Wall", 0)
	m_wall_type_option.set_item_metadata(0, WALL_TYPE_WALL)
	m_wall_type_option.add_item("Room", 1)
	m_wall_type_option.set_item_metadata(1, WALL_TYPE_ROOM)
	m_wall_type_option.item_selected.connect(_on_wall_type_selected)
	_add_labeled_control(
		parent,
		"Type:",
		m_wall_type_option,
		"Draw one wall span or four connected walls enclosing a rectangular room."
	)

	m_grid_spin = _make_spin(0.05, 8.0, 0.05, 0.5)
	_add_labeled_control(parent, "Grid:", m_grid_spin, "Snap size for drawing and editing wall endpoints.")
	m_grid_spin.value_changed.connect(_on_wall_setting_changed)

	m_wall_base_height_spin = _make_spin(-20.0, 20.0, 0.01, 0.0)
	m_wall_base_height_spin.tooltip_text = "Parent-local Y height for new wall bases."
	_add_labeled_control(parent, "Base Y:", m_wall_base_height_spin)
	m_wall_base_height_spin.value_changed.connect(_on_wall_setting_changed)

	m_wall_height_spin = _make_spin(0.1, 6.0, 0.05, 2.4)
	_add_labeled_control(parent, "Height:", m_wall_height_spin, "Vertical height of newly drawn walls.")
	m_wall_height_spin.value_changed.connect(_on_wall_setting_changed)

	m_wall_thickness_spin = _make_spin(0.03, 1.0, 0.01, 0.22)
	_add_labeled_control(parent, "Thickness:", m_wall_thickness_spin, "Depth of the wall measured across its center line.")
	m_wall_thickness_spin.value_changed.connect(_on_wall_setting_changed)

	m_wall_color_picker = _make_color_picker(Color(0.78, 0.68, 0.54, 1.0))
	m_wall_color_picker.color_changed.connect(_on_wall_color_changed)
	_add_labeled_control(parent, "Color:", m_wall_color_picker, "Vertex color applied to newly drawn walls.")

	m_lock_8_way_check = CheckBox.new()
	m_lock_8_way_check.text = "8-way lock"
	m_lock_8_way_check.tooltip_text = "Constrain new wall spans to horizontal, vertical, and diagonal directions."
	m_lock_8_way_check.button_pressed = true
	m_lock_8_way_check.toggled.connect(_on_wall_lock_changed)
	parent.add_child(m_lock_8_way_check)


func _build_floor_controls(parent: VBoxContainer) -> void:
	var header := Label.new()
	header.text = "Floor Defaults"
	parent.add_child(header)

	m_floor_type_option = OptionButton.new()
	m_floor_type_option.tooltip_text = "Choose whether the selected Rectangle/Polygon outline creates a slab or cuts a matching hole."
	m_floor_type_option.add_item("Solid", 0)
	m_floor_type_option.set_item_metadata(0, FLOOR_TYPE_SOLID)
	m_floor_type_option.add_item("Hole", 1)
	m_floor_type_option.set_item_metadata(1, FLOOR_TYPE_HOLE)
	m_floor_type_option.select(0)
	m_floor_type_option.item_selected.connect(_on_floor_type_selected)
	_add_labeled_control(parent, "Type:", m_floor_type_option)

	m_floor_style_option = OptionButton.new()
	m_floor_style_option.tooltip_text = "Choose a two-corner rectangle or a multi-vertex polygon footprint."
	m_floor_style_option.add_item("Rectangle", 0)
	m_floor_style_option.set_item_metadata(0, FLOOR_STYLE_RECTANGLE)
	m_floor_style_option.add_item("Polygon", 1)
	m_floor_style_option.set_item_metadata(1, FLOOR_STYLE_POLYGON)
	m_floor_style_option.select(0)
	m_floor_style_option.item_selected.connect(_on_floor_style_selected)
	_add_labeled_control(parent, "Style:", m_floor_style_option)

	m_floor_grid_spin = _make_spin(0.05, 8.0, 0.05, 0.5)
	_add_labeled_control(parent, "Grid:", m_floor_grid_spin, "Snap size for drawing and editing floor footprints.")
	m_floor_grid_spin.value_changed.connect(_on_floor_setting_changed)

	m_floor_base_height_spin = _make_spin(-20.0, 20.0, 0.01, 0.0)
	m_floor_base_height_spin.tooltip_text = "Parent-local Y height for new floor top surfaces."
	_add_labeled_control(parent, "Base Y:", m_floor_base_height_spin)
	m_floor_base_height_spin.value_changed.connect(_on_floor_setting_changed)

	m_floor_thickness_spin = _make_spin(0.01, 2.0, 0.01, 0.12)
	_add_labeled_control(parent, "Thickness:", m_floor_thickness_spin, "Thickness extending downward from the floor top surface.")
	m_floor_thickness_spin.value_changed.connect(_on_floor_setting_changed)

	m_floor_color_picker = _make_color_picker(Color(0.46, 0.40, 0.32, 1.0))
	m_floor_color_picker.color_changed.connect(_on_floor_color_changed)
	_add_labeled_control(parent, "Color:", m_floor_color_picker, "Vertex color applied to newly drawn floors.")


func _build_stair_controls(parent: VBoxContainer) -> void:
	var header := Label.new()
	header.text = "Stairs Defaults"
	parent.add_child(header)

	m_stair_grid_spin = _make_spin(0.05, 8.0, 0.05, 0.5)
	_add_labeled_control(parent, "Grid:", m_stair_grid_spin, "Snap size for drawing and editing stair footprints.")
	m_stair_grid_spin.value_changed.connect(_on_stair_setting_changed)

	m_stair_base_height_spin = _make_spin(-20.0, 20.0, 0.01, 0.0)
	m_stair_base_height_spin.tooltip_text = "Parent-local Y height for the lower stair entry."
	_add_labeled_control(parent, "Base Y:", m_stair_base_height_spin)
	m_stair_base_height_spin.value_changed.connect(_on_stair_setting_changed)

	m_stair_height_spin = _make_spin(0.05, 20.0, 0.01, 1.2)
	_add_labeled_control(parent, "Height:", m_stair_height_spin, "Total climb height from the lower entry to the top tread.")
	m_stair_height_spin.value_changed.connect(_on_stair_setting_changed)

	m_stair_step_count_spin = _make_spin(1.0, 64.0, 1.0, 6.0)
	_add_labeled_control(parent, "Steps:", m_stair_step_count_spin, "Number of risers/treads generated across the drawn stair run.")
	m_stair_step_count_spin.value_changed.connect(_on_stair_setting_changed)

	m_stair_thickness_spin = _make_spin(0.0, 2.0, 0.01, 0.12)
	_add_labeled_control(parent, "Thickness:", m_stair_thickness_spin, "Solid underside thickness extending below the lower stair entry.")
	m_stair_thickness_spin.value_changed.connect(_on_stair_setting_changed)

	m_stair_rotation_spin = _make_spin(-180.0, 180.0, 1.0, 0.0)
	m_stair_rotation_spin.tooltip_text = "Starting Y rotation for new stairs, in degrees."
	_add_labeled_control(parent, "Rotation:", m_stair_rotation_spin)
	m_stair_rotation_spin.value_changed.connect(_on_stair_setting_changed)

	m_stair_color_picker = _make_color_picker(Color(0.52, 0.46, 0.38, 1.0))
	m_stair_color_picker.color_changed.connect(_on_stair_color_changed)
	_add_labeled_control(parent, "Color:", m_stair_color_picker, "Vertex color applied to newly drawn stairs.")


func _build_pillar_controls(parent: VBoxContainer) -> void:
	var header := Label.new()
	header.text = "Pillar Defaults"
	parent.add_child(header)

	m_pillar_grid_spin = _make_spin(0.05, 8.0, 0.05, 0.5)
	_add_labeled_control(parent, "Grid:", m_pillar_grid_spin, "Snap size for placing and moving pillars.")
	m_pillar_grid_spin.value_changed.connect(_on_pillar_setting_changed)

	m_pillar_style_option = OptionButton.new()
	m_pillar_style_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_pillar_style_option.add_item("Round", 0)
	m_pillar_style_option.set_item_metadata(0, "round")
	m_pillar_style_option.add_item("Square", 1)
	m_pillar_style_option.set_item_metadata(1, "square")
	m_pillar_style_option.add_item("Octagonal", 2)
	m_pillar_style_option.set_item_metadata(2, "octagonal")
	m_pillar_style_option.add_item("Tapered", 3)
	m_pillar_style_option.set_item_metadata(3, "tapered")
	m_pillar_style_option.item_selected.connect(_on_pillar_style_selected)
	_add_labeled_control(parent, "Style:", m_pillar_style_option, "Pillar body shape used for newly placed pillars.")

	m_pillar_base_height_spin = _make_spin(-20.0, 20.0, 0.01, 0.0)
	m_pillar_base_height_spin.tooltip_text = "Parent-local Y height for new pillar bases."
	_add_labeled_control(parent, "Base Y:", m_pillar_base_height_spin)
	m_pillar_base_height_spin.value_changed.connect(_on_pillar_setting_changed)

	m_pillar_radius_spin = _make_spin(0.05, 4.0, 0.01, 0.25)
	m_pillar_radius_spin.tooltip_text = "Lower body radius."
	_add_labeled_control(parent, "Lower Radius:", m_pillar_radius_spin)
	m_pillar_radius_spin.value_changed.connect(_on_pillar_setting_changed)

	m_pillar_upper_radius_spin = _make_spin(0.0, 4.0, 0.01, 0.0)
	m_pillar_upper_radius_spin.tooltip_text = "Upper body radius. Set to 0 to use the selected style's default top radius."
	_add_labeled_control(parent, "Upper Radius:", m_pillar_upper_radius_spin)
	m_pillar_upper_radius_spin.value_changed.connect(_on_pillar_setting_changed)

	m_pillar_height_spin = _make_spin(0.1, 12.0, 0.05, 2.4)
	_add_labeled_control(parent, "Height:", m_pillar_height_spin, "Vertical height of newly placed pillars.")
	m_pillar_height_spin.value_changed.connect(_on_pillar_setting_changed)

	m_pillar_lower_rim_height_spin = _make_spin(0.0, 2.0, 0.01, 0.12)
	m_pillar_lower_rim_height_spin.tooltip_text = "Lower rim band height. Set height or outset to 0 to disable it."
	_add_labeled_control(parent, "Lower Rim H:", m_pillar_lower_rim_height_spin)
	m_pillar_lower_rim_height_spin.value_changed.connect(_on_pillar_setting_changed)

	m_pillar_lower_rim_outset_spin = _make_spin(0.0, 2.0, 0.01, 0.05)
	m_pillar_lower_rim_outset_spin.tooltip_text = "Lower rim radius added beyond the pillar body."
	_add_labeled_control(parent, "Lower Rim Out:", m_pillar_lower_rim_outset_spin)
	m_pillar_lower_rim_outset_spin.value_changed.connect(_on_pillar_setting_changed)

	m_pillar_upper_rim_height_spin = _make_spin(0.0, 2.0, 0.01, 0.12)
	m_pillar_upper_rim_height_spin.tooltip_text = "Upper rim band height. Set height or outset to 0 to disable it."
	_add_labeled_control(parent, "Upper Rim H:", m_pillar_upper_rim_height_spin)
	m_pillar_upper_rim_height_spin.value_changed.connect(_on_pillar_setting_changed)

	m_pillar_upper_rim_outset_spin = _make_spin(0.0, 2.0, 0.01, 0.05)
	m_pillar_upper_rim_outset_spin.tooltip_text = "Upper rim radius added beyond the pillar body."
	_add_labeled_control(parent, "Upper Rim Out:", m_pillar_upper_rim_outset_spin)
	m_pillar_upper_rim_outset_spin.value_changed.connect(_on_pillar_setting_changed)

	m_pillar_color_picker = _make_color_picker(Color(0.70, 0.64, 0.52, 1.0))
	m_pillar_color_picker.color_changed.connect(_on_pillar_color_changed)
	_add_labeled_control(parent, "Color:", m_pillar_color_picker, "Vertex color applied to newly placed pillars.")

	m_pillar_style_header = _add_style_properties_header(parent)
	m_pillar_sides_spin = _make_spin(3.0, 24.0, 1.0, 8.0)
	m_pillar_sides_row = _add_labeled_control(
		parent,
		"Sides:",
		m_pillar_sides_spin,
		"Number of sides used by round and tapered pillar styles."
	)
	m_pillar_sides_spin.value_changed.connect(_on_pillar_setting_changed)
	_update_pillar_style_controls()


func _build_roof_controls(parent: VBoxContainer) -> void:
	var header := Label.new()
	header.text = "Roof Defaults"
	parent.add_child(header)

	m_roof_grid_spin = _make_spin(0.05, 8.0, 0.05, 0.5)
	_add_labeled_control(parent, "Grid:", m_roof_grid_spin, "Snap size for drawing and editing roof footprints.")
	m_roof_grid_spin.value_changed.connect(_on_roof_setting_changed)

	m_roof_style_option = OptionButton.new()
	m_roof_style_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_roof_style_option.add_item("Flat", 0)
	m_roof_style_option.set_item_metadata(0, "flat")
	m_roof_style_option.add_item("Shed", 1)
	m_roof_style_option.set_item_metadata(1, "shed")
	m_roof_style_option.add_item("Gable", 2)
	m_roof_style_option.set_item_metadata(2, "gable")
	m_roof_style_option.add_item("Hip", 3)
	m_roof_style_option.set_item_metadata(3, "hip")
	m_roof_style_option.add_item("Dome", 4)
	m_roof_style_option.set_item_metadata(4, "dome")
	m_roof_style_option.select(2)
	m_roof_style_option.item_selected.connect(_on_roof_style_selected)
	_add_labeled_control(parent, "Style:", m_roof_style_option, "Roof shape used for newly drawn roof footprints.")

	m_roof_footprint_option = OptionButton.new()
	m_roof_footprint_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_roof_footprint_option.add_item("Rectangle", 0)
	m_roof_footprint_option.set_item_metadata(0, FLOOR_STYLE_RECTANGLE)
	m_roof_footprint_option.add_item("Polygon", 1)
	m_roof_footprint_option.set_item_metadata(1, FLOOR_STYLE_POLYGON)
	m_roof_footprint_option.select(0)
	m_roof_footprint_option.item_selected.connect(_on_roof_footprint_selected)
	m_roof_footprint_row = _add_labeled_control(
		parent,
		"Footprint:",
		m_roof_footprint_option,
		"Rectangle and Polygon only change how a Flat roof is created."
	)

	m_roof_base_height_spin = _make_spin(-20.0, 20.0, 0.01, 2.4)
	m_roof_base_height_spin.tooltip_text = "Parent-local Y height for new roof eaves."
	_add_labeled_control(parent, "Base Y:", m_roof_base_height_spin)
	m_roof_base_height_spin.value_changed.connect(_on_roof_setting_changed)

	m_roof_thickness_spin = _make_spin(0.02, 2.0, 0.01, 0.12)
	_add_labeled_control(parent, "Thickness:", m_roof_thickness_spin, "Thickness extending downward from the generated roof surface.")
	m_roof_thickness_spin.value_changed.connect(_on_roof_setting_changed)

	m_roof_overhang_spin = _make_spin(0.0, 4.0, 0.01, 0.2)
	_add_labeled_control(parent, "Overhang:", m_roof_overhang_spin, "Distance the roof eaves extend beyond the drawn footprint.")
	m_roof_overhang_spin.value_changed.connect(_on_roof_setting_changed)

	m_roof_rotation_spin = _make_spin(-180.0, 180.0, 1.0, 0.0)
	m_roof_rotation_spin.tooltip_text = "Starting Y rotation for new roofs, in degrees."
	_add_labeled_control(parent, "Rotation:", m_roof_rotation_spin)
	m_roof_rotation_spin.value_changed.connect(_on_roof_setting_changed)

	m_roof_color_picker = _make_color_picker(Color(0.50, 0.34, 0.25, 1.0))
	m_roof_color_picker.color_changed.connect(_on_roof_color_changed)
	_add_labeled_control(parent, "Color:", m_roof_color_picker, "Vertex color applied to newly drawn roofs.")

	m_roof_style_header = _add_style_properties_header(parent)
	m_roof_height_spin = _make_spin(0.0, 89.0, 1.0, DEFAULT_ROOF_ANGLE_DEGREES)
	m_roof_height_spin.tooltip_text = "Roof face angle in degrees for shed, gable, hip, and dome roofs. A 45-degree dome is hemispherical on a square footprint."
	m_roof_angle_row = _add_labeled_control(parent, "Angle:", m_roof_height_spin)
	m_roof_height_spin.value_changed.connect(_on_roof_setting_changed)

	m_roof_hip_gable_height_spin = _make_spin(0.0, 20.0, 0.01, 0.0)
	m_roof_hip_gable_height_row = _add_labeled_control(
		parent,
		"Gable Drop:",
		m_roof_hip_gable_height_spin,
		"Vertical drop from a hip roof peak to the clipped gable base. Positive values extend the ridge while keeping roof faces at the selected angle."
	)
	m_roof_hip_gable_height_spin.value_changed.connect(_on_roof_setting_changed)
	_update_roof_style_controls()


func _build_prop_controls(parent: VBoxContainer) -> void:
	var header := Label.new()
	header.text = "Prop Palette"
	parent.add_child(header)

	var palette_root_row := HBoxContainer.new()
	var palette_root_label := Label.new()
	palette_root_label.text = "Folder:"
	palette_root_label.custom_minimum_size = Vector2(84.0, 0.0)
	palette_root_label.tooltip_text = "Resource folder scanned for prop palette scene files."
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
	palette_root_browse.tooltip_text = "Choose the folder scanned by the prop palette."
	palette_root_browse.pressed.connect(_on_browse_palette_root)
	palette_root_row.add_child(palette_root_browse)
	parent.add_child(palette_root_row)

	var scene_row := HBoxContainer.new()
	m_prop_path_edit = LineEdit.new()
	m_prop_path_edit.placeholder_text = DEFAULT_PROP_PALETTE_ROOT.path_join("...")
	m_prop_path_edit.tooltip_text = "Scene file placed by the Prop tool."
	m_prop_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_prop_path_edit.text_changed.connect(_on_prop_setting_changed)
	scene_row.add_child(m_prop_path_edit)

	var browse_button := Button.new()
	browse_button.text = "Browse"
	browse_button.tooltip_text = "Choose a prop scene file to place."
	browse_button.pressed.connect(_on_browse_scene)
	scene_row.add_child(browse_button)
	parent.add_child(scene_row)

	var scan_button := Button.new()
	scan_button.text = "Rescan Palette"
	scan_button.tooltip_text = "Refresh the prop palette list from the configured folder."
	scan_button.pressed.connect(_scan_palette)
	parent.add_child(scan_button)

	m_palette_list = ItemList.new()
	m_palette_list.custom_minimum_size = Vector2(0, 180)
	m_palette_list.tooltip_text = "Prop scene files found in the configured palette folder."
	m_palette_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m_palette_list.item_selected.connect(_on_palette_item_selected)
	parent.add_child(m_palette_list)

	m_prop_clearance_spin = _make_spin(0.0, 5.0, 0.05, 0.25)
	_add_labeled_control(parent, "Clearance:", m_prop_clearance_spin, "Forward offset from the wall face when placing props on walls.")
	m_prop_clearance_spin.value_changed.connect(_on_prop_clearance_changed)


func _build_window_controls(parent: VBoxContainer) -> void:
	var header := Label.new()
	header.text = "Window Defaults"
	parent.add_child(header)

	m_window_style_option = OptionButton.new()
	m_window_style_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_window_style_option.add_item("Single Window", 0)
	m_window_style_option.set_item_metadata(0, "single_window")
	m_window_style_option.add_item("Double Window", 1)
	m_window_style_option.set_item_metadata(1, "double_window")
	m_window_style_option.add_item("Grid Window", 2)
	m_window_style_option.set_item_metadata(2, "grid_window")
	m_window_style_option.add_item("Louvered Window", 3)
	m_window_style_option.set_item_metadata(3, "louvered_window")
	m_window_style_option.add_item("Transom Window", 4)
	m_window_style_option.set_item_metadata(4, "transom_window")
	m_window_style_option.add_item("Arched Window", 5)
	m_window_style_option.set_item_metadata(5, "arched_window")
	m_window_style_option.add_item("Window Frame", 6)
	m_window_style_option.set_item_metadata(6, "frame")
	m_window_style_option.item_selected.connect(_on_window_style_selected)
	_add_labeled_control(parent, "Style:", m_window_style_option, "Window opening or frame style to place on a wall.")

	m_window_width_spin = _make_spin(0.1, 8.0, 0.01, _window_default_width("single_window"))
	_add_labeled_control(parent, "Width:", m_window_width_spin, "Opening width measured along the wall.")
	m_window_width_spin.value_changed.connect(_on_window_setting_changed)

	m_window_height_spin = _make_spin(0.1, 8.0, 0.01, 1.0)
	_add_labeled_control(parent, "Height:", m_window_height_spin, "Opening height measured upward from the sill.")
	m_window_height_spin.value_changed.connect(_on_window_setting_changed)

	m_window_frame_spin = _make_spin(0.01, 1.0, 0.01, 0.08)
	_add_labeled_control(parent, "Frame:", m_window_frame_spin, "Visible frame thickness around the opening.")
	m_window_frame_spin.value_changed.connect(_on_window_setting_changed)

	m_window_frame_protrusion_spin = _make_spin(0.0, 0.5, 0.005, 0.02)
	_add_labeled_control(
		parent,
		"Frame Outset:",
		m_window_frame_protrusion_spin,
		"Distance the frame casing projects beyond the wall face."
	)
	m_window_frame_protrusion_spin.value_changed.connect(_on_window_setting_changed)

	m_window_frame_color_picker = _make_color_picker(Color(0.86, 0.92, 0.94, 1.0))
	_add_labeled_control(parent, "Frame Color:", m_window_frame_color_picker, "Color of the window frame casing.")
	m_window_frame_color_picker.color_changed.connect(_on_window_style_color_changed)

	m_window_sill_spin = _make_spin(0.0, 10.0, 0.01, 0.9)
	m_window_sill_spin.tooltip_text = "Height of the opening's bottom edge above the wall base."
	_add_labeled_control(parent, "Sill:", m_window_sill_spin)
	m_window_sill_spin.value_changed.connect(_on_window_setting_changed)

	m_window_frame_sides_option = _make_frame_sides_option()
	_add_labeled_control(parent, "Frame Sides:", m_window_frame_sides_option, "Show the frame casing on just the placed wall face, or on both faces.")
	m_window_frame_sides_option.item_selected.connect(_on_window_frame_sides_selected)

	m_window_style_header = _add_style_properties_header(parent)

	m_window_pane_depth_spin = _make_spin(0.01, 0.5, 0.01, 0.03)
	m_window_style_rows["pane_depth"] = _add_labeled_control(
		parent, "Pane Depth:", m_window_pane_depth_spin, "Depth of generated window glass."
	)
	m_window_pane_depth_spin.value_changed.connect(_on_window_setting_changed)

	m_window_pane_color_picker = _make_color_picker(Color(0.58, 0.82, 0.95, 0.52))
	m_window_style_rows["pane_color"] = _add_labeled_control(
		parent, "Pane Color:", m_window_pane_color_picker, "Color and opacity of generated window glass."
	)
	m_window_pane_color_picker.color_changed.connect(_on_window_style_color_changed)

	m_window_grid_rows_spin = _make_spin(0.0, 8.0, 1.0, 2.0)
	m_window_style_rows["grid_rows"] = _add_labeled_control(
		parent, "Grid Rows:", m_window_grid_rows_spin, "Horizontal muntin rows inside a grid window."
	)
	m_window_grid_rows_spin.value_changed.connect(_on_window_setting_changed)

	m_window_grid_cols_spin = _make_spin(0.0, 8.0, 1.0, 1.0)
	m_window_style_rows["grid_cols"] = _add_labeled_control(
		parent, "Grid Cols:", m_window_grid_cols_spin, "Vertical muntin columns inside a grid window."
	)
	m_window_grid_cols_spin.value_changed.connect(_on_window_setting_changed)

	m_window_muntin_thickness_spin = _make_spin(0.005, 0.3, 0.005, 0.03)
	m_window_style_rows["muntin"] = _add_labeled_control(
		parent, "Muntin:", m_window_muntin_thickness_spin, "Thickness of grid-window muntin bars."
	)
	m_window_muntin_thickness_spin.value_changed.connect(_on_window_setting_changed)

	m_window_louver_count_spin = _make_spin(1.0, 16.0, 1.0, 6.0)
	m_window_style_rows["louver_count"] = _add_labeled_control(
		parent, "Louvers:", m_window_louver_count_spin, "Number of horizontal louver slats."
	)
	m_window_louver_count_spin.value_changed.connect(_on_window_setting_changed)

	m_window_louver_depth_spin = _make_spin(0.01, 0.5, 0.01, 0.03)
	m_window_style_rows["louver_depth"] = _add_labeled_control(
		parent, "Louver Depth:", m_window_louver_depth_spin, "Depth of generated louver slats."
	)
	m_window_louver_depth_spin.value_changed.connect(_on_window_setting_changed)

	m_window_transom_ratio_spin = _make_spin(0.0, 0.9, 0.01, 0.28)
	m_window_style_rows["transom_ratio"] = _add_labeled_control(
		parent, "Transom Ratio:", m_window_transom_ratio_spin, "Fraction of the pane height above the transom rail."
	)
	m_window_transom_ratio_spin.value_changed.connect(_on_window_setting_changed)

	m_window_transom_rail_spin = _make_spin(0.005, 0.3, 0.005, 0.03)
	m_window_style_rows["transom_rail"] = _add_labeled_control(
		parent, "Transom Rail:", m_window_transom_rail_spin, "Thickness of the transom rail."
	)
	m_window_transom_rail_spin.value_changed.connect(_on_window_setting_changed)

	m_window_arch_steps_spin = _make_spin(1.0, 6.0, 1.0, 3.0)
	m_window_style_rows["arch_steps"] = _add_labeled_control(
		parent, "Arch Steps:", m_window_arch_steps_spin, "Number of stepped bands forming the window arch."
	)
	m_window_arch_steps_spin.value_changed.connect(_on_window_setting_changed)
	_update_window_style_controls()


func _build_door_controls(parent: VBoxContainer) -> void:
	var header := Label.new()
	header.text = "Door Defaults"
	parent.add_child(header)

	m_door_style_option = OptionButton.new()
	m_door_style_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_door_style_option.add_item("Single Door", 0)
	m_door_style_option.set_item_metadata(0, "single_door")
	m_door_style_option.add_item("Double Door", 1)
	m_door_style_option.set_item_metadata(1, "double_door")
	m_door_style_option.add_item("Glazed Door", 2)
	m_door_style_option.set_item_metadata(2, "glazed_door")
	m_door_style_option.add_item("Cross Glazed Door", 3)
	m_door_style_option.set_item_metadata(3, "glazed_grid_door")
	m_door_style_option.add_item("Panel Door", 4)
	m_door_style_option.set_item_metadata(4, "panel_door")
	m_door_style_option.add_item("Dutch Door", 5)
	m_door_style_option.set_item_metadata(5, "dutch_door")
	m_door_style_option.add_item("Single Door Frame", 6)
	m_door_style_option.set_item_metadata(6, "single_frame")
	m_door_style_option.add_item("Double Door Frame", 7)
	m_door_style_option.set_item_metadata(7, "double_frame")
	m_door_style_option.item_selected.connect(_on_door_style_selected)
	_add_labeled_control(parent, "Style:", m_door_style_option, "Door opening or frame style to place on a wall.")

	m_door_width_spin = _make_spin(0.3, 8.0, 0.01, _door_default_width("single_door"))
	_add_labeled_control(parent, "Width:", m_door_width_spin, "Door opening width measured along the wall.")
	m_door_width_spin.value_changed.connect(_on_door_setting_changed)

	m_door_height_spin = _make_spin(0.3, 8.0, 0.01, 2.1)
	_add_labeled_control(parent, "Height:", m_door_height_spin, "Door opening height measured from the wall base.")
	m_door_height_spin.value_changed.connect(_on_door_setting_changed)

	m_door_frame_spin = _make_spin(0.01, 1.0, 0.01, 0.08)
	_add_labeled_control(parent, "Frame:", m_door_frame_spin, "Visible frame thickness around the door opening.")
	m_door_frame_spin.value_changed.connect(_on_door_setting_changed)

	m_door_frame_protrusion_spin = _make_spin(0.0, 0.5, 0.005, 0.02)
	_add_labeled_control(
		parent,
		"Frame Outset:",
		m_door_frame_protrusion_spin,
		"Distance the frame casing projects beyond the wall face."
	)
	m_door_frame_protrusion_spin.value_changed.connect(_on_door_setting_changed)

	m_door_frame_color_picker = _make_color_picker(Color(0.86, 0.92, 0.94, 1.0))
	_add_labeled_control(parent, "Frame Color:", m_door_frame_color_picker, "Color of the door frame casing.")
	m_door_frame_color_picker.color_changed.connect(_on_door_style_color_changed)

	m_door_frame_sides_option = _make_frame_sides_option()
	_add_labeled_control(parent, "Frame Sides:", m_door_frame_sides_option, "Show the frame casing on just the placed wall face, or on both faces.")
	m_door_frame_sides_option.item_selected.connect(_on_door_frame_sides_selected)

	m_door_style_header = _add_style_properties_header(parent)

	m_door_panel_depth_spin = _make_spin(0.01, 0.5, 0.01, 0.05)
	m_door_style_rows["panel_depth"] = _add_labeled_control(
		parent, "Panel Depth:", m_door_panel_depth_spin, "Depth of generated solid door leaves."
	)
	m_door_panel_depth_spin.value_changed.connect(_on_door_setting_changed)

	m_door_panel_color_picker = _make_color_picker(Color(0.50, 0.34, 0.20, 1.0))
	m_door_style_rows["panel_color"] = _add_labeled_control(
		parent, "Panel Color:", m_door_panel_color_picker, "Color of generated door leaves."
	)
	m_door_panel_color_picker.color_changed.connect(_on_door_style_color_changed)

	m_door_glazing_ratio_spin = _make_spin(0.0, 0.95, 0.01, 0.55)
	m_door_style_rows["glazing_ratio"] = _add_labeled_control(
		parent, "Glazing Ratio:", m_door_glazing_ratio_spin, "Fraction of each glazed door leaf occupied by glass."
	)
	m_door_glazing_ratio_spin.value_changed.connect(_on_door_setting_changed)

	m_door_glass_depth_spin = _make_spin(0.01, 0.5, 0.01, 0.03)
	m_door_style_rows["glass_depth"] = _add_labeled_control(
		parent, "Glass Depth:", m_door_glass_depth_spin, "Depth of generated door glass."
	)
	m_door_glass_depth_spin.value_changed.connect(_on_door_setting_changed)

	m_door_glass_color_picker = _make_color_picker(Color(0.58, 0.82, 0.95, 0.52))
	m_door_style_rows["glass_color"] = _add_labeled_control(
		parent, "Glass Color:", m_door_glass_color_picker, "Color and opacity of generated door glass."
	)
	m_door_glass_color_picker.color_changed.connect(_on_door_style_color_changed)

	m_door_grid_rows_spin = _make_spin(0.0, 8.0, 1.0, 2.0)
	m_door_style_rows["grid_rows"] = _add_labeled_control(
		parent, "Grid Rows:", m_door_grid_rows_spin, "Horizontal muntin rows inside a cross-glazed door."
	)
	m_door_grid_rows_spin.value_changed.connect(_on_door_setting_changed)

	m_door_grid_cols_spin = _make_spin(0.0, 8.0, 1.0, 1.0)
	m_door_style_rows["grid_cols"] = _add_labeled_control(
		parent, "Grid Cols:", m_door_grid_cols_spin, "Vertical muntin columns inside a cross-glazed door."
	)
	m_door_grid_cols_spin.value_changed.connect(_on_door_setting_changed)

	m_door_muntin_thickness_spin = _make_spin(0.005, 0.3, 0.005, 0.03)
	m_door_style_rows["muntin"] = _add_labeled_control(
		parent, "Muntin:", m_door_muntin_thickness_spin, "Thickness of cross-glazed muntin bars."
	)
	m_door_muntin_thickness_spin.value_changed.connect(_on_door_setting_changed)

	m_door_inset_rows_spin = _make_spin(0.0, 4.0, 1.0, 3.0)
	m_door_style_rows["inset_rows"] = _add_labeled_control(
		parent, "Inset Rows:", m_door_inset_rows_spin, "Rows of raised inset details on a panel door."
	)
	m_door_inset_rows_spin.value_changed.connect(_on_door_setting_changed)

	m_door_inset_cols_spin = _make_spin(0.0, 3.0, 1.0, 2.0)
	m_door_style_rows["inset_cols"] = _add_labeled_control(
		parent, "Inset Cols:", m_door_inset_cols_spin, "Columns of raised inset details on a panel door."
	)
	m_door_inset_cols_spin.value_changed.connect(_on_door_setting_changed)
	_update_door_style_controls()


func _make_spin(min_value: float, max_value: float, step: float, value: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	spin.value = value
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spin


func _make_color_picker(initial_color: Color) -> ColorPickerButton:
	var picker := ColorPickerButton.new()
	picker.color = initial_color
	picker.text = " "
	picker.tooltip_text = "Choose color"
	picker.custom_minimum_size = Vector2(COLOR_SWATCH_MIN_WIDTH, 0.0)
	picker.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	picker.size_flags_vertical = Control.SIZE_FILL
	picker.resized.connect(_on_color_picker_resized.bind(picker))
	_update_color_picker_icon(picker)
	return picker


func _on_color_picker_resized(picker: ColorPickerButton) -> void:
	_sync_color_picker_minimum_width(picker)


func _update_color_picker_icon(picker: ColorPickerButton) -> void:
	if picker == null:
		return
	picker.icon = _make_color_swatch_texture(picker.color)
	_sync_color_picker_minimum_width(picker)


func _sync_color_picker_minimum_width(picker: ColorPickerButton) -> void:
	if picker == null:
		return
	var required_width := maxf(
		COLOR_SWATCH_MIN_WIDTH,
		ceilf(maxf(picker.get_combined_minimum_size().y, picker.size.y))
	)
	if is_equal_approx(picker.custom_minimum_size.x, required_width) and is_zero_approx(picker.custom_minimum_size.y):
		return
	picker.custom_minimum_size = Vector2(required_width, 0.0)


func _refresh_color_picker_icons() -> void:
	_update_color_picker_icon(m_debug_wireframe_color_picker)
	_update_color_picker_icon(m_wall_color_picker)
	_update_color_picker_icon(m_floor_color_picker)
	_update_color_picker_icon(m_stair_color_picker)
	_update_color_picker_icon(m_pillar_color_picker)
	_update_color_picker_icon(m_roof_color_picker)
	_update_color_picker_icon(m_window_frame_color_picker)
	_update_color_picker_icon(m_window_pane_color_picker)
	_update_color_picker_icon(m_door_frame_color_picker)
	_update_color_picker_icon(m_door_panel_color_picker)
	_update_color_picker_icon(m_door_glass_color_picker)


func _make_color_swatch_texture(color: Color) -> Texture2D:
	var size := COLOR_SWATCH_ICON_SIZE
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var opaque_color := Color(color.r, color.g, color.b, 1.0)
	for y in range(size):
		for x in range(size):
			var checker_dark := (int(x / 4) + int(y / 4)) % 2 == 0
			var checker_color := Color(0.64, 0.64, 0.64, 1.0) if checker_dark else Color(0.86, 0.86, 0.86, 1.0)
			image.set_pixel(x, y, checker_color.lerp(opaque_color, color.a))
	var luminance := color.r * 0.299 + color.g * 0.587 + color.b * 0.114
	var border_color := Color(0.0, 0.0, 0.0, 0.85) if luminance > 0.58 else Color(1.0, 1.0, 1.0, 0.85)
	for index in range(size):
		image.set_pixel(index, 0, border_color)
		image.set_pixel(index, size - 1, border_color)
		image.set_pixel(0, index, border_color)
		image.set_pixel(size - 1, index, border_color)
	return ImageTexture.create_from_image(image)


func _add_labeled_control(
	parent: VBoxContainer,
	label_text: String,
	control: Control,
	description: String = ""
) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(84.0, 0.0)
	var tooltip := description.strip_edges()
	if tooltip.is_empty():
		tooltip = control.tooltip_text.strip_edges()
	if !tooltip.is_empty():
		row.tooltip_text = tooltip
		label.tooltip_text = tooltip
		control.tooltip_text = tooltip
	row.add_child(label)
	row.add_child(control)
	parent.add_child(row)
	return row


func _add_style_properties_header(parent: VBoxContainer) -> Label:
	var header := Label.new()
	header.text = "Style Properties"
	parent.add_child(header)
	return header


func _on_mode_selected(index: int) -> void:
	var mode := String(m_mode_option.get_item_metadata(index))
	_update_tool_tooltip_for_mode(mode)
	_update_visible_tool_section(mode)
	tool_mode_changed.emit(mode)


func select_tool_mode(mode: String) -> void:
	# Programmatic entry point (used by the 3D viewport toolbar) that mirrors a
	# user choosing a tool in the dock's option button.
	var index := _index_for_tool_mode(mode)
	if index < 0:
		return
	if m_mode_option != null:
		m_mode_option.select(index)
	_update_tool_tooltip_for_mode(mode)
	_update_visible_tool_section(mode)
	tool_mode_changed.emit(mode)


func _index_for_tool_mode(mode: String) -> int:
	if m_mode_option == null:
		return -1
	for i in range(m_mode_option.item_count):
		if String(m_mode_option.get_item_metadata(i)) == mode:
			return i
	return -1


func _update_tool_tooltip_for_mode(mode: String) -> void:
	if m_mode_option == null:
		return
	m_mode_option.tooltip_text = _shortcut_text_for_mode(mode)


func _shortcut_text_for_mode(mode: String) -> String:
	match mode:
		MODE_WALL:
			return SHORTCUTS_WALL_TEXT
		MODE_FLOOR:
			return SHORTCUTS_FLOOR_TEXT
		MODE_STAIRS:
			return SHORTCUTS_STAIRS_TEXT
		MODE_PILLAR:
			return SHORTCUTS_PILLAR_TEXT
		MODE_ROOF:
			return SHORTCUTS_ROOF_TEXT
		MODE_PROP:
			return SHORTCUTS_PROP_TEXT
		MODE_WINDOW:
			return SHORTCUTS_WINDOW_TEXT
		MODE_DOOR:
			return SHORTCUTS_DOOR_TEXT
		_:
			return SHORTCUTS_SELECT_TEXT


func _update_visible_tool_section(mode: String) -> void:
	if m_wall_section != null:
		m_wall_section.visible = mode == MODE_WALL
	if m_floor_section != null:
		m_floor_section.visible = mode == MODE_FLOOR
	if m_stair_section != null:
		m_stair_section.visible = mode == MODE_STAIRS
	if m_pillar_section != null:
		m_pillar_section.visible = mode == MODE_PILLAR
	if m_roof_section != null:
		m_roof_section.visible = mode == MODE_ROOF
	if m_prop_section != null:
		m_prop_section.visible = mode == MODE_PROP
	if m_window_section != null:
		m_window_section.visible = mode == MODE_WINDOW
	if m_door_section != null:
		m_door_section.visible = mode == MODE_DOOR


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


func _on_wall_type_selected(_index: int) -> void:
	_update_wall_type_controls()
	_emit_wall_settings()


func _on_wall_color_changed(_color: Color) -> void:
	_update_color_picker_icon(m_wall_color_picker)
	_emit_wall_settings()


func _on_wall_lock_changed(_pressed: bool) -> void:
	_emit_wall_settings()


func _on_floor_type_selected(_index: int) -> void:
	_update_floor_type_controls()
	_emit_floor_settings()


func _on_floor_style_selected(_index: int) -> void:
	_emit_floor_settings()


func _on_floor_setting_changed(_value: float) -> void:
	_emit_floor_settings()


func _on_floor_color_changed(_color: Color) -> void:
	_update_color_picker_icon(m_floor_color_picker)
	_emit_floor_settings()


func _on_stair_setting_changed(_value: float) -> void:
	_emit_stair_settings()


func _on_stair_color_changed(_color: Color) -> void:
	_update_color_picker_icon(m_stair_color_picker)
	_emit_stair_settings()


func _on_pillar_setting_changed(_value: float) -> void:
	_emit_pillar_settings()


func _on_pillar_style_selected(_index: int) -> void:
	_update_pillar_style_controls()
	_emit_pillar_settings()


func _on_pillar_color_changed(_color: Color) -> void:
	_update_color_picker_icon(m_pillar_color_picker)
	_emit_pillar_settings()


func _on_roof_setting_changed(_value: float) -> void:
	_emit_roof_settings()


func _on_roof_style_selected(_index: int) -> void:
	_update_roof_style_controls()
	_emit_roof_settings()


func _on_roof_footprint_selected(_index: int) -> void:
	_emit_roof_settings()


func _on_roof_color_changed(_color: Color) -> void:
	_update_color_picker_icon(m_roof_color_picker)
	_emit_roof_settings()


func _on_debug_wireframe_changed(_pressed: bool) -> void:
	_update_debug_wireframe_controls()
	_emit_display_settings()


func _on_debug_wireframe_color_changed(_color: Color) -> void:
	_update_color_picker_icon(m_debug_wireframe_color_picker)
	_emit_display_settings()


func _update_debug_wireframe_controls() -> void:
	if m_debug_wireframe_xray_check != null:
		m_debug_wireframe_xray_check.disabled = (
			m_debug_wireframe_check == null
			or !m_debug_wireframe_check.button_pressed
		)
	if m_debug_wireframe_color_picker != null:
		m_debug_wireframe_color_picker.disabled = (
			m_debug_wireframe_check == null
			or !m_debug_wireframe_check.button_pressed
		)


func _on_prop_setting_changed(_value: String) -> void:
	_emit_prop_settings()


func _on_prop_clearance_changed(_value: float) -> void:
	_emit_prop_settings()


func _on_window_setting_changed(_value: float) -> void:
	_emit_window_settings()


func _on_window_style_selected(_index: int) -> void:
	var style := _selected_window_style()
	if m_window_width_spin != null:
		m_window_width_spin.value = _window_default_width(style)
	_update_window_style_controls()
	_emit_window_settings()


func _on_door_style_selected(_index: int) -> void:
	var style := _selected_door_style()
	if m_door_width_spin != null:
		m_door_width_spin.value = _door_default_width(style)
	_update_door_style_controls()
	_emit_door_settings()


func _on_door_setting_changed(_value: float) -> void:
	_emit_door_settings()


func _on_window_style_color_changed(_color: Color) -> void:
	_update_color_picker_icon(m_window_frame_color_picker)
	_update_color_picker_icon(m_window_pane_color_picker)
	_emit_window_settings()


func _on_door_style_color_changed(_color: Color) -> void:
	_update_color_picker_icon(m_door_frame_color_picker)
	_update_color_picker_icon(m_door_panel_color_picker)
	_update_color_picker_icon(m_door_glass_color_picker)
	_emit_door_settings()


func _on_window_frame_sides_selected(_index: int) -> void:
	_emit_window_settings()


func _on_door_frame_sides_selected(_index: int) -> void:
	_emit_door_settings()


func _make_frame_sides_option() -> OptionButton:
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.add_item("Placed Side", 0)
	option.set_item_metadata(0, 0)
	option.add_item("Both Sides", 1)
	option.set_item_metadata(1, 1)
	return option


func _selected_frame_sides(option: OptionButton) -> int:
	if option == null or option.selected < 0:
		return 0
	return int(option.get_item_metadata(option.selected))


func _select_frame_sides(option: OptionButton, value: int) -> void:
	if option == null:
		return
	for index in range(option.get_item_count()):
		if int(option.get_item_metadata(index)) == value:
			option.select(index)
			return
	option.select(0)


func _emit_all_settings() -> void:
	_emit_display_settings()
	_emit_wall_settings()
	_emit_floor_settings()
	_emit_stair_settings()
	_emit_pillar_settings()
	_emit_roof_settings()
	_emit_prop_settings()
	_emit_window_settings()
	_emit_door_settings()


func _emit_display_settings() -> void:
	display_settings_changed.emit({
		"wireframe": (
			m_debug_wireframe_check != null
			and m_debug_wireframe_check.button_pressed
		),
		"wireframe_xray": (
			m_debug_wireframe_xray_check != null
			and m_debug_wireframe_xray_check.button_pressed
		),
		"wireframe_color": (
			m_debug_wireframe_color_picker.color
			if m_debug_wireframe_color_picker != null
			else Color(0.05, 0.95, 1.0, 1.0)
		),
	})


func _emit_wall_settings() -> void:
	wall_settings_changed.emit({
		"grid_step": float(m_grid_spin.value),
		"type": _selected_wall_type(),
		"base_height": float(m_wall_base_height_spin.value),
		"height": float(m_wall_height_spin.value),
		"thickness": float(m_wall_thickness_spin.value),
		"color": m_wall_color_picker.color,
		"lock_8_way": m_lock_8_way_check.button_pressed,
	})


func _emit_floor_settings() -> void:
	floor_settings_changed.emit({
		"grid_step": float(m_floor_grid_spin.value),
		"type": _selected_floor_type(),
		"style": _selected_floor_style(),
		"base_height": float(m_floor_base_height_spin.value),
		"thickness": float(m_floor_thickness_spin.value),
		"color": m_floor_color_picker.color,
	})


func _emit_stair_settings() -> void:
	stair_settings_changed.emit({
		"grid_step": float(m_stair_grid_spin.value),
		"base_height": float(m_stair_base_height_spin.value),
		"height": float(m_stair_height_spin.value),
		"step_count": int(roundf(m_stair_step_count_spin.value)),
		"thickness": float(m_stair_thickness_spin.value),
		"rotation_degrees": float(m_stair_rotation_spin.value),
		"color": m_stair_color_picker.color,
	})


func _emit_pillar_settings() -> void:
	pillar_settings_changed.emit({
		"grid_step": float(m_pillar_grid_spin.value),
		"style": _selected_pillar_style(),
		"base_height": float(m_pillar_base_height_spin.value),
		"radius": float(m_pillar_radius_spin.value),
		"upper_radius": float(m_pillar_upper_radius_spin.value),
		"height": float(m_pillar_height_spin.value),
		"sides": int(roundf(m_pillar_sides_spin.value)),
		"lower_rim_height": float(m_pillar_lower_rim_height_spin.value),
		"lower_rim_outset": float(m_pillar_lower_rim_outset_spin.value),
		"upper_rim_height": float(m_pillar_upper_rim_height_spin.value),
		"upper_rim_outset": float(m_pillar_upper_rim_outset_spin.value),
		"color": m_pillar_color_picker.color,
	})


func _emit_roof_settings() -> void:
	roof_settings_changed.emit({
		"grid_step": float(m_roof_grid_spin.value),
		"style": _selected_roof_style(),
		"footprint_style": _selected_roof_footprint_style(),
		"base_height": float(m_roof_base_height_spin.value),
		"height": float(m_roof_height_spin.value),
		"thickness": float(m_roof_thickness_spin.value),
		"overhang": float(m_roof_overhang_spin.value),
		"hip_gable_height": float(m_roof_hip_gable_height_spin.value),
		"rotation_degrees": float(m_roof_rotation_spin.value),
		"color": m_roof_color_picker.color,
	})


func _selected_wall_type() -> String:
	if m_wall_type_option == null or m_wall_type_option.selected < 0:
		return WALL_TYPE_WALL
	return String(m_wall_type_option.get_item_metadata(m_wall_type_option.selected))


func _select_wall_type(wall_type: String) -> void:
	if m_wall_type_option == null:
		return
	for index in range(m_wall_type_option.get_item_count()):
		if String(m_wall_type_option.get_item_metadata(index)) == wall_type:
			m_wall_type_option.select(index)
			_update_wall_type_controls()
			return
	m_wall_type_option.select(0)
	_update_wall_type_controls()


func _update_wall_type_controls() -> void:
	if m_lock_8_way_check != null:
		m_lock_8_way_check.disabled = _selected_wall_type() == WALL_TYPE_ROOM


func _selected_floor_type() -> String:
	if m_floor_type_option == null or m_floor_type_option.selected < 0:
		return FLOOR_TYPE_SOLID
	return String(m_floor_type_option.get_item_metadata(m_floor_type_option.selected))


func _select_floor_type(floor_type: String) -> void:
	if m_floor_type_option == null:
		return
	for index in range(m_floor_type_option.get_item_count()):
		if String(m_floor_type_option.get_item_metadata(index)) == floor_type:
			m_floor_type_option.select(index)
			_update_floor_type_controls()
			return
	m_floor_type_option.select(0)
	_update_floor_type_controls()


func _selected_floor_style() -> String:
	if m_floor_style_option == null or m_floor_style_option.selected < 0:
		return FLOOR_STYLE_RECTANGLE
	return String(m_floor_style_option.get_item_metadata(m_floor_style_option.selected))


func _select_floor_style(floor_style: String) -> void:
	if m_floor_style_option == null:
		return
	for index in range(m_floor_style_option.get_item_count()):
		if String(m_floor_style_option.get_item_metadata(index)) == floor_style:
			m_floor_style_option.select(index)
			return
	m_floor_style_option.select(0)


func _update_floor_type_controls() -> void:
	if m_floor_style_option != null:
		m_floor_style_option.disabled = false


func _selected_pillar_style() -> String:
	if m_pillar_style_option == null or m_pillar_style_option.selected < 0:
		return "round"
	return String(m_pillar_style_option.get_item_metadata(m_pillar_style_option.selected))


func _select_pillar_style(style: String) -> void:
	if m_pillar_style_option == null:
		return
	for index in range(m_pillar_style_option.get_item_count()):
		if String(m_pillar_style_option.get_item_metadata(index)) == style:
			m_pillar_style_option.select(index)
			_update_pillar_style_controls()
			return
	m_pillar_style_option.select(0)
	_update_pillar_style_controls()


func _update_pillar_style_controls() -> void:
	var has_side_count := _selected_pillar_style() in ["round", "tapered"]
	if m_pillar_style_header != null:
		m_pillar_style_header.visible = has_side_count
	if m_pillar_sides_row != null:
		m_pillar_sides_row.visible = has_side_count


func _selected_roof_style() -> String:
	if m_roof_style_option == null or m_roof_style_option.selected < 0:
		return "gable"
	return String(m_roof_style_option.get_item_metadata(m_roof_style_option.selected))


func _selected_roof_footprint_style() -> String:
	if m_roof_footprint_option == null or m_roof_footprint_option.selected < 0:
		return FLOOR_STYLE_RECTANGLE
	return String(m_roof_footprint_option.get_item_metadata(m_roof_footprint_option.selected))


func _select_roof_footprint_style(style: String) -> void:
	if m_roof_footprint_option == null:
		return
	for index in range(m_roof_footprint_option.get_item_count()):
		if String(m_roof_footprint_option.get_item_metadata(index)) == style:
			m_roof_footprint_option.select(index)
			return
	m_roof_footprint_option.select(0)


func _select_roof_style(style: String) -> void:
	if m_roof_style_option == null:
		return
	for index in range(m_roof_style_option.get_item_count()):
		if String(m_roof_style_option.get_item_metadata(index)) == style:
			m_roof_style_option.select(index)
			_update_roof_style_controls()
			return
	m_roof_style_option.select(2)
	_update_roof_style_controls()


func _update_roof_style_controls() -> void:
	var style := _selected_roof_style()
	var has_angle := style != "flat"
	var has_gable_drop := style == "hip"
	if m_roof_footprint_row != null:
		m_roof_footprint_row.visible = style == "flat"
	if m_roof_style_header != null:
		m_roof_style_header.visible = has_angle or has_gable_drop
	if m_roof_angle_row != null:
		m_roof_angle_row.visible = has_angle
	if m_roof_hip_gable_height_row != null:
		m_roof_hip_gable_height_row.visible = has_gable_drop


func _emit_prop_settings() -> void:
	prop_settings_changed.emit({
		"scene_path": m_prop_path_edit.text.strip_edges(),
		"clearance": float(m_prop_clearance_spin.value),
	})


func _emit_window_settings() -> void:
	window_settings_changed.emit({
		"style": _selected_window_style(),
		"width": float(m_window_width_spin.value),
		"height": float(m_window_height_spin.value),
		"frame_thickness": float(m_window_frame_spin.value),
		"frame_protrusion": float(m_window_frame_protrusion_spin.value),
		"frame_color": m_window_frame_color_picker.color,
		"sill_height": float(m_window_sill_spin.value),
		"frame_sides": _selected_frame_sides(m_window_frame_sides_option),
		"window_pane_depth": float(m_window_pane_depth_spin.value),
		"window_pane_color": m_window_pane_color_picker.color,
		"pane_grid_rows": int(roundf(m_window_grid_rows_spin.value)),
		"pane_grid_cols": int(roundf(m_window_grid_cols_spin.value)),
		"muntin_thickness": float(m_window_muntin_thickness_spin.value),
		"louver_count": int(roundf(m_window_louver_count_spin.value)),
		"louver_depth": float(m_window_louver_depth_spin.value),
		"transom_ratio": float(m_window_transom_ratio_spin.value),
		"transom_rail_thickness": float(m_window_transom_rail_spin.value),
		"arch_steps": int(roundf(m_window_arch_steps_spin.value)),
	})


func _selected_window_style() -> String:
	if m_window_style_option == null or m_window_style_option.selected < 0:
		return "single_window"
	return String(m_window_style_option.get_item_metadata(m_window_style_option.selected))


func _select_window_style(style: String) -> void:
	if m_window_style_option == null:
		return
	for index in range(m_window_style_option.get_item_count()):
		if String(m_window_style_option.get_item_metadata(index)) == style:
			m_window_style_option.select(index)
			_update_window_style_controls()
			return
	m_window_style_option.select(0)
	_update_window_style_controls()


func _update_window_style_controls() -> void:
	var style := _selected_window_style()
	var visible_keys: Array[String] = []
	if style in ["single_window", "double_window", "grid_window", "transom_window", "arched_window"]:
		visible_keys.append_array(["pane_depth", "pane_color"])
	match style:
		"grid_window":
			visible_keys.append_array(["grid_rows", "grid_cols", "muntin"])
		"louvered_window":
			visible_keys.append_array(["louver_count", "louver_depth"])
		"transom_window":
			visible_keys.append_array(["transom_ratio", "transom_rail"])
		"arched_window":
			visible_keys.append("arch_steps")
	_set_style_rows_visible(m_window_style_rows, visible_keys)
	if m_window_style_header != null:
		m_window_style_header.visible = !visible_keys.is_empty()


func _window_default_width(style: String) -> float:
	return 1.8 if style == "double_window" else 1.0


func _emit_door_settings() -> void:
	door_settings_changed.emit({
		"style": _selected_door_style(),
		"width": float(m_door_width_spin.value),
		"height": float(m_door_height_spin.value),
		"frame_thickness": float(m_door_frame_spin.value),
		"frame_protrusion": float(m_door_frame_protrusion_spin.value),
		"frame_color": m_door_frame_color_picker.color,
		"frame_sides": _selected_frame_sides(m_door_frame_sides_option),
		"door_panel_depth": float(m_door_panel_depth_spin.value),
		"door_panel_color": m_door_panel_color_picker.color,
		"door_glazing_ratio": float(m_door_glazing_ratio_spin.value),
		"door_glass_depth": float(m_door_glass_depth_spin.value),
		"door_glass_color": m_door_glass_color_picker.color,
		"pane_grid_rows": int(roundf(m_door_grid_rows_spin.value)),
		"pane_grid_cols": int(roundf(m_door_grid_cols_spin.value)),
		"muntin_thickness": float(m_door_muntin_thickness_spin.value),
		"door_inset_rows": int(roundf(m_door_inset_rows_spin.value)),
		"door_inset_cols": int(roundf(m_door_inset_cols_spin.value)),
	})


func _selected_door_style() -> String:
	if m_door_style_option == null or m_door_style_option.selected < 0:
		return "single_door"
	return String(m_door_style_option.get_item_metadata(m_door_style_option.selected))


func _select_door_style(style: String) -> void:
	if m_door_style_option == null:
		return
	for index in range(m_door_style_option.get_item_count()):
		if String(m_door_style_option.get_item_metadata(index)) == style:
			m_door_style_option.select(index)
			_update_door_style_controls()
			return
	m_door_style_option.select(0)
	_update_door_style_controls()


func _update_door_style_controls() -> void:
	var style := _selected_door_style()
	var visible_keys: Array[String] = []
	if style not in ["single_frame", "double_frame"]:
		visible_keys.append_array(["panel_depth", "panel_color"])
	if style in ["glazed_door", "glazed_grid_door"]:
		visible_keys.append_array(["glazing_ratio", "glass_depth", "glass_color"])
	if style == "glazed_grid_door":
		visible_keys.append_array(["grid_rows", "grid_cols", "muntin"])
	if style == "panel_door":
		visible_keys.append_array(["inset_rows", "inset_cols"])
	_set_style_rows_visible(m_door_style_rows, visible_keys)
	if m_door_style_header != null:
		m_door_style_header.visible = !visible_keys.is_empty()


func _set_style_rows_visible(rows: Dictionary, visible_keys: Array[String]) -> void:
	for key_variant in rows:
		var key := String(key_variant)
		var row := rows[key_variant] as Control
		if row != null:
			row.visible = visible_keys.has(key)


func _door_default_width(style: String) -> float:
	return 1.6 if style.begins_with("double") else 0.9


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
	m_debug_wireframe_check.button_pressed = bool(
		state.get(
			"debug_wireframe",
			state.get("roof_debug_wireframe", m_debug_wireframe_check.button_pressed)
		)
	)
	m_debug_wireframe_xray_check.button_pressed = bool(
		state.get(
			"debug_wireframe_xray",
			m_debug_wireframe_xray_check.button_pressed
		)
	)
	var wireframe_color_variant: Variant = state.get(
		"debug_wireframe_color",
		m_debug_wireframe_color_picker.color
	)
	if wireframe_color_variant is Color:
		m_debug_wireframe_color_picker.color = wireframe_color_variant
	_update_debug_wireframe_controls()
	_select_wall_type(str(state.get("wall_type", _selected_wall_type())))
	m_wall_base_height_spin.value = float(state.get("wall_base_height", m_wall_base_height_spin.value))
	_select_floor_type(str(state.get("floor_type", _selected_floor_type())))
	_select_floor_style(str(state.get("floor_style", _selected_floor_style())))
	m_floor_grid_spin.value = float(state.get("floor_grid_step", m_floor_grid_spin.value))
	m_floor_base_height_spin.value = float(state.get("floor_base_height", m_floor_base_height_spin.value))
	m_floor_thickness_spin.value = float(state.get("floor_thickness", m_floor_thickness_spin.value))
	var floor_color_variant: Variant = state.get("floor_color", m_floor_color_picker.color)
	if floor_color_variant is Color:
		m_floor_color_picker.color = floor_color_variant
	m_stair_grid_spin.value = float(state.get("stair_grid_step", m_stair_grid_spin.value))
	m_stair_base_height_spin.value = float(state.get("stair_base_height", m_stair_base_height_spin.value))
	m_stair_height_spin.value = float(state.get("stair_height", m_stair_height_spin.value))
	m_stair_step_count_spin.value = float(state.get("stair_step_count", m_stair_step_count_spin.value))
	m_stair_thickness_spin.value = float(state.get("stair_thickness", m_stair_thickness_spin.value))
	m_stair_rotation_spin.value = float(state.get("stair_rotation_degrees", m_stair_rotation_spin.value))
	var stair_color_variant: Variant = state.get("stair_color", m_stair_color_picker.color)
	if stair_color_variant is Color:
		m_stair_color_picker.color = stair_color_variant
	m_pillar_grid_spin.value = float(state.get("pillar_grid_step", m_pillar_grid_spin.value))
	_select_pillar_style(str(state.get("pillar_style", _selected_pillar_style())))
	m_pillar_base_height_spin.value = float(state.get("pillar_base_height", m_pillar_base_height_spin.value))
	m_pillar_radius_spin.value = float(state.get("pillar_radius", m_pillar_radius_spin.value))
	m_pillar_upper_radius_spin.value = float(state.get("pillar_upper_radius", m_pillar_upper_radius_spin.value))
	m_pillar_height_spin.value = float(state.get("pillar_height", m_pillar_height_spin.value))
	m_pillar_sides_spin.value = float(state.get("pillar_sides", m_pillar_sides_spin.value))
	m_pillar_lower_rim_height_spin.value = float(state.get("pillar_lower_rim_height", m_pillar_lower_rim_height_spin.value))
	m_pillar_lower_rim_outset_spin.value = float(state.get("pillar_lower_rim_outset", m_pillar_lower_rim_outset_spin.value))
	m_pillar_upper_rim_height_spin.value = float(state.get("pillar_upper_rim_height", m_pillar_upper_rim_height_spin.value))
	m_pillar_upper_rim_outset_spin.value = float(state.get("pillar_upper_rim_outset", m_pillar_upper_rim_outset_spin.value))
	var pillar_color_variant: Variant = state.get("pillar_color", m_pillar_color_picker.color)
	if pillar_color_variant is Color:
		m_pillar_color_picker.color = pillar_color_variant
	m_roof_grid_spin.value = float(state.get("roof_grid_step", m_roof_grid_spin.value))
	_select_roof_style(str(state.get("roof_style", _selected_roof_style())))
	_select_roof_footprint_style(
		str(state.get("roof_footprint_style", _selected_roof_footprint_style()))
	)
	m_roof_base_height_spin.value = float(state.get("roof_base_height", m_roof_base_height_spin.value))
	m_roof_height_spin.value = _stored_roof_angle_degrees(state)
	m_roof_thickness_spin.value = float(state.get("roof_thickness", m_roof_thickness_spin.value))
	m_roof_overhang_spin.value = float(state.get("roof_overhang", m_roof_overhang_spin.value))
	m_roof_hip_gable_height_spin.value = float(
		state.get("roof_hip_gable_height", m_roof_hip_gable_height_spin.value)
	)
	m_roof_rotation_spin.value = float(state.get("roof_rotation_degrees", m_roof_rotation_spin.value))
	var roof_color_variant: Variant = state.get("roof_color", m_roof_color_picker.color)
	if roof_color_variant is Color:
		m_roof_color_picker.color = roof_color_variant
	var window_style := str(state.get("window_style", _selected_window_style()))
	_select_window_style(window_style)
	m_window_width_spin.value = float(state.get("window_width", _window_default_width(window_style)))
	m_window_height_spin.value = float(state.get("window_height", m_window_height_spin.value))
	m_window_frame_spin.value = float(state.get("window_frame_thickness", m_window_frame_spin.value))
	m_window_frame_protrusion_spin.value = float(
		state.get("window_frame_protrusion", m_window_frame_protrusion_spin.value)
	)
	var window_frame_color_variant: Variant = state.get("window_frame_color", m_window_frame_color_picker.color)
	if window_frame_color_variant is Color:
		m_window_frame_color_picker.color = window_frame_color_variant
	m_window_sill_spin.value = float(state.get("window_sill_height", m_window_sill_spin.value))
	_select_frame_sides(m_window_frame_sides_option, int(state.get("window_frame_sides", _selected_frame_sides(m_window_frame_sides_option))))
	m_window_pane_depth_spin.value = float(state.get("window_pane_depth", m_window_pane_depth_spin.value))
	var window_pane_color_variant: Variant = state.get("window_pane_color", m_window_pane_color_picker.color)
	if window_pane_color_variant is Color:
		m_window_pane_color_picker.color = window_pane_color_variant
	m_window_grid_rows_spin.value = float(state.get("window_pane_grid_rows", m_window_grid_rows_spin.value))
	m_window_grid_cols_spin.value = float(state.get("window_pane_grid_cols", m_window_grid_cols_spin.value))
	m_window_muntin_thickness_spin.value = float(
		state.get("window_muntin_thickness", m_window_muntin_thickness_spin.value)
	)
	m_window_louver_count_spin.value = float(state.get("window_louver_count", m_window_louver_count_spin.value))
	m_window_louver_depth_spin.value = float(state.get("window_louver_depth", m_window_louver_depth_spin.value))
	m_window_transom_ratio_spin.value = float(state.get("window_transom_ratio", m_window_transom_ratio_spin.value))
	m_window_transom_rail_spin.value = float(state.get("window_transom_rail", m_window_transom_rail_spin.value))
	m_window_arch_steps_spin.value = float(state.get("window_arch_steps", m_window_arch_steps_spin.value))
	var door_style := str(state.get("door_style", _selected_door_style()))
	_select_door_style(door_style)
	m_door_width_spin.value = float(state.get("door_width", _door_default_width(door_style)))
	m_door_height_spin.value = float(state.get("door_height", m_door_height_spin.value))
	m_door_frame_spin.value = float(state.get("door_frame_thickness", m_door_frame_spin.value))
	m_door_frame_protrusion_spin.value = float(
		state.get("door_frame_protrusion", m_door_frame_protrusion_spin.value)
	)
	var door_frame_color_variant: Variant = state.get("door_frame_color", m_door_frame_color_picker.color)
	if door_frame_color_variant is Color:
		m_door_frame_color_picker.color = door_frame_color_variant
	_select_frame_sides(m_door_frame_sides_option, int(state.get("door_frame_sides", _selected_frame_sides(m_door_frame_sides_option))))
	m_door_panel_depth_spin.value = float(state.get("door_panel_depth", m_door_panel_depth_spin.value))
	var door_panel_color_variant: Variant = state.get("door_panel_color", m_door_panel_color_picker.color)
	if door_panel_color_variant is Color:
		m_door_panel_color_picker.color = door_panel_color_variant
	m_door_glazing_ratio_spin.value = float(state.get("door_glazing_ratio", m_door_glazing_ratio_spin.value))
	m_door_glass_depth_spin.value = float(state.get("door_glass_depth", m_door_glass_depth_spin.value))
	var door_glass_color_variant: Variant = state.get("door_glass_color", m_door_glass_color_picker.color)
	if door_glass_color_variant is Color:
		m_door_glass_color_picker.color = door_glass_color_variant
	m_door_grid_rows_spin.value = float(state.get("door_pane_grid_rows", m_door_grid_rows_spin.value))
	m_door_grid_cols_spin.value = float(state.get("door_pane_grid_cols", m_door_grid_cols_spin.value))
	m_door_muntin_thickness_spin.value = float(
		state.get("door_muntin_thickness", m_door_muntin_thickness_spin.value)
	)
	m_door_inset_rows_spin.value = float(state.get("door_inset_rows", m_door_inset_rows_spin.value))
	m_door_inset_cols_spin.value = float(state.get("door_inset_cols", m_door_inset_cols_spin.value))
	_update_window_style_controls()
	_update_door_style_controls()
	_refresh_color_picker_icons()


func _stored_roof_angle_degrees(state: Dictionary) -> float:
	if state.has("roof_angle_degrees"):
		return float(state["roof_angle_degrees"])
	var legacy_value := float(state.get("roof_height", m_roof_height_spin.value))
	if legacy_value > 0.0 and legacy_value <= LEGACY_ROOF_VALUE_MAX:
		return rad_to_deg(atan(legacy_value))
	return legacy_value


func _save_persisted_settings() -> void:
	var editor_settings := _get_editor_settings()
	if editor_settings == null:
		return

	editor_settings.set_project_metadata(PROJECT_METADATA_SECTION, PROJECT_METADATA_KEY, {
		"prop_palette_root": _get_configured_palette_root(),
		"debug_wireframe": (
			m_debug_wireframe_check.button_pressed
			if m_debug_wireframe_check != null
			else false
		),
		"debug_wireframe_xray": (
			m_debug_wireframe_xray_check.button_pressed
			if m_debug_wireframe_xray_check != null
			else false
		),
		"debug_wireframe_color": (
			m_debug_wireframe_color_picker.color
			if m_debug_wireframe_color_picker != null
			else Color(0.05, 0.95, 1.0, 1.0)
		),
		"wall_type": _selected_wall_type(),
		"wall_base_height": float(m_wall_base_height_spin.value) if m_wall_base_height_spin != null else 0.0,
		"floor_type": _selected_floor_type(),
		"floor_style": _selected_floor_style(),
		"floor_grid_step": float(m_floor_grid_spin.value) if m_floor_grid_spin != null else 0.5,
		"floor_base_height": float(m_floor_base_height_spin.value) if m_floor_base_height_spin != null else 0.0,
		"floor_thickness": float(m_floor_thickness_spin.value) if m_floor_thickness_spin != null else 0.12,
		"floor_color": m_floor_color_picker.color if m_floor_color_picker != null else Color(0.46, 0.40, 0.32, 1.0),
		"stair_grid_step": float(m_stair_grid_spin.value) if m_stair_grid_spin != null else 0.5,
		"stair_base_height": float(m_stair_base_height_spin.value) if m_stair_base_height_spin != null else 0.0,
		"stair_height": float(m_stair_height_spin.value) if m_stair_height_spin != null else 1.2,
		"stair_step_count": int(roundf(m_stair_step_count_spin.value)) if m_stair_step_count_spin != null else 6,
		"stair_thickness": float(m_stair_thickness_spin.value) if m_stair_thickness_spin != null else 0.12,
		"stair_rotation_degrees": float(m_stair_rotation_spin.value) if m_stair_rotation_spin != null else 0.0,
		"stair_color": m_stair_color_picker.color if m_stair_color_picker != null else Color(0.52, 0.46, 0.38, 1.0),
		"pillar_grid_step": float(m_pillar_grid_spin.value) if m_pillar_grid_spin != null else 0.5,
		"pillar_style": _selected_pillar_style(),
		"pillar_base_height": float(m_pillar_base_height_spin.value) if m_pillar_base_height_spin != null else 0.0,
		"pillar_radius": float(m_pillar_radius_spin.value) if m_pillar_radius_spin != null else 0.25,
		"pillar_upper_radius": float(m_pillar_upper_radius_spin.value) if m_pillar_upper_radius_spin != null else 0.0,
		"pillar_height": float(m_pillar_height_spin.value) if m_pillar_height_spin != null else 2.4,
		"pillar_sides": int(roundf(m_pillar_sides_spin.value)) if m_pillar_sides_spin != null else 8,
		"pillar_lower_rim_height": float(m_pillar_lower_rim_height_spin.value) if m_pillar_lower_rim_height_spin != null else 0.12,
		"pillar_lower_rim_outset": float(m_pillar_lower_rim_outset_spin.value) if m_pillar_lower_rim_outset_spin != null else 0.05,
		"pillar_upper_rim_height": float(m_pillar_upper_rim_height_spin.value) if m_pillar_upper_rim_height_spin != null else 0.12,
		"pillar_upper_rim_outset": float(m_pillar_upper_rim_outset_spin.value) if m_pillar_upper_rim_outset_spin != null else 0.05,
		"pillar_color": m_pillar_color_picker.color if m_pillar_color_picker != null else Color(0.70, 0.64, 0.52, 1.0),
		"roof_grid_step": float(m_roof_grid_spin.value) if m_roof_grid_spin != null else 0.5,
		"roof_style": _selected_roof_style(),
		"roof_footprint_style": _selected_roof_footprint_style(),
		"roof_base_height": float(m_roof_base_height_spin.value) if m_roof_base_height_spin != null else 2.4,
		"roof_angle_degrees": float(m_roof_height_spin.value) if m_roof_height_spin != null else DEFAULT_ROOF_ANGLE_DEGREES,
		"roof_height": float(m_roof_height_spin.value) if m_roof_height_spin != null else DEFAULT_ROOF_ANGLE_DEGREES,
		"roof_thickness": float(m_roof_thickness_spin.value) if m_roof_thickness_spin != null else 0.12,
		"roof_overhang": float(m_roof_overhang_spin.value) if m_roof_overhang_spin != null else 0.2,
		"roof_hip_gable_height": float(m_roof_hip_gable_height_spin.value) if m_roof_hip_gable_height_spin != null else 0.0,
		"roof_rotation_degrees": float(m_roof_rotation_spin.value) if m_roof_rotation_spin != null else 0.0,
		"roof_color": m_roof_color_picker.color if m_roof_color_picker != null else Color(0.50, 0.34, 0.25, 1.0),
		"window_style": _selected_window_style(),
		"window_width": float(m_window_width_spin.value) if m_window_width_spin != null else 1.0,
		"window_height": float(m_window_height_spin.value) if m_window_height_spin != null else 1.0,
		"window_frame_thickness": float(m_window_frame_spin.value) if m_window_frame_spin != null else 0.08,
		"window_frame_protrusion": float(m_window_frame_protrusion_spin.value) if m_window_frame_protrusion_spin != null else 0.02,
		"window_frame_color": m_window_frame_color_picker.color if m_window_frame_color_picker != null else Color(0.86, 0.92, 0.94, 1.0),
		"window_sill_height": float(m_window_sill_spin.value) if m_window_sill_spin != null else 0.9,
		"window_frame_sides": _selected_frame_sides(m_window_frame_sides_option),
		"window_pane_depth": float(m_window_pane_depth_spin.value) if m_window_pane_depth_spin != null else 0.03,
		"window_pane_color": m_window_pane_color_picker.color if m_window_pane_color_picker != null else Color(0.58, 0.82, 0.95, 0.52),
		"window_pane_grid_rows": int(roundf(m_window_grid_rows_spin.value)) if m_window_grid_rows_spin != null else 2,
		"window_pane_grid_cols": int(roundf(m_window_grid_cols_spin.value)) if m_window_grid_cols_spin != null else 1,
		"window_muntin_thickness": float(m_window_muntin_thickness_spin.value) if m_window_muntin_thickness_spin != null else 0.03,
		"window_louver_count": int(roundf(m_window_louver_count_spin.value)) if m_window_louver_count_spin != null else 6,
		"window_louver_depth": float(m_window_louver_depth_spin.value) if m_window_louver_depth_spin != null else 0.03,
		"window_transom_ratio": float(m_window_transom_ratio_spin.value) if m_window_transom_ratio_spin != null else 0.28,
		"window_transom_rail": float(m_window_transom_rail_spin.value) if m_window_transom_rail_spin != null else 0.03,
		"window_arch_steps": int(roundf(m_window_arch_steps_spin.value)) if m_window_arch_steps_spin != null else 3,
		"door_style": _selected_door_style(),
		"door_width": float(m_door_width_spin.value) if m_door_width_spin != null else 0.9,
		"door_height": float(m_door_height_spin.value) if m_door_height_spin != null else 2.1,
		"door_frame_thickness": float(m_door_frame_spin.value) if m_door_frame_spin != null else 0.08,
		"door_frame_protrusion": float(m_door_frame_protrusion_spin.value) if m_door_frame_protrusion_spin != null else 0.02,
		"door_frame_color": m_door_frame_color_picker.color if m_door_frame_color_picker != null else Color(0.86, 0.92, 0.94, 1.0),
		"door_frame_sides": _selected_frame_sides(m_door_frame_sides_option),
		"door_panel_depth": float(m_door_panel_depth_spin.value) if m_door_panel_depth_spin != null else 0.05,
		"door_panel_color": m_door_panel_color_picker.color if m_door_panel_color_picker != null else Color(0.50, 0.34, 0.20, 1.0),
		"door_glazing_ratio": float(m_door_glazing_ratio_spin.value) if m_door_glazing_ratio_spin != null else 0.55,
		"door_glass_depth": float(m_door_glass_depth_spin.value) if m_door_glass_depth_spin != null else 0.03,
		"door_glass_color": m_door_glass_color_picker.color if m_door_glass_color_picker != null else Color(0.58, 0.82, 0.95, 0.52),
		"door_pane_grid_rows": int(roundf(m_door_grid_rows_spin.value)) if m_door_grid_rows_spin != null else 2,
		"door_pane_grid_cols": int(roundf(m_door_grid_cols_spin.value)) if m_door_grid_cols_spin != null else 1,
		"door_muntin_thickness": float(m_door_muntin_thickness_spin.value) if m_door_muntin_thickness_spin != null else 0.03,
		"door_inset_rows": int(roundf(m_door_inset_rows_spin.value)) if m_door_inset_rows_spin != null else 3,
		"door_inset_cols": int(roundf(m_door_inset_cols_spin.value)) if m_door_inset_cols_spin != null else 2,
	})
