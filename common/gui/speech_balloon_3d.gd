class_name SpeechBalloon3D
extends Node3D

# Phase E of docs/plan/low_poly_3d_replacement.md: world-anchored dialogue for the
# 3D lane. The 2D SpeechBalloon is an atlas-based Node2D UI; this 3D counterpart is
# a camera-facing text label with a translucent background panel that floats above
# an actor and auto-hides. It carries no story logic — the world scene feeds it the
# line returned by the shared story services.
#
# Tuning: raise TEXT_WORLD_SIZE to make the text bigger, lower it to shrink. The
# background quad resizes itself to the text automatically.

const DEFAULT_DURATION := 3.5

# World-space height of one text line, in metres. The whole balloon scales from this.
const TEXT_WORLD_SIZE := 0.42
# Text wrapping width in the label's virtual pixels (world width = WRAP_PIXELS * pixel_size).
const WRAP_PIXELS := 260.0
const FONT_PIXELS := 48
# Extra background around the text, in metres.
const BG_PADDING := Vector2(0.14, 0.08)

const TEXT_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const OUTLINE_COLOR := Color(0.03, 0.03, 0.05, 1.0)
const OUTLINE_PIXELS := 22
# White background at 80% transparency (alpha 0.2).
const BG_COLOR := Color(1.0, 1.0, 1.0, 0.2)

# The balloon counter-scales to the camera so it keeps a constant on-screen size at
# any zoom. This reference is the default overworld orthographic size (scale 1.0),
# and the perspective fallback distance for non-orthographic cameras.
const REFERENCE_ORTHO_SIZE := 36.0
const REFERENCE_DISTANCE := 34.0

var m_label: Label3D = null
var m_background: MeshInstance3D = null
var m_remaining := 0.0


func _ready() -> void:
	var pixel_size := TEXT_WORLD_SIZE / float(FONT_PIXELS)

	m_background = MeshInstance3D.new()
	m_background.mesh = QuadMesh.new()
	var bg_material := StandardMaterial3D.new()
	bg_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg_material.albedo_color = BG_COLOR
	bg_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	bg_material.no_depth_test = true
	bg_material.render_priority = 0
	m_background.material_override = bg_material
	add_child(m_background)

	m_label = Label3D.new()
	m_label.pixel_size = pixel_size
	m_label.font_size = FONT_PIXELS
	m_label.outline_size = OUTLINE_PIXELS
	m_label.modulate = TEXT_COLOR
	m_label.outline_modulate = OUTLINE_COLOR
	m_label.no_depth_test = true
	m_label.render_priority = 1
	m_label.outline_render_priority = 1
	m_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	m_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	m_label.width = WRAP_PIXELS
	add_child(m_label)

	visible = false
	set_process(false)


func show_line(line: String, duration := DEFAULT_DURATION) -> void:
	if m_label == null:
		return
	m_label.text = line
	visible = true
	m_remaining = duration
	set_process(true)
	_resize_background()


func _process(delta: float) -> void:
	_face_camera()
	_resize_background()
	m_remaining -= delta
	if m_remaining <= 0.0:
		visible = false
		set_process(false)


# Keep the balloon's plane parallel to the active camera so text and background
# always face the viewer, and counter-scale to the camera so the balloon holds a
# constant on-screen size at any zoom. Text and background scale together because
# the background is sized from the label's local AABB before this scale is applied.
func _face_camera() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var scale_factor := 1.0
	if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		scale_factor = camera.size / REFERENCE_ORTHO_SIZE
	else:
		scale_factor = camera.global_position.distance_to(global_position) / REFERENCE_DISTANCE
	scale_factor = maxf(scale_factor, 0.001)
	var facing_basis := camera.global_transform.basis.scaled(Vector3.ONE * scale_factor)
	global_transform = Transform3D(facing_basis, global_position)


func _resize_background() -> void:
	if m_label == null or m_background == null:
		return
	var aabb := m_label.get_aabb()
	if aabb.size.x <= 0.0 or aabb.size.y <= 0.0:
		return
	var quad := m_background.mesh as QuadMesh
	if quad == null:
		return
	quad.size = Vector2(aabb.size.x, aabb.size.y) + BG_PADDING
	# Centre the panel on the text and nudge it slightly behind.
	m_background.position = Vector3(
		aabb.position.x + aabb.size.x * 0.5,
		aabb.position.y + aabb.size.y * 0.5,
		-0.01
	)
