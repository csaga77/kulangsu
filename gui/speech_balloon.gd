@tool
class_name SpeechBalloon
extends Node2D

@export var text: String:
	get:
		return m_text
	set(new_text):
		if m_text == new_text:
			return
		m_text = new_text
		_update_text()

@export var delete_on_close: bool = false

@export var is_floating_bubble_enabled: bool = false:
	set(new_floating):
		if is_floating_bubble_enabled == new_floating:
			return
		is_floating_bubble_enabled = new_floating
		_update_location()

@export var bubble_count: int = 2:
	set(new_count):
		if bubble_count == new_count:
			return
		bubble_count = max(new_count, 1)
		_update_bubbles()

@export var offset: float = 20.0:
	set(new_offset):
		if is_equal_approx(offset, new_offset):
			return
		offset = new_offset
		_update_balloon_offsets()
		_update_location()

enum LocationEnum {
	TOP_LEFT = 0,
	TOP_RIGHT = 1,
	BOTTOM_LEFT = 2,
	BOTTOM_RIGHT = 3,
	LEFT_TOP = 4,
	LEFT_BOTTOM = 5,
	RIGHT_TOP = 6,
	RIGHT_BOTTOM = 7
}

@export var anchor_location: LocationEnum = LocationEnum.BOTTOM_LEFT:
	get:
		return m_anchor_location
	set(new_location):
		if m_anchor_location == new_location:
			return
		m_anchor_location = new_location
		_update_location()

@export_group("Text Layout")
@export var max_text_width: float = 220.0:
	set(v):
		v = max(v, 1.0)
		if is_equal_approx(max_text_width, v):
			return
		max_text_width = v
		_update_text_layout()
		_update_text()

@export var horizontal_alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT:
	set(v):
		if horizontal_alignment == v:
			return
		horizontal_alignment = v
		_update_text_layout()

@export_group("Text Animation")
@export var text_characters_per_second: float = 120.0:
	set(v):
		text_characters_per_second = max(v, 0.0)

@export var text_start_delay: float = 0.0:
	set(v):
		text_start_delay = max(v, 0.0)

@export var skip_animation_in_editor: bool = true
@export var use_typewriter_animation: bool = true

@onready var m_locations: Array = [
	$Balloon/VBox/HBoxTop/TopLeft,
	$Balloon/VBox/HBoxTop/TopRight,
	$Balloon/VBox/HBoxBottom/BottomLeft,
	$Balloon/VBox/HBoxBottom/BottomRight,
	$Balloon/VBox/HBoxMid/VBoxLeft/LeftTop,
	$Balloon/VBox/HBoxMid/VBoxLeft/LeftBottom,
	$Balloon/VBox/HBoxMid/VBoxRight/RightTop,
	$Balloon/VBox/HBoxMid/VBoxRight/RightBottom
]

@onready var m_label: Label = $Balloon/VBox/HBoxMid/PanelContainer/Label
@onready var m_panel_container: PanelContainer = $Balloon/VBox/HBoxMid/PanelContainer
@onready var m_balloon: Control = $Balloon
@onready var m_balloon_content: Control = $Balloon/VBox
@onready var m_bubble_prototype: Control = $FloatingBubble

var m_balloon_offsets: Array = []
var m_anchor_location: LocationEnum = LocationEnum.BOTTOM_LEFT
var m_text: String = ""
var m_floating_bubbles: Array = []

var m_is_typing: bool = false
var m_typing_delay_remaining: float = 0.0
var m_visible_characters_float: float = 0.0

func _ready() -> void:
	hidden.connect(func() -> void:
		if delete_on_close:
			queue_free()
	)

	_update_bubbles()
	_update_balloon_offsets()
	_update_balloon_growth()
	_update_location()
	_update_text_layout()
	_update_text()
	set_process(m_is_typing)

func _process(delta: float) -> void:
	if !m_is_typing:
		return

	if m_label == null:
		m_is_typing = false
		set_process(false)
		return

	if m_typing_delay_remaining > 0.0:
		m_typing_delay_remaining -= delta
		if m_typing_delay_remaining > 0.0:
			return

	var cps: float = text_characters_per_second
	if cps <= 0.0:
		finish_text_animation()
		return

	m_visible_characters_float += cps * delta
	var visible_count: int = mini(int(floor(m_visible_characters_float)), m_text.length())
	m_label.visible_characters = visible_count
	_update_current_text_width(visible_count)

	if visible_count >= m_text.length():
		m_is_typing = false
		set_process(false)

func close(delay: float = 0.0) -> void:
	if delay > 0.0:
		var timer: SceneTreeTimer = get_tree().create_timer(delay)
		timer.timeout.connect(hide)
	else:
		hide()

func finish_text_animation() -> void:
	if m_label == null:
		return

	m_label.text = m_text
	m_label.visible_characters = -1
	_update_current_text_width(m_text.length())
	m_is_typing = false
	set_process(false)

func _update_bubbles() -> void:
	if m_bubble_prototype == null:
		return

	for bubble in m_floating_bubbles:
		if bubble == m_bubble_prototype:
			continue
		bubble.queue_free()

	m_floating_bubbles = [m_bubble_prototype]

	for i in range(bubble_count - 1):
		var new_bubble: Control = m_bubble_prototype.duplicate(DUPLICATE_USE_INSTANTIATION)
		m_floating_bubbles.append(new_bubble)
		add_child(new_bubble)

	_update_location()

