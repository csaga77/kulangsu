@tool
class_name LPCAnimationSprite2D
extends Node2D

enum BodyTypeEnum {
	MALE = 0,
	FEMALE = 1,
	TEEN = 2,
	CHILD = 3,
	MUSCULAR = 4,
	PREGNANT = 5,
}

# -------------------------------------------------------------------
# Style option folders
# -------------------------------------------------------------------

const HAIR_SPRITE_FOLDER_PATH: String = "res://resources/sprites/characters/hair/"

const MALE_LEGS_FOLDER_PATH: String = "res://resources/sprites/characters/male/legs/"
const FEMALE_LEGS_FOLDER_PATH: String = "res://resources/sprites/characters/female/legs/"

const MALE_SHIRTS_FOLDER_PATH: String = "res://resources/sprites/characters/male/torso/shirts/"
const FEMALE_SHIRTS_FOLDER_PATH: String = "res://resources/sprites/characters/female/torso/shirts/"

const MALE_HEAD_FOLDER_PATH: String = "res://resources/sprites/characters/male/head/"
const FEMALE_HEAD_FOLDER_PATH: String = "res://resources/sprites/characters/female/head/"

const MALE_FEET_FOLDER_PATH: String = "res://resources/sprites/characters/male/feet/"
const FEMALE_FEET_FOLDER_PATH: String = "res://resources/sprites/characters/female/feet/"

# -------------------------------------------------------------------
# Exports
# -------------------------------------------------------------------

@export var body_type: BodyTypeEnum = BodyTypeEnum.MALE:
	set(v):
		if body_type == v:
			return
		body_type = v
		_refresh_all_style_options()
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
		_reload()

@export var refresh_sprite_options: bool = false:
	set(_v):
		refresh_sprite_options = false
		if Engine.is_editor_hint():
			_refresh_all_style_options()
			_reload()

# -------------------------------------------------------------------
# Stored values (persisted) - NOT directly shown in inspector
# Visible inspector properties are dynamic: hair/legs/shirt/head/feet + animation
# -------------------------------------------------------------------

@export_storage var m_animation: String = "idle_down"

@export_storage var m_hair: String = "Bald"
@export_storage var m_legs: String = "<none>"
@export_storage var m_shirt: String = "<none>"
@export_storage var m_head: String = "<none>"
@export_storage var m_feet: String = "<none>"

# -------------------------------------------------------------------
# Style option data
# -------------------------------------------------------------------

var hair_sprite_paths: Array[String] = []
var hair_style_names: Array[String] = []

var legs_sprite_paths: Array[String] = []
var legs_style_names: Array[String] = []

var shirt_sprite_paths: Array[String] = []
var shirt_style_names: Array[String] = []

var head_sprite_paths: Array[String] = []
var head_style_names: Array[String] = []

var feet_sprite_paths: Array[String] = []
var feet_style_names: Array[String] = []

var m_animations: Array[String] = []

# -------------------------------------------------------------------
# Runtime
# -------------------------------------------------------------------

var m_sprite: AnimatedSprite2D = null
var m_is_reloading: bool = false
var m_current_animation_name: String = ""

func _enter_tree() -> void:
	pass

func _ready() -> void:
	_ensure_sprite()
	_refresh_all_style_options()
	_reload()

# -------------------------------------------------------------------
# Dynamic inspector properties
# -------------------------------------------------------------------

func _get_property_list() -> Array:
	var property_list: Array = []

	# Ensure style arrays exist when inspector queries properties
	if hair_style_names.is_empty() \
	or legs_style_names.is_empty() \
	or shirt_style_names.is_empty() \
	or head_style_names.is_empty() \
	or feet_style_names.is_empty():
		_refresh_all_style_options()

	# Animation dropdown options
	property_list.append({
		"name": "animation",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(m_animations)
	})

	# Style dropdowns
	property_list.append({
		"name": "hair",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(hair_style_names)
	})
	property_list.append({
		"name": "legs",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(legs_style_names)
	})
	property_list.append({
		"name": "shirt",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(shirt_style_names)
	})
	property_list.append({
		"name": "head",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(head_style_names)
	})
	property_list.append({
		"name": "feet",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(feet_style_names)
	})

	return property_list

