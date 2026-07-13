# Terrain Water Rendering

## Goal

Keep production 3D water calm, readable, continuous with the seabed, and responsive to the shared weather wind without creating a second water implementation.

## Ownership

- [`../../terrain/low_poly_terrain_3d.gd`](../../terrain/low_poly_terrain_3d.gd) owns water mesh children, material setup, and lifecycle.
- [`../../terrain/low_poly_terrain_mesh_builder.gd`](../../terrain/low_poly_terrain_mesh_builder.gd) builds continuous seabed, water-body, surface, overlap, and shoreline geometry from the sampled grid.
- [`../../resources/materials/water_3d.gdshader`](../../resources/materials/water_3d.gdshader) owns spatial wave, color, transparency, and highlight behavior.
- [`../../terrain/low_poly_art_style_3d.gd`](../../terrain/low_poly_art_style_3d.gd) and [`../../terrain/low_poly_postcard_diorama_style.tres`](../../terrain/low_poly_postcard_diorama_style.tres) own palette and tuning defaults.
- [`../../terrain/low_poly_water_wind_adapter.gd`](../../terrain/low_poly_water_wind_adapter.gd) normalizes `WeatherManager` wind and updates the water shader.

The retired `TileMapLayer` water material, setup helper, tilesets, focused 2D water scene, and hidden shoreline tile collision were removed with the 2D overworld.

## Contracts

- Water classification comes from the same mask/heightmap sample used by land generation.
- Underwater terrain remains visible as continuous seabed; water must not expose holes at the shoreline.
- Water rendering may overlap neighboring land visually to avoid cracks, but actor collision and height queries remain terrain-owned.
- Wind is consumed through the adapter rather than coupling `LowPolyTerrain3D` directly to `WeatherManager`.
- Keep motion and highlights restrained enough for the painted-postcard art direction.

## Validation

- Run [`../../scenes/tests/test_low_poly_terrain_3d.tscn`](../../scenes/tests/test_low_poly_terrain_3d.tscn) after mesh, classification, material, or wind changes.
- Run [`../../scenes/tests/test_game_world_3d.tscn`](../../scenes/tests/test_game_world_3d.tscn) to verify wading limits and live weather-to-water propagation.
- Use the full app or the fixed production-world QA captures for visual checks of shoreline continuity, transparency, wave restraint, and actor readability.

## Out Of Scope

- A second 2D/tilemap water renderer.
- Boats, wakes, dynamic splashes, or gameplay rules based on water state.
