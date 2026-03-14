extends PanelContainer

signal cancel_requested()
signal confirm_requested()

@onready var m_title_label: Label = $Margin/Body/ConfirmTitle
@onready var m_body_label: Label = $Margin/Body/ConfirmBody
@onready var m_cancel_button: Button = $Margin/Body/Actions/CancelButton
@onready var m_confirm_button: Button = $Margin/Body/Actions/ConfirmButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_stylebox_override("panel", UIStyle.build_panel_style())
	m_cancel_button.pressed.connect(cancel_requested.emit)
	m_confirm_button.pressed.connect(confirm_requested.emit)


func set_content(title_text: String, body_text: String) -> void:
	m_title_label.text = title_text
	m_body_label.text = body_text
