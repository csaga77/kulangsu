@tool
class_name Portal
extends Area2D

@export_flags_2d_physics var mask1 := 0
@export_flags_2d_physics var mask2 := 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _draw() -> void:
	DrawUtils.draw_arrow(self, $CollisionShape2D.position, Vector2.RIGHT.rotated(0), 20, Color.RED)

var m_objects_in_portal :Set = Set.new()
var m_enter_mask := 0

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
	if obj.collision_mask & mask1:
		if local_pos.x < 0:
			m_enter_mask = mask1
			obj.collision_mask |= mask2
			m_objects_in_portal.insert(obj)
			print("mask1 entered")
	elif obj.collision_mask & mask2:
		if local_pos.x > 0:
			m_enter_mask = mask2
			obj.collision_mask |= mask1
			m_objects_in_portal.insert(obj)
			print("mask2 entered")
			


func _on_body_exited(body: Node2D) -> void:
	var obj :CollisionObject2D = body
	if obj == null:
		return
	if !m_objects_in_portal.remove(obj):
		return
	var local_pos = to_local(body.global_position)
	var vec = local_pos.normalized()
	if vec.x > 0:
		obj.collision_mask |= mask2
		obj.collision_mask &= ~mask1
		if m_enter_mask != mask2:
			obj.z_index += 1
		print("mask2 exited")
	else:
		obj.collision_mask |= mask1
		obj.collision_mask &= ~mask2
		if m_enter_mask != mask1:
			obj.z_index -= 1
		print("mask1 exited")
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
