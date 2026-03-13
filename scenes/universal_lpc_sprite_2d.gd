@tool
class_name UniversalLpcSprite2D
extends Node2D

var animation_enum_values: PackedStringArray = []
var expression_enum_values: PackedStringArray = []

@export_storage var animation: int = 0:
	set(value):
		var names: PackedStringArray = _get_animation_enum_names()

		if names.is_empty():
			animation = value
			return

		var max_index: int = names.size() - 1
		animation = clampi(value, 0, max_index)
		_apply_current_animation_to_sprites()

var animation_name: String:
	get():
		var names: PackedStringArray = _get_animation_enum_names()
		if names.is_empty():
			return ""
		return names[clampi(animation, 0, names.size() - 1)]

@export_storage var m_expression: int = 0

var expression_name: String:
	get():
		var names: PackedStringArray = _get_expression_enum_names()
		if names.is_empty():
			return ""
		return names[clampi(m_expression, 0, names.size() - 1)]

var is_playing: bool = true:
	set(value):
		is_playing = value
		_apply_play_state_to_sprites()

@export_storage var m_configuration: Dictionary = {}
@export_storage var m_metadata_path: String = ""
var m_metadata: Dictionary = {}

var m_sprite_nodes: Array[AnimatedSprite2D] = []
var m_texture_cache: Dictionary = {} # <String texture_path, Texture2D>

var m_default_expression_replacement :Dictionary = {
	"Angry": "anger",
	"Angry_Alt": "anger",
	"Blush": "blush",
	"Closed_Eyes": "closed",
	"Closing_Eyes": "closing",
	"Happy": "happy",
	"Happy_Alt": "happy",
	"Looking_Left": "look_l",
	"Looking_Right": "look_r",
	"Neutral": "neutral",
	"Rolling_Eyes": "eyeroll",
	"Sad": "sad",
	"Sad_Alt": "sad",
	"Shame": "shame",
	"Shock": "shock",
	"none": "default"
}

func _get_property_list() -> Array:
	var properties: Array = []

	properties.append({
		"name": "is_playing",
		"type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_EDITOR
	})

	var expression_names: PackedStringArray = _get_expression_enum_names()
	if not expression_names.is_empty():
		properties.append({
			"name": "expression",
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": ",".join(expression_names),
			"usage": PROPERTY_USAGE_EDITOR
		})

	var animation_names: PackedStringArray = _get_animation_enum_names()
	if not animation_names.is_empty():
		properties.append({
			"name": "animation",
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": ",".join(animation_names),
			"usage": PROPERTY_USAGE_EDITOR
		})

	return properties


func _get(property: StringName):
	if property == "animation":
		return animation

	if property == "expression":
		return m_expression

	if property == "is_playing":
		return is_playing

	return null


func _set(property: StringName, value) -> bool:
	if property == "animation":
		var names: PackedStringArray = _get_animation_enum_names()
		if names.is_empty():
			animation = 0
			return true

		var index: int = clampi(int(value), 0, names.size() - 1)
		animation = index
		_apply_current_animation_to_sprites()
		return true

	if property == "expression":
		var names: PackedStringArray = _get_expression_enum_names()
		if names.is_empty():
			m_expression = 0
			return true

		var index: int = clampi(int(value), 0, names.size() - 1)
		m_expression = index
		_apply_expression_to_sprites()
		return true

	if property == "is_playing":
		is_playing = bool(value)
		return true

	return false


func load(configuration_data: Dictionary, universal_lpc_metadata_file: String) -> void:
	m_metadata_path = universal_lpc_metadata_file
	m_configuration = configuration_data.duplicate(true)
	_reload()


