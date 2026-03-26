# Terrain System

## Goal

- Make island-terrain edits predictable for future agents by separating terrain semantics from the scene-owning paint loop.
- Keep the current mask-driven workflow, but move the terrain legend into small typed resources so most changes stay data-oriented instead of branch-oriented.

## User / Player Experience

- The island should continue to read as one authored place with calm coastlines, clear streets, and stable building masking.
- Terrain changes should preserve landmark placement and traversal readability instead of feeling procedurally unstable.

## Rules

- `terrain/terrain.tscn` remains the owning scene for authored island content, landmark placement, and generated helper layers.
- `terrain/terrain.gd` remains the scene owner that rebuilds generated layers from the terrain mask and keeps the tunnel-related masking hooks working.
- `terrain/terrain_generation_profile.gd` is the source of truth for generated-layer defaults such as land, water, street-connect, and building-mask tile outputs.
- `terrain/terrain_mask_rule.gd` is the source of truth for per-color terrain semantics. Exact RGB matches map a mask color to a behavior; unmatched opaque pixels fall back to the default land rule.
- Transparent mask pixels remain water by contract.
- Adding a new terrain semantic should start with a new `TerrainMaskRule` or profile adjustment. Only extend `terrain.gd` when a new semantic needs a genuinely new output behavior, not just different data.
- Generated helper `TileMapLayer` nodes must stay transient and unowned so terrain reloads do not serialize large caches back into `terrain/terrain.tscn`.
- Terrain generation stays presentation-focused. Do not move gameplay progression, save state, or UI logic into the terrain generator.

## Edge Cases

- Imported PNG colors are compared as quantized 8-bit RGB values so authored mask colors remain stable even after image load conversion.
- Any opaque pixel that does not match an explicit color rule still paints as land. If a new authored color should behave differently, add a rule instead of relying on a lucky fallback.
- Street painting still uses the plus-shaped terrain-connect footprint from the current implementation. If street topology changes, update both the profile and this doc.
- `@tool` reloads can still dirty transient helper nodes during editor validation. Treat new serialized helper-layer data as a regression.

## Architecture / Ownership

- [`../../terrain/terrain.tscn`](../../terrain/terrain.tscn) owns authored world content plus the generated helper-layer attachment points.
- [`../../terrain/terrain.gd`](../../terrain/terrain.gd) owns mask loading, generated-layer lifecycle, and the runtime player transparency hook.
- [`../../terrain/terrain_generation_profile.gd`](../../terrain/terrain_generation_profile.gd) owns the generated-terrain defaults and street-connect footprint.
- [`../../terrain/terrain_mask_rule.gd`](../../terrain/terrain_mask_rule.gd) owns per-color terrain semantics and per-rule tile overrides.
- [`../../resources/materials/water.tres`](../../resources/materials/water.tres) and [`../../resources/materials/water.gdshader`](../../resources/materials/water.gdshader) still own water appearance, not mask semantics.

## Relevant Files

- Scenes:
- [`../../terrain/terrain.tscn`](../../terrain/terrain.tscn)
- Scripts:
- [`../../terrain/terrain.gd`](../../terrain/terrain.gd)
- [`../../terrain/terrain_generation_profile.gd`](../../terrain/terrain_generation_profile.gd)
- [`../../terrain/terrain_mask_rule.gd`](../../terrain/terrain_mask_rule.gd)
- Assets:
- [`../../design/gulangyu_map_mini_export.png`](../../design/gulangyu_map_mini_export.png)
- Related docs:
- [`terrain_water_rendering.md`](terrain_water_rendering.md)
- [`../architecture.md`](../architecture.md)
- [`../module_map.md`](../module_map.md)

## Signals / Nodes / Data Flow

- Signals emitted:
- None dedicated to terrain generation.
- Signals consumed:
- `HumanBody2D.global_position_changed` for the terrain transparency rectangle update.
- Important node paths, dictionaries, resources, or data flow:
- `Terrain._paint_terrain_from_mask()` reads `mask_file`, asks `TerrainGenerationProfile` how to interpret each pixel, then writes to `base`, `streets`, `water`, and `building_mask`.
- `TerrainGenerationProfile.resolve_rule_for_pixel()` maps exact mask colors to `TerrainMaskRule` resources and falls back to `default_land_rule`.
- `TerrainMaskRule` can override the profile defaults for a specific semantic without forcing new branches into `Terrain.gd`.

## Contracts / Boundaries

- Transparent pixels mean water unless this doc and [`../module_map.md`](../module_map.md) are updated together.
- `terrain/terrain.gd` may orchestrate generation, but semantic meaning belongs in the profile and rule resources.
- Water visuals remain governed by [`terrain_water_rendering.md`](terrain_water_rendering.md). Do not mix shader-tuning decisions into terrain-semantic rules.
- If terrain generation stops being mask-driven or starts writing gameplay data, update this doc, [`../architecture.md`](../architecture.md), and [`../contracts.md`](../contracts.md).

## Validation

- Run [`../../terrain/terrain.tscn`](../../terrain/terrain.tscn) directly after terrain-generation changes and confirm `_reload_terrain: painted ...` appears without new parse errors.
- Use the `reload` inspector toggle on `Terrain` after changing the mask, a rule, or the generation profile.
- Visually verify land fill, street connectivity, building masking, and coastline water placement.
- For water-only tuning, use [`../../scenes/tests/test_water_render.tscn`](../../scenes/tests/test_water_render.tscn) before rechecking the full terrain scene.
- For full integration changes that affect landmark readability or masking, validate through [`../../scenes/game_main.tscn`](../../scenes/game_main.tscn).

## Out Of Scope

- Procedural island generation, biome simulation, erosion, or runtime terrain deformation.
- Moving landmark placement out of the authored terrain scene.
- Gameplay systems that depend on terrain state changing during play.
