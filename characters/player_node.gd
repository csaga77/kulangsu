@tool
class_name Player
extends CharacterBody2D

signal global_position_changed()

@export var draw_bounding_rect: bool = false

@export var direction: float = 0.0:
	set(new_direction):
		if is_equal_approx(direction, new_direction):
			return
		direction = new_direction
		_update_state()

@export var is_walking: bool = false:
	set(new_is_walking):
		if is_walking == new_is_walking:
			return
		is_walking = new_is_walking
		_update_state()

@export var is_running: bool = false:
	set(new_is_running):
		if is_running == new_is_running:
			return
		is_running = new_is_running
		_update_state()

enum BodyTypeEnum {
	MALE = 0,
	FEMALE = 1
}

@export var body_type: BodyTypeEnum = BodyTypeEnum.MALE:
	set(new_body_type):
		if body_type == new_body_type:
			return
		body_type = new_body_type
		_refresh_all_style_options()
		_reload()

# -------------------------------------------------------------------
# Style option folders
# -------------------------------------------------------------------

const HAIR_SPRITE_FOLDER_PATH: String = "res://resources/sprites/characters/hair/"

const MALE_LEGS_FOLDER_PATH: String = "res://resources/sprites/characters/male/legs/"
const FEMALE_LEGS_FOLDER_PATH: String = "res://resources/sprites/characters/female/legs/"

const MALE_SHIRTS_FOLDER_PATH: String = "res://resources/sprites/characters/male/torso/shirts/"
const FEMALE_SHIRTS_FOLDER_PATH: String = "res://resources/sprites/characters/female/torso/shirts/"

const MALE_HEAD_FOLDER_PATH: String = "res://resources/sprites/characters/male/head/"
const FEMALE_HEAD_FOLDER_PATH: String = "res://resources/sprites/characters/female/head/"

const MALE_FEET_FOLDER_PATH: String = "res://resources/sprites/characters/male/feet/"
const FEMALE_FEET_FOLDER_PATH: String = "res://resources/sprites/characters/female/feet/"

# -------------------------------------------------------------------
# Generic style option data (not exported)
# -------------------------------------------------------------------

var hair_sprite_paths: Array[String] = []
var hair_style_names: Array[String] = []
@export_storage var hair_style_value: String = "Bald"

var legs_sprite_paths: Array[String] = []
var legs_style_names: Array[String] = []
@export_storage var legs_style_value: String = "<none>"

var shirt_sprite_paths: Array[String] = []
var shirt_style_names: Array[String] = []
@export_storage var shirt_style_value: String = "<none>"

var head_sprite_paths: Array[String] = []
var head_style_names: Array[String] = []
@export_storage var head_style_value: String = "<none>"

var feet_sprite_paths: Array[String] = []
var feet_style_names: Array[String] = []
@export_storage var feet_style_value: String = "<none>"

@export var refresh_sprite_options: bool = false:
	set(new_value):
		refresh_sprite_options = false
		if Engine.is_editor_hint():
			_refresh_all_style_options()
			_reload()

@export var hair_color: Color = Color.BLACK:
	set(new_hair_color):
		if hair_color == new_hair_color:
			return
		hair_color = new_hair_color
		_reload()

@export var legs_color: Color = Color.WHITE:
	set(new_legs_color):
		if legs_color == new_legs_color:
			return
		legs_color = new_legs_color
		_reload()

@export var shirt_color: Color = Color.WHITE:
	set(new_shirt_color):
		if shirt_color == new_shirt_color:
			return
		shirt_color = new_shirt_color
		_reload()

@export var head_color: Color = Color.WHITE:
	set(new_head_color):
		if head_color == new_head_color:
			return
		head_color = new_head_color
		_reload()

@export var feet_color: Color = Color.WHITE:
	set(new_feet_color):
		if feet_color == new_feet_color:
			return
		feet_color = new_feet_color
		_reload()

# -------------------------------------------------------------------
# Runtime state
# -------------------------------------------------------------------

var root_node: Node2D
var animated_sprite: AnimatedSprite2D
var last_global_position: Vector2 = Vector2.ZERO
var is_currently_reloading: bool = false
var is_currently_jumping: bool = false
var current_animation_name: String = ""

func _enter_tree() -> void:
	_refresh_all_style_options()

func _ready() -> void:
	root_node = self
	_refresh_all_style_options()
	_reload()

# -------------------------------------------------------------------
# Dynamic inspector enums (single inspector properties)
# -------------------------------------------------------------------

