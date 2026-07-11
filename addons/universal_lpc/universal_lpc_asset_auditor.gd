@tool
class_name UniversalLpcAssetAuditor
extends RefCounted

const PLAYER_CORE_ANIMATIONS = [
	"idle",
	"walk",
	"run",
	"jump",
]

const PLAYER_SECONDARY_ANIMATIONS = [
	"hurt",
	"sit",
	"emote",
]

const SOURCE_ANIMATION_ALIASES = {
	"spellcast": ["cast"],
	"combat_idle": ["combat"],
	"backslash": ["1h_backslash"],
	"halfslash": ["1h_halfslash"],
}

const COMMON_SOURCE_ANIMATIONS = [
	"cast",
	"spellcast",
	"thrust",
	"walk",
	"slash",
	"shoot",
	"hurt",
	"watering",
	"climb",
	"idle",
	"jump",
	"sit",
	"emote",
	"run",
	"combat",
	"combat_idle",
	"backslash",
	"halfslash",
	"1h_slash",
	"1h_backslash",
	"1h_halfslash",
]

var _scan_cache: Dictionary = {}


func audit(
	universal_lpc_root: String = "res://3rdparty/Universal-LPC-Spritesheet-Character-Generator",
	sheet_definitions_dir: String = "sheet_definitions",
	spritesheets_dir: String = "spritesheets"
) -> Dictionary:
	_scan_cache.clear()

	var definitions_root := _join_path(universal_lpc_root, sheet_definitions_dir)
	var spritesheets_root := _join_path(universal_lpc_root, spritesheets_dir)
	var definition_files := _collect_json_files(definitions_root)
	definition_files.sort()

	var player_requirements := _build_player_requirement_map()
	var audited_definitions: Array[Dictionary] = []
	var missing_source_rows: Array[Dictionary] = []
	var source_rows_not_declared: Array[Dictionary] = []
	var explicit_default_subsets: Array[Dictionary] = []
	var skipped_dynamic_paths: Array[Dictionary] = []
	var player_ai_targets: Array[Dictionary] = []
	var player_metadata_targets: Array[Dictionary] = []
	var player_missing_definitions := PackedStringArray([])

	for definition_path in definition_files:
		var audited := _audit_definition(String(definition_path), definitions_root, spritesheets_root, player_requirements)
		if audited.is_empty():
			continue

		audited_definitions.append(audited)

		if bool(audited.get("has_missing_source_rows", false)):
			missing_source_rows.append(audited)
		if bool(audited.get("has_source_rows_not_declared", false)):
			source_rows_not_declared.append(audited)
		if bool(audited.get("explicit_default_subset", false)):
			explicit_default_subsets.append(audited)
		if bool(audited.get("has_dynamic_paths", false)):
			skipped_dynamic_paths.append(audited)
		if int(audited.get("player_ai_score", 0)) > 0:
			player_ai_targets.append(audited)
		if int(audited.get("player_metadata_score", 0)) > 0:
			player_metadata_targets.append(audited)
		if bool(audited.get("player_missing_definition", false)):
			player_missing_definitions.append(String(audited.get("path_string", "")))

	_sort_by_score_desc(player_ai_targets, "player_ai_score")
	_sort_by_score_desc(player_metadata_targets, "player_metadata_score")
	_sort_by_issue_count_desc(missing_source_rows)
	_sort_by_issue_count_desc(source_rows_not_declared)
	_sort_by_path(explicit_default_subsets)
	_sort_by_path(skipped_dynamic_paths)

	var player_requirement_paths := _to_packed_string_array(player_requirements.keys())
	player_requirement_paths.sort()
	for player_path in player_requirement_paths:
		var has_definition := false
		for entry in audited_definitions:
			if String(entry.get("path_string", "")) == player_path:
				has_definition = true
				break
		if not has_definition:
			player_missing_definitions.append(player_path)

	player_missing_definitions = _unique_packed(player_missing_definitions)
	player_missing_definitions.sort()

	return {
		"summary": {
			"definitions_scanned": audited_definitions.size(),
			"missing_source_row_definitions": missing_source_rows.size(),
			"source_rows_not_declared_definitions": source_rows_not_declared.size(),
			"explicit_default_subset_definitions": explicit_default_subsets.size(),
			"dynamic_path_definitions": skipped_dynamic_paths.size(),
			"player_requirement_paths": player_requirements.size(),
			"player_ai_targets": player_ai_targets.size(),
			"player_metadata_targets": player_metadata_targets.size(),
			"player_missing_definitions": player_missing_definitions.size(),
		},
		"player_requirements": player_requirements,
		"player_missing_definitions": player_missing_definitions,
		"definitions": audited_definitions,
		"missing_source_rows": missing_source_rows,
		"source_rows_not_declared": source_rows_not_declared,
		"explicit_default_subsets": explicit_default_subsets,
		"skipped_dynamic_paths": skipped_dynamic_paths,
		"player_ai_targets": player_ai_targets,
		"player_metadata_targets": player_metadata_targets,
	}


