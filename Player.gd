@tool
class_name Player
extends CharacterBody2D

enum BodyTypeEnum
{
	MALE = 0,
	FEMALE = 1
}

signal global_position_changed()

@export var body_type :BodyTypeEnum = BodyTypeEnum.MALE:
	set(new_body_type):
		if body_type == new_body_type:
			return
		body_type = new_body_type
		_reload()

@export var direction :float = 0:
	set(new_direction):
		if direction == new_direction:
			return
		direction = new_direction
		_update_state()
		
@export var is_walking :bool = false:
	set(new_is_walking):
		if is_walking == new_is_walking:
			return
		is_walking = new_is_walking
		_update_state()
		
@export var is_running :bool = false:
	set(new_is_running):
		if is_running == new_is_running:
			return
		is_running = new_is_running
		_update_state() 
		
func get_bounding_rect() -> Rect2:
	return Rect2(global_position - Vector2(16, 32), Vector2(32, 64))
	
func get_ground_rect() -> Rect2:
	return Rect2(global_position - Vector2(16, 4), Vector2(32, 32))

var m_male_frames := [
	"res://sprites/male/male_body.png",
	"res://sprites/male/male_basic_shoes_black.png",
	"res://sprites/male/male_longpants_black.png",
	"res://sprites/male/male_longsleeve_white.png",
	#"res://sprites/backpack_black.png",
	"res://sprites/male/male_head.png",
	"res://sprites/hair_short_black.png",
]

var m_female_frames := [
	"res://sprites/female/female_body.png",
	"res://sprites/female/female_basic_shoes_black.png",
	"res://sprites/female/female_longpants_black.png",
	"res://sprites/female/female_longsleeve_white.png",
	#"res://sprites/backpack_black.png",
	"res://sprites/female/female_head.png",
	"res://sprites/hair_long_loose_blonde.png",
]

var m_last_global_position := Vector2.ZERO

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_reload()

func _reload():
	for node in get_children():
		if node is AnimatedSprite2D:
			node.queue_free()
			
	var body :AnimatedSprite2D = AnimatedSprite2D.new()
	add_child(body)
	body.position = Vector2(0, -32)

	var sprite_frames_template :SpriteFrames = load("res://sprites/male_animations.tres").duplicate()
	body.sprite_frames = sprite_frames_template
	
	var combined_image :Image = null
	var frames = m_male_frames
	if body_type == BodyTypeEnum.FEMALE:
		frames = m_female_frames
	for texture_file in frames:
		var frame_texture :Texture2D = load(texture_file)
		if combined_image == null:
			combined_image = frame_texture.get_image()
		else:
			var img = frame_texture.get_image()
			combined_image.blend_rect(img, img.get_used_rect(), img.get_used_rect().position)
	
	var texture := ImageTexture.create_from_image(combined_image)
	var animations = sprite_frames_template.get_animation_names()
	for animation_name in animations:
		var count = sprite_frames_template.get_frame_count(animation_name)
		for i in count:
			var tex :AtlasTexture = sprite_frames_template.get_frame_texture(animation_name, i).duplicate()
			if tex != null:
				tex.atlas = texture
				sprite_frames_template.set_frame(animation_name, i, tex)

	_update_state()

func _is_in_range(value, min_value, max_value) -> bool:
	return value >= min_value and value <= max_value

func _normalize_angle(degrees):
	var d = fmod(degrees, 360)
	if d < 0:
		d += 360
	return d

func _update_state() -> void:
	var animation_name = "walk" if is_walking else "idle"
	if is_walking:
		if is_running:
			animation_name = "run"
	animation_name += "_"
	var normalized_direction = _normalize_angle(direction)
	if _is_in_range(normalized_direction, 0, 45.01) or _is_in_range(normalized_direction, 314.09, 360):
		animation_name += "right"
	elif _is_in_range(normalized_direction, 135, 225):
		animation_name += "left"
	elif _is_in_range(normalized_direction, 45, 135):
		animation_name += "up"
	elif _is_in_range(normalized_direction, 225, 315):
		animation_name += "down"
		
	for node in get_children():
		if node is AnimatedSprite2D:
			node.stop()
			node.play(animation_name)
		
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if !m_last_global_position.is_equal_approx(global_position):
		global_position_changed.emit()
