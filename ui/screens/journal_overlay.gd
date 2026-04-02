extends PanelContainer

const HUMAN_BODY_SCENE := preload("res://characters/human_body_2d.tscn")
const APP_RUNTIME := preload("res://game/app_runtime.gd")

signal close_requested()

@onready var m_tabs: TabContainer = $Margin/Body/Tabs
@onready var m_quest_body: Label = $Margin/Body/Tabs/Objectives/QuestBody
@onready var m_map_body: Label = $Margin/Body/Tabs/Map/MapBody
@onready var m_residents_body: Label = $Margin/Body/Tabs/Residents/ResidentsBody
@onready var m_melody_body: Label = $Margin/Body/Tabs/Melody/MelodyBody
@onready var m_melody_practice_button: Button = $Margin/Body/Tabs/Melody/MelodyPracticeButton
@onready var m_preview_viewport: SubViewport = $Margin/Body/Tabs/Wardrobe/WardrobeContent/PreviewFrame/PreviewViewportContainer/PreviewViewport
@onready var m_wardrobe_body: Label = $Margin/Body/Tabs/Wardrobe/WardrobeContent/WardrobeBody
@onready var m_costume_value: Label = $Margin/Body/Tabs/Wardrobe/WardrobeContent/CostumeRow/Controls/Value
@onready var m_prev_costume_button: Button = $Margin/Body/Tabs/Wardrobe/WardrobeContent/CostumeRow/Controls/PreviousCostumeButton
@onready var m_next_costume_button: Button = $Margin/Body/Tabs/Wardrobe/WardrobeContent/CostumeRow/Controls/NextCostumeButton
@onready var m_hair_style_value: Label = $Margin/Body/Tabs/Wardrobe/WardrobeContent/HairStyleRow/Controls/Value
@onready var m_prev_hair_style_button: Button = $Margin/Body/Tabs/Wardrobe/WardrobeContent/HairStyleRow/Controls/PreviousHairStyleButton
@onready var m_next_hair_style_button: Button = $Margin/Body/Tabs/Wardrobe/WardrobeContent/HairStyleRow/Controls/NextHairStyleButton
@onready var m_hair_color_value: Label = $Margin/Body/Tabs/Wardrobe/WardrobeContent/HairColorRow/Controls/Value
@onready var m_prev_hair_color_button: Button = $Margin/Body/Tabs/Wardrobe/WardrobeContent/HairColorRow/Controls/PreviousHairColorButton
@onready var m_next_hair_color_button: Button = $Margin/Body/Tabs/Wardrobe/WardrobeContent/HairColorRow/Controls/NextHairColorButton
@onready var m_close_button: Button = $Margin/Body/CloseButton

var m_preview_actor: HumanBody2D = null


func _app_state():
	return APP_RUNTIME.get_app_state(self)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_stylebox_override("panel", UIStyle.build_panel_style())
	_build_preview_actor()
	m_prev_costume_button.pressed.connect(_on_previous_costume_pressed)
	m_next_costume_button.pressed.connect(_on_next_costume_pressed)
	m_prev_hair_style_button.pressed.connect(_on_previous_hair_style_pressed)
	m_next_hair_style_button.pressed.connect(_on_next_hair_style_pressed)
	m_prev_hair_color_button.pressed.connect(_on_previous_hair_color_pressed)
	m_next_hair_color_button.pressed.connect(_on_next_hair_color_pressed)
	m_melody_practice_button.pressed.connect(_on_melody_practice_pressed)
	m_close_button.pressed.connect(close_requested.emit)
	if !_app_state().player_costumes_changed.is_connected(_on_player_costumes_changed):
		_app_state().player_costumes_changed.connect(_on_player_costumes_changed)
	if !_app_state().player_appearance_changed.is_connected(_on_player_appearance_changed):
		_app_state().player_appearance_changed.connect(_on_player_appearance_changed)
	refresh_from_state()