func build_markdown_report(report: Dictionary, max_entries_per_section: int = 20) -> String:
	var summary: Dictionary = report.get("summary", {})
	var lines: Array[String] = []

	lines.append("# Universal LPC Asset Audit")
	lines.append("")
	lines.append("## Summary")
	lines.append("")
	lines.append("- Definitions scanned: %d" % int(summary.get("definitions_scanned", 0)))
	lines.append("- Definitions with missing source rows: %d" % int(summary.get("missing_source_row_definitions", 0)))
	lines.append("- Definitions with source rows missing from JSON: %d" % int(summary.get("source_rows_not_declared_definitions", 0)))
	lines.append("- Definitions with explicit default-animation subsets: %d" % int(summary.get("explicit_default_subset_definitions", 0)))
	lines.append("- Definitions skipped because of dynamic source paths: %d" % int(summary.get("dynamic_path_definitions", 0)))
	lines.append("- Player-facing AI targets: %d" % int(summary.get("player_ai_targets", 0)))
	lines.append("- Player-facing metadata targets: %d" % int(summary.get("player_metadata_targets", 0)))
	lines.append("- Player requirement paths without a matching definition: %d" % int(summary.get("player_missing_definitions", 0)))

	_append_path_list_section(
		lines,
		"Player Requirement Paths Missing Definitions",
		report.get("player_missing_definitions", PackedStringArray()),
		max_entries_per_section
	)
	_append_definition_section(
		lines,
		"Top Player AI Targets",
		report.get("player_ai_targets", []),
		max_entries_per_section,
		func(entry: Dictionary) -> String:
			return _format_player_ai_entry(entry)
	)
	_append_definition_section(
		lines,
		"Top Player Metadata Targets",
		report.get("player_metadata_targets", []),
		max_entries_per_section,
		func(entry: Dictionary) -> String:
			return _format_player_metadata_entry(entry)
	)
	_append_definition_section(
		lines,
		"Definitions Missing Source Rows",
		report.get("missing_source_rows", []),
		max_entries_per_section,
		func(entry: Dictionary) -> String:
			return _format_missing_source_entry(entry)
	)
	_append_definition_section(
		lines,
		"Definitions With Source Rows Missing From JSON",
		report.get("source_rows_not_declared", []),
		max_entries_per_section,
		func(entry: Dictionary) -> String:
			return _format_metadata_gap_entry(entry)
	)
	_append_definition_section(
		lines,
		"Explicit Default-Animation Subsets",
		report.get("explicit_default_subsets", []),
		max_entries_per_section,
		func(entry: Dictionary) -> String:
			return _format_subset_entry(entry)
	)
	_append_definition_section(
		lines,
		"Definitions Skipped For Dynamic Paths",
		report.get("skipped_dynamic_paths", []),
		max_entries_per_section,
		func(entry: Dictionary) -> String:
			return _format_dynamic_entry(entry)
	)

	return "\n".join(lines).strip_edges() + "\n"


