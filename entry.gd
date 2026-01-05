@tool
class_name Entry
extends Node2D

@export var layer1: TileMapLayer
@export var layer2: TileMapLayer

@export_enum("top-right:0", "top-left:1", "bottom-left:2", "bottom-right:3") var direction := 0:
	set(new_direction):
		if direction == new_direction:
			return
		direction = new_direction
		_update_direction()

@onready var m_entry1 :Node2D = $Entry1
@onready var m_entry2 :Node2D = $Entry2
var m_entry_positions := [
	Vector2(32, -16), 
	Vector2(-32, -16), 
	Vector2(-32, 16), 
	Vector2(32, 16), 
]
		
func _update_direction() -> void:
	if m_entry2 == null:
		return
	m_entry2.position = m_entry_positions.get(direction)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_update_direction()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _switch_layer(body: Node2D, source_layer :TileMapLayer, target_layer :TileMapLayer, default_position :Vector2) -> void:
	var character := body as Character
	if character == null:
		return
	character.switch_layer(source_layer, target_layer, default_position)
	
var m_on_layer1 := false
var m_on_layer2 := false

func _on_entry_1_body_entered(body: Node2D) -> void:
	m_on_layer1 = true
	_switch_layer(body, layer2, layer1, m_entry1.global_position)
	
func _on_entry_1_body_exited(body: Node2D) -> void:
	m_on_layer1 = false
	if m_on_layer2:
		_switch_layer(body, layer1, layer2, m_entry2.global_position)

func _on_entry_2_body_entered(body: Node2D) -> void:
	m_on_layer2 = true
	_switch_layer(body, layer1, layer2, m_entry2.global_position)

func _on_entry_2_body_exited(body: Node2D) -> void:
	m_on_layer2 = false
	if m_on_layer1:
		_switch_layer(body, layer2, layer1, m_entry1.global_position)
		
