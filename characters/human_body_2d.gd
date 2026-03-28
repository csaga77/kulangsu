# res://characters/human_body_2d.gd
@tool
class_name HumanBody2D
extends CharacterBody2D

signal global_position_changed()

const BASE_SPRITE_OFFSET: Vector2 = Vector2(-32, -64)
const JUMP_DURATION: float = 0.55
const JUMP_HEIGHT: float = 28.0

enum FacialMoodEnum {
	MANUAL = 0,
	NORMAL = 1,
	SMILE = 2,
	BLUSH = 3,
	ANGRY = 4,
	SAD = 5,
	SHAME = 6,
	SHOCK = 7,
}

enum FacialActionEnum {
	NONE = 0,
	BLINK = 1,
	ROLLING_EYES = 2,
}

@export var draw_bounding_rect: bool = false

@export var direction: float = 0.0:
	set(v):
		if is_equal_approx(direction, v):
			return
		direction = v
		_update_state()

@export var is_walking: bool = false:
	set(v):
		if is_walking == v:
			return
		is_walking = v
		_update_state()

@export var is_running: bool = false:
	set(v):
		if is_running == v:
			return
		is_running = v
		_update_state()

var m_has_ready: bool = false

@export var facial_mood: FacialMoodEnum = FacialMoodEnum.MANUAL:
	set(v):
		if facial_mood == v:
			return
		facial_mood = v
		if m_has_ready:
			_restart_face_driver()
		else:
			_restart_face_driver_no_apply()

@export var facial_action: FacialActionEnum = FacialActionEnum.NONE:
	set(v):
		if facial_action == v:
			return
		facial_action = v
		if m_has_ready:
			_restart_face_driver()
		else:
			_restart_face_driver_no_apply()

@export var controller: BaseController:
	set(v):
		if controller == v:
			return

		if controller != null:
			controller.teardown()

		controller = v

		if is_inside_tree() and controller != null:
			controller.setup(self)
			
signal configuration_changed(cfg: Dictionary)

func get_configuration() -> Dictionary:
	if m_universal_lpc_sprite:
		return m_universal_lpc_sprite.configuration
	return m_cached_configuration.duplicate(true) if m_has_cached_configuration else {}
		
func set_configuration(new_config: Dictionary) -> void:
	m_cached_configuration = new_config.duplicate(true)
	m_has_cached_configuration = true
	if m_universal_lpc_sprite:
		m_universal_lpc_sprite.set_configuration(new_config)


@export var configuration: Dictionary:
	get():
		return get_configuration()
	set(new_config):
		set_configuration(new_config)

var m_animation: String = "idle-s"

var m_last_global_position: Vector2 = Vector2.ZERO
var m_is_currently_jumping: bool = false
var m_jump_timer: float = 0.0
var m_current_animation_name: String = ""
var m_anim_options: Array[String] = []
var m_cached_configuration: Dictionary = {}
var m_has_cached_configuration: bool = false

var m_face_base: String = ""
var m_face_render: String = ""

var m_action_timer: float = 0.0
var m_action_step_index: int = 0
var m_action_loops_done: int = 0
var m_action_is_running: bool = false

var m_universal_lpc_sprite: UniversalLpcSprite2D = null

const BLINK_STEP_SEC := 0.08
const ROLL_STEP_SEC := 0.12

const ACTION_DEFS := {
	FacialActionEnum.NONE: {
		"step_sec": 0.0,
		"loops": 1,
		"steps": ["base"],
		"complete_action": FacialActionEnum.NONE,
	},
	FacialActionEnum.BLINK: {
		"step_sec": BLINK_STEP_SEC,
		"loops": 2,
		"steps": ["base", "closing", "closed", "closing", "base"],
		"complete_action": FacialActionEnum.NONE,
	},
	FacialActionEnum.ROLLING_EYES: {
		"step_sec": ROLL_STEP_SEC,
		"loops": 0,
		"steps": ["rolling", "look_left", "closing", "look_right"],
		"complete_action": FacialActionEnum.NONE,
	},
}

var m_is_notifying_property_changed := false


func _ready() -> void:
	if controller != null:
		controller.setup(self)

	_ensure_universal_lpc_sprite()

	_restart_face_driver_no_apply()

	m_has_ready = true
	_update_state()


func _exit_tree() -> void:
	if controller != null:
		controller.teardown()


