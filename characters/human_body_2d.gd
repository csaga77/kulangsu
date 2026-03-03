# res://characters/human_body_2d.gd
@tool
class_name HumanBody2D
extends CharacterBody2D

signal global_position_changed()

const BASE_SPRITE_OFFSET: Vector2 = Vector2(0, -32)

enum FacialMoodEnum {
	MANUAL = 0, # uses builder.face_style as base
	NORMAL = 1,
	SMILE = 2,
	ANGRY = 3,
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

# ------------------------------------------------------------
# Boot guard: absolutely no builder rebuilds during load/_ready
# ------------------------------------------------------------
var m_has_ready: bool = false

# Facial controls (stay in HumanBody2D)
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

# Builder owns ALL appearance properties/styles/options/caches.
# We do NOT expose builder style properties here.
@export var sprite_builder: UniversalLPCSpriteBuilder = UniversalLPCSpriteBuilder.new():
	set(v):
		if sprite_builder == v:
			return

		if sprite_builder and sprite_builder.changed.is_connected(_on_builder_changed):
			sprite_builder.changed.disconnect(_on_builder_changed)

		sprite_builder = v

		if sprite_builder and !sprite_builder.changed.is_connected(_on_builder_changed):
			sprite_builder.changed.connect(_on_builder_changed)

		# IMPORTANT: no builder work during scene load / before ready.
		if m_has_ready and sprite_builder:
			sprite_builder.ensure_options_ready()
			_restart_face_driver()
			_reload()
			_notify_property_changed()

# Persist SpriteFrames so we don't rebuild on ready
var body_sprite_frames: Texture2D
var head_bg_sprite_frames: Dictionary
var head_sprite_frames: Dictionary

# Keep animation in HumanBody2D
@export_storage var m_animation: String = "idle_s"

# Runtime nodes
var m_body_node: AnimatedSprite2D
var m_head_bg_node: AnimatedSprite2D
var m_head_node: AnimatedSprite2D

var m_last_global_position: Vector2 = Vector2.ZERO
var m_is_currently_jumping: bool = false
var m_current_animation_name: String = ""
var m_is_reloading: bool = false

# Animation options (from factory by builder.body_type)
var m_anim_options: Array[String] = []

# Face driver
var m_face_base: String = ""
var m_face_render: String = ""

var m_action_timer: float = 0.0
var m_action_step_index: int = 0
var m_action_loops_done: int = 0
var m_action_is_running: bool = false

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
		"steps": ["base", "closing eyes", "closed eyes", "closing eyes", "base"],
		"complete_action": FacialActionEnum.NONE,
	},
	FacialActionEnum.ROLLING_EYES: {
		"step_sec": ROLL_STEP_SEC,
		"loops": 0, # infinite (NO closed-eyes step)
		"steps": ["rolling eyes", "looking left", "closing eyes", "looking right"],
		"complete_action": FacialActionEnum.NONE, # ignored when loops=0
	},
}

var m_is_notifying_property_changed := false

func _ready() -> void:
	# Keep builder reference connected (safe), but do NOT trigger any build calls.
	if sprite_builder == null:
		sprite_builder = UniversalLPCSpriteBuilder.new()
	if !sprite_builder.changed.is_connected(_on_builder_changed):
		sprite_builder.changed.connect(_on_builder_changed)

	# Create sprites if missing
	if m_head_bg_node == null:
		m_head_bg_node = AnimatedSprite2D.new()
		m_head_bg_node.name = "head_bg_sprite"
		add_child(m_head_bg_node)

	if m_body_node == null:
		m_body_node = AnimatedSprite2D.new()
		m_body_node.name = "body_sprite"
		add_child(m_body_node)

	if m_head_node == null:
		m_head_node = AnimatedSprite2D.new()
		m_head_node.name = "head_sprite"
		add_child(m_head_node)

	move_child(m_head_bg_node, 0)
	move_child(m_body_node, 1)
	move_child(m_head_node, 2)

	# Load persisted frames ONLY (no rebuild)
	m_body_node.sprite_frames = UniversalLPCSpriteFactory.create_sprite_frames_from_template(0, body_sprite_frames)
	_apply_face_switch()
	#m_head_bg_node.sprite_frames = head_bg_sprite_frames
	#m_head_node.sprite_frames = head_sprite_frames
	
	# Start face driver state, but DO NOT apply_face_switch (that can rebuild via builder)
	_restart_face_driver_no_apply()

	# Only apply animation if frames are present
	if m_body_node.sprite_frames != null:
		_apply_animation_value()

	_connect_jump_signals()
	_update_state()

	# ---- READY COMPLETE ----
	m_has_ready = true

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
	# IMPORTANT: do NOT call _apply_face_switch() here