func _update_balloon_offsets() -> void:
	m_balloon_offsets = [
		Vector2(offset, offset),
		Vector2(-offset, offset),
		Vector2(offset, -offset),
		Vector2(-offset, -offset),
		Vector2(offset, offset),
		Vector2(offset, -offset),
		Vector2(-offset, offset),
		Vector2(-offset, -offset),
	]

func _update_text_layout() -> void:
	if m_label == null:
		return

	m_label.horizontal_alignment = horizontal_alignment
	m_label.clip_text = false
	m_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m_label.custom_minimum_size.x = 0.0
	m_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	if m_panel_container:
		m_panel_container.custom_minimum_size.x = 0.0

func _update_text() -> void:
	if m_label == null:
		return

	_update_text_layout()
	m_label.text = m_text

	if !use_typewriter_animation:
		m_label.visible_characters = -1
		_update_current_text_width(m_text.length())
		m_is_typing = false
		set_process(false)
		return

	if Engine.is_editor_hint() and skip_animation_in_editor:
		m_label.visible_characters = -1
		_update_current_text_width(m_text.length())
		m_is_typing = false
		set_process(false)
		return

	if m_text.is_empty():
		m_label.visible_characters = -1
		_update_current_text_width(0)
		m_is_typing = false
		set_process(false)
		return

	m_visible_characters_float = 0.0
	m_typing_delay_remaining = text_start_delay
	m_label.visible_characters = 0
	_update_current_text_width(0)
	m_is_typing = true
	set_process(true)

func _update_current_text_width(visible_count: int) -> void:
	if m_label == null:
		return

	var visible_text: String = m_text.substr(0, clampi(visible_count, 0, m_text.length()))
	var target_width: float = _measure_visible_text_width(visible_text)

	if max_text_width > 0.0:
		target_width = min(target_width, max_text_width)

	target_width = max(target_width, 1.0)

	m_label.custom_minimum_size.x = target_width

	if m_panel_container:
		m_panel_container.custom_minimum_size.x = target_width

func _measure_visible_text_width(visible_text: String) -> float:
	if visible_text.is_empty():
		return 1.0

	var font: Font = m_label.get_theme_font("font")
	if font == null:
		return 1.0

	var font_size: int = m_label.get_theme_font_size("font_size")
	var max_line_width: float = 0.0
	var lines: PackedStringArray = visible_text.split("\n", false)

	if lines.is_empty():
		return 1.0

	for line in lines:
		var line_width: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		max_line_width = max(max_line_width, line_width)

	return max_line_width

func _update_balloon_growth() -> void:
	if m_balloon_content == null:
		return

	var h_grow: Control.GrowDirection = Control.GROW_DIRECTION_BOTH
	var v_grow: Control.GrowDirection = Control.GROW_DIRECTION_BOTH

	match m_anchor_location:
		LocationEnum.TOP_LEFT:
			h_grow = Control.GROW_DIRECTION_END
			v_grow = Control.GROW_DIRECTION_END
		LocationEnum.TOP_RIGHT:
			h_grow = Control.GROW_DIRECTION_BEGIN
			v_grow = Control.GROW_DIRECTION_END
		LocationEnum.BOTTOM_LEFT:
			h_grow = Control.GROW_DIRECTION_END
			v_grow = Control.GROW_DIRECTION_BEGIN
		LocationEnum.BOTTOM_RIGHT:
			h_grow = Control.GROW_DIRECTION_BEGIN
			v_grow = Control.GROW_DIRECTION_BEGIN
		LocationEnum.LEFT_TOP:
			h_grow = Control.GROW_DIRECTION_END
			v_grow = Control.GROW_DIRECTION_END
		LocationEnum.LEFT_BOTTOM:
			h_grow = Control.GROW_DIRECTION_END
			v_grow = Control.GROW_DIRECTION_BEGIN
		LocationEnum.RIGHT_TOP:
			h_grow = Control.GROW_DIRECTION_BEGIN
			v_grow = Control.GROW_DIRECTION_END
		LocationEnum.RIGHT_BOTTOM:
			h_grow = Control.GROW_DIRECTION_BEGIN
			v_grow = Control.GROW_DIRECTION_BEGIN

	m_balloon_content.grow_horizontal = h_grow
	m_balloon_content.grow_vertical = v_grow

func _update_location() -> void:
	if m_locations.is_empty():
		return

	_update_balloon_growth()

	for sprite in m_locations:
		sprite.visible = false

	if is_floating_bubble_enabled:
		m_balloon.position = m_balloon_offsets[m_anchor_location]

		var control_point: Vector2 = m_balloon.position
		control_point.x = 0.0

		var end_point: Vector2 = m_balloon.position * Vector2(4.0, 1.5)
		var i: int = 0
		for bubble in m_floating_bubbles:
			bubble.visible = true
			var s: float = float(i) / m_floating_bubbles.size()
			bubble.size = Vector2(11.0, 11.0) + Vector2(30.0, 15.0) * s
			bubble.position = MathUtils.quadratic_bezier2(
				Vector2.ZERO,
				control_point,
				end_point,
				s
			) - bubble.size / 2.0
			i += 1
	else:
		m_balloon.position = Vector2.ZERO
		for bubble in m_floating_bubbles:
			bubble.visible = false
		m_locations[m_anchor_location].visible = true