func _reload() -> void:
	_clear_sprites()
	_clear_texture_cache()

	m_metadata = _load_metadata_json(m_metadata_path)
	if m_metadata.is_empty():
		push_error("Failed to load Universal LPC metadata: %s" % m_metadata_path)
		return
	m_default_expression_replacement = m_metadata.get("default_expression_paths", {})
	_restore_expression_selection()

	var selections_value = m_configuration.get("selections", {})
	if typeof(selections_value) != TYPE_DICTIONARY:
		push_error("configuration_data.selections must be a Dictionary of <path string>: <variant>.")
		return

	var selections: Dictionary = selections_value
	var sprite_entries: Array[Dictionary] = []

	for path_key in selections.keys():
		var path_string: String = str(path_key).strip_edges()
		if path_string == "":
			continue

		var variant: String = str(selections[path_key]).strip_edges()
		if variant == "":
			continue

		var configured_selection: Dictionary = {
			"path_string": path_string,
			"variant": variant
		}

		var resolved_selection: Dictionary = _resolve_selection_definition(configured_selection)
		if resolved_selection.is_empty():
			continue

		var layers = resolved_selection.get("layers", [])
		if typeof(layers) != TYPE_ARRAY:
			continue

		for layer_index in range(layers.size()):
			var layer_value = layers[layer_index]
			if typeof(layer_value) != TYPE_DICTIONARY:
				continue

			var layer: Dictionary = layer_value
			var z_pos: float = _get_layer_zpos(layer)
			var priority: int = int(resolved_selection.get("priority", 999999))

			sprite_entries.append({
				"selection": resolved_selection,
				"layer": layer,
				"layer_index": layer_index,
				"z_pos": z_pos,
				"priority": priority,
				"path_string": str(resolved_selection.get("path_string", "")),
				"name": str(resolved_selection.get("name", ""))
			})

	sprite_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var az := float(a.get("z_pos", 0.0))
		var bz := float(b.get("z_pos", 0.0))
		if not is_equal_approx(az, bz):
			return az < bz

		var ap: int = int(a.get("priority", 999999))
		var bp: int = int(b.get("priority", 999999))
		if ap != bp:
			return ap < bp

		var an: String = str(a.get("name", "")).to_lower()
		var bn: String = str(b.get("name", "")).to_lower()
		if an != bn:
			return an < bn

		return str(a.get("path_string", "")).to_lower() < str(b.get("path_string", "")).to_lower()
	)

	for entry_value in sprite_entries:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue

		var entry: Dictionary = entry_value
		var selection: Dictionary = entry.get("selection", {})
		var layer: Dictionary = entry.get("layer", {})
		var layer_index: int = int(entry.get("layer_index", 0))

		var sprite: AnimatedSprite2D = _create_sprite_from_selection_layer(selection, layer, layer_index)
		if sprite == null:
			continue

		add_child(sprite)
		m_sprite_nodes.append(sprite)

	_restore_animation_selection()
	_apply_current_animation_to_sprites()
	#_prewarm_expression_texture_cache()
	notify_property_list_changed()


func _resolve_selection_definition(configured_selection: Dictionary) -> Dictionary:
	var path_string: String = str(configured_selection.get("path_string", "")).strip_edges()
	if path_string == "":
		return {}

	var definition: Dictionary = _find_definition_by_path_string(path_string)
	if definition.is_empty():
		push_warning("Could not find definition for selection path: %s" % path_string)
		return {}

	var resolved: Dictionary = definition.duplicate(true)
	resolved["path_string"] = path_string
	resolved["variant"] = str(configured_selection.get("variant", "")).strip_edges()
	return resolved


func _find_definition_by_path_string(path_string: String) -> Dictionary:
	var definitions_value = m_metadata.get("definitions", [])
	if typeof(definitions_value) != TYPE_ARRAY:
		return {}

	for definition_value in definitions_value:
		if typeof(definition_value) != TYPE_DICTIONARY:
			continue

		var definition: Dictionary = definition_value
		var definition_path: String = _definition_to_path_string(definition)
		if definition_path == path_string:
			return definition

	return {}


func _definition_to_path_string(definition: Dictionary) -> String:
	var json_file: String = str(definition.get("json_file", "")).strip_edges()
	if json_file == "":
		return ""

	var parts: Array[String] = []

	var dir_path: String = json_file.get_base_dir()
	if dir_path != "" and dir_path != ".":
		var dir_parts: PackedStringArray = dir_path.split("/")
		for part in dir_parts:
			var clean_part: String = String(part).strip_edges()
			if clean_part != "" and clean_part != ".":
				parts.append(clean_part)

	var leaf_name: String = json_file.get_file().get_basename().strip_edges()
	if leaf_name != "":
		parts.append(leaf_name)

	return "/".join(parts)


