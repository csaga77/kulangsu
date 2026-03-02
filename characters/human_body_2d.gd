# res://characters/human_body_2d.gd
# Changes:
# - Remove facial_mood / facial_action from dynamic property list (they are @export already).
# - Fix enum usage error (no enum "function" calls).
# - Manage facial action animation via ACTION_DEFS in one place.
# - Blink: base -> closing -> closed -> closing -> base, repeated twice.
# - Rolling eyes: rolling -> looking_left -> closing_eyes -> looking_right, loops forever (NO closed_eyes).
# - Add "complete_action" in ACTION_DEFS:
#     * When a finite action completes, it switches to complete_action (configurable per action).
#     * No standalone COMPLETE action enum/state.

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

enum FacialMoodEnum {
	MANUAL = 0, # use "face" dropdown as base
	NORMAL = 1,
	SMILE = 2,
	ANGRY = 3,
}

enum FacialActionEnum {
	NONE = 0,
	BLINK = 1,
	ROLLING_EYES = 2,
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
		_invalidate_body_cache()
		_invalidate_head_face_cache()
		_restart_face_driver()
		_reload()
		_update_state()

@export var refresh_sprite_options: bool = false:
	set(_v):
		refresh_sprite_options = false
		if Engine.is_editor_hint():
			_refresh_options_and_clamp_selections()
			_restart_face_driver()
			_reload()

@export var body_color: Color = Color.WHITE:
	set(v):
		if body_color == v:
			return
		body_color = v
		_invalidate_body_cache()
		_invalidate_head_face_cache()
		_reload()

@export var hair_color: Color = Color.WHITE:
	set(v):
		if hair_color == v:
			return
		hair_color = v
		_invalidate_head_face_cache()
		_reload()

@export var legs_color: Color = Color.WHITE:
	set(v):
		if legs_color == v:
			return
		legs_color = v
		_invalidate_body_cache()
		_reload()

@export var shirt_color: Color = Color.WHITE:
	set(v):
		if shirt_color == v:
			return
		shirt_color = v
		_invalidate_body_cache()
		_reload()

@export var feet_color: Color = Color.WHITE:
	set(v):
		if feet_color == v:
			return
		feet_color = v
		_invalidate_body_cache()
		_reload()

# These are exported already -> DO NOT add to dynamic properties.
@export var facial_mood: FacialMoodEnum = FacialMoodEnum.MANUAL:
	set(v):
		if facial_mood == v:
			return
		facial_mood = v
		_restart_face_driver()

@export var facial_action: FacialActionEnum = FacialActionEnum.NONE:
	set(v):
		if facial_action == v:
			return
		facial_action = v
		_restart_face_driver()

# private members
@export_storage var m_animation: String = "idle_s"

@export_storage var m_body: String = "Default"
@export_storage var m_face: String = "Default" # manual face selection
@export_storage var m_hair: String = "Bald"
@export_storage var m_legs: String = "<none>"
@export_storage var m_shirt: String = "<none>"
@export_storage var m_head: String = "<none>"
@export_storage var m_feet: String = "<none>"

# -------------------------------------------------------------------
# Runtime
# -------------------------------------------------------------------
@onready var m_body_node: AnimatedSprite2D
@onready var m_head_bg_node: AnimatedSprite2D
@onready var m_head_node: AnimatedSprite2D

var m_last_global_position: Vector2 = Vector2.ZERO
var m_is_currently_jumping: bool = false
var m_current_animation_name: String = ""
var m_is_reloading: bool = false

# Cached options for building inspector hint strings (names only)
var m_anim_options: Array[String] = []
var m_body_options: Array[String] = []
var m_face_options: Array[String] = []
var m_hair_options: Array[String] = []
var m_legs_options: Array[String] = []
var m_shirt_options: Array[String] = []
var m_head_options: Array[String] = []
var m_feet_options: Array[String] = []

# ------------------------------------------------------------
# Body cache (SpriteFrames only rebuilt when key changes)
# ------------------------------------------------------------
var m_body_cache_key: String = ""

# ------------------------------------------------------------
# Head face cache (BG + FG SpriteFrames per face)
# ------------------------------------------------------------
var m_head_face_cache_key: String = ""
var m_head_face_cache: Dictionary = {} # face_style -> { "bg": SpriteFrames, "fg": SpriteFrames }

# ------------------------------------------------------------
# Face driver (mood + action)
# ------------------------------------------------------------
var m_face_base: String = ""   # resolved base face (mood/manual)
var m_face_render: String = "" # actually rendered face (base or action frame)

var m_action_timer: float = 0.0
var m_action_step_index: int = 0
var m_action_loops_done: int = 0
var m_action_is_running: bool = false

const BLINK_STEP_SEC := 0.08
const ROLL_STEP_SEC := 0.12

# NOTE:
# - loops == 0 => infinite
# - complete_action is used only when loops > 0 and loops completed.
# - complete_action should be a FacialActionEnum value.
const ACTION_DEFS := {
	FacialActionEnum.NONE: {
		"step_sec": 0.0,
		"loops": 1,
		"steps": ["base"],
		"complete_action": FacialActionEnum.NONE,
	},
	FacialActionEnum.BLINK: {
		"step_sec": BLINK_STEP_SEC,
		"loops": 2, # do twice then switch to complete_action
		"steps": ["base", "closing eyes", "closed eyes", "closing eyes", "base"],
		"complete_action": FacialActionEnum.NONE,
	},
	FacialActionEnum.ROLLING_EYES: {
		"step_sec": ROLL_STEP_SEC,
		"loops": 0, # infinite loop
		"steps": ["rolling eyes", "looking left", "closing eyes", "looking right"],
		"complete_action": FacialActionEnum.NONE, # ignored (loops=0), kept for completeness
	},
}

func _ready() -> void:
	# 1) Head BG stack (head/face/hair backgrounds ONLY)
	if m_head_bg_node == null:
		m_head_bg_node = AnimatedSprite2D.new()
		m_head_bg_node.name = "head_bg_sprite"
		add_child(m_head_bg_node)