func _set(property_name: StringName, value: Variant) -> bool:
	var p := String(property_name)

	if p == "hair":
		var v := _get_valid_style_value(String(value), hair_style_names)
		if m_hair == v:
			return true
		m_hair = v
		_reload()
		if Engine.is_editor_hint():
			notify_property_list_changed()
		return true

	if p == "legs":
		var v := _get_valid_style_value(String(value), legs_style_names)
		if m_legs == v:
			return true
		m_legs = v
		_reload()
		if Engine.is_editor_hint():
			notify_property_list_changed()
		return true

	if p == "shirt":
		var v := _get_valid_style_value(String(value), shirt_style_names)
		if m_shirt == v:
			return true
		m_shirt = v
		_reload()
		if Engine.is_editor_hint():
			notify_property_list_changed()
		return true

	if p == "head":
		var v := _get_valid_style_value(String(value), head_style_names)
		if m_head == v:
			return true
		m_head = v
		_reload()
		if Engine.is_editor_hint():
			notify_property_list_changed()
		return true

	if p == "feet":
		var v := _get_valid_style_value(String(value), feet_style_names)
		if m_feet == v:
			return true
		m_feet = v
		_reload()
		if Engine.is_editor_hint():
			notify_property_list_changed()
		return true

	if p == "animation":
		var v := String(value)
		if m_animation == v:
			return true
		m_animation = v
		call_deferred("_apply_animation_value")
		return true

	return false

func _get(property_name: StringName) -> Variant:
	var p := String(property_name)

	if p == "animation":
		return m_animation
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
# PUBLIC API (only play / stop)
# -------------------------------------------------------------------

func play(anim_name: String) -> void:
	_ensure_sprite()
	if m_sprite == null:
		return
	if m_current_animation_name == anim_name:
		return

	m_current_animation_name = anim_name
	if m_animation != anim_name:
		m_animation = anim_name
		if Engine.is_editor_hint():
			notify_property_list_changed()

	m_sprite.stop()
	if !m_animations.has(anim_name):
		return
	m_sprite.play(anim_name)

func stop() -> void:
	if m_sprite:
		m_sprite.stop()

func get_sprite() -> AnimatedSprite2D:
	return m_sprite

# -------------------------------------------------------------------
# Private: safe apply for inspector-driven animation changes
# -------------------------------------------------------------------

func _apply_animation_value() -> void:
	_ensure_sprite()
	if m_sprite == null or m_sprite.sprite_frames == null:
		return
	if m_animation.is_empty():
		return
	if !m_sprite.sprite_frames.has_animation(m_animation):
		return
	play(m_animation)

# -------------------------------------------------------------------
# Private: sprite setup + reload/composition
# -------------------------------------------------------------------

func _ensure_sprite() -> void:
	if m_sprite and is_instance_valid(m_sprite):
		return

	for c in get_children():
		if c is AnimatedSprite2D:
			c.queue_free()

	m_sprite = AnimatedSprite2D.new()
	m_sprite.name = "sprite"
	add_child(m_sprite)

func _reload() -> void:
	if m_is_reloading:
		return
	m_is_reloading = true
	call_deferred("_do_reload")

