@tool
class_name LpcSpriteBuilder
extends Node

@export var sprite: UniversalLpcSprite2D:
	set(new_sprite):
		if sprite == new_sprite:
			return
		sprite = new_sprite
		_on_sprite_changed()
@export var metadata_file: String = "res://resources/sprites/universal_lpc/universal_lpc_metadata.json"

var m_metadata: Dictionary = {}
var m_body_types: PackedStringArray = []

var m_configuration_data: Dictionary = {}
var m_selected_body_type: int = 0
var m_match_body_color: bool = false
var m_body_variant: int = 0
		
func _ready() -> void:
	_on_sprite_changed()

func _on_sprite_changed() -> void:
	if sprite == null:
		return

	var config: Dictionary = sprite.get_configuration()
	if config.is_empty():
		return

	m_configuration_data = config.duplicate(true)

	_apply_configuration_to_builder_state(m_configuration_data)

	if not m_metadata.is_empty():
		notify_property_list_changed()

func _apply_configuration_to_builder_state(configuration: Dictionary) -> void:
	_apply_body_type_from_configuration(configuration)
	_apply_selection_state_from_configuration(configuration)


func _apply_body_type_from_configuration(configuration: Dictionary) -> void:
	var body_type_index: int = int(configuration.get("body_type_index", -1))
	if body_type_index >= 0 and body_type_index < m_body_types.size():
		m_selected_body_type = body_type_index
		return

	var body_type_name: String = str(configuration.get("body_type", "")).strip_edges()
	if body_type_name == "":
		return

	var found_index: int = m_body_types.find(body_type_name)
	if found_index >= 0:
		m_selected_body_type = found_index


func _apply_selection_state_from_configuration(configuration: Dictionary) -> void:
	var spritesheets = m_metadata.get("spritesheets", [])
	if typeof(spritesheets) != TYPE_ARRAY:
		return

	_reset_tree_selection_state(spritesheets)
	m_body_variant = 0

	var selections_value = configuration.get("selections", {})
	if typeof(selections_value) != TYPE_DICTIONARY:
		return

	var selections: Dictionary = selections_value
	_apply_selection_state_recursive(spritesheets, selections)


func _reset_tree_selection_state(children: Array) -> void:
	for child in children:
		if typeof(child) != TYPE_DICTIONARY:
			continue

		var child_dict: Dictionary = child
		var node_type: String = str(child_dict.get("type", ""))

		if node_type == "directory":
			_reset_tree_selection_state(child_dict.get("children", []))
		elif node_type == "file":
			var state: Dictionary = child_dict.get("state", {})
			state["variant_index"] = 0
			child_dict["state"] = state


func _apply_selection_state_recursive(children: Array, selections: Dictionary, current_parts: Array[String] = []) -> void:
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
			_apply_selection_state_recursive(child_dict.get("children", []), selections, new_parts)
		elif node_type == "file":
			var path_string: String = "/".join(new_parts)
			if not selections.has(path_string):
				continue

			var selected_variant: String = str(selections[path_string]).strip_edges()
			if selected_variant == "":
				continue

			var data: Dictionary = child_dict.get("data", {})
			var variants: PackedStringArray = to_packed_string_array(data.get("variants", []))
			var variant_index: int = variants.find(selected_variant)
			if variant_index < 0:
				continue

			var state: Dictionary = child_dict.get("state", {})
			state["variant_index"] = variant_index + 1
			child_dict["state"] = state

			if data.get("match_body_color", false):
				m_body_variant = variant_index + 1

func _get_property_list() -> Array:
	var properties: Array = []

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

	var spritesheets: Array = m_metadata.get("spritesheets", [])
	_append_leaf_properties(properties, spritesheets)

	var top_keys: Array = m_metadata.keys()
	top_keys.sort()

	properties.append({
		"name": "Metadata",
		"type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP
	})

	for key in top_keys:
		properties.append({
			"name": "metadata/%s" % String(key),
			"type": TYPE_ARRAY if typeof(m_metadata[key]) == TYPE_ARRAY else TYPE_STRING,
			"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY
		})

	properties.append({
		"name": "metadata/selection_data",
		"type": TYPE_DICTIONARY,
		"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY
	})

	return properties


func _get(property: StringName):
	var prop_name := String(property)

	if prop_name == "match_body_color":
		return m_match_body_color

	if prop_name == "body_type":
		return m_selected_body_type

	var leaf_value = get_leaf_value(prop_name)
	if leaf_value != null:
		return leaf_value

	var prefix := "metadata/"
	if prop_name.begins_with(prefix):
		var key := prop_name.trim_prefix(prefix)
		if key == "selection_data":
			return m_configuration_data
		if m_metadata.has(key):
			return m_metadata[key]

	return null


