@tool
class_name UniversalLpcMetadataReader
extends Node

@export_dir var universal_lpc_root: String = "res://universal_lpc"
@export var sheet_definitions_dir: String = "sheet_definitions"
@export var spritesheets_dir: String = "spritesheets"
@export var include_credits: bool = true

@export var use_js_frame_info: bool = true
@export var custom_animations_js_relative_path: String = "sources/custom-animations.js"

var _cached_js_frame_layout: Dictionary = {}
var _js_frame_layout_loaded: bool = false

const DEFAULT_ANIMATIONS: PackedStringArray = [
	"idle",
	"spellcast",
	"thrust",
	"walk",
	"run",
	"sit",
	"slash",
	"shoot",
	"hurt",
	"jump",
	"climb",
	"watering",
	"emote",
	"combat",
	"1h_slash",
	"1h_backslash",
	"1h_halfslash"
]

const DEFAULT_VARIANTS: PackedStringArray = []

const FALLBACK_FRAME_LAYOUT: Dictionary = {
	"1h_backslash": {"directions": 4, "frame_height": 64, "frame_width": 64, "frames_per_direction": 1, "total_frames": 4},
	"1h_halfslash": {"directions": 4, "frame_height": 64, "frame_width": 64, "frames_per_direction": 1, "total_frames": 4},
	"1h_slash": {"directions": 4, "frame_height": 64, "frame_width": 64, "frames_per_direction": 1, "total_frames": 4},
	"climb": {"directions": 1, "frame_height": 64, "frame_width": 64, "frames_per_direction": 6, "total_frames": 6},
	"combat": {"directions": 4, "frame_height": 64, "frame_width": 64, "frames_per_direction": 1, "total_frames": 4},
	"emote": {"directions": 4, "frame_height": 64, "frame_width": 64, "frames_per_direction": 1, "total_frames": 4},
	"hurt": {"directions": 1, "frame_height": 64, "frame_width": 64, "frames_per_direction": 6, "total_frames": 6},
	"idle": {"directions": 4, "frame_height": 64, "frame_width": 64, "frames_per_direction": 2, "total_frames": 8},
	"jump": {"directions": 4, "frame_height": 64, "frame_width": 64, "frames_per_direction": 9, "total_frames": 36},
	"run": {"directions": 4, "frame_height": 64, "frame_width": 64, "frames_per_direction": 8, "total_frames": 32},
	"shoot": {"directions": 4, "frame_height": 64, "frame_width": 64, "frames_per_direction": 13, "total_frames": 52},
	"sit": {"directions": 4, "frame_height": 64, "frame_width": 64, "frames_per_direction": 1, "total_frames": 4},
	"slash": {"directions": 4, "frame_height": 64, "frame_width": 64, "frames_per_direction": 6, "total_frames": 24},
	"spellcast": {"directions": 4, "frame_height": 64, "frame_width": 64, "frames_per_direction": 7, "total_frames": 28},
	"thrust": {"directions": 4, "frame_height": 64, "frame_width": 64, "frames_per_direction": 8, "total_frames": 32},
	"walk": {"directions": 4, "frame_height": 64, "frame_width": 64, "frames_per_direction": 9, "total_frames": 36},
	"watering": {"directions": 4, "frame_height": 64, "frame_width": 64, "frames_per_direction": 6, "total_frames": 24}
}


func read_all_sheet_metadata() -> Array[Dictionary]:
	_clear_js_frame_layout_cache()

	var results: Array[Dictionary] = []

	var defs_root := _join_path(universal_lpc_root, sheet_definitions_dir)
	var json_files := _collect_json_files(defs_root)

	for json_path in json_files:
		var parsed := _read_one_sheet_definition(json_path)
		if !parsed.is_empty():
			results.append(parsed)

	results.sort_custom(_sort_metadata_entries)

	_print_read_summary(json_files, results)
	return results


