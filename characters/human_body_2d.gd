# res://characters/human_body_2d.gd
@tool
class_name HumanBody2D
extends CharacterBody2D

signal global_position_changed()

const BASE_SPRITE_OFFSET: Vector2 = Vector2(0, -32)

enum BodyTypeEnum {
	MALE = 0,
	FEMALE = 1,
	TEEN = 2,
	CHILD = 3,
	MUSCULAR = 4,
	PREGNANT = 5,
}

@export var draw_bounding_rect: bool = false

@export var direction: float = 0.0:
	set(v):
		if is_equal_approx(direction, v):
			return
		direction = v
		_update_state()

@export var is_walking: bool = false:
	set(v):
		if is_walking == v:
			return
		is_walking = v
		_update_state()

@export var is_running: bool = false:
	set(v):
		if is_running == v:
			return
		is_running = v
		_update_state()

# -------------------------------------------------------------------
# Appearance / sprite generation
# -------------------------------------------------------------------
@export var body_type: BodyTypeEnum = BodyTypeEnum.MALE:
	set(v):
		if body_type == v:
			return
		body_type = v
		_refresh_options_and_clamp_selections()
		_reload()
		_update_state()

@export var refresh_sprite_options: bool = false:
	set(_v):
		refresh_sprite_options = false
		if Engine.is_editor_hint():
			_refresh_options_and_clamp_selections()
			_reload()

@export var body_color: Color = Color.WHITE:
	set(v):
		if body_color == v:
			return
		body_color = v
		_reload()

@export var hair_color: Color = Color.BLACK:
	set(v):
		if hair_color == v:
			return
		hair_color = v
		_reload()

@export var legs_color: Color = Color.WHITE:
	set(v):
		if legs_color == v:
			return
		legs_color = v
		_reload()

@export var shirt_color: Color = Color.WHITE:
	set(v):
		if shirt_color == v:
			return
		shirt_color = v
		_reload()

@export var feet_color: Color = Color.WHITE:
	set(v):
		if feet_color == v:
			return
		feet_color = v
		_reload()

# Stored values (persisted) for dynamic dropdowns on HumanBody2D
@export_storage var m_animation: String = "idle_s"

@export_storage var m_body: String = "Default"
@export_storage var m_hair: String = "Bald"
@export_storage var m_legs: String = "<none>"
@export_storage var m_shirt: String = "<none>"
@export_storage var m_head: String = "<none>"
@export_storage var m_feet: String = "<none>"

# -------------------------------------------------------------------
# Runtime
# -------------------------------------------------------------------
@onready var m_anim_node: AnimatedSprite2D

var m_last_global_position: Vector2 = Vector2.ZERO
var m_is_currently_jumping: bool = false
var m_current_animation_name: String = ""

var m_is_reloading: bool = false

# Cached options for building inspector hint strings (names only)
var m_anim_options: Array[String] = []
var m_body_options: Array[String] = []
var m_hair_options: Array[String] = []
var m_legs_options: Array[String] = []
var m_shirt_options: Array[String] = []
var m_head_options: Array[String] = []
var m_feet_options: Array[String] = []

func _ready() -> void:
	m_anim_node = AnimatedSprite2D.new()
	m_anim_node.name = "sprite"
	add_child(m_anim_node)

	_refresh_options_and_clamp_selections()
	_reload()
	_connect_jump_signals()
	_update_state()

# ------------------------------------------------------------
# Dynamic inspector properties (dropdowns on HumanBody2D)
# ------------------------------------------------------------

func _get_property_list() -> Array:
	var property_list: Array = []

	if m_anim_node == null:
		return property_list

	if m_anim_options.is_empty() \
	or m_body_options.is_empty() \
	or m_hair_options.is_empty() \
	or m_legs_options.is_empty() \
	or m_shirt_options.is_empty() \
	or m_head_options.is_empty() \
	or m_feet_options.is_empty():
		_refresh_options_and_clamp_selections()

	property_list.append({
		"name": "animation",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(m_anim_options)
	})

	property_list.append({
		"name": "body",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(m_body_options)
	})
	property_list.append({
		"name": "hair",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(m_hair_options)
	})
	property_list.append({
		"name": "legs",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(m_legs_options)
	})
	property_list.append({
		"name": "shirt",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(m_shirt_options)
	})
	property_list.append({
		"name": "head",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(m_head_options)
	})
	property_list.append({
		"name": "feet",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(m_feet_options)
	})

	return property_list