# ------------------------------------------------------------
# Dynamic inspector properties
# - ONLY expose "animation" here
# - facial_mood / facial_action are exported already
# - builder properties are NOT exposed on this node
# ------------------------------------------------------------
func _get_property_list() -> Array:
	var property_list: Array = []

	if m_body_node == null or m_head_node == null or m_head_bg_node == null:
		return property_list

	# Avoid forcing builder work before ready; allow after ready (editor convenience)
	if m_has_ready and sprite_builder != null:
		sprite_builder.ensure_options_ready()
		_refresh_anim_options_and_clamp()

	property_list.append({
		"name": "animation",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(m_anim_options)
	})

	return property_list

func _set(property_name: StringName, value: Variant) -> bool:
	var p := String(property_name)
	var v: String = String(value) if value is String else ""

	if p == "animation":
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

func _on_builder_changed() -> void:
	# Ignore builder changes during load / before ready (prevents rebuilds)
	if !m_has_ready:
		return

	_refresh_anim_options_and_clamp()
	_restart_face_driver()
	_reload()
	_notify_property_changed()

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

# ------------------------------------------------------------
# Jump + animation state logic
# ------------------------------------------------------------
func jump() -> void:
	if m_is_currently_jumping:
		return
	m_is_currently_jumping = true
	_update_state()

func move(direction_vector: Vector2) -> void:
	var dir_vec := direction_vector
	if dir_vec.length_squared() > 0.000001:
		dir_vec = dir_vec.normalized()

	var movement_speed: float = 300.0 if is_running else 100.0
	velocity = dir_vec * movement_speed

	var sprite := _get_anim_driver()
	if sprite != null and m_is_currently_jumping and (sprite.frame <= 1 or sprite.frame == 7):
		return

	move_and_slide()

func get_texture() -> Texture2D:
	var sprite: AnimatedSprite2D = m_body_node
	if sprite == null:
		sprite = m_head_node
	if sprite == null:
		sprite = m_head_bg_node
	if sprite == null or sprite.sprite_frames == null:
		return null
	return sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)

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

func _connect_jump_signals() -> void:
	var sprite := _get_anim_driver()
	if sprite == null:
		return
	if !sprite.animation_finished.is_connected(_on_animation_finished):
		sprite.animation_finished.connect(_on_animation_finished)
	if !sprite.frame_changed.is_connected(_on_animation_frame_changed):
		sprite.frame_changed.connect(_on_animation_frame_changed)

func _on_animation_frame_changed() -> void:
	_sync_head_to_body()

	_set_sprite_offset(BASE_SPRITE_OFFSET)
	var sprite := _get_anim_driver()
	if sprite != null and m_is_currently_jumping and sprite.frame > 1 and sprite.frame < 7:
		var jump_y: float = BASE_SPRITE_OFFSET.y - (2 - abs(sprite.frame - 4)) * 16
		_set_sprite_offset(Vector2(BASE_SPRITE_OFFSET.x, jump_y))

func _on_animation_finished() -> void:
	var sprite := _get_anim_driver()
	if sprite == null:
		return
	if m_is_currently_jumping and sprite.animation.contains("jump"):
		m_is_currently_jumping = false
		_update_state()

func _refresh_anim_options_and_clamp() -> void:
	if sprite_builder == null:
		return
	var f := UniversalLPCSpriteFactory.get_instance()
	m_anim_options = f.get_animation_options(int(sprite_builder.body_type))
	m_animation = f.get_valid_style_value(m_animation, m_anim_options)

func _apply_animation_value() -> void:
	if m_body_node == null or m_head_node == null or m_head_bg_node == null:
		return
	if m_animation.is_empty():
		return
	if m_body_node.sprite_frames != null and !m_body_node.sprite_frames.has_animation(m_animation):
		return
	_update_state()

