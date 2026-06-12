@tool
class_name LowPolyCharacterConfig
extends Resource

const MIN_HEIGHT_MODIFIER := 0.7
const MAX_HEIGHT_MODIFIER := 1.4
const MIN_LIMB_THICKNESS := 0.5
const MAX_LIMB_THICKNESS := 2.0
const MIN_HEAD_SCALE := 0.6
const MAX_HEAD_SCALE := 1.5
const MIN_TORSO_MASS := 0.8
const MAX_TORSO_MASS := 1.8

@export var seed_text := ""
@export_range(MIN_HEIGHT_MODIFIER, MAX_HEIGHT_MODIFIER, 0.01) var height_modifier := 1.0
@export_range(MIN_LIMB_THICKNESS, MAX_LIMB_THICKNESS, 0.01) var limb_thickness := 1.0
@export_range(MIN_HEAD_SCALE, MAX_HEAD_SCALE, 0.01) var head_scale := 1.0
@export_range(MIN_TORSO_MASS, MAX_TORSO_MASS, 0.01) var torso_mass := 1.0
@export var main_color := Color(0.18, 0.52, 0.58, 1.0)
@export var accent_color := Color(0.83, 0.66, 0.30, 1.0)
@export var skin_color := Color(0.84, 0.63, 0.45, 1.0)
@export var hair_color := Color(0.25, 0.16, 0.10, 1.0)
@export var left_limb_scale := 1.0
@export var right_limb_scale := 1.0
@export var left_accent_flag := false
@export var right_accent_flag := false


static func from_seed(seed_value: Variant) -> LowPolyCharacterConfig:
	var cfg := LowPolyCharacterConfig.new()
	cfg.seed_text = str(seed_value)
	if cfg.seed_text.is_empty():
		cfg.seed_text = "kulangsu"

	cfg.height_modifier = _range(cfg.seed_text, "height", MIN_HEIGHT_MODIFIER, MAX_HEIGHT_MODIFIER)
	cfg.limb_thickness = _range(cfg.seed_text, "limb_thickness", MIN_LIMB_THICKNESS, MAX_LIMB_THICKNESS)
	cfg.head_scale = _range(cfg.seed_text, "head_scale", MIN_HEAD_SCALE, MAX_HEAD_SCALE)
	cfg.torso_mass = _range(cfg.seed_text, "torso_mass", MIN_TORSO_MASS, MAX_TORSO_MASS)
	cfg.left_limb_scale = _range(cfg.seed_text, "left_limb_scale", 0.88, 1.12)
	cfg.right_limb_scale = _range(cfg.seed_text, "right_limb_scale", 0.88, 1.12)
	cfg.left_accent_flag = _unit(cfg.seed_text, "left_accent") > 0.68
	cfg.right_accent_flag = _unit(cfg.seed_text, "right_accent") > 0.68
	cfg._apply_seed_palette()
	return cfg


func to_dictionary() -> Dictionary:
	return {
		"seed_text": seed_text,
		"height_modifier": snappedf(height_modifier, 0.0001),
		"limb_thickness": snappedf(limb_thickness, 0.0001),
		"head_scale": snappedf(head_scale, 0.0001),
		"torso_mass": snappedf(torso_mass, 0.0001),
		"main_color": main_color.to_html(),
		"accent_color": accent_color.to_html(),
		"skin_color": skin_color.to_html(),
		"hair_color": hair_color.to_html(),
		"left_limb_scale": snappedf(left_limb_scale, 0.0001),
		"right_limb_scale": snappedf(right_limb_scale, 0.0001),
		"left_accent_flag": left_accent_flag,
		"right_accent_flag": right_accent_flag,
	}


func _apply_seed_palette() -> void:
	var base_hue := _unit(seed_text, "main_hue")
	var harmony_index := int(floor(_unit(seed_text, "harmony") * 3.0))
	var accent_hue := base_hue
	match harmony_index:
		0:
			accent_hue = fposmod(base_hue + 0.5, 1.0)
		1:
			accent_hue = fposmod(base_hue + 1.0 / 3.0, 1.0)
		_:
			accent_hue = fposmod(base_hue + _range(seed_text, "analogous_offset", 0.06, 0.12), 1.0)

	var main_saturation := _range(seed_text, "main_saturation", 0.42, 0.70)
	var main_value := _range(seed_text, "main_value", 0.48, 0.76)
	var accent_saturation := _range(seed_text, "accent_saturation", 0.48, 0.78)
	var accent_value := _range(seed_text, "accent_value", 0.58, 0.86)

	main_color = Color.from_hsv(base_hue, main_saturation, main_value, 1.0)
	accent_color = Color.from_hsv(accent_hue, accent_saturation, accent_value, 1.0)
	skin_color = Color.from_hsv(_range(seed_text, "skin_hue", 0.055, 0.095), _range(seed_text, "skin_sat", 0.30, 0.46), _range(seed_text, "skin_value", 0.62, 0.86), 1.0)
	hair_color = Color.from_hsv(_range(seed_text, "hair_hue", 0.035, 0.095), _range(seed_text, "hair_sat", 0.35, 0.68), _range(seed_text, "hair_value", 0.16, 0.36), 1.0)


static func _range(seed_text_value: String, salt: String, minimum: float, maximum: float) -> float:
	return lerpf(minimum, maximum, _unit(seed_text_value, salt))


static func _unit(seed_text_value: String, salt: String) -> float:
	var hash_value := _hash_seed("%s:%s" % [seed_text_value, salt])
	return float(hash_value % 100000) / 99999.0


static func _hash_seed(text: String) -> int:
	var hash_value := 2166136261
	for i in range(text.length()):
		hash_value = int(hash_value ^ text.unicode_at(i))
		hash_value = int(hash_value * 16777619) & 0x7fffffff
	return hash_value
