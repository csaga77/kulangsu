@tool
class_name Bridge
extends Node2D

@export var character :CollisionObject2D = null:
	set(new_character):
		if character == new_character:
			return
		character = new_character
		if m_level1:
			m_level1.character = character
		if m_level2:
			m_level2.character = character
		if m_steps:
			m_steps.character  = character
		if m_steps2:
			m_steps2.character = character
		if m_steps3:
			m_steps3.character = character

@onready var m_ground :TileMapLayer = $ground
@onready var m_level1 :TileMapLayer = $level1
@onready var m_level2 :TileMapLayer = $level1/level2
@onready var m_steps  :TileMapLayer = $steps
@onready var m_steps3 :TileMapLayer = $steps3
@onready var m_steps2 :TileMapLayer = $level1/steps2

var m_is_on_steps := false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	m_level1.character = character
	m_level2.character = character
	m_steps.character  = character
	m_steps2.character = character
	m_steps3.character = character

func _switch_layer(body: Node2D, source_layer :TileMapLayer, target_layer :TileMapLayer, default_position :Vector2) -> void:
	var c := body as Character
	if c == null:
		return
	if source_layer == null:
		source_layer = c.m_default_layer
	c.switch_layer(source_layer, target_layer, default_position)

func _on_body_entered(body: Node2D) -> void:
	_switch_layer(body, null, m_ground, body.global_position)

func _on_body_exited(body: Node2D) -> void:
	_switch_layer(body, m_ground, null, body.global_position)
