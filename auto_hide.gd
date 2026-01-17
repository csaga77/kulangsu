@tool
extends TileMapLayer

@export var target_nodes :Dictionary[Node2D, bool]

@export var character :Player = null:
	set(new_character):
		if character == new_character:
			return
		if character:
			character.global_position_changed.disconnect(self._on_character_global_position_changed)
		character = new_character
		if character:
			character.global_position_changed.connect(self._on_character_global_position_changed)
		_on_character_global_position_changed()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if GameGlobal.get_instance():
		GameGlobal.get_instance().player_changed.connect(self._on_player_changed)
	_on_player_changed()

func _on_player_changed() -> void:
	character = GameGlobal.get_instance().get_player()

func _on_character_global_position_changed() -> void:
	if CommonUtils.get_absolute_z_index(character) != CommonUtils.get_absolute_z_index(self):
		return
	var _is_visible = true
	if character != null:
		_is_visible = !Utils.intersects_rect_global(self, character.get_bounding_rect())
	else:
		_is_visible = true
		
	for node in target_nodes.keys():
		var is_semi_transparent = target_nodes.get(node, false)
		node.visible = is_semi_transparent || _is_visible
		node.modulate.a = 1.0 if _is_visible else 0.2