func _set(property_name: StringName, value: Variant) -> bool:
	var p := String(property_name)
	var v :String
	if value is String:
		v = String(value)

	if p == "animation":
		if m_animation == v:
			return true
		m_animation = v
		call_deferred("_apply_animation_value")
		return true

	var f := UniversalLPCSpriteFactory.get_instance()

	if p == "body":
		v = f.get_valid_style_value(v, m_body_options)
		if m_body == v:
			return true
		m_body = v
		_reload()
		if Engine.is_editor_hint():
			notify_property_list_changed()
		return true

	if p == "hair":
		v = f.get_valid_style_value(v, m_hair_options)
		if m_hair == v:
			return true
		m_hair = v
		_reload()
		if Engine.is_editor_hint():
			notify_property_list_changed()
		return true

	if p == "legs":
		v = f.get_valid_style_value(v, m_legs_options)
		if m_legs == v:
			return true
		m_legs = v
		_reload()
		if Engine.is_editor_hint():
			notify_property_list_changed()
		return true

	if p == "shirt":
		v = f.get_valid_style_value(v, m_shirt_options)
		if m_shirt == v:
			return true
		m_shirt = v
		_reload()
		if Engine.is_editor_hint():
			notify_property_list_changed()
		return true

	if p == "head":
		v = f.get_valid_style_value(v, m_head_options)
		if m_head == v:
			return true
		m_head = v
		_reload()
		if Engine.is_editor_hint():
			notify_property_list_changed()
		return true

	if p == "feet":
		v = f.get_valid_style_value(v, m_feet_options)
		if m_feet == v:
			return true
		m_feet = v
		_reload()
		if Engine.is_editor_hint():
			notify_property_list_changed()
		return true

	return false

func _get(property_name: StringName) -> Variant:
	var p := String(property_name)

	if p == "animation":
		return m_animation
	if p == "body":
		return m_body
	if p == "hair":
		return m_hair
	if p == "legs":
		return m_legs
	if p == "shirt":
		return m_shirt
	if p == "head":
		return m_head
	if p == "feet":
		return m_feet

	return null

# ------------------------------------------------------------
# Character actions and rectangles
# ------------------------------------------------------------

func jump() -> void:
	if m_is_currently_jumping:
		return
	m_is_currently_jumping = true
	_update_state()

func move(direction_vector: Vector2) -> void:
	var dir_vec: Vector2 = direction_vector
	if dir_vec.length_squared() > 0.000001:
		dir_vec = dir_vec.normalized()

	var movement_speed: float = 300.0 if is_running else 100.0
	velocity = dir_vec * movement_speed

	var sprite := _get_sprite()
	if sprite != null and m_is_currently_jumping and (sprite.frame <= 1 or sprite.frame == 7):
		return

	move_and_slide()

func get_texture() -> Texture2D:
	var sprite := _get_sprite()
	if sprite == null or sprite.sprite_frames == null:
		return null
	return sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)

func get_local_bounding_rect() -> Rect2:
	var current_texture: Texture2D = get_texture()
	if current_texture:
		var texture_size: Vector2 = current_texture.get_size()
		return Rect2(-Vector2(texture_size.x * 0.5, texture_size.y), texture_size)
	return Rect2(Vector2(-16, -64), Vector2(32, 64))

func get_bounding_rect() -> Rect2:
	var local_bounding_rect: Rect2 = get_local_bounding_rect()
	local_bounding_rect.position += global_position
	return local_bounding_rect

func get_local_ground_rect() -> Rect2:
	return Rect2(Vector2(-16, -32), Vector2(32, 32))

func get_ground_rect() -> Rect2:
	var local_ground_rect: Rect2 = get_local_ground_rect()
	local_ground_rect.position += global_position
	return local_ground_rect

# ------------------------------------------------------------
# Jump logic
# ------------------------------------------------------------

func _connect_jump_signals() -> void:
	var sprite := _get_sprite()
	if sprite == null:
		return

	if !sprite.animation_finished.is_connected(_on_animation_finished):
		sprite.animation_finished.connect(_on_animation_finished)
	if !sprite.frame_changed.is_connected(_on_animation_frame_changed):
		sprite.frame_changed.connect(_on_animation_frame_changed)

func _on_animation_frame_changed() -> void:
	var sprite := _get_sprite()
	if sprite == null:
		return

	_set_sprite_offset(BASE_SPRITE_OFFSET)

	if m_is_currently_jumping and sprite.frame > 1 and sprite.frame < 7:
		var jump_y: float = BASE_SPRITE_OFFSET.y - (2 - abs(sprite.frame - 4)) * 16
		_set_sprite_offset(Vector2(BASE_SPRITE_OFFSET.x, jump_y))

func _on_animation_finished() -> void:
	var sprite := _get_sprite()
	if sprite == null:
		return

	if m_is_currently_jumping and sprite.animation.contains("jump"):
		m_is_currently_jumping = false
		_update_state()

