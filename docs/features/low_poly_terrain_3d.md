# Low Poly Terrain 3D Prototype

## Goal

- Explore whether the existing Kulangsu terrain mask can drive a calm low-poly 3D island presentation.
- Keep the experiment parallel to the current 2D overworld so the playable `game_main` flow remains stable.
- Reuse current terrain semantics instead of inventing a separate mask legend.
- Establish the terrain side of the low-poly visual style before any runtime 3D world integration.

## Current Status

- [`../../terrain/low_poly_terrain_3d.gd`](../../terrain/low_poly_terrain_3d.gd) reads the same terrain mask and `TerrainGenerationProfile` resource used by the 2D terrain generator.
- [`../../scenes/tests/test_low_poly_terrain_3d.tscn`](../../scenes/tests/test_low_poly_terrain_3d.tscn) is the focused validation scene.
- The prototype samples the `512 x 512` mask into coarse cells, then builds separate 3D meshes for:
  - water
  - smooth low-poly land
  - shoreline side walls
  - street overlays
  - building footprint overlays
  - optional land collision
- An optional grayscale `heightmap_file` can add terrain elevation offsets on top of `land_height`; by default those sampled heights are lightly smoothed into a connected sloped land mesh instead of block terraces.
- The scene uses an orthographic `Camera3D` and a simple directional light for a first low-poly island read.
- [`../../terrain/low_poly_art_style_3d.gd`](../../terrain/low_poly_art_style_3d.gd) defines `class_name LowPolyArtStyle3D`, the shared style-preset resource for terrain palette, camera, lighting, and landmark colors.
- [`../../terrain/low_poly_postcard_diorama_style.tres`](../../terrain/low_poly_postcard_diorama_style.tres) is the first Painted Postcard Diorama preset.
- [`../../terrain/low_poly_world_coordinates_3d.gd`](../../terrain/low_poly_world_coordinates_3d.gd) defines `class_name LowPolyWorldCoordinates3D`, the shared terrain-mask-pixel to 3D XZ world-position adapter, including helpers for rough 2D isometric authored positions.
- [`../../architecture/low_poly/low_poly_landmark_proxy_3d.gd`](../../architecture/low_poly/low_poly_landmark_proxy_3d.gd) defines `class_name LowPolyLandmarkProxy3D`, a simple reusable landmark-volume generator for early postcard-diorama house, church, tunnel, and tower silhouettes.
- [`../../scenes/tests/test_low_poly_world_3d.tscn`](../../scenes/tests/test_low_poly_world_3d.tscn) combines the terrain, land collision, `HumanBody3D`, `PlayerController3D`, `Camera3DController`, the five canonical `LowPolyLandmarkProxy3D` placeholders, coordinate round-tripping, and camera framing in one playable Painted Postcard Diorama validation slice.

## Ownership

- The current runtime 2D terrain remains owned by [`../../terrain/terrain.tscn`](../../terrain/terrain.tscn) and [`../../terrain/terrain.gd`](../../terrain/terrain.gd).
- The 3D prototype is owned by [`../../terrain/low_poly_terrain_3d.gd`](../../terrain/low_poly_terrain_3d.gd) and the focused test scene under [`../../scenes/tests/`](../../scenes/tests).
- Terrain mask meaning remains owned by [`../../terrain/terrain_generation_profile.gd`](../../terrain/terrain_generation_profile.gd), [`../../terrain/terrain_mask_rule.gd`](../../terrain/terrain_mask_rule.gd), and [`../../terrain/island_generation_profile.tres`](../../terrain/island_generation_profile.tres).
- Do not route story, save state, resident spawning, or main-scene weather through this prototype until an explicit 3D world-integration phase starts.

## Contracts