func _ensure_universal_lpc_sprite() -> void:
	if m_universal_lpc_sprite != null and is_instance_valid(m_universal_lpc_sprite):
		return

	m_universal_lpc_sprite = get_node_or_null("universal_lpc_sprite") as UniversalLpcSprite2D
	if m_universal_lpc_sprite == null:
		m_universal_lpc_sprite = UniversalLpcSprite2D.new()
		m_universal_lpc_sprite.name = "universal_lpc_sprite"
		add_child(m_universal_lpc_sprite)

	if !m_universal_lpc_sprite.configuration_changed.is_connected(_on_universal_lpc_sprite_configuration_changed):
		m_universal_lpc_sprite.configuration_changed.connect(_on_universal_lpc_sprite_configuration_changed)

	move_child(m_universal_lpc_sprite, get_child_count() - 1)
	m_universal_lpc_sprite.position = BASE_SPRITE_OFFSET
	_sync_universal_lpc_sprite_material()

	if m_has_cached_configuration:
		m_universal_lpc_sprite.set_configuration(m_cached_configuration)
	else:
		m_cached_configuration = m_universal_lpc_sprite.get_configuration().duplicate(true)
		m_has_cached_configuration = true


func _sync_universal_lpc_sprite_material() -> void:
	if m_universal_lpc_sprite == null:
		return

	m_universal_lpc_sprite.material = material


func _on_universal_lpc_sprite_configuration_changed(cfg: Dictionary) -> void:
	m_cached_configuration = cfg.duplicate(true)
	m_has_cached_configuration = true
	configuration_changed.emit(cfg)


func _restart_face_driver_no_apply() -> void:
	_resolve_face_base_from_mood()

	m_action_timer = 0.0
	m_action_step_index = 0
	m_action_loops_done = 0

	var def: Dictionary = ACTION_DEFS.get(int(facial_action), ACTION_DEFS[FacialActionEnum.NONE])
	var steps: Array = def.get("steps", ["base"])
	m_action_is_running = (int(facial_action) != int(FacialActionEnum.NONE)) and steps.size() > 0

	m_face_render = _resolve_face_for_step(String(steps[0]))
	if m_face_render.is_empty():
		m_face_render = m_face_base


func _get_property_list() -> Array:
	var property_list: Array = []

	_refresh_anim_options_and_clamp()

	property_list.append({
		"name": "animation",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_EDITOR,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(m_anim_options)
	})

	return property_list


func _set(property_name: StringName, value: Variant) -> bool:
	if property_name == "animation":
		var v: String = String(value) if value is String else ""
		if m_animation == v:
			return true
		m_animation = v
		call_deferred("_apply_animation_value")
		_notify_property_changed()
		return true
	return false


func _get(property_name: StringName) -> Variant:
	var p := String(property_name)
	if p == "animation":
		return m_animation
	return null


func _notify_property_changed() -> void:
	if !Engine.is_editor_hint():
		return
	if m_is_notifying_property_changed:
		return
	m_is_notifying_property_changed = true
	call_deferred("_do_notify_property_changed")


func _do_notify_property_changed() -> void:
	m_is_notifying_property_changed = false
	notify_property_list_changed()


func jump() -> void:
	if m_is_currently_jumping:
		return
	m_is_currently_jumping = true
	m_jump_timer = 0.0
	_update_state()


func move(direction_vector: Vector2) -> void:
	var dir_vec := direction_vector
	if dir_vec.length_squared() > 0.000001:
		dir_vec = dir_vec.normalized()

	var movement_speed: float = 300.0 if is_running else 100.0
	move_with_speed(dir_vec, movement_speed)


func move_with_speed(direction_vector: Vector2, movement_speed: float) -> void:
	var dir_vec := direction_vector
	if dir_vec.length_squared() > 0.000001:
		dir_vec = dir_vec.normalized()

	velocity = dir_vec * movement_speed
	move_and_slide()


func get_direction_vector() -> Vector2:
	return Vector2.from_angle(deg_to_rad(direction))


func set_direction_vector(vec: Vector2) -> void:
	direction = rad_to_deg(vec.angle())


func get_texture() -> Texture2D:
	if m_universal_lpc_sprite == null:
		return null

	if m_universal_lpc_sprite.has_method("get_texture"):
		var tex = m_universal_lpc_sprite.call("get_texture")
		if tex is Texture2D:
			return tex

	return null


func get_local_bounding_rect() -> Rect2:
	var current_texture: Texture2D = get_texture()
	if current_texture:
		var texture_size: Vector2 = current_texture.get_size()
		return Rect2(-Vector2(texture_size.x * 0.5, texture_size.y), texture_size)
	return Rect2(Vector2(-16, -64), Vector2(32, 64))


func get_local_ground_rect() -> Rect2:
	return Rect2(Vector2(-16, -32), Vector2(32, 32))


func get_bounding_rect() -> Rect2:
	var r: Rect2 = get_local_bounding_rect()
	r.position += global_position
	return r


