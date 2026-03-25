@tool
extends Node2D

@onready var m_reader: UniversalLpcMetadataGenerator = $metadata_generator
@onready var m_builder: LpcSpriteBuilder = $universal_lpc_sprite_builder
@onready var m_sprite: UniversalLpcSprite2D = $universal_lpc_sprite

@export var metadata_file: String = "res://resources/sprites/universal_lpc/universal_lpc_metadata.json"
@export var target_path: String = "res://resources/sprites/universal_lpc"

var m_is_loading_sprite := false


func _ready() -> void:
	#if m_builder.sprite == null:
		#m_builder.sprite = m_sprite

	if m_builder.metadata_file.strip_edges() == "":
		m_builder.metadata_file = metadata_file

	_load_metadata_json()
	_generate_selection_data()


func _get_property_list() -> Array:
	return [
		{
			"name": "generate_metadata_json",
			"type": TYPE_CALLABLE,
			"usage": PROPERTY_USAGE_EDITOR,
			"hint": PROPERTY_HINT_TOOL_BUTTON,
			"hint_string": "Generate Metadata JSON"
		},
		{
			"name": "load_metadata_json",
			"type": TYPE_CALLABLE,
			"usage": PROPERTY_USAGE_EDITOR,
			"hint": PROPERTY_HINT_TOOL_BUTTON,
			"hint_string": "Load Metadata JSON"
		}
	]


func _get(property: StringName):
	if property == "generate_metadata_json":
		return Callable(self, "_generate_metadata_json")
	if property == "load_metadata_json":
		return Callable(self, "_load_metadata_json")

	return null


func _set(_property: StringName, _value) -> bool:
	return false


func _generate_metadata_json() -> void:
	if not Engine.is_editor_hint():
		return

	if m_reader == null:
		push_error("UniversalLpcMetadataReader not found.")
		return

	print("Generating Universal LPC metadata...")

	var ok: bool = m_reader.export_metadata_as_json(metadata_file, target_path)

	if ok:
		print("Metadata JSON generated at: ", metadata_file)
	else:
		push_error("Failed to generate metadata JSON.")

func _load_metadata_json() -> void:
	if not Engine.is_editor_hint():
		return

	if metadata_file.strip_edges() == "":
		push_error("metadata_file is empty.")
		return

	if not FileAccess.file_exists(metadata_file):
		push_error("Metadata JSON not found: %s" % metadata_file)
		return

	var text: String = FileAccess.get_file_as_string(metadata_file)
	if text.is_empty():
		push_error("Metadata JSON is empty: %s" % metadata_file)
		return

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("Failed to parse metadata JSON: %s" % metadata_file)
		return

	if typeof(json.data) != TYPE_DICTIONARY:
		push_error("Metadata JSON root must be a Dictionary.")
		return

	var root: Dictionary = json.data

	UniversalLpcFactory.instance().configure(metadata_file)
	m_builder.metadata_file = metadata_file
	m_builder.load_metadata_from_root(root, m_builder.configuration)

	_generate_selection_data()

	var leaf_count := m_builder.count_leaf_items(m_builder.m_metadata.get("spritesheets", []))
	print("Loaded metadata JSON and built property tree from json_file relative path.")
	print("[ULPC Metadata Summary]")
	print("Leaf items: ", leaf_count)
	if not m_builder.m_body_types.is_empty():
		print("Body Types: ", ", ".join(m_builder.m_body_types))


func _generate_selection_data() -> void:
	if m_is_loading_sprite:
		return
	m_is_loading_sprite = true
	call_deferred("_do_load_sprite")


func _do_load_sprite() -> void:
	m_builder.load_into_sprite(metadata_file)
	m_is_loading_sprite = false
