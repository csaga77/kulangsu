@tool
class_name AutoVisibilityNode2D
extends IsometricBlock

@export var semi_transparent_mask_layers :Array[TileMapLayer]
@export var visibility_mask_layers :Array[TileMapLayer]
@export var use_ground_bounding_rect := false
@export var smooth_visibility_change := false
@export var is_enabled := true

var m_player :Player
var m_shader_material :ShaderMaterial
var m_target_visible := true
var m_is_changing_visibility := false

func _ready() -> void:
	super._ready()
	m_shader_material = material
	if !Engine.is_editor_hint():
		if GameGlobal.get_instance():
			GameGlobal.get_instance().player_changed.connect(self._on_player_changed)
	_on_player_changed()

func _on_player_changed() -> void:
	if Engine.is_editor_hint():
		return
	_set_player(GameGlobal.get_instance().get_player())

func _set_player(new_character):
	if m_player == new_character:
		return
	if m_player:
		m_player.global_position_changed.disconnect(self._update_visibility)
	m_player = new_character
	if m_player:
		m_player.global_position_changed.connect(self._update_visibility)
	_update_visibility()

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

func _update_visibility() -> void:
	if Engine.is_editor_hint():
		return
	if not is_enabled:
		return
	var is_semi_transparent := false
	#print(is_semi_transparent)
	var should_be_visible := true
	var bounding_rect :Rect2
	if m_player:
		bounding_rect = m_player.get_ground_rect() if use_ground_bounding_rect else m_player.get_bounding_rect()
		for layer in visibility_mask_layers:
			if not layer.enabled:
				continue
			if CommonUtils.get_absolute_z_index(m_player) > CommonUtils.get_absolute_z_index(layer):
				continue
			if TileMapUtils.intersects_iso_grid_rect_global(layer, bounding_rect):
				should_be_visible = false
				break
		for layer in semi_transparent_mask_layers:
			if not layer.enabled:
				continue
			if CommonUtils.get_absolute_z_index(m_player) > CommonUtils.get_absolute_z_index(layer):
				continue
			if TileMapUtils.intersects_iso_grid_rect_global(layer, bounding_rect):
				is_semi_transparent = true
				break
	_set_visible(should_be_visible)
	
	if !m_is_changing_visibility:
		if m_shader_material:
			modulate.a = 1.0
			if should_be_visible and !is_semi_transparent:
				if material:
					material = null
			else:
				if material == null:
					material = m_shader_material
		else:
			modulate.a = 0.1 if is_semi_transparent else 1.0
	
