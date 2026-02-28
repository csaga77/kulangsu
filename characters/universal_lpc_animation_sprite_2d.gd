# res://characters/universal_lpc_animation_sprite_2d.gd
@tool
class_name UniversalLPCAnimationSprite2D
extends AnimatedSprite2D

enum BodyTypeEnum {
	MALE = 0,
	FEMALE = 1,
	TEEN = 2,
	CHILD = 3,
	MUSCULAR = 4,
	PREGNANT = 5,
}

# -------------------------------------------------------------------
# Exports
# -------------------------------------------------------------------

@export var body_type: BodyTypeEnum = BodyTypeEnum.MALE:
	set(v):
		if body_type == v:
			return
		body_type = v
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

@export var head_color: Color = Color.WHITE:
	set(v):
		if head_color == v:
			return
		head_color = v
		_reload()

@export var feet_color: Color = Color.WHITE:
	set(v):
		if feet_color == v:
			return
		feet_color = v
		_reload()

@export var sprite_frames_template_path: String = "res://resources/animations/characters/male_animations.tres":
	set(v):
		if sprite_frames_template_path == v:
			return
		sprite_frames_template_path = v
		_refresh_options_and_clamp_selections()
		_reload()

@export var refresh_sprite_options: bool = false:
	set(_v):
		refresh_sprite_options = false
		if Engine.is_editor_hint():
			_refresh_options_and_clamp_selections()
			_reload()

func get_anim_options() -> Array[String]:
	return m_anim_options

func get_body_options() -> Array[String]:
	return m_body_options

func get_hair_options() -> Array[String]:
	return m_hair_options

func get_legs_options() -> Array[String]:
	return m_legs_options

func get_shirt_options() -> Array[String]:
	return m_shirt_options

func get_head_options() -> Array[String]:
	return m_head_options

func get_feet_options() -> Array[String]:
	return m_feet_options

# -------------------------------------------------------------------
# Stored values (persisted) - NOT directly shown in inspector
# Visible inspector properties are dynamic: animation + body/hair/legs/shirt/head/feet
# -------------------------------------------------------------------

@export_storage var m_animation: String = "idle_s"

@export_storage var m_body: String = "Default"
@export_storage var m_hair: String = "Bald"
@export_storage var m_legs: String = "<none>"
@export_storage var m_shirt: String = "<none>"
@export_storage var m_head: String = "<none>"
@export_storage var m_feet: String = "<none>"

# -------------------------------------------------------------------
# Runtime (no option arrays stored here; options come from factory)
# -------------------------------------------------------------------

var m_is_reloading: bool = false
var m_current_animation_name: String = ""

# Cached options just for building inspector hint strings (names only)
var m_anim_options: Array[String] = []
var m_body_options: Array[String] = []
var m_hair_options: Array[String] = []
var m_legs_options: Array[String] = []
var m_shirt_options: Array[String] = []
var m_head_options: Array[String] = []
var m_feet_options: Array[String] = []

func _ready() -> void:
	_refresh_options_and_clamp_selections()
	_reload()

# -------------------------------------------------------------------
# Dynamic inspector properties
# -------------------------------------------------------------------

func _get_property_list() -> Array:
	var property_list: Array = []

	# Editor queries can happen before _ready timing; keep it robust
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
		"usage": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(m_feet_options)
	})

	return property_list

func _set(property_name: StringName, value: Variant) -> bool:
	var p := String(property_name)
	var v: String 
	if value is String:
		v = String(value)

	if p == "animation":
		if m_animation == v:
			return true
		m_animation = v
		call_deferred("_apply_animation_value")
		return true

	if p == "body":
		v = UniversalLPCSpriteFactory.get_instance().get_valid_style_value(v, m_body_options)
		if m_body == v:
			return true
		m_body = v
		_reload()
		if Engine.is_editor_hint():
			notify_property_list_changed()
		return true

	if p == "hair":
		v = UniversalLPCSpriteFactory.get_instance().get_valid_style_value(v, m_hair_options)
		if m_hair == v:
			return true
		m_hair = v
		_reload()
		if Engine.is_editor_hint():
			notify_property_list_changed()
		return true

	if p == "legs":
		v = UniversalLPCSpriteFactory.get_instance().get_valid_style_value(v, m_legs_options)
		if m_legs == v:
			return true
		m_legs = v
		_reload()
		if Engine.is_editor_hint():
			notify_property_list_changed()
		return true

	if p == "shirt":
		v = UniversalLPCSpriteFactory.get_instance().get_valid_style_value(v, m_shirt_options)
		if m_shirt == v:
			return true
		m_shirt = v
		_reload()
		if Engine.is_editor_hint():
			notify_property_list_changed()
		return true

	if p == "head":
		v = UniversalLPCSpriteFactory.get_instance().get_valid_style_value(v, m_head_options)
		if m_head == v:
			return true
		m_head = v
		_reload()
		if Engine.is_editor_hint():
			notify_property_list_changed()
		return true

	if p == "feet":
		v = UniversalLPCSpriteFactory.get_instance().get_valid_style_value(v, m_feet_options)
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

# -------------------------------------------------------------------
# PUBLIC API
# -------------------------------------------------------------------
# Backward-compatible helper for callers that expect get_sprite()
func get_animation_names() -> Array[String]:
	return m_anim_options

# -------------------------------------------------------------------
# Private
# -------------------------------------------------------------------

func _apply_animation_value() -> void:
	if sprite_frames == null:
		return
	if m_animation.is_empty():
		return
	if !sprite_frames.has_animation(m_animation):
		return
	play(m_animation)

func _refresh_options_and_clamp_selections() -> void:
	var f := UniversalLPCSpriteFactory.get_instance()

	# Pull options from factory (sprite stores only names for inspector)
	m_anim_options = f.get_animation_options_from_template(sprite_frames_template_path)
	m_body_options = f.get_body_options(int(body_type))
	m_hair_options = f.get_hair_options(int(body_type))
	m_legs_options = f.get_legs_options(int(body_type))
	m_shirt_options = f.get_shirt_options(int(body_type))
	m_head_options = f.get_head_options(int(body_type))
	m_feet_options = f.get_feet_options(int(body_type))

	# Clamp persisted selections to current available options
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

	var f := UniversalLPCSpriteFactory.get_instance()

	# Build frames via factory (includes BG layers + tinting)
	# NOTE: included head_color (it was previously missing in the call)
	var frames := f.create_sprite_frames(
		sprite_frames_template_path,
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

	sprite_frames = frames

	# Ensure animation list is aligned with actual frames
	m_anim_options = f.get_animation_options_from_template(sprite_frames_template_path)
	m_animation = f.get_valid_style_value(m_animation, m_anim_options)

	# Play current animation if possible
	if !m_animation.is_empty() and frames.has_animation(m_animation):
		m_current_animation_name = m_animation
		super.play(m_animation)
	else:
		var packed: PackedStringArray = frames.get_animation_names()
		if packed.size() > 0:
			m_animation = String(packed[0])
			m_current_animation_name = m_animation
			super.play(m_animation)

	if Engine.is_editor_hint():
		notify_property_list_changed()
