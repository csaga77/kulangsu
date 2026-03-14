@tool
extends Node2D

@onready var m_player :HumanBody2D = $player
@onready var m_terrain: Terrain = $terrain
var m_is_ready := false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	m_is_ready = true
	if is_instance_valid(m_terrain):
		m_terrain.player = m_player
	GameGlobal.get_instance().set_player(m_player)