func _audit_definition(
	definition_path: String,
	definitions_root: String,
	spritesheets_root: String,
	player_requirements: Dictionary
) -> Dictionary:
	var json_text := FileAccess.get_file_as_string(definition_path)
	if json_text.is_empty():
		return {}

	var json := JSON.new()
	if json.parse(json_text) != OK:
		return {}

	if typeof(json.data) != TYPE_DICTIONARY:
		return {}

	var root: Dictionary = json.data
	var relative_path := _relative_to(definitions_root, definition_path)
	if relative_path == "":
		return {}

	var base_name := relative_path.get_file().get_basename().to_lower()
	if base_name.begins_with("meta_"):
		return {}

	var path_string := relative_path.get_basename()
	var declared_variants := _to_packed_string_array(root.get("variants", []))
	var declared_animations := _to_declared_animations(root)
	var explicit_animations := root.has("animations")
	var explicit_default_subset := _is_explicit_default_subset(root, declared_animations)
	var layers := _extract_layers(root)
	var scan_instances := _build_scan_instances(layers, spritesheets_root)
	var source_animation_names: PackedStringArray = []
	var dynamic_paths: PackedStringArray = []

	for instance_value in scan_instances:
		if typeof(instance_value) != TYPE_DICTIONARY:
			continue

		var instance: Dictionary = instance_value
		if bool(instance.get("dynamic", false)):
			dynamic_paths.append(String(instance.get("base_dir", "")))
			continue

		var scan: Dictionary = _scan_base_dir(String(instance.get("absolute_base_dir", "")))
		source_animation_names.append_array(_to_packed_string_array(scan.get("animations", [])))

	source_animation_names = _unique_packed(source_animation_names)
	source_animation_names = _filter_animation_names(source_animation_names, declared_animations)
	source_animation_names.sort()
	dynamic_paths = _unique_packed(dynamic_paths)
	dynamic_paths.sort()

	var missing_source_animations := PackedStringArray([])
	var partial_variant_animations := PackedStringArray([])
	var alias_fix_animations := PackedStringArray([])

	for animation_name in declared_animations:
		var coverage := _evaluate_animation_coverage(scan_instances, animation_name, declared_variants)
		if bool(coverage.get("all_present", false)):
			continue

		if bool(coverage.get("all_missing_instances_alias_fixable", false)):
			alias_fix_animations.append(animation_name)
		elif bool(coverage.get("any_partial_variant_gap", false)):
			partial_variant_animations.append(animation_name)
		else:
			missing_source_animations.append(animation_name)

	var undeclared_source_animations := PackedStringArray([])
	if explicit_animations:
		for source_animation in source_animation_names:
			if declared_animations.has(source_animation):
				continue
			if _is_source_animation_alias_for_declared(source_animation, declared_animations):
				continue
			undeclared_source_animations.append(source_animation)
		undeclared_source_animations = _unique_packed(undeclared_source_animations)
		undeclared_source_animations.sort()

	var player_requirement: Dictionary = player_requirements.get(path_string, {})
	var player_used_by := _to_packed_string_array(player_requirement.get("used_by", []))
	player_used_by.sort()
	var player_body_types := _to_packed_string_array(player_requirement.get("body_types", []))
	player_body_types.sort()
	var player_variants := _to_packed_string_array(player_requirement.get("variants", []))
	player_variants.sort()

	var player_missing_core := PackedStringArray([])
	var player_missing_secondary := PackedStringArray([])
	var player_alias_fix := PackedStringArray([])
	var player_metadata_gaps := PackedStringArray([])

	if not player_body_types.is_empty() or not player_variants.is_empty():
		for animation_name in PLAYER_CORE_ANIMATIONS:
			if not declared_animations.has(animation_name):
				if source_animation_names.has(animation_name):
					player_metadata_gaps.append(animation_name)
				continue

			var player_coverage := _evaluate_animation_coverage(
				_filter_instances_for_player(scan_instances, player_body_types),
				animation_name,
				player_variants
			)
			if bool(player_coverage.get("all_present", false)):
				continue
			if bool(player_coverage.get("all_missing_instances_alias_fixable", false)):
				player_alias_fix.append(animation_name)
			else:
				player_missing_core.append(animation_name)

		for animation_name in PLAYER_SECONDARY_ANIMATIONS:
			if not declared_animations.has(animation_name):
				if source_animation_names.has(animation_name):
					player_metadata_gaps.append(animation_name)
				continue

			var player_coverage := _evaluate_animation_coverage(
				_filter_instances_for_player(scan_instances, player_body_types),
				animation_name,
				player_variants
			)
			if bool(player_coverage.get("all_present", false)):
				continue
			if bool(player_coverage.get("all_missing_instances_alias_fixable", false)):
				player_alias_fix.append(animation_name)
			else:
				player_missing_secondary.append(animation_name)

		for source_animation in source_animation_names:
			if declared_animations.has(source_animation):
				continue
			if _is_source_animation_alias_for_declared(source_animation, declared_animations):
				continue
			if PLAYER_CORE_ANIMATIONS.has(source_animation) or PLAYER_SECONDARY_ANIMATIONS.has(source_animation):
				player_metadata_gaps.append(source_animation)

	player_missing_core = _unique_packed(player_missing_core)
	player_missing_core.sort()
	player_missing_secondary = _unique_packed(player_missing_secondary)
	player_missing_secondary.sort()
	player_alias_fix = _unique_packed(player_alias_fix)
	player_alias_fix.sort()
	player_metadata_gaps = _unique_packed(player_metadata_gaps)
	player_metadata_gaps.sort()

	var player_ai_score := 0
	if not player_used_by.is_empty():
		player_ai_score += player_missing_core.size() * 30
		player_ai_score += player_missing_secondary.size() * 12
		if not player_missing_core.is_empty():
			player_ai_score += 100
		elif not player_missing_secondary.is_empty():
			player_ai_score += 40

	var player_metadata_score := 0
	if not player_used_by.is_empty():
		player_metadata_score += player_metadata_gaps.size() * 18
		player_metadata_score += player_alias_fix.size() * 10
		if not player_metadata_gaps.is_empty():
			player_metadata_score += 60

	var name := String(root.get("name", path_string.get_file())).strip_edges()
	if name == "":
		name = path_string.get_file()

	return {
		"path_string": path_string,
		"json_file": relative_path,
		"name": name,
		"type_name": String(root.get("type_name", "")).strip_edges(),
		"declared_animations": declared_animations,
		"declared_variants": declared_variants,
		"explicit_animations": explicit_animations,
		"explicit_default_subset": explicit_default_subset,
		"missing_source_animations": missing_source_animations,
		"partial_variant_animations": partial_variant_animations,
		"alias_fix_animations": alias_fix_animations,
		"undeclared_source_animations": undeclared_source_animations,
		"source_animation_names": source_animation_names,
		"dynamic_paths": dynamic_paths,
		"has_missing_source_rows": not missing_source_animations.is_empty() or not partial_variant_animations.is_empty(),
		"has_source_rows_not_declared": not undeclared_source_animations.is_empty(),
		"has_dynamic_paths": not dynamic_paths.is_empty(),
		"issue_count": missing_source_animations.size() + partial_variant_animations.size() + undeclared_source_animations.size(),
		"player_used_by": player_used_by,
		"player_body_types": player_body_types,
		"player_variants": player_variants,
		"player_missing_core_animations": player_missing_core,
		"player_missing_secondary_animations": player_missing_secondary,
		"player_alias_fix_animations": player_alias_fix,
		"player_metadata_gap_animations": player_metadata_gaps,
		"player_ai_score": player_ai_score,
		"player_metadata_score": player_metadata_score,
	}


