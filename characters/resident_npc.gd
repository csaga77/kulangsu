@tool
class_name ResidentNPC
extends HumanBody2D

@export var resident_definition: Resource
@export var resident_id: StringName


func _ready() -> void:
	super._ready()
	_apply_resident_definition()


func has_definition() -> bool:
	return resident_definition != null


func apply_definition(definition, resident_id_value: String = "") -> void:
	resident_definition = definition
	if !resident_id_value.is_empty():
		resident_id = StringName(resident_id_value)
	elif resident_definition != null and !resident_definition.id.is_empty():
		resident_id = StringName(resident_definition.id)
	_apply_resident_definition()


func sync_definition_presentation() -> void:
	_apply_resident_definition()


func _apply_resident_definition() -> void:
	if resident_definition == null:
		return

	if resident_id == StringName() and !resident_definition.id.is_empty():
		resident_id = StringName(resident_definition.id)

	if !resident_definition.display_name.is_empty():
		name = resident_definition.display_name

	var appearance_config = resident_definition.build_appearance_config()
	if !appearance_config.is_empty():
		set_configuration(appearance_config)
