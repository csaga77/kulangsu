@tool
extends Node2D

@onready var m_player :Player = $player
var m_is_ready := false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	m_is_ready = true
	GameGlobal.get_instance().set_player(m_player)
