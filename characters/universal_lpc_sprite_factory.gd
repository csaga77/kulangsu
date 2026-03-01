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
# SpriteFrames template selection (HumanBody2D should NOT know this)
# ------------------------------------------------------------
const DEFAULT_SPRITE_FRAMES_TEMPLATE_PATH: String = "res://resources/animations/characters/male_animations.tres"

func _get_template_path_for_body_type(_body_type: int) -> String:
	return DEFAULT_SPRITE_FRAMES_TEMPLATE_PATH


# ------------------------------------------------------------
# Folder / base paths (factory owns folder logic)
# ------------------------------------------------------------
const HAIR_OPTIONS := {
	"Default": [
		{"path": "res://resources/sprites/characters/hair/",       "body_types": ["adult"]},
		{"path": "res://resources/sprites/characters/hair/child/", "body_types": ["child"]},
	],
}

const FACE_OPTIONS := {
	"Human": [
		{"path": "res://resources/sprites/characters/head/faces/human/child/",   "body_types": ["child"]},
		{"path": "res://resources/sprites/characters/head/faces/human/male/",    "body_types": ["male", "muscular"]},
		{"path": "res://resources/sprites/characters/head/faces/human/female/",  "body_types": ["female", "teen"]},
		{"path": "res://resources/sprites/characters/head/faces/human/elderly/", "body_types": ["adult"], "head_types": ["elderly"]},
	],
}

const HEAD_OPTIONS := {
	"Human": [
		{"path": "res://resources/sprites/characters/head/heads/human/child/", "body_types": ["child"]},
		{"path": "res://resources/sprites/characters/head/heads/human/",       "body_types": ["adult"]},
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
		{"path": "res://resources/sprites/characters/legs/male/",     "body_types": ["male"]},
		{"path": "res://resources/sprites/characters/legs/muscular/", "body_types": ["muscular"]},
		{"path": "res://resources/sprites/characters/legs/pregnant/", "body_types": ["pregnant"]},
		{"path": "res://resources/sprites/characters/legs/child/",    "body_types": ["child"]},
		{"path": "res://resources/sprites/characters/legs/thin/",     "body_types": ["thin"]},
	],
}

