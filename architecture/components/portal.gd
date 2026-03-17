@tool
class_name Portal
extends Area2D

@export_flags_2d_physics var mask1 := 0
@export_flags_2d_physics var mask2 := 0
@export var delta_z := 1

const SIDE_EPSILON := 0.001

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _draw() -> void:
	DrawUtils.draw_arrow(self, $CollisionShape2D.position, Vector2.RIGHT.rotated(0), 20, Color.RED)

var m_transition_state_by_body: Dictionary = {}

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
		if mask1 != mask2:
			obj.collision_mask &= ~mask1
			obj.collision_mask |= mask2
		if enter_direction:
			obj.z_index += delta_z
		#print("mask2 exited")
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