func _do_reload() -> void:
	m_is_reloading = false
	_ensure_sprite()
	if m_sprite == null:
		return

	var template: SpriteFrames = load(sprite_frames_template_path)
	if template == null:
		notify_property_list_changed()
		return

	template = template.duplicate()
	m_sprite.sprite_frames = template

	# Animation dropdown options (PackedStringArray -> Array[String])
	m_animations.clear()
	if m_sprite.sprite_frames != null:
		var anim_names_packed: PackedStringArray = m_sprite.sprite_frames.get_animation_names()
		for s in anim_names_packed:
			m_animations.append(String(s))

	if m_animations.is_empty():
		m_animations = [
			"idle_down", "idle_up", "idle_left", "idle_right",
			"walk_down", "walk_up", "walk_left", "walk_right",
			"run_down", "run_up", "run_left", "run_right",
			"jump_down", "jump_up", "jump_left", "jump_right"
		]

	var combined_image: Image = null

	var base_body_path: String = _get_body_sprite_path_for_current_body()

	var selected_feet_path: String = _get_feet_sprite_path_for_current_style()
	var selected_legs_path: String = _get_legs_sprite_path_for_current_style()
	var selected_shirt_path: String = _get_shirt_sprite_path_for_current_style()
	var selected_head_path: String = _get_head_sprite_path_for_current_style()
	var selected_hair_path: String = _get_hair_sprite_path_for_current_style()

	# ------------------------------------------------------------
	# 1) BG accessory layers ( *_bg.* ), auto-resolved by base name.
	#    Not selectable; blended FIRST (behind everything).
	#    Color is applied to BG as well (matching its owner part).
	# ------------------------------------------------------------
	var bg_entries: Array[Dictionary] = []

	var bg_path: String

	bg_path = _get_bg_sprite_path(base_body_path)
	if !bg_path.is_empty():
		bg_entries.append({"path": bg_path, "tint": Color.WHITE, "tint_on": false})

	bg_path = _get_bg_sprite_path(selected_feet_path)
	if !bg_path.is_empty():
		bg_entries.append({"path": bg_path, "tint": feet_color, "tint_on": true})

	bg_path = _get_bg_sprite_path(selected_legs_path)
	if !bg_path.is_empty():
		bg_entries.append({"path": bg_path, "tint": legs_color, "tint_on": true})

	bg_path = _get_bg_sprite_path(selected_shirt_path)
	if !bg_path.is_empty():
		bg_entries.append({"path": bg_path, "tint": shirt_color, "tint_on": true})

	bg_path = _get_bg_sprite_path(selected_head_path)
	if !bg_path.is_empty():
		bg_entries.append({"path": bg_path, "tint": head_color, "tint_on": true})

	bg_path = _get_bg_sprite_path(selected_hair_path)
	if !bg_path.is_empty():
		bg_entries.append({"path": bg_path, "tint": hair_color, "tint_on": true})

	for e in bg_entries:
		combined_image = _blend_layer_image(
			combined_image,
			String(e.get("path", "")),
			e.get("tint", Color.WHITE),
			bool(e.get("tint_on", false))
		)

	# ------------------------------------------------------------
	# 2) Main layers: body -> feet -> legs -> shirt -> head -> hair
	# ------------------------------------------------------------
	combined_image = _blend_layer_image(combined_image, base_body_path, Color.WHITE, false)

	if !selected_feet_path.is_empty():
		combined_image = _blend_layer_image(combined_image, selected_feet_path, feet_color, true)

	if !selected_legs_path.is_empty():
		combined_image = _blend_layer_image(combined_image, selected_legs_path, legs_color, true)

	if !selected_shirt_path.is_empty():
		combined_image = _blend_layer_image(combined_image, selected_shirt_path, shirt_color, true)

	if !selected_head_path.is_empty():
		combined_image = _blend_layer_image(combined_image, selected_head_path, head_color, true)

	if !selected_hair_path.is_empty():
		combined_image = _blend_layer_image(combined_image, selected_hair_path, hair_color, true)

	if combined_image == null:
		notify_property_list_changed()
		return

	var combined_tex := ImageTexture.create_from_image(combined_image)

	for anim_name in template.get_animation_names():
		var count := template.get_frame_count(anim_name)
		for i in count:
			var orig := template.get_frame_texture(anim_name, i)
			var atlas := orig.duplicate() as AtlasTexture
			if atlas:
				atlas.atlas = combined_tex
				template.set_frame(anim_name, i, atlas)

	if !m_animation.is_empty() and template.has_animation(m_animation):
		m_current_animation_name = m_animation
		m_sprite.play(m_animation)
	else:
		var names: PackedStringArray = template.get_animation_names()
		if names.size() > 0:
			m_animation = String(names[0])
			m_current_animation_name = m_animation
			m_sprite.play(m_animation)

	notify_property_list_changed()

