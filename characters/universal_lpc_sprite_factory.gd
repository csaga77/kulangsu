# res://characters/universal_lpc_sprite_factory.gd
@tool
class_name UniversalLPCSpriteFactory
extends RefCounted

# ------------------------------------------------------------
# Singleton (lazy)
# ------------------------------------------------------------
static var s_instance: UniversalLPCSpriteFactory = null

static func get_instance() -> UniversalLPCSpriteFactory:
	if s_instance == null:
		s_instance = UniversalLPCSpriteFactory.new()
	return s_instance


# ------------------------------------------------------------
# Folder / base paths (factory owns folder logic)
# ------------------------------------------------------------
#
# OPTIONS pattern:
#   Category -> [ { "path": String, "body_types": Array[String] }, ... ]
#
# body_types supports:
#   "male", "female", "teen", "child", "muscular", "pregnant"
# and also group aliases:
#   "adult" : matches male/female/teen/muscular/pregnant
#   "thin"  : matches female/teen/pregnant/child
#
# IMPORTANT:
# - Selection priority is the ORDER of variants in each category array.
# - Matching uses _body_tags_for(body_type) (specific -> fallbacks).
#

const HAIR_OPTIONS := {
	"Default": [
		{"path": "res://resources/sprites/characters/hair/",       "body_types": ["adult"]},
		{"path": "res://resources/sprites/characters/hair/child/", "body_types": ["child"]},
	],
}

const HEAD_OPTIONS := {
	"Human": [
		{"path": "res://resources/sprites/characters/head/child/", "body_types": ["child"]},
		{"path": "res://resources/sprites/characters/head/",       "body_types": ["adult"]},
	],
}

const BODY_OPTIONS := {
	"Human": [
		{"path": "res://resources/sprites/characters/body/male/",     "body_types": ["male"]},
		{"path": "res://resources/sprites/characters/body/muscular/", "body_types": ["muscular"]},
		{"path": "res://resources/sprites/characters/body/female/",   "body_types": ["female"]},
		{"path": "res://resources/sprites/characters/body/teen/",     "body_types": ["teen"]},
		{"path": "res://resources/sprites/characters/body/pregnant/", "body_types": ["pregnant"]},
		{"path": "res://resources/sprites/characters/body/child/",    "body_types": ["child"]},
	],
}

const LEGS_OPTIONS := {
	"Default": [
		{"path": "res://resources/sprites/characters/legs/male/",      "body_types": ["male"]},
		{"path": "res://resources/sprites/characters/legs/muscular/",  "body_types": ["muscular"]},
		{"path": "res://resources/sprites/characters/legs/pregnant/",  "body_types": ["pregnant"]},
		{"path": "res://resources/sprites/characters/legs/child/",     "body_types": ["child"]},
		{"path": "res://resources/sprites/characters/legs/thin/",      "body_types": ["thin"]},
	],
}

const SHIRT_OPTIONS := {
	"Clothes": [
		{"path": "res://resources/sprites/characters/torso/clothes/male/",      "body_types": ["male"]},
		{"path": "res://resources/sprites/characters/torso/clothes/teen/",      "body_types": ["teen"]},
		{"path": "res://resources/sprites/characters/torso/clothes/pregnant/",  "body_types": ["pregnant"]},
		{"path": "res://resources/sprites/characters/torso/clothes/child/",     "body_types": ["child"]},
		{"path": "res://resources/sprites/characters/torso/clothes/female/",    "body_types": ["female"]},
	],
}

const FEET_OPTIONS := {
	"Foot Wears": [
		{"path": "res://resources/sprites/characters/feet/male/", "body_types": ["male", "muscular"]},
		{"path": "res://resources/sprites/characters/feet/thin/", "body_types": ["thin", "pregnant"]},
	]
}


# ------------------------------------------------------------
# Cache
# ------------------------------------------------------------
var m_cache_hair: Dictionary = {}       # key: "hair:<body_key>:<options_hash>"
var m_cache_parts: Dictionary = {}      # key: "<part>:<body_key>:<options_hash>"
var m_cache_animations: Dictionary = {} # template_path -> Array[String]


# ------------------------------------------------------------
# Public API: style options (names only)
# ------------------------------------------------------------
func get_hair_options(body_type: int) -> Array[String]:
	return _cached_names(_get_hair_cache(body_type))

func get_body_options(body_type: int) -> Array[String]:
	return _cached_names(_get_part_cache("body", body_type, BODY_OPTIONS, "Human", "Default"))

func get_legs_options(body_type: int) -> Array[String]:
	return _cached_names(_get_part_cache("legs", body_type, LEGS_OPTIONS, "Default", "<none>"))

