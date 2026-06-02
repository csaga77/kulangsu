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
  - land
  - shoreline side walls
  - street overlays
  - building footprint overlays
  - optional land collision
- The scene uses an orthographic `Camera3D` and a simple directional light for a first low-poly island read.
- The prototype does not yet provide the canonical coordinate adapter needed for 3D landmark anchors, resident spawns, story resume anchors, or interaction hotspots.

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
- Any placement work must go through an explicit mask-pixel to 3D-world coordinate adapter instead of duplicating the current grid-centering math in landmark, actor, or story code.

## Visual Style Contract

- Keep the first 3D read orthographic, gently elevated, and island-focused rather than switching to a free camera too early.
- Use a calm, readable material palette: soft water, clear land/street/building contrast, and enough shoreline shadow/color separation to preserve the island silhouette.
- Prefer simple low-poly volume and silhouette clarity over texture detail.
- Keep water, land, streets, and building footprints as separate mesh/material passes until the intended art direction is proven.
- Treat landmark buildings as future silhouette anchors, not as terrain-mask side effects.

## Extension Notes

- Use `sample_stride` to trade mask fidelity against mesh density.
- Use `cell_size`, `land_height`, `street_lift`, and `building_footprint_lift` to tune the island scale and low-poly read.
- Add a stable 2D-mask-pixel to 3D-world coordinate adapter before wiring landmarks, residents, interaction hotspots, or story resume anchors.
- The next validation scene should combine terrain, land collision, `HumanBody3D`, `PlayerController3D`, and camera framing instead of validating terrain and actor behavior separately forever.
- If this evolves into a real gameplay terrain layer, update this doc with navigation, landmark anchors, weather, and story-resume contracts.

## Validation

- Run:

```sh
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --scene res://scenes/tests/test_low_poly_terrain_3d.tscn --quit-after 1
```

- Confirm the scene loads and logs a summary like:

```text
LowPolyTerrain3D: built 512x512 source mask into 128x128 sampled cells ...
```

- Visual validation should check that the island silhouette, water/land split, streets, and building footprint overlays are readable from the orthographic camera.
- Future combined validation should use `test_low_poly_world_3d.tscn` or an equivalent scene name once the coordinate adapter and playable 3D slice exist.
