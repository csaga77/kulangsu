extends PanelContainer

signal close_requested()

@onready var m_tabs: TabContainer = $Margin/Body/Tabs
@onready var m_quest_body: Label = $Margin/Body/Tabs/Objectives/QuestBody
@onready var m_map_body: Label = $Margin/Body/Tabs/Map/MapBody
@onready var m_residents_body: Label = $Margin/Body/Tabs/Residents/ResidentsBody
@onready var m_melody_body: Label = $Margin/Body/Tabs/Melody/MelodyBody
@onready var m_close_button: Button = $Margin/Body/CloseButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_stylebox_override("panel", UIStyle.build_panel_style())
	m_close_button.pressed.connect(close_requested.emit)


func refresh_from_state() -> void:
	m_quest_body.text = "Main Quest\n%s" % AppState.objective
	m_map_body.text = "Discovered landmarks\n%s\n\nCurrent location\n%s" % [
		"\n".join(AppState.landmarks),
		AppState.location,
	]
	m_residents_body.text = "Known residents\n%s" % "\n".join(AppState.residents)
	m_melody_body.text = "Melody fragments\nRecovered: %d / %d" % [
		AppState.fragments_found,
		AppState.fragments_total,
	]