func _restore_animation_selection() -> void:
	var names: PackedStringArray = _compute_animation_enum_names()
	animation_enum_values = names

	if names.is_empty():
		animation = 0
		return

	if animation >= 0 and animation < names.size():
		return

	animation = 0


func _restore_expression_selection() -> void:
	var names: PackedStringArray = _compute_expression_enum_names()
	expression_enum_values = names

	if names.is_empty():
		m_expression = 0
		return

	if m_expression >= 0 and m_expression < names.size():
		return

	m_expression = 0


func _create_sprite_from_selection_layer(selection: Dictionary, layer: Dictionary, layer_index: int) -> AnimatedSprite2D:
	var texture: Texture2D = _get_texture_for_selection_layer(selection, layer)
	if texture == null:
		push_warning("Failed to resolve combined texture for selection layer: %s [layer %d]" % [str(selection.get("path_string", "")), layer_index])
		return null

	var sprite_frames: SpriteFrames = _build_sprite_frames(selection, texture)
	if sprite_frames == null:
		push_warning("Failed to build SpriteFrames for selection layer: %s [layer %d]" % [str(selection.get("path_string", "")), layer_index])
		return null

	var sprite := AnimatedSprite2D.new()
	sprite.name = "%s_layer_%d" % [str(selection.get("name", str(selection.get("path_string", "sprite")))), layer_index]
	sprite.sprite_frames = sprite_frames
	sprite.position = Vector2.ZERO
	sprite.z_index = int(round(_get_layer_zpos(layer)))
	sprite.centered = false
	sprite.set_meta("selection_data", selection.duplicate(true))
	sprite.set_meta("layer_data", layer.duplicate(true))
	sprite.set_meta("layer_index", layer_index)
	sprite.set_meta("texture_path", _resolve_texture_path_from_selection_layer(selection, layer))

	var current_name: String = animation_name
	if current_name != "" and sprite_frames.has_animation(current_name):
		sprite.animation = current_name
	else:
		var all_names: PackedStringArray = sprite_frames.get_animation_names()
		if not all_names.is_empty():
			sprite.animation = all_names[0]

	_apply_animation_to_sprite(sprite)
	return sprite


func _build_sprite_frames(_selection: Dictionary, texture: Texture2D) -> SpriteFrames:
	var default_layout: Dictionary = _get_default_frame_layout_from_metadata()
	if default_layout.is_empty():
		return null

	var sprite_frames := SpriteFrames.new()
	var sheet_image: Image = texture.get_image()
	if sheet_image == null or sheet_image.is_empty():
		return null

	var animation_names: PackedStringArray = _get_base_animation_names()
	for base_animation_name in animation_names:
		var config_value = default_layout.get(base_animation_name, null)
		if typeof(config_value) != TYPE_DICTIONARY:
			continue

		var config: Dictionary = config_value
		var frame_width: int = int(config.get("frame_width", 64))
		var frame_height: int = int(config.get("frame_height", 64))
		var y_pos: int = int(config.get("y", -1))
		var directions: int = int(config.get("directions", 4))
		var frames_value = config.get("frames", [])
		var frame_cycle: Array = []

		if typeof(frames_value) == TYPE_ARRAY:
			frame_cycle = (frames_value as Array).duplicate()
		elif typeof(frames_value) == TYPE_PACKED_INT32_ARRAY:
			for item in frames_value:
				frame_cycle.append(item)

		if frame_width <= 0 or frame_height <= 0 or y_pos < 0 or frame_cycle.is_empty():
			continue

		var dir_codes: PackedStringArray = _get_direction_codes_for_animation(directions)
		for dir_index in range(dir_codes.size()):
			var dir_code: String = dir_codes[dir_index]
			var anim_key: String = "%s-%s" % [base_animation_name, dir_code]

			if not sprite_frames.has_animation(anim_key):
				sprite_frames.add_animation(anim_key)

			sprite_frames.set_animation_loop(anim_key, true)
			sprite_frames.set_animation_speed(anim_key, 8.0)

			var row_y: int = y_pos + dir_index * frame_height
			for frame_number in frame_cycle:
				var frame_index: int = int(frame_number)
				var region := Rect2i(frame_index * frame_width, row_y, frame_width, frame_height)
				if region.position.x < 0 or region.position.y < 0:
					continue
				if region.end.x > sheet_image.get_width() or region.end.y > sheet_image.get_height():
					continue

				var atlas := AtlasTexture.new()
				atlas.atlas = texture
				atlas.region = Rect2(region)

				sprite_frames.add_frame(anim_key, atlas)

	return sprite_frames


