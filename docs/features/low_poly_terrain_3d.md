# Low Poly Terrain 3D

## Goal

- Drive the production low-poly 3D island from the existing Kulangsu terrain mask and heightmap.
- Reuse current terrain semantics instead of inventing a separate mask legend.
- Keep terrain generation independently testable from runtime world integration.

## Current Status

- [`../../terrain/low_poly_terrain_3d.gd`](../../terrain/low_poly_terrain_3d.gd) reads the same terrain mask and `TerrainGenerationProfile` resource used by the 2D terrain generator, while allowing the heightmap to define the full low-poly land source area. The pipeline is split in three: [`../../terrain/low_poly_terrain_sampler.gd`](../../terrain/low_poly_terrain_sampler.gd) (`class_name LowPolyTerrainSampler`) turns the mask/heightmap images into a coarse [`../../terrain/low_poly_terrain_cell.gd`](../../terrain/low_poly_terrain_cell.gd) (`class_name LowPolyTerrainCell`, holding the `Kind` enum) grid using the cached [`../../terrain/low_poly_image_pixel_reader.gd`](../../terrain/low_poly_image_pixel_reader.gd) (`class_name LowPolyImagePixelReader`); [`../../terrain/low_poly_terrain_mesh_builder.gd`](../../terrain/low_poly_terrain_mesh_builder.gd) (`class_name LowPolyTerrainMeshBuilder`) turns that cell grid into low-poly mesh geometry (its `MeshBuildResult` holds one `MeshBuildState` per material pass plus collision faces and cell counts) and owns the shared corner/surface-height math; and the node owns exports, lifecycle, materials, wind, and the public surface-height queries (which delegate the corner/surface-height math to a cached `LowPolyTerrainMeshBuilder` so mesh geometry and placement queries never diverge).
- [`../../scenes/tests/test_low_poly_terrain_3d.tscn`](../../scenes/tests/test_low_poly_terrain_3d.tscn) is the focused validation scene.
- The prototype samples the terrain source into coarse cells, then builds separate 3D meshes for:
  - semi-transparent water at the configured water level, expanded over adjacent shoreline land cells, animated by the `resources/materials/water_3d.gdshader` spatial shader (real wave-geometry displacement: a sum-of-sines height field displaces the surface each frame with analytic normals and crest foam; the baked mesh stays flat at `water_height`)
  - semi-transparent water surface layer
  - shoreline water highlight bands
  - smooth low-poly land and visible seabed terrain
  - shoreline side walls for mask-clipped terrain
  - generated road/kerb/footpath assemblies derived from street-mask centerlines; STREET cells that cannot become a path render only as supporting land instead of a second mask overlay
  - building footprint overlays
  - optional land collision
- An optional grayscale `heightmap_file` can add terrain elevation offsets on top of `land_height`; by default it also expands land to the full heightmap source instead of clipping land to the mask.
- When `heightmap_expands_land_to_source` is enabled, the mask is still sampled for street and building-footprint colors above the waterline, while sampled heightmap elevation at or below `water_height` becomes water.
- The scene uses an orthographic `Camera3D` and a simple directional light for a first low-poly island read.
- [`../../terrain/low_poly_art_style_3d.gd`](../../terrain/low_poly_art_style_3d.gd) defines `class_name LowPolyArtStyle3D`, the shared style-preset resource for terrain palette, faceted water colors/tuning, camera, lighting, and landmark colors.
- [`../../terrain/low_poly_postcard_diorama_style.tres`](../../terrain/low_poly_postcard_diorama_style.tres) is the first Painted Postcard Diorama preset.
- [`../../terrain/low_poly_world_coordinates_3d.gd`](../../terrain/low_poly_world_coordinates_3d.gd) defines `class_name LowPolyWorldCoordinates3D`, the shared terrain-mask-pixel to 3D XZ world-position adapter, including helpers for rough 2D isometric authored positions.
- [`../../scenes/tests/test_low_poly_terrain_3d.tscn`](../../scenes/tests/test_low_poly_terrain_3d.tscn) owns terrain mesh, water-layer, wind-control, and coordinate round-trip checks; [`../../scenes/tests/test_street_mask_generation.tscn`](../../scenes/tests/test_street_mask_generation.tscn) owns explicit Street3D extraction including the real island source; [`../../scenes/tests/test_game_world_3d.tscn`](../../scenes/tests/test_game_world_3d.tscn) owns production-world terrain/generated-street, actor grounding/wading, camera, authored-landmark collision, and weather-to-water integration checks.
- [`../../scenes/tests/test_camera_3d_occlusion.tscn`](../../scenes/tests/test_camera_3d_occlusion.tscn) is the focused camera-occlusion regression for multiple blockers, target exclusion, and exact transparency restoration.

