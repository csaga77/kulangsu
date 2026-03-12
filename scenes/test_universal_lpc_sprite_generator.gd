@tool
extends Node2D

@onready var m_reader: UniversalLpcMetadataReader = $metadata_reader
@onready var m_sprite: UniversalLpcSprite2D = $universal_lpc_sprite
@export var output_json_path: String = "res://universal_lpc_metadata.json"
@export var target_path: String = "res://resources/sprites/universal_lpc"

var m_loaded_metadata: Dictionary = {}
var m_body_types: PackedStringArray = []

@export_storage var m_selection_data: Dictionary = {}
@export_storage var m_selected_body_type: int = 0
@export_storage var m_match_body_color: bool = false
@export_storage var m_body_variant: int = 0

func _ready() -> void:
	_load_metadata_json()
	_generate_selection_data()

func _get_property_list() -> Array:
	var properties: Array = []

	properties.append({
		"name": "generate_metadata_json",
		"type": TYPE_CALLABLE,
		"usage": PROPERTY_USAGE_EDITOR,
		"hint": PROPERTY_HINT_TOOL_BUTTON,
		"hint_string": "Generate Metadata JSON"
	})

	properties.append({
		"name": "load_metadata_json",
		"type": TYPE_CALLABLE,
		"usage": PROPERTY_USAGE_EDITOR,
		"hint": PROPERTY_HINT_TOOL_BUTTON,
		"hint_string": "Load Metadata JSON"
	})

	properties.append({
		"name": "generate_sprite",
		"type": TYPE_CALLABLE,
		"usage": PROPERTY_USAGE_EDITOR,
		"hint": PROPERTY_HINT_TOOL_BUTTON,
		"hint_string": "Generate Sprite"
	})

	if not m_body_types.is_empty():
		properties.append({
			"name": "match_body_color",
			"type": TYPE_BOOL,
			"hint": PROPERTY_HINT_NONE,
			"hint_string": "Match Body Color",
			"usage": PROPERTY_USAGE_EDITOR
		})
		
		properties.append({
			"name": "body_type",
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": ",".join(m_body_types),
			"usage": PROPERTY_USAGE_EDITOR
		})

	var spritesheets: Array = m_loaded_metadata.get("spritesheets", [])
	_append_leaf_properties(properties, spritesheets)

	var top_keys: Array = m_loaded_metadata.keys()
	top_keys.sort()

	properties.append({
		"name": "Metadata",
		"type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP
	})

	for key in top_keys:
		properties.append({
			"name": "metadata/%s" % String(key),
			"type": TYPE_ARRAY if typeof(m_loaded_metadata[key]) == TYPE_ARRAY else TYPE_STRING,
			"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY
		})

	properties.append({
		"name": "metadata/selection_data",
		"type": TYPE_DICTIONARY,
		"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY
	})

	return properties


func _append_leaf_properties(properties: Array, children: Array, current_parts: Array[String] = []) -> void:
	for child in children:
		if typeof(child) != TYPE_DICTIONARY:
			continue

		var child_dict: Dictionary = child
		var child_name: String = str(child_dict.get("name", "")).strip_edges()
		if child_name == "":
			continue

		var new_parts: Array[String] = current_parts.duplicate()
		new_parts.append(child_name)

		var node_type: String = str(child_dict.get("type", ""))
		if node_type == "directory":
			_append_leaf_properties(properties, child_dict.get("children", []), new_parts)
		elif node_type == "file":
			var leaf_path: String = "/".join(new_parts)
			var variants: PackedStringArray = _get_leaf_variants(child_dict)
			if not variants.is_empty():
				var enum_items: PackedStringArray = ["<none>"]
				for v in variants:
					enum_items.append(v)

				properties.append({
					"name": leaf_path,
					"type": TYPE_INT,
					"hint": PROPERTY_HINT_ENUM,
					"hint_string": ",".join(enum_items),
					"usage": PROPERTY_USAGE_EDITOR
				})


func _get(property: StringName):
	if property == "generate_metadata_json":
		return Callable(self, "_generate_metadata_json")
	if property == "load_metadata_json":
		return Callable(self, "_load_metadata_json")
	if property == "generate_sprite":
		return Callable(self, "_generate_sprite")

	var prop_name := String(property)
	
	if prop_name == "match_body_color":
		return m_match_body_color

	if prop_name == "body_type":
		return m_selected_body_type

	var leaf: Dictionary = _find_leaf_by_property_path(prop_name)
	if not leaf.is_empty():
		var state: Dictionary = leaf.get("state", {})
		return int(state.get("variant_index", 0))

	var prefix := "metadata/"
	if prop_name.begins_with(prefix):
		var key := prop_name.trim_prefix(prefix)
		if key == "selection_data":
			return m_selection_data
		if m_loaded_metadata.has(key):
			return m_loaded_metadata[key]

	return null