# ------------------------------------------------------------
# Animation state -> play
# ------------------------------------------------------------

func _apply_animation_value() -> void:
	if m_anim_node == null:
		return
	if m_anim_node.sprite_frames == null:
		return
	if m_animation.is_empty():
		return
	if !m_anim_node.sprite_frames.has_animation(m_animation):
		return
	_update_state()
	if Engine.is_editor_hint():
		notify_property_list_changed()

func _update_state() -> void:
	if m_anim_node == null:
		return

	_set_sprite_offset(BASE_SPRITE_OFFSET)

	var base_animation_name: String = "walk" if is_walking else "idle"

	if m_is_currently_jumping:
		if m_current_animation_name.contains("jump"):
			return
		base_animation_name = "jump"
	elif is_walking and is_running:
		base_animation_name = "run"

	var new_animation_name: String = base_animation_name + "_"
	var normalized_direction: float = CommonUtils.normalize_angle(direction)

	if CommonUtils.is_in_range(normalized_direction, 0.0, 45.01) or CommonUtils.is_in_range(normalized_direction, 314.09, 360.0):
		new_animation_name += "e"
	elif CommonUtils.is_in_range(normalized_direction, 135.0, 225.0):
		new_animation_name += "w"
	elif CommonUtils.is_in_range(normalized_direction, 45.0, 135.0):
		new_animation_name += "n"
	elif CommonUtils.is_in_range(normalized_direction, 225.0, 315.0):
		new_animation_name += "s"

	if m_current_animation_name == new_animation_name:
		return

	m_current_animation_name = new_animation_name

	if m_animation != new_animation_name:
		m_animation = new_animation_name
		if Engine.is_editor_hint():
			notify_property_list_changed()

	m_anim_node.stop()
	if m_anim_node.sprite_frames and m_anim_node.sprite_frames.has_animation(new_animation_name):
		m_anim_node.play(new_animation_name)

# ------------------------------------------------------------
# Sprite generation (factory) - template path hidden in factory
# ------------------------------------------------------------

func _refresh_options_and_clamp_selections() -> void:
	var f := UniversalLPCSpriteFactory.get_instance()

	m_anim_options = f.get_animation_options(int(body_type))
	m_body_options = f.get_body_options(int(body_type))
	m_hair_options = f.get_hair_options(int(body_type))
	m_legs_options = f.get_legs_options(int(body_type))
	m_shirt_options = f.get_shirt_options(int(body_type))
	m_head_options = f.get_head_options(int(body_type))
	m_feet_options = f.get_feet_options(int(body_type))

	m_animation = f.get_valid_style_value(m_animation, m_anim_options)
	m_body = f.get_valid_style_value(m_body, m_body_options)
	m_hair = f.get_valid_style_value(m_hair, m_hair_options)
	m_legs = f.get_valid_style_value(m_legs, m_legs_options)
	m_shirt = f.get_valid_style_value(m_shirt, m_shirt_options)
	m_head = f.get_valid_style_value(m_head, m_head_options)
	m_feet = f.get_valid_style_value(m_feet, m_feet_options)

	if Engine.is_editor_hint():
		notify_property_list_changed()

func _reload() -> void:
	if m_is_reloading:
		return
	m_is_reloading = true
	call_deferred("_do_reload")

func _do_reload() -> void:
	m_is_reloading = false
	if m_anim_node == null:
		return

	var f := UniversalLPCSpriteFactory.get_instance()

	var frames := f.create_sprite_frames_for_body_type(
		int(body_type),
		m_body,
		m_hair,
		m_legs,
		m_shirt,
		m_head,
		m_feet,
		body_color,
		hair_color,
		legs_color,
		shirt_color,
		feet_color
	)

	if frames == null:
		if Engine.is_editor_hint():
			notify_property_list_changed()
		return

	m_anim_node.sprite_frames = frames

	m_anim_options = f.get_animation_options(int(body_type))
	m_animation = f.get_valid_style_value(m_animation, m_anim_options)

	if !m_animation.is_empty() and frames.has_animation(m_animation):
		m_current_animation_name = m_animation
		m_anim_node.play(m_animation)
	else:
		var packed: PackedStringArray = frames.get_animation_names()
		if packed.size() > 0:
			m_animation = String(packed[0])
			m_current_animation_name = m_animation
			m_anim_node.play(m_animation)

	if Engine.is_editor_hint():
		notify_property_list_changed()

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

func _get_sprite() -> AnimatedSprite2D:
	return m_anim_node

func _set_sprite_offset(offset: Vector2) -> void:
	if m_anim_node == null:
		return
	m_anim_node.position = offset

# ------------------------------------------------------------
# Process + debug draw
# ------------------------------------------------------------

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