## Ownership

- The runtime terrain is owned by [`../../terrain/low_poly_terrain_3d.gd`](../../terrain/low_poly_terrain_3d.gd) and assembled by [`../../scenes/game_world_3d.tscn`](../../scenes/game_world_3d.tscn); focused tests remain under [`../../scenes/tests/`](../../scenes/tests).
- Street integration is a pre-mesh terrain stage. With `generate_streets_from_mask` enabled (the default), `LowPolyStreetPathExtractor` thins sampled STREET cells to deterministic centerlines and traces branch-to-branch multipoint paths through bends and junctions. Its centerline simplify pass runs at a tolerance above one cell (`generated_street_simplify_tolerance_cells`, default 1.2) so a diagonal mask line, which block downsampling snaps into a sub-cell staircase, collapses into a single straight run instead of a zigzag, while genuine multi-cell bends and curves survive. `LowPolyTerrain3D` instantiates Street3D assemblies beneath `GeneratedStreets`, samples each path from the untouched base grid, automatically clips compatible sibling street geometry at mid-span crossings while mitering kerbs and footpaths onto shared corners at branch/endpoint junctions so sidewalks connect, and automatically relaxes only an impossible generated-path riser limit enough to keep extreme heightmap slopes constructible. The same pass also discovers authored duck-typed sources beneath `street_source_root_path` (or the owning/current scene). `LowPolyStreetCorridorIntegrator` then lowers and feathers the supporting bed before terrain mesh/collision construction, converts corridor-core cells to plain land, and skips water by default. STREET cells remain semantic extraction input, but the terrain mesh builder renders them as supporting land; Street3D exclusively owns visible road, kerb, footpath, stair, material, mesh, and collision geometry.
- Generated streets are baked into the scene as definitions, not as geometry, and are not re-extracted on every load. The mask-to-centerline extraction only runs on an explicit rebuild — `rebuild_from_source()`, the `rebuild` toggle, or a terrain property change (i.e. "rebuild the terrain in the editor"). The `GeneratedStreets` subtree is owned by the edited scene so it serializes into the `.tscn`, but only each Street3D's definition persists: its centerline `path_points`, its sampled height `profile_points`, and its authored properties (road/kerb/footpath widths, colors, stair settings, ...). Those generated `Street_###` nodes remain individually editable in the Inspector: changing a street property rebuilds its visible geometry and resolves crossings and endpoint junctions directly from the current sibling Street3D definitions, without reading the terrain mask or rebuilding terrain. The supporting terrain bed refreshes from the stored corridors on scene load or an explicit reuse rebuild. An explicit full terrain rebuild deliberately re-extracts the mask and replaces individual overrides with the terrain's generated-street defaults. The mesh geometry is deliberately kept out of the file — `LowPolyTerrain3D` nulls generated street meshes on `NOTIFICATION_EDITOR_PRE_SAVE` and restores them on `NOTIFICATION_EDITOR_POST_SAVE` — and each Street3D rebuilds its mesh from the stored profile on load (`build_on_ready`). On scene load the terrain also reshapes its bed from the stored street corridors (`rebuild_reusing_generated_streets()`, also the `_ready` path) without re-extracting them. Because runtime never re-extracts, a scene must be rebuilt once in the editor to bake its streets. `GeneratedStreets` carries `GENERATED_STREET_ROOT_META` (not the transient `GENERATED_META`), so the per-rebuild clear that discards mesh/water children leaves baked streets intact.
- Terrain mask meaning remains owned by [`../../terrain/terrain_generation_profile.gd`](../../terrain/terrain_generation_profile.gd), [`../../terrain/terrain_mask_rule.gd`](../../terrain/terrain_mask_rule.gd), and [`../../terrain/island_generation_profile.tres`](../../terrain/island_generation_profile.tres).
- Keep story, save state, resident spawning, and weather orchestration in `game_world_3d`; `LowPolyTerrain3D` remains a rendering, collision, and placement-query subsystem.
- Water waves are wind-aware through a decoupled API: `LowPolyTerrain3D.set_wind(wind_angle_degrees, normalized_strength)` (plus the inspector-exported `wind_angle_degrees` / `wind_strength`) retunes the cached water materials live without a rebuild. The terrain never imports or reads `WeatherManager`.
- The weather connection lives in the integration layer: `WeatherManager` publishes live wind via the `wind_changed(angle, raw_strength)` signal plus `get_current_wind()` / `get_reference_wind_strength()`, and `terrain/low_poly_water_wind_adapter.gd` (`class_name LowPolyWaterWindAdapter`) binds a weather source to a terrain — duck-typed on both ends — normalizing raw wind into 0..1 and calling `set_wind()`. `game_world_3d.gd` owns that binding, and `test_game_world_3d.gd` verifies manager wind reaches the runtime water shader.

