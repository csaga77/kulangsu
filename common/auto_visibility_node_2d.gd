@tool
class_name AutoVisibilityNode2D
extends IsometricBlock

@export var visibility_mask_nodes: Array[Node2D]
@export var use_ground_bounding_rect := true
@export var smooth_visibility_change := true
@export var is_inverted := false
@export var is_enabled := true

var m_player: Player = null
var m_target_visible := true
var m_is_changing_visibility := false

func _ready() -> void:
	super._ready()

	if !Engine.is_editor_hint():
		var gg = GameGlobal.get_instance()
		if gg:
			gg.player_changed.connect(self._on_player_changed)

	_on_player_changed()

func _on_player_changed() -> void:
	if Engine.is_editor_hint():
		return

	var gg = GameGlobal.get_instance()
	if gg == null:
		_set_player(null)
		return

	_set_player(gg.get_player())

func _set_player(new_player: Player) -> void:
	if m_player == new_player:
		return

	if m_player:
		if m_player.global_position_changed.is_connected(self._update_visibility):
			m_player.global_position_changed.disconnect(self._update_visibility)

	m_player = new_player

	if m_player:
		m_player.global_position_changed.connect(self._update_visibility)

	_update_visibility()

func _set_visible(new_is_visible: bool) -> void:
	if smooth_visibility_change:
		if m_target_visible == new_is_visible:
			return

		m_target_visible = new_is_visible

		# Ensure correct logical visibility during fade-in
		if new_is_visible:
			visible = true

		var tween = AnimationUtils.tween_node2d_visibility(self, new_is_visible)
		if tween:
			m_is_changing_visibility = true
			tween.finished.connect(func():
				m_is_changing_visibility = false
				# Ensure correct logical visibility at end of fade-out
				if !m_target_visible:
					visible = false
			)
		else:
			visible = new_is_visible
	else:
		visible = new_is_visible

func _update_visibility() -> void:
	if Engine.is_editor_hint():
		return
	if !is_enabled:
		return

	# No player => keep visible (or keep current state; choose visible for safety)
	if m_player == null:
		_set_visible(true)
		return

	var should_be_visible := true
	var bounding_rect: Rect2 = m_player.get_ground_rect() if use_ground_bounding_rect else m_player.get_bounding_rect()

	for mask_node in visibility_mask_nodes:
		if mask_node == null:
			continue

		# Custom mask node hook: mask_player(player, rect_global) -> bool
		if mask_node.has_method("mask_player"):
			if mask_node.mask_player(m_player, bounding_rect):
				should_be_visible = false
				break
			continue

		# Built-in TileMapLayer fallback
		if mask_node is TileMapLayer:
			if _masks_player_tilemap_layer(m_player, bounding_rect, mask_node):
				should_be_visible = false
				break
	
	_set_visible(!should_be_visible if is_inverted else should_be_visible)

func _masks_player_tilemap_layer(player_node: Node2D, bounding_rect: Rect2, tile_map_layer: TileMapLayer) -> bool:
	if player_node == null or tile_map_layer == null:
		return false
	if !tile_map_layer.enabled:
		return false

	# Player above this layer => ignore masking
	if CommonUtils.get_absolute_z_index(player_node) > CommonUtils.get_absolute_z_index(tile_map_layer):
		return false

	return TileMapUtils.intersects_iso_grid_rect_global(tile_map_layer, bounding_rect)
