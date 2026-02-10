@tool
class_name Player
extends CharacterBody2D

enum BodyTypeEnum
{
	MALE = 0,
	FEMALE = 1
}

signal global_position_changed()

#signal texture_changed()

@export var draw_bounding_rect := false

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
		
enum HairStyle {
	Bald,
	LongLoose,
	Short,
	ShortBangsShort,
	ShortBangs,
	ShortBedhead,
	ShortCowlick,
	ShortCowlickTall,
	ShortCurtains,
	ShortIdol,
	Ponytail,
	Spiked,
	SpikedBeehive,
	SpikedLiberty,
	SpikedPorcupine,
	Spiked2,
}

@export var hair_style :HairStyle = HairStyle.Short:
	set(new_style) :
		if hair_style == new_style:
			return
		hair_style = new_style
		_reload()

@export var hair_color :Color = Color.BLACK:
	set(new_color):
		if hair_color == new_color:
			return
		hair_color = new_color
		_reload()
		
func jump() -> void:
	if m_is_jumping:
		return
	m_is_jumping = true
	_update_state()
		
func get_local_bounding_rect() -> Rect2:
	var t := get_texture()
	if t:
		var v = t.get_size()
		return Rect2(-Vector2(v.x / 2, v.y), v)
	return Rect2(- Vector2(16, 64), Vector2(32, 64))
		
func get_bounding_rect() -> Rect2:
	var br = get_local_bounding_rect()
	br.position += global_position
	return br
	
func get_local_ground_rect() -> Rect2:
	return Rect2(- Vector2(16, 32), Vector2(32, 32))
	
func get_ground_rect() -> Rect2:
	var br = get_local_ground_rect()
	br.position += global_position
	return br

func get_texture() -> Texture2D:
	if m_sprite == null:
		return null
	return m_sprite.sprite_frames.get_frame_texture(m_sprite.animation, m_sprite.frame)
	
func move(direction_vector) -> void:
	velocity = direction_vector * (300 if is_running else 100)
	if m_is_jumping and (m_sprite.frame < 1 or m_sprite.frame == 5):
		return
	move_and_slide()
	
var m_male_frames := [
	"res://resources/sprites/characters/male/male_body.png",
	"res://resources/sprites/characters/male/male_basic_shoes_black.png",
	#"res://resources/sprites/characters/male/male_longpants_black.png",
	"res://resources/sprites/characters/male/male_shorts_leather.png",
	#"res://resources/sprites/characters/male/male_longsleeve_white.png",
	"res://resources/sprites/characters/male/male_sleeveless_white.png",
	#"res://resources/sprites/characters/backpack_black.png",
	"res://resources/sprites/characters/male/male_head.png",
]

var m_female_frames := [
	"res://resources/sprites/characters/female/female_body.png",
	"res://resources/sprites/characters/female/female_basic_shoes_black.png",
	#"res://resources/sprites/characters/female/female_longpants_black.png",
	"res://resources/sprites/characters/female/female_shorts_leather.png",
	"res://resources/sprites/characters/female/female_sleeveless_white.png",
	#"res://resources/sprites/characters/female/female_longsleeve_white.png",
	#"res://resources/sprites/characters/backpack_black.png",
	"res://resources/sprites/characters/female/female_head.png",
]


