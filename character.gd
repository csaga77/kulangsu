@tool
extends CharacterBody2D

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

@onready var m_body    = $body
@onready var m_pants   = $body/pants
@onready var m_clothes = $body/clothes
@onready var m_hair    = $body/hair
@onready var m_foot    = $body/foot

var m_clothes_frames :SpriteFrames
var m_pants_frames   :SpriteFrames
var m_hair_frames    :SpriteFrames
var m_foot_frames    :SpriteFrames

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	m_clothes_frames = load("res://sprites/male_animations.tres").duplicate()
	m_pants_frames   = load("res://sprites/male_animations.tres").duplicate()
	m_hair_frames    = load("res://sprites/male_animations.tres").duplicate()
	m_foot_frames    = load("res://sprites/male_animations.tres").duplicate()

	var cloth_texture :Texture2D = load("res://sprites/male_longsleeve.png")
	var pant_texture  :Texture2D = load("res://sprites/male_longpants.png")
	var hair_texture  :Texture2D = load("res://sprites/hair_black.png")
	var foot_texture  :Texture2D = load("res://sprites/basic_shoes_black.png")

	var animations = m_clothes_frames.get_animation_names()
	for animation_name in animations:
		var count = m_clothes_frames.get_frame_count(animation_name)
		for i in count:
			var tex :AtlasTexture = m_clothes_frames.get_frame_texture(animation_name, i).duplicate()
			if tex != null:
				tex.atlas = cloth_texture
				m_clothes_frames.set_frame(animation_name, i, tex)

			tex = m_pants_frames.get_frame_texture(animation_name, i).duplicate()
			if tex != null:
				tex.atlas = pant_texture
				m_pants_frames.set_frame(animation_name, i, tex)

			tex = m_hair_frames.get_frame_texture(animation_name, i).duplicate()
			if tex != null:
				tex.atlas = hair_texture
				m_hair_frames.set_frame(animation_name, i, tex)

			tex = m_foot_frames.get_frame_texture(animation_name, i).duplicate()
			if tex != null:
				tex.atlas = foot_texture
				m_foot_frames.set_frame(animation_name, i, tex)

	m_clothes.sprite_frames = m_clothes_frames
	m_pants.sprite_frames   = m_pants_frames
	m_hair.sprite_frames    = m_hair_frames
	m_foot.sprite_frames    = m_foot_frames

	_update_state()

func _is_in_range(value, min, max) -> bool:
	return value >= min and value <= max

func _normalize_angle(degrees):
	var d = fmod(degrees, 360)
	if d < 0:
		d += 360
	return d

func _update_state() -> void:
	if m_body == null:
		return
	var animation_name = "walk" if is_walking else "idle"
	if is_walking:
		if is_running:
			animation_name = "run"
	animation_name += "_"
	var normalized_direction = _normalize_angle(direction)
	if _is_in_range(normalized_direction, 0, 45) or _is_in_range(normalized_direction, 315, 360):
		animation_name += "right"
	elif _is_in_range(normalized_direction, 45, 135):
		animation_name += "up"
	elif _is_in_range(normalized_direction, 135, 225):
		animation_name += "left"
	elif _is_in_range(normalized_direction, 225, 315):
		animation_name += "down"
	m_body.stop()
	m_body.play(animation_name)
	
	m_pants.stop()
	m_pants.play(animation_name)
	
	m_clothes.stop()
	m_clothes.play(animation_name)
	
	m_hair.stop()
	m_hair.play(animation_name)
	
	m_foot.stop()
	m_foot.play(animation_name)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
