@tool
extends TileMapLayer

@export var semi_transparent := false

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

func _update_character() -> void:
	pass

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _on_character_global_position_changed() -> void:
	if character != null and CommonUtils.get_absolute_z_index(character) < CommonUtils.get_absolute_z_index(self):
		var _is_visible = !Utils.intersects_rect_global(self, character.get_bounding_rect())
		visible = semi_transparent || _is_visible
		modulate.a = 1.0 if _is_visible else 0.5
	else:
		visible = true
		modulate.a = 1.0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if character == null:
		return
	var rect :Rect2
	rect.position = character.global_position - Vector2(16, 4)
	rect.size = Vector2(32, 32)