func _build_scan_instances(layers: Array[Dictionary], spritesheets_root: String) -> Array[Dictionary]:
	var instances: Array[Dictionary] = []

	for layer_value in layers:
		if typeof(layer_value) != TYPE_DICTIONARY:
			continue

		var layer: Dictionary = layer_value
		var layer_name := String(layer.get("layer_name", "layer")).strip_edges()
		var data_value = layer.get("data", {})
		if typeof(data_value) != TYPE_DICTIONARY:
			continue

		var layer_data: Dictionary = data_value
		var body_type_keys := _body_type_keys_for_layer(layer_data)
		if body_type_keys.is_empty():
			continue

		for body_type in body_type_keys:
			var body_key := String(body_type)
			var base_dir := String(layer_data.get(body_key, layer_data.get("default", ""))).strip_edges()
			if base_dir == "":
				continue

			var normalized_base_dir := _normalize_rel_dir(base_dir)
			instances.append({
				"layer_name": layer_name,
				"body_type": body_key,
				"base_dir": normalized_base_dir,
				"absolute_base_dir": _join_path(spritesheets_root, normalized_base_dir),
				"dynamic": normalized_base_dir.contains("${"),
			})

	return instances


func _body_type_keys_for_layer(layer_data: Dictionary) -> PackedStringArray:
	var keys := PackedStringArray([])

	if layer_data.has("default"):
		keys.append("default")

	for body_type in UniversalLpcMetadataGenerator.BODY_TYPES:
		if layer_data.has(body_type):
			keys.append(body_type)

	return _unique_packed(keys)


func _filter_instances_for_player(instances: Array[Dictionary], player_body_types: PackedStringArray) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []

	for instance_value in instances:
		if typeof(instance_value) != TYPE_DICTIONARY:
			continue

		var instance: Dictionary = instance_value
		var body_type := String(instance.get("body_type", ""))
		if body_type == "default" or player_body_types.has(body_type):
			filtered.append(instance)

	return filtered


func _evaluate_animation_coverage(
	instances: Array[Dictionary],
	animation_name: String,
	required_variants: PackedStringArray
) -> Dictionary:
	if instances.is_empty():
		return {
			"all_present": true,
			"all_missing_instances_alias_fixable": false,
			"any_partial_variant_gap": false,
		}

	var all_present := true
	var all_missing_instances_alias_fixable := true
	var any_partial_variant_gap := false

	for instance_value in instances:
		if typeof(instance_value) != TYPE_DICTIONARY:
			continue

		var instance: Dictionary = instance_value
		if bool(instance.get("dynamic", false)):
			continue

		var scan: Dictionary = _scan_base_dir(String(instance.get("absolute_base_dir", "")))
		var direct_support := _animation_support(scan, animation_name, required_variants)
		if bool(direct_support.get("present", false)):
			continue

		all_present = false
		if bool(direct_support.get("has_any_source", false)):
			any_partial_variant_gap = true

		var alias_support := _animation_alias_support(scan, animation_name, required_variants)
		if not bool(alias_support.get("present", false)):
			all_missing_instances_alias_fixable = false

	return {
		"all_present": all_present,
		"all_missing_instances_alias_fixable": (not all_present) and all_missing_instances_alias_fixable,
		"any_partial_variant_gap": any_partial_variant_gap,
	}