func _get_property_list() -> Array:
	var property_list: Array = []

	if hair_style_names.is_empty() \
	or legs_style_names.is_empty() \
	or shirt_style_names.is_empty() \
	or head_style_names.is_empty() \
	or feet_style_names.is_empty():
		_refresh_all_style_options()

	property_list.append({
		"name": "hair_style",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(hair_style_names)
	})

	property_list.append({
		"name": "legs_style",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(legs_style_names)
	})

	property_list.append({
		"name": "shirt_style",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(shirt_style_names)
	})

	property_list.append({
		"name": "head_style",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(head_style_names)
	})

	property_list.append({
		"name": "feet_style",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(feet_style_names)
	})

	return property_list

func _set(property_name: StringName, value: Variant) -> bool:
	var property_name_string: String = String(property_name)

	if property_name_string == "hair_style":
		var new_value: String = String(value)
		if hair_style_value == new_value:
			return true
		hair_style_value = new_value
		hair_style_value = _get_valid_style_value(hair_style_value, hair_style_names)
		_reload()
		if Engine.is_editor_hint():
			notify_property_list_changed()
		return true

	if property_name_string == "legs_style":
		var new_value: String = String(value)
		if legs_style_value == new_value:
			return true
		legs_style_value = new_value
		legs_style_value = _get_valid_style_value(legs_style_value, legs_style_names)
		_reload()
		if Engine.is_editor_hint():
			notify_property_list_changed()
		return true

	if property_name_string == "shirt_style":
		var new_value: String = String(value)
		if shirt_style_value == new_value:
			return true
		shirt_style_value = new_value
		shirt_style_value = _get_valid_style_value(shirt_style_value, shirt_style_names)
		_reload()
		if Engine.is_editor_hint():
			notify_property_list_changed()
		return true

	if property_name_string == "head_style":
		var new_value: String = String(value)
		if head_style_value == new_value:
			return true
		head_style_value = new_value
		head_style_value = _get_valid_style_value(head_style_value, head_style_names)
		_reload()
		if Engine.is_editor_hint():
			notify_property_list_changed()
		return true

	if property_name_string == "feet_style":
		var new_value: String = String(value)
		if feet_style_value == new_value:
			return true
		feet_style_value = new_value
		feet_style_value = _get_valid_style_value(feet_style_value, feet_style_names)
		_reload()
		if Engine.is_editor_hint():
			notify_property_list_changed()
		return true

	return false

func _get(property_name: StringName) -> Variant:
	var property_name_string: String = String(property_name)

	if property_name_string == "hair_style":
		return hair_style_value
	if property_name_string == "legs_style":
		return legs_style_value
	if property_name_string == "shirt_style":
		return shirt_style_value
	if property_name_string == "head_style":
		return head_style_value
	if property_name_string == "feet_style":
		return feet_style_value

	return null

# -------------------------------------------------------------------
# Generic builder
# -------------------------------------------------------------------

func _refresh_all_style_options() -> void:
	_build_style_options(
		HAIR_SPRITE_FOLDER_PATH,
		hair_sprite_paths,
		hair_style_names,
		true,
		true,
		true,
		"Bald"
	)
	hair_style_value = _get_valid_style_value(hair_style_value, hair_style_names)

	var legs_folder_path: String = _get_legs_folder_path_for_current_body()
	_build_style_options(
		legs_folder_path,
		legs_sprite_paths,
		legs_style_names,
		true,
		true,
		true,
		"<none>"
	)
	legs_style_value = _get_valid_style_value(legs_style_value, legs_style_names)

	var shirts_folder_path: String = _get_shirts_folder_path_for_current_body()
	_build_style_options(
		shirts_folder_path,
		shirt_sprite_paths,
		shirt_style_names,
		true,
		true,
		true,
		"<none>"
	)
	shirt_style_value = _get_valid_style_value(shirt_style_value, shirt_style_names)

	var head_folder_path: String = _get_head_folder_path_for_current_body()
	_build_style_options(
		head_folder_path,
		head_sprite_paths,
		head_style_names,
		true,
		true,
		true,
		"<none>"
	)
	head_style_value = _get_valid_style_value(head_style_value, head_style_names)

	var feet_folder_path: String = _get_feet_folder_path_for_current_body()
	_build_style_options(
		feet_folder_path,
		feet_sprite_paths,
		feet_style_names,
		true,
		true,
		true,
		"<none>"
	)
	feet_style_value = _get_valid_style_value(feet_style_value, feet_style_names)

	notify_property_list_changed()

