@tool
class_name Bridge
extends IsometricBlock

@export var character :Character = null:
	set(new_character):
		if character == new_character:
			return
		if character:
			character.global_position_changed.disconnect(self._on_character_global_position_changed)
		character = new_character
		if character:
			character.global_position_changed.connect(self._on_character_global_position_changed)
		if m_level1:
			m_level1.character = character
		if m_level2:
			m_level2.character = character

@onready var m_ground :TileMapLayer = $ground
@onready var m_level1 :TileMapLayer = $level1
@onready var m_level2 :TileMapLayer = $level1/level2
@onready var m_steps  :Node2D = $ground/steps
@onready var m_steps_mask :TileMapLayer = $ground/mask

var m_is_on_steps := false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	m_level1.character = character
	m_level2.character = character
	
func _on_character_global_position_changed() -> void:
	if character == null or m_steps_mask == null:
		m_steps.modulate.a = 1.0
		return
	var bounding_rect = character.get_ground_rect()
	if Utils.intersects_rect_global(m_steps_mask, bounding_rect):
		m_steps.modulate.a = 0.5
	else:
		m_steps.modulate.a = 1.0

func _switch_layer(body: Node2D, source_layer :TileMapLayer, target_layer :TileMapLayer, default_position :Vector2) -> void:
	var c := body as Character
	if c == null:
		return
	if source_layer == null:
		source_layer = c.m_default_layer
	#c.switch_layer(source_layer, target_layer, default_position)

func _on_body_entered(body: Node2D) -> void:
	_switch_layer(body, null, m_ground, body.global_position)

func _on_body_exited(body: Node2D) -> void:
	_switch_layer(body, m_ground, null, body.global_position)
