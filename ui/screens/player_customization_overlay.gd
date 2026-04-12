extends PanelContainer

const HUMAN_BODY_SCENE := preload("res://characters/human_body_2d.tscn")
const APP_RUNTIME := preload("res://game/app_runtime.gd")
const PLAYER_APPEARANCE_CATALOG := preload("res://game/player_appearance_catalog.gd")
const PLAYER_COSTUME_CATALOG := preload("res://game/player_costume_catalog.gd")
const PREVIEW_ACTOR_SCALE := 2.2
const PREVIEW_SPRITE_SIZE := Vector2(64.0, 64.0)

signal confirm_requested()
signal cancel_requested()

@onready var m_title_label: Label = $Margin/Body/Title
@onready var m_subtitle_label: Label = $Margin/Body/SubTitle
@onready var m_preview_viewport: SubViewport = $Margin/Body/Content/PreviewColumn/PreviewFrame/PreviewViewportContainer/PreviewViewport
@onready var m_summary_label: Label = $Margin/Body/Content/PreviewColumn/Summary
@onready var m_body_prev_button: Button = $Margin/Body/Content/ControlsColumn/BodyRow/Controls/PrevButton
@onready var m_body_value: Label = $Margin/Body/Content/ControlsColumn/BodyRow/Controls/Value
@onready var m_gender_value: Label = $Margin/Body/Content/ControlsColumn/GenderRow/Controls/Value
@onready var m_skin_value: Label = $Margin/Body/Content/ControlsColumn/SkinRow/Controls/Value
@onready var m_hair_style_value: Label = $Margin/Body/Content/ControlsColumn/HairStyleRow/Controls/Value
@onready var m_hair_color_value: Label = $Margin/Body/Content/ControlsColumn/HairColorRow/Controls/Value
@onready var m_confirm_button: Button = $Margin/Body/Footer/ConfirmButton
@onready var m_cancel_button: Button = $Margin/Body/Footer/CancelButton

var m_is_free_walk := false
var m_preview_actor: HumanBody2D = null
var m_draft_profile: Dictionary = {}
var m_preview_center_refresh_pending := false


func _app_state():
	return APP_RUNTIME.get_app_state(self)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_stylebox_override("panel", UIStyle.build_panel_style())
	_build_preview_actor()
	_connect_buttons()
	m_preview_viewport.size_changed.connect(_schedule_preview_center_refresh)

	visibility_changed.connect(_on_visibility_changed)
	refresh_from_state()


func set_flow_context(is_free_walk: bool) -> void:
	m_is_free_walk = is_free_walk
	if is_node_ready():
		_refresh_flow_labels()


func refresh_from_state() -> void:
	m_draft_profile = PLAYER_APPEARANCE_CATALOG.normalize_profile(_app_state().get_player_profile())
	_refresh_from_draft()


func commit_draft_to_app_state() -> void:
	_ensure_draft_profile()
	_app_state().set_player_profile(m_draft_profile)
	_app_state().equip_player_costume(PLAYER_COSTUME_CATALOG.default_costume_id())


func _refresh_from_draft() -> void:
	_ensure_draft_profile()
	_refresh_flow_labels()
	m_body_value.text = PLAYER_APPEARANCE_CATALOG.body_frame_display_name(
		String(m_draft_profile.get("body_frame_id", "adult"))
	)
	m_gender_value.text = PLAYER_APPEARANCE_CATALOG.presentation_display_name(
		String(m_draft_profile.get("presentation_id", "masculine"))
	)
	m_skin_value.text = PLAYER_APPEARANCE_CATALOG.skin_tone_display_name(
		String(m_draft_profile.get("skin_tone_id", "light"))
	)
	m_hair_style_value.text = PLAYER_APPEARANCE_CATALOG.hair_style_display_name(
		String(m_draft_profile.get("hair_style_id", "short_bangs"))
	)
	m_hair_color_value.text = PLAYER_APPEARANCE_CATALOG.hair_color_display_name(
		String(m_draft_profile.get("hair_color_id", "chestnut"))
	)
	m_summary_label.text = _build_setup_summary_text()
	_refresh_preview()


func _build_preview_actor() -> void:
	var preview_root := Node2D.new()
	preview_root.name = "PreviewRoot"
	m_preview_viewport.add_child(preview_root)

	m_preview_actor = HUMAN_BODY_SCENE.instantiate() as HumanBody2D
	if m_preview_actor == null:
		return

	preview_root.add_child(m_preview_actor)
	m_preview_actor.scale = Vector2.ONE * PREVIEW_ACTOR_SCALE
	_schedule_preview_center_refresh()
	m_preview_actor.direction = 180.0
	m_preview_actor.is_running = false
	m_preview_actor.is_walking = false
	m_preview_actor.facial_mood = HumanBody2D.FacialMoodEnum.NORMAL