func _animation_alias_support(scan: Dictionary, animation_name: String, required_variants: PackedStringArray) -> Dictionary:
	var aliases := _to_packed_string_array(SOURCE_ANIMATION_ALIASES.get(animation_name, []))
	for alias_name in aliases:
		var support := _animation_support(scan, alias_name, required_variants)
		if bool(support.get("present", false)):
			return support
	return {
		"present": false,
		"has_any_source": false,
		"missing_variants": required_variants,
	}


func _animation_support(scan: Dictionary, animation_name: String, required_variants: PackedStringArray) -> Dictionary:
	var animation_map_value = scan.get("animation_map", {})
	if typeof(animation_map_value) != TYPE_DICTIONARY:
		return {
			"present": false,
			"has_any_source": false,
			"missing_variants": required_variants,
		}

	var animation_map: Dictionary = animation_map_value
	if not animation_map.has(animation_name):
		return {
			"present": false,
			"has_any_source": false,
			"missing_variants": required_variants,
		}

	var data_value = animation_map[animation_name]
	if typeof(data_value) != TYPE_DICTIONARY:
		return {
			"present": false,
			"has_any_source": false,
			"missing_variants": required_variants,
		}

	var animation_data: Dictionary = data_value
	var has_shared_file := bool(animation_data.get("shared_file", false))
	var source_variants := _to_packed_string_array(animation_data.get("variants", []))
	source_variants = _unique_packed(source_variants)

	if has_shared_file:
		return {
			"present": true,
			"has_any_source": true,
			"missing_variants": PackedStringArray([]),
		}

	if required_variants.is_empty():
		return {
			"present": not source_variants.is_empty(),
			"has_any_source": not source_variants.is_empty(),
			"missing_variants": PackedStringArray([]),
		}

	var missing_variants := PackedStringArray([])
	for variant in required_variants:
		var normalized_variant := _normalize_variant_name(variant)
		if source_variants.has(normalized_variant):
			continue
		missing_variants.append(variant)

	return {
		"present": missing_variants.is_empty(),
		"has_any_source": not source_variants.is_empty(),
		"missing_variants": missing_variants,
	}


func _scan_base_dir(absolute_base_dir: String) -> Dictionary:
	if _scan_cache.has(absolute_base_dir):
		return _scan_cache[absolute_base_dir]

	var result := {
		"animations": PackedStringArray([]),
		"animation_map": {},
	}

	var dir := DirAccess.open(absolute_base_dir)
	if dir == null:
		_scan_cache[absolute_base_dir] = result
		return result

	var animation_map: Dictionary = {}
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name == "":
			break
		if name == "." or name == "..":
			continue

		var lower_name := name.to_lower()
		if dir.current_is_dir():
			var animation_name := name.strip_edges()
			if animation_name == "":
				continue

			var variants := _collect_png_basenames(_join_path(absolute_base_dir, name))
			if variants.is_empty():
				continue

			var data: Dictionary = animation_map.get(animation_name, {
				"shared_file": false,
				"variants": PackedStringArray([]),
			})
			var existing_variants := _to_packed_string_array(data.get("variants", []))
			existing_variants.append_array(variants)
			data["variants"] = _unique_packed(existing_variants)
			animation_map[animation_name] = data
		elif lower_name.ends_with(".png"):
			var animation_name := name.get_basename().strip_edges()
			if animation_name == "":
				continue

			var data: Dictionary = animation_map.get(animation_name, {
				"shared_file": false,
				"variants": PackedStringArray([]),
			})
			data["shared_file"] = true
			animation_map[animation_name] = data
	dir.list_dir_end()

	var animation_names := _to_packed_string_array(animation_map.keys())
	animation_names.sort()

	result["animations"] = animation_names
	result["animation_map"] = animation_map
	_scan_cache[absolute_base_dir] = result
	return result


