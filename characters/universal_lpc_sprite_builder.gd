# res://characters/universal_lpc_sprite_builder.gd
# Requirements:
# - KEEP _get_property_list()
# - Expose style dropdowns via _get() / _set()
# - REMOVE any standalone @export style properties (no duplicates in inspector)
# - Styles must still be persisted -> use @export_storage backing fields

@tool
class_name UniversalLPCSpriteBuilder
extends Resource

# -----------------------
# Enums / non-style exports
# -----------------------
enum BodyTypeEnum {
	MALE = 0,
	FEMALE = 1,
	TEEN = 2,
	CHILD = 3,
	MUSCULAR = 4,
	PREGNANT = 5,
}

@export var trigger_reload: bool:
	set(new_trigger):
		if new_trigger:
			_emit_changed()

@export var body_type: BodyTypeEnum = BodyTypeEnum.MALE:
	set(v):
		if body_type == v:
			return
		body_type = v
		m_options_ready = false
		_emit_changed()

@export var body_color: Color = Color.WHITE:
	set(v):
		if body_color == v:
			return
		body_color = v
		_emit_changed()

@export var hair_color: Color = Color.WHITE:
	set(v):
		if hair_color == v:
			return
		hair_color = v
		_emit_changed()

@export var legs_color: Color = Color.WHITE:
	set(v):
		if legs_color == v:
			return
		legs_color = v
		_emit_changed()

@export var shirt_color: Color = Color.WHITE:
	set(v):
		if shirt_color == v:
			return
		shirt_color = v
		
		_emit_changed()

@export var feet_color: Color = Color.WHITE:
	set(v):
		if feet_color == v:
			return
		feet_color = v
		
		_emit_changed()

# -----------------------
# Styles (NO @export here)
# Persisted, but not shown as regular export properties.
# Only exposed via dynamic property list.
# -----------------------
@export_storage var m_body_style: String = "Default"
@export_storage var m_face_style: String = "Default"
@export_storage var m_hair_style: String = "Bald"
@export_storage var m_legs_style: String = "<none>"
@export_storage var m_shirt_style: String = "<none>"
@export_storage var m_head_style: String = "<none>"
@export_storage var m_feet_style: String = "<none>"

# -----------------------
# Options (cached)
# -----------------------
var body_options: Array[String] = []
var face_options: Array[String] = []
var hair_options: Array[String] = []
var legs_options: Array[String] = []
var shirt_options: Array[String] = []
var head_options: Array[String] = []
var feet_options: Array[String] = []

var m_options_ready: bool = false

# ------------------------------------------------------------
# Dynamic inspector properties (styles only)
# ------------------------------------------------------------
func _get_property_list() -> Array:
	ensure_options_ready()
	var props: Array = []
	props.append(_enum_prop("body_style", body_options))
	props.append(_enum_prop("face_style", face_options))
	props.append(_enum_prop("hair_style", hair_options))
	props.append(_enum_prop("legs_style", legs_options))
	props.append(_enum_prop("shirt_style", shirt_options))
	props.append(_enum_prop("head_style", head_options))
	props.append(_enum_prop("feet_style", feet_options))
	return props

func _enum_prop(name: String, options: Array[String]) -> Dictionary:
	return {
		"name": name,
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(options)
	}

func _get(property_name: StringName) -> Variant:
	var p := String(property_name)
	match p:
		"body_style": return m_body_style
		"face_style": return m_face_style
		"hair_style": return m_hair_style
		"legs_style": return m_legs_style
		"shirt_style": return m_shirt_style
		"head_style": return m_head_style
		"feet_style": return m_feet_style
		_: return null

func _set(property_name: StringName, value: Variant) -> bool:
	var p := String(property_name)
	var v := String(value) if value is String else ""

	ensure_options_ready()
	var f := UniversalLPCSpriteFactory.get_instance()

	if p == "body_style":
		v = f.get_valid_style_value(v, body_options)
		if m_body_style == v:
			return true
		m_body_style = v
		_emit_changed()
		return true

	if p == "face_style":
		v = f.get_valid_style_value(v, face_options)
		if m_face_style == v:
			return true
		m_face_style = v
		_emit_changed()
		return true

	if p == "hair_style":
		v = f.get_valid_style_value(v, hair_options)
		if m_hair_style == v:
			return true
		m_hair_style = v
		_emit_changed()
		return true

	if p == "legs_style":
		v = f.get_valid_style_value(v, legs_options)
		if m_legs_style == v:
			return true
		m_legs_style = v
		_emit_changed()
		return true

	if p == "shirt_style":
		v = f.get_valid_style_value(v, shirt_options)
		if m_shirt_style == v:
			return true
		m_shirt_style = v
		_emit_changed()
		return true

	if p == "head_style":
		v = f.get_valid_style_value(v, head_options)
		if m_head_style == v:
			return true
		m_head_style = v
		_emit_changed()
		return true

	if p == "feet_style":
		v = f.get_valid_style_value(v, feet_options)
		if m_feet_style == v:
			return true
		m_feet_style = v
		
		_emit_changed()
		return true

	return false