## Contracts

- Without heightmap expansion, the prototype treats water the same way as the 2D terrain generator: pixels below `land_min_alpha_8bit` are water.
- With `heightmap_expands_land_to_source` enabled and a heightmap assigned, the heightmap dimensions become the generated terrain source and every sampled heightmap cell at or below `water_height` becomes water; higher cells become land unless the mask upgrades them to STREET semantics or building-footprint overlays.
- Opaque blue terrain-rule pixels become sampled STREET cells. By default those cells generate centerline-based road/kerb/footpath assemblies. The terrain mesh builder does not create a parallel `StreetMesh`; untraced, water-skipped, or invalid fragments render as ordinary supporting land.
- Opaque red terrain-rule pixels become building footprint overlays.
- Other opaque land pixels become low-poly land.
- The prototype should remain coarse and fast enough to regenerate in editor or headless validation.
- Generated mesh and collision nodes are runtime/editor transient children marked with metadata; they should not become serialized child content in the scene.
- Mask-generated Street3D definitions persist beneath `GeneratedStreets` between loads and are replaced deterministically only on an explicit terrain rebuild. Their mesh buffers remain transient. Authored Street3D nodes remain the path for persistent manual profile-height edits outside the generated subtree.
- Terrain sampling currently lets street or building pixels win the whole sampled cell. Treat that chunkiness as prototype style until a deliberate readability pass decides otherwise.
- Heightmaps are sampled at the same coarse cell resolution as the terrain mask, then `smooth_land_surface` builds connected low-poly surface facets by averaging adjacent cell heights at shared corners.
- `height_smoothing_passes` applies a small blur before mesh creation. In heightmap-expanded mode it smooths the source heights before waterline classification; in mask-clipped mode it remains land-only. Keep it low so the terrain reads as simple low-poly slopes rather than noisy per-pixel relief.
- Turning `smooth_land_surface` off preserves the old block/terrace style with internal vertical height walls.
- Black heightmap pixels map to `heightmap_min_offset`, white pixels map to `heightmap_max_offset`, and the result is added to `land_height`; the final sampled height is compared with `water_height` when heightmap expansion is active.
- Assigning `heightmap_file`, editing `heightmap_expands_land_to_source`, or editing heightmap min/max offsets is manual-apply by design: press the exported `rebuild` control or call `rebuild_from_source()` after those edits. This prevents large or imported heightmap images from rebuilding during the Inspector assignment itself.
- Any placement work must go through `LowPolyWorldCoordinates3D` instead of duplicating the current grid-centering or isometric-position conversion math in landmark, actor, or story code.
- Landmark and future hotspot placement should query `LowPolyTerrain3D.get_world_surface_height(...)` or `LowPolyTerrain3D.get_sample_cell_height(...)` after terrain generation when a heightmap is active. In heightmap-expanded water, those queries deliberately return the underlying land/seabed elevation rather than the visual water plane, so seabed-anchored placement stays available.
- The moving actor wades through water rather than sinking to the seabed or standing on top of the water plane: `game_world_3d.gd` resolves ground height as `max(seabed, water_surface - MAX_ACTOR_WADE_DEPTH)`, combining `LowPolyTerrain3D.get_world_surface_height(...)` (seabed) with `get_world_water_surface_height(...)` (water plane). In shallow water the actor stands on the seabed; in deeper water it remains partially submerged and can step back onto shore. A physics raycast still takes precedence when it hits real collision. `test_game_world_3d.gd` owns the settling and water-cell regressions.
- When placement should rest on the visible water plane instead of the seabed (boats, water hotspots, or anything that should float), use `LowPolyTerrain3D.get_world_water_surface_height(...)` or `LowPolyTerrain3D.get_sample_cell_water_surface_height(...)`. These additive queries return `water_height` over water cells in both mask-clipped and heightmap-expanded modes and the land surface elsewhere; they do not change the seabed-following behavior of `get_world_surface_height`/`get_sample_cell_height`.
- Style tuning flows through `LowPolyArtStyle3D` presets, which are the single source of truth for the terrain palette and water tuning. The terrain node no longer exports its own `land_color`, `shoreline_color`, `building_footprint_color`, or the `water_*` color/wave/shoreline/surface-layer values; assign an `art_style`, or rely on the built-in default style when none is assigned. Street colors belong to each Street3D definition.
- The low-poly water pass generates a vertex-colored semi-transparent `WaterMesh` flat at `water_height`, a semi-transparent `WaterSurfaceLayerMesh` lifted over the same water area, and a separate translucent `WaterShorelineMesh`; all stay transient generated children like the land and collision helper nodes. All three water meshes share the `water_3d.gdshader` `ShaderMaterial` and the same world-space waves so they rise and fall together (the body passes `use_vertex_color = true`; the foam and gloss overlays pass a flat `base_color`). The layers are ordered by `render_priority` (body < shoreline foam < surface gloss) so they composite stably, and their geometry lifts stack in the same order. Animation is real wave-geometry displacement done in the vertex stage (`VERTEX.y` offset from a sum-of-sines height field with analytic normals), so the *baked* mesh stays flat at `water_height` and surface-height queries (`get_world_water_surface_height`, etc.) and validation remain valid against the flat geometry. The body alpha is `vertex_color.a * water_opacity`; overlays use `base_color.a`. Water tuning (`water_wave_depth` = vertical amplitude, `water_wave_frequency` = spatial frequency, `water_wave_speed` = animation rate, plus the lifts) lives in `LowPolyArtStyle3D`. The shader assumes the terrain root is axis-aligned (no rotation/scale) so a vertical `VERTEX.y` offset equals a vertical world offset. Wind feeds the shader as `wind_dir` (XZ travel direction) and `wind_strength` (0..1), which fan the wave directions around the wind and scale amplitude, speed, and choppiness; `set_wind()` updates all three cached water materials at once.
- `water_land_overlap_cells` expands only the rendered water footprint, defaulting to one adjacent land-cell ring so the water plane visually connects into the shoreline without converting those cells to water for terrain height, collision, or placement queries.
- Heightmap-expanded water cells keep their underlying terrain surface in `LandMesh` when the sampled height is below `water_height`, and dry land samples include neighboring submerged heights at shared corners so land continues into the seabed instead of ending at a vertical shoreline wall.
- The water surface layer should stay only slightly above `water_height`, below the shoreline highlight lift by default, so it reads as a calm glassy sheet without hiding the shoreline band.
- Editing values inside an assigned `LowPolyArtStyle3D` preset is manual-apply by design: press the exported `rebuild` control or call the relevant rebuild method after style edits. The prototype does not need automatic resource-change rebuilds.

