# Low Poly Terrain 3D Prototype

## Goal

- Explore whether the existing Kulangsu terrain mask and heightmap can drive a calm low-poly 3D island presentation.
- Keep the experiment parallel to the current 2D overworld so the playable `game_main` flow remains stable.
- Reuse current terrain semantics instead of inventing a separate mask legend.
- Establish the terrain side of the low-poly visual style before any runtime 3D world integration.

## Current Status

- [`../../terrain/low_poly_terrain_3d.gd`](../../terrain/low_poly_terrain_3d.gd) reads the same terrain mask and `TerrainGenerationProfile` resource used by the 2D terrain generator, while allowing the heightmap to define the full low-poly land source area. The pipeline is split in two: [`../../terrain/low_poly_terrain_sampler.gd`](../../terrain/low_poly_terrain_sampler.gd) (`class_name LowPolyTerrainSampler`) turns the mask/heightmap images into a coarse [`../../terrain/low_poly_terrain_cell.gd`](../../terrain/low_poly_terrain_cell.gd) (`class_name LowPolyTerrainCell`, holding the `Kind` enum) grid using the cached [`../../terrain/low_poly_image_pixel_reader.gd`](../../terrain/low_poly_image_pixel_reader.gd) (`class_name LowPolyImagePixelReader`), and the node owns turning that grid into meshes/collision plus the surface-height queries.
- [`../../scenes/tests/test_low_poly_terrain_3d.tscn`](../../scenes/tests/test_low_poly_terrain_3d.tscn) is the focused validation scene.
- The prototype samples the terrain source into coarse cells, then builds separate 3D meshes for:
  - semi-transparent water at the configured water level, expanded over adjacent shoreline land cells, animated by the `resources/materials/water_3d.gdshader` spatial shader (real wave-geometry displacement: a sum-of-sines height field displaces the surface each frame with analytic normals and crest foam; the baked mesh stays flat at `water_height`)
  - semi-transparent water surface layer
  - shoreline water highlight bands
  - smooth low-poly land and visible seabed terrain
  - shoreline side walls for mask-clipped terrain
  - street overlays
  - building footprint overlays
  - optional land collision
- An optional grayscale `heightmap_file` can add terrain elevation offsets on top of `land_height`; by default it also expands land to the full heightmap source instead of clipping land to the mask.
- When `heightmap_expands_land_to_source` is enabled, the mask is still sampled for street and building-footprint colors above the waterline, while sampled heightmap elevation at or below `water_height` becomes water.
- The scene uses an orthographic `Camera3D` and a simple directional light for a first low-poly island read.
- [`../../terrain/low_poly_art_style_3d.gd`](../../terrain/low_poly_art_style_3d.gd) defines `class_name LowPolyArtStyle3D`, the shared style-preset resource for terrain palette, faceted water colors/tuning, camera, lighting, and landmark colors.
- [`../../terrain/low_poly_postcard_diorama_style.tres`](../../terrain/low_poly_postcard_diorama_style.tres) is the first Painted Postcard Diorama preset.
- [`../../terrain/low_poly_world_coordinates_3d.gd`](../../terrain/low_poly_world_coordinates_3d.gd) defines `class_name LowPolyWorldCoordinates3D`, the shared terrain-mask-pixel to 3D XZ world-position adapter, including helpers for rough 2D isometric authored positions.
- [`../../architecture/low_poly/low_poly_landmark_proxy_3d.gd`](../../architecture/low_poly/low_poly_landmark_proxy_3d.gd) defines `class_name LowPolyLandmarkProxy3D`, a simple reusable landmark-volume generator for early postcard-diorama house, church, tunnel, and tower silhouettes. Each generated part (wall/body boxes, tower cylinders, gable roofs) also parents static collision by default (`generate_collision`) so the character is blocked by the landmark walls and roof.
- [`../../scenes/tests/test_low_poly_world_3d.tscn`](../../scenes/tests/test_low_poly_world_3d.tscn) combines the terrain, land collision, terrain-following `HumanBody3D`, `PlayerController3D`, `Camera3DController`, the five canonical `LowPolyLandmarkProxy3D` placeholders, coordinate round-tripping, camera orbit rotation, and camera framing in one playable Painted Postcard Diorama validation slice.

## Ownership

