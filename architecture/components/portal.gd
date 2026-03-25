@tool
class_name Portal
extends Area2D

@export var level_from := -1
@export var level_to := -1
@export_flags_2d_physics var mask1 := 0
@export_flags_2d_physics var mask2 := 0
@export var delta_z := 1

const SIDE_EPSILON := 0.001
const DEBUG_FILL_COLOR := Color(0.301961, 0.878431, 1.0, 0.18)
const DEBUG_OUTLINE_COLOR := Color(0.301961, 0.878431, 1.0, 0.95)
const DEBUG_OUTLINE_WIDTH := 2.0
const DEBUG_CAPSULE_SEGMENTS := 16

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_update_level_masks()
	queue_redraw()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()

func _draw() -> void:
	var collision_shape := $CollisionShape2D as CollisionShape2D
	if collision_shape == null or collision_shape.shape == null:
		return

	var shape := collision_shape.shape
	if shape is RectangleShape2D:
		_draw_rectangle_shape(collision_shape, shape as RectangleShape2D)
	elif shape is CapsuleShape2D:
		_draw_capsule_shape(collision_shape, shape as CapsuleShape2D)

	var arrow_direction := collision_shape.transform.x.normalized()
	DrawUtils.draw_arrow(
		self,
		collision_shape.position,
		arrow_direction,
		_get_arrow_length(shape),
		DEBUG_OUTLINE_COLOR
	)


func _draw_rectangle_shape(collision_shape: CollisionShape2D, shape: RectangleShape2D) -> void:
	var half_size := shape.size * 0.5
	var points := PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
	])
	_draw_portal_polygon(collision_shape, points)


func _draw_capsule_shape(collision_shape: CollisionShape2D, shape: CapsuleShape2D) -> void:
	var radius: float = shape.radius
	var total_height: float = maxf(shape.height, radius * 2.0)
	var half_body_height: float = maxf(total_height * 0.5 - radius, 0.0)
	var top_center := Vector2(0.0, -half_body_height)
	var bottom_center := Vector2(0.0, half_body_height)
	var points := PackedVector2Array()

	for i in range(DEBUG_CAPSULE_SEGMENTS + 1):
		var t: float = float(i) / float(DEBUG_CAPSULE_SEGMENTS)
		var angle: float = lerpf(PI, 0.0, t)
		points.append(top_center + Vector2(cos(angle), sin(angle)) * radius)

	for i in range(DEBUG_CAPSULE_SEGMENTS + 1):
		var t: float = float(i) / float(DEBUG_CAPSULE_SEGMENTS)
		var angle: float = lerpf(0.0, PI, t)
		points.append(bottom_center + Vector2(cos(angle), sin(angle)) * radius)

	_draw_portal_polygon(collision_shape, points)


func _draw_portal_polygon(collision_shape: CollisionShape2D, local_points: PackedVector2Array) -> void:
	if local_points.is_empty():
		return

	var transformed_points := PackedVector2Array()
	for point in local_points:
		transformed_points.append(collision_shape.transform * point)

	draw_colored_polygon(transformed_points, DEBUG_FILL_COLOR)
	for i in range(transformed_points.size()):
		var next_index := (i + 1) % transformed_points.size()
		draw_line(
			transformed_points[i],
			transformed_points[next_index],
			DEBUG_OUTLINE_COLOR,
			DEBUG_OUTLINE_WIDTH
		)


func _get_arrow_length(shape: Shape2D) -> float:
	if shape is RectangleShape2D:
		return maxf((shape as RectangleShape2D).size.x * 0.4, 16.0)
	if shape is CapsuleShape2D:
		return maxf((shape as CapsuleShape2D).radius * 1.5, 16.0)
	return 20.0

var m_transition_state_by_body: Dictionary = {}