## Visual Style Contract

- Keep the first 3D read orthographic, gently elevated, and island-focused rather than switching to a free camera too early.
- Let the player orbit the orthographic camera around the actor for inspection, while keeping zoom and follow behavior intact.
- Keep automatic target-occluder transparency enabled so collision-backed landmark parts between the camera and player fade without material replacement; tune the fade and query through `Camera3DController` exports.
- Use a calm, readable material palette: soft water, clear land/street/building contrast, and enough shoreline shadow/color separation to preserve the island silhouette.
- Prefer simple low-poly volume and silhouette clarity over texture detail.
- Keep water, the water surface layer, water shoreline highlights, land, Street3D assemblies, and building footprints as separate material owners until the intended art direction is proven; do not restore a mask-derived street mesh pass.
- Keep water treatment restrained: flat water level, vertex-color depth/shimmer, semi-transparent material, and narrow shoreline highlight bands should support the harbor-storybook atmosphere rather than becoming large waves or foam effects.
- Treat landmark buildings as future silhouette anchors, not as terrain-mask side effects.
- Use the Low-Poly Building Editor and versioned `BuildingSpec` pipeline for new landmark massing; the runtime owns three authored landmark scenes and stable marker anchors for the two unfinished tunnels.

## Extension Notes

- Use `sample_stride` to trade mask fidelity against mesh density.
- Use `cell_size`, `land_height`, `smooth_land_surface`, `height_smoothing_passes`, `street_lift`, and `building_footprint_lift` to tune the island scale, generated-street clearance, and low-poly read.
- Use `generate_streets_from_mask`, `generated_street_minimum_path_cells`, `generated_street_maximum_paths`, `generated_street_road_width_cells`, and `generated_street_footpath_width_cells` to control automatic street extraction and cross-section scale. Disabling `generate_streets_from_mask` stops mask-derived visible streets; authored Street3D corridor integration remains available.
- Use `heightmap_file`, `heightmap_expands_land_to_source`, `heightmap_min_offset`, `heightmap_max_offset`, and `water_height` to prototype full heightmap land, mask-clipped islands, terraces, hills, sea level, and exposed coastlines without changing terrain mask semantics.
- Use `water_color`, `water_deep_color`, `water_surface_layer_color`, `water_shoreline_color`, `water_highlight_color`, `water_wave_depth`, `water_wave_frequency`, `water_shoreline_band_ratio`, `water_shoreline_lift`, and `water_surface_layer_lift` on the shared `LowPolyArtStyle3D` style preset to tune the 3D water tint, transparency, shimmer, and shoreline read. `water_land_overlap_cells` stays on the terrain node since it controls geometry footprint, not palette.
- After assigning or editing heightmap settings in the editor, manually rebuild affected terrain nodes before judging the elevation result.
- Tune palette, camera, sunlight, and proxy landmark colors through `low_poly_postcard_diorama_style.tres` while this scene remains the golden slice.
- After editing the style preset, manually rebuild affected terrain/proxy nodes or reload the validation scene before judging the new visual read.
- Use the combined world scene to tune terrain scale, land collision, actor scale, `Camera3DController` follow offset, orbit rotation feel, landmark placeholder scale, and material readability together.
- Build one dedicated landmark interaction slice before visual-style acceptance so approach distance, camera occlusion, collision, subject range, resident scale, and resume placement inform the final terrain/camera tuning.
- If this evolves into a real gameplay terrain layer, update this doc with navigation, landmark anchors, weather, and story-resume contracts.

