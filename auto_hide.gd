@tool
extends TileMapLayer

@export var character :Character = null:
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
	if character != null and character.z_index < z_index:
		visible = !Utils.intersects_rect_global(self, character.get_bounding_rect())
	else:
		visible = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if character == null:
		return
	var rect :Rect2
	rect.position = character.global_position - Vector2(16, 4)
	rect.size = Vector2(32, 32)