func get_shirt_options(body_type: int) -> Array[String]:
	return _cached_names(_get_part_cache("shirt", body_type, SHIRT_OPTIONS, "Clothes", "<none>"))

func get_head_options(body_type: int) -> Array[String]:
	# Uses Default-label behavior too
	return _cached_names(_get_part_cache("head", body_type, HEAD_OPTIONS, "Human", "Default"))

func get_feet_options(body_type: int) -> Array[String]:
	return _cached_names(_get_part_cache("feet", body_type, FEET_OPTIONS, "Foot Wears", "<none>"))

func get_valid_style_value(style_value: String, options: Array[String]) -> String:
	if options.is_empty():
		return style_value
	if options.find(style_value) != -1:
		return style_value
	return options[0]


# ------------------------------------------------------------
# Public API: animation options (names only)
# ------------------------------------------------------------
func get_animation_options_from_template(sprite_frames_template_path: String) -> Array[String]:
	if sprite_frames_template_path.is_empty():
		return []

	if m_cache_animations.has(sprite_frames_template_path):
		return _cast_to_string_array(m_cache_animations[sprite_frames_template_path])

	var out: Array[String] = []
	var sf: SpriteFrames = load(sprite_frames_template_path)
	if sf != null:
		var packed: PackedStringArray = sf.get_animation_names()
		for s in packed:
			out.append(String(s))

	if out.is_empty():
		out = [
			"idle_s", "idle_n", "idle_w", "idle_e",
			"walk_s", "walk_n", "walk_w", "walk_e",
			"run_s", "run_n", "run_w", "run_e",
			"jump_s", "jump_n", "jump_w", "jump_e"
		]

	m_cache_animations[sprite_frames_template_path] = out
	return out


# ------------------------------------------------------------
# Public API: create final SpriteFrames
# ------------------------------------------------------------
func create_sprite_frames(
	sprite_frames_template_path: String,
	body_type: int,
	selected_body: String,
	selected_hair: String,
	selected_legs: String,
	selected_shirt: String,
	selected_head: String,
	selected_feet: String,
	body_color: Color,
	hair_color: Color,
	legs_color: Color,
	shirt_color: Color,
	feet_color: Color
) -> SpriteFrames:
	var sprite_frames: SpriteFrames = load(sprite_frames_template_path)
	if sprite_frames == null:
		return null

	sprite_frames = sprite_frames.duplicate()

	var body_cache := _get_part_cache("body", body_type, BODY_OPTIONS, "Human", "Default")
	var hair_cache := _get_hair_cache(body_type)
	var legs_cache := _get_part_cache("legs", body_type, LEGS_OPTIONS, "Default", "<none>")
	var shirt_cache := _get_part_cache("shirt", body_type, SHIRT_OPTIONS, "Clothes", "<none>")
	var head_cache := _get_part_cache("head", body_type, HEAD_OPTIONS, "Human", "Default")
	var feet_cache := _get_part_cache("feet", body_type, FEET_OPTIONS, "Foot Wears", "<none>")

	var body_path: String = _resolve_from_cache(body_cache, selected_body)
	var hair_path: String = _resolve_from_cache(hair_cache, selected_hair)
	var legs_path: String = _resolve_from_cache(legs_cache, selected_legs)
	var shirt_path: String = _resolve_from_cache(shirt_cache, selected_shirt)
	var head_path: String = _resolve_from_cache(head_cache, selected_head)
	var feet_path: String = _resolve_from_cache(feet_cache, selected_feet)

	var atlas_image: Image = create_sprite_atlas_image(
		body_path,
		hair_path,
		legs_path,
		shirt_path,
		head_path,
		feet_path,
		body_color,
		hair_color,
		legs_color,
		shirt_color,
		feet_color
	)
	if atlas_image == null:
		return sprite_frames

	var atlas_tex := ImageTexture.create_from_image(atlas_image)

	for anim_name in sprite_frames.get_animation_names():
		var count := sprite_frames.get_frame_count(anim_name)
		for i in count:
			var orig := sprite_frames.get_frame_texture(anim_name, i)
			var atlas := orig.duplicate() as AtlasTexture
			if atlas:
				atlas.atlas = atlas_tex
				sprite_frames.set_frame(anim_name, i, atlas)

	return sprite_frames


