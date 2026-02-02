@tool
class_name TestScene
extends Node2D

@export var building :PackedScene:
	set(new_building):
		if building == new_building:
			return
		building = new_building
		call_deferred("_reload_building")
		
@onready var m_player :Player = $Player
@onready var m_root   :Node2D = $Root

func _ready() -> void:
	if Engine.is_editor_hint():
		var shader_material :ShaderMaterial = m_root.material
		if shader_material:
			shader_material.set_shader_parameter("trans_rect_size", Vector2i.ZERO)
	else:
		GameGlobal.get_instance().set_player(m_player)
		m_player.global_position_changed.connect(self._on_player_moved)
		#m_player.texture_changed.connect(self._on_player_texture_changed)
		
	_reload_building()

func _reload_building() -> void:
	if m_root:
		for child in m_root.get_children():
			child.queue_free()

	if building:
		var new_building = building.instantiate()
		m_root.add_child(new_building)
		#print("_reload_building()")

func _process(_delta: float) -> void:
	pass

func _on_player_texture_changed() -> void:
	var shader_material :ShaderMaterial = m_root.material
	if shader_material:
		var tex :AtlasTexture = m_player.get_texture()
		if tex:
			var r = tex.region;
			var atlas_size = tex.atlas.get_size()
			var region := Vector4(r.position.x / atlas_size.x, r.position.y / atlas_size.y, r.size.x / atlas_size.x, r.size.y / atlas_size.y)
			shader_material.set_shader_parameter("player_texture_region", region)
		else:
			shader_material.set_shader_parameter("player_texture_region", Vector4.ZERO)
		shader_material.set_shader_parameter("player_texture", m_player.get_texture())
		
func _on_player_moved() -> void:
	var bounding_rect := m_player.get_bounding_rect()
	var shader_material :ShaderMaterial = m_root.material
	if shader_material:
		shader_material.set_shader_parameter("trans_rect_pos", bounding_rect.position)
		shader_material.set_shader_parameter("trans_rect_size", bounding_rect.size)
		#m_player.get_texture().get_image().save_png("user://test.png")