# ------------------------------------------------------------
# Options + cache helpers
# ------------------------------------------------------------
func ensure_options_ready() -> void:
	if m_options_ready:
		return

	var f := UniversalLPCSpriteFactory.get_instance()

	body_options = f.get_body_options(int(body_type))
	face_options = f.get_face_options(int(body_type))
	hair_options = f.get_hair_options(int(body_type))
	legs_options = f.get_legs_options(int(body_type))
	shirt_options = f.get_shirt_options(int(body_type))
	head_options = f.get_head_options(int(body_type))
	feet_options = f.get_feet_options(int(body_type))

	# Clamp stored styles
	m_body_style = f.get_valid_style_value(m_body_style, body_options)
	m_face_style = f.get_valid_style_value(m_face_style, face_options)
	m_hair_style = f.get_valid_style_value(m_hair_style, hair_options)
	m_legs_style = f.get_valid_style_value(m_legs_style, legs_options)
	m_shirt_style = f.get_valid_style_value(m_shirt_style, shirt_options)
	m_head_style = f.get_valid_style_value(m_head_style, head_options)
	m_feet_style = f.get_valid_style_value(m_feet_style, feet_options)

	m_options_ready = true

func _emit_changed() -> void:
	changed.emit()
	if Engine.is_editor_hint():
		notify_property_list_changed()

# ------------------------------------------------------------
# API used by HumanBody2D
# ------------------------------------------------------------
func build_body_frames_texture_image() -> Image:
	var f := UniversalLPCSpriteFactory.get_instance()
	var layers: Array[Dictionary] = [
		{"part": "body", "style": m_body_style, "tint": body_color, "tint_on": true},
		{"part": "feet", "style": m_feet_style, "tint": feet_color, "tint_on": true},
		{"part": "legs", "style": m_legs_style, "tint": legs_color, "tint_on": true},
		{"part": "shirt", "style": m_shirt_style, "tint": shirt_color, "tint_on": true},
	]
	return f.create_sprite_frames_texture_image(int(body_type), layers, "body")
	
func build_head_frames_texture_images(is_bg: bool) -> Dictionary:
	ensure_options_ready()
	var textures :Dictionary
	var f := UniversalLPCSpriteFactory.get_instance()
	for face_key in face_options:
		if face_key == "<none>":
			continue
		var layers :Array[Dictionary] = _get_head_head_layers(face_key, is_bg)
		var frame_texture_image: Image = f.create_sprite_frames_texture_image(int(body_type), layers, "" if is_bg else face_key)
		if frame_texture_image != null:
			textures[face_key.to_lower()] = frame_texture_image
	return textures
		
func _get_head_head_layers(face_key: String, is_bg :bool) -> Array[Dictionary]:
	var face_skip_colors: Array = [
		Color("#f9d5ba"), Color("#faece7"), Color("#e4a47c"),
		Color("#cc8665"), Color("#99423c")
	]

	var base_layers: Array[Dictionary] = [
		{"part": "head", "style": m_head_style, "tint": body_color, "tint_on": true},
		{"part": "face", "style": face_key, "tint": body_color, "tint_on": true, "tint_mask": face_skip_colors},
		{"part": "hair", "style": m_hair_style, "tint": hair_color, "tint_on": true},
	]

	var layers: Array[Dictionary] = []
	for l_any in base_layers:
		var l: Dictionary = l_any.duplicate(true)
		if is_bg:
			l["is_fg_on"] = false
		else:
			l["is_bg_on"] = false
		layers.append(l)
		
	return layers

# ------------------------------------------------------------
# Cache keys
# ------------------------------------------------------------
func _get_body_cache_key() -> String:
	return (
		str(int(body_type))
		+ "|body=" + m_body_style
		+ "|feet=" + m_feet_style
		+ "|legs=" + m_legs_style
		+ "|shirt=" + m_shirt_style
		+ "|body_color=" + body_color.to_html(true)
		+ "|feet_color=" + feet_color.to_html(true)
		+ "|legs_color=" + legs_color.to_html(true)
		+ "|shirt_color=" + shirt_color.to_html(true)
	)

func _get_head_cache_key() -> String:
	return (
		str(int(body_type))
		+ "|head=" + m_head_style
		+ "|hair=" + m_hair_style
		+ "|body_color=" + body_color.to_html(true)
		+ "|hair_color=" + hair_color.to_html(true)
	)