	# 2) Body stack (body/feet/legs/shirt)
	if m_body_node == null:
		m_body_node = AnimatedSprite2D.new()
		m_body_node.name = "body_sprite"
		add_child(m_body_node)

	# 3) Head FG stack (head/face/hair foreground ONLY)
	if m_head_node == null:
		m_head_node = AnimatedSprite2D.new()
		m_head_node.name = "head_sprite"
		add_child(m_head_node)

	# Ensure draw order: head-bg behind body behind head-fg
	move_child(m_head_bg_node, 0)
	move_child(m_body_node, 1)
	move_child(m_head_node, 2)

	_refresh_options_and_clamp_selections()
	_restart_face_driver()
	_reload()
	_connect_jump_signals()
	_update_state()

# ------------------------------------------------------------
# Dynamic inspector properties (dropdowns on HumanBody2D)
# NOTE: facial_mood / facial_action are @export -> DO NOT add here.
# ------------------------------------------------------------
func _get_property_list() -> Array:
	var property_list: Array = []

	if m_body_node == null or m_head_node == null or m_head_bg_node == null:
		return property_list

	if m_anim_options.is_empty() \
	or m_body_options.is_empty() \
	or m_face_options.is_empty() \
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
		"name": "face",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(m_face_options)
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
	var v: String = String(value) if value is String else ""

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
		_invalidate_body_cache()
		_reload()
		if Engine.is_editor_hint():
			notify_property_list_changed()
		return true

	if p == "face":
		v = f.get_valid_style_value(v, m_face_options)
		if m_face == v:
			return true
		m_face = v
		if facial_mood == FacialMoodEnum.MANUAL:
			_restart_face_driver()
		if Engine.is_editor_hint():
			notify_property_list_changed()
		return true

	if p == "hair":
		v = f.get_valid_style_value(v, m_hair_options)
		if m_hair == v:
			return true
		m_hair = v
		_invalidate_head_face_cache()
		_reload()
		if Engine.is_editor_hint():
			notify_property_list_changed()
		return true

	if p == "legs":
		v = f.get_valid_style_value(v, m_legs_options)
		if m_legs == v:
			return true
		m_legs = v
		_invalidate_body_cache()
		_reload()
		if Engine.is_editor_hint():
			notify_property_list_changed()
		return true

	if p == "shirt":
		v = f.get_valid_style_value(v, m_shirt_options)
		if m_shirt == v:
			return true
		m_shirt = v
		_invalidate_body_cache()
		_reload()
		if Engine.is_editor_hint():
			notify_property_list_changed()
		return true

	if p == "head":
		v = f.get_valid_style_value(v, m_head_options)
		if m_head == v:
			return true
		m_head = v
		_invalidate_head_face_cache()
		_reload()
		if Engine.is_editor_hint():
			notify_property_list_changed()
		return true