func _collect_png_basenames(path: String) -> PackedStringArray:
	var out := PackedStringArray([])
	var dir := DirAccess.open(path)
	if dir == null:
		return out

	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name == "":
			break
		if name == "." or name == "..":
			continue
		if dir.current_is_dir():
			continue
		if not name.to_lower().ends_with(".png"):
			continue

		out.append(_normalize_variant_name(name.get_basename()))
	dir.list_dir_end()

	return _unique_packed(out)


func _build_player_requirement_map() -> Dictionary:
	var requirements: Dictionary = {}
	var player_body_types := PackedStringArray(["male", "female", "teen"])
	var skin_variants := PackedStringArray([])
	for option_value in PlayerAppearanceCatalog.skin_tone_options():
		if typeof(option_value) != TYPE_DICTIONARY:
			continue
		skin_variants.append(String((option_value as Dictionary).get("id", "")))

	var hair_variants := PackedStringArray([])
	for option_value in PlayerAppearanceCatalog.hair_color_options():
		if typeof(option_value) != TYPE_DICTIONARY:
			continue
		hair_variants.append(String((option_value as Dictionary).get("variant", "")))

	_register_player_requirement(requirements, "body/body", player_body_types, skin_variants, "Base body")
	_register_player_requirement(requirements, PlayerAppearanceCatalog.FACE_PATH, player_body_types, skin_variants, "Base face")
	_register_player_requirement(
		requirements,
		PlayerAppearanceCatalog.MALE_HEAD_PATH,
		PackedStringArray(["male", "teen"]),
		skin_variants,
		"Masculine head"
	)
	_register_player_requirement(
		requirements,
		PlayerAppearanceCatalog.FEMALE_HEAD_PATH,
		PackedStringArray(["female", "teen"]),
		skin_variants,
		"Feminine head"
	)

	for option_value in PlayerAppearanceCatalog.hair_style_options():
		if typeof(option_value) != TYPE_DICTIONARY:
			continue

		var option: Dictionary = option_value
		var path := String(option.get("path", "")).strip_edges()
		if path == "":
			continue

		var label := "Hair style: %s" % String(option.get("display_name", option.get("id", path)))
		_register_player_requirement(requirements, path, player_body_types, hair_variants, label)

	var costume_catalog := PlayerCostumeCatalog.build_catalog()
	for costume_id in PlayerCostumeCatalog.ordered_ids():
		if not costume_catalog.has(costume_id):
			continue

		var costume_value = costume_catalog[costume_id]
		if typeof(costume_value) != TYPE_DICTIONARY:
			continue

		var costume: Dictionary = costume_value
		var selections_value = costume.get("selections", {})
		if typeof(selections_value) != TYPE_DICTIONARY:
			continue

		var costume_name := String(costume.get("display_name", costume_id))
		for path_key in selections_value.keys():
			var path := String(path_key).strip_edges()
			var variant := String(selections_value[path_key]).strip_edges()
			if path == "":
				continue

			_register_player_requirement(
				requirements,
				path,
				player_body_types,
				PackedStringArray([variant]) if variant != "" else PackedStringArray([]),
				"Costume: %s" % costume_name
			)

	return requirements


func _register_player_requirement(
	requirements: Dictionary,
	path: String,
	body_types: PackedStringArray,
	variants: PackedStringArray,
	label: String
) -> void:
	if path == "":
		return

	var entry: Dictionary = requirements.get(path, {
		"body_types": PackedStringArray([]),
		"variants": PackedStringArray([]),
		"used_by": PackedStringArray([]),
	})

	var existing_body_types := _to_packed_string_array(entry.get("body_types", []))
	existing_body_types.append_array(body_types)
	entry["body_types"] = _unique_packed(existing_body_types)

	var existing_variants := _to_packed_string_array(entry.get("variants", []))
	existing_variants.append_array(variants)
	entry["variants"] = _unique_packed(existing_variants)

	var existing_labels := _to_packed_string_array(entry.get("used_by", []))
	existing_labels.append(label)
	entry["used_by"] = _unique_packed(existing_labels)

	requirements[path] = entry


func _extract_layers(root: Dictionary) -> Array[Dictionary]:
	var layers: Array[Dictionary] = []

	if root.has("layers") and typeof(root["layers"]) == TYPE_ARRAY:
		for layer_value in root["layers"]:
			if typeof(layer_value) != TYPE_DICTIONARY:
				continue
			layers.append((layer_value as Dictionary).duplicate(true))

	for key in root.keys():
		var key_str := String(key)
		if not key_str.begins_with("layer_"):
			continue
		if typeof(root[key]) != TYPE_DICTIONARY:
			continue

		layers.append({
			"layer_name": key_str,
			"data": (root[key] as Dictionary).duplicate(true),
		})

	return layers


