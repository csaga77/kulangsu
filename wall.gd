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

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	var has_changed := false
	var cells = Utils.get_cells_intersecting_rect_global(self, trans_rect)
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
