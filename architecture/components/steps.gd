@tool
class_name Steps
extends AutoVisibilityNode2D

@export var level_bottom: LevelSpec = null
@export var level_top: LevelSpec = null

@export var layer1_nodes :Array[Portal]

@export_flags_2d_physics var layer1 := 0:
	set(new_layer):
		if layer1 == new_layer:
			return
		layer1 = new_layer
		_request_mask_update()

@export var body_nodes :Array[CollisionObject2D]

@export_flags_2d_physics var collision_layer := 0:
	set(new_layer):
		if collision_layer == new_layer:
			return
		collision_layer = new_layer
		_request_mask_update()

@export var layer2_nodes :Array[Portal]

@export_flags_2d_physics var layer2 := 0:
	set(new_layer):
		if layer2 == new_layer:
			return
		layer2 = new_layer
		_request_mask_update()

func _request_mask_update() -> void:
	if !is_inside_tree():
		return
	_update_mask()

func _update_mask() -> void:
	# If both LevelSpecs are provided, use them to derive the collision masks
	if level_bottom != null and level_top != null:
		var level_context: LevelContext2D = LevelContext2D.find_from(self)
		if level_context == null:
			push_warning("Steps '%s' could not find a LevelContext2D for level-based mask resolution." % name)
			return

		var bottom_mask: int = level_context.resolve_level_collision_mask(level_bottom.level_id, layer1)
		var top_mask: int = level_context.resolve_level_collision_mask(level_top.level_id, layer2)
		var bottom_z: int = level_context.resolve_level_z_index(level_bottom.level_id, 0)
		var top_z: int = level_context.resolve_level_z_index(level_top.level_id, 0)
		var z_gap: int = abs(top_z - bottom_z)
		var should_override_delta: bool = z_gap % 2 == 0
		var portal_delta_z: int = z_gap >> 1 if should_override_delta else 1
		if !should_override_delta:
			push_warning(
				"Steps '%s' expected an even z gap between levels %d and %d, keeping existing portal delta_z."
				% [name, level_bottom.level_id, level_top.level_id]
			)

		# Apply to body nodes (CollisionObject2D): set collision_layer bits
		for body in body_nodes:
			if is_instance_valid(body):
				body.collision_layer = collision_layer

		# Apply to portal1 nodes: mask1 = bottom level, mask2 = collision_layer
		for p1 in layer1_nodes:
			if is_instance_valid(p1):
				p1.mask1 = bottom_mask
				p1.mask2 = collision_layer
				if should_override_delta:
					p1.delta_z = portal_delta_z

		# Apply to portal2 nodes: mask1 = collision_layer, mask2 = top level
		for p2 in layer2_nodes:
			if is_instance_valid(p2):
				p2.mask1 = collision_layer
				p2.mask2 = top_mask
				if should_override_delta:
					p2.delta_z = portal_delta_z
	else:
		# Fallback to original behavior if LevelSpecs not provided
		# Apply to body nodes (CollisionObject2D): set collision_layer bits
		for body in body_nodes:
			if is_instance_valid(body):
				body.collision_layer = collision_layer

		# Apply to portal1 nodes: mask1 = layer1, mask2 = collision_layer
		for p1 in layer1_nodes:
			if is_instance_valid(p1):
				p1.mask1 = layer1
				p1.mask2 = collision_layer

		# Apply to portal2 nodes: mask1 = collision_layer, mask2 = layer2
		for p2 in layer2_nodes:
			if is_instance_valid(p2):
				p2.mask1 = collision_layer
				p2.mask2 = layer2
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super._ready()
	_update_mask()
