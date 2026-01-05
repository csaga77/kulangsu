extends Node2D

@export var character :CollisionObject2D = null 

@onready var m_ground :TileMapLayer = $ground
@onready var m_steps  :TileMapLayer = $steps
@onready var m_bridge :TileMapLayer = $bridge
@onready var m_steps_mask_ground :TileMapLayer = $steps_mask_ground
@onready var m_steps_mask_bridge :TileMapLayer = $steps_mask_bridge
@onready var m_steps_mask :TileMapLayer = $steps_mask

var m_is_on_steps := false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if character == null:
		return
	var rect :Rect2
	rect.position = character.global_position - Vector2(16, 4)
	rect.size = Vector2(32, 32)
	
	if character.z_index <= z_index:
		var is_bridge_visible = !Utils.intersects_rect_global(m_ground, rect)
		m_bridge.visible = is_bridge_visible
		var is_on_steps = Utils.intersects_rect_global(m_steps_mask_ground, rect)
		if is_on_steps != m_is_on_steps:
			if m_is_on_steps and !is_on_steps:
				#print("check if still on steps")
				is_on_steps = Utils.intersects_rect_global(m_steps_mask, rect)
			m_is_on_steps = is_on_steps
			m_steps.collision_enabled = is_on_steps
			m_ground.collision_enabled = !is_on_steps
			#print(is_on_steps)
		if m_is_on_steps:
			var is_on_bridge = Utils.intersects_rect_global(m_steps_mask_bridge, rect)
			if is_on_bridge:
				m_steps.collision_enabled = false
				character.z_index = m_bridge.z_index
				m_bridge.collision_enabled = true
	else:
		var is_on_steps = Utils.intersects_rect_global(m_steps_mask_bridge, rect)
		if is_on_steps != m_is_on_steps:
			if m_is_on_steps and !is_on_steps:
				#print("check if still on steps")
				is_on_steps = Utils.intersects_rect_global(m_steps_mask, rect)
			m_is_on_steps = is_on_steps
			m_steps.collision_enabled = is_on_steps
			m_bridge.collision_enabled = !is_on_steps
			#print(is_on_steps)
		m_bridge.visible = !is_on_steps
		if m_is_on_steps:
			var is_on_ground = Utils.intersects_rect_global(m_steps_mask_ground, rect)
			if is_on_ground:
				m_steps.collision_enabled = false
				character.z_index = z_index
				m_ground.collision_enabled = true
		
	
		