func _update_state() -> void:
	if m_body_node == null or m_head_node == null or m_head_bg_node == null:
		return

	_set_sprite_offset(BASE_SPRITE_OFFSET)

	var base_animation_name: String = "walk" if is_walking else "idle"
	if m_is_currently_jumping:
		if m_current_animation_name.contains("jump"):
			return
		base_animation_name = "jump"
	elif is_walking and is_running:
		base_animation_name = "run"

	var new_animation_name := base_animation_name + "_"
	var normalized_direction: float = CommonUtils.normalize_angle(direction)

	if CommonUtils.is_in_range(normalized_direction, 0.0, 45.01) or CommonUtils.is_in_range(normalized_direction, 314.09, 360.0):
		new_animation_name += "e"
	elif CommonUtils.is_in_range(normalized_direction, 135.0, 225.0):
		new_animation_name += "w"
	elif CommonUtils.is_in_range(normalized_direction, 45.0, 135.0):
		new_animation_name += "n"
	elif CommonUtils.is_in_range(normalized_direction, 225.0, 315.0):
		new_animation_name += "s"

	if m_current_animation_name == new_animation_name:
		return

	m_current_animation_name = new_animation_name

	if m_animation != new_animation_name:
		m_animation = new_animation_name
		_notify_property_changed()

	_stop_all_sprites()

	if m_body_node.sprite_frames and m_body_node.sprite_frames.has_animation(new_animation_name):
		m_body_node.play(new_animation_name)
	if m_head_bg_node.sprite_frames and m_head_bg_node.sprite_frames.has_animation(new_animation_name):
		m_head_bg_node.play(new_animation_name)
	if m_head_node.sprite_frames and m_head_node.sprite_frames.has_animation(new_animation_name):
		m_head_node.play(new_animation_name)

	_sync_head_to_body()

# ------------------------------------------------------------
# Sprite generation via builder
# (Never called from _ready; only after m_has_ready==true paths)
# ------------------------------------------------------------
func _reload() -> void:
	if !m_has_ready:
		return
	if m_is_reloading:
		return
	m_is_reloading = true
	call_deferred("_do_reload")

func _do_reload() -> void:
	m_is_reloading = false
	if m_body_node == null or m_head_node == null or m_head_bg_node == null or sprite_builder == null:
		return

	# Body frames (cached inside builder, persisted via export var)
	var new_body_frames := sprite_builder.build_body_frames_texture()
	if new_body_frames != null:
		body_sprite_frames = new_body_frames
		m_body_node.sprite_frames = UniversalLPCSpriteFactory.create_sprite_frames_from_template(0, body_sprite_frames)

	head_bg_sprite_frames = sprite_builder.build_head_frames_textures(true)
	head_sprite_frames = sprite_builder.build_head_frames_textures(false)
	
	# Ensure head frames match current face render (persist current)
	_apply_face_switch()

	_refresh_anim_options_and_clamp()

	# Pick a playable animation if needed
	var anim_to_play := m_animation
	if m_body_node.sprite_frames != null and (anim_to_play.is_empty() or !m_body_node.sprite_frames.has_animation(anim_to_play)):
		var packed := m_body_node.sprite_frames.get_animation_names()
		anim_to_play = String(packed[0]) if packed.size() > 0 else ""

	if !anim_to_play.is_empty():
		m_animation = anim_to_play
		m_current_animation_name = anim_to_play
		_stop_all_sprites()
		if m_body_node.sprite_frames != null and m_body_node.sprite_frames.has_animation(anim_to_play):
			m_body_node.play(anim_to_play)

	_notify_property_changed()

# ------------------------------------------------------------
# Face driver (mood + action)
# ------------------------------------------------------------
func _restart_face_driver() -> void:
	_restart_face_driver_no_apply()
	call_deferred("_apply_face_switch") # allowed outside _ready()

