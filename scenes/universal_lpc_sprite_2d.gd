@tool
class_name UniversalLpcSprite2D
extends Node2D

@export var animation: int = 0:
	set(value):
		var names: PackedStringArray = _get_animation_names()
		var max_index: int = maxi(0, names.size() - 1)
		animation = clampi(value, 0, max_index)
		_apply_current_animation_to_sprites()

var m_selection_data: Dictionary = {}
var m_metadata_root: Dictionary = {}
var m_sprite_nodes: Array[Sprite2D] = []


func _get_property_list() -> Array:
	var properties: Array = []

	var animation_names: PackedStringArray = _get_animation_names()
	if not animation_names.is_empty():
		properties.append({
			"name": "animation",
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": ",".join(animation_names),
			"usage": PROPERTY_USAGE_EDITOR
		})

	return properties


# Recreate sprites with the selection_data.
func load(selection_data: Dictionary, universal_lpc_metadata_path: String) -> void:
	m_selection_data = selection_data.duplicate(true)
	m_metadata_root = _load_metadata_json(universal_lpc_metadata_path)

	if m_metadata_root.is_empty():
		push_error("Failed to load Universal LPC metadata: %s" % universal_lpc_metadata_path)
		_clear_sprites()
		return

	_clear_sprites()

	var selections = m_selection_data.get("selections", [])
	if typeof(selections) != TYPE_ARRAY:
		push_error("selection_data.selections must be an Array.")
		return

	var sorted_selections: Array = selections.duplicate(true)
	sorted_selections.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var az := _get_selection_zpos(a)
		var bz := _get_selection_zpos(b)
		if not is_equal_approx(az, bz):
			return az < bz

		var ap: int = int(a.get("priority", 999999))
		var bp: int = int(b.get("priority", 999999))
		if ap != bp:
			return ap < bp

		return str(a.get("path_string", "")).to_lower() < str(b.get("path_string", "")).to_lower()
	)

	for selection_value in sorted_selections:
		if typeof(selection_value) != TYPE_DICTIONARY:
			continue

		var selection: Dictionary = selection_value
		var sprite: Sprite2D = _create_sprite_from_selection(selection)
		if sprite == null:
			continue

		add_child(sprite)
		if Engine.is_editor_hint() and get_tree().edited_scene_root != null:
			sprite.owner = get_tree().edited_scene_root

		m_sprite_nodes.append(sprite)

	var names: PackedStringArray = _get_animation_names()
	if not names.is_empty():
		animation = clampi(animation, 0, names.size() - 1)
	else:
		animation = 0

	_apply_current_animation_to_sprites()
	notify_property_list_changed()


func _create_sprite_from_selection(selection: Dictionary) -> Sprite2D:
	var texture_path: String = _resolve_texture_path_from_selection(selection)
	if texture_path == "":
		push_warning("Could not resolve combined texture for selection: %s" % str(selection.get("path_string", "")))
		return null

	var texture: Texture2D = load(texture_path) as Texture2D
	if texture == null:
		push_warning("Failed to load combined texture: %s" % texture_path)
		return null

	var row_rects: Dictionary = _build_animation_row_rects(selection)
	if row_rects.is_empty():
		push_warning("Could not build animation row rects for selection: %s" % str(selection.get("path_string", "")))
		return null

	var sprite := Sprite2D.new()
	sprite.name = str(selection.get("name", str(selection.get("path_string", "sprite"))))
	sprite.texture = texture
	sprite.centered = false
	sprite.position = Vector2.ZERO
	sprite.z_index = int(round(_get_selection_zpos(selection)))
	sprite.region_enabled = true
	sprite.set_meta("row_rects", row_rects)
	sprite.set_meta("selection_data", selection.duplicate(true))

	var current_animation_name: String = _get_current_animation_name()
	var rect: Rect2 = _get_animation_row_rect(row_rects, current_animation_name)
	if rect.size.x <= 0 or rect.size.y <= 0:
		rect = _get_first_animation_row_rect(row_rects)

	sprite.region_rect = rect
	return sprite


