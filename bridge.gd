@tool
class_name Bridge
extends Node2D

@export var character :CollisionObject2D = null:
	set(new_character):
		if character == new_character:
			return
		character = new_character
		if m_bridge:
			m_bridge.character = character
		if m_bridge2:
			m_bridge2.character = character

@onready var m_ground  :TileMapLayer = $level1/ground
@onready var m_bridge  :TileMapLayer = $level1/bridge
@onready var m_bridge2 :TileMapLayer = $level2/bridge2

var m_is_on_steps := false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	m_bridge.character = character
	m_bridge2.character = character

func _switch_layer(body: Node2D, source_layer :TileMapLayer, target_layer :TileMapLayer, default_position :Vector2) -> void:
	var c := body as Character
	if c == null:
		return
	c.switch_layer(source_layer, target_layer, default_position)

func _on_body_entered(body: Node2D) -> void:
	_switch_layer(body, null, m_ground, body.global_position)

func _on_body_exited(body: Node2D) -> void:
	_switch_layer(body, m_ground, null, body.global_position)