- The current runtime 2D terrain remains owned by [`../../terrain/terrain.tscn`](../../terrain/terrain.tscn) and [`../../terrain/terrain.gd`](../../terrain/terrain.gd).
- The 3D prototype is owned by [`../../terrain/low_poly_terrain_3d.gd`](../../terrain/low_poly_terrain_3d.gd) and the focused test scene under [`../../scenes/tests/`](../../scenes/tests).
- Terrain mask meaning remains owned by [`../../terrain/terrain_generation_profile.gd`](../../terrain/terrain_generation_profile.gd), [`../../terrain/terrain_mask_rule.gd`](../../terrain/terrain_mask_rule.gd), and [`../../terrain/island_generation_profile.tres`](../../terrain/island_generation_profile.tres).
- Do not route story, save state, resident spawning, or main-scene weather through this prototype until the parallel 3D lane has green combined smoke tests, accepted visual QA screenshots, a stable interaction contract, an acceptable performance budget, and a written story/resident ownership plan.
- Water waves are wind-aware through a decoupled API: `LowPolyTerrain3D.set_wind(wind_angle_degrees, normalized_strength)` (plus the inspector-exported `wind_angle_degrees` / `wind_strength`) retunes the cached water materials live without a rebuild. The terrain never imports or reads `WeatherManager`.
- The weather connection lives in the integration layer: `WeatherManager` publishes live wind via the `wind_changed(angle, raw_strength)` signal plus `get_current_wind()` / `get_reference_wind_strength()`, and `terrain/low_poly_water_wind_adapter.gd` (`class_name LowPolyWaterWindAdapter`) binds a weather source to a terrain — duck-typed on both ends — normalizing raw wind into 0..1 and calling `set_wind()`. `scenes/tests/test_low_poly_world_3d.gd` acquires the global `WeatherManager` (via `WeatherRuntime`), binds the adapter, and feeds a gusting stand-in into the manager (the 3D slice has no 2D overlays to cycle) so the full weather -> adapter -> water path runs until the lane is cleared to consume the real cycle.

## Contracts

- Without heightmap expansion, the prototype treats water the same way as the 2D terrain generator: pixels below `land_min_alpha_8bit` are water.
- With `heightmap_expands_land_to_source` enabled and a heightmap assigned, the heightmap dimensions become the generated terrain source and every sampled heightmap cell at or below `water_height` becomes water; higher cells become land unless the mask upgrades them to street or building-footprint overlays.
- Opaque blue terrain-rule pixels become street overlays.
- Opaque red terrain-rule pixels become building footprint overlays.
- Other opaque land pixels become low-poly land.
- The prototype should remain coarse and fast enough to regenerate in editor or headless validation.
- Generated mesh and collision nodes are runtime/editor transient children marked with metadata; they should not become serialized child content in the scene.
- Terrain sampling currently lets street or building pixels win the whole sampled cell. Treat that chunkiness as prototype style until a deliberate readability pass decides otherwise.
- Heightmaps are sampled at the same coarse cell resolution as the terrain mask, then `smooth_land_surface` builds connected low-poly surface facets by averaging adjacent cell heights at shared corners.
- `height_smoothing_passes` applies a small blur before mesh creation. In heightmap-expanded mode it smooths the source heights before waterline classification; in mask-clipped mode it remains land-only. Keep it low so the terrain reads as simple low-poly slopes rather than noisy per-pixel relief.
- Turning `smooth_land_surface` off preserves the old block/terrace style with internal vertical height walls.
- Black heightmap pixels map to `heightmap_min_offset`, white pixels map to `heightmap_max_offset`, and the result is added to `land_height`; the final sampled height is compared with `water_height` when heightmap expansion is active.
- Assigning `heightmap_file`, editing `heightmap_expands_land_to_source`, or editing heightmap min/max offsets is manual-apply by design: press the exported `rebuild` control or call `rebuild_from_source()` after those edits. This prevents large or imported heightmap images from rebuilding during the Inspector assignment itself.
- Any placement work must go through `LowPolyWorldCoordinates3D` instead of duplicating the current grid-centering or isometric-position conversion math in landmark, actor, or story code.
- Actor, landmark, and future hotspot placement should query `LowPolyTerrain3D.get_world_surface_height(...)` or `LowPolyTerrain3D.get_sample_cell_height(...)` after terrain generation when a heightmap is active. In heightmap-expanded water, those queries deliberately return the underlying land/seabed elevation rather than the visual water plane, so moving actors follow terrain height for now (this is asserted by `test_low_poly_world_3d.gd`).
- When placement should rest on the visible water plane instead of the seabed (boats, water hotspots, or actors that should not sink), use `LowPolyTerrain3D.get_world_water_surface_height(...)` or `LowPolyTerrain3D.get_sample_cell_water_surface_height(...)`. These additive queries return `water_height` over water cells in both mask-clipped and heightmap-expanded modes and the land surface elsewhere; they do not change the seabed-following behavior of `get_world_surface_height`/`get_sample_cell_height`.
- Style tuning flows through `LowPolyArtStyle3D` presets, which are the single source of truth for the terrain palette and water tuning. The terrain node no longer exports its own `land_color`, `shoreline_color`, `street_color`, `building_footprint_color`, or the `water_*` color/wave/shoreline/surface-layer values; assign an `art_style`, or rely on the built-in default style when none is assigned.
- The low-poly water pass generates a vertex-colored semi-transparent `WaterMesh` flat at `water_height`, a semi-transparent `WaterSurfaceLayerMesh` lifted over the same water area, and a separate translucent `WaterShorelineMesh`; all stay transient generated children like the land, street, and collision helper nodes. All three water meshes share the `water_3d.gdshader` `ShaderMaterial` and the same world-space waves so they rise and fall together (the body passes `use_vertex_color = true`; the foam and gloss overlays pass a flat `base_color`). The layers are ordered by `render_priority` (body < shoreline foam < surface gloss) so they composite stably, and their geometry lifts stack in the same order. Animation is real wave-geometry displacement done in the vertex stage (`VERTEX.y` offset from a sum-of-sines height field with analytic normals), so the *baked* mesh stays flat at `water_height` and surface-height queries (`get_world_water_surface_height`, etc.) and validation remain valid against the flat geometry. The body alpha is `vertex_color.a * water_opacity`; overlays use `base_color.a`. Water tuning (`water_wave_depth` = vertical amplitude, `water_wave_frequency` = spatial frequency, `water_wave_speed` = animation rate, plus the lifts) lives in `LowPolyArtStyle3D`. The shader assumes the terrain root is axis-aligned (no rotation/scale) so a vertical `VERTEX.y` offset equals a vertical world offset. Wind feeds the shader as `wind_dir` (XZ travel direction) and `wind_strength` (0..1), which fan the wave directions around the wind and scale amplitude, speed, and choppiness; `set_wind()` updates all three cached water materials at once.
- `water_land_overlap_cells` expands only the rendered water footprint, defaulting to one adjacent land-cell ring so the water plane visually connects into the shoreline without converting those cells to water for terrain height, collision, or placement queries.
- Heightmap-expanded water cells keep their underlying terrain surface in `LandMesh` when the sampled height is below `water_height`, and dry land samples include neighboring submerged heights at shared corners so land continues into the seabed instead of ending at a vertical shoreline wall.
- The water surface layer should stay only slightly above `water_height`, below the shoreline highlight lift by default, so it reads as a calm glassy sheet without hiding the shoreline band.
- Editing values inside an assigned `LowPolyArtStyle3D` preset is manual-apply by design: press the exported `rebuild` control or call the relevant rebuild method after style edits. The prototype does not need automatic resource-change rebuilds.

