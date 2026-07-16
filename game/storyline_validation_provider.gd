@tool
class_name KulangsuStorylineValidationProvider
extends StorylineHostValidationProvider
## Kulangsu semantic validation plugged into the generic storyline editor.

const STORY_EFFECT_SCHEMA_SCRIPT := preload("res://game/story_effect_schema.gd")
const STORY_EVENT_CATALOG_SCRIPT := preload("res://game/story_event_catalog.gd")


func validate_resource(
	_target: Object,
	catalog_context: Dictionary = {}
) -> PackedStringArray:
	return _validate_story_catalog(catalog_context)


func validate_catalog(catalog_context: Dictionary = {}) -> PackedStringArray:
	return _validate_story_catalog(catalog_context)


func _validate_story_catalog(catalog_context: Dictionary) -> PackedStringArray:
	var context := STORY_EFFECT_SCHEMA_SCRIPT.build_validation_context(catalog_context)
	return STORY_EVENT_CATALOG_SCRIPT.validate_catalog(context)
