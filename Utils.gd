@tool
class_name Utils

static func find_cells_rect(layer: TileMapLayer, rect_global) -> Rect2i:
	# 1) Convert global rect corners -> layer local
	var p0_local: Vector2i = layer.local_to_map(layer.to_local(rect_global.position))
	var p1_local: Vector2i = layer.local_to_map(layer.to_local(rect_global.end))
	var p2_local: Vector2i = layer.local_to_map(layer.to_local(rect_global.position + Vector2(rect_global.size.x, 0)))
	var p3_local: Vector2i = layer.local_to_map(layer.to_local(rect_global.position + Vector2(0, rect_global.size.y)))

	# Make sure min/max are correct even if rect has negative size
	var min_cell := Vector2i(min(p0_local.x, p1_local.x, p2_local.x, p3_local.x), min(p0_local.y, p1_local.y, p2_local.y, p3_local.y))
	var max_cell := Vector2i(max(p0_local.x, p1_local.x, p2_local.x, p3_local.x), max(p0_local.y, p1_local.y, p2_local.y, p3_local.y))

	# 2) Convert local bounds -> cell bounds (inclusive)
	# Note: using a tiny epsilon so tiles that lie exactly on the edge are included.
	#var eps := 0.0001
	#var min_cell: Vector2i = layer.local_to_map(min_local)
	#var max_cell: Vector2i = layer.local_to_map(max_local - Vector2(eps, eps))

	# Normalize in case transforms cause inversion
	var x0 = min(min_cell.x, max_cell.x)
	var x1 = max(min_cell.x, max_cell.x)
	var y0 = min(min_cell.y, max_cell.y)
	var y1 = max(min_cell.y, max_cell.y)
	
	return Rect2i(x0, y0, x1 - x0, y1 - y0)

static func intersects_rect_global(layer: TileMapLayer, rect_global) -> bool:
	var rect :Rect2i = find_cells_rect(layer, rect_global)
	if !layer.get_used_rect().intersects(rect):
		return false
	
	# Normalize in case transforms cause inversion
	var x0 = rect.position.x
	var x1 = rect.end.x
	var y0 = rect.position.y
	var y1 = rect.end.y
	
	# 3) Broad-phase: iterate all candidate cells
	for y in range(y0, y1):
		for x in range(x0, x1):
			var cell := Vector2i(x, y)
			if layer.get_cell_source_id(cell) == -1:
				continue
			return true
	return false
	
# Returns a list of Vector2i cell coords whose tile area intersects rect_global.
static func get_cells_intersecting_rect_global(layer: TileMapLayer, rect_global: Rect2) -> Set:
	var result: Set = Set.new([])
	var rect :Rect2i = find_cells_rect(layer, rect_global)
	
	# Normalize in case transforms cause inversion
	var x0 = rect.position.x
	var x1 = rect.end.x
	var y0 = rect.position.y
	var y1 = rect.end.y

	# 3) Broad-phase: iterate all candidate cells
	for y in range(y0, y1):
		for x in range(x0, x1):
			var cell := Vector2i(x, y)

			# Optional: skip empty cells (fast if you only want painted tiles)
			# If you want "all possible cells", remove this check.
			if layer.get_cell_source_id(cell) == -1:
				continue

			# Optional exact test (recommended if you have rotation/scaling/etc.)
			# Compute the tile's world rect and test intersection.
			#var tile_local_origin: Vector2 = layer.map_to_local(cell)
			#var tile_size: Vector2 = layer.tile_set.tile_size

			# Tile rect in GLOBAL space
			#var tile_rect_global := Rect2(
				#layer.to_global(tile_local_origin),
				#tile_size * layer.global_scale.abs() # works for common non-rotated setups
			#)

			# If your TileMapLayer can be rotated, do a local-space exact test instead:
			# (comment out tile_rect_global logic above and use below)
			# var tile_rect_local := Rect2(tile_local_origin, tile_size)
			# var rect_local := Rect2(min_local, max_local - min_local)
			# if not tile_rect_local.intersects(rect_local):
			#     continue

			#if tile_rect_global.intersects(rect_global):
			result.insert(cell)

	return result

static func enable_collision(layer :TileMapLayer, collision_enabled := true) -> void:
	layer.collision_enabled = collision_enabled
	var children = layer.find_children("*", "TileMapLayer")
	for child in children:
		child.collision_enabled = collision_enabled
		
		