func _apply_current_animation_to_sprites() -> void:
	var animation_name: String = _get_current_animation_name()
	for sprite in m_sprite_nodes:
		if not is_instance_valid(sprite):
			continue
		if not sprite.has_meta("row_rects"):
			continue

		var row_rects_value = sprite.get_meta("row_rects")
		if typeof(row_rects_value) != TYPE_DICTIONARY:
			continue

		var row_rects: Dictionary = row_rects_value
		var rect: Rect2 = _get_animation_row_rect(row_rects, animation_name)
		if rect.size.x <= 0 or rect.size.y <= 0:
			rect = _get_first_animation_row_rect(row_rects)

		if rect.size.x > 0 and rect.size.y > 0:
			sprite.region_enabled = true
			sprite.region_rect = rect


func _get_animation_row_rect(row_rects: Dictionary, animation_name: String) -> Rect2:
	if row_rects.has(animation_name):
		var value = row_rects[animation_name]
		if value is Rect2:
			return value
	return Rect2()


func _get_first_animation_row_rect(row_rects: Dictionary) -> Rect2:
	for animation_name in _get_animation_names():
		var rect: Rect2 = _get_animation_row_rect(row_rects, animation_name)
		if rect.size.x > 0 and rect.size.y > 0:
			return rect
	return Rect2()


func _build_animation_row_rects(selection: Dictionary) -> Dictionary:
	var rects: Dictionary = {}
	var frame_info_data: Dictionary = _get_selection_frame_info_data(selection)
	var default_layout: Dictionary = _get_default_frame_layout_from_metadata()

	var y_offset: float = 0.0
	for animation_name in _get_animation_names():
		var size: Vector2i = _infer_animation_sheet_size(animation_name, frame_info_data, default_layout)
		var rect := Rect2(0, y_offset, float(size.x), float(size.y))
		rects[animation_name] = rect
		y_offset += float(size.y)

	return rects


func _get_selection_frame_info_data(selection: Dictionary) -> Dictionary:
	var frame_info_value = selection.get("frame_info", {})
	if typeof(frame_info_value) != TYPE_DICTIONARY:
		return {}

	var frame_info: Dictionary = frame_info_value
	var data_value = frame_info.get("data", {})
	if typeof(data_value) != TYPE_DICTIONARY:
		return {}

	return data_value


func _get_default_frame_layout_from_metadata() -> Dictionary:
	var default_frame_info_value = m_metadata_root.get("default_frame_info", {})
	if typeof(default_frame_info_value) != TYPE_DICTIONARY:
		return {}

	var default_frame_info: Dictionary = default_frame_info_value
	var data_value = default_frame_info.get("data", {})
	if typeof(data_value) != TYPE_DICTIONARY:
		return {}

	return data_value


func _infer_animation_sheet_size(animation_name: String, frame_info_data: Dictionary, default_layout: Dictionary) -> Vector2i:
	var layout: Dictionary = {}

	if frame_info_data.has(animation_name) and typeof(frame_info_data[animation_name]) == TYPE_DICTIONARY:
		layout = (frame_info_data[animation_name] as Dictionary).duplicate(true)
	elif default_layout.has(animation_name) and typeof(default_layout[animation_name]) == TYPE_DICTIONARY:
		layout = (default_layout[animation_name] as Dictionary).duplicate(true)

	if layout.is_empty():
		return Vector2i(1, 1)

	var frame_width: int = int(layout.get("frame_width", 64))
	var frame_height: int = int(layout.get("frame_height", 64))
	var directions: int = int(layout.get("directions", 1))
	var frames_per_direction: int = int(layout.get("frames_per_direction", 1))

	return Vector2i(maxi(1, frame_width * frames_per_direction), maxi(1, frame_height * directions))


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
		var data = layer.get("data", {})
		if typeof(data) != TYPE_DICTIONARY:
			continue

		var layer_data: Dictionary = data
		if layer_data.has("zPos"):
			var z: float = float(layer_data.get("zPos", 0.0))
			if not found or z > highest_z:
				highest_z = z
				found = true

	return highest_z if found else 0.0