var m_hair_sprites := {
	HairStyle.Bald : "",
	HairStyle.LongLoose: "res://resources/sprites/characters/hair/hair_long_loose_blonde.png",
	HairStyle.Short : "res://resources/sprites/characters/hair/hair_short_black.png",
	HairStyle.ShortBangsShort : "res://resources/sprites/characters/hair/hair_short_bangs_short_white.png",
	HairStyle.ShortBangs : "res://resources/sprites/characters/hair/hair_short_bangs_white.png",
	HairStyle.ShortBedhead : "res://resources/sprites/characters/hair/hair_short_bedhead_white.png",
	HairStyle.ShortCowlick : "res://resources/sprites/characters/hair/hair_short_cowlick_white.png",
	HairStyle.ShortCowlickTall : "res://resources/sprites/characters/hair/hair_short_cowlick_tall_white.png",
	HairStyle.ShortCurtains : "res://resources/sprites/characters/hair/hair_short_curtains_white.png",
	HairStyle.ShortIdol : "res://resources/sprites/characters/hair/hair_short_idol_white.png",
	HairStyle.Ponytail : "res://resources/sprites/characters/hair/hair_ponytail_white.png",
	HairStyle.Spiked : "res://resources/sprites/characters/hair/hair_spiked_white.png",
	HairStyle.SpikedBeehive : "res://resources/sprites/characters/hair/hair_spiked_beehive_white.png",
	HairStyle.SpikedLiberty : "res://resources/sprites/characters/hair/hair_spiked_liberty_white.png",
	HairStyle.SpikedPorcupine : "res://resources/sprites/characters/hair/hair_spiked_porcupine_white.png",
	HairStyle.Spiked2 : "res://resources/sprites/characters/hair/hair_spiked2_white.png",
}

var m_root :Node2D
var m_sprite :AnimatedSprite2D
var m_last_global_position := Vector2.ZERO
var m_is_reloading := false
var m_is_jumping := false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	m_root = self
	_reload()

func _reload():
	if m_is_reloading:
		return
	m_is_reloading = true
	call_deferred("_do_reload")
	
func _do_reload():
	m_is_reloading = false
	if m_root == null:
		return
	for node in m_root.get_children():
		if node is AnimatedSprite2D:
			node.queue_free()
			
	var body :AnimatedSprite2D = AnimatedSprite2D.new()
	m_sprite = body
	#m_sprite.material = material
	m_root.add_child(m_sprite)
	m_sprite.position = Vector2(0, -32)
	m_sprite.animation_finished.connect(self._on_animation_finished)

	var sprite_frames_template :SpriteFrames = load("res://resources/animations/characters/male_animations.tres").duplicate()
	m_sprite.sprite_frames = sprite_frames_template
	
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
			
	var hair_sprite :String = m_hair_sprites.get(hair_style, "")
	if !hair_sprite.is_empty():
		var hair_texture :Texture2D = load(hair_sprite)
		if hair_texture != null:
			var img = hair_texture.get_image()
			img = ImageUtils.colorize_image(img, hair_color)
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

func _update_state() -> void:
	if m_sprite == null:
		return
	m_sprite.position = Vector2(0, -32)
	var animation_name = "walk" if is_walking else "idle"
	if m_is_jumping:
		animation_name = "jump"
	elif is_walking:
		if is_running:
			animation_name = "run"
	animation_name += "_"
	var normalized_direction = CommonUtils.normalize_angle(direction)
	if CommonUtils.is_in_range(normalized_direction, 0, 45.01) or CommonUtils.is_in_range(normalized_direction, 314.09, 360):
		animation_name += "right"
	elif CommonUtils.is_in_range(normalized_direction, 135, 225):
		animation_name += "left"
	elif CommonUtils.is_in_range(normalized_direction, 45, 135):
		animation_name += "up"
	elif CommonUtils.is_in_range(normalized_direction, 225, 315):
		animation_name += "down"
		
	for node in m_root.get_children():
		if node is AnimatedSprite2D:
			node.stop()
			node.play(animation_name)
			#if !node.frame_changed.is_connected(self.texture_changed.emit):
				#node.frame_changed.connect(self.texture_changed.emit)
		
func _on_animation_frame_changed() -> void:
	#if m_is_jumping and m_sprite.animation.contains("jump"):
	pass
		
		
func _on_animation_finished() -> void:
	if m_is_jumping and m_sprite.animation.contains("jump"):
		m_is_jumping = false
		_update_state()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if !m_last_global_position.is_equal_approx(global_position):
		m_last_global_position = global_position
		global_position_changed.emit()
		if draw_bounding_rect:
			queue_redraw()

func _draw() -> void:
	if draw_bounding_rect:
		draw_rect(get_local_bounding_rect(), Color.RED, false)
		draw_rect(get_local_ground_rect(), Color.BLUE, false)