# ------------------------------------------------------------
# Public API: create atlas image
# ------------------------------------------------------------
func create_sprite_atlas_image(
	body_path: String,
	hair_path: String,
	legs_path: String,
	shirt_path: String,
	head_path: String,
	feet_path: String,
	body_color: Color,
	hair_color: Color,
	legs_color: Color,
	shirt_color: Color,
	feet_color: Color
) -> Image:
	if body_path.is_empty():
		return null

	var combined: Image = null

	# 1) BG layers first
	var bg_layers: Array[Dictionary] = []

	var p: String
	p = _bg_path(body_path)
	if !p.is_empty():
		bg_layers.append({"path": p, "tint": body_color, "tint_on": true})

	p = _bg_path(feet_path)
	if !p.is_empty():
		bg_layers.append({"path": p, "tint": feet_color, "tint_on": true})

	p = _bg_path(legs_path)
	if !p.is_empty():
		bg_layers.append({"path": p, "tint": legs_color, "tint_on": true})

	p = _bg_path(shirt_path)
	if !p.is_empty():
		bg_layers.append({"path": p, "tint": shirt_color, "tint_on": true})

	p = _bg_path(head_path)
	if !p.is_empty():
		bg_layers.append({"path": p, "tint": body_color, "tint_on": true})

	p = _bg_path(hair_path)
	if !p.is_empty():
		bg_layers.append({"path": p, "tint": hair_color, "tint_on": true})

	for e in bg_layers:
		combined = _blend_layer_image(
			combined,
			String(e.get("path", "")),
			e.get("tint", Color.WHITE),
			bool(e.get("tint_on", false))
		)

	# 2) Main layers
	combined = _blend_layer_image(combined, body_path, body_color, true)

	if !feet_path.is_empty():
		combined = _blend_layer_image(combined, feet_path, feet_color, true)
	if !legs_path.is_empty():
		combined = _blend_layer_image(combined, legs_path, legs_color, true)
	if !shirt_path.is_empty():
		combined = _blend_layer_image(combined, shirt_path, shirt_color, true)
	if !head_path.is_empty():
		combined = _blend_layer_image(combined, head_path, body_color, true)
	if !hair_path.is_empty():
		combined = _blend_layer_image(combined, hair_path, hair_color, true)

	return combined


# ============================================================
# Internal: hair cache
# ============================================================
func _get_hair_cache(body_type: int) -> Dictionary:
	var cache_key := "hair:" + _body_key(body_type) + ":" + str(HAIR_OPTIONS.hash())
	if m_cache_hair.has(cache_key):
		return m_cache_hair[cache_key]

	var out := _get_options_cache(HAIR_OPTIONS, body_type, "Default", "Bald")
	m_cache_hair[cache_key] = out
	return out


# ============================================================
# Internal: resolve
# ============================================================
func _resolve_from_cache(cache: Dictionary, selected_name: String) -> String:
	if selected_name == "<none>" or selected_name.is_empty():
		return ""
	var name_to_path: Dictionary = cache.get("name_to_path", {})
	if name_to_path.has(selected_name):
		return String(name_to_path[selected_name])
	return ""


# ============================================================
# Internal: caches (generic)
# ============================================================
func _get_part_cache(
	part: String,
	body_type: int,
	options_dict: Dictionary,
	default_category: String,
	empty_name: String
) -> Dictionary:
	var cache_key := part + ":" + _body_key(body_type) + ":" + str(options_dict.hash())
	if m_cache_parts.has(cache_key):
		return m_cache_parts[cache_key]

	var out := _get_options_cache(options_dict, body_type, default_category, empty_name)
	m_cache_parts[cache_key] = out
	return out


# Build cache from:
#   OPTIONS = { "Category": [ {path, body_types:[...]}, ... ] }
#
# IMPORTANT CHANGE:
# - If empty_name == "Default", ALWAYS create a "Default" entry and bind it to
#   the first discovered sprite in default_category (preferred) for ALL parts.
func _get_options_cache(
	options_dict: Dictionary,
	body_type: int,
	default_category: String,
	empty_name: String
) -> Dictionary:
	var names: Array[String] = []
	var name_to_path: Dictionary = {}

	var has_default := (empty_name == "Default")
	if has_default:
		names.append("Default")
		name_to_path["Default"] = ""
	else:
		if empty_name != "":
			names.append(empty_name)
			name_to_path[empty_name] = ""

	var tags := _body_tags_for(body_type)

	# Stable category order
	var cat_keys: Array[String] = []
	for k in options_dict.keys():
		cat_keys.append(String(k))
	cat_keys.sort()

	for category in cat_keys:
		var variants_any: Variant = options_dict.get(category, [])
		var variants: Array = variants_any if variants_any is Array else []

		var folder := _pick_folder_for_tags(variants, tags)
		if folder.is_empty():
			continue

		var local_names: Array[String] = []
		var local_map: Dictionary = {}
		_build_style_options(folder, local_names, local_map, false, true, true, "")

		# NEW: Always bind "Default" to first discovered sprite in default_category (preferred)
		if has_default and category == default_category and String(name_to_path.get("Default", "")).is_empty():
			if local_names.size() > 0:
				name_to_path["Default"] = String(local_map.get(local_names[0], ""))

		for n in local_names:
			var full_name := category + " / " + n
			if !name_to_path.has(full_name):
				names.append(full_name)
				name_to_path[full_name] = String(local_map.get(n, ""))

	# If Default still empty, bind to first available non-empty option
	if has_default and String(name_to_path.get("Default", "")).is_empty():
		for n2 in names:
			if n2 == "Default":
				continue
			var p2 := String(name_to_path.get(n2, ""))
			if !p2.is_empty():
				name_to_path["Default"] = p2
				break

	# Keep Default first if enabled
	if has_default and names.size() > 0 and names[0] != "Default":
		names.erase("Default")
		names.insert(0, "Default")

	return {"names": names, "name_to_path": name_to_path}