func export_metadata_as_json(output_path: String = "user://universal_lpc_metadata.json") -> bool:
	var definitions := read_all_sheet_metadata()
	var export_data: Dictionary = {
		"default_animations": DEFAULT_ANIMATIONS.duplicate(),
		"default_variants": DEFAULT_VARIANTS.duplicate(),
		"default_frame_info": {
			"source": "fallback",
			"data": _get_default_frame_layout()
		},
		"definitions": definitions
	}
	var json_text := JSON.stringify(export_data, "\t")

	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open output file: %s" % output_path)
		return false

	file.store_string(json_text)
	file.close()

	_print_export_summary(definitions, output_path)
	return true


func _print_export_summary(data: Array[Dictionary], output_path: String) -> void:
	var definition_count: int = data.size()
	var total_animation_count: int = 0
	var total_variant_count: int = 0
	var total_layer_count: int = 0
	var priorities: Array[int] = []
	var definitions_with_credits: int = 0
	var additional_animation_names: PackedStringArray = []
	var variant_names: PackedStringArray = []
	var tag_names: PackedStringArray = []
	var type_names: PackedStringArray = []

	var custom_animation_names: PackedStringArray = []
	var js_layout: Dictionary = _extract_frame_layout_from_js()
	for key in js_layout.keys():
		custom_animation_names.append(str(key))

	for entry in data:
		var animations: PackedStringArray = _to_packed_string_array(entry.get("animations", []))
		var variants: PackedStringArray = _to_packed_string_array(entry.get("variants", []))
		var tags: PackedStringArray = _to_packed_string_array(entry.get("tags", []))
		var type_name: String = str(entry.get("type_name", ""))
		var priority: int = int(entry.get("priority", 999999))
		var layers_value = entry.get("layers", [])
		var layer_count: int = layers_value.size() if typeof(layers_value) == TYPE_ARRAY else 0

		total_animation_count += animations.size()
		total_variant_count += variants.size()
		total_layer_count += layer_count
		priorities.append(priority)

		for animation in animations:
			if not DEFAULT_ANIMATIONS.has(animation):
				additional_animation_names.append(animation)

		for variant in variants:
			variant_names.append(variant)

		for tag in tags:
			tag_names.append(tag)

		if type_name != "":
			type_names.append(type_name)

		if entry.has("credits"):
			definitions_with_credits += 1

	additional_animation_names = _unique_packed(additional_animation_names)
	variant_names = _unique_packed(variant_names)
	tag_names = _unique_packed(tag_names)
	type_names = _unique_packed(type_names)
	custom_animation_names = _unique_packed(custom_animation_names)

	print("[ULPC Metadata] Export complete")
	print("[ULPC Metadata] Output: %s" % output_path)
	print("[ULPC Metadata] Definitions: %d" % definition_count)
	print("[ULPC Metadata] Total animations referenced: %d" % total_animation_count)
	print("[ULPC Metadata] Total variants referenced: %d" % total_variant_count)
	print("[ULPC Metadata] Total layers referenced: %d" % total_layer_count)
	print("[ULPC Metadata] Priority range: %s" % _format_priority_summary(priorities))
	print("[ULPC Metadata] Definitions with credits: %d" % definitions_with_credits)
	print("[ULPC Metadata] Unique type names (%d): %s" % [type_names.size(), ", ".join(type_names)])
	print("[ULPC Metadata] Additional animations (not in default) (%d): %s" % [additional_animation_names.size(), ", ".join(additional_animation_names)])
	print("[ULPC Metadata] All custom animations from JS (%d): %s" % [custom_animation_names.size(), ", ".join(custom_animation_names)])
	print("[ULPC Metadata] Unique animation variants (%d): %s" % [variant_names.size(), ", ".join(variant_names)])
	print("[ULPC Metadata] Unique tags (%d): %s" % [tag_names.size(), ", ".join(tag_names)])


