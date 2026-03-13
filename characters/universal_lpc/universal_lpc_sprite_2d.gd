@tool
class_name UniversalLpcSprite2D
extends Node2D

@export var metadata_file: String = "res://resources/sprites/universal_lpc/universal_lpc_metadata.json":
	set(new_file):
		if metadata_file == new_file:
			return
		metadata_file = new_file
		_reload()

signal configuration_changed(cfg: Dictionary)

func get_configuration() -> Dictionary:
	return m_configuration
	
func set_configuration(new_config: Dictionary) -> void:
	if m_configuration == new_config:
		return
	m_configuration = new_config
	_reload()
	configuration_changed.emit(m_configuration)
	
@export var configuration: Dictionary:
	get():
		return get_configuration()
	set(new_cfg):
		set_configuration(new_cfg)
		
@export_storage var animation: int = 0:
	set(value):
		var names: PackedStringArray = _get_animation_enum_names()

		if names.is_empty():
			animation = value
			return

		var max_index: int = names.size() - 1
		animation = clampi(value, 0, max_index)
		_apply_current_animation_to_sprites()

var animation_name: String:
	set(new_animation):
		var names: PackedStringArray = _get_animation_enum_names()
		if names.is_empty():
			return
		var index := names.find(new_animation)
		if index < 0:
			return
		animation = index
	get():
		var names: PackedStringArray = _get_animation_enum_names()
		if names.is_empty():
			return ""
		return names[clampi(animation, 0, names.size() - 1)]

@export_storage var m_expression: int = 0

var expression_name: String:
	set(new_expression):
		if expression_name == new_expression:
			return
		var names: PackedStringArray = _get_expression_enum_names()
		if names.is_empty():
			return
		m_expression = names.find(new_expression)
		_apply_expression_to_sprites()
	get():
		var names: PackedStringArray = _get_expression_enum_names()
		if names.is_empty():
			return ""
		return names[clampi(m_expression, 0, names.size() - 1)]

var is_playing: bool = true:
	set(value):
		is_playing = value
		_apply_play_state_to_sprites()

var m_configuration: Dictionary = {}
var m_sprite_nodes: Array[AnimatedSprite2D] = []

func _get_property_list() -> Array:
	var properties: Array = []

	properties.append({
		"name": "is_playing",
		"type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_EDITOR
	})

	var expression_names: PackedStringArray = _get_expression_enum_names()
	if not expression_names.is_empty():
		properties.append({
			"name": "expression",
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": ",".join(expression_names),
			"usage": PROPERTY_USAGE_EDITOR
		})

	var animation_names: PackedStringArray = _get_animation_enum_names()
	if not animation_names.is_empty():
		properties.append({
			"name": "animation",
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": ",".join(animation_names),
			"usage": PROPERTY_USAGE_EDITOR
		})

	return properties


func _get(property: StringName):
	if property == "animation":
		return animation

	if property == "expression":
		return m_expression

	if property == "is_playing":
		return is_playing

	return null

	
func _set(property: StringName, value) -> bool:
	if property == "animation":
		var names: PackedStringArray = _get_animation_enum_names()
		if names.is_empty():
			animation = 0
			return true

		var index: int = clampi(int(value), 0, names.size() - 1)
		animation = index
		_apply_current_animation_to_sprites()
		return true

	if property == "expression":
		var names: PackedStringArray = _get_expression_enum_names()
		if names.is_empty():
			m_expression = 0
			return true

		var index: int = clampi(int(value), 0, names.size() - 1)
		m_expression = index
		_apply_expression_to_sprites()
		return true

	if property == "is_playing":
		is_playing = bool(value)
		return true

	return false

var m_is_loading := false
func _reload() -> void:
	if m_is_loading:
		return
	m_is_loading = true
	call_deferred("_do_reload")
	
