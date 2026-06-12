@tool
class_name BuildingOpening3D
extends Node3D

const GENERATED_META := &"building_opening_generated"

@export var rebuild := false:
	set(value):
		if !value:
			return
		call_deferred("_rebuild")

@export_range(0.1, 12.0, 0.01) var opening_width := 1.0:
	set(value):
		var clamped_value := maxf(value, 0.1)
		if is_equal_approx(opening_width, clamped_value):
			return
		opening_width = clamped_value
		_request_rebuild()

@export_range(0.1, 12.0, 0.01) var opening_height := 1.0:
	set(value):
		var clamped_value := maxf(value, 0.1)
		if is_equal_approx(opening_height, clamped_value):
			return
		opening_height = clamped_value
		_request_rebuild()

@export_range(0.01, 1.0, 0.01) var frame_thickness := 0.08:
	set(value):
		var clamped_value := maxf(value, 0.01)
		if is_equal_approx(frame_thickness, clamped_value):
			return
		frame_thickness = clamped_value
		_request_rebuild()

@export_range(0.01, 1.0, 0.01) var frame_depth := 0.08:
	set(value):
		var clamped_value := maxf(value, 0.01)
		if is_equal_approx(frame_depth, clamped_value):
			return
		frame_depth = clamped_value
		_request_rebuild()

@export var frame_color := Color(0.86, 0.92, 0.94, 1.0):
	set(value):
		if frame_color == value:
			return
		frame_color = value
		_request_rebuild()

@export var build_on_ready := true

var m_is_ready := false
var m_rebuild_queued := false


func _ready() -> void:
	m_is_ready = true
	if build_on_ready:
		_rebuild()


func get_opening_rect() -> Rect2:
	var size := Vector2(opening_width, opening_height)
	var center := Vector2(position.x, position.y)
	return Rect2(center - size * 0.5, size)


func _request_rebuild() -> void:
	if !m_is_ready:
		return
	if m_rebuild_queued:
		return
	m_rebuild_queued = true
	call_deferred("_rebuild")


func _rebuild() -> void:
	m_rebuild_queued = false
	_clear_generated_children()

	var half_width := opening_width * 0.5
	var half_height := opening_height * 0.5
	var side_height := opening_height + frame_thickness * 2.0
	var top_width := opening_width + frame_thickness * 2.0

	_add_box(
		"LeftFrame",
		Vector3(frame_thickness, side_height, frame_depth),
		Vector3(-half_width - frame_thickness * 0.5, 0.0, 0.0)
	)
	_add_box(
		"RightFrame",
		Vector3(frame_thickness, side_height, frame_depth),
		Vector3(half_width + frame_thickness * 0.5, 0.0, 0.0)
	)
	_add_box(
		"TopFrame",
		Vector3(top_width, frame_thickness, frame_depth),
		Vector3(0.0, half_height + frame_thickness * 0.5, 0.0)
	)
	_add_box(
		"BottomFrame",
		Vector3(top_width, frame_thickness, frame_depth),
		Vector3(0.0, -half_height - frame_thickness * 0.5, 0.0)
	)


func _add_box(part_name: String, size: Vector3, local_position: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size

	var instance := MeshInstance3D.new()
	instance.name = part_name
	instance.mesh = mesh
	instance.position = local_position
	instance.material_override = _build_material(frame_color)
	instance.set_meta(GENERATED_META, true)
	add_child(instance)
	if Engine.is_editor_hint():
		instance.owner = null


func _build_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if color.a < 0.99:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _clear_generated_children() -> void:
	for child in get_children():
		if !child.has_meta(GENERATED_META):
			continue
		remove_child(child)
		child.free()