	if p == "feet":
		v = f.get_valid_style_value(v, m_feet_options)
		if m_feet == v:
			return true
		m_feet = v
		_invalidate_body_cache()
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
	if p == "face":
		return m_face
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
# Jump + animation state logic (unchanged)
# ------------------------------------------------------------
func jump() -> void:
	if m_is_currently_jumping:
		return
	m_is_currently_jumping = true
	_update_state()

func move(direction_vector: Vector2) -> void:
	var dir_vec := direction_vector
	if dir_vec.length_squared() > 0.000001:
		dir_vec = dir_vec.normalized()

	var movement_speed: float = 300.0 if is_running else 100.0
	velocity = dir_vec * movement_speed

	var sprite := _get_anim_driver()
	if sprite != null and m_is_currently_jumping and (sprite.frame <= 1 or sprite.frame == 7):
		return

	move_and_slide()

func get_texture() -> Texture2D:
	var sprite: AnimatedSprite2D = m_body_node
	if sprite == null:
		sprite = m_head_node
	if sprite == null:
		sprite = m_head_bg_node
	if sprite == null or sprite.sprite_frames == null:
		return null
	return sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)

func get_local_bounding_rect() -> Rect2:
	var current_texture: Texture2D = get_texture()
	if current_texture:
		var texture_size: Vector2 = current_texture.get_size()
		return Rect2(-Vector2(texture_size.x * 0.5, texture_size.y), texture_size)
	return Rect2(Vector2(-16, -64), Vector2(32, 64))

func get_local_ground_rect() -> Rect2:
	return Rect2(Vector2(-16, -32), Vector2(32, 32))

func get_bounding_rect() -> Rect2:
	var local_bounding_rect: Rect2 = get_local_bounding_rect()
	local_bounding_rect.position += global_position
	return local_bounding_rect

func get_ground_rect() -> Rect2:
	var local_ground_rect: Rect2 = get_local_ground_rect()
	local_ground_rect.position += global_position
	return local_ground_rect

func _connect_jump_signals() -> void:
	var sprite := _get_anim_driver()
	if sprite == null:
		return
	if !sprite.animation_finished.is_connected(_on_animation_finished):
		sprite.animation_finished.connect(_on_animation_finished)
	if !sprite.frame_changed.is_connected(_on_animation_frame_changed):
		sprite.frame_changed.connect(_on_animation_frame_changed)

func _on_animation_frame_changed() -> void:
	_sync_head_to_body()

	_set_sprite_offset(BASE_SPRITE_OFFSET)
	var sprite := _get_anim_driver()
	if sprite != null and m_is_currently_jumping and sprite.frame > 1 and sprite.frame < 7:
		var jump_y: float = BASE_SPRITE_OFFSET.y - (2 - abs(sprite.frame - 4)) * 16
		_set_sprite_offset(Vector2(BASE_SPRITE_OFFSET.x, jump_y))

func _on_animation_finished() -> void:
	var sprite := _get_anim_driver()
	if sprite == null:
		return
	if m_is_currently_jumping and sprite.animation.contains("jump"):
		m_is_currently_jumping = false
		_update_state()

func _apply_animation_value() -> void:
	if m_body_node == null or m_head_node == null or m_head_bg_node == null:
		return
	if m_animation.is_empty():
		return

	if m_body_node.sprite_frames != null and !m_body_node.sprite_frames.has_animation(m_animation):
		return

	_update_state()
	if Engine.is_editor_hint():
		notify_property_list_changed()

func _update_state() -> void:
	if m_body_node == null or m_head_node == null or m_head_bg_node == null:
		return

	_set_sprite_offset(BASE_SPRITE_OFFSET)

	var base_animation_name: String = "walk" if is_walking else "idle"
	if m_is_currently_jumping:
		if m_current_animation_name.contains("jump"):
			return
		base_animation_name = "jump"
	elif is_walking and is_running:
		base_animation_name = "run"

	var new_animation_name := base_animation_name + "_"
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

	_stop_all_sprites()

	if m_body_node.sprite_frames and m_body_node.sprite_frames.has_animation(new_animation_name):
		m_body_node.play(new_animation_name)
	if m_head_bg_node.sprite_frames and m_head_bg_node.sprite_frames.has_animation(new_animation_name):
		m_head_bg_node.play(new_animation_name)
	if m_head_node.sprite_frames and m_head_node.sprite_frames.has_animation(new_animation_name):
		m_head_node.play(new_animation_name)

	_sync_head_to_body()