func _get_legs_folder_path_for_current_body() -> String:
	return MALE_LEGS_FOLDER_PATH if body_type == BodyTypeEnum.MALE else FEMALE_LEGS_FOLDER_PATH

func _get_shirts_folder_path_for_current_body() -> String:
	return MALE_SHIRTS_FOLDER_PATH if body_type == BodyTypeEnum.MALE else FEMALE_SHIRTS_FOLDER_PATH

func _get_head_folder_path_for_current_body() -> String:
	return MALE_HEAD_FOLDER_PATH if body_type == BodyTypeEnum.MALE else FEMALE_HEAD_FOLDER_PATH

func _get_feet_folder_path_for_current_body() -> String:
	return MALE_FEET_FOLDER_PATH if body_type == BodyTypeEnum.MALE else FEMALE_FEET_FOLDER_PATH

func _build_style_options(
	folder_path: String,
	out_sprite_paths: Array[String],
	out_style_names: Array[String],
	include_empty_option: bool,
	remove_prefixes: bool,
	remove_color_suffixes: bool,
	empty_option_name: String
) -> void:
	out_sprite_paths.clear()
	out_style_names.clear()

	if include_empty_option:
		out_sprite_paths.append("")
		out_style_names.append(empty_option_name)

	var discovered_sprite_paths: Array[String] = _scan_sprite_paths(folder_path)
	for sprite_path in discovered_sprite_paths:
		out_sprite_paths.append(sprite_path)
		var file_base_name: String = sprite_path.get_file().get_basename()
		out_style_names.append(_format_style_display_name(file_base_name, remove_prefixes, remove_color_suffixes, empty_option_name))

	if out_style_names.is_empty():
		out_style_names.append(empty_option_name)

func _scan_sprite_paths(folder_path: String) -> Array[String]:
	var discovered_sprite_paths: Array[String] = []

	var directory_access: DirAccess = DirAccess.open(folder_path)
	if directory_access == null:
		return discovered_sprite_paths

	directory_access.list_dir_begin()
	var file_name: String = directory_access.get_next()

	while !file_name.is_empty():
		if !directory_access.current_is_dir():
			var lower_case_file_name: String = file_name.to_lower()
			var is_supported_image: bool = (
				lower_case_file_name.ends_with(".png")
				or lower_case_file_name.ends_with(".webp")
				or lower_case_file_name.ends_with(".jpg")
				or lower_case_file_name.ends_with(".jpeg")
			)
			if is_supported_image:
				discovered_sprite_paths.append(folder_path + file_name)

		file_name = directory_access.get_next()

	directory_access.list_dir_end()

	discovered_sprite_paths.sort()
	return discovered_sprite_paths

func _format_style_display_name(file_base_name: String, remove_prefixes: bool, remove_color_suffixes: bool, empty_option_name: String) -> String:
	var name: String = file_base_name

	if name.is_empty():
		return empty_option_name

	if remove_prefixes:
		var prefixes: Array[String] = [
			"male_",
			"female_",
			"hair_",
			"legs_",
			"shirt_",
			"head_",
			"feet_",
		]
		for prefix in prefixes:
			if name.begins_with(prefix):
				name = name.trim_prefix(prefix)
				break

	if remove_color_suffixes:
		var suffixes: Array[String] = [
			"_white",
			"_black",
			"_blonde",
			"_brown",
			"_red",
			"_blue",
			"_green"
		]
		for suffix in suffixes:
			if name.ends_with(suffix):
				name = name.trim_suffix(suffix)
				break

	name = name.replace("_", " ")

	var words: PackedStringArray = name.split(" ", false)
	for word_index in words.size():
		var word: String = words[word_index]
		if word.length() == 0:
			continue
		words[word_index] = word[0].to_upper() + word.substr(1)

	return " ".join(words)

func _get_valid_style_value(style_value: String, style_names: Array[String]) -> String:
	if style_names.is_empty():
		return style_value
	if style_names.find(style_value) != -1:
		return style_value
	return style_names[0]

# -------------------------------------------------------------------
# Style sprite selection helpers
# -------------------------------------------------------------------

func _get_selected_sprite_path(style_value: String, style_names: Array[String], sprite_paths: Array[String]) -> String:
	if style_value == "<none>":
		return ""
	if style_names.is_empty():
		return ""
	var style_index: int = style_names.find(style_value)
	if style_index < 0:
		return ""
	if style_index >= sprite_paths.size():
		return ""
	return sprite_paths[style_index]