func refresh_from_state() -> void:
	m_quest_body.text = "Main Quest\n%s" % _app_state().objective
	m_map_body.text = _app_state().build_map_journal_text()
	m_residents_body.text = "Resident Notes\n%s" % _app_state().build_resident_journal_text()
	m_melody_body.text = "Melody Journal\n%s" % _app_state().build_melody_journal_text()
	m_wardrobe_body.text = "Wardrobe\n%s" % _app_state().build_player_costume_journal_text()
	m_costume_value.text = _app_state().get_equipped_player_costume_display_name()
	m_hair_style_value.text = _app_state().get_player_hair_style_display_name()
	m_hair_color_value.text = _app_state().get_player_hair_color_display_name()
	_refresh_preview()

	var unlocked_count = _app_state().get_unlocked_player_costume_ids().size()
	m_prev_costume_button.disabled = unlocked_count <= 1
	m_next_costume_button.disabled = unlocked_count <= 1

	var primary_melody_id := _primary_melody_id()
	if primary_melody_id.is_empty():
		m_melody_practice_button.disabled = true
		m_melody_practice_button.text = "Practice Melody"
		return

	var melody_definition = _app_state().get_melody_definition(primary_melody_id)
	var melody_state = _app_state().get_melody_state(primary_melody_id)
	var melody_label := String(melody_definition.get("display_name", "Melody"))
	var stage := String(melody_state.get("state", "unknown"))
	var is_replay := stage in ["performed", "resonant"]
	m_melody_practice_button.disabled = !_app_state().can_practice_melody(primary_melody_id)
	if is_replay:
		m_melody_practice_button.text = "Replay %s" % melody_label
	else:
		m_melody_practice_button.text = "Practice %s" % melody_label


func _build_preview_actor() -> void:
	var preview_root := Node2D.new()
	preview_root.name = "PreviewRoot"
	m_preview_viewport.add_child(preview_root)

	m_preview_actor = HUMAN_BODY_SCENE.instantiate() as HumanBody2D
	if m_preview_actor == null:
		return

	preview_root.add_child(m_preview_actor)
	m_preview_actor.position = Vector2(140, 228)
	m_preview_actor.scale = Vector2.ONE * 1.85
	m_preview_actor.direction = 180.0
	m_preview_actor.is_running = false
	m_preview_actor.is_walking = false
	m_preview_actor.facial_mood = HumanBody2D.FacialMoodEnum.NORMAL


func _refresh_preview() -> void:
	if m_preview_actor == null:
		return

	m_preview_actor.set_configuration(_app_state().get_player_appearance_config())


func _primary_melody_id() -> String:
	var melody_ids = _app_state().get_melody_ids()
	if melody_ids.is_empty():
		return ""
	return String(melody_ids[0])


func _on_previous_costume_pressed() -> void:
	_app_state().cycle_player_costume(-1)
	refresh_from_state()


func _on_next_costume_pressed() -> void:
	_app_state().cycle_player_costume(1)
	refresh_from_state()


func _on_previous_hair_style_pressed() -> void:
	_app_state().cycle_player_hair_style(-1)
	refresh_from_state()


func _on_next_hair_style_pressed() -> void:
	_app_state().cycle_player_hair_style(1)
	refresh_from_state()


func _on_previous_hair_color_pressed() -> void:
	_app_state().cycle_player_hair_color(-1)
	refresh_from_state()


func _on_next_hair_color_pressed() -> void:
	_app_state().cycle_player_hair_color(1)
	refresh_from_state()


func _on_melody_practice_pressed() -> void:
	var melody_id := _primary_melody_id()
	if melody_id.is_empty():
		return
	_app_state().request_melody_practice(melody_id)


func _on_player_costumes_changed(_unlocked_ids: PackedStringArray, _equipped_costume_id: String) -> void:
	refresh_from_state()


func _on_player_appearance_changed(_profile: Dictionary, _appearance_config: Dictionary) -> void:
	refresh_from_state()