func _resolve_face_base_from_mood() -> void:
	if sprite_builder == null:
		m_face_base = "Human / Neutral"
		return

	# allowed outside _ready (and outside strict no-build paths)
	if m_has_ready:
		sprite_builder.ensure_options_ready()

	match int(facial_mood):
		int(FacialMoodEnum.MANUAL):
			m_face_base = sprite_builder.face_style
		int(FacialMoodEnum.NORMAL):
			m_face_base = _find_face_option_by_keywords(["neutral", "normal"])
		int(FacialMoodEnum.SMILE):
			m_face_base = _find_face_option_by_keywords(["smile", "happy"])
		int(FacialMoodEnum.ANGRY):
			m_face_base = _find_face_option_by_keywords(["angry", "mad"])
		_:
			m_face_base = sprite_builder.face_style

	if m_face_base.is_empty() or m_face_base == "<none>":
		m_face_base = "Human / Neutral"

func _resolve_face_for_step(step_name: String) -> String:
	if step_name == "base":
		return m_face_base
	return _find_face_option_by_keywords_excluding(step_name)

func _find_face_option_by_keywords(keywords: Array[String]) -> String:
	if sprite_builder == null:
		return ""
	if m_has_ready:
		sprite_builder.ensure_options_ready()
	if sprite_builder.face_options.is_empty():
		return ""

	for opt in sprite_builder.face_options:
		var s := String(opt).to_lower()
		for k in keywords:
			if s.find(String(k).to_lower()) != -1:
				return String(opt)
	return ""

func _find_face_option_by_keywords_excluding(step_name: String) -> String:
	if sprite_builder == null:
		return ""
	if m_has_ready:
		sprite_builder.ensure_options_ready()
	if sprite_builder.face_options.is_empty():
		return ""

	var needle := step_name.strip_edges().to_lower()
	if needle.is_empty():
		return ""

	for opt in sprite_builder.face_options:
		var s2 := String(opt).to_lower()
		if s2.find(needle) != -1:
			return String(opt)
	return ""

func _set_facial_action_internal(action_value: int) -> void:
	facial_action = action_value

func _advance_action_step() -> void:
	var def: Dictionary = ACTION_DEFS.get(int(facial_action), ACTION_DEFS[FacialActionEnum.NONE])
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
	# Never build head frames before ready
	if !m_has_ready:
		return
	if m_head_node == null or m_head_bg_node == null or sprite_builder == null:
		return

	var face_to_use := m_face_render
	if face_to_use.is_empty() or face_to_use == "<none>":
		face_to_use = "Human / Neutral"
	face_to_use = face_to_use.to_lower()
	var bg_texture = head_bg_sprite_frames.get(face_to_use, null)
	var fg_texture = head_sprite_frames.get(face_to_use, null)
	if fg_texture == null and !head_sprite_frames.is_empty():
		fg_texture = head_sprite_frames.get("<none>", null)
	m_head_bg_node.sprite_frames = UniversalLPCSpriteFactory.create_sprite_frames_from_template(0, bg_texture)
	m_head_node.sprite_frames = UniversalLPCSpriteFactory.create_sprite_frames_from_template(0, fg_texture)
	#print(face_to_use, ": ", m_head_node.sprite_frames)
	
	_sync_head_to_body()

# ------------------------------------------------------------
# Helpers + process/draw
# ------------------------------------------------------------
func _get_anim_driver() -> AnimatedSprite2D:
	return m_body_node

func _stop_all_sprites() -> void:
	if m_body_node != null:
		m_body_node.stop()
	if m_head_bg_node != null:
		m_head_bg_node.stop()
	if m_head_node != null:
		m_head_node.stop()

func _sync_head_to_body() -> void:
	if m_body_node == null:
		return

	var anim := m_body_node.animation
	var frame := m_body_node.frame

	if m_head_bg_node != null and m_head_bg_node.sprite_frames != null and m_head_bg_node.sprite_frames.has_animation(anim):
		if m_head_bg_node.animation != anim:
			m_head_bg_node.animation = anim
		m_head_bg_node.frame = frame

	if m_head_node != null and m_head_node.sprite_frames != null and m_head_node.sprite_frames.has_animation(anim):
		if m_head_node.animation != anim:
			m_head_node.animation = anim
		m_head_node.frame = frame

func _set_sprite_offset(offset: Vector2) -> void:
	if m_body_node != null:
		m_body_node.position = offset
	if m_head_bg_node != null:
		m_head_bg_node.position = offset
	if m_head_node != null:
		m_head_node.position = offset

func _process(delta: float) -> void:
	_sync_head_to_body()

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
