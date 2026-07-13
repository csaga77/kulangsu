# Weather Rendering

## Goal

Provide one production 3D weather path for rain, environment fog, cloud-light modulation, and shared wind.

## Ownership

- [`../../weather/weather_manager.gd`](../../weather/weather_manager.gd) owns weighted weather presets, hold/transition timing, current weather state, and the published wind signal.
- [`../../weather/weather_runtime.gd`](../../weather/weather_runtime.gd) resolves the scene-owned manager.
- [`../../weather/weather_rig_3d.gd`](../../weather/weather_rig_3d.gd) owns `GPUParticles3D` rain, environment fog application, moving cloud-light modulation, and visibility.
- [`../../scenes/game_world_3d.gd`](../../scenes/game_world_3d.gd) creates/configures `WeatherRig3D`, registers it as `weather_state_target`, and binds wind to low-poly water.
- [`../../terrain/low_poly_water_wind_adapter.gd`](../../terrain/low_poly_water_wind_adapter.gd) normalizes manager wind for the water shader.

The retired canvas rain/fog/cloud-shadow/ground-impact overlays, 2D tuning sandbox, and overlay-specific preset resource were removed after the 3D cutover. `WeatherManager` now accepts only a scene-owned `weather_state_target` with the production methods below.

## Target Contract

A registered target may implement:

- `capture_weather_state() -> Dictionary`
- `apply_weather(weather: Dictionary) -> void`
- `set_wind(angle_degrees: float, strength: float) -> void`
- `set_weather_visible(is_visible: bool) -> void`

The shared weather dictionary contains `rain_density`, `fog_density`, `fog_height_ratio`, `fog_drift_speed`, `wind_angle_degrees`, `wind_strength`, `drop_speed`, and `drop_size`.

## Rules

- Weather presentation stays scene/rendering-owned; do not move random cycling into `AppState`.
- Water consumes the manager's wind signal through an adapter instead of registering as another weather target.
- Runtime weather is not save-persistent or story-authored yet.
- New weather visuals should be implemented in 3D and exercised through the production world rather than creating a parallel canvas path.

## Validation

- Run [`../../scenes/tests/test_game_world_3d.tscn`](../../scenes/tests/test_game_world_3d.tscn). It verifies registration, rain activation, wind application, water propagation, and a complete random transition.
- Run [`../../weather/tests/capture_weather_3d.tscn`](../../weather/tests/capture_weather_3d.tscn) with a graphical renderer for the steady-rain visual proof; it must print `PASS: WeatherRig3D steady-rain capture`.
- Let the full app run through at least one transition and check rain coverage, fog readability, moving light, actor silhouettes, and water response.

## Out Of Scope

- Forecast UI, story-driven schedules, save-persistent weather, thunder, puddles, wet-surface shaders, and gameplay rules based on weather.