func _set(property: StringName, value) -> bool:
	var prop_name := String(property)

	if prop_name == "match_body_color":
		var new_match = bool(value)
		if m_match_body_color == new_match:
			return false
		m_match_body_color = new_match
		_generate_selection_data()
		if Engine.is_editor_hint():
			notify_property_list_changed()
		return true

	if prop_name == "body_type":
		if m_body_types.is_empty():
			return false

		var index: int = clampi(int(value), 0, m_body_types.size() - 1)
		if m_selected_body_type == index:
			return true

		m_selected_body_type = index
		_generate_selection_data()
		print("Selected body type: ", m_body_types[m_selected_body_type])
		if Engine.is_editor_hint():
			notify_property_list_changed()
		return true

	var leaf: Dictionary = _find_leaf_by_property_path(prop_name)
	if not leaf.is_empty():
		var variants: PackedStringArray = _get_leaf_variants(leaf)
		var max_index: int = variants.size()
		var index: int = clampi(int(value), 0, max_index)
		var leaf_data: Dictionary
		if index > 0:
			leaf_data = leaf.get("data", {})
			var type_name: String = str(leaf_data.get("type_name", "")).strip_edges()
			if type_name != "":
				_clear_same_type_name_selection(m_loaded_metadata.get("spritesheets", []), type_name, leaf)

		var state: Dictionary = leaf.get("state", {})
		state["variant_index"] = index
		leaf["state"] = state
		if leaf_data.get("match_body_color", false) and index > 0:
			#print("match_body_color :", index)
			m_body_variant = index

		_generate_selection_data()
		if index == 0:
			print("_set(%s: none)" % prop_name)
		else:
			print("_set(%s: %s)" % [prop_name, variants[index - 1]])

		notify_property_list_changed()
		return true

	return false


func _generate_metadata_json() -> void:
	if not Engine.is_editor_hint():
		return

	if m_reader == null:
		push_error("UniversalLpcMetadataReader not found.")
		return

	print("Generating Universal LPC metadata...")

	var ok: bool = m_reader.export_metadata_as_json(output_json_path, target_path)

	if ok:
		print("Metadata JSON generated at: ", output_json_path)
	else:
		push_error("Failed to generate metadata JSON.")


func _generate_sprite() -> void:
	if not Engine.is_editor_hint():
		return
	m_sprite.load(m_selection_data, output_json_path)


func _load_metadata_json() -> void:
	if not Engine.is_editor_hint():
		return

	if output_json_path.strip_edges() == "":
		push_error("output_json_path is empty.")
		return

	if not FileAccess.file_exists(output_json_path):
		push_error("Metadata JSON not found: %s" % output_json_path)
		return

	var text: String = FileAccess.get_file_as_string(output_json_path)
	if text.is_empty():
		push_error("Metadata JSON is empty: %s" % output_json_path)
		return

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("Failed to parse metadata JSON: %s" % output_json_path)
		return

	if typeof(json.data) != TYPE_DICTIONARY:
		push_error("Metadata JSON root must be a Dictionary.")
		return

	var root: Dictionary = json.data
	m_loaded_metadata.clear()
	#m_selection_data.clear()
	m_body_types.clear()
	#m_selected_body_type = 0

	var json_universal_lpc_root: String = str(root.get("universal_lpc_root", ""))
	var json_sheet_definitions_dir: String = str(root.get("sheet_definitions_dir", "sheet_definitions"))
	var json_body_types_value = root.get("body_types", [])

	if typeof(json_body_types_value) == TYPE_ARRAY:
		for item in json_body_types_value:
			if typeof(item) == TYPE_STRING:
				var body_type: String = String(item).strip_edges()
				if body_type != "":
					m_body_types.append(body_type)

	var definitions = root.get("definitions", [])
	if typeof(definitions) != TYPE_ARRAY:
		notify_property_list_changed()
		return

	var spritesheet_tree: Array = []
	var directory_priorities: Dictionary = {}

	for entry in definitions:
		if typeof(entry) != TYPE_DICTIONARY:
			continue

		var def: Dictionary = entry
		var json_file: String = str(def.get("json_file", ""))
		if json_file == "":
			continue

		var base_name: String = json_file.get_file().get_basename().to_lower()
		if not base_name.begins_with("meta_"):
			continue

		var relative_dir_path: String = _meta_relative_directory_path_from_export(json_file)
		directory_priorities[relative_dir_path] = int(def.get("priority", 999999))

	for entry in definitions:
		if typeof(entry) != TYPE_DICTIONARY:
			continue

		var def: Dictionary = entry
		var json_file: String = str(def.get("json_file", ""))
		if json_file == "":
			continue

		var base_name: String = json_file.get_file().get_basename().to_lower()
		if base_name.begins_with("meta_"):
			continue

		var path_parts: Array[String] = _json_file_to_tree_path_parts(json_file)
		if path_parts.is_empty():
			continue

		var spritesheet_item: Dictionary = _build_spritesheet_item(def)
		if spritesheet_item.is_empty():
			continue

		spritesheet_item["json_file_absolute"] = _join_path(_join_path(json_universal_lpc_root, json_sheet_definitions_dir), json_file)

		_insert_item_into_tree_from_path_array(spritesheet_tree, path_parts, spritesheet_item, directory_priorities)

	_sort_tree_recursive(spritesheet_tree)

	m_loaded_metadata["universal_lpc_root"] = json_universal_lpc_root
	m_loaded_metadata["sheet_definitions_dir"] = json_sheet_definitions_dir
	if not m_body_types.is_empty():
		m_loaded_metadata["body_types"] = m_body_types
	m_loaded_metadata["spritesheets"] = spritesheet_tree

	_generate_selection_data()

	notify_property_list_changed()

	var leaf_count := _count_leaf_items(spritesheet_tree)
	print("Loaded metadata JSON and built property tree from json_file relative path.")
	print("[ULPC Metadata Summary]")
	print("Leaf items: ", leaf_count)
	if not m_body_types.is_empty():
		print("Body Types: ", ", ".join(m_body_types))

