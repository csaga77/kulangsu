# Multi-Level Spaces

## Goal

- Support stacked interiors and landmarks where the player can move between floors, tunnels, stairs, and portals.
- Keep reusable room scenes reusable by mapping local floor slots to runtime levels from the parent landmark scene.
- Preserve the player-facing behavior that higher floors hide and reveal correctly as the player moves on and off them.

## User / Player Experience

- The player can walk into layered spaces such as Bagua Tower and move between floors through doors, portals, and stairs.
- Collision should follow the active floor so the player only walks on the current traversable layer.
- Upper-floor geometry should reveal when the player reaches that level and hide again when the player returns below it.
- NPC and interaction behavior should respect the player's active level so stacked spaces do not feel confusing or leaky.

## Requirement Summary For New Agents

- Reusable room scenes must not hardcode global runtime level ids.
- Parent landmark scenes own the mapping from local floor slots to runtime levels.
- Portals and stairs must move actors between levels in both directions, not only on ascent.
- Visibility changes must continue to match the player's active floor.
- New stacked spaces should follow the Bagua Tower pattern unless the design explicitly replaces it.

## Current Design

### 1. Room-Level Tile Mapping

- [`../../common/level_node_2d.gd`](../../common/level_node_2d.gd) owns the resolved room level used for tile-layer physics atlas selection.
- `LevelNode2D` supports three sources:
  - `EXPLICIT`: use the node's own exported `level`
  - `CONTEXT_SLOT`: resolve `level_slot` through a parent-owned `LevelContext2D`
  - `INHERIT_PARENT`: reuse the nearest parent `LevelNode2D` resolved level
- `LevelNode2D` applies the resolved level by rewriting `coords.x` for every cell in its exported `physics_layers`.

### 2. Parent-Owned Runtime Mapping

- [`../../common/level_context_2d.gd`](../../common/level_context_2d.gd) stores:
  - `runtime_levels`, a `PackedInt32Array` that maps local floor slots to stable `level_id` values
  - `level_profiles`, a parent-owned array of [`../../common/level_profile.gd`](../../common/level_profile.gd) resources keyed by `level_id`
- Parent landmark scenes such as [`../../architecture/bagua_tower/bagua_tower.tscn`](../../architecture/bagua_tower/bagua_tower.tscn) own this mapping.
- Reusable room scenes such as the Bagua corner rooms use `INHERIT_PARENT` so they do not bake in runtime ids.
- Current Bagua Tower mapping is local slots `0/1/2 -> runtime levels 2/4/6`.
- Bagua also defines a separate base-bridge profile with `level_id = 0` for the exterior-to-ground door portals. That profile is intentionally not part of the reusable room-slot mapping.

### 3. Shared Level Profiles And Actor Transitions

- [`../../common/level_spec.gd`](../../common/level_spec.gd) is now a lightweight `@tool` `Resource` that exposes only `level_id`. Use it as a durable reference to a logical level from reusable portals, stairs, and scene instances.
- [`../../common/level_profile.gd`](../../common/level_profile.gd) is the actual runtime floor profile keyed by `level_id`:
  - `physics_atlas_column`: tile physics atlas column used by `LevelNode2D`
  - `collision_mask`: actor collision mask for this floor
  - `z_index`: actor z layer / occlusion rank
- `LevelContext2D` is the lookup surface that maps `level_id -> LevelProfile`. `LevelNode2D`, `Portal`, and `Steps` all resolve through the nearest context instead of carrying duplicate values.
- `LevelContext2D.apply_level_to_actor(level_id, actor)` is the shared path for applying actor collision-mask and `z_index` state.
- [`../../architecture/components/steps.gd`](../../architecture/components/steps.gd) now accepts two exported `LevelSpec` resources:
  - `level_bottom`: source floor id reference
  - `level_top`: destination floor id reference
  - Derives `collision_mask` values and stair portal `delta_z` spacing from the parent-owned profiles
  - Falls back to hand-authored `layer1`, `layer2`, `collision_layer` values if specs are not provided or a level context is unavailable
- [`../../architecture/components/portal.gd`](../../architecture/components/portal.gd) now accepts two exported `LevelSpec` resources:
  - `level_from`: source level id reference
  - `level_to`: destination level id reference
  - Calls `LevelContext2D.apply_level_to_actor()` on exit when specs are provided
  - Falls back to hand-authored mask manipulation if specs are not provided or a level context is unavailable
- Portal transition state is tracked per body instance so overlapping actors do not overwrite each other.
- Portal side detection now tolerates centerline contact, which matters for descending stairs.

### 4. Visibility

- [`../../common/auto_visibility_node_2d.gd`](../../common/auto_visibility_node_2d.gd) hides or reveals nodes based on:
  - the player's current global position / ground rect
  - configured `visibility_mask_nodes`
  - the absolute `z_index` relationship between the player and masking layers
- Bagua Tower floors use hand-authored mask tilemaps plus `AutoVisibilityNode2D` to reveal the upper level only when the player is on that floor.

## Reference Implementation

- [`../../architecture/bagua_tower/bagua_tower.tscn`](../../architecture/bagua_tower/bagua_tower.tscn) is the best current reference for the intended pattern.
- Parent ownership:
  - `base/level_context` defines both the local-slot -> `level_id` mapping and the `level_id -> LevelProfile` mapping.
  - `base/ground_level`, `upper_level`, and `roof_level` resolve through context slots.
  - `base/portal_*` door bridges resolve through the same `LevelContext2D`, but use the separate base profile instead of a room slot.