## Visual Style Contract

- Keep the first 3D read orthographic, gently elevated, and island-focused rather than switching to a free camera too early.
- Let the player orbit the orthographic camera around the actor for inspection, while keeping zoom and follow behavior intact.
- Use a calm, readable material palette: soft water, clear land/street/building contrast, and enough shoreline shadow/color separation to preserve the island silhouette.
- Prefer simple low-poly volume and silhouette clarity over texture detail.
- Keep water, the water surface layer, water shoreline highlights, land, streets, and building footprints as separate mesh/material passes until the intended art direction is proven.
- Keep water treatment restrained: flat water level, vertex-color depth/shimmer, semi-transparent material, and narrow shoreline highlight bands should support the harbor-storybook atmosphere rather than becoming large waves or foam effects.
- Treat landmark buildings as future silhouette anchors, not as terrain-mask side effects.
- Use the five canonical `LowPolyLandmarkProxy3D` placeholders for first-pass landmark massing before replacing proxies with bespoke low-poly landmark meshes.

## Extension Notes

- Use `sample_stride` to trade mask fidelity against mesh density.
- Use `cell_size`, `land_height`, `smooth_land_surface`, `height_smoothing_passes`, `street_lift`, and `building_footprint_lift` to tune the island scale and low-poly read.
- Use `heightmap_file`, `heightmap_expands_land_to_source`, `heightmap_min_offset`, `heightmap_max_offset`, and `water_height` to prototype full heightmap land, mask-clipped islands, terraces, hills, sea level, and exposed coastlines without changing terrain mask semantics.
- Use `water_color`, `water_deep_color`, `water_surface_layer_color`, `water_shoreline_color`, `water_highlight_color`, `water_wave_depth`, `water_wave_frequency`, `water_shoreline_band_ratio`, `water_shoreline_lift`, and `water_surface_layer_lift` on the shared `LowPolyArtStyle3D` style preset to tune the 3D water tint, transparency, shimmer, and shoreline read. `water_land_overlap_cells` stays on the terrain node since it controls geometry footprint, not palette.
- After assigning or editing heightmap settings in the editor, manually rebuild affected terrain nodes before judging the elevation result.
- Tune palette, camera, sunlight, and proxy landmark colors through `low_poly_postcard_diorama_style.tres` while this scene remains the golden slice.
- After editing the style preset, manually rebuild affected terrain/proxy nodes or reload the validation scene before judging the new visual read.
- Use the combined world scene to tune terrain scale, land collision, actor scale, `Camera3DController` follow offset, orbit rotation feel, landmark placeholder scale, and material readability together.
- Add interaction areas only after the five-placeholder blockout stays readable and the coordinate adapter placement contract remains stable.
- If this evolves into a real gameplay terrain layer, update this doc with navigation, landmark anchors, weather, and story-resume contracts.