func _update_level_masks() -> void:
	var level_context := LevelContext2D.find_from(self)
	if level_context == null:
		return
	if level_from >= 0:
		mask1 = level_context.resolve_level_collision_mask(level_from, mask1)
	if level_to >= 0:
		mask2 = level_context.resolve_level_collision_mask(level_to, mask2)

func _store_transition_state(obj: CollisionObject2D, enter_direction: bool) -> void:
	m_transition_state_by_body[obj.get_instance_id()] = {
		"enter_direction": enter_direction,
	}

func _take_transition_state(obj: CollisionObject2D) -> Dictionary:
	var body_id := obj.get_instance_id()
	var transition_state: Dictionary = m_transition_state_by_body.get(body_id, {})
	if !transition_state.is_empty():
		m_transition_state_by_body.erase(body_id)
	return transition_state

func _on_body_entered(body: Node2D) -> void:
	var obj :CollisionObject2D = body
	if obj == null:
		return
	if obj.collision_mask & mask1 == 0 and obj.collision_mask & mask2 == 0:
		return
	#m_objects_in_portal.insert(obj)
	#if obj.collision_mask & mask1:
		#m_enter_mask = mask1
	#else:
		#m_enter_mask = mask2
	var local_pos = to_local(body.global_position)
	#print(local_pos)
	if obj.collision_mask & mask1:
		if _is_on_mask1_side(local_pos.x):
			_store_transition_state(obj, true)
			obj.collision_mask |= mask2
		elif mask1 == mask2:
			#Only change z
			_store_transition_state(obj, false)
	elif obj.collision_mask & mask2:
		if _is_on_mask2_side(local_pos.x):
			_store_transition_state(obj, false)
			obj.collision_mask |= mask1
			#print("mask2 entered")
			

func _on_body_exited(body: Node2D) -> void:
	var obj :CollisionObject2D = body
	if obj == null:
		return
	var transition_state := _take_transition_state(obj)
	if transition_state.is_empty():
		return
	var enter_direction := bool(transition_state.get("enter_direction", true))
	var local_pos = to_local(body.global_position)
	var vec = local_pos.normalized()
	if _is_on_mask2_side(vec.x):
		if level_from >= 0 and level_to >= 0:
			var level_context := LevelContext2D.find_from(self)
			if level_context == null or !level_context.apply_level_to_actor(level_to, obj):
				if mask1 != mask2:
					obj.collision_mask &= ~mask1
					obj.collision_mask |= mask2
				if enter_direction:
					obj.z_index += delta_z
		else:
			if mask1 != mask2:
				obj.collision_mask &= ~mask1
				obj.collision_mask |= mask2
			if enter_direction:
				obj.z_index += delta_z
		#print("mask2 exited")
	else:
		if level_from >= 0 and level_to >= 0:
			var level_context := LevelContext2D.find_from(self)
			if level_context == null or !level_context.apply_level_to_actor(level_from, obj):
				if mask1 != mask2:
					obj.collision_mask &= ~mask2
					obj.collision_mask |= mask1
				if !enter_direction:
					obj.z_index -= delta_z
		else:
			if mask1 != mask2:
				obj.collision_mask &= ~mask2
				obj.collision_mask |= mask1
			if !enter_direction:
				obj.z_index -= delta_z
		#print("mask1 exited")
	#var exit_degrees = rad_to_deg(vec.angle())
	#print("exited : ", exit_degrees)
	#var obj :CollisionObject2D = body
	#if obj:
		#if CommonUtils.is_in_range(exit_degrees, -90, 90):
			#obj.collision_mask |= mask2
			#obj.collision_mask &= ~mask1
			#print("mask2 exited")
		#else:
			#obj.collision_mask |= mask1
			#obj.collision_mask &= ~mask2
			#print("mask1 exited")

func _is_on_mask1_side(local_x: float) -> bool:
	return local_x <= SIDE_EPSILON

func _is_on_mask2_side(local_x: float) -> bool:
	return local_x >= -SIDE_EPSILON