func _pick_folder_for_tags(variants: Array, tags: Array[String]) -> String:
	for v_any in variants:
		var v: Dictionary = v_any if v_any is Dictionary else {}
		var supported := _variant_supported_body_types(v)

		for tag in tags:
			if supported.has(tag):
				return String(v.get("path", ""))

	return ""


func _variant_supported_body_types(v: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var raw: Variant = v.get("body_types", [])
	if raw is Array:
		for e in raw:
			out.append(String(e))
	elif raw is PackedStringArray:
		for e2 in raw:
			out.append(String(e2))
	else:
		var legacy := String(v.get("body_type", ""))
		if !legacy.is_empty():
			out.append(legacy)
	return out


func _build_style_options(
	folder_path: String,
	out_names: Array[String],
	out_name_to_path: Dictionary,
	include_empty_option: bool,
	remove_prefixes: bool,
	remove_color_suffixes: bool,
	empty_option_name: String
) -> void:
	out_names.clear()
	out_name_to_path.clear()

	if include_empty_option:
		out_names.append(empty_option_name)
		out_name_to_path[empty_option_name] = ""

	var discovered_paths := _scan_sprite_paths(folder_path)
	for sprite_path in discovered_paths:
		var base := sprite_path.get_file().get_basename()
		var display := _format_style_display_name(base, remove_prefixes, remove_color_suffixes, empty_option_name)

		if !out_name_to_path.has(display):
			out_names.append(display)
			out_name_to_path[display] = sprite_path


func _scan_sprite_paths(folder_path: String) -> Array[String]:
	var discovered: Array[String] = []
	if folder_path.is_empty():
		return discovered

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
				var base := f.get_basename()
				if !base.ends_with("_bg"):
					discovered.append(folder_path + f)
		f = da.get_next()

	da.list_dir_end()
	discovered.sort()
	return discovered


# ============================================================
# Internal: blending + bg lookup
# ============================================================
func _bg_path(main_sprite_path: String) -> String:
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


# ============================================================
# Internal: body tag / cache key logic
# ============================================================
# BodyTypeEnum ordering:
# 0 MALE, 1 FEMALE, 2 TEEN, 3 CHILD, 4 MUSCULAR, 5 PREGNANT
func _body_tags_for(body_type: int) -> Array[String]:
	match body_type:
		0: return ["male", "adult"]
		1: return ["female", "thin", "adult"]
		2: return ["teen", "thin", "adult"]
		3: return ["child"]
		4: return ["muscular", "adult"]
		5: return ["pregnant", "thin", "adult"]
		_: return ["adult"]

func _body_key(body_type: int) -> String:
	var tags := _body_tags_for(body_type)
	return tags[0] if tags.size() > 0 else "adult"


# ============================================================
# Internal: typed helpers
# ============================================================
func _cached_names(cache: Dictionary) -> Array[String]:
	if cache.has("names"):
		return _cast_to_string_array(cache["names"])
	return []

func _cast_to_string_array(v: Variant) -> Array[String]:
	var out: Array[String] = []
	if v is Array:
		for e in v:
			out.append(String(e))
	elif v is PackedStringArray:
		for e2 in v:
			out.append(String(e2))
	return out


func _format_style_display_name(
	file_base_name: String,
	remove_prefixes: bool,
	remove_color_suffixes: bool,
	empty_option_name: String
) -> String:
	var name := file_base_name
	if name.is_empty():
		return empty_option_name

	if remove_prefixes:
		var prefixes := ["hair_", "legs_", "shirt_", "head_", "feet_"]
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