func _apply_play_state_to_sprites() -> void:
	for sprite in m_sprite_nodes:
		if not is_instance_valid(sprite):
			continue

		if is_playing:
			if sprite.sprite_frames != null and sprite.animation != StringName(""):
				sprite.play()
		else:
			sprite.stop()


func _apply_current_animation_to_sprites() -> void:
	for sprite in m_sprite_nodes:
		_apply_animation_to_sprite(sprite)


func _apply_animation_to_sprite(sprite: AnimatedSprite2D) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return

	var current_name: String = animation_name
	if current_name != "" and sprite.sprite_frames.has_animation(current_name):
		sprite.animation = current_name
	elif not sprite.sprite_frames.get_animation_names().is_empty():
		sprite.animation = sprite.sprite_frames.get_animation_names()[0]

	if is_playing:
		sprite.play()
	else:
		sprite.stop()


func _apply_expression_to_sprites() -> void:
	for sprite in m_sprite_nodes:
		if not is_instance_valid(sprite):
			continue

		var selection = sprite.get_meta("selection_data", {})
		var layer = sprite.get_meta("layer_data", {})

		if typeof(selection) != TYPE_DICTIONARY or typeof(layer) != TYPE_DICTIONARY:
			continue

		var was_playing: bool = sprite.is_playing()
		var old_animation: StringName = sprite.animation
		var old_frame: int = sprite.frame
		var old_progress: float = sprite.frame_progress

		var texture: Texture2D = _get_texture_for_selection_layer(selection, layer)
		if texture == null:
			continue

		var sprite_frames: SpriteFrames = _build_sprite_frames(selection, texture)
		if sprite_frames == null:
			continue

		sprite.sprite_frames = sprite_frames
		sprite.set_meta("texture_path", _resolve_texture_path_from_selection_layer(selection, layer))

		var target_animation: String = animation_name
		if target_animation == "":
			target_animation = str(old_animation)

		if target_animation != "" and sprite_frames.has_animation(target_animation):
			sprite.animation = target_animation
		else:
			var all_names: PackedStringArray = sprite_frames.get_animation_names()
			if not all_names.is_empty():
				sprite.animation = all_names[0]

		var frame_count: int = sprite_frames.get_frame_count(sprite.animation)
		if frame_count > 0:
			sprite.frame = clampi(old_frame, 0, frame_count - 1)
			sprite.frame_progress = old_progress

		if is_playing and was_playing:
			sprite.play()
		else:
			sprite.stop()


func _prewarm_expression_texture_cache() -> void:
	var expression_names: PackedStringArray = _get_expression_enum_names()
	if expression_names.is_empty():
		return

	var original_expression: int = m_expression

	for expr_index in range(expression_names.size()):
		m_expression = expr_index

		for sprite in m_sprite_nodes:
			if not is_instance_valid(sprite):
				continue

			var selection = sprite.get_meta("selection_data", {})
			var layer = sprite.get_meta("layer_data", {})
			if typeof(selection) != TYPE_DICTIONARY or typeof(layer) != TYPE_DICTIONARY:
				continue

			var texture_path: String = _resolve_texture_path_from_selection_layer(selection, layer)
			if texture_path != "":
				_get_cached_texture(texture_path)

	m_expression = original_expression


func _get_direction_codes_for_animation(direction_count: int) -> PackedStringArray:
	if direction_count <= 1:
		return PackedStringArray(["s"])
	return PackedStringArray(["n", "w", "s", "e"])


