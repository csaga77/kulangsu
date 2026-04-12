class_name TunnelContext
extends Node

const LEVEL_REGISTRY := preload("res://common/level_registry.gd")

var m_player: HumanBody2D = null
var m_resident_root: Node2D = null
var m_tunnel_nodes: Array[Tunnel] = []
var m_use_process_fallback := true
var m_tunnel_managed_resident_ids: Dictionary = {}


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if !m_use_process_fallback:
		return
	sync()


func configure(player: HumanBody2D, resident_root: Node2D, tunnel_nodes: Array) -> void:
	m_player = player
	m_resident_root = resident_root
	m_tunnel_nodes.clear()
	m_tunnel_managed_resident_ids.clear()
	for tunnel_value in tunnel_nodes:
		var tunnel := tunnel_value as Tunnel
		if tunnel != null:
			m_tunnel_nodes.append(tunnel)

	sync()


func sync() -> void:
	if !is_instance_valid(m_resident_root):
		return

	var active_tunnel := find_player_tunnel()
	for tunnel in m_tunnel_nodes:
		if !is_instance_valid(tunnel):
			continue
		tunnel.set_player_inside(tunnel == active_tunnel)

	for child in m_resident_root.get_children():
		var resident := child as HumanBody2D
		if resident == null:
			continue

		var resident_id := resident.get_instance_id()
		var resident_tunnel := find_resident_tunnel(resident)
		if resident_tunnel != null:
			m_tunnel_managed_resident_ids[resident_id] = true
			LEVEL_REGISTRY.apply_level_to_actor(resident_tunnel.get_resolved_level_id(), resident)
			resident.visible = resident_tunnel == active_tunnel
			continue

		if m_tunnel_managed_resident_ids.has(resident_id):
			resident.visible = active_tunnel == null


func find_player_tunnel() -> Tunnel:
	return find_tunnel_for_actor(m_player, true)


func find_resident_tunnel(actor: HumanBody2D) -> Tunnel:
	return find_tunnel_for_actor(actor, true)


func find_tunnel_for_actor(actor: HumanBody2D, require_interior_level: bool) -> Tunnel:
	if !is_instance_valid(actor):
		return null

	for tunnel in m_tunnel_nodes:
		if !is_instance_valid(tunnel):
			continue
		if require_interior_level and tunnel.contains_actor_interior(actor):
			return tunnel
		if !require_interior_level and tunnel.contains_actor(actor):
			return tunnel

	return null