func _get_hair_sprite_path_for_current_style() -> String:
	return _get_selected_sprite_path(hair_style_value, hair_style_names, hair_sprite_paths)

func _get_legs_sprite_path_for_current_style() -> String:
	return _get_selected_sprite_path(legs_style_value, legs_style_names, legs_sprite_paths)

func _get_shirt_sprite_path_for_current_style() -> String:
	return _get_selected_sprite_path(shirt_style_value, shirt_style_names, shirt_sprite_paths)

func _get_head_sprite_path_for_current_style() -> String:
	return _get_selected_sprite_path(head_style_value, head_style_names, head_sprite_paths)

func _get_feet_sprite_path_for_current_style() -> String:
	return _get_selected_sprite_path(feet_style_value, feet_style_names, feet_sprite_paths)

# -------------------------------------------------------------------
# Character actions and rectangles
# -------------------------------------------------------------------

func jump() -> void:
	if is_currently_jumping:
		return
	is_currently_jumping = true
	_update_state()

func move(direction_vector: Vector2) -> void:
	var normalized_direction_vector: Vector2 = direction_vector
	if normalized_direction_vector.length_squared() > 0.000001:
		normalized_direction_vector = normalized_direction_vector.normalized()

	var movement_speed: float = 300.0 if is_running else 100.0
	velocity = normalized_direction_vector * movement_speed

	if animated_sprite != null and is_currently_jumping and (animated_sprite.frame <= 1 or animated_sprite.frame == 7):
		return

	move_and_slide()

func get_texture() -> Texture2D:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return null
	return animated_sprite.sprite_frames.get_frame_texture(animated_sprite.animation, animated_sprite.frame)

func get_local_bounding_rect() -> Rect2:
	var current_texture: Texture2D = get_texture()
	if current_texture:
		var texture_size: Vector2 = current_texture.get_size()
		return Rect2(-Vector2(texture_size.x * 0.5, texture_size.y), texture_size)
	return Rect2(Vector2(-16, -64), Vector2(32, 64))

func get_bounding_rect() -> Rect2:
	var local_bounding_rect: Rect2 = get_local_bounding_rect()
	local_bounding_rect.position += global_position
	return local_bounding_rect

func get_local_ground_rect() -> Rect2:
	return Rect2(Vector2(-16, -32), Vector2(32, 32))

func get_ground_rect() -> Rect2:
	var local_ground_rect: Rect2 = get_local_ground_rect()
	local_ground_rect.position += global_position
	return local_ground_rect

# -------------------------------------------------------------------
# Reload and animation logic
# -------------------------------------------------------------------

func _reload() -> void:
	if is_currently_reloading:
		return
	is_currently_reloading = true
	call_deferred("_do_reload")