func _get_selection_zpos(selection: Dictionary) -> float:
	var layers = selection.get("layers", [])
	if typeof(layers) != TYPE_ARRAY:
		return 0.0

	var highest_z: float = 0.0
	var found := false

	for layer_value in layers:
		if typeof(layer_value) != TYPE_DICTIONARY:
			continue

		var layer: Dictionary = layer_value
		var z: float = _get_layer_zpos(layer)
		if not found or z > highest_z:
			highest_z = z
			found = true

	return highest_z if found else 0.0


func _get_layer_zpos(layer: Dictionary) -> float:
	var data = layer.get("data", {})
	if typeof(data) != TYPE_DICTIONARY:
		return 0.0

	var layer_data: Dictionary = data
	if layer_data.has("zPos"):
		return float(layer_data.get("zPos", 0.0))

	return 0.0


func _get_texture_for_selection_layer(selection: Dictionary, layer: Dictionary) -> Texture2D:
	var texture_path: String = _resolve_texture_path_from_selection_layer(selection, layer)
	#print(texture_path)
	if texture_path == "":
		return null

	return _get_cached_texture(texture_path)


func _get_cached_texture(texture_path: String) -> Texture2D:
	#print("_get_cached_texture: ", texture_path)
	if texture_path == "":
		return null

	#print(texture_path)
	if m_texture_cache.has(texture_path):
		var cached = m_texture_cache[texture_path]
		if cached is Texture2D:
			return cached

	var texture: Texture2D = load(texture_path) as Texture2D
	if texture == null:
		push_warning("Failed to load combined texture: %s" % texture_path)
		return null

	m_texture_cache[texture_path] = texture
	return texture


func _clear_texture_cache() -> void:
	m_texture_cache.clear()


func _resolve_texture_path_from_selection_layer(selection: Dictionary, layer: Dictionary) -> String:
	var metadata_root_path: String = str(m_metadata.get("target_path", ""))
	var spritesheets_dir: String = str(m_metadata.get("spritesheets_dir", "spritesheets"))
	if metadata_root_path == "":
		return ""

	var spritesheets_root: String = _join_path(metadata_root_path, spritesheets_dir)

	var body_type: String = str(m_configuration.get("body_type", ""))
	var variant: String = str(selection.get("variant", "")).strip_edges()
	if variant == "":
		return ""

	var resolved_base_path: String = _resolve_base_path_from_layer(selection, body_type, layer)
	if resolved_base_path == "":
		return ""

	var base_dir: String = _join_path(spritesheets_root, _normalize_relative_dir(resolved_base_path))
	var candidate: String = _join_path(base_dir, "%s.png" % variant)
	#print("_resolve_texture_path_from_selection_layer: ", candidate)
	if ResourceLoader.exists(candidate):
		return candidate

	return ""


func _resolve_base_path_from_layer(selection: Dictionary, body_type: String, layer: Dictionary) -> String:
	if typeof(layer) != TYPE_DICTIONARY:
		return ""

	var data = layer.get("data", {})
	if typeof(data) != TYPE_DICTIONARY:
		return ""

	var layer_data: Dictionary = data
	var base_dir: String = ""

	if body_type != "" and layer_data.has(body_type):
		base_dir = str(layer_data.get(body_type, ""))
	elif layer_data.has("default"):
		base_dir = str(layer_data.get("default", ""))

	if base_dir == "":
		return ""

	base_dir = _apply_replace_in_path(selection, base_dir)
	base_dir = _normalize_relative_dir(base_dir)

	if base_dir.contains("${"):
		return ""

	return base_dir


func _resolve_base_paths_from_selection_layers(selection: Dictionary, body_type: String, layers: Array) -> PackedStringArray:
	var out: PackedStringArray = []

	for layer_value in layers:
		if typeof(layer_value) != TYPE_DICTIONARY:
			continue

		var layer: Dictionary = layer_value
		var base_dir: String = _resolve_base_path_from_layer(selection, body_type, layer)
		if base_dir != "" and not out.has(base_dir):
			out.append(base_dir)

	return out