func _do_reload() -> void:
	m_is_loading = false
	#print("_realod()")
	_clear_sprites()

	if not UniversalLpcFactory.instance().configure(metadata_file):
		return

	_restore_expression_selection()

	var selections_value = m_configuration.get("selections", {})
	if typeof(selections_value) != TYPE_DICTIONARY:
		push_error("configuration_data.selections must be a Dictionary of <path string>: <variant>.")
		return

	var selections: Dictionary = selections_value
	var sprite_entries: Array[Dictionary] = []

	for path_key in selections.keys():
		var path_string: String = str(path_key).strip_edges()
		if path_string == "":
			continue

		var variant: String = str(selections[path_key]).strip_edges()
		if variant == "":
			continue

		var configured_selection: Dictionary = {
			"path_string": path_string,
			"variant": variant
		}

		var resolved_selection: Dictionary = _resolve_selection_definition(configured_selection)
		if resolved_selection.is_empty():
			continue

		var layers = resolved_selection.get("layers", [])
		if typeof(layers) != TYPE_ARRAY:
			continue

		for layer_index in range(layers.size()):
			var layer_value = layers[layer_index]
			if typeof(layer_value) != TYPE_DICTIONARY:
				continue

			var layer: Dictionary = layer_value
			var z_pos: float = _get_layer_zpos(layer)
			var priority: int = int(resolved_selection.get("priority", 999999))

			sprite_entries.append({
				"selection": resolved_selection,
				"layer": layer,
				"layer_index": layer_index,
				"z_pos": z_pos,
				"priority": priority,
				"path_string": str(resolved_selection.get("path_string", "")),
				"name": str(resolved_selection.get("name", ""))
			})

	sprite_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var az := float(a.get("z_pos", 0.0))
		var bz := float(b.get("z_pos", 0.0))
		if not is_equal_approx(az, bz):
			return az < bz

		var ap: int = int(a.get("priority", 999999))
		var bp: int = int(b.get("priority", 999999))
		if ap != bp:
			return ap < bp

		var an: String = str(a.get("name", "")).to_lower()
		var bn: String = str(b.get("name", "")).to_lower()
		if an != bn:
			return an < bn

		return str(a.get("path_string", "")).to_lower() < str(b.get("path_string", "")).to_lower()
	)

	for entry_value in sprite_entries:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue

		var entry: Dictionary = entry_value
		var selection: Dictionary = entry.get("selection", {})
		var layer: Dictionary = entry.get("layer", {})
		var layer_index: int = int(entry.get("layer_index", 0))

		var sprite: AnimatedSprite2D = _create_sprite_from_selection_layer(selection, layer, layer_index)
		if sprite == null:
			continue
		sprite.use_parent_material = true
		add_child(sprite)
		m_sprite_nodes.append(sprite)

	_restore_animation_selection()
	_apply_current_animation_to_sprites()
	notify_property_list_changed()


func _resolve_selection_definition(configured_selection: Dictionary) -> Dictionary:
	var path_string: String = str(configured_selection.get("path_string", "")).strip_edges()
	if path_string == "":
		return {}

	var definition: Dictionary = UniversalLpcFactory.instance().find_definition_by_path_string(path_string)
	if definition.is_empty():
		push_warning("Could not find definition for selection path: %s" % path_string)
		return {}

	var resolved: Dictionary = definition.duplicate(true)
	resolved["path_string"] = path_string
	resolved["variant"] = str(configured_selection.get("variant", "")).strip_edges()
	return resolved


func _restore_animation_selection() -> void:
	var names: PackedStringArray = _get_animation_enum_names()

	if names.is_empty():
		animation = 0
		return

	if animation >= 0 and animation < names.size():
		return

	animation = 0


func _restore_expression_selection() -> void:
	var names: PackedStringArray = _get_expression_enum_names()

	if names.is_empty():
		m_expression = 0
		return

	if m_expression >= 0 and m_expression < names.size():
		return

	m_expression = 0


