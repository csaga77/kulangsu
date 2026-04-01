extends PanelContainer

signal back_requested()

@onready var m_credits_text: RichTextLabel = $Margin/Body/CreditsText
@onready var m_back_button: Button = $Margin/Body/BackButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_stylebox_override("panel", UIStyle.build_panel_style())
	m_credits_text.text = _load_credits_text()
	m_back_button.pressed.connect(back_requested.emit)


func _load_credits_text() -> String:
	var output := "Kulangsu Credits\n\n"
	if FileAccess.file_exists("res://credit.md"):
		var file := FileAccess.open("res://credit.md", FileAccess.READ)
		if file != null:
			output += file.get_as_text()
			return output
	output += "credit.md not found."
	return output