func _to_declared_animations(root: Dictionary) -> PackedStringArray:
	if root.has("animations"):
		return _unique_packed(_to_packed_string_array(root.get("animations", [])))
	return UniversalLpcMetadataGenerator.DEFAULT_ANIMATIONS


func _is_explicit_default_subset(root: Dictionary, declared_animations: PackedStringArray) -> bool:
	if not root.has("animations"):
		return false

	var declared_default := PackedStringArray([])
	for animation_name in declared_animations:
		if UniversalLpcMetadataGenerator.DEFAULT_ANIMATIONS.has(animation_name):
			declared_default.append(animation_name)

	declared_default = _unique_packed(declared_default)
	return not declared_default.is_empty() and declared_default.size() < UniversalLpcMetadataGenerator.DEFAULT_ANIMATIONS.size()


func _collect_json_files(root_path: String) -> PackedStringArray:
	var out := PackedStringArray([])
	_collect_json_files_recursive(root_path, out)
	return out


func _collect_json_files_recursive(path: String, out: PackedStringArray) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
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


func _append_path_list_section(lines: Array[String], title: String, paths, max_entries_per_section: int) -> void:
	var path_list := _to_packed_string_array(paths)
	if path_list.is_empty():
		return

	lines.append("")
	lines.append("## %s" % title)
	lines.append("")

	var limit := mini(max_entries_per_section, path_list.size())
	for index in range(limit):
		lines.append("- `%s`" % String(path_list[index]))
	if path_list.size() > max_entries_per_section:
		lines.append("- ... %d more" % (path_list.size() - max_entries_per_section))


func _append_definition_section(
	lines: Array[String],
	title: String,
	entries_value,
	max_entries_per_section: int,
	formatter: Callable
) -> void:
	if typeof(entries_value) != TYPE_ARRAY:
		return

	var entries: Array = entries_value
	if entries.is_empty():
		return

	lines.append("")
	lines.append("## %s" % title)
	lines.append("")

	var limit := mini(max_entries_per_section, entries.size())
	for index in range(limit):
		var entry_value = entries[index]
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		lines.append("- %s" % String(formatter.call(entry_value)))

	if entries.size() > max_entries_per_section:
		lines.append("- ... %d more" % (entries.size() - max_entries_per_section))


func _format_player_ai_entry(entry: Dictionary) -> String:
	var parts: Array[String] = []
	parts.append(_entry_label(entry))
	parts.append("used by %s" % ", ".join(_to_packed_string_array(entry.get("player_used_by", []))))

	var core := _to_packed_string_array(entry.get("player_missing_core_animations", []))
	if not core.is_empty():
		parts.append("core missing: %s" % ", ".join(core))

	var secondary := _to_packed_string_array(entry.get("player_missing_secondary_animations", []))
	if not secondary.is_empty():
		parts.append("secondary missing: %s" % ", ".join(secondary))

	return " | ".join(parts)


func _format_player_metadata_entry(entry: Dictionary) -> String:
	var parts: Array[String] = []
	parts.append(_entry_label(entry))
	parts.append("used by %s" % ", ".join(_to_packed_string_array(entry.get("player_used_by", []))))

	var metadata_gaps := _to_packed_string_array(entry.get("player_metadata_gap_animations", []))
	if not metadata_gaps.is_empty():
		parts.append("source exists but JSON omits: %s" % ", ".join(metadata_gaps))

	var alias_fixes := _to_packed_string_array(entry.get("player_alias_fix_animations", []))
	if not alias_fixes.is_empty():
		parts.append("alias/runtime fix candidate: %s" % ", ".join(alias_fixes))

	return " | ".join(parts)


func _format_missing_source_entry(entry: Dictionary) -> String:
	var parts: Array[String] = []
	parts.append(_entry_label(entry))

	var missing := _to_packed_string_array(entry.get("missing_source_animations", []))
	if not missing.is_empty():
		parts.append("missing rows: %s" % ", ".join(missing))

	var partial := _to_packed_string_array(entry.get("partial_variant_animations", []))
	if not partial.is_empty():
		parts.append("missing variants: %s" % ", ".join(partial))

	var alias_fixes := _to_packed_string_array(entry.get("alias_fix_animations", []))
	if not alias_fixes.is_empty():
		parts.append("alias fix candidate: %s" % ", ".join(alias_fixes))

	return " | ".join(parts)


func _format_metadata_gap_entry(entry: Dictionary) -> String:
	return "%s | source rows not declared: %s" % [
		_entry_label(entry),
		", ".join(_to_packed_string_array(entry.get("undeclared_source_animations", [])))
	]