func get_ground_rect() -> Rect2:
	var r: Rect2 = get_local_ground_rect()
	r.position += global_position
	return r


func _refresh_anim_options_and_clamp() -> void:
	m_anim_options.clear()

	if m_universal_lpc_sprite == null:
		return

	var names: PackedStringArray = _get_universal_enum_names("animation")
	for n in names:
		m_anim_options.append(String(n))

	if m_anim_options.is_empty():
		return

	if not m_anim_options.has(m_animation):
		m_animation = m_anim_options[0]


func _apply_animation_value() -> void:
	if m_universal_lpc_sprite == null:
		return
	if m_animation.is_empty():
		return
	_set_universal_animation_by_name(m_animation)
	_update_state()


func _update_state() -> void:
	if m_universal_lpc_sprite == null:
		return

	_set_sprite_offset(_get_current_sprite_offset())

	var base_animation_name: String = "walk"
	if not is_walking:
		base_animation_name = "idle"
	elif is_running:
		base_animation_name = "run"

	if m_is_currently_jumping:
		base_animation_name = "jump"

	var direction_suffix: String = _get_direction_suffix()
	var new_animation_name: String = "%s-%s" % [base_animation_name, direction_suffix]

	if m_current_animation_name == new_animation_name:
		return

	m_current_animation_name = new_animation_name

	if m_animation != new_animation_name:
		m_animation = new_animation_name
		_notify_property_changed()

	_set_universal_animation_by_name(new_animation_name)


func _restart_face_driver() -> void:
	_restart_face_driver_no_apply()
	call_deferred("_apply_face_switch")


func _resolve_face_base_from_mood() -> void:
	match int(facial_mood):
		int(FacialMoodEnum.MANUAL):
			m_face_base = _find_expression_by_keywords(["neutral"])
		int(FacialMoodEnum.NORMAL):
			m_face_base = _find_expression_by_keywords(["neutral", "normal"])
		int(FacialMoodEnum.SMILE):
			m_face_base = _find_expression_by_keywords(["happy", "smile"])
		int(FacialMoodEnum.BLUSH):
			m_face_base = _find_expression_by_keywords(["blush"])
		int(FacialMoodEnum.ANGRY):
			m_face_base = _find_expression_by_keywords(["angry", "anger", "mad"])
		int(FacialMoodEnum.SAD):
			m_face_base = _find_expression_by_keywords(["sad"])
		int(FacialMoodEnum.SHAME):
			m_face_base = _find_expression_by_keywords(["shame"])
		int(FacialMoodEnum.SHOCK):
			m_face_base = _find_expression_by_keywords(["shock", "surprise"])
		_:
			m_face_base = _find_expression_by_keywords(["neutral", "normal"])

	if m_face_base.is_empty():
		m_face_base = _find_first_expression_name()


func _resolve_face_for_step(step_name: String) -> String:
	if step_name == "base":
		return m_face_base

	match step_name:
		"closing":
			return _find_expression_by_keywords(["closing"])
		"closed":
			return _find_expression_by_keywords(["closed"])
		"rolling":
			return _find_expression_by_keywords(["rolling", "eyeroll"])
		"look_left":
			return _find_expression_by_keywords(["left", "look_l", "looking_left"])
		"look_right":
			return _find_expression_by_keywords(["right", "look_r", "looking_right"])

	return m_face_base


func _set_facial_action_internal(action_value: int) -> void:
	facial_action = action_value


func _advance_action_step() -> void:
	var def: Dictionary = ACTION_DEFS.get(facial_action, ACTION_DEFS[FacialActionEnum.NONE])
	var steps: Array = def.get("steps", ["base"])
	if steps.is_empty():
		m_action_is_running = false
		m_face_render = m_face_base
		_apply_face_switch()
		return

	m_action_step_index += 1
	if m_action_step_index >= steps.size():
		m_action_step_index = 0
		m_action_loops_done += 1

	var loops: int = int(def.get("loops", 1))
	if loops > 0 and m_action_loops_done >= loops:
		m_action_is_running = false
		m_face_render = m_face_base
		_apply_face_switch()

		var next_action: int = int(def.get("complete_action", FacialActionEnum.NONE))
		if next_action != int(facial_action):
			call_deferred("_set_facial_action_internal", next_action)
		return

	m_face_render = _resolve_face_for_step(String(steps[m_action_step_index]))
	if m_face_render.is_empty():
		m_face_render = m_face_base
	_apply_face_switch()