# ------------------------------------------------------------
# Sprite generation
# ------------------------------------------------------------
func _refresh_options_and_clamp_selections() -> void:
	var f := UniversalLPCSpriteFactory.get_instance()

	m_anim_options = f.get_animation_options(int(body_type))
	m_body_options = f.get_body_options(int(body_type))
	m_face_options = f.get_face_options(int(body_type))
	m_hair_options = f.get_hair_options(int(body_type))
	m_legs_options = f.get_legs_options(int(body_type))
	m_shirt_options = f.get_shirt_options(int(body_type))
	m_head_options = f.get_head_options(int(body_type))
	m_feet_options = f.get_feet_options(int(body_type))

	m_animation = f.get_valid_style_value(m_animation, m_anim_options)
	m_body = f.get_valid_style_value(m_body, m_body_options)
	m_face = f.get_valid_style_value(m_face, m_face_options)
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
	if m_body_node == null or m_head_node == null or m_head_bg_node == null:
		return

	var f := UniversalLPCSpriteFactory.get_instance()

	# Body frames: rebuild ONLY if body parameters changed
	var new_body_key := _get_body_cache_key()
	var body_frames: SpriteFrames = m_body_node.sprite_frames

	if body_frames == null or m_body_cache_key != new_body_key:
		m_body_cache_key = new_body_key

		var body_layers: Array[Dictionary] = [
			{"part": "body", "style": m_body, "tint": body_color, "tint_on": true},
			{"part": "feet", "style": m_feet, "tint": feet_color, "tint_on": true},
			{"part": "legs", "style": m_legs, "tint": legs_color, "tint_on": true},
			{"part": "shirt", "style": m_shirt, "tint": shirt_color, "tint_on": true},
		]

		body_frames = f.create_sprite_frames(int(body_type), body_layers)
		if body_frames == null:
			if Engine.is_editor_hint():
				notify_property_list_changed()
			return

		m_body_node.sprite_frames = body_frames

	# Head face cache build (BG + FG per face)
	var new_head_cache_key := _get_head_face_cache_key()
	if m_head_face_cache_key != new_head_cache_key:
		m_head_face_cache_key = new_head_cache_key
		m_head_face_cache.clear()

		for face_style in m_face_options:
			if face_style == "<none>" or face_style.is_empty():
				continue
			_build_and_cache_head_frames_for_face(face_style)

	# Refresh animations list
	m_anim_options = f.get_animation_options(int(body_type))
	m_animation = f.get_valid_style_value(m_animation, m_anim_options)

	# Apply current animation if possible; otherwise fall back to first available
	var anim_to_play := m_animation
	if anim_to_play.is_empty() \
	or !body_frames.has_animation(anim_to_play) \
	or (m_head_bg_node.sprite_frames != null and !m_head_bg_node.sprite_frames.has_animation(anim_to_play)) \
	or (m_head_node.sprite_frames != null and !m_head_node.sprite_frames.has_animation(anim_to_play)):
		var packed := body_frames.get_animation_names()
		anim_to_play = String(packed[0]) if packed.size() > 0 else ""

	if !anim_to_play.is_empty():
		m_animation = anim_to_play
		m_current_animation_name = anim_to_play
		_stop_all_sprites()
		if m_body_node.sprite_frames != null and m_body_node.sprite_frames.has_animation(anim_to_play):
			m_body_node.play(anim_to_play)

		_apply_face_switch()

	if Engine.is_editor_hint():
		notify_property_list_changed()

# ------------------------------------------------------------
# Body cache helpers
# ------------------------------------------------------------
func _invalidate_body_cache() -> void:
	m_body_cache_key = ""

func _get_body_cache_key() -> String:
	return (
		str(int(body_type))
		+ "|body=" + m_body
		+ "|feet=" + m_feet
		+ "|legs=" + m_legs
		+ "|shirt=" + m_shirt
		+ "|body_color=" + body_color.to_html(true)
		+ "|feet_color=" + feet_color.to_html(true)
		+ "|legs_color=" + legs_color.to_html(true)
		+ "|shirt_color=" + shirt_color.to_html(true)
	)

