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
	var animation_entries: Array[Dictionary] = _resolve_texture_paths_from_selection(selection)
	if animation_entries.is_empty():
		push_warning("Could not resolve animation textures for selection: %s" % str(selection.get("path_string", "")))
		return null

	var current_animation_name: String = _get_current_animation_name()
	var texture: Texture2D = _get_texture_for_animation(animation_entries, current_animation_name)
	if texture == null:
		texture = animation_entries[0].get("texture", null) as Texture2D
	if texture == null:
		return null

	var sprite := Sprite2D.new()
	sprite.name = str(selection.get("name", str(selection.get("path_string", "sprite"))))
	sprite.texture = texture
	sprite.centered = false
	sprite.position = Vector2.ZERO
	sprite.z_index = int(round(_get_selection_zpos(selection)))
	sprite.set_meta("animation_entries", animation_entries)
	sprite.set_meta("selection_data", selection.duplicate(true))

	var frame_info: Dictionary = selection.get("frame_info", {})
	var frame_data: Dictionary = frame_info.get("data", {}) if typeof(frame_info) == TYPE_DICTIONARY else {}

	var anim_key: String = _get_frame_info_key(selection)
	if frame_data.has(anim_key):
		var anim_info = frame_data[anim_key]
		if typeof(anim_info) == TYPE_DICTIONARY:
			var anim_dict: Dictionary = anim_info
			var frame_width: int = int(anim_dict.get("frame_width", 0))
			var frame_height: int = int(anim_dict.get("frame_height", 0))
			if frame_width > 0 and frame_height > 0:
				sprite.region_enabled = true
				sprite.region_rect = Rect2(0, 0, frame_width, frame_height)

	return sprite


func _apply_current_animation_to_sprites() -> void:
	var animation_name: String = _get_current_animation_name()
	for sprite in m_sprite_nodes:
		if not is_instance_valid(sprite):
			continue
		if not sprite.has_meta("animation_entries"):
			continue

		var entries_value = sprite.get_meta("animation_entries")
		if typeof(entries_value) != TYPE_ARRAY:
			continue

		var entries: Array[Dictionary] = entries_value
		var texture: Texture2D = _get_texture_for_animation(entries, animation_name)
		if texture == null and not entries.is_empty():
			texture = entries[0].get("texture", null) as Texture2D

		if texture != null:
			sprite.texture = texture


func _get_texture_for_animation(entries: Array[Dictionary], animation_name: String) -> Texture2D:
	for entry_value in entries:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		if str(entry.get("animation", "")) == animation_name:
			return entry.get("texture", null) as Texture2D
	return null


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


func _get_frame_info_key(selection: Dictionary) -> String:
	var path_string: String = str(selection.get("path_string", ""))
	if path_string != "":
		return path_string.get_file()

	var name: String = str(selection.get("name", ""))
	return name


func _resolve_texture_paths_from_selection(selection: Dictionary) -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	var metadata_root_path: String = str(m_metadata_root.get("universal_lpc_root", ""))
	var spritesheets_dir: String = str(m_metadata_root.get("spritesheets_dir", "spritesheets"))
	if metadata_root_path == "":
		return results

	var default_animations: PackedStringArray = _get_animation_names()
	if default_animations.is_empty():
		return results

	var spritesheets_root: String = _join_path(metadata_root_path, spritesheets_dir)

	var body_type: String = str(m_selection_data.get("body_type", ""))
	var variant: String = str(selection.get("variant", ""))
	var layers = selection.get("layers", [])

	if typeof(layers) != TYPE_ARRAY:
		return results

	var resolved_base_paths: PackedStringArray = _resolve_base_paths_from_selection_layers(selection, body_type, layers)
	if resolved_base_paths.is_empty():
		return results

	for animation_name in default_animations:
		var found_path: String = ""
		for base_path in resolved_base_paths:
			var base_dir: String = _join_path(spritesheets_root, _normalize_relative_dir(base_path))
			if variant != "":
				var candidate_with_variant: String = _join_path(base_dir, "%s/%s.png" % [animation_name, variant])
				
				if ResourceLoader.exists(candidate_with_variant):
					found_path = candidate_with_variant
					break

			var candidate_fallback: String = _join_path(base_dir, "%s.png" % animation_name)
			if ResourceLoader.exists(candidate_fallback):
				found_path = candidate_fallback
				break
		
		if found_path == "":
			continue
		var texture: Texture2D = load(found_path) as Texture2D
		if texture == null:
			continue
		
		results.append({
			"animation": animation_name,
			"path": found_path,
			"texture": texture
		})

	return results


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