# -------------------------------------------------------------------
# Private: bg helpers + blending
# -------------------------------------------------------------------

func _get_bg_sprite_path(main_sprite_path: String) -> String:
	if main_sprite_path.is_empty():
		return ""

	var dir_path := main_sprite_path.get_base_dir() + "/"
	var base := main_sprite_path.get_file().get_basename()
	var ext := main_sprite_path.get_extension()
	if base.ends_with("_bg"):
		return ""

	var bg_path := dir_path + base + "_bg." + ext
	return bg_path if FileAccess.file_exists(bg_path) else ""

func _blend_layer_image(
	combined_image: Image,
	layer_path: String,
	tint_color: Color,
	apply_tint: bool
) -> Image:
	if layer_path.is_empty():
		return combined_image

	var tex: Texture2D = load(layer_path)
	if tex == null:
		return combined_image

	var img: Image = tex.get_image()
	if img == null:
		return combined_image

	if apply_tint:
		img = ImageUtils.colorize_image(img, tint_color)

	if combined_image == null:
		return img

	var used := img.get_used_rect()
	combined_image.blend_rect(img, used, used.position)
	return combined_image

# -------------------------------------------------------------------
# Private: style option builder
# -------------------------------------------------------------------

func _refresh_all_style_options() -> void:
	_build_style_options(HAIR_SPRITE_FOLDER_PATH, hair_sprite_paths, hair_style_names, true, true, true, "Bald")
	m_hair = _get_valid_style_value(m_hair, hair_style_names)

	var legs_folder := _get_legs_folder_path_for_current_body()
	_build_style_options(legs_folder, legs_sprite_paths, legs_style_names, true, true, true, "<none>")
	m_legs = _get_valid_style_value(m_legs, legs_style_names)

	var shirts_folder := _get_shirts_folder_path_for_current_body()
	_build_style_options(shirts_folder, shirt_sprite_paths, shirt_style_names, true, true, true, "<none>")
	m_shirt = _get_valid_style_value(m_shirt, shirt_style_names)

	var head_folder := _get_head_folder_path_for_current_body()
	_build_style_options(head_folder, head_sprite_paths, head_style_names, true, true, true, "<none>")
	m_head = _get_valid_style_value(m_head, head_style_names)

	var feet_folder := _get_feet_folder_path_for_current_body()
	_build_style_options(feet_folder, feet_sprite_paths, feet_style_names, true, true, true, "<none>")
	m_feet = _get_valid_style_value(m_feet, feet_style_names)

	notify_property_list_changed()

func _is_male_variant() -> bool:
	match body_type:
		BodyTypeEnum.MALE, BodyTypeEnum.MUSCULAR:
			return true
		BodyTypeEnum.FEMALE, BodyTypeEnum.PREGNANT:
			return false
		BodyTypeEnum.TEEN, BodyTypeEnum.CHILD:
			return true
		_:
			return true

func _get_body_sprite_path_for_current_body() -> String:
	return "res://resources/sprites/characters/male/male_body.png" if _is_male_variant() else "res://resources/sprites/characters/female/female_body.png"

func _get_legs_folder_path_for_current_body() -> String:
	return MALE_LEGS_FOLDER_PATH if _is_male_variant() else FEMALE_LEGS_FOLDER_PATH

func _get_shirts_folder_path_for_current_body() -> String:
	return MALE_SHIRTS_FOLDER_PATH if _is_male_variant() else FEMALE_SHIRTS_FOLDER_PATH

func _get_head_folder_path_for_current_body() -> String:
	return MALE_HEAD_FOLDER_PATH if _is_male_variant() else FEMALE_HEAD_FOLDER_PATH

