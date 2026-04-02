extends PanelContainer

const HUMAN_BODY_SCENE := preload("res://characters/human_body_2d.tscn")
const APP_RUNTIME := preload("res://game/app_runtime.gd")

signal confirm_requested()
signal cancel_requested()

@onready var m_title_label: Label = $Margin/Body/Title
@onready var m_subtitle_label: Label = $Margin/Body/SubTitle
@onready var m_preview_viewport: SubViewport = $Margin/Body/Content/PreviewColumn/PreviewFrame/PreviewViewportContainer/PreviewViewport
@onready var m_summary_label: Label = $Margin/Body/Content/PreviewColumn/Summary
@onready var m_body_value: Label = $Margin/Body/Content/ControlsColumn/BodyRow/Controls/Value
@onready var m_gender_value: Label = $Margin/Body/Content/ControlsColumn/GenderRow/Controls/Value
@onready var m_skin_value: Label = $Margin/Body/Content/ControlsColumn/SkinRow/Controls/Value
@onready var m_hair_style_value: Label = $Margin/Body/Content/ControlsColumn/HairStyleRow/Controls/Value
@onready var m_hair_color_value: Label = $Margin/Body/Content/ControlsColumn/HairColorRow/Controls/Value
@onready var m_confirm_button: Button = $Margin/Body/Footer/ConfirmButton
@onready var m_cancel_button: Button = $Margin/Body/Footer/CancelButton

var m_is_free_walk := false
var m_preview_actor: HumanBody2D = null


func _app_state():
	return APP_RUNTIME.get_app_state(self)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_stylebox_override("panel", UIStyle.build_panel_style())
	_build_preview_actor()
	_connect_buttons()

	if !_app_state().player_appearance_changed.is_connected(_on_player_appearance_changed):
		_app_state().player_appearance_changed.connect(_on_player_appearance_changed)

	refresh_from_state()


func set_flow_context(is_free_walk: bool) -> void:
	m_is_free_walk = is_free_walk
	if is_node_ready():
		_refresh_flow_labels()


func refresh_from_state() -> void:
	_refresh_flow_labels()
	m_body_value.text = _app_state().get_player_body_display_name()
	m_gender_value.text = _app_state().get_player_gender_display_name()
	m_skin_value.text = _app_state().get_player_skin_display_name()
	m_hair_style_value.text = _app_state().get_player_hair_style_display_name()
	m_hair_color_value.text = _app_state().get_player_hair_color_display_name()
	m_summary_label.text = _app_state().build_player_setup_summary_text()
	_refresh_preview()


func _build_preview_actor() -> void:
	var preview_root := Node2D.new()
	preview_root.name = "PreviewRoot"
	m_preview_viewport.add_child(preview_root)

	m_preview_actor = HUMAN_BODY_SCENE.instantiate() as HumanBody2D
	if m_preview_actor == null:
		return

	preview_root.add_child(m_preview_actor)
	m_preview_actor.position = Vector2(180, 288)
	m_preview_actor.scale = Vector2.ONE * 2.2
	m_preview_actor.direction = 180.0
	m_preview_actor.is_running = false
	m_preview_actor.is_walking = false
	m_preview_actor.facial_mood = HumanBody2D.FacialMoodEnum.NORMAL


func _connect_buttons() -> void:
	$Margin/Body/Content/ControlsColumn/BodyRow/Controls/PrevButton.pressed.connect(
		func() -> void:
			_app_state().cycle_player_body_frame(-1)
			refresh_from_state()
	)
	$Margin/Body/Content/ControlsColumn/BodyRow/Controls/NextButton.pressed.connect(
		func() -> void:
			_app_state().cycle_player_body_frame(1)
			refresh_from_state()
	)
	$Margin/Body/Content/ControlsColumn/GenderRow/Controls/PrevButton.pressed.connect(
		func() -> void:
			_app_state().cycle_player_gender(-1)
			refresh_from_state()
	)
	$Margin/Body/Content/ControlsColumn/GenderRow/Controls/NextButton.pressed.connect(
		func() -> void:
			_app_state().cycle_player_gender(1)
			refresh_from_state()
	)
	$Margin/Body/Content/ControlsColumn/SkinRow/Controls/PrevButton.pressed.connect(
		func() -> void:
			_app_state().cycle_player_skin_tone(-1)
			refresh_from_state()
	)
	$Margin/Body/Content/ControlsColumn/SkinRow/Controls/NextButton.pressed.connect(
		func() -> void:
			_app_state().cycle_player_skin_tone(1)
			refresh_from_state()
	)
	$Margin/Body/Content/ControlsColumn/HairStyleRow/Controls/PrevButton.pressed.connect(
		func() -> void:
			_app_state().cycle_player_hair_style(-1)
			refresh_from_state()
	)
	$Margin/Body/Content/ControlsColumn/HairStyleRow/Controls/NextButton.pressed.connect(
		func() -> void:
			_app_state().cycle_player_hair_style(1)
			refresh_from_state()
	)
	$Margin/Body/Content/ControlsColumn/HairColorRow/Controls/PrevButton.pressed.connect(
		func() -> void:
			_app_state().cycle_player_hair_color(-1)
			refresh_from_state()
	)
	$Margin/Body/Content/ControlsColumn/HairColorRow/Controls/NextButton.pressed.connect(
		func() -> void:
			_app_state().cycle_player_hair_color(1)
			refresh_from_state()
	)

	m_confirm_button.pressed.connect(confirm_requested.emit)
	m_cancel_button.pressed.connect(cancel_requested.emit)


func _refresh_flow_labels() -> void:
	if m_is_free_walk:
		m_title_label.text = "Set Up Your Walker"
		m_subtitle_label.text = "Choose a body, gender, skin tone, and hair before entering free walk. Costume changes unlock inside the journal once you are on the island."
		m_confirm_button.text = "Enter Free Walk"
	else:
		m_title_label.text = "Set Up Your Traveler"
		m_subtitle_label.text = "Choose a body, gender, skin tone, and hair before arriving on Kulangsu. Costumes and hair can still change later from the journal."
		m_confirm_button.text = "Begin Story"


func _refresh_preview() -> void:
	if m_preview_actor == null:
		return

	m_preview_actor.set_configuration(_app_state().get_player_appearance_config())


func _on_player_appearance_changed(_profile: Dictionary, _appearance_config: Dictionary) -> void:
	refresh_from_state()
