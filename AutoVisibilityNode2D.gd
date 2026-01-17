@tool
class_name AutoVisibilityNode2D
extends Node2D

@export var semi_transparent_mask_layers :Array[TileMapLayer]
@export var visibility_mask_layers 	:Array[TileMapLayer]

var m_player :Player

func set_player(new_character):
		if m_player == new_character:
			return
		if m_player:
			m_player.global_position_changed.disconnect(self._on_character_global_position_changed)
		m_player = new_character
		if m_player:
			m_player.global_position_changed.connect(self._on_character_global_position_changed)
		_on_character_global_position_changed()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if GameGlobal.get_instance():
		GameGlobal.get_instance().player_changed.connect(self._on_player_changed)
	_on_player_changed()

func _on_player_changed() -> void:
	set_player(GameGlobal.get_instance().get_player())

func _on_character_global_position_changed() -> void:
	var is_semi_transparent := false
	var should_be_visible := true
	var bounding_rect :Rect2
	if m_player:
		bounding_rect = m_player.get_bounding_rect()
		for layer in visibility_mask_layers:
			if CommonUtils.get_absolute_z_index(m_player) != CommonUtils.get_absolute_z_index(layer):
				continue
			if Utils.intersects_rect_global(layer, bounding_rect):
				should_be_visible = false
				break
		for layer in semi_transparent_mask_layers:
			if CommonUtils.get_absolute_z_index(m_player) != CommonUtils.get_absolute_z_index(layer):
				continue
			if Utils.intersects_rect_global(layer, bounding_rect):
				#print(layer.name)
				is_semi_transparent = true
				break
	visible = should_be_visible
	var shader_material :ShaderMaterial = material
	if shader_material:
		modulate.a = 1.0
		#leave the transparency to wall_transparent.shader
		#shader paramters are updated in global auto visiblity material.
		#if is_semi_transparent:
			#shader_material.set_shader_parameter("trans_rect_pos", bounding_rect.position)
			#shader_material.set_shader_parameter("trans_rect_size", bounding_rect.size)
		#else:
			#shader_material.set_shader_parameter("trans_rect_size", Vector2.ZERO)
	else:
		modulate.a = 0.1 if is_semi_transparent else 1.0
	
