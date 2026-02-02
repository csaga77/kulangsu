@tool
class_name AutoVisibilityNode2D
extends Node2D

@export var semi_transparent_mask_layers :Array[TileMapLayer]
@export var semi_transparent_mask_areas :Array[Area2D]:
	set(new_areas):
		if semi_transparent_mask_areas == new_areas:
			return
		semi_transparent_mask_areas = new_areas
		_update_areas()
@export var visibility_mask_layers :Array[TileMapLayer]
@export var use_ground_bounding_rect := false
@export var smooth_visibility_change := false

var m_player :Player
var m_shader_material :ShaderMaterial
var m_in_semi_transparent_areas_count := 0
var m_target_visible := true
var m_is_changing_visibility := false

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
	m_shader_material = material
	if !Engine.is_editor_hint():
		if GameGlobal.get_instance():
			GameGlobal.get_instance().player_changed.connect(self._on_player_changed)
	_on_player_changed()
	_update_areas()

func _update_areas() -> void:
	for area in semi_transparent_mask_areas:
		if !area.body_entered.is_connected(self._on_semit_transparent_area_entered):
			area.body_entered.connect(self._on_semit_transparent_area_entered)
		if !area.body_exited.is_connected(self._on_semit_transparent_area_exited):
			area.body_exited.connect(self._on_semit_transparent_area_exited)

func _on_semit_transparent_area_entered(body: Node2D) -> void:
	if body == m_player:
		m_in_semi_transparent_areas_count += 1
		
func _on_semit_transparent_area_exited(body: Node2D) -> void:
	if body == m_player:
		m_in_semi_transparent_areas_count -= 1

func _on_player_changed() -> void:
	if Engine.is_editor_hint():
		return
	set_player(GameGlobal.get_instance().get_player())

func _set_visible(new_is_visible: bool) -> void:
	if smooth_visibility_change:
		if m_target_visible != new_is_visible:
			m_target_visible = new_is_visible
			var tween = AnimationUtils.tween_node2d_visibility(self, new_is_visible)
			if tween:
				m_is_changing_visibility = true
				tween.finished.connect(func():
					m_is_changing_visibility = false
				)
	else:
		visible = new_is_visible

func _on_character_global_position_changed() -> void:
	if Engine.is_editor_hint():
		return
	var is_semi_transparent := m_in_semi_transparent_areas_count > 0
	#print(is_semi_transparent)
	var should_be_visible := true
	var bounding_rect :Rect2
	if m_player:
		bounding_rect = m_player.get_ground_rect() if use_ground_bounding_rect else m_player.get_bounding_rect()
		for layer in visibility_mask_layers:
			if CommonUtils.get_absolute_z_index(m_player) > CommonUtils.get_absolute_z_index(layer):
				continue
			if TileMapUtils.intersects_iso_grid_rect_global(layer, bounding_rect):
				should_be_visible = false
				break
		for layer in semi_transparent_mask_layers:
			if CommonUtils.get_absolute_z_index(m_player) != CommonUtils.get_absolute_z_index(layer):
				#print(layer.name, "false")
				continue
			if TileMapUtils.intersects_iso_grid_rect_global(layer, bounding_rect):
				#print(layer.name, "true")
				is_semi_transparent = true
				break
			#else:
				#print(layer.name, ": false")
				
	_set_visible(should_be_visible)
	
	#print(is_semi_transparent)
	if !m_is_changing_visibility:
		if m_shader_material:
			modulate.a = 1.0
			if should_be_visible and !is_semi_transparent:
				if material:
					#print(name, " null ", should_be_visible)
					material = null
			else:
				if material == null:
					#print(name, " material ", should_be_visible)
					material = m_shader_material
			#leave the transparency to wall_transparent.shader
			#shader paramters are updated in global auto visiblity material.
			#if is_semi_transparent:
				#shader_material.set_shader_parameter("trans_rect_pos", bounding_rect.position)
				#shader_material.set_shader_parameter("trans_rect_size", bounding_rect.size)
			#else:
				#shader_material.set_shader_parameter("trans_rect_size", Vector2.ZERO)
		else:
			modulate.a = 0.1 if is_semi_transparent else 1.0
	