func _get_feet_folder_path_for_current_body() -> String:
	return MALE_FEET_FOLDER_PATH if _is_male_variant() else FEMALE_FEET_FOLDER_PATH

func _build_style_options(
	folder_path: String,
	out_sprite_paths: Array[String],
	out_style_names: Array[String],
	include_empty_option: bool,
	remove_prefixes: bool,
	remove_color_suffixes: bool,
	empty_option_name: String
) -> void:
	out_sprite_paths.clear()
	out_style_names.clear()

	if include_empty_option:
		out_sprite_paths.append("")
		out_style_names.append(empty_option_name)

	var discovered := _scan_sprite_paths(folder_path)
	for sprite_path in discovered:
		out_sprite_paths.append(sprite_path)
		var base := sprite_path.get_file().get_basename()
		out_style_names.append(_format_style_display_name(base, remove_prefixes, remove_color_suffixes, empty_option_name))

	if out_style_names.is_empty():
		out_style_names.append(empty_option_name)

func _scan_sprite_paths(folder_path: String) -> Array[String]:
	var discovered: Array[String] = []
	var da := DirAccess.open(folder_path)
	if da == null:
		return discovered

	da.list_dir_begin()
	var f := da.get_next()
	while !f.is_empty():
		if !da.current_is_dir():
			var lf := f.to_lower()
			var ok := lf.ends_with(".png") or lf.ends_with(".webp") or lf.ends_with(".jpg") or lf.ends_with(".jpeg")
			if ok:
				# Exclude *_bg sprites from selectable options
				var base := f.get_basename()
				if !base.ends_with("_bg"):
					discovered.append(folder_path + f)
		f = da.get_next()

	da.list_dir_end()
	discovered.sort()
	return discovered

func _format_style_display_name(file_base_name: String, remove_prefixes: bool, remove_color_suffixes: bool, empty_option_name: String) -> String:
	var name := file_base_name
	if name.is_empty():
		return empty_option_name

	if remove_prefixes:
		var prefixes := ["male_", "female_", "hair_", "legs_", "shirt_", "head_", "feet_"]
		for pr in prefixes:
			if name.begins_with(pr):
				name = name.trim_prefix(pr)
				break

	if remove_color_suffixes:
		var suffixes := ["_white", "_black", "_blonde", "_brown", "_red", "_blue", "_green"]
		for su in suffixes:
			if name.ends_with(su):
				name = name.trim_suffix(su)
				break

	name = name.replace("_", " ")
	var words := name.split(" ", false)
	for i in words.size():
		var w: String = words[i]
		if w.length() == 0:
			continue
		words[i] = w[0].to_upper() + w.substr(1)

	return " ".join(words)

func _get_valid_style_value(style_value: String, style_names: Array[String]) -> String:
	if style_names.is_empty():
		return style_value
	if style_names.find(style_value) != -1:
		return style_value
	return style_names[0]

func _get_selected_sprite_path(style_value: String, style_names: Array[String], sprite_paths: Array[String]) -> String:
	if style_value == "<none>":
		return ""
	if style_names.is_empty():
		return ""
	var idx := style_names.find(style_value)
	if idx < 0 or idx >= sprite_paths.size():
		return ""
	return sprite_paths[idx]

func _get_hair_sprite_path_for_current_style() -> String:
	return _get_selected_sprite_path(m_hair, hair_style_names, hair_sprite_paths)

func _get_legs_sprite_path_for_current_style() -> String:
	return _get_selected_sprite_path(m_legs, legs_style_names, legs_sprite_paths)

func _get_shirt_sprite_path_for_current_style() -> String:
	return _get_selected_sprite_path(m_shirt, shirt_style_names, shirt_sprite_paths)

func _get_head_sprite_path_for_current_style() -> String:
	return _get_selected_sprite_path(m_head, head_style_names, head_sprite_paths)

func _get_feet_sprite_path_for_current_style() -> String:
	return _get_selected_sprite_path(m_feet, feet_style_names, feet_sprite_paths)
