@tool
class_name UniversalLpcFactory

static func instance() -> UniversalLpcFactory:
	if m_instance == null:
		m_instance = UniversalLpcFactory.new()
	return m_instance

static var m_instance :UniversalLpcFactory

var m_metadata_file: String = ""
var m_metadata: Dictionary = {}
var m_texture_cache: Dictionary = {} # <String, Texture2D>

var animation_enum_values: PackedStringArray = []
var expression_enum_values: PackedStringArray = []

var m_default_expression_replacement: Dictionary = {
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

const DEFAULT_EXPRESSION_REPLACEMENT: Dictionary = {
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


func configure(metadata_file: String) -> bool:
	metadata_file = metadata_file.strip_edges()
	if metadata_file == "":
		_clear_state()
		push_error("metadata_file is empty.")
		return false

	if m_metadata_file == metadata_file and not m_metadata.is_empty():
		return true

	var metadata: Dictionary = _load_metadata_json(metadata_file)
	if metadata.is_empty():
		return false

	m_metadata_file = metadata_file
	m_metadata = metadata
	m_texture_cache.clear()
	m_default_expression_replacement = DEFAULT_EXPRESSION_REPLACEMENT.duplicate(true)

	var default_expr_value = m_metadata.get("default_expression_paths", {})
	if typeof(default_expr_value) == TYPE_DICTIONARY and not default_expr_value.is_empty():
		m_default_expression_replacement = default_expr_value.duplicate(true)

	animation_enum_values = _compute_animation_enum_names()
	expression_enum_values = _compute_expression_enum_names()
	return true


func _clear_state() -> void:
	m_metadata_file = ""
	m_metadata = {}
	m_texture_cache.clear()
	animation_enum_values = PackedStringArray([])
	expression_enum_values = PackedStringArray([])


func get_metadata() -> Dictionary:
	return m_metadata


func get_animation_enum_names() -> PackedStringArray:
	if animation_enum_values.is_empty():
		animation_enum_values = _compute_animation_enum_names()
	return animation_enum_values


func get_expression_enum_names() -> PackedStringArray:
	if expression_enum_values.is_empty():
		expression_enum_values = _compute_expression_enum_names()
	return expression_enum_values


func get_default_frame_layout() -> Dictionary:
	var default_frame_info_value = m_metadata.get("default_frame_info", {})
	if typeof(default_frame_info_value) != TYPE_DICTIONARY:
		return {}

	var default_frame_info: Dictionary = default_frame_info_value
	var data_value = default_frame_info.get("data", {})
	if typeof(data_value) != TYPE_DICTIONARY:
		return {}

	return data_value


func get_base_animation_names() -> PackedStringArray:
	return _to_packed_string_array(m_metadata.get("default_animations", []))


func find_definition_by_path_string(path_string: String) -> Dictionary:
	var definitions_value = m_metadata.get("definitions", [])
	if typeof(definitions_value) != TYPE_ARRAY:
		return {}

	for definition_value in definitions_value:
		if typeof(definition_value) != TYPE_DICTIONARY:
			continue

		var definition: Dictionary = definition_value
		var definition_path: String = definition_to_path_string(definition)
		if definition_path == path_string:
			return definition

	return {}


func definition_to_path_string(definition: Dictionary) -> String:
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


func get_texture(texture_path: String) -> Texture2D:
	texture_path = texture_path.strip_edges()
	if texture_path == "":
		return null

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


func clear_texture_cache() -> void:
	m_texture_cache.clear()


func resolve_texture_path(
	selection: Dictionary,
	layer: Dictionary,
	configuration: Dictionary,
	expression_name: String,
	resolve_token_callback: Callable
) -> String:
	var metadata_root_path: String = str(m_metadata.get("target_path", ""))
	var spritesheets_dir: String = str(m_metadata.get("spritesheets_dir", "spritesheets"))
	if metadata_root_path == "":
		return ""

	var spritesheets_root: String = _join_path(metadata_root_path, spritesheets_dir)

	var body_type: String = str(configuration.get("body_type", ""))
	var variant: String = str(selection.get("variant", "")).strip_edges()
	if variant == "":
		return ""

	var resolved_base_path: String = resolve_base_path_from_layer(
		selection,
		body_type,
		layer,
		expression_name,
		resolve_token_callback
	)
	if resolved_base_path == "":
		return ""
	var base_dir: String = _join_path(spritesheets_root, _normalize_relative_dir(resolved_base_path))
	var candidate: String = _join_path(base_dir, "%s.png" % variant).replace(" ", "_")
	if ResourceLoader.exists(candidate):
		return candidate

	return ""


func resolve_base_path_from_layer(
	selection: Dictionary,
	body_type: String,
	layer: Dictionary,
	expression_name: String,
	resolve_token_callback: Callable
) -> String:
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

	base_dir = apply_replace_in_path(selection, base_dir, expression_name, resolve_token_callback)
	base_dir = _normalize_relative_dir(base_dir)

	if base_dir.contains("${"):
		return ""

	return base_dir


func apply_replace_in_path(
	selection: Dictionary,
	template_path: String,
	expression_name: String,
	resolve_token_callback: Callable
) -> String:
	var replace_value = selection.get("replace_in_path", {})
	var resolved: String = template_path

	# Replace head/faces/${head}/<anything>/ with head/faces/${head}/${expression}/
	var expr_regex := RegEx.new()
	if expr_regex.compile("(head/faces/\\$\\{head\\}/)[^/]+") == OK:
		var expr_match := expr_regex.search(resolved)
		if expr_match:
			resolved = resolved.replace(expr_match.get_string(0), expr_match.get_string(1) + "${expression}")

	if typeof(replace_value) != TYPE_DICTIONARY:
		return _normalize_relative_dir(resolved)

	var replace_map: Dictionary = replace_value

	var token_regex := RegEx.new()
	if token_regex.compile("\\$\\{([^}]+)\\}") != OK:
		return _normalize_relative_dir(resolved)

	var matches: Array = token_regex.search_all(resolved)
	for match in matches:
		var token_name: String = match.get_string(1)
		var selected_value: String = ""

		if token_name == "expression":
			selected_value = expression_name
		elif resolve_token_callback.is_valid():
			selected_value = str(resolve_token_callback.call(token_name))

		if selected_value == "":
			selected_value = "none"

		var replacement: String = get_replace_in_path_replacement(replace_map, token_name, selected_value)
		resolved = resolved.replace("${%s}" % token_name, replacement)

	return _normalize_relative_dir(resolved)


func get_replace_in_path_replacement(replace_map: Dictionary, token_name: String, selected_value: String) -> String:
	if not replace_map.has(token_name):
		if token_name == "expression":
			return str(m_default_expression_replacement.get(selected_value, "neutral")).strip_edges()
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


func _compute_animation_enum_names() -> PackedStringArray:
	var out: PackedStringArray = []
	var default_layout: Dictionary = get_default_frame_layout()
	var base_animation_names: PackedStringArray = get_base_animation_names()

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

	return out


func _get_direction_codes_for_animation(direction_count: int) -> PackedStringArray:
	if direction_count <= 1:
		return PackedStringArray(["s"])
	return PackedStringArray(["n", "w", "s", "e"])


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
