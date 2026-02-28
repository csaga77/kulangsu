@tool
class_name Player
extends CharacterBody2D

signal global_position_changed()

const BASE_SPRITE_OFFSET: Vector2 = Vector2(0, -32)

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

# ------------------------------------------------------------
# Animation/style proxy properties (stored on Player)
# ------------------------------------------------------------

@export var body_type: UniversalLPCAnimationSprite2D.BodyTypeEnum = UniversalLPCAnimationSprite2D.BodyTypeEnum.MALE:
	set(v):
		if body_type == v:
			return
		body_type = v
		_apply_all_customization_to_anim()
		_update_state()

@export var hair_color: Color = Color.BLACK:
	set(v):
		if hair_color == v:
			return
		hair_color = v
		_apply_colors_to_anim()

@export var legs_color: Color = Color.WHITE:
	set(v):
		if legs_color == v:
			return
		legs_color = v
		_apply_colors_to_anim()

@export var shirt_color: Color = Color.WHITE:
	set(v):
		if shirt_color == v:
			return
		shirt_color = v
		_apply_colors_to_anim()

@export var head_color: Color = Color.WHITE:
	set(v):
		if head_color == v:
			return
		head_color = v
		_apply_colors_to_anim()

@export var feet_color: Color = Color.WHITE:
	set(v):
		if feet_color == v:
			return
		feet_color = v
		_apply_colors_to_anim()

# NEW: body color (tint for base body sprites), same pattern as others
@export var body_color: Color = Color.WHITE:
	set(v):
		if body_color == v:
			return
		body_color = v
		_apply_colors_to_anim()

# Stored values (persisted) for dynamic dropdowns on Player
@export_storage var m_animation: String = "idle_down"
@export_storage var m_hair: String = "Bald"
@export_storage var m_legs: String = "<none>"
@export_storage var m_shirt: String = "<none>"
@export_storage var m_head: String = "<none>"
@export_storage var m_feet: String = "<none>"
# NEW: body style selection (kept like other dropdown-backed values)
@export_storage var m_body: String = "Default"

# ------------------------------------------------------------
# Runtime
# ------------------------------------------------------------

@onready var m_anim_node: UniversalLPCAnimationSprite2D = $UniversalLPCAnimationSprite2D

var m_last_global_position: Vector2 = Vector2.ZERO
var m_is_currently_jumping: bool = false
var m_current_animation_name: String = ""

func _ready() -> void:
	_apply_all_customization_to_anim()
	_connect_jump_signals()
	_update_state()

# ------------------------------------------------------------
# Dynamic inspector properties (dropdowns on Player)
# ------------------------------------------------------------

func _get_property_list() -> Array:
	var property_list: Array = []

	# Ensure anim node exists in editor (might not in some tool edge cases)
	if m_anim_node == null:
		return property_list

	# Animation dropdown options (from current SpriteFrames if available)
	var anim_names: PackedStringArray = PackedStringArray()
	var sprite := _get_sprite()
	if sprite != null and sprite.sprite_frames != null:
		anim_names = sprite.sprite_frames.get_animation_names()

	if anim_names.is_empty():
		anim_names = PackedStringArray([
			"idle_down", "idle_up", "idle_left", "idle_right",
			"walk_down", "walk_up", "walk_left", "walk_right",
			"run_down", "run_up", "run_left", "run_right",
			"jump_down", "jump_up", "jump_left", "jump_right"
		])

	property_list.append({
		"name": "animation",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(anim_names)
	})

	# Style dropdown options come from UniversalLPCAnimationSprite2D's lists
	var body_names: Array[String] = m_anim_node.get_body_options() # NEW
	var hair_names: Array[String] = m_anim_node.get_hair_options()
	var legs_names: Array[String] = m_anim_node.get_legs_options()
	var shirt_names: Array[String] = m_anim_node.get_shirt_options()
	var head_names: Array[String] = m_anim_node.get_head_options()
	var feet_names: Array[String] = m_anim_node.get_feet_options()

	if body_names.is_empty() or hair_names.is_empty() or legs_names.is_empty() or shirt_names.is_empty() or head_names.is_empty() or feet_names.is_empty():
		# Trigger a refresh on the anim node (safe in editor)
		if Engine.is_editor_hint():
			m_anim_node.refresh_sprite_options = true

		# Re-read (may still be empty on first inspector build; that's OK)
		# Prefer calling option getters again (keeps it consistent with latest API)
		body_names = m_anim_node.get_body_options()
		hair_names = m_anim_node.get_hair_options()
		legs_names = m_anim_node.get_legs_options()
		shirt_names = m_anim_node.get_shirt_options()
		head_names = m_anim_node.get_head_options()
		feet_names = m_anim_node.get_feet_options()

		# Fallback to legacy arrays if your node still uses them in some cases
		if body_names.is_empty() and "body_style_names" in m_anim_node:
			body_names = m_anim_node.body_style_names
		if hair_names.is_empty():
			hair_names = m_anim_node.hair_style_names
		if legs_names.is_empty():
			legs_names = m_anim_node.legs_style_names
		if shirt_names.is_empty():
			shirt_names = m_anim_node.shirt_style_names
		if head_names.is_empty():
			head_names = m_anim_node.head_style_names
		if feet_names.is_empty():
			feet_names = m_anim_node.feet_style_names

	property_list.append({
		"name": "body", # NEW
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(body_names)
	})
	property_list.append({
		"name": "hair",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(hair_names)
	})
	property_list.append({
		"name": "legs",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(legs_names)
	})
	property_list.append({
		"name": "shirt",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(shirt_names)
	})
	property_list.append({
		"name": "head",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(head_names)
	})
	property_list.append({
		"name": "feet",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(feet_names)
	})

	return property_list

