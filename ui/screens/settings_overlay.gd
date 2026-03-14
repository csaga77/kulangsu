extends PanelContainer

signal back_requested()

@onready var m_back_button: Button = $Margin/Body/BackButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_stylebox_override("panel", UIStyle.build_panel_style())
	m_back_button.pressed.connect(back_requested.emit)
