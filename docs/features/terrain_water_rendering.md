# Terrain Water Rendering

## Goal

- Keep the island coastline readable and calm without breaking isometric tile seams.
- Give future water-render improvements a single implementation-facing note that explains where the shoreline logic lives and what constraints it must preserve.

## User / Player Experience

- Open water should feel soft, clearly blue, gently animated, and lightly translucent rather than noisy, murky, or overprocessed.
- Water should support the game's harbor-storybook atmosphere instead of drawing attention to the rendering technique.

## Rules

- The water base remains a single generated `TileMapLayer` populated from transparent pixels in the terrain mask and attached directly under the terrain root so it stays independent from the ground helper layers.
- Water rendering is built from four active layers of responsibility:
- blue body color
- world-space water animation and waves
- semi-transparent compositing
- background distortion through screen refraction
- Water tile art must remain visually seamless across neighboring cells; avoid per-tile UV warps that break atlas edges.
- Semi-transparent water should preserve the base tile alpha first, then layer tint and refraction on top so the water remains visible on `TileMapLayer` rendering paths.
- Refraction should support the water read, not replace it. If the sea starts looking muddy or brown, pull distortion influence back before changing terrain generation.
- Tool-generated terrain helpers should stay transient and unowned so they do not show up in the editor scene tree or accumulate large serialized `TileMapLayer` caches in `terrain.tscn`.
- Water and foam changes should stay calm and restrained. Favor subtle motion and shoreline readability over dramatic wave effects.

## Edge Cases

- Mask boundary checks must safely treat out-of-bounds pixels as non-land.
- Because terrain is generated in a `@tool` script, scene validation in the editor can dirty generated nodes. Keep an eye on accidental `.tscn` churn.
- If generated terrain helper nodes ever start showing up in the scene tree again, treat that as a regression and remove their owner/serialization path before tuning water visuals.
- If water ever looks inactive, confirm whether the issue is shader hookup, wave motion strength, or scene composition before reworking the material again.
- If background distortion is hard to see, confirm that useful scenery is actually rendered behind the water layer before increasing the refraction further.
- If white seam lines appear after a transparency pass, check alpha-mask stability and atlas-edge sampling before changing terrain generation.
- If animation becomes too subtle after a transparency pass, strengthen self-driven tint or highlight motion before relying on more screen distortion.

## Architecture / Ownership

- [`../../terrain.tscn`](../../terrain.tscn) and [`../../terrain.gd`](../../terrain.gd) own water tile generation.
- [`../../resources/materials/water.tres`](../../resources/materials/water.tres) and [`../../resources/materials/water.gdshader`](../../resources/materials/water.gdshader) own the blue water body, wave animation, semi-transparent tinting, and screen-space refraction treatment.
- Keep water rendering local to terrain/common rendering helpers. Do not move it into UI, `AppState`, or unrelated gameplay modules.

## Relevant Files

- Scenes:
- [`../../scenes/test_water_render.tscn`](../../scenes/test_water_render.tscn)
- [`../../terrain.tscn`](../../terrain.tscn)
- Scripts:
- [`../../scenes/test_water_render.gd`](../../scenes/test_water_render.gd)
- [`../../terrain.gd`](../../terrain.gd)
- Materials:
- [`../../resources/materials/water.tres`](../../resources/materials/water.tres)
- [`../../resources/materials/water.gdshader`](../../resources/materials/water.gdshader)
- Related docs:
- [`../module_map.md`](../module_map.md)

## Signals / Nodes / Data Flow

- Signals emitted:
- None dedicated to water rendering.
- Signals consumed:
- None dedicated to water rendering.
- Important node paths, dictionaries, resources, or data flow:
- `terrain.gd` reads `mask_file`, paints land/street/building layers, then fills water for transparent pixels.
- `water.tres` points to `water.gdshader`, which applies world-space wave motion, a blue water body, semi-transparent compositing, and light screen refraction on the water layer.

## Contracts / Boundaries

- Transparent pixels in the terrain mask are still the source of truth for water placement.
- The water layer must stay compatible with the existing isometric `TileMapLayer` placement conventions, but it should not depend on editor snapping from [`../../common/isometric_block.gd`](../../common/isometric_block.gd) because it is generated, not hand-placed.
- If terrain generation stops being mask-driven, this doc and [`../module_map.md`](../module_map.md) should be updated.
- If shoreline foam moves from procedural drawing to atlas/mesh-based content, update this doc with the new asset ownership and validation steps.

## Validation

- Use [`../../scenes/test_water_render.tscn`](../../scenes/test_water_render.tscn) for focused water tuning before checking the full terrain scene.
- The test scene root exposes a `rebuild` toggle in the inspector so water tiles and the guide backdrop can be refreshed after local scene edits.
- Run [`../../terrain.tscn`](../../terrain.tscn) directly after water changes.
- Confirm `_reload_terrain: painted ...` appears without new terrain/water parse errors.
- Visually check four things:
- water tiles remain seamless
- blue color and wave motion remain readable before any refraction detail
- motion stays subtle enough for the harbor tone

## Out Of Scope

- Dynamic wake systems, boats, splashes, or resident interaction ripples.
- Full shoreline terrain autotiling or depth-based water simulation.
- Gameplay logic based on water state.