# ------------------------------------------------------------
# Head cache helpers
# ------------------------------------------------------------
func _invalidate_head_face_cache() -> void:
	m_head_face_cache_key = ""
	m_head_face_cache.clear()

func _get_head_face_cache_key() -> String:
	return (
		str(int(body_type))
		+ "|head=" + m_head
		+ "|hair=" + m_hair
		+ "|body_color=" + body_color.to_html(true)
		+ "|hair_color=" + hair_color.to_html(true)
	)

func _build_and_cache_head_frames_for_face(face_style: String) -> void:
	if face_style.is_empty() or face_style == "<none>":
		return
	if m_head_face_cache.has(face_style):
		return
	if m_head_node == null or m_head_bg_node == null:
		return

	var f := UniversalLPCSpriteFactory.get_instance()

	var face_skip_colors: Array = [
		Color("#f9d5ba"), Color("#faece7"), Color("#e4a47c"),
		Color("#cc8665"), Color("#99423c")
	]

	var head_base_layers: Array[Dictionary] = [
		{"part": "head", "style": m_head, "tint": body_color, "tint_on": true},
		{"part": "face", "style": face_style, "tint": body_color, "tint_on": true, "tint_mask": face_skip_colors},
		{"part": "hair", "style": m_hair, "tint": hair_color, "tint_on": true},
	]

	var head_fg_layers: Array[Dictionary] = []
	for l_any in head_base_layers:
		var l: Dictionary = l_any.duplicate(true)
		l["is_bg_on"] = false
		head_fg_layers.append(l)

	var head_bg_layers: Array[Dictionary] = []
	for l_any2 in head_base_layers:
		var l2: Dictionary = l_any2.duplicate(true)
		l2["is_fg_on"] = false
		head_bg_layers.append(l2)

	var head_fg_frames := f.create_sprite_frames(int(body_type), head_fg_layers)
	var head_bg_frames := f.create_sprite_frames(int(body_type), head_bg_layers)
	
	m_head_face_cache[face_style] = {"bg": head_bg_frames, "fg": head_fg_frames}

func _apply_face_switch() -> void:
	if m_head_node == null or m_head_bg_node == null:
		return

	var new_key := _get_head_face_cache_key()
	if m_head_face_cache_key != new_key:
		_reload()
		return

	var face_to_use := m_face_render
	if face_to_use.is_empty() or face_to_use == "<none>":
		face_to_use = "Human / Neutral"

	if !m_head_face_cache.has(face_to_use):
		if m_head_face_cache.has("Human / Neutral"):
			face_to_use = "Human / Neutral"
		else:
			_reload()
			return

	var entry: Dictionary = m_head_face_cache[face_to_use]
	var head_bg_frames: SpriteFrames = entry.get("bg", null)
	var head_fg_frames: SpriteFrames = entry.get("fg", null)

	m_head_bg_node.sprite_frames = head_bg_frames
	m_head_node.sprite_frames = head_fg_frames

	_sync_head_to_body()

# ------------------------------------------------------------
# Face driver (mood + action) - centralized via ACTION_DEFS
# ------------------------------------------------------------
func _restart_face_driver() -> void:
	_resolve_face_base_from_mood()

	m_action_timer = 0.0
	m_action_step_index = 0
	m_action_loops_done = 0

	var def: Dictionary = ACTION_DEFS.get(int(facial_action), ACTION_DEFS[FacialActionEnum.NONE])
	var steps: Array = def.get("steps", ["base"])
	m_action_is_running = (int(facial_action) != int(FacialActionEnum.NONE)) and steps.size() > 0

	# Render first step immediately
	m_face_render = _resolve_face_for_step(String(steps[0]))
	if m_face_render.is_empty():
		m_face_render = m_face_base

	call_deferred("_apply_face_switch")

func _resolve_face_base_from_mood() -> void:
	match int(facial_mood):
		int(FacialMoodEnum.MANUAL):
			m_face_base = m_face
		int(FacialMoodEnum.NORMAL):
			m_face_base = _find_face_option_by_keywords(["neutral", "normal"])
		int(FacialMoodEnum.SMILE):
			m_face_base = _find_face_option_by_keywords(["smile", "happy"])
		int(FacialMoodEnum.ANGRY):
			m_face_base = _find_face_option_by_keywords(["angry", "mad"])
		_:
			m_face_base = m_face

	if m_face_base.is_empty() or m_face_base == "<none>":
		m_face_base = "Human / Neutral"

