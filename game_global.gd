@tool
class_name GameGlobal
extends Resource

static func get_instance() -> GameGlobal:
	if m_instance == null:
		m_instance = GameGlobal.new()
	return m_instance
	
signal player_changed()
	
func get_player() -> Player:
	return m_player
	
func set_player(new_player) -> void:
	if m_player == new_player:
		return
	m_player = new_player
	player_changed.emit()

#private

static var m_instance :GameGlobal

var m_player: Player