func _apply_replace_in_path(selection: Dictionary, template_path: String) -> String:
	var replace_value = selection.get("replace_in_path", {})
	var resolved: String = template_path

	# Replace head expression folder with ${expression}
	var expr_regex := RegEx.new()
	if expr_regex.compile("(head/faces/\\$\\{head\\}/)[^/]+") == OK:
		var match := expr_regex.search(resolved)
		if match:
			resolved = resolved.replace(match.get_string(0), match.get_string(1) + "${expression}")
			

	if typeof(replace_value) != TYPE_DICTIONARY:
		return _normalize_relative_dir(resolved)

	var replace_map: Dictionary = replace_value

	var token_regex := RegEx.new()
	if token_regex.compile("\\$\\{([^}]+)\\}") != OK:
		return _normalize_relative_dir(resolved)

	var matches: Array = token_regex.search_all(resolved)
	
	for match in matches:
		var token_name: String = match.get_string(1)
		var selected_value: String = _get_selected_value_for_token(token_name)
		if selected_value == "":
			selected_value = "none"
		
		var replacement: String = _get_replace_in_path_replacement(replace_map, token_name, selected_value)
		resolved = resolved.replace("${%s}" % token_name, replacement)
	return _normalize_relative_dir(resolved)


func _get_replace_in_path_replacement(replace_map: Dictionary, token_name: String, selected_value: String) -> String:
	if not replace_map.has(token_name):
		if token_name == "expression":
			return m_default_expression_replacement.get(selected_value, "neutral")
		return ""

	var token_value = replace_map[token_name]
	if typeof(token_value) != TYPE_DICTIONARY:
		return ""

	selected_value = selected_value.to_lower()

	var token_dict: Dictionary = token_value
	for key in token_dict.keys():
		var key_1: String = str(key).to_lower()
		if selected_value == key_1:
			return str(token_dict[key]).strip_edges()

		var key_2: String = key_1.replace("_", " ")
		if selected_value == key_2:
			return str(token_dict[key]).strip_edges()

	if token_dict.has("none"):
		return str(token_dict["none"]).strip_edges()

	return ""


func _get_selected_value_for_token(token_name: String) -> String:
	if token_name == "expression":
		return expression_name

	var selections_value = m_configuration.get("selections", {})
	if typeof(selections_value) != TYPE_DICTIONARY:
		return ""

	var selections: Dictionary = selections_value
	for path_key in selections.keys():
		var path_string: String = str(path_key).strip_edges()
		if path_string == "":
			continue

		var configured_selection: Dictionary = {
			"path_string": path_string,
			"variant": str(selections[path_key]).strip_edges()
		}

		var resolved_selection: Dictionary = _resolve_selection_definition(configured_selection)
		if resolved_selection.is_empty():
			continue

		var type_name: String = str(resolved_selection.get("type_name", "")).strip_edges()
		if type_name != token_name:
			continue

		var resolved_name: String = str(resolved_selection.get("name", "")).strip_edges()
		if resolved_name != "":
			return resolved_name

		var variant: String = str(resolved_selection.get("variant", "")).strip_edges()
		if variant != "":
			return variant

	return ""


func _get_default_frame_layout_from_metadata() -> Dictionary:
	var default_frame_info_value = m_metadata.get("default_frame_info", {})
	if typeof(default_frame_info_value) != TYPE_DICTIONARY:
		return {}

	var default_frame_info: Dictionary = default_frame_info_value
	var data_value = default_frame_info.get("data", {})
	if typeof(data_value) != TYPE_DICTIONARY:
		return {}

	return data_value


func _get_base_animation_names() -> PackedStringArray:
	return _to_packed_string_array(m_metadata.get("default_animations", []))


func _get_animation_enum_names() -> PackedStringArray:
	if !animation_enum_values.is_empty():
		return animation_enum_values
	return _compute_animation_enum_names()


