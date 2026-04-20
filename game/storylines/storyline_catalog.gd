class_name StorylineCatalog
extends RefCounted

const STORYLINE_DIR := "res://game/storylines"
const STORYLINE_SUFFIX := "_storyline.gd"


static func route_display_order() -> Array[String]:
	var route_definitions := build_route_definitions()
	var entries: Array[Dictionary] = []
	for route_id_variant in route_definitions.keys():
		var route_id := String(route_id_variant)
		var route_definition: Dictionary = route_definitions.get(route_id, {})
		if route_definition is Dictionary:
			entries.append({
				"id": route_id,
				"display_order": int(route_definition.get("display_order", 9999)),
				"display_name": String(route_definition.get("display_name", route_id)),
			})
	entries.sort_custom(_sort_route_entries)
	var ordered_ids: Array[String] = []
	for entry in entries:
		ordered_ids.append(String(entry.get("id", "")))
	return ordered_ids


static func build_route_definitions() -> Dictionary:
	var route_definitions := {}
	for storyline in _load_storyline_modules():
		var route_definition: Dictionary = storyline.get("route", {})
		var route_id := String(route_definition.get("id", "")).strip_edges()
		if route_id.is_empty():
			push_warning("Skipping storyline route without an id")
			continue
		if route_definitions.has(route_id):
			push_warning("Duplicate storyline route id '%s'; keeping the latest definition" % route_id)
		route_definitions[route_id] = route_definition
	return route_definitions


static func build_event_definitions() -> Dictionary:
	var event_definitions := {}
	for storyline in _load_storyline_modules():
		var route_definition: Dictionary = storyline.get("route", {})
		var route_id := String(route_definition.get("id", "")).strip_edges()
		for event_value in storyline.get("events", []):
			if !(event_value is Dictionary):
				continue
			var event_definition: Dictionary = (event_value as Dictionary).duplicate(true)
			var event_id := String(event_definition.get("id", "")).strip_edges()
			if event_id.is_empty():
				push_warning("Skipping storyline event without an id in route '%s'" % route_id)
				continue
			if String(event_definition.get("route_id", "")).strip_edges().is_empty():
				event_definition["route_id"] = route_id
			if event_definitions.has(event_id):
				push_warning("Duplicate storyline event id '%s'; keeping the latest definition" % event_id)
			event_definitions[event_id] = event_definition
	return event_definitions


static func _load_storyline_modules() -> Array[Dictionary]:
	var modules: Array[Dictionary] = []
	for path in _discover_storyline_paths():
		var script: GDScript = load(path) as GDScript
		if script == null:
			push_warning("Failed to load storyline module %s" % path)
			continue
		if !script.can_instantiate():
			push_warning("Storyline module %s cannot be instantiated" % path)
			continue
		var instance: Object = script.new()
		if instance == null or !instance.has_method("build_storyline"):
			push_warning("Storyline module %s is missing build_storyline()" % path)
			continue
		var storyline_value = instance.call("build_storyline")
		if !(storyline_value is Dictionary):
			push_warning("Storyline module %s did not return a Dictionary" % path)
			continue
		modules.append(_normalize_storyline(path, storyline_value as Dictionary))
	modules.sort_custom(_sort_storyline_modules)
	return modules


static func _normalize_storyline(path: String, storyline_value: Dictionary) -> Dictionary:
	var storyline := storyline_value.duplicate(true)
	var route_value = storyline.get("route", {})
	var normalized_route: Dictionary = {}
	if route_value is Dictionary:
		normalized_route = (route_value as Dictionary).duplicate(true)
	var route_id := String(normalized_route.get("id", "")).strip_edges()
	normalized_route["id"] = route_id
	if !normalized_route.has("display_order"):
		normalized_route["display_order"] = 9999
	var events: Array = []
	var events_value = storyline.get("events", [])
	if events_value is Array:
		events = (events_value as Array).duplicate(true)
	return {
		"path": path,
		"route": normalized_route,
		"events": events,
	}


static func _discover_storyline_paths() -> Array[String]:
	var paths: Array[String] = []
	var directory := DirAccess.open(STORYLINE_DIR)
	if directory == null:
		push_warning("Unable to open storyline directory %s" % STORYLINE_DIR)
		return paths
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while !file_name.is_empty():
		if !directory.current_is_dir() and file_name.ends_with(STORYLINE_SUFFIX):
			paths.append("%s/%s" % [STORYLINE_DIR, file_name])
		file_name = directory.get_next()
	directory.list_dir_end()
	paths.sort()
	return paths


static func _sort_route_entries(a: Dictionary, b: Dictionary) -> bool:
	var order_a := int(a.get("display_order", 9999))
	var order_b := int(b.get("display_order", 9999))
	if order_a == order_b:
		return String(a.get("display_name", a.get("id", ""))) < String(b.get("display_name", b.get("id", "")))
	return order_a < order_b


static func _sort_storyline_modules(a: Dictionary, b: Dictionary) -> bool:
	var route_a: Dictionary = a.get("route", {})
	var route_b: Dictionary = b.get("route", {})
	var order_a := int(route_a.get("display_order", 9999))
	var order_b := int(route_b.get("display_order", 9999))
	if order_a == order_b:
		return String(route_a.get("id", "")) < String(route_b.get("id", ""))
	return order_a < order_b