func _set(property_name: StringName, value: Variant) -> bool:
	var p := String(property_name)

	if p == "animation":
		var v := String(value)
		if m_animation == v:
			return true
		m_animation = v
		call_deferred("_apply_animation_value")
		return true

	if p == "body": # NEW
		var v := String(value)
		if m_body == v:
			return true
		m_body = v
		_apply_styles_to_anim()
		return true

	if p == "hair":
		var v := String(value)
		if m_hair == v:
			return true
		m_hair = v
		_apply_styles_to_anim()
		return true

	if p == "legs":
		var v := String(value)
		if m_legs == v:
			return true
		m_legs = v
		_apply_styles_to_anim()
		return true

	if p == "shirt":
		var v := String(value)
		if m_shirt == v:
			return true
		m_shirt = v
		_apply_styles_to_anim()
		return true

	if p == "head":
		var v := String(value)
		if m_head == v:
			return true
		m_head = v
		_apply_styles_to_anim()
		return true

	if p == "feet":
		var v := String(value)
		if m_feet == v:
			return true
		m_feet = v
		_apply_styles_to_anim()
		return true

	return false

func _get(property_name: StringName) -> Variant:
	var p := String(property_name)

	if p == "animation":
		return m_animation
	if p == "body": # NEW
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

	# Preserve your old "don't move during main jump frames" rule
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
# Jump logic (kept in Player)
# ------------------------------------------------------------

func _connect_jump_signals() -> void:
	var sprite := _get_sprite()
	if sprite == null:
		return

	# Avoid double-connect in editor
	if !sprite.animation_finished.is_connected(_on_animation_finished):
		sprite.animation_finished.connect(_on_animation_finished)
	if !sprite.frame_changed.is_connected(_on_animation_frame_changed):
		sprite.frame_changed.connect(_on_animation_frame_changed)

func _on_animation_frame_changed() -> void:
	var sprite := _get_sprite()
	if sprite == null:
		return

	# Base offset always
	_set_sprite_offset(BASE_SPRITE_OFFSET)

	# Jump vertical bob (same shape as your original)
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
# Animation state -> play on UniversalLPCAnimationSprite2D
# ------------------------------------------------------------

func _apply_animation_value() -> void:
	if m_anim_node == null:
		return
	_update_state()
	if Engine.is_editor_hint():
		notify_property_list_changed()

func _update_state() -> void:
	if m_anim_node == null:
		return

	# Always keep base offset applied (jump will override per frame)
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

	# Keep Player's animation dropdown in sync with state
	if m_animation != new_animation_name:
		m_animation = new_animation_name
		if Engine.is_editor_hint():
			notify_property_list_changed()

	m_anim_node.play(new_animation_name)

# ------------------------------------------------------------
# Apply customization to animation node
# ------------------------------------------------------------

func _apply_all_customization_to_anim() -> void:
	if m_anim_node == null:
		return
	m_anim_node.body_type = body_type
	_apply_colors_to_anim()
	_apply_styles_to_anim()
	call_deferred("_apply_animation_value")

func _apply_colors_to_anim() -> void:
	if m_anim_node == null:
		return
	m_anim_node.hair_color = hair_color
	m_anim_node.legs_color = legs_color
	m_anim_node.shirt_color = shirt_color
	m_anim_node.head_color = head_color
	m_anim_node.feet_color = feet_color
	m_anim_node.body_color = body_color # NEW

func _apply_styles_to_anim() -> void:
	if m_anim_node == null:
		return

	# Set dynamic properties on UniversalLPCAnimationSprite2D
	m_anim_node.set("body", m_body) # NEW
	m_anim_node.set("hair", m_hair)
	m_anim_node.set("legs", m_legs)
	m_anim_node.set("shirt", m_shirt)
	m_anim_node.set("head", m_head)
	m_anim_node.set("feet", m_feet)

	# After rebuild, reconnect sprite signals if the child AnimatedSprite2D got recreated
	call_deferred("_reconnect_after_reload")

func _reconnect_after_reload() -> void:
	_connect_jump_signals()

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

func _get_sprite() -> AnimatedSprite2D:
	if m_anim_node == null:
		return null
	return m_anim_node.get_sprite()

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