func _apply_face_switch() -> void:
	if !m_has_ready:
		return
	if m_universal_lpc_sprite == null:
		return

	var face_to_use: String = m_face_render
	if face_to_use.is_empty():
		face_to_use = m_face_base
	if face_to_use.is_empty():
		face_to_use = _find_first_expression_name()

	if face_to_use.is_empty():
		return

	_set_universal_expression_by_name(face_to_use)


func _get_current_sprite_offset() -> Vector2:
	if !m_is_currently_jumping:
		return BASE_SPRITE_OFFSET

	var t: float = clampf(m_jump_timer / JUMP_DURATION, 0.0, 1.0)
	var parabola: float = 1.0 - pow(2.0 * t - 1.0, 2.0)
	var jump_y: float = -JUMP_HEIGHT * parabola
	return BASE_SPRITE_OFFSET + Vector2(0.0, jump_y)


func _get_direction_suffix() -> String:
	var normalized_direction: float = CommonUtils.normalize_angle(direction)

	if CommonUtils.is_in_range(normalized_direction, 0.0, 45.01) or CommonUtils.is_in_range(normalized_direction, 314.09, 360.0):
		return "e"
	elif CommonUtils.is_in_range(normalized_direction, 135.0, 225.0):
		return "w"
	elif CommonUtils.is_in_range(normalized_direction, 45.0, 135.0):
		return "s"
	return "n"


func _set_sprite_offset(offset: Vector2) -> void:
	if m_universal_lpc_sprite != null:
		m_universal_lpc_sprite.position = offset


func _process(delta: float) -> void:
	if controller != null:
		controller.process(delta)

	if m_is_currently_jumping:
		m_jump_timer += delta
		if m_jump_timer >= JUMP_DURATION:
			m_jump_timer = 0.0
			m_is_currently_jumping = false
			_update_state()
		else:
			_set_sprite_offset(_get_current_sprite_offset())

	if m_action_is_running and m_has_ready:
		var def: Dictionary = ACTION_DEFS.get(int(facial_action), ACTION_DEFS[FacialActionEnum.NONE])
		var step_sec: float = float(def.get("step_sec", 0.0))
		if step_sec <= 0.00001:
			m_action_is_running = false
		else:
			m_action_timer += delta
			while m_action_timer >= step_sec:
				m_action_timer -= step_sec
				_advance_action_step()
				if !m_action_is_running:
					break

	if !m_last_global_position.is_equal_approx(global_position):
		m_last_global_position = global_position
		global_position_changed.emit()
		if draw_bounding_rect:
			queue_redraw()


func _draw() -> void:
	if draw_bounding_rect:
		draw_rect(get_local_bounding_rect(), Color.RED, false)
		draw_rect(get_local_ground_rect(), Color.BLUE, false)


func _get_universal_enum_names(property_name: String) -> PackedStringArray:
	var out: PackedStringArray = []
	if m_universal_lpc_sprite == null:
		return out

	for prop in m_universal_lpc_sprite.get_property_list():
		if typeof(prop) != TYPE_DICTIONARY:
			continue
		if str(prop.get("name", "")) != property_name:
			continue

		if int(prop.get("hint", PROPERTY_HINT_NONE)) != PROPERTY_HINT_ENUM:
			return out

		var hint_string: String = str(prop.get("hint_string", ""))
		if hint_string.is_empty():
			return out

		var parts: PackedStringArray = hint_string.split(",")
		for part in parts:
			var clean_part: String = String(part).strip_edges()
			if !clean_part.is_empty():
				out.append(clean_part)
		return out

	return out


func _find_first_expression_name() -> String:
	var names: PackedStringArray = _get_universal_enum_names("expression")
	return "" if names.is_empty() else String(names[0])


func _find_expression_by_keywords(keywords: Array[String]) -> String:
	var names: PackedStringArray = _get_universal_enum_names("expression")
	if names.is_empty():
		return ""

	for name in names:
		var lowered: String = String(name).to_lower()
		for keyword in keywords:
			var k: String = String(keyword).to_lower()
			if lowered.find(k) != -1:
				return String(name)

	return ""


func _set_universal_animation_by_name(animation_name: String) -> void:
	if m_universal_lpc_sprite == null or animation_name.is_empty():
		return
	m_universal_lpc_sprite.animation_name = animation_name

func _set_universal_expression_by_name(expression_name: String) -> void:
	if m_universal_lpc_sprite == null or expression_name.is_empty():
		return
	#print_debug(expression_name)
	m_universal_lpc_sprite.expression_name = expression_name

func _name_matches(a: String, b: String) -> bool:
	var a1: String = a.to_lower().replace("_", "").replace("-", "").replace(" ", "")
	var b1: String = b.to_lower().replace("_", "").replace("-", "").replace(" ", "")
	return a1 == b1
