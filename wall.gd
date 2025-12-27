extends TileMapLayer
@export var trans_rect :Rect2
@export var debug :bool = true:
	set(new_debug):
		if debug == new_debug:
			return
		debug = new_debug
		queue_redraw()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

var m_overlapping_cells :Set = Set.new([])
var m_clear_cells :Set = Set.new([])

# Returns a list of Vector2i cell coords whose tile area intersects rect_global.
func get_cells_intersecting_rect_global(layer: TileMapLayer, rect_global: Rect2) -> Set:
	var result: Set = Set.new([])

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

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	var has_changed := false
	var cells = get_cells_intersecting_rect_global(self, trans_rect)
	var clear_cells := Set.new([])
	for cell in m_overlapping_cells.data:
		if !cells.has(cell):
			clear_cells.insert(cell)
			has_changed = true

	for cell in cells.data:
		if !m_overlapping_cells.has(cell):
			has_changed = true
			break

	m_overlapping_cells = cells
	m_clear_cells = clear_cells

	if debug:
		queue_redraw()
	if has_changed:
		#print(m_overlapping_cells.data)
		notify_runtime_tile_data_update()

	#var shader_material :ShaderMaterial = material
	#shader_material.set_shader_parameter("trans_rect_pos", trans_rect.position)
	#shader_material.set_shader_parameter("trans_rect_size", trans_rect.size)
	

func _use_tile_data_runtime_update(coords: Vector2i) -> bool:
	return m_overlapping_cells.has(coords) or m_clear_cells.has(coords)

func _tile_data_runtime_update(coords: Vector2i, tile_data: TileData) -> void:
	if m_overlapping_cells.has(coords):
		tile_data.modulate = Color(1, 1, 1, 0.5)
	else:
		tile_data.modulate = Color(1, 1, 1, 1.0)
	
func _to_local(global_rect: Rect2) -> Rect2:
	var local_rect = global_rect
	local_rect.position -= global_position
	return local_rect
	
func _draw() -> void:
	if debug:
		var local_trans_rect = _to_local(trans_rect)
		draw_rect(local_trans_rect, Color(1.0, 0, 0, 0.5), false)
		for cell in m_overlapping_cells.data:
			#var cell_data :TileData = get_cell_tile_data(cell)
			var pos = map_to_local(cell)
			draw_circle(pos, 10, Color(1.0, 0, 0, 0.5))
