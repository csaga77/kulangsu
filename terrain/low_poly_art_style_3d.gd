@tool
class_name LowPolyArtStyle3D
extends Resource

@export_group("Terrain")
@export var land_color: Color = Color(0.52, 0.70, 0.48, 1.0)
@export var shoreline_color: Color = Color(0.34, 0.49, 0.41, 1.0)
@export var street_color: Color = Color(0.84, 0.77, 0.62, 1.0)
@export var building_footprint_color: Color = Color(0.76, 0.57, 0.43, 1.0)
@export var water_color: Color = Color(0.38, 0.66, 0.82, 0.82)
@export var water_deep_color: Color = Color(0.24, 0.48, 0.67, 0.86)
@export var water_surface_layer_color: Color = Color(0.72, 0.90, 0.96, 0.30)
@export var water_shoreline_color: Color = Color(0.60, 0.83, 0.88, 0.72)
@export var water_highlight_color: Color = Color(0.86, 0.96, 0.98, 0.54)
@export_range(0.0, 0.2, 0.005) var water_wave_depth: float = 0.045
@export_range(0.05, 4.0, 0.05) var water_wave_frequency: float = 0.48
@export_range(0.0, 0.45, 0.01) var water_shoreline_band_ratio: float = 0.18
@export_range(0.0, 0.05, 0.001) var water_shoreline_lift: float = 0.006
@export_range(0.0, 0.05, 0.001) var water_surface_layer_lift: float = 0.003

@export_group("Camera")
@export var camera_follow_offset := Vector3(20.0, 23.0, 18.0)
@export var camera_look_at_offset := Vector3(0.0, 0.9, 0.0)
@export_range(4.0, 120.0, 0.5) var camera_orthographic_size := 36.0
@export_range(4.0, 120.0, 0.5) var min_camera_orthographic_size := 12.0
@export_range(4.0, 160.0, 0.5) var max_camera_orthographic_size := 82.0

@export_group("Lighting")
@export var sun_color := Color(1.0, 0.91, 0.78, 1.0)
@export_range(0.0, 8.0, 0.05) var sun_energy := 2.35
@export var sun_position := Vector3(28.0, 44.0, 18.0)
@export var sun_look_at := Vector3(-20.0, -18.0, -8.0)
@export var sun_shadows_enabled := true

@export_group("Landmarks")
@export var landmark_wall_color := Color(0.88, 0.79, 0.62, 1.0)
@export var landmark_roof_color := Color(0.70, 0.28, 0.18, 1.0)
@export var landmark_trim_color := Color(0.96, 0.88, 0.72, 1.0)
@export var landmark_pier_color := Color(0.50, 0.36, 0.24, 1.0)
@export var landmark_shadow_color := Color(0.18, 0.19, 0.23, 1.0)
