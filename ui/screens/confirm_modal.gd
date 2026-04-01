extends PanelContainer

signal cancel_requested()
signal confirm_requested()

const UI_DESIGN_SIZE := Vector2(1920.0, 1080.0)
const MIN_PANEL_SIZE := Vector2(760.0, 320.0)
const MAX_PANEL_SIZE := Vector2(1180.0, 900.0)

@onready var m_title_label: Label = $Margin/Body/ConfirmTitle
@onready var m_body_label: Label = $Margin/Body/ConfirmBody
@onready var m_cancel_button: Button = $Margin/Body/Actions/CancelButton
@onready var m_confirm_button: Button = $Margin/Body/Actions/ConfirmButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_stylebox_override("panel", UIStyle.build_panel_style())
	m_cancel_button.pressed.connect(cancel_requested.emit)
	m_confirm_button.pressed.connect(confirm_requested.emit)
	call_deferred("_fit_to_content")


func set_content(title_text: String, body_text: String) -> void:
	m_title_label.text = title_text
	m_body_label.text = body_text
	call_deferred("_fit_to_content")


func _fit_to_content() -> void:
	if not is_node_ready():
		return

	var minimum_size := get_combined_minimum_size()
	size = Vector2(
		clampf(maxf(minimum_size.x, MIN_PANEL_SIZE.x), MIN_PANEL_SIZE.x, MAX_PANEL_SIZE.x),
		clampf(maxf(minimum_size.y, MIN_PANEL_SIZE.y), MIN_PANEL_SIZE.y, MAX_PANEL_SIZE.y)
	)
	position = (UI_DESIGN_SIZE - size) * 0.5