func _compute_animation_enum_names() -> PackedStringArray:
	var out: PackedStringArray = []
	var default_layout: Dictionary = _get_default_frame_layout_from_metadata()
	var base_animation_names: PackedStringArray = _get_base_animation_names()

	for base_name in base_animation_names:
		var config_value = default_layout.get(base_name, null)
		if typeof(config_value) != TYPE_DICTIONARY:
			continue

		var config: Dictionary = config_value
		var direction_count: int = int(config.get("directions", 4))
		var dir_codes: PackedStringArray = _get_direction_codes_for_animation(direction_count)

		for dir_code in dir_codes:
			out.append("%s-%s" % [base_name, dir_code])

	return out


func _get_expression_enum_names() -> PackedStringArray:
	if !expression_enum_values.is_empty():
		return expression_enum_values
	return _compute_expression_enum_names()


func _compute_expression_enum_names() -> PackedStringArray:
	var out: PackedStringArray = []
	var definitions_value = m_metadata.get("definitions", [])
	if typeof(definitions_value) != TYPE_ARRAY:
		return out

	for definition_value in definitions_value:
		if typeof(definition_value) != TYPE_DICTIONARY:
			continue

		var definition: Dictionary = definition_value
		var replace_in_path_value = definition.get("replace_in_path", {})
		if typeof(replace_in_path_value) != TYPE_DICTIONARY:
			continue

		var replace_in_path: Dictionary = replace_in_path_value
		if not replace_in_path.has("expression"):
			continue

		var expression_map_value = replace_in_path.get("expression", {})
		if typeof(expression_map_value) != TYPE_DICTIONARY:
			continue

		var expression_map: Dictionary = expression_map_value
		for key in expression_map.keys():
			var expression_key: String = str(key).strip_edges()
			if expression_key != "" and not out.has(expression_key):
				out.append(expression_key)
		break

	if out.is_empty():
		out.append("none")

	expression_enum_values = out
	return out


func _load_metadata_json(universal_lpc_metadata_path: String) -> Dictionary:
	if universal_lpc_metadata_path.strip_edges() == "":
		push_error("universal_lpc_metadata_path is empty.")
		return {}

	if not FileAccess.file_exists(universal_lpc_metadata_path):
		push_error("Metadata JSON not found: %s" % universal_lpc_metadata_path)
		return {}

	var text: String = FileAccess.get_file_as_string(universal_lpc_metadata_path)
	if text.is_empty():
		push_error("Metadata JSON is empty: %s" % universal_lpc_metadata_path)
		return {}

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("Failed to parse metadata JSON: %s" % universal_lpc_metadata_path)
		return {}

	if typeof(json.data) != TYPE_DICTIONARY:
		push_error("Metadata JSON root must be a Dictionary.")
		return {}

	return json.data as Dictionary


func _clear_sprites() -> void:
	for sprite in m_sprite_nodes:
		if is_instance_valid(sprite):
			sprite.queue_free()
	m_sprite_nodes.clear()

	for child in get_children():
		if child is AnimatedSprite2D:
			child.queue_free()


func _normalize_relative_dir(path: String) -> String:
	var normalized: String = path.strip_edges().replace("\\", "/")
	while normalized.begins_with("/"):
		normalized = normalized.substr(1)
	while normalized.ends_with("/"):
		normalized = normalized.left(normalized.length() - 1)
	while normalized.find("//") != -1:
		normalized = normalized.replace("//", "/")
	return normalized


func _to_packed_string_array(value) -> PackedStringArray:
	var out: PackedStringArray = []

	match typeof(value):
		TYPE_STRING:
			if value != "":
				out.append(value)
		TYPE_ARRAY:
			for item in value:
				if typeof(item) == TYPE_STRING and item != "":
					out.append(item)
		TYPE_PACKED_STRING_ARRAY:
			for item in value:
				if item != "":
					out.append(item)

	return out


func _join_path(a: String, b: String) -> String:
	if a.ends_with("/"):
		return a + b
	return a + "/" + b


func _ready() -> void:
	if m_metadata_path.strip_edges() != "":
		_reload()

	if Engine.is_editor_hint():
		notify_property_list_changed()
	else:
		_apply_current_animation_to_sprites()


func _process(_delta: float) -> void:
	pass
