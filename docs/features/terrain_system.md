# Terrain System

## Goal

Build the production island as a low-poly 3D surface from authored mask and heightmap data while keeping terrain semantics data-driven and deterministic.

## Ownership

- [`../../scenes/game_world_3d.tscn`](../../scenes/game_world_3d.tscn) owns production-world integration and instances `LowPolyTerrain3D`.
- [`../../terrain/low_poly_terrain_3d.gd`](../../terrain/low_poly_terrain_3d.gd) owns terrain lifecycle, mesh/collision children, materials, rebuilds, and public height queries.
- [`../../terrain/low_poly_terrain_sampler.gd`](../../terrain/low_poly_terrain_sampler.gd) samples the mask and optional heightmap into typed terrain cells.
- [`../../terrain/low_poly_terrain_mesh_builder.gd`](../../terrain/low_poly_terrain_mesh_builder.gd) converts sampled cells into land, building, shoreline, seabed, water, and collision geometry. STREET-classified cells render as supporting land because generated/authored Street3D nodes exclusively own visible streets.
- [`../../terrain/terrain_generation_profile.gd`](../../terrain/terrain_generation_profile.gd), [`../../terrain/terrain_mask_rule.gd`](../../terrain/terrain_mask_rule.gd), and [`../../terrain/island_generation_profile.tres`](../../terrain/island_generation_profile.tres) own the authored mask legend and generation defaults.
- [`../../terrain/low_poly_world_coordinates_3d.gd`](../../terrain/low_poly_world_coordinates_3d.gd) converts mask pixels and retained authored isometric coordinates into 3D world positions.
- [`../../terrain/low_poly_street_path_extractor.gd`](../../terrain/low_poly_street_path_extractor.gd) and [`../../terrain/low_poly_street_corridor_integrator.gd`](../../terrain/low_poly_street_corridor_integrator.gd) own generated street paths and terrain-bed integration.

The retired `TileMapLayer` terrain scene, 2D water setup, tilesets, and shoreline collision layer were removed after the 3D runtime cutover. Source-control history is the rollback/reference path.

## Contracts

- Quantize source colors and alpha before matching rules so imported image formats do not alter semantics.
- Pixels below `land_min_alpha_8bit` are water unless the generation profile is intentionally changed.
- New mask meanings begin as a `TerrainMaskRule`; extend generator code only for genuinely new output behavior.
- Keep generation presentation-focused. Story, save, progression, and UI logic do not belong in terrain code.
- Height and surface queries used by actors, landmarks, streets, and resume anchors must use the same sampled data as mesh generation.
- Generated meshes and collisions are transient scene children; do not serialize generated buffers into the authored world scene.

## Water

Water is part of the `LowPolyTerrain3D` pipeline. It consists of continuous visible seabed plus layered 3D water meshes, shoreline bands, the spatial shader in [`../../resources/materials/water_3d.gdshader`](../../resources/materials/water_3d.gdshader), and wind updates through [`../../terrain/low_poly_water_wind_adapter.gd`](../../terrain/low_poly_water_wind_adapter.gd). See [`terrain_water_rendering.md`](terrain_water_rendering.md).

## Validation

- Run [`../../scenes/tests/test_low_poly_terrain_3d.tscn`](../../scenes/tests/test_low_poly_terrain_3d.tscn) for sampling, mesh, collision, water, and coordinate round-trip coverage.
- Run [`../../scenes/tests/test_street_mask_generation.tscn`](../../scenes/tests/test_street_mask_generation.tscn) and [`../../scenes/tests/test_street_terrain_integration.tscn`](../../scenes/tests/test_street_terrain_integration.tscn) for street generation changes.
- Run [`../../scenes/tests/test_game_world_3d.tscn`](../../scenes/tests/test_game_world_3d.tscn) for production integration, actor grounding/wading, landmarks, residents, weather, and resume anchors.

## Out Of Scope

- Runtime terrain deformation, erosion, or biome simulation.
- Gameplay state stored in generated terrain cells.
- Reintroducing a parallel 2D overworld or tilemap terrain path.