## Review Notes

Findings from a code review of the generator, recorded for follow-up.

Addressed:

- Mask classification reads pixels through a cached RGBA8 byte buffer (`_ImagePixelReader`) instead of per-pixel `Image.get_pixel`, which removes the main per-rebuild hot-loop cost at full-resolution masks.
- Street corridor shaping indexes profile segments into the sampled terrain cells covered by their road-and-feather bounds, so each cell evaluates only nearby segments instead of scanning every segment from every generated street. Generated-street junction resolution separately caches the current Street3D profiles and rejects plan-disjoint pairs before segment tests; it never reads the terrain mask.
- Grid centering math now has a single source of truth: `LowPolyWorldCoordinates3D.compute_world_origin(...)`. Both the coordinate adapter and `LowPolyTerrain3D._get_grid_origin_offset` call it so mesh placement and actor/landmark placement cannot silently desync.
- The heightmap image is normalized to `FORMAT_RGBA8` on load, matching the mask path.
- The exported `rebuild` toggle routes through `_request_rebuild()` so it respects readiness and the queued-rebuild guard instead of issuing a redundant deferred build.
- `test_low_poly_terrain_3d.gd` covers the non-expanded mask-clipped path, water layers, wind control, and `LowPolyWorldCoordinates3D` round trips.
- `test_street_terrain_integration.gd` covers automatic Street3D discovery, base-grid terrain sampling, corridor bed shaping, unaffected exterior terrain, manual profile-height preservation, coalesced terrain regeneration after an authored street-width change, and mask-independent intersection refresh plus override preservation after an individual generated-street width edit.
- `test_street_mask_generation.gd` covers STREET-cell centerline extraction, a bent multipoint path, generated sibling junction geometry, complete shared-endpoint joins across every three-or-more-arm fixture and real-island junction (including stair-bearing arms), a diagonal mask line collapsing to a straight two-point run instead of a staircase zigzag, visible generated Street3D mesh, absence of the obsolete mask-derived `StreetMesh`, corridor shaping, deterministic replacement on an explicit rebuild, a reuse rebuild that preserves stored street nodes, and a real-island rebuild that produces visible streets and stair segments. Focused T-junction surface ownership lives in the building editor's `test_street_3d.tscn`; `test_game_world_3d.gd` also asserts the production island has visible generated streets without the legacy overlay.
- Terrain palette and water tuning are no longer duplicated between the terrain node and `LowPolyArtStyle3D`. The node-level color/water exports were removed and all values resolve through `_effective_style()` (assigned `art_style`, else a built-in default style).
- Heightmap elevation sampling reads through the same cached pixel-reader RGBA8 buffer as the mask path instead of calling `Image.get_pixel` per cell.
- The generator was split along its natural seams. First the "images -> cell grid" sampling stage (classification, height smoothing, heightmap waterline, mask/heightmap pixel sampling) moved out of the monolithic node into `LowPolyTerrainSampler`, with the shared `LowPolyTerrainCell` (and its `Kind` enum) and `LowPolyImagePixelReader` promoted to their own files. Then the "cell grid -> meshes/collision" stage (the per-cell build loop, water-render-cell expansion, all the quad/side/water-band geometry helpers, and the corner/surface-height math) moved into `LowPolyTerrainMeshBuilder`, whose `build(...)` returns a `MeshBuildResult` of per-pass `MeshBuildState` buffers plus collision faces and cell counts, and whose `WaterRendering` type carries the resolved water palette/wave tuning. The node now configures a sampler and calls `build_grid(...)`, then configures a mesh builder (setting geometry params and a `WaterRendering` resolved from the art style) and calls `build(...)`, and only wraps the returned buffers in `MeshInstance3D`/material children, adds collision, and prints the summary. The node's public surface-height queries delegate to the same cached mesh builder via `get_cell_surface_height(...)`, so the node retains only exports, lifecycle, image loading, materials, wind, and style resolution. Behavior is unchanged.