func _set(property: StringName, value) -> bool:
	var prop_name := String(property)

	if prop_name == "match_body_color":
		var new_match: bool = bool(value)
		if m_match_body_color == new_match:
			return false

		m_match_body_color = new_match
		load_into_sprite(metadata_file)
		notify_property_list_changed()
		return true

	if prop_name == "body_type":
		if m_body_types.is_empty():
			return false

		var index: int = clampi(int(value), 0, m_body_types.size() - 1)
		if m_selected_body_type == index:
			return true

		m_selected_body_type = index
		load_into_sprite(metadata_file)
		notify_property_list_changed()
		print("Selected body type: ", m_body_types[m_selected_body_type])
		return true

	var result: Dictionary = set_leaf_value(prop_name, int(value))
	if bool(result.get("changed", false)):
		var index: int = int(result.get("index", 0))
		var variants: PackedStringArray = result.get("variants", PackedStringArray())

		load_into_sprite(metadata_file)
		notify_property_list_changed()

		if index == 0:
			print("_set(%s: none)" % prop_name)
		else:
			print("_set(%s: %s)" % [prop_name, variants[index - 1]])
		return true

	return false


func clear() -> void:
	m_metadata.clear()
	m_body_types.clear()
	m_configuration_data.clear()
	m_selected_body_type = 0
	m_match_body_color = false
	m_body_variant = 0


func load_into_sprite(in_metadata_file: String = "") -> void:
	if in_metadata_file.strip_edges() != "":
		metadata_file = in_metadata_file

	generate_selection_data()

	if sprite == null:
		return

	sprite.load(m_configuration_data, metadata_file)


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
			var variants: PackedStringArray = get_leaf_variants(child_dict)
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


func get_leaf_value(property_path: String) -> Variant:
	var leaf: Dictionary = find_leaf_by_property_path(property_path)
	if leaf.is_empty():
		return null

	var state: Dictionary = leaf.get("state", {})
	return int(state.get("variant_index", 0))


func set_leaf_value(property_path: String, value: int) -> Dictionary:
	var leaf: Dictionary = find_leaf_by_property_path(property_path)
	if leaf.is_empty():
		return {
			"changed": false
		}

	var variants: PackedStringArray = get_leaf_variants(leaf)
	var max_index: int = variants.size()
	var index: int = clampi(int(value), 0, max_index)
	var leaf_data: Dictionary = {}

	if index > 0:
		leaf_data = leaf.get("data", {})
		var type_name: String = str(leaf_data.get("type_name", "")).strip_edges()
		if type_name != "":
			clear_same_type_name_selection(m_metadata.get("spritesheets", []), type_name, leaf)

	var state: Dictionary = leaf.get("state", {})
	state["variant_index"] = index
	leaf["state"] = state

	if leaf_data.get("match_body_color", false) and index > 0:
		m_body_variant = index

	var selected_variant: String = ""
	if index > 0 and index - 1 < variants.size():
		selected_variant = variants[index - 1]

	return {
		"changed": true,
		"index": index,
		"variants": variants,
		"selected_variant": selected_variant
	}


func generate_selection_data() -> Dictionary:
	var selected_items: Dictionary = {}
	collect_selected_items(m_metadata.get("spritesheets", []), selected_items)

	m_configuration_data = {
		"body_type_index": m_selected_body_type,
		"body_type": get_selected_body_type_name(),
		"selections": selected_items
	}

	return m_configuration_data


func collect_selected_items(children: Array, out_items: Dictionary, current_parts: Array[String] = []) -> void:
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
			collect_selected_items(child_dict.get("children", []), out_items, new_parts)
		elif node_type == "file":
			var state: Dictionary = child_dict.get("state", {})
			var variant_index: int = int(state.get("variant_index", 0))
			if variant_index <= 0:
				continue

			var data: Dictionary = child_dict.get("data", {})
			var variants: PackedStringArray = to_packed_string_array(data.get("variants", []))
			if variant_index > variants.size():
				continue

			if m_match_body_color and data.get("match_body_color", false):
				variant_index = m_body_variant
				state["variant_index"] = variant_index
				child_dict["state"] = state

			var path_string: String = "/".join(new_parts)
			out_items[path_string] = variants[variant_index - 1]


func get_selected_body_type_name() -> String:
	if m_selected_body_type < 0 or m_selected_body_type >= m_body_types.size():
		return ""
	return m_body_types[m_selected_body_type]


func clear_same_type_name_selection(children: Array, type_name: String, except_leaf: Dictionary) -> void:
	for child in children:
		if typeof(child) != TYPE_DICTIONARY:
			continue

		var child_dict: Dictionary = child
		var node_type: String = str(child_dict.get("type", ""))

		if node_type == "directory":
			clear_same_type_name_selection(child_dict.get("children", []), type_name, except_leaf)
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