const SHIRT_OPTIONS := {
	"Clothes": [
		{"path": "res://resources/sprites/characters/torso/clothes/male/",     "body_types": ["male"]},
		{"path": "res://resources/sprites/characters/torso/clothes/teen/",     "body_types": ["teen"]},
		{"path": "res://resources/sprites/characters/torso/clothes/pregnant/", "body_types": ["pregnant"]},
		{"path": "res://resources/sprites/characters/torso/clothes/child/",    "body_types": ["child"]},
		{"path": "res://resources/sprites/characters/torso/clothes/female/",   "body_types": ["female"]},
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
var m_cache_parts: Dictionary = {}      # key: "<part>:<body_key>:<options_hash>[:<head_type>]"
var m_cache_animations: Dictionary = {} # template_path -> Array[String]


# ------------------------------------------------------------
# Public API: style options (names only)
# ------------------------------------------------------------
func get_hair_options(body_type: int) -> Array[String]:
	return _cached_names(_get_hair_cache(body_type))

# Backward-compatible: defaults to non-elderly face cache.
func get_face_options(body_type: int, head_type: String = "") -> Array[String]:
	return _cached_names(_get_part_cache("face", body_type, FACE_OPTIONS, "Human", "<none>", head_type))

func get_body_options(body_type: int) -> Array[String]:
	return _cached_names(_get_part_cache("body", body_type, BODY_OPTIONS, "Human", "Default", ""))

func get_legs_options(body_type: int) -> Array[String]:
	return _cached_names(_get_part_cache("legs", body_type, LEGS_OPTIONS, "Default", "<none>", ""))

func get_shirt_options(body_type: int) -> Array[String]:
	return _cached_names(_get_part_cache("shirt", body_type, SHIRT_OPTIONS, "Clothes", "<none>", ""))

func get_head_options(body_type: int) -> Array[String]:
	return _cached_names(_get_part_cache("head", body_type, HEAD_OPTIONS, "Human", "Default", ""))

func get_feet_options(body_type: int) -> Array[String]:
	return _cached_names(_get_part_cache("feet", body_type, FEET_OPTIONS, "Foot Wears", "<none>", ""))

func get_valid_style_value(style_value: String, options: Array[String]) -> String:
	if options.is_empty():
		return style_value
	if options.find(style_value) != -1:
		return style_value
	return options[0]


# ------------------------------------------------------------
# Public API: animation options (names only)
# ------------------------------------------------------------
func get_animation_options(body_type: int) -> Array[String]:
	var template_path := _get_template_path_for_body_type(body_type)
	return get_animation_options_from_template(template_path)

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
# Public API: create final SpriteFrames (flexible layer API)
# ------------------------------------------------------------
# layers supports any order and any subset. Each layer can be either:
#   { "part": "face", "style": "Default", "tint": Color, "tint_on": true }
# or
#   { "path": "res://...", "tint": Color, "tint_on": true }
#
# BG order is strictly the inverted order of layers.
func create_sprite_frames(body_type: int, layers: Array[Dictionary], name:StringName = "") -> SpriteFrames:
	var template_path := _get_template_path_for_body_type(body_type)
	var sprite_frames: SpriteFrames = load(template_path)
	if sprite_frames == null:
		return null

	sprite_frames = sprite_frames.duplicate()

	var resolved_layers := _resolve_layers(body_type, layers)
	if resolved_layers.is_empty():
		return sprite_frames

	var atlas_image: Image = create_sprite_atlas_image(resolved_layers)
	if atlas_image == null:
		return sprite_frames
		
	if !name.is_empty():
		atlas_image.save_png("user://sprite_{0}_{1}.png".format([body_type, name.replace("/", "_")]))

	var atlas_tex := ImageTexture.create_from_image(atlas_image)

	for anim_name in sprite_frames.get_animation_names():
		var count := sprite_frames.get_frame_count(anim_name)
		for i in range(count):
			var orig := sprite_frames.get_frame_texture(anim_name, i)
			var atlas := orig.duplicate() as AtlasTexture
			if atlas:
				atlas.atlas = atlas_tex
				sprite_frames.set_frame(anim_name, i, atlas)

	return sprite_frames


# ------------------------------------------------------------
# Public API: create atlas image (strict BG inversion rule)
# ------------------------------------------------------------
func create_sprite_atlas_image(layers: Array[Dictionary]) -> Image:
	var combined: Image = null

	# 1) BG pass: STRICT inverted order of layers
	for i in range(layers.size() - 1, -1, -1):
		var layer := layers[i]
		var is_bg_on := bool(layer.get("is_bg_on", true))
		if !is_bg_on:
			continue
		var path := String(layer.get("path", ""))
		if path.is_empty():
			continue

		var tint_on := bool(layer.get("tint_on", true))
		var tint: Color = layer.get("tint", Color.WHITE)
		var tint_mask: Array[Color] = ContainerUtils.to_color_array(layer.get("tint_mask", []))

		var bg_path := _bg_path(path)
		if !bg_path.is_empty():
			combined = _blend_layer_image(combined, bg_path, tint, tint_on, tint_mask)

	# 2) Main pass: forward order
	for layer in layers:
		var is_fg_on := bool(layer.get("is_fg_on", true))
		if !is_fg_on:
			continue
		var path := String(layer.get("path", ""))
		if path.is_empty():
			continue

		var tint_on := bool(layer.get("tint_on", true))
		var tint: Color = layer.get("tint", Color.WHITE)
		var tint_mask: Array[Color] = ContainerUtils.to_color_array(layer.get("tint_mask", []))

		combined = _blend_layer_image(combined, path, tint, tint_on, tint_mask)

	return combined


# ============================================================
# Internal: resolve flexible layers -> file paths
# ============================================================
func _resolve_layers(body_type: int, layers: Array[Dictionary]) -> Array[Dictionary]:
	# 1) First resolve "head" path (if any), so we can infer head_type for face.
	var resolved_head_path := ""
	for l_any in layers:
		var l: Dictionary = l_any if l_any is Dictionary else {}

		if String(l.get("part", "")) == "head":
			if l.has("path"):
				resolved_head_path = String(l.get("path", ""))
				break
			else:
				var style := String(l.get("style", ""))
				var hp := _resolve_part_style_to_path("head", body_type, style, "")
				if !hp.is_empty():
					resolved_head_path = hp
					break

	var inferred_head_type := _infer_head_type_from_head_path(resolved_head_path)

	# 2) Resolve all layers, routing face via inferred_head_type.
	var out: Array[Dictionary] = []

	for l_any2 in layers:
		var l2: Dictionary = l_any2 if l_any2 is Dictionary else {}

		# Direct path provided
		if l2.has("path"):
			var p := String(l2.get("path", ""))
			if !p.is_empty():
				out.append(l2)
			continue

		# Resolve from part/style
		var part := String(l2.get("part", ""))
		var style := String(l2.get("style", ""))

		var head_type_for_part := inferred_head_type if part == "face" else ""
		var resolved := _resolve_part_style_to_path(part, body_type, style, head_type_for_part)
		if !resolved.is_empty():
			l2["path"] = resolved
			out.append(l2)

	return out


func _resolve_part_style_to_path(part: String, body_type: int, style: String, head_type: String) -> String:
	if style.is_empty() or style == "<none>":
		return ""

	if part == "hair":
		return _resolve_from_cache(_get_hair_cache(body_type), style)
	if part == "body":
		return _resolve_from_cache(_get_part_cache("body", body_type, BODY_OPTIONS, "Human", "Default", ""), style)
	if part == "legs":
		return _resolve_from_cache(_get_part_cache("legs", body_type, LEGS_OPTIONS, "Default", "<none>", ""), style)
	if part == "shirt":
		return _resolve_from_cache(_get_part_cache("shirt", body_type, SHIRT_OPTIONS, "Clothes", "<none>", ""), style)
	if part == "head":
		return _resolve_from_cache(_get_part_cache("head", body_type, HEAD_OPTIONS, "Human", "Default", ""), style)
	if part == "face":
		return _resolve_from_cache(_get_part_cache("face", body_type, FACE_OPTIONS, "Human", "<none>", head_type), style)
	if part == "feet":
		return _resolve_from_cache(_get_part_cache("feet", body_type, FEET_OPTIONS, "Foot Wears", "<none>", ""), style)

	return ""


func _infer_head_type_from_head_path(head_path: String) -> String:
	if head_path.is_empty():
		return ""
	var s := head_path.to_lower()
	# Rule: contains "_elderly" OR "elderly_"
	if s.find("_elderly") != -1 or s.find("elderly_") != -1:
		return "elderly"
	return ""


# ============================================================
# Internal: hair cache
# ============================================================
func _get_hair_cache(body_type: int) -> Dictionary:
	var cache_key := "hair:" + _body_key(body_type) + ":" + str(HAIR_OPTIONS.hash())
	if m_cache_hair.has(cache_key):
		return m_cache_hair[cache_key]

	var out := _get_options_cache(HAIR_OPTIONS, body_type, "Default", "Bald", "")
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
	empty_name: String,
	head_type: String
) -> Dictionary:
	var ht := head_type.strip_edges().to_lower()
	var ht_key := ""
	# Only faces are head-type dependent (keep others stable)
	if part == "face" and !ht.is_empty():
		ht_key = ":head_type=" + ht

	var cache_key := part + ":" + _body_key(body_type) + ":" + str(options_dict.hash()) + ht_key
	if m_cache_parts.has(cache_key):
		return m_cache_parts[cache_key]

	var out := _get_options_cache(options_dict, body_type, default_category, empty_name, ht)
	m_cache_parts[cache_key] = out
	return out


# IMPORTANT CHANGE:
# - If empty_name == "Default", ALWAYS create a "Default" entry and bind it to
#   the first discovered sprite in default_category (preferred) for ALL parts.
# - head_type filtering:
#   * If head_type is non-empty, ONLY variants whose "head_types" includes it are eligible.
#   * If head_type is empty, variants that specify "head_types" are ignored (reserved variants).
func _get_options_cache(
	options_dict: Dictionary,
	body_type: int,
	default_category: String,
	empty_name: String,
	head_type: String
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

		var folder := _pick_folder_for_tags_and_head_type(variants, tags, head_type)
		if folder.is_empty():
			continue

		var local_names: Array[String] = []
		var local_map: Dictionary = {}
		_build_style_options(folder, local_names, local_map, false, "")

		# Always bind Default to first discovered sprite in default_category (preferred)
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


func _pick_folder_for_tags_and_head_type(variants: Array, body_tags: Array[String], head_type: String) -> String:
	var ht := head_type.strip_edges().to_lower()

	for v_any in variants:
		var v: Dictionary = v_any if v_any is Dictionary else {}

		# Head type gating (if variant declares head_types)
		var v_head_types := _variant_supported_head_types(v)
		if ht.is_empty():
			# If we are NOT in a head-typed request, ignore reserved variants that declare head_types.
			if v_head_types.size() > 0:
				continue
		else:
			# If we ARE in a head-typed request, require a match.
			if v_head_types.size() == 0:
				continue
			if v_head_types.find(ht) == -1:
				continue

		var supported := _variant_supported_body_types(v)
		for tag in body_tags:
			if supported.has(tag):
				return String(v.get("path", ""))

	return ""


func _variant_supported_head_types(v: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var raw: Variant = v.get("head_types", [])
	if raw is Array:
		for e in raw:
			out.append(String(e).to_lower())
	elif raw is PackedStringArray:
		for e2 in raw:
			out.append(String(e2).to_lower())
	return out


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
		var display := _format_style_display_name(base, empty_option_name)

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
	apply_tint: bool,
	mask: Array[Color] = []
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
		# Tint in-place on the layer image to avoid extra copies.
		img = ImageUtils.colorize_image(img, tint_color, false, mask, false)

	if combined_image == null:
		return img

	var used := img.get_used_rect()
	combined_image.blend_rect(img, used, used.position)
	return combined_image


# ============================================================
# Internal: body tag / cache key logic
# ============================================================
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


func _format_style_display_name(file_base_name: String, empty_option_name: String) -> String:
	var name := file_base_name
	if name.is_empty():
		return empty_option_name

	name = name.replace("_", " ")
	var words := name.split(" ", false)
	for i in range(words.size()):
		var w: String = words[i]
		if w.length() == 0:
			continue
		words[i] = w[0].to_upper() + w.substr(1)

	return " ".join(words)