func _create_sprite_from_selection_layer(selection: Dictionary, layer: Dictionary, layer_index: int) -> AnimatedSprite2D:
	var texture_path: String = _resolve_texture_path_from_selection_layer(selection, layer)
	if texture_path == "":
		push_warning("Failed to resolve combined texture for selection layer: %s [layer %d]" % [str(selection.get("path_string", "")), layer_index])
		return null

	var texture: Texture2D = UniversalLpcFactory.instance().get_texture(texture_path)
	if texture == null:
		return null

	var sprite_frames: SpriteFrames = _build_sprite_frames(texture)
	if sprite_frames == null:
		push_warning("Failed to build SpriteFrames for selection layer: %s [layer %d]" % [str(selection.get("path_string", "")), layer_index])
		return null

	var sprite := AnimatedSprite2D.new()
	sprite.name = "%s_layer_%d" % [str(selection.get("name", str(selection.get("path_string", "sprite")))), layer_index]
	sprite.sprite_frames = sprite_frames
	sprite.position = Vector2.ZERO
	sprite.z_index = int(round(_get_layer_zpos(layer)))
	sprite.centered = false
	sprite.set_meta("selection_data", selection.duplicate(true))
	sprite.set_meta("layer_data", layer.duplicate(true))
	sprite.set_meta("layer_index", layer_index)
	sprite.set_meta("texture_path", texture_path)

	var current_name: String = animation_name
	if current_name != "" and sprite_frames.has_animation(current_name):
		sprite.animation = current_name
	else:
		var all_names: PackedStringArray = sprite_frames.get_animation_names()
		if not all_names.is_empty():
			sprite.animation = all_names[0]

	_apply_animation_to_sprite(sprite)
	return sprite


func _build_sprite_frames(texture: Texture2D) -> SpriteFrames:
	var default_layout: Dictionary = UniversalLpcFactory.instance().get_default_frame_layout()
	if default_layout.is_empty():
		return null

	var sprite_frames := SpriteFrames.new()
	var sheet_image: Image = texture.get_image()
	if sheet_image == null or sheet_image.is_empty():
		return null

	var animation_names: PackedStringArray = UniversalLpcFactory.instance().get_base_animation_names()
	for base_animation_name in animation_names:
		var config_value = default_layout.get(base_animation_name, null)
		if typeof(config_value) != TYPE_DICTIONARY:
			continue

		var config: Dictionary = config_value
		var frame_width: int = int(config.get("frame_width", 64))
		var frame_height: int = int(config.get("frame_height", 64))
		var y_pos: int = int(config.get("y", -1))
		var directions: int = int(config.get("directions", 4))
		var frames_value = config.get("frames", [])
		var frame_cycle: Array = []

		if typeof(frames_value) == TYPE_ARRAY:
			frame_cycle = (frames_value as Array).duplicate()
		elif typeof(frames_value) == TYPE_PACKED_INT32_ARRAY:
			for item in frames_value:
				frame_cycle.append(item)

		if frame_width <= 0 or frame_height <= 0 or y_pos < 0 or frame_cycle.is_empty():
			continue

		var dir_codes: PackedStringArray = _get_direction_codes_for_animation(directions)
		for dir_index in range(dir_codes.size()):
			var dir_code: String = dir_codes[dir_index]
			var anim_key: String = "%s-%s" % [base_animation_name, dir_code]

			if not sprite_frames.has_animation(anim_key):
				sprite_frames.add_animation(anim_key)

			sprite_frames.set_animation_loop(anim_key, true)
			sprite_frames.set_animation_speed(anim_key, 8.0)

			var row_y: int = y_pos + dir_index * frame_height
			for frame_number in frame_cycle:
				var frame_index: int = int(frame_number)
				var region := Rect2i(frame_index * frame_width, row_y, frame_width, frame_height)
				if region.position.x < 0 or region.position.y < 0:
					continue
				if region.end.x > sheet_image.get_width() or region.end.y > sheet_image.get_height():
					continue

				var atlas := AtlasTexture.new()
				atlas.atlas = texture
				atlas.region = Rect2(region)
				sprite_frames.add_frame(anim_key, atlas)

	return sprite_frames


func _apply_play_state_to_sprites() -> void:
	for sprite in m_sprite_nodes:
		if not is_instance_valid(sprite):
			continue

		if is_playing:
			if sprite.sprite_frames != null and sprite.animation != StringName(""):
				sprite.play()
		else:
			sprite.stop()


func _apply_current_animation_to_sprites() -> void:
	for sprite in m_sprite_nodes:
		_apply_animation_to_sprite(sprite)


func _apply_animation_to_sprite(sprite: AnimatedSprite2D) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return

	var current_name: String = animation_name
	if current_name != "" and sprite.sprite_frames.has_animation(current_name):
		sprite.animation = current_name
	elif not sprite.sprite_frames.get_animation_names().is_empty():
		sprite.animation = sprite.sprite_frames.get_animation_names()[0]

	if is_playing:
		sprite.play()
	else:
		sprite.stop()