## Review Notes

Findings from a code review of the generator, recorded for follow-up.

Addressed:

- Mask classification reads pixels through a cached RGBA8 byte buffer (`_ImagePixelReader`) instead of per-pixel `Image.get_pixel`, which removes the main per-rebuild hot-loop cost at full-resolution masks.
- Grid centering math now has a single source of truth: `LowPolyWorldCoordinates3D.compute_world_origin(...)`. Both the coordinate adapter and `LowPolyTerrain3D._get_grid_origin_offset` call it so mesh placement and actor/landmark placement cannot silently desync.
- The heightmap image is normalized to `FORMAT_RGBA8` on load, matching the mask path.
- The exported `rebuild` toggle routes through `_request_rebuild()` so it respects readiness and the queued-rebuild guard instead of issuing a redundant deferred build.
- `test_low_poly_terrain_3d.gd` now also covers the non-expanded mask-clipped path (synthetic water-border mask), asserting land/water/shoreline meshes and water/land cell classification.
- Terrain palette and water tuning are no longer duplicated between the terrain node and `LowPolyArtStyle3D`. The node-level color/water exports were removed and all values resolve through `_effective_style()` (assigned `art_style`, else a built-in default style), so a scene can no longer set a node color that the style silently overrides. The previously dead `water_color` override in `test_low_poly_world_3d.tscn` was removed.
- Heightmap elevation sampling reads through the same cached pixel-reader RGBA8 buffer as the mask path instead of calling `Image.get_pixel` per cell.
- The generator was split along its natural seam: the "images -> cell grid" sampling stage (classification, height smoothing, heightmap waterline, mask/heightmap pixel sampling) moved out of the monolithic node into `LowPolyTerrainSampler`, with the shared `LowPolyTerrainCell` (and its `Kind` enum) and `LowPolyImagePixelReader` promoted to their own files. The node still owns exports, lifecycle, the `cell grid -> meshes/collision` build, and the public surface-height queries. Behavior is unchanged; the node configures a sampler and calls `build_grid(...)`. The `cell grid -> meshes` mesh-builder half is the remaining future extraction.

Known tradeoffs left as-is for the prototype:

- Water, the water surface layer, and the shoreline bands are three semi-transparent passes with `CULL_DISABLED`; expect some transparency sort flicker at grazing angles. Acceptable for the current calm-water look.
- `_calculate_surface_normal` forces facet normals upward (`normal.y >= 0`). With flat low-poly shading this is fine for near-horizontal terrain but can mis-light very steep heightmap facets; revisit only if slopes read wrong.
- Terrain sampling still lets a single street or building pixel win an entire sampled cell (existing documented chunkiness).

## Validation

- Run:

```sh
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --scene res://scenes/tests/test_low_poly_terrain_3d.tscn --quit-after 1
```

- Confirm the scene loads and logs a summary like:

```text
LowPolyTerrain3D: built 512x512 source into 128x128 sampled cells ...
PASS: LowPolyTerrain3D heightmap smoke test
```

- Visual validation should check that heightmap-expanded water follows `water_height`, the transparent water plane reveals seabed terrain, dry land continues into the seabed without vertical walls, the rendered water footprint overlaps one adjacent shoreline land cell by default, mask-clipped water/land split still works, the semi-transparent top water layer and shoreline highlights remain readable, and sloped heightmap elevation, streets, and building footprint overlays are clear from the orthographic camera.
- Screenshot QA should capture the combined world scene from its fixed validation camera and confirm the render is nonblank, the player is readable, all five landmark proxies are visible enough for blockout review, water/seabed layering is legible, and terrain or UI elements do not incoherently overlap.
- Run the combined validation scene after coordinate, collision, player movement, or camera changes:

```sh
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --scene res://scenes/tests/test_low_poly_world_3d.tscn --quit-after 1
```

- Confirm the scene logs:

```text
PASS: LowPolyWorld3D smoke test
```
