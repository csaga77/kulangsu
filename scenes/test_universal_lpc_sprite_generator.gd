@tool
extends Node2D

@onready var m_reader: UniversalLpcMetadataReader = $metadata_reader

@export var output_json_path: String = "res://universal_lpc_metadata.json"


func _get_property_list() -> Array:
	var properties: Array = []

	properties.append({
		"name": "generate_metadata_json",
		"type": TYPE_CALLABLE,
		"usage": PROPERTY_USAGE_EDITOR,
		"hint": PROPERTY_HINT_TOOL_BUTTON,
		"hint_string": "Generate Metadata JSON"
	})

	return properties


func _get(property: StringName):
	if property == "generate_metadata_json":
		return Callable(self, "_generate_metadata_json")
	return null


func _generate_metadata_json() -> void:
	if not Engine.is_editor_hint():
		return

	if m_reader == null:
		push_error("UniversalLpcMetadataReader not found.")
		return

	print("Generating Universal LPC metadata...")

	var ok: bool = m_reader.export_metadata_as_json(output_json_path)

	if ok:
		print("Metadata JSON generated at: ", output_json_path)
	else:
		push_error("Failed to generate metadata JSON.")