- Reusable child content:
  - the Bagua corner room scenes inherit their resolved level from the parent floor node.
- Traversal:
  - stair instances own the floor-to-floor `LevelSpec` references.
  - direct portals and stair portals both resolve final actor state through the same `LevelProfile` data.

## Known Limitation

- Visibility masking remains a separate authored concern (see `AutoVisibilityNode2D`).
- `LevelProfile` does not encode visibility mask information; visibility still depends on hand-authored mask tilemaps and `z_index` comparison.
- Direct spawn, teleport, or restore into non-base floors should call `LevelContext2D.apply_level_to_actor(level_id, actor)` to ensure consistent actor state. This is not yet automated globally.
- Multi-stair spaces that need intermediate traversal-only states may still need additional authored mask logic beyond the current shared level-profile model.

## Implemented Direction

As of this version, the parent-owned `level_id -> LevelProfile` model has been implemented:

- `LevelSpec` is a level-id reference, not a duplicate floor data container.
- `LevelProfile` is the single shared source for per-level tile-atlas, collision-mask, and actor-`z_index` data inside the owning landmark scene.
- `LevelNode2D`, `Portal`, and `Steps` all resolve their runtime floor behavior through the nearest `LevelContext2D`.
- Backward compatibility is preserved: portals and stairs continue to work with hand-authored mask values if `LevelSpec` references are not provided.
- Bagua Tower has been migrated to use `LevelProfile` resources for its room floors plus a separate base bridge profile for the exterior door portals.

## Future Direction

- Consider a central registry for spawn, teleport, and restore flows so actor placement always applies the correct `level_id` automatically.
- Automatically derive visibility mask setup from `LevelProfile` data and authored floor metadata.
- Consider making level-aware spawning part of the main game flow.

## Ownership / Boundaries

- Room tile-level resolution belongs in [`../../common/level_node_2d.gd`](../../common/level_node_2d.gd) and [`../../common/level_context_2d.gd`](../../common/level_context_2d.gd).
- Actor mask / z transitions belong in reusable traversal components under [`../../architecture/components/`](../../architecture/components/).
- Visibility behavior belongs in [`../../common/auto_visibility_node_2d.gd`](../../common/auto_visibility_node_2d.gd) plus scene-authored mask tilemaps.
- Parent landmarks own local-slot mapping, level profiles, and should place stairs / portals where they know the `from` and `to` floors.
- Reusable room scenes should not own global runtime level ids.

## Relevant Files

- Scenes:
  - [`../../architecture/bagua_tower/bagua_tower.tscn`](../../architecture/bagua_tower/bagua_tower.tscn)
  - [`../../architecture/bagua_tower/bagua_tower_corner_room_north.tscn`](../../architecture/bagua_tower/bagua_tower_corner_room_north.tscn)
  - [`../../architecture/components/stairs_se_to_ne_4_0.tscn`](../../architecture/components/stairs_se_to_ne_4_0.tscn)
- Scripts:
  - [`../../common/level_profile.gd`](../../common/level_profile.gd)
  - [`../../common/level_spec.gd`](../../common/level_spec.gd)
  - [`../../common/level_node_2d.gd`](../../common/level_node_2d.gd)
  - [`../../common/level_context_2d.gd`](../../common/level_context_2d.gd)
  - [`../../common/auto_visibility_node_2d.gd`](../../common/auto_visibility_node_2d.gd)
  - [`../../architecture/components/steps.gd`](../../architecture/components/steps.gd)
  - [`../../architecture/components/portal.gd`](../../architecture/components/portal.gd)
- Level resources (Bagua Tower):
  - `LevelSpec_ground`, `LevelSpec_upper`, and `LevelSpec_roof` are inline level-id references
  - `LevelProfile_ground`, `LevelProfile_upper`, and `LevelProfile_roof` are inline runtime floor profiles
- Validation scenes:
  - [`../../scenes/test_level_context.tscn`](../../scenes/test_level_context.tscn)
  - [`../../scenes/test_portal_overlap.tscn`](../../scenes/test_portal_overlap.tscn)
  - [`../../scenes/test_bagua_portal_levels.tscn`](../../scenes/test_bagua_portal_levels.tscn)
  - [`../../scenes/test_bagua_stairs_visibility.tscn`](../../scenes/test_bagua_stairs_visibility.tscn)

## Validation

- Validate local-slot resolution with [`../../scenes/test_level_context.tscn`](../../scenes/test_level_context.tscn).
- Validate concurrent portal usage with [`../../scenes/test_portal_overlap.tscn`](../../scenes/test_portal_overlap.tscn).
- Validate direct portal level-id actor transitions with [`../../scenes/test_bagua_portal_levels.tscn`](../../scenes/test_bagua_portal_levels.tscn).
- Validate real Bagua ascent + descent + visibility behavior with [`../../scenes/test_bagua_stairs_visibility.tscn`](../../scenes/test_bagua_stairs_visibility.tscn).
- When editing stacked spaces, verify both directions of traversal. Do not assume a passing ascent implies descent is correct.

## Out Of Scope

- Replacing the current visibility system.
- Redesigning Bagua Tower content layout.
- Automatically deriving every visibility rule from `LevelContext2D` in the current patch.