func find_leaf_by_property_path(property_path: String) -> Dictionary:
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

	return find_leaf_by_path_parts(m_metadata.get("spritesheets", []), parts)


func find_leaf_by_path_parts(children: Array, parts: Array[String], index: int = 0) -> Dictionary:
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
			return find_leaf_by_path_parts(child_dict.get("children", []), parts, index + 1)

	return {}


func get_leaf_variants(leaf: Dictionary) -> PackedStringArray:
	var data: Dictionary = leaf.get("data", {})
	return to_packed_string_array(data.get("variants", []))


func count_leaf_items(children: Array) -> int:
	var count := 0

	for child in children:
		if typeof(child) != TYPE_DICTIONARY:
			continue

		var node_type: String = str(child.get("type", ""))
		if node_type == "file":
			count += 1
		elif node_type == "directory":
			count += count_leaf_items(child.get("children", []))

	return count


func load_metadata_from_root(root: Dictionary, previous_configuration_data: Dictionary = {}) -> void:
	m_metadata.clear()
	m_body_types.clear()

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
		m_metadata["universal_lpc_root"] = json_universal_lpc_root
		m_metadata["sheet_definitions_dir"] = json_sheet_definitions_dir
		if not m_body_types.is_empty():
			m_metadata["body_types"] = m_body_types
		m_metadata["spritesheets"] = []
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

		var relative_dir_path: String = meta_relative_directory_path_from_export(json_file)
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

		var path_parts: Array[String] = json_file_to_tree_path_parts(json_file)
		if path_parts.is_empty():
			continue

		var spritesheet_item: Dictionary = build_spritesheet_item(def)
		if spritesheet_item.is_empty():
			continue

		spritesheet_item["json_file_absolute"] = join_path(join_path(json_universal_lpc_root, json_sheet_definitions_dir), json_file)

		insert_item_into_tree_from_path_array(
			spritesheet_tree,
			path_parts,
			spritesheet_item,
			directory_priorities,
			previous_configuration_data
		)

	sort_tree_recursive(spritesheet_tree)

	m_metadata["universal_lpc_root"] = json_universal_lpc_root
	m_metadata["sheet_definitions_dir"] = json_sheet_definitions_dir
	if not m_body_types.is_empty():
		m_metadata["body_types"] = m_body_types
	m_metadata["spritesheets"] = spritesheet_tree
	notify_property_list_changed()


func meta_relative_directory_path_from_export(json_file: String) -> String:
	return json_file.get_base_dir()


func json_file_to_tree_path_parts(json_file: String) -> Array[String]:
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


func path_array_key(path_parts: Array[String]) -> String:
	return "/".join(path_parts)


func build_spritesheet_item(def: Dictionary) -> Dictionary:
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


func insert_item_into_tree_from_path_array(
	tree: Array,
	path_parts: Array[String],
	item: Dictionary,
	directory_priorities: Dictionary,
	previous_configuration_data: Dictionary = {}
) -> void:
	var node_array: Array = tree
	var current_path: Array[String] = []

	for i in range(path_parts.size()):
		var part: String = path_parts[i]
		var is_leaf: bool = i == path_parts.size() - 1
		current_path.append(part)

		var existing = find_child_dict(node_array, part)

		if is_leaf:
			var path_string: String = "/".join(path_parts)
			var selections: Dictionary = previous_configuration_data.get("selections", {})
			var variant: String = str(selections.get(path_string, ""))
			var variant_index := 0
			if not variant.is_empty():
				var variant_list = item.get("variants", [])
				if typeof(variant_list) == TYPE_ARRAY:
					variant_index = variant_list.find(variant) + 1

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

		var dir_key: String = path_array_key(current_path)
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


func find_child_dict(children: Array, name: String):
	for child in children:
		if typeof(child) == TYPE_DICTIONARY and child.get("name", "") == name:
			return child
	return null


func sort_tree_recursive(children: Array) -> void:
	children.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ap := int(a.get("priority", 999999))
		var bp := int(b.get("priority", 999999))
		if ap != bp:
			return ap < bp
		return str(a.get("name", "")).to_lower() < str(b.get("name", "")).to_lower()
	)

	for child in children:
		if typeof(child) == TYPE_DICTIONARY and child.get("type", "") == "directory":
			sort_tree_recursive(child["children"])


func to_packed_string_array(value) -> PackedStringArray:
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


func join_path(a: String, b: String) -> String:
	if a.ends_with("/"):
		return a + b
	return a + "/" + b