func _connect_buttons() -> void:
	$Margin/Body/Content/ControlsColumn/BodyRow/Controls/PrevButton.pressed.connect(
		func() -> void:
			_cycle_draft_option("body_frame_id", PLAYER_APPEARANCE_CATALOG.body_frame_options(), -1)
	)
	$Margin/Body/Content/ControlsColumn/BodyRow/Controls/NextButton.pressed.connect(
		func() -> void:
			_cycle_draft_option("body_frame_id", PLAYER_APPEARANCE_CATALOG.body_frame_options(), 1)
	)
	$Margin/Body/Content/ControlsColumn/GenderRow/Controls/PrevButton.pressed.connect(
		func() -> void:
			_cycle_draft_option("presentation_id", PLAYER_APPEARANCE_CATALOG.presentation_options(), -1)
	)
	$Margin/Body/Content/ControlsColumn/GenderRow/Controls/NextButton.pressed.connect(
		func() -> void:
			_cycle_draft_option("presentation_id", PLAYER_APPEARANCE_CATALOG.presentation_options(), 1)
	)
	$Margin/Body/Content/ControlsColumn/SkinRow/Controls/PrevButton.pressed.connect(
		func() -> void:
			_cycle_draft_option("skin_tone_id", PLAYER_APPEARANCE_CATALOG.skin_tone_options(), -1)
	)
	$Margin/Body/Content/ControlsColumn/SkinRow/Controls/NextButton.pressed.connect(
		func() -> void:
			_cycle_draft_option("skin_tone_id", PLAYER_APPEARANCE_CATALOG.skin_tone_options(), 1)
	)
	$Margin/Body/Content/ControlsColumn/HairStyleRow/Controls/PrevButton.pressed.connect(
		func() -> void:
			_cycle_draft_option("hair_style_id", PLAYER_APPEARANCE_CATALOG.hair_style_options(), -1)
	)
	$Margin/Body/Content/ControlsColumn/HairStyleRow/Controls/NextButton.pressed.connect(
		func() -> void:
			_cycle_draft_option("hair_style_id", PLAYER_APPEARANCE_CATALOG.hair_style_options(), 1)
	)
	$Margin/Body/Content/ControlsColumn/HairColorRow/Controls/PrevButton.pressed.connect(
		func() -> void:
			_cycle_draft_option("hair_color_id", PLAYER_APPEARANCE_CATALOG.hair_color_options(), -1)
	)
	$Margin/Body/Content/ControlsColumn/HairColorRow/Controls/NextButton.pressed.connect(
		func() -> void:
			_cycle_draft_option("hair_color_id", PLAYER_APPEARANCE_CATALOG.hair_color_options(), 1)
	)

	m_confirm_button.pressed.connect(
		func() -> void:
			commit_draft_to_app_state()
			confirm_requested.emit()
	)
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

	_schedule_preview_center_refresh()
	m_preview_actor.set_configuration(_build_preview_appearance_config())


func _center_preview_actor() -> void:
	if m_preview_actor == null:
		return

	var viewport_size := Vector2(m_preview_viewport.size)
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var scaled_preview_size := PREVIEW_SPRITE_SIZE * PREVIEW_ACTOR_SCALE
	m_preview_actor.position = Vector2(
		viewport_size.x * 0.5,
		viewport_size.y * 0.5 + scaled_preview_size.y * 0.5
	)


func _schedule_preview_center_refresh() -> void:
	if m_preview_center_refresh_pending:
		return

	m_preview_center_refresh_pending = true
	call_deferred("_refresh_preview_center_after_layout")


func _refresh_preview_center_after_layout() -> void:
	_center_preview_actor()
	await get_tree().process_frame
	_center_preview_actor()
	m_preview_center_refresh_pending = false


func _ensure_draft_profile() -> void:
	if !m_draft_profile.is_empty():
		return
	m_draft_profile = PLAYER_APPEARANCE_CATALOG.default_profile()


func _cycle_draft_option(profile_key: String, options: Array, direction: int) -> void:
	_ensure_draft_profile()
	var current_id := String(m_draft_profile.get(profile_key, ""))
	m_draft_profile[profile_key] = PLAYER_APPEARANCE_CATALOG.cycle_option_id(options, current_id, direction)
	_refresh_from_draft()


func _build_preview_appearance_config() -> Dictionary:
	_ensure_draft_profile()
	var costume: Dictionary = _default_setup_costume()
	var costume_selections: Dictionary = costume.get("selections", {})
	return PLAYER_APPEARANCE_CATALOG.build_appearance_config(m_draft_profile, costume_selections)


func _build_setup_summary_text() -> String:
	_ensure_draft_profile()
	return "Body: %s\nGender: %s\nSkin: %s\nHair: %s\nHair color: %s\nStarting look: %s" % [
		PLAYER_APPEARANCE_CATALOG.body_frame_display_name(String(m_draft_profile.get("body_frame_id", "adult"))),
		PLAYER_APPEARANCE_CATALOG.presentation_display_name(String(m_draft_profile.get("presentation_id", "masculine"))),
		PLAYER_APPEARANCE_CATALOG.skin_tone_display_name(String(m_draft_profile.get("skin_tone_id", "light"))),
		PLAYER_APPEARANCE_CATALOG.hair_style_display_name(String(m_draft_profile.get("hair_style_id", "short_bangs"))),
		PLAYER_APPEARANCE_CATALOG.hair_color_display_name(String(m_draft_profile.get("hair_color_id", "chestnut"))),
		String(_default_setup_costume().get("display_name", "Harbor Arrival")),
	]


func _default_setup_costume() -> Dictionary:
	var catalog := PLAYER_COSTUME_CATALOG.build_catalog()
	return catalog.get(PLAYER_COSTUME_CATALOG.default_costume_id(), {})


func grab_default_focus() -> void:
	if !is_visible_in_tree():
		return
	m_body_prev_button.grab_focus()


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_schedule_preview_center_refresh()
		call_deferred("grab_default_focus")
