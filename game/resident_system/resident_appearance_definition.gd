@tool
class_name ResidentAppearanceDefinition
extends Resource

@export var body_type: String = ""
@export var body_type_index_override: int = -1
@export var skin: String = ""
@export var head_path: String = ""
@export var hair_path: String = ""
@export var hair_color: String = ""
@export var shirt_path: String = ""
@export var shirt_color: String = ""
@export var pants_path: String = ""
@export var pants_color: String = ""
@export var shoes_path: String = ""
@export var shoes_color: String = ""
@export var extra_selections: Dictionary = {}
@export var selections: Dictionary = {}


func is_empty() -> bool:
	return body_type.is_empty() \
		and selections.is_empty() \
		and skin.is_empty() \
		and head_path.is_empty() \
		and shirt_path.is_empty() \
		and pants_path.is_empty() \
		and shoes_path.is_empty()


func to_configuration() -> Dictionary:
	if is_empty():
		return {}

	var resolved_selections := _build_selections()
	var body_type_index := body_type_index_override
	if body_type_index < 0:
		body_type_index = _resolve_body_type_index(body_type)

	return {
		"body_type": body_type,
		"body_type_index": body_type_index,
		"selections": resolved_selections,
	}


func _build_selections() -> Dictionary:
	if !selections.is_empty():
		return selections.duplicate(true)

	var built := {}
	if !skin.is_empty():
		built["body/body"] = skin
		built["head/faces/face_neutral"] = skin
	if !head_path.is_empty() and !skin.is_empty():
		built[head_path] = skin
	if !hair_path.is_empty() and !hair_color.is_empty():
		built[hair_path] = hair_color
	if !shirt_path.is_empty() and !shirt_color.is_empty():
		built[shirt_path] = shirt_color
	if !pants_path.is_empty() and !pants_color.is_empty():
		built[pants_path] = pants_color
	if !shoes_path.is_empty() and !shoes_color.is_empty():
		built[shoes_path] = shoes_color

	built.merge(extra_selections, true)
	return built


func _resolve_body_type_index(body_type_value: String) -> int:
	match body_type_value:
		"male":
			return 0
		"female":
			return 1
		"teen":
			return 2
		"child":
			return 3
		"muscular":
			return 4
		"pregnant":
			return 5
		_:
			return 0