Known tradeoffs left as-is for the prototype:

- Water, the water surface layer, and the shoreline bands are three semi-transparent passes with `CULL_DISABLED`; expect some transparency sort flicker at grazing angles. Acceptable for the current calm-water look.
- `_calculate_surface_normal` forces facet normals upward (`normal.y >= 0`). With flat low-poly shading this is fine for near-horizontal terrain but can mis-light very steep heightmap facets; revisit only if slopes read wrong.
- Terrain sampling still lets a single street or building pixel win an entire sampled cell (existing documented chunkiness).

## Validation

- Run:

```sh
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --scene res://scenes/tests/test_low_poly_terrain_3d.tscn
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --scene res://scenes/tests/test_street_terrain_integration.tscn
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --scene res://scenes/tests/test_street_mask_generation.tscn
```

- Confirm the scene loads and logs a summary like:

```text
LowPolyTerrain3D: built 512x512 source into 128x128 sampled cells ...
PASS: LowPolyTerrain3D heightmap smoke test
```

- Visual validation should check that heightmap-expanded water follows `water_height`, the transparent water plane reveals seabed terrain, dry land continues into the seabed without vertical shoreline walls, the rendered water footprint overlaps one adjacent shoreline land cell by default, mask-clipped water/land split still works, the semi-transparent top water layer and shoreline highlights remain readable, edited Street3D road/kerb/footpath colors remain visible under the production ambient-color lighting, and sloped heightmap elevation, streets, and building footprint overlays are clear from the orthographic camera.
- Screenshot QA should use the production-world QA runner and confirm the render is nonblank, the player is readable, authored landmarks and tunnel anchors compose coherently, and water/seabed layering remains legible.
- Run the production-world smoke after coordinate, collision, player movement, camera, or weather-adapter changes:

```sh
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --scene res://scenes/tests/test_game_world_3d.tscn
```

- Confirm the scene logs:

```text
PASS: game_world_3d smoke test
```

- Every headless scene must return process status `0`; assertion failures return nonzero.
- Run the focused camera-occlusion regression after changing `Camera3DController` transparency or ray-query behavior:

```sh
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --scene res://scenes/tests/test_camera_3d_occlusion.tscn
```