func _print_read_summary(json_files: PackedStringArray, results: Array[Dictionary]) -> void:
	print("[ULPC Metadata] JSON files scanned: %d" % json_files.size())
	print("[ULPC Metadata] Valid definitions loaded: %d" % results.size())

func _read_one_sheet_definition(json_path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(json_path)
	if text.is_empty():
		push_warning("Empty or unreadable json: %s" % json_path)
		return {}

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_warning("Failed to parse json: %s error=%s" % [json_path, err])
		return {}

	var root = json.data
	if typeof(root) != TYPE_DICTIONARY:
		push_warning("Unexpected json root type in: %s" % json_path)
		return {}

	var d: Dictionary = root
	var source_animations: PackedStringArray = _extract_animations(d)
	var animations: PackedStringArray = _extract_additional_animations_only(source_animations)
	var has_explicit_animations: bool = d.has("animations")
	var tags: PackedStringArray = _extract_tags(d)
	var frame_info: Dictionary = _extract_frame_info(d, source_animations)
	frame_info = _remove_default_frame_info_blocks(frame_info)
	var has_custom_frame_info: bool = _has_custom_frame_info(frame_info)
	var priority: int = _extract_priority(d)

	var metadata: Dictionary = {
		"json_file": json_path,
		"priority": priority
	}

	if d.has("definition_name") and typeof(d["definition_name"]) == TYPE_STRING and str(d["definition_name"]) != "":
		metadata["definition_name"] = str(d["definition_name"])

	if d.has("name") or d.has("label"):
		var exported_name: String = str(d.get("name", d.get("label", "")))
		if exported_name != "":
			metadata["name"] = exported_name

	var type_name: String = str(d.get("type_name", ""))
	if type_name != "":
		metadata["type_name"] = type_name

	if (d.has("tags") or d.has("tag")) and not tags.is_empty():
		metadata["tags"] = tags

	var source_variants: PackedStringArray = _to_packed_string_array(d.get("variants", []))
	var variants: PackedStringArray = _extract_additional_variants_only(source_variants)
	if d.has("variants") and not variants.is_empty():
		metadata["variants"] = variants

	if has_explicit_animations and not animations.is_empty():
		metadata["animations"] = animations

	if d.has("required"):
		var required: PackedStringArray = _to_packed_string_array(d.get("required", []))
		if not required.is_empty():
			metadata["required"] = required

	var layers := _extract_layers(d)
	if not layers.is_empty():
		metadata["layers"] = layers

	if d.has("aliases") and typeof(d["aliases"]) == TYPE_DICTIONARY and not (d["aliases"] as Dictionary).is_empty():
		metadata["aliases"] = (d["aliases"] as Dictionary).duplicate(true)

	if has_custom_frame_info:
		metadata["frame_info"] = frame_info

	if include_credits and d.has("credits") and typeof(d["credits"]) == TYPE_ARRAY:
		metadata["credits"] = d["credits"]

	var handled_source_keys: Dictionary = {
		"priority": true,
		"definition_name": true,
		"name": true,
		"label": true,
		"type_name": true,
		"tags": true,
		"tag": true,
		"variants": true,
		"animations": true,
		"required": true,
		"layers": true,
		"aliases": true,
		"credits": true,
		"frame_info": true,
		"frames": true,
		"frame_data": true,
		"animation_frames": true,
		"layout": true
	}

	for key in d.keys():
		var key_str: String = str(key)
		if handled_source_keys.has(key_str):
			continue
		if key_str.begins_with("layer_"):
			continue
		if metadata.has(key_str):
			continue

		var value = d[key]
		match typeof(value):
			TYPE_DICTIONARY:
				metadata[key_str] = (value as Dictionary).duplicate(true)
			TYPE_ARRAY:
				metadata[key_str] = (value as Array).duplicate(true)
			_:
				metadata[key_str] = value

	return metadata


func _remove_default_frame_info_blocks(frame_info: Dictionary) -> Dictionary:
	if frame_info.is_empty():
		return frame_info

	var normalized: Dictionary = frame_info.duplicate(true)
	var data = normalized.get("data", {})
	if typeof(data) != TYPE_DICTIONARY:
		return normalized

	var data_dict: Dictionary = data
	var filtered_data: Dictionary = {}
	var default_layout: Dictionary = _get_default_frame_layout()

	for key in data_dict.keys():
		var value = data_dict[key]
		if default_layout.has(key):
			var default_block = default_layout[key]
			if typeof(value) == TYPE_DICTIONARY and typeof(default_block) == TYPE_DICTIONARY and _dictionaries_equal(value as Dictionary, default_block as Dictionary):
				continue
		filtered_data[key] = value

	normalized["data"] = filtered_data
	return normalized


func _has_custom_frame_info(frame_info: Dictionary) -> bool:
	if frame_info.is_empty():
		return false

	var data = frame_info.get("data", {})
	if typeof(data) != TYPE_DICTIONARY:
		return true

	return not (data as Dictionary).is_empty()


func _dictionaries_equal(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false

	for key in a.keys():
		if not b.has(key):
			return false

		var av = a[key]
		var bv = b[key]

		if typeof(av) != typeof(bv):
			return false

		match typeof(av):
			TYPE_DICTIONARY:
				if not _dictionaries_equal(av as Dictionary, bv as Dictionary):
					return false
			TYPE_ARRAY:
				if not _arrays_equal(av as Array, bv as Array):
					return false
			_:
				if av != bv:
					return false

	return true


func _extract_priority(d: Dictionary) -> int:
	if d.has("priority"):
		return int(d.get("priority", 999999))
	return 999999


func _sort_metadata_entries(a: Dictionary, b: Dictionary) -> bool:
	var pa: int = int(a.get("priority", 999999))
	var pb: int = int(b.get("priority", 999999))
	if pa != pb:
		return pa < pb

	var la: String = str(a.get("name", a.get("definition_name", ""))).to_lower()
	var lb: String = str(b.get("name", b.get("definition_name", ""))).to_lower()
	if la != lb:
		return la < lb

	return str(a.get("json_file", "")) < str(b.get("json_file", ""))


func _format_priority_summary(priorities: Array[int]) -> String:
	if priorities.is_empty():
		return "none"

	var sorted_priorities: Array[int] = priorities.duplicate()
	sorted_priorities.sort()
	return "%d..%d" % [sorted_priorities[0], sorted_priorities[sorted_priorities.size() - 1]]


func _extract_animations(d: Dictionary) -> PackedStringArray:
	if d.has("animations"):
		return _to_packed_string_array(d["animations"])
	return DEFAULT_ANIMATIONS


func _extract_additional_animations_only(animations: PackedStringArray) -> PackedStringArray:
	var extras: PackedStringArray = []
	for animation in animations:
		if not DEFAULT_ANIMATIONS.has(animation):
			extras.append(animation)
	return _unique_packed(extras)


func _extract_additional_variants_only(variants: PackedStringArray) -> PackedStringArray:
	var extras: PackedStringArray = []
	for variant in variants:
		if not DEFAULT_VARIANTS.has(variant):
			extras.append(variant)
	return _unique_packed(extras)


func _extract_tags(d: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []

	for key in ["tags", "tag", "type_name", "name", "label", "category"]:
		if not d.has(key):
			continue

		var value = d[key]
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

	return _unique_packed(out)


func _extract_layers(d: Dictionary) -> Array[Dictionary]:
	var layers: Array[Dictionary] = []

	if d.has("layers") and typeof(d["layers"]) == TYPE_ARRAY:
		for layer in d["layers"]:
			if typeof(layer) == TYPE_DICTIONARY:
				layers.append(layer.duplicate(true))

	for key in d.keys():
		var key_str := str(key).to_lower()
		if key_str.begins_with("layer_") and typeof(d[key]) == TYPE_DICTIONARY:
			var layer_entry: Dictionary = {
				"layer_name": key,
				"data": (d[key] as Dictionary).duplicate(true)
			}
			layers.append(layer_entry)

	return layers


func _extract_frame_info(d: Dictionary, animations: PackedStringArray) -> Dictionary:
	var info: Dictionary = {}

	for key in ["frame_info", "frames", "frame_data", "animation_frames", "layout"]:
		if d.has(key) and typeof(d[key]) == TYPE_DICTIONARY:
			info["source"] = "json"
			info["data"] = d[key]
			return info

	var inferred: Dictionary = {}
	var default_layout: Dictionary = _get_default_frame_layout()

	for anim in animations:
		var base: Dictionary
		if default_layout.has(anim):
			base = (default_layout[anim] as Dictionary).duplicate(true)
		else:
			base = {
				"frame_width": 64,
				"frame_height": 64,
				"directions": 4,
				"frames_per_direction": 1
			}

		base["total_frames"] = int(base["directions"]) * int(base["frames_per_direction"])
		inferred[anim] = base

	info["source"] = "fallback"
	info["data"] = inferred
	return info


func _collect_json_files(root_path: String) -> PackedStringArray:
	var out: PackedStringArray = []
	_collect_json_files_recursive(root_path, out)
	return out


func _collect_json_files_recursive(path: String, out: PackedStringArray) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("Cannot open directory: %s" % path)
		return

	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name == "":
			break
		if name == "." or name == "..":
			continue

		var full_path := _join_path(path, name)
		if dir.current_is_dir():
			_collect_json_files_recursive(full_path, out)
		elif name.to_lower().ends_with(".json"):
			out.append(full_path)
	dir.list_dir_end()


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


func _unique_packed(input: PackedStringArray) -> PackedStringArray:
	var seen: Dictionary = {}
	var out: PackedStringArray = []

	for item in input:
		if not seen.has(item):
			seen[item] = true
			out.append(item)

	return out


func _join_path(a: String, b: String) -> String:
	if a.ends_with("/"):
		return a + b
	return a + "/" + b


func _arrays_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false

	for i in range(a.size()):
		var av = a[i]
		var bv = b[i]

		if typeof(av) != typeof(bv):
			return false

		match typeof(av):
			TYPE_DICTIONARY:
				if not _dictionaries_equal(av as Dictionary, bv as Dictionary):
					return false
			TYPE_ARRAY:
				if not _arrays_equal(av as Array, bv as Array):
					return false
			_:
				if av != bv:
					return false

	return true


func _clear_js_frame_layout_cache() -> void:
	_js_frame_layout_loaded = false
	_cached_js_frame_layout.clear()


func _get_default_frame_layout() -> Dictionary:
	var layout: Dictionary = FALLBACK_FRAME_LAYOUT.duplicate(true)
	var js_layout: Dictionary = _extract_frame_layout_from_js()
	for key in js_layout.keys():
		layout[key] = (js_layout[key] as Dictionary).duplicate(true)
	return layout

func _extract_frame_layout_from_js() -> Dictionary:
	if _js_frame_layout_loaded:
		return _cached_js_frame_layout.duplicate(true)

	_js_frame_layout_loaded = true
	_cached_js_frame_layout = {}

	if not use_js_frame_info:
		return _cached_js_frame_layout.duplicate(true)

	var js_path: String = _join_path(universal_lpc_root, custom_animations_js_relative_path)
	if custom_animations_js_relative_path.strip_edges() == "":
		return _cached_js_frame_layout.duplicate(true)
	if not FileAccess.file_exists(js_path):
		return _cached_js_frame_layout.duplicate(true)

	var text: String = FileAccess.get_file_as_string(js_path)
	if text.is_empty():
		return _cached_js_frame_layout.duplicate(true)

	print("[ULPC Metadata] Reading custom animation frame info from: %s" % js_path)

	var frame_size: int = 64
	var frame_size_regex := RegEx.new()
	if frame_size_regex.compile("const\\s+universalFrameSize\\s*=\\s*(\\d+)\\s*;") == OK:
		var frame_size_match := frame_size_regex.search(text)
		if frame_size_match:
			frame_size = int(frame_size_match.get_string(1))

	var layout: Dictionary = _extract_explicit_custom_animation_layouts(text, frame_size)
	if layout.is_empty():
		var crop_regex := RegEx.new()
		var crop_pattern := 'cropToSubSheet\\(\\s*sheet\\s*,\\s*(\\d+)\\s*\\*\\s*universalFrameSize\\s*,\\s*(\\d+)\\s*\\*\\s*universalFrameSize\\s*,\\s*[^,]+,\\s*[^,]+,\\s*"([^"]+)"'
		if crop_regex.compile(crop_pattern) == OK:
			for result in crop_regex.search_all(text):
				var total_width_units: int = int(result.get_string(1))
				var total_height_units: int = int(result.get_string(2))
				var animation_name: String = result.get_string(3)

				var frame_width: int = _infer_custom_animation_frame_width(animation_name, frame_size)
				var frame_height: int = frame_width
				var total_width_px: int = total_width_units * frame_size
				var total_height_px: int = total_height_units * frame_size
				var frames_per_direction: int = maxi(1, total_width_px / maxi(frame_width, 1))
				var directions: int = maxi(1, total_height_px / maxi(frame_height, 1))

				layout[animation_name] = {
					"directions": directions,
					"frame_height": frame_height,
					"frame_width": frame_width,
					"frames_per_direction": frames_per_direction,
					"total_frames": directions * frames_per_direction
				}

	_cached_js_frame_layout = layout.duplicate(true)
	print("[ULPC Metadata] JS custom animation count: %d" % _cached_js_frame_layout.size())
	return _cached_js_frame_layout.duplicate(true)


func _extract_explicit_custom_animation_layouts(text: String, default_frame_size: int) -> Dictionary:
	var layout: Dictionary = {}
	var anchor: String = "customAnimations"
	var anchor_index: int = text.find(anchor)
	if anchor_index == -1:
		return layout

	var object_start: int = text.find("{", anchor_index)
	if object_start == -1:
		return layout
		
	var object_end: int = _find_matching_brace(text, object_start, "{", "}")
	if object_end == -1:
		return layout

	var index: int = object_start + 1
	while index < object_end:
		while index < object_end and text.substr(index, 1) in [" ", "\n", "\r", "\t", ","]:
			index += 1
		if index >= object_end:
			break
		
		var key_start: int = index
		while index < object_end and text.substr(index, 1) != ":":
			index += 1
		if index >= object_end:
			break

		var animation_name: String = text.substr(key_start, index - key_start).strip_edges()
		animation_name = animation_name.trim_prefix('"').trim_suffix('"')
		index += 1

		while index < object_end and text.substr(index, 1) in [" ", "\n", "\r", "\t"]:
			index += 1
		if index >= object_end or text.substr(index, 1) != "{":
			continue
		
		var block_start: int = index
		var block_end: int = _find_matching_brace(text, block_start, "{", "}")
		if block_end == -1:
			break

		var block_text: String = text.substr(block_start, block_end - block_start + 1)
		index = block_end + 1

		var frame_size: int = _extract_int_from_block(block_text, ["frameSize", "frame_size", "size"])
		if frame_size <= 0:
			frame_size = _infer_custom_animation_frame_width(animation_name, default_frame_size)
		if frame_size <= 0:
			frame_size = default_frame_size

		var frames_key_index: int = block_text.find("frames")
		if frames_key_index == -1:
			continue
		
		var frames_array_start: int = block_text.find("[", frames_key_index)
		if frames_array_start == -1:
			continue

		var frames_array_end: int = _find_matching_brace(block_text, frames_array_start, "[", "]")
		if frames_array_end == -1:
			continue

		var frames_array_text: String = block_text.substr(frames_array_start, frames_array_end - frames_array_start + 1)
		var frame_rows: Array = _extract_custom_animation_frame_rows(frames_array_text)
		#print("custom animation : ", animation_name, ", frame_size :", frame_size)
		
		if frame_rows.is_empty():
			continue

		var directions: int = frame_rows.size()
		var frames_per_direction: int = 0
		for row in frame_rows:
			if typeof(row) == TYPE_ARRAY:
				frames_per_direction = maxi(frames_per_direction, (row as Array).size())

		layout[animation_name] = {
			"directions": directions,
			"frame_height": frame_size,
			"frame_width": frame_size,
			"frames_per_direction": frames_per_direction,
			"total_frames": directions * frames_per_direction,
			"frames": frame_rows.duplicate(true)
		}

	print("[ULPC Metadata] Extracted custom animation layouts: %s" % ", ".join(layout.keys()))
	return layout


func _find_matching_brace(text: String, open_index: int, open_char: String, close_char: String) -> int:
	var depth: int = 0
	for i in range(open_index, text.length()):
		var ch := text.substr(i, 1)
		if ch == open_char:
			depth += 1
		elif ch == close_char:
			depth -= 1
			if depth == 0:
				return i
	return -1

func _extract_custom_animation_frame_rows(frames_array_text: String) -> Array:
	var frame_rows: Array = []

	# Remove the outer frames array brackets first.
	if frames_array_text.length() < 2:
		return frame_rows

	var inner_text: String = frames_array_text.substr(1, frames_array_text.length() - 2)
	var index: int = 0

	while index < inner_text.length():
		while index < inner_text.length() and inner_text.substr(index, 1) in [" ", "\n", "\r", "\t", ","]:
			index += 1

		if index >= inner_text.length():
			break

		if inner_text.substr(index, 1) != "[":
			index += 1
			continue

		var row_start: int = index
		var row_end: int = _find_matching_brace(inner_text, row_start, "[", "]")
		if row_end == -1:
			break

		var row_text: String = inner_text.substr(row_start + 1, row_end - row_start - 1)
		var row_items: PackedStringArray = _extract_custom_animation_row_items(row_text)
		if not row_items.is_empty():
			var row_array: Array[String] = []
			for item in row_items:
				row_array.append(item)
			frame_rows.append(row_array)

		index = row_end + 1

	return frame_rows

func _extract_custom_animation_row_items(row_text: String) -> PackedStringArray:
	var items: PackedStringArray = []
	var current: String = ""
	var in_string: bool = false
	var escape_next: bool = false

	for i in range(row_text.length()):
		var ch := row_text.substr(i, 1)

		if in_string:
			if escape_next:
				current += ch
				escape_next = false
				continue

			if ch == "\\":
				escape_next = true
				continue

			if ch == '"':
				items.append(current)
				current = ""
				in_string = false
				continue

			current += ch
		else:
			if ch == '"':
				in_string = true

	return items


func _extract_int_from_block(block_text: String, keys: Array[String]) -> int:
	for key in keys:
		var regex := RegEx.new()
		var pattern := '(?:"%s"|%s)\\s*:\\s*(\\d+(?:\\.\\d+)?)' % [key, key]
		if regex.compile(pattern) != OK:
			continue
		var match := regex.search(block_text)
		if match:
			return int(floor(float(match.get_string(1))))
	return 0


func _infer_custom_animation_frame_width(animation_name: String, default_frame_size: int) -> int:
	var suffix_regex := RegEx.new()
	if suffix_regex.compile('(?:_|-)(\\d+)$') == OK:
		var match := suffix_regex.search(animation_name)
		if match:
			return int(match.get_string(1))
	return default_frame_size