func _format_subset_entry(entry: Dictionary) -> String:
	return "%s | explicit subset: %s" % [
		_entry_label(entry),
		", ".join(_to_packed_string_array(entry.get("declared_animations", [])))
	]


func _format_dynamic_entry(entry: Dictionary) -> String:
	return "%s | dynamic paths: %s" % [
		_entry_label(entry),
		", ".join(_to_packed_string_array(entry.get("dynamic_paths", [])))
	]


func _entry_label(entry: Dictionary) -> String:
	var type_name := String(entry.get("type_name", "")).strip_edges()
	if type_name != "":
		return "`%s` (%s)" % [String(entry.get("path_string", "")), type_name]
	return "`%s`" % String(entry.get("path_string", ""))


func _sort_by_score_desc(entries: Array[Dictionary], key: String) -> void:
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var av := int(a.get(key, 0))
		var bv := int(b.get(key, 0))
		if av != bv:
			return av > bv
		return String(a.get("path_string", "")) < String(b.get("path_string", ""))
	)


func _sort_by_issue_count_desc(entries: Array[Dictionary]) -> void:
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var av := int(a.get("issue_count", 0))
		var bv := int(b.get("issue_count", 0))
		if av != bv:
			return av > bv
		return String(a.get("path_string", "")) < String(b.get("path_string", ""))
	)


func _sort_by_path(entries: Array[Dictionary]) -> void:
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("path_string", "")) < String(b.get("path_string", ""))
	)


func _normalize_rel_dir(path: String) -> String:
	var normalized := path.replace("\\", "/").strip_edges()
	var has_scheme := normalized.contains("://")
	while normalized.ends_with("/"):
		normalized = normalized.left(normalized.length() - 1)
	while normalized.begins_with("/"):
		normalized = normalized.substr(1)
	while not has_scheme and normalized.find("//") != -1:
		normalized = normalized.replace("//", "/")
	return normalized


func _normalize_variant_name(variant: String) -> String:
	return variant.strip_edges().to_lower().replace(" ", "_")


func _relative_to(root: String, full_path: String) -> String:
	var normalized_root := root.replace("\\", "/")
	while normalized_root.ends_with("/"):
		normalized_root = normalized_root.left(normalized_root.length() - 1)
	var normalized_path := full_path.replace("\\", "/")
	if normalized_path.begins_with(normalized_root + "/"):
		return normalized_path.trim_prefix(normalized_root + "/")
	return normalized_path


func _join_path(left: String, right: String) -> String:
	if left == "":
		return right
	if right == "":
		return left
	return "%s/%s" % [left.trim_suffix("/"), right.trim_prefix("/")]


func _to_packed_string_array(value) -> PackedStringArray:
	var out := PackedStringArray([])

	match typeof(value):
		TYPE_STRING:
			var text := String(value).strip_edges()
			if text != "":
				out.append(text)
		TYPE_ARRAY:
			for item in value:
				var text := String(item).strip_edges()
				if text != "":
					out.append(text)
		TYPE_PACKED_STRING_ARRAY:
			for item in value:
				var text := String(item).strip_edges()
				if text != "":
					out.append(text)

	return out


func _unique_packed(values: PackedStringArray) -> PackedStringArray:
	var seen: Dictionary = {}
	var out := PackedStringArray([])
	for value in values:
		var text := String(value).strip_edges()
		if text == "" or seen.has(text):
			continue
		seen[text] = true
		out.append(text)
	return out


func _filter_animation_names(source_animation_names: PackedStringArray, declared_animations: PackedStringArray) -> PackedStringArray:
	var allowed := PackedStringArray(COMMON_SOURCE_ANIMATIONS)
	allowed.append_array(declared_animations)
	allowed.append_array(UniversalLpcMetadataGenerator.DEFAULT_ANIMATIONS)
	for alias_target in SOURCE_ANIMATION_ALIASES.keys():
		allowed.append(String(alias_target))
		allowed.append_array(_to_packed_string_array(SOURCE_ANIMATION_ALIASES[alias_target]))

	allowed = _unique_packed(allowed)

	var filtered := PackedStringArray([])
	for animation_name in source_animation_names:
		if allowed.has(animation_name):
			filtered.append(animation_name)
	return _unique_packed(filtered)


func _is_source_animation_alias_for_declared(source_animation: String, declared_animations: PackedStringArray) -> bool:
	for declared_animation in declared_animations:
		var aliases := _to_packed_string_array(SOURCE_ANIMATION_ALIASES.get(declared_animation, []))
		if aliases.has(source_animation):
			return true
	return false
