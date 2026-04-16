@tool
class_name StoryInspectable
extends LevelArea2D

const STORY_INSPECTABLE_LEVEL_REGISTRY := preload("res://common/level_registry.gd")

@export var inspectable_id: String = ""
@export var display_name: String = "Inspect"
@export var debug_draw := false
@export var debug_color: Color = Color(0.28, 0.82, 0.96, 0.35)


func _init() -> void:
	level_id = 0
	level_id_mode = STORY_INSPECTABLE_LEVEL_REGISTRY.LevelIdMode.RELATIVE_TO_PARENT
	sync_z_index_to_resolved_level = true


func _draw() -> void:
	if !debug_draw:
		return
	var radius := 28.0
	for child in get_children():
		var shape_node := child as CollisionShape2D
		if shape_node != null and shape_node.shape is CircleShape2D:
			radius = (shape_node.shape as CircleShape2D).radius
			break
	draw_circle(Vector2.ZERO, radius, debug_color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(debug_color.r, debug_color.g, debug_color.b, 0.85), 1.5)
	var label_text := inspectable_id if !inspectable_id.is_empty() else display_name
	var font := ThemeDB.fallback_font
	var font_size := ThemeDB.fallback_font_size
	var text_size := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, Vector2(-text_size.x * 0.5, -radius - 6.0), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