var m_is_loading_sprite := false

func _generate_selection_data() -> void:
	if m_is_loading_sprite:
		return
	m_is_loading_sprite = true
	call_deferred("_do_load_sprite")
	
func _do_load_sprite() -> void:
	var selected_items: Dictionary = {}
	_collect_selected_items(m_loaded_metadata.get("spritesheets", []), selected_items)

	m_selection_data = {
		"body_type_index": m_selected_body_type,
		"body_type": _get_selected_body_type_name(),
		"selections": selected_items
	}
	_generate_sprite()
	m_is_loading_sprite = false

func _collect_selected_items(children: Array, out_items: Dictionary, current_parts: Array[String] = []) -> void:
	for child in children:
		if typeof(child) != TYPE_DICTIONARY:
			continue

		var child_dict: Dictionary = child
		var child_name: String = str(child_dict.get("name", "")).strip_edges()
		if child_name == "":
			continue

		var new_parts: Array[String] = current_parts.duplicate()
		new_parts.append(child_name)

		var node_type: String = str(child_dict.get("type", ""))
		if node_type == "directory":
			_collect_selected_items(child_dict.get("children", []), out_items, new_parts)
		elif node_type == "file":
			var state: Dictionary = child_dict.get("state", {})
			var variant_index: int = int(state.get("variant_index", 0))
			if variant_index <= 0:
				continue

			var data: Dictionary = child_dict.get("data", {})
			var variants: PackedStringArray = _to_packed_string_array(data.get("variants", []))
			if variant_index > variants.size():
				continue

			if m_match_body_color and data.get("match_body_color", false):
				variant_index = m_body_variant
				state["variant_index"] = variant_index

			var path_string: String = "/".join(new_parts)
			out_items[path_string] = variants[variant_index - 1]


func _get_selected_body_type_name() -> String:
	if m_selected_body_type < 0 or m_selected_body_type >= m_body_types.size():
		return ""
	return m_body_types[m_selected_body_type]


func _clear_same_type_name_selection(children: Array, type_name: String, except_leaf: Dictionary) -> void:
	for child in children:
		if typeof(child) != TYPE_DICTIONARY:
			continue

		var child_dict: Dictionary = child
		var node_type: String = str(child_dict.get("type", ""))

		if node_type == "directory":
			_clear_same_type_name_selection(child_dict.get("children", []), type_name, except_leaf)
		elif node_type == "file":
			if child_dict == except_leaf:
				continue

			var data: Dictionary = child_dict.get("data", {})
			var child_type_name: String = str(data.get("type_name", "")).strip_edges()
			if child_type_name != type_name:
				continue

			var state: Dictionary = child_dict.get("state", {})
			if int(state.get("variant_index", 0)) != 0:
				state["variant_index"] = 0
				child_dict["state"] = state