func _resolve_texture_path_from_selection(selection: Dictionary) -> String:
	var metadata_root_path: String = str(m_metadata_root.get("target_path", ""))
	var spritesheets_dir: String = str(m_metadata_root.get("spritesheets_dir", "spritesheets"))
	if metadata_root_path == "":
		return ""

	var spritesheets_root: String = _join_path(metadata_root_path, spritesheets_dir)

	var body_type: String = str(m_selection_data.get("body_type", ""))
	var variant: String = str(selection.get("variant", ""))
	var layers = selection.get("layers", [])

	if typeof(layers) != TYPE_ARRAY or variant == "":
		return ""

	var resolved_base_paths: PackedStringArray = _resolve_base_paths_from_selection_layers(selection, body_type, layers)
	if resolved_base_paths.is_empty():
		return ""

	for base_path in resolved_base_paths:
		var base_dir: String = _join_path(spritesheets_root, _normalize_relative_dir(base_path))
		var candidate: String = _join_path(base_dir, "%s.png" % variant)
		if ResourceLoader.exists(candidate):
			return candidate

	return ""


func _resolve_base_paths_from_selection_layers(selection: Dictionary, body_type: String, layers: Array) -> PackedStringArray:
	var out: PackedStringArray = []

	for layer_value in layers:
		if typeof(layer_value) != TYPE_DICTIONARY:
			continue

		var layer: Dictionary = layer_value
		var data = layer.get("data", {})
		if typeof(data) != TYPE_DICTIONARY:
			continue

		var layer_data: Dictionary = data
		var base_dir: String = ""

		if body_type != "" and layer_data.has(body_type):
			base_dir = str(layer_data.get(body_type, ""))
		elif layer_data.has("default"):
			base_dir = str(layer_data.get("default", ""))

		if base_dir == "":
			continue

		base_dir = _apply_replace_in_path(selection, base_dir)
		base_dir = _normalize_relative_dir(base_dir)

		if base_dir != "" and not out.has(base_dir):
			out.append(base_dir)

	return out


func _apply_replace_in_path(selection: Dictionary, template_path: String) -> String:
	var selection_replace_map = selection.get("replace_in_path", {})
	if typeof(selection_replace_map) != TYPE_DICTIONARY:
		return template_path

	var resolved: String = template_path
	var replace_map: Dictionary = selection_replace_map

	for token in replace_map.keys():
		var token_name: String = str(token)
		var token_dict_value = replace_map[token]
		if typeof(token_dict_value) != TYPE_DICTIONARY:
			continue

		var token_dict: Dictionary = token_dict_value
		var selected_value: String = _get_selected_value_for_token(token_name)
		if selected_value == "":
			selected_value = "none"

		var replacement: String = str(token_dict.get(selected_value, token_dict.get("none", "")))
		resolved = resolved.replace("${%s}" % token_name, replacement)

	return resolved


func _get_selected_value_for_token(token_name: String) -> String:
	var selections = m_selection_data.get("selections", [])
	if typeof(selections) != TYPE_ARRAY:
		return ""

	for selection_value in selections:
		if typeof(selection_value) != TYPE_DICTIONARY:
			continue

		var selection: Dictionary = selection_value
		var type_name: String = str(selection.get("type_name", "")).strip_edges()
		if type_name != token_name:
			continue

		var variant: String = str(selection.get("variant", "")).strip_edges()
		if variant != "":
			return variant

		var name: String = str(selection.get("name", "")).strip_edges()
		if name != "":
			return name

	return ""


func _get_animation_names() -> PackedStringArray:
	return _to_packed_string_array(m_metadata_root.get("default_animations", []))


func _get_current_animation_name() -> String:
	var names: PackedStringArray = _get_animation_names()
	if names.is_empty():
		return ""
	var idx: int = clampi(animation, 0, names.size() - 1)
	return names[idx]


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
		if child is Sprite2D:
			child.queue_free()


func _normalize_relative_dir(path: String) -> String:
	var normalized: String = path.strip_edges().replace("\\", "/")
	while normalized.begins_with("/"):
		normalized = normalized.substr(1)
	while normalized.ends_with("/"):
		normalized = normalized.left(normalized.length() - 1)
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
	if Engine.is_editor_hint():
		notify_property_list_changed()


func _process(_delta: float) -> void:
	pass
