@tool
class_name SpeechBalloon
extends Node2D

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
		bubble_count = new_count
		_update_bubbles()
		
@export var offset: float = 20.0:
	set(new_offset):
		if is_equal_approx(offset, new_offset):
			return
		offset = new_offset
		_update_balloon_offsets()
		_update_location()

@export var text: String:
	get: return m_text
	set(new_text):
		if m_text == new_text:
			return
		m_text = new_text
		_update_text()

enum LocationEnum
{
	TOP_LEFT = 0,
	TOP_RIGHT = 1,
	BOTTOM_LEFT = 2,
	BOTTOM_RIGHT = 3,
	LEFT_TOP = 4,
	LEFT_BOTTOM = 5,
	RIGHT_TOP = 6,
	RIGHT_BOTTOM = 7
}

@export var location: LocationEnum = LocationEnum.BOTTOM_LEFT:
	get: return m_location
	set(new_location):
		if m_location == new_location:
			return
		m_location = new_location
		_update_location()
		
func close(delay: float = 0.0) -> void:
	if delay > 0:
		var timer = get_tree().create_timer(delay)
		timer.timeout.connect(self.hide)
	else:
		hide()

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
@onready var m_balloon: Control = $Balloon
@onready var m_bubble_prototype: Control = $FloatingBubble

var m_anchors: Array = [
	Control.LayoutPreset.PRESET_TOP_LEFT,
	Control.LayoutPreset.PRESET_TOP_RIGHT,
	Control.LayoutPreset.PRESET_BOTTOM_LEFT,
	Control.LayoutPreset.PRESET_BOTTOM_RIGHT,
	Control.LayoutPreset.PRESET_TOP_LEFT,
	Control.LayoutPreset.PRESET_BOTTOM_LEFT,
	Control.LayoutPreset.PRESET_TOP_RIGHT,
	Control.LayoutPreset.PRESET_BOTTOM_RIGHT,
]
var m_balloon_offsets: Array = []
var m_location: LocationEnum = LocationEnum.BOTTOM_LEFT
var m_text: String

var m_text_tween: Tween
var m_floating_bubbles: Array = []

func _ready() -> void:
	hidden.connect(func() : if delete_on_close: queue_free())

	_update_text()
	#m_label.text = m_text
	_update_bubbles()
	_update_balloon_offsets()
	_update_location()

func _update_bubbles() -> void:
	if m_bubble_prototype == null:
		return
	for bubble in m_floating_bubbles:
		if bubble == m_bubble_prototype:
			continue
		bubble.queue_free()
	m_floating_bubbles = [
		m_bubble_prototype
	]
	for i in range(bubble_count - 1):
		var new_bubble = m_bubble_prototype.duplicate(DUPLICATE_USE_INSTANTIATION)
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

func _update_text() -> void:
	if is_instance_valid(m_text_tween):
		m_text_tween.kill()
	if m_label:
		#m_label.text = m_text
		m_text_tween = m_label.create_tween()
		m_text_tween.tween_property(m_label, "text", m_text, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
func _update_location() -> void:
	if m_locations.is_empty():
		return
	for sprite in m_locations:
		sprite.visible = false
	if is_floating_bubble_enabled: 
		m_balloon.position = m_balloon_offsets[m_location]
		var control_point = m_balloon.position
		control_point.x = 0.0
		# offset end_point so the last bubble can be overlaped by the balloon 
		var end_point = m_balloon.position * Vector2(4.0, 1.5)
		var i : int = 0
		for bubble in m_floating_bubbles:
			bubble.visible = true
			var s : float = float(i) / m_floating_bubbles.size()
			bubble.size = Vector2(11.0, 11.0) + Vector2(30.0, 15.0) * s
			bubble.position = MathUtils.quadratic_bezier2(Vector2.ZERO, control_point, end_point, s) - bubble.size / 2.0
			i += 1
	else:
		m_balloon.position = Vector2.ZERO
		for bubble in m_floating_bubbles:
			bubble.visible = false
		m_locations[m_location].visible = true
	$Balloon/VBox.set_anchors_preset(m_anchors[m_location], true)
	# need to call set_offsets_preset to reposition the VBox
	$Balloon/VBox.set_offsets_preset(m_anchors[m_location], Control.PRESET_MODE_MINSIZE)
	