- The prototype must treat water the same way as the 2D terrain generator: pixels below `land_min_alpha_8bit` are water.
- Opaque blue terrain-rule pixels become street overlays.
- Opaque red terrain-rule pixels become building footprint overlays.
- Other opaque land pixels become low-poly land.
- The prototype should remain coarse and fast enough to regenerate in editor or headless validation.
- Generated mesh and collision nodes are runtime/editor transient children marked with metadata; they should not become serialized child content in the scene.
- Terrain sampling currently lets street or building pixels win the whole sampled cell. Treat that chunkiness as prototype style until a deliberate readability pass decides otherwise.
- Heightmaps are sampled at the same coarse cell resolution as the terrain mask, then `smooth_land_surface` builds connected low-poly surface facets by averaging adjacent cell heights at shared corners.
- `height_smoothing_passes` applies a small land-only blur before mesh creation. Keep it low so the terrain reads as simple low-poly slopes rather than noisy per-pixel relief.
- Turning `smooth_land_surface` off preserves the old block/terrace style with internal vertical height walls.
- Black heightmap pixels map to `heightmap_min_offset`, white pixels map to `heightmap_max_offset`, and the result is added to `land_height`; water remains at `water_height`.
- Assigning `heightmap_file` or editing heightmap min/max offsets is manual-apply by design: press the exported `rebuild` control or call `rebuild_from_source()` after those edits. This prevents large or imported heightmap images from rebuilding during the Inspector assignment itself.
- Any placement work must go through `LowPolyWorldCoordinates3D` instead of duplicating the current grid-centering or isometric-position conversion math in landmark, actor, or story code.
- Actor, landmark, and future hotspot placement should query `LowPolyTerrain3D.get_sample_cell_height(...)` after terrain generation when a heightmap is active.
- Style tuning should flow through `LowPolyArtStyle3D` presets before hardcoding scene-local color, camera, or lighting values.
- Editing values inside an assigned `LowPolyArtStyle3D` preset is manual-apply by design: press the exported `rebuild` control or call the relevant rebuild method after style edits. The prototype does not need automatic resource-change rebuilds.

## Visual Style Contract

- Keep the first 3D read orthographic, gently elevated, and island-focused rather than switching to a free camera too early.
- Use a calm, readable material palette: soft water, clear land/street/building contrast, and enough shoreline shadow/color separation to preserve the island silhouette.
- Prefer simple low-poly volume and silhouette clarity over texture detail.
- Keep water, land, streets, and building footprints as separate mesh/material passes until the intended art direction is proven.
- Treat landmark buildings as future silhouette anchors, not as terrain-mask side effects.
- Use the five canonical `LowPolyLandmarkProxy3D` placeholders for first-pass landmark massing before replacing proxies with bespoke low-poly landmark meshes.

## Extension Notes

- Use `sample_stride` to trade mask fidelity against mesh density.
- Use `cell_size`, `land_height`, `smooth_land_surface`, `height_smoothing_passes`, `street_lift`, and `building_footprint_lift` to tune the island scale and low-poly read.
- Use `heightmap_file`, `heightmap_min_offset`, and `heightmap_max_offset` to prototype island slopes, terraces, or hills without changing terrain mask semantics.
- After assigning or editing heightmap settings in the editor, manually rebuild affected terrain nodes before judging the elevation result.
- Tune palette, camera, sunlight, and proxy landmark colors through `low_poly_postcard_diorama_style.tres` while this scene remains the golden slice.
- After editing the style preset, manually rebuild affected terrain/proxy nodes or reload the validation scene before judging the new visual read.
- Use the combined world scene to tune terrain scale, land collision, actor scale, `Camera3DController` follow offset, landmark placeholder scale, and material readability together.
- Add interaction areas only after the five-placeholder blockout stays readable and the coordinate adapter placement contract remains stable.
- If this evolves into a real gameplay terrain layer, update this doc with navigation, landmark anchors, weather, and story-resume contracts.

## Validation

- Run:

```sh
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --scene res://scenes/tests/test_low_poly_terrain_3d.tscn --quit-after 1
```

- Confirm the scene loads and logs a summary like:

```text
LowPolyTerrain3D: built 512x512 source mask into 128x128 sampled cells ...
PASS: LowPolyTerrain3D heightmap smoke test
```

- Visual validation should check that the island silhouette, water/land split, sloped heightmap elevation, streets, and building footprint overlays are readable from the orthographic camera.
- Run the combined validation scene after coordinate, collision, player movement, or camera changes:

```sh
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --scene res://scenes/tests/test_low_poly_world_3d.tscn --quit-after 1
```

- Confirm the scene logs:

```text
PASS: LowPolyWorld3D smoke test
```
