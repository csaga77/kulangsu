extends PanelContainer

const APP_RUNTIME := preload("res://game/app_runtime.gd")

signal back_requested()

@onready var m_master_slider: HSlider = $Margin/Body/MasterSlider
@onready var m_music_slider: HSlider = $Margin/Body/MusicSlider
@onready var m_prompt_slider: HSlider = $Margin/Body/PromptSlider
@onready var m_speech_text_speed_slider: HSlider = $Margin/Body/SpeechTextSpeedSlider
@onready var m_back_button: Button = $Margin/Body/BackButton


func _app_state():
	return APP_RUNTIME.get_app_state(self)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_stylebox_override("panel", UIStyle.build_panel_style())
	_refresh_from_state()
	_bind_controls()
	_bind_state()
	m_back_button.pressed.connect(back_requested.emit)
	visibility_changed.connect(_on_visibility_changed)


func grab_default_focus() -> void:
	if !is_visible_in_tree():
		return
	m_master_slider.grab_focus()


func _bind_controls() -> void:
	m_master_slider.value_changed.connect(_on_master_slider_value_changed)
	m_music_slider.value_changed.connect(_on_music_slider_value_changed)
	m_prompt_slider.value_changed.connect(_on_prompt_slider_value_changed)
	m_speech_text_speed_slider.value_changed.connect(_on_speech_text_speed_slider_value_changed)


func _bind_state() -> void:
	if !_app_state().master_volume_changed.is_connected(_on_master_volume_changed):
		_app_state().master_volume_changed.connect(_on_master_volume_changed)
	if !_app_state().music_volume_changed.is_connected(_on_music_volume_changed):
		_app_state().music_volume_changed.connect(_on_music_volume_changed)
	if !_app_state().prompt_volume_changed.is_connected(_on_prompt_volume_changed):
		_app_state().prompt_volume_changed.connect(_on_prompt_volume_changed)
	if !_app_state().dialogue_text_speed_changed.is_connected(_on_dialogue_text_speed_changed):
		_app_state().dialogue_text_speed_changed.connect(_on_dialogue_text_speed_changed)


func _refresh_from_state() -> void:
	var app_state = _app_state()
	if app_state == null:
		return

	m_master_slider.set_value_no_signal(app_state.get_master_volume_percent())
	m_music_slider.set_value_no_signal(app_state.get_music_volume_percent())
	m_prompt_slider.set_value_no_signal(app_state.get_prompt_volume_percent())
	m_speech_text_speed_slider.set_value_no_signal(app_state.get_dialogue_text_speed_percent())


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		call_deferred("grab_default_focus")


func _on_master_slider_value_changed(value: float) -> void:
	_app_state().set_master_volume_percent(value)


func _on_music_slider_value_changed(value: float) -> void:
	_app_state().set_music_volume_percent(value)


func _on_prompt_slider_value_changed(value: float) -> void:
	_app_state().set_prompt_volume_percent(value)


func _on_speech_text_speed_slider_value_changed(value: float) -> void:
	_app_state().set_dialogue_text_speed_percent(value)


func _on_master_volume_changed(value: float) -> void:
	m_master_slider.set_value_no_signal(value)


func _on_music_volume_changed(value: float) -> void:
	m_music_slider.set_value_no_signal(value)


func _on_prompt_volume_changed(value: float) -> void:
	m_prompt_slider.set_value_no_signal(value)


func _on_dialogue_text_speed_changed(value: float, _characters_per_second: float) -> void:
	m_speech_text_speed_slider.set_value_no_signal(value)