func _find_leaf_by_property_path(property_path: String) -> Dictionary:
	if property_path.strip_edges() == "":
		return {}

	var parts_raw: PackedStringArray = property_path.split("/")
	var parts: Array[String] = []
	for part in parts_raw:
		var clean_part: String = String(part).strip_edges()
		if clean_part != "":
			parts.append(clean_part)

	if parts.is_empty():
		return {}

	return _find_leaf_by_path_parts(m_loaded_metadata.get("spritesheets", []), parts)


func _find_leaf_by_path_parts(children: Array, parts: Array[String], index: int = 0) -> Dictionary:
	if index >= parts.size():
		return {}

	var target: String = parts[index]

	for child in children:
		if typeof(child) != TYPE_DICTIONARY:
			continue

		var child_dict: Dictionary = child
		if str(child_dict.get("name", "")) != target:
			continue

		var node_type: String = str(child_dict.get("type", ""))
		if index == parts.size() - 1:
			if node_type == "file":
				return child_dict
			return {}

		if node_type == "directory":
			return _find_leaf_by_path_parts(child_dict.get("children", []), parts, index + 1)

	return {}


func _get_leaf_variants(leaf: Dictionary) -> PackedStringArray:
	var data: Dictionary = leaf.get("data", {})
	return _to_packed_string_array(data.get("variants", []))


func _count_leaf_items(children: Array) -> int:
	var count := 0

	for child in children:
		if typeof(child) != TYPE_DICTIONARY:
			continue

		var node_type: String = str(child.get("type", ""))
		if node_type == "file":
			count += 1
		elif node_type == "directory":
			count += _count_leaf_items(child.get("children", []))

	return count


func _meta_relative_directory_path_from_export(json_file: String) -> String:
	return json_file.get_base_dir()


func _json_file_to_tree_path_parts(json_file: String) -> Array[String]:
	var parts: Array[String] = []

	if json_file == "":
		return parts

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

	return parts


func _path_array_key(path_parts: Array[String]) -> String:
	return "/".join(path_parts)


func _build_spritesheet_item(def: Dictionary) -> Dictionary:
	var item: Dictionary = {}

	for key in [
		"name",
		"type_name",
		"tags",
		"variants",
		"animations",
		"required",
		"aliases",
		"frame_info",
		"layers",
		"priority",
		"json_file",
		"match_body_color",
		"path"
	]:
		if def.has(key):
			item[key] = def[key]

	return item


func _insert_item_into_tree_from_path_array(tree: Array, path_parts: Array[String], item: Dictionary, directory_priorities: Dictionary) -> void:
	var node_array: Array = tree
	var current_path: Array[String] = []

	for i in range(path_parts.size()):
		var part: String = path_parts[i]
		var is_leaf: bool = i == path_parts.size() - 1
		current_path.append(part)

		var existing = _find_child(node_array, part)

		if is_leaf:
			var path_string = "/".join(path_parts)
			var variant :String = m_selection_data["selections"].get(path_string, "")
			var variant_index := 0
			if !variant.is_empty():
				variant_index = item.get("variants", []).find(variant) + 1

			if existing == null:
				node_array.append({
					"name": part,
					"type": "file",
					"priority": int(item.get("priority", 999999)),
					"data": item,
					"state": {
						"variant_index": variant_index
					}
				})
			else:
				existing["priority"] = int(item.get("priority", 999999))
				existing["data"] = item
				var state: Dictionary = existing.get("state", {})
				if not state.has("variant_index"):
					state["variant_index"] = variant_index
				existing["state"] = state
			return

		var dir_key: String = _path_array_key(current_path)
		var dir_priority: int = int(directory_priorities.get(dir_key, 999999))

		if existing == null:
			var new_dir := {
				"name": part,
				"type": "directory",
				"priority": dir_priority,
				"children": []
			}
			node_array.append(new_dir)
			node_array = new_dir["children"]
		else:
			if dir_priority != 999999:
				existing["priority"] = dir_priority
			node_array = existing.get("children", [])


func _find_child(children: Array, name: String):
	for child in children:
		if typeof(child) == TYPE_DICTIONARY and child.get("name", "") == name:
			return child
	return null


func _sort_tree_recursive(children: Array) -> void:
	children.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ap := int(a.get("priority", 999999))
		var bp := int(b.get("priority", 999999))
		if ap != bp:
			return ap < bp
		return str(a.get("name", "")).to_lower() < str(b.get("name", "")).to_lower()
	)

	for child in children:
		if typeof(child) == TYPE_DICTIONARY and child.get("type", "") == "directory":
			_sort_tree_recursive(child["children"])


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
