@tool
class_name OverworldWeatherPreset
extends Resource

@export var rain_properties: Dictionary = {}
@export var fog_properties: Dictionary = {}
@export var cloud_properties: Dictionary = {}
@export var impact_properties: Dictionary = {}


func get_rain_properties() -> Dictionary:
	return rain_properties.duplicate(true)


func get_fog_properties() -> Dictionary:
	return fog_properties.duplicate(true)


func get_cloud_properties() -> Dictionary:
	return cloud_properties.duplicate(true)


func get_impact_properties() -> Dictionary:
	return impact_properties.duplicate(true)