func _apply_expression_to_sprites() -> void:
	for sprite in m_sprite_nodes:
		if not is_instance_valid(sprite):
			continue

		var selection = sprite.get_meta("selection_data", {})
		var layer = sprite.get_meta("layer_data", {})

		if typeof(selection) != TYPE_DICTIONARY or typeof(layer) != TYPE_DICTIONARY:
			continue

		var was_playing: bool = sprite.is_playing()
		var old_animation: StringName = sprite.animation
		var old_frame: int = sprite.frame
		var old_progress: float = sprite.frame_progress

		var texture_path: String = _resolve_texture_path_from_selection_layer(selection, layer)
		if texture_path == "":
			continue

		var texture: Texture2D = UniversalLpcFactory.instance().get_texture(texture_path)
		if texture == null:
			continue
		#print(texture_path)
		var sprite_frames: SpriteFrames = _build_sprite_frames(texture)
		if sprite_frames == null:
			continue

		sprite.sprite_frames = sprite_frames
		sprite.set_meta("texture_path", texture_path)

		var target_animation: String = animation_name
		if target_animation == "":
			target_animation = str(old_animation)

		if target_animation != "" and sprite_frames.has_animation(target_animation):
			sprite.animation = target_animation
		else:
			var all_names: PackedStringArray = sprite_frames.get_animation_names()
			if not all_names.is_empty():
				sprite.animation = all_names[0]

		var frame_count: int = sprite_frames.get_frame_count(sprite.animation)
		if frame_count > 0:
			sprite.frame = clampi(old_frame, 0, frame_count - 1)
			sprite.frame_progress = old_progress

		if is_playing and was_playing:
			sprite.play()
		else:
			sprite.stop()


func _get_direction_codes_for_animation(direction_count: int) -> PackedStringArray:
	if direction_count <= 1:
		return PackedStringArray(["s"])
	return PackedStringArray(["n", "w", "s", "e"])


func _get_layer_zpos(layer: Dictionary) -> float:
	var data = layer.get("data", {})
	if typeof(data) != TYPE_DICTIONARY:
		return 0.0

	var layer_data: Dictionary = data
	if layer_data.has("zPos"):
		return float(layer_data.get("zPos", 0.0))

	return 0.0


func _resolve_texture_path_from_selection_layer(selection: Dictionary, layer: Dictionary) -> String:
	return UniversalLpcFactory.instance().resolve_texture_path(
		selection,
		layer,
		m_configuration,
		expression_name,
		Callable(self, "_get_selected_value_for_token")
	)


func _get_selected_value_for_token(token_name: String) -> String:
	if token_name == "expression":
		return expression_name

	var selections_value = m_configuration.get("selections", {})
	if typeof(selections_value) != TYPE_DICTIONARY:
		return ""

	var selections: Dictionary = selections_value
	for path_key in selections.keys():
		var path_string: String = str(path_key).strip_edges()
		if path_string == "":
			continue

		var configured_selection: Dictionary = {
			"path_string": path_string,
			"variant": str(selections[path_key]).strip_edges()
		}

		var resolved_selection: Dictionary = _resolve_selection_definition(configured_selection)
		if resolved_selection.is_empty():
			continue

		var type_name: String = str(resolved_selection.get("type_name", "")).strip_edges()
		if type_name != token_name:
			continue

		var resolved_name: String = str(resolved_selection.get("name", "")).strip_edges()
		if resolved_name != "":
			return resolved_name

		var variant: String = str(resolved_selection.get("variant", "")).strip_edges()
		if variant != "":
			return variant

	return ""


func _get_animation_enum_names() -> PackedStringArray:
	return UniversalLpcFactory.instance().get_animation_enum_names()


func _get_expression_enum_names() -> PackedStringArray:
	return UniversalLpcFactory.instance().get_expression_enum_names()


func _clear_sprites() -> void:
	for sprite in m_sprite_nodes:
		if is_instance_valid(sprite):
			sprite.queue_free()
	m_sprite_nodes.clear()

	for child in get_children():
		if child is AnimatedSprite2D:
			child.queue_free()


func _ready() -> void:
	_reload()

	if Engine.is_editor_hint():
		notify_property_list_changed()
	else:
		_apply_current_animation_to_sprites()


func _process(_delta: float) -> void:
	pass