func _do_reload() -> void:
	is_currently_reloading = false
	if root_node == null:
		return

	for child_node in root_node.get_children():
		if child_node is AnimatedSprite2D:
			child_node.queue_free()

	var new_animated_sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	animated_sprite = new_animated_sprite
	root_node.add_child(animated_sprite)

	animated_sprite.position = Vector2(0, -32)
	animated_sprite.animation_finished.connect(_on_animation_finished)
	animated_sprite.frame_changed.connect(_on_animation_frame_changed)

	var sprite_frames_template: SpriteFrames = load("res://resources/animations/characters/male_animations.tres").duplicate()
	animated_sprite.sprite_frames = sprite_frames_template

	var combined_character_image: Image = null

	var body_path: String = "res://resources/sprites/characters/male/male_body.png" if body_type == BodyTypeEnum.MALE else "res://resources/sprites/characters/female/female_body.png"

	var legs_path: String = _get_legs_sprite_path_for_current_style()
	var shirt_path: String = _get_shirt_sprite_path_for_current_style()
	var head_path: String = _get_head_sprite_path_for_current_style()
	var feet_path: String = _get_feet_sprite_path_for_current_style()

	# Layer order:
	# body -> feet -> legs -> shirt -> head -> hair
	var frame_paths: Array[String] = []
	frame_paths.append(body_path)

	if !feet_path.is_empty():
		frame_paths.append(feet_path)

	if !legs_path.is_empty():
		frame_paths.append(legs_path)

	if !shirt_path.is_empty():
		frame_paths.append(shirt_path)

	if !head_path.is_empty():
		frame_paths.append(head_path)

	for texture_path in frame_paths:
		var frame_texture: Texture2D = load(texture_path)
		if frame_texture == null:
			continue

		var frame_image: Image = frame_texture.get_image()
		if frame_image == null:
			continue

		if texture_path == feet_path and !feet_path.is_empty():
			frame_image = ImageUtils.colorize_image(frame_image, feet_color)
		elif texture_path == legs_path and !legs_path.is_empty():
			frame_image = ImageUtils.colorize_image(frame_image, legs_color)
		elif texture_path == shirt_path and !shirt_path.is_empty():
			frame_image = ImageUtils.colorize_image(frame_image, shirt_color)
		elif texture_path == head_path and !head_path.is_empty():
			frame_image = ImageUtils.colorize_image(frame_image, head_color)

		if combined_character_image == null:
			combined_character_image = frame_image
		else:
			var used_rectangle: Rect2i = frame_image.get_used_rect()
			combined_character_image.blend_rect(frame_image, used_rectangle, used_rectangle.position)

	var hair_sprite_path: String = _get_hair_sprite_path_for_current_style()
	if !hair_sprite_path.is_empty() and combined_character_image != null:
		var hair_texture: Texture2D = load(hair_sprite_path)
		if hair_texture != null:
			var hair_image: Image = hair_texture.get_image()
			if hair_image != null:
				hair_image = ImageUtils.colorize_image(hair_image, hair_color)
				var hair_used_rectangle: Rect2i = hair_image.get_used_rect()
				combined_character_image.blend_rect(hair_image, hair_used_rectangle, hair_used_rectangle.position)

	if combined_character_image == null:
		return

	var combined_character_texture: ImageTexture = ImageTexture.create_from_image(combined_character_image)

	for animation_name in sprite_frames_template.get_animation_names():
		var frame_count: int = sprite_frames_template.get_frame_count(animation_name)
		for frame_index in frame_count:
			var original_frame_texture: Texture2D = sprite_frames_template.get_frame_texture(animation_name, frame_index)
			var atlas_texture: AtlasTexture = original_frame_texture.duplicate() as AtlasTexture
			if atlas_texture != null:
				atlas_texture.atlas = combined_character_texture
				sprite_frames_template.set_frame(animation_name, frame_index, atlas_texture)

	_update_state()

func _update_state() -> void:
	if animated_sprite == null:
		return

	animated_sprite.position = Vector2(0, -32)

	var base_animation_name: String = "walk" if is_walking else "idle"

	if is_currently_jumping:
		if current_animation_name.contains("jump"):
			return
		base_animation_name = "jump"
	elif is_walking and is_running:
		base_animation_name = "run"

	var new_animation_name: String = base_animation_name + "_"
	var normalized_direction: float = CommonUtils.normalize_angle(direction)

	if CommonUtils.is_in_range(normalized_direction, 0.0, 45.01) or CommonUtils.is_in_range(normalized_direction, 314.09, 360.0):
		new_animation_name += "right"
	elif CommonUtils.is_in_range(normalized_direction, 135.0, 225.0):
		new_animation_name += "left"
	elif CommonUtils.is_in_range(normalized_direction, 45.0, 135.0):
		new_animation_name += "up"
	elif CommonUtils.is_in_range(normalized_direction, 225.0, 315.0):
		new_animation_name += "down"

	if current_animation_name == new_animation_name:
		return

	current_animation_name = new_animation_name
	animated_sprite.stop()
	animated_sprite.play(new_animation_name)

func _on_animation_frame_changed() -> void:
	if animated_sprite == null:
		return
	if is_currently_jumping and animated_sprite.frame > 1 and animated_sprite.frame < 7:
		animated_sprite.position.y = -32 - (2 - abs(animated_sprite.frame - 4)) * 16

func _on_animation_finished() -> void:
	if animated_sprite == null:
		return
	if is_currently_jumping and animated_sprite.animation.contains("jump"):
		is_currently_jumping = false
		_update_state()

func _process(_delta: float) -> void:
	if !last_global_position.is_equal_approx(global_position):
		last_global_position = global_position
		global_position_changed.emit()
		if draw_bounding_rect:
			queue_redraw()

func _draw() -> void:
	if draw_bounding_rect:
		draw_rect(get_local_bounding_rect(), Color.RED, false)
		draw_rect(get_local_ground_rect(), Color.BLUE, false)