func _resolve_face_for_step(step_name: String) -> String:
	if step_name == "base":
		return m_face_base
	return _find_face_option_by_keywords_excluding(step_name)

func _find_face_option_by_keywords(keywords: Array[String]) -> String:
	if m_face_options.is_empty():
		return ""

	for opt in m_face_options:
		var s := String(opt).to_lower()
		for k in keywords:
			if s.find(String(k).to_lower()) != -1:
				return String(opt)
	return ""

# NOTE: simplified: no "excludes" param
func _find_face_option_by_keywords_excluding(step_name: String) -> String:
	if m_face_options.is_empty():
		return ""

	var needle := step_name.strip_edges().to_lower()
	if needle.is_empty():
		return ""

	# First hit wins (keeps option order stable)
	for opt in m_face_options:
		var s2 := String(opt).to_lower()
		if s2.find(needle) != -1:
			return String(opt)

	return ""

func _set_facial_action_internal(action_value: int) -> void:
	# Setting exported property -> will call setter -> _restart_face_driver()
	facial_action = action_value

func _advance_action_step() -> void:
	var def: Dictionary = ACTION_DEFS.get(int(facial_action), ACTION_DEFS[FacialActionEnum.NONE])
	var steps: Array = def.get("steps", ["base"])
	if steps.is_empty():
		m_action_is_running = false
		m_face_render = m_face_base
		_apply_face_switch()
		return

	m_action_step_index += 1
	if m_action_step_index >= steps.size():
		m_action_step_index = 0
		m_action_loops_done += 1

	var loops: int = int(def.get("loops", 1))
	if loops > 0 and m_action_loops_done >= loops:
		# Finite action finished -> switch to complete_action (configurable)
		m_action_is_running = false
		m_face_render = m_face_base
		_apply_face_switch()

		var next_action: int = int(def.get("complete_action", FacialActionEnum.NONE))
		if next_action != int(facial_action):
			call_deferred("_set_facial_action_internal", next_action)
		return

	m_face_render = _resolve_face_for_step(String(steps[m_action_step_index]))
	if m_face_render.is_empty():
		m_face_render = m_face_base
	_apply_face_switch()

# ------------------------------------------------------------
# Helpers + process/draw
# ------------------------------------------------------------
func _get_anim_driver() -> AnimatedSprite2D:
	return m_body_node

func _stop_all_sprites() -> void:
	if m_body_node != null:
		m_body_node.stop()
	if m_head_bg_node != null:
		m_head_bg_node.stop()
	if m_head_node != null:
		m_head_node.stop()

func _sync_head_to_body() -> void:
	if m_body_node == null:
		return

	var anim := m_body_node.animation
	var frame := m_body_node.frame

	if m_head_bg_node != null and m_head_bg_node.sprite_frames and m_head_bg_node.sprite_frames.has_animation(anim):
		if m_head_bg_node.animation != anim:
			m_head_bg_node.animation = anim
		m_head_bg_node.frame = frame

	if m_head_node != null and m_head_node.sprite_frames and m_head_node.sprite_frames.has_animation(anim):
		if m_head_node.animation != anim:
			m_head_node.animation = anim
		m_head_node.frame = frame

func _set_sprite_offset(offset: Vector2) -> void:
	if m_body_node != null:
		m_body_node.position = offset
	if m_head_bg_node != null:
		m_head_bg_node.position = offset
	if m_head_node != null:
		m_head_node.position = offset

func _process(delta: float) -> void:
	_sync_head_to_body()

	# facial action tick (single place)
	if m_action_is_running:
		var def: Dictionary = ACTION_DEFS.get(int(facial_action), ACTION_DEFS[FacialActionEnum.NONE])
		var step_sec: float = float(def.get("step_sec", 0.0))
		if step_sec <= 0.00001:
			m_action_is_running = false
		else:
			m_action_timer += delta
			while m_action_timer >= step_sec:
				m_action_timer -= step_sec
				_advance_action_step()
				if !m_action_is_running:
					break

	if !m_last_global_position.is_equal_approx(global_position):
		m_last_global_position = global_position
		global_position_changed.emit()
		if draw_bounding_rect:
			queue_redraw()

func _draw() -> void:
	if draw_bounding_rect:
		draw_rect(get_local_bounding_rect(), Color.RED, false)
		draw_rect(get_local_ground_rect(), Color.BLUE, false)
