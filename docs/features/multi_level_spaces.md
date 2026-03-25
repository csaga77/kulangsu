# Multi-Level Spaces

## Goal

- Support stacked interiors and landmarks where the player can move between floors, tunnels, stairs, and portals.
- Keep reusable room scenes reusable by letting each level-aware node resolve its `level_id` relative to the closest level-aware parent when needed.
- Preserve the player-facing behavior that higher floors hide and reveal correctly as the player moves on and off them.

## Requirement Summary For New Agents

- Every level-aware node must define a `level_id` for its own level.
- A level-aware node may also define related ids such as `level_from`, `level_to`, `level_bottom`, or `level_top`.
- A node chooses whether all of those ids are absolute or relative to the closest level-aware parent.
- Reusable room scenes should prefer relative level ids so they do not hardcode global runtime ids.
- Portals and stairs must move actors between levels in both directions.
- Visibility changes must continue to match the player's active floor.

## Current Design

### 1. Level Id Resolution

- [`../../common/level_registry.gd`](../../common/level_registry.gd) is now the single source of truth for level behavior.
- It owns:
  - the relative-vs-absolute `level_id` resolution rules
  - the shared derivation rules for tile-atlas lookup, collision-mask lookup, `z_index` lookup, and applying actor state
- By default it derives:
  - `physics_atlas_column = level_id`
  - `z_index = level_id`
  - `collision_mask = 1 << (19 + level_id)`
- If a level id is invalid, callers fall back to their existing authored values.

### 2. Level-Aware Nodes

- [`../../common/level_node_2d.gd`](../../common/level_node_2d.gd)
  - owns a node's resolved room level for tile physics atlas selection
  - rewrites `coords.x` for its exported `physics_layers`
- [`../../architecture/components/portal.gd`](../../architecture/components/portal.gd)
  - owns `level_id`, `level_from`, and `level_to`
  - resolves actor collision-mask and `z_index` state through `LevelRegistry`
  - still falls back to hand-authored masks if no valid level data is available
- [`../../architecture/components/steps.gd`](../../architecture/components/steps.gd)
  - owns `level_id`, `level_bottom`, and `level_top`
  - derives stair portal masks and `delta_z` from `LevelRegistry`
  - still falls back to hand-authored masks if no valid level data is available

### 3. Global Static Level Data

- The derived level rules currently live in [`../../common/level_registry.gd`](../../common/level_registry.gd).
- The active shared floor ids used by Bagua are:
  - `0`: Bagua exterior base bridge
  - `2`: Bagua ground floor
  - `4`: Bagua upper floor
  - `6`: Bagua roof
- Other scenes may still use raw authored masks and atlas-column fallback when they do not need a shared derived level id yet.

### 4. Visibility

- [`../../common/auto_visibility_node_2d.gd`](../../common/auto_visibility_node_2d.gd) still owns visibility masking behavior.
- Visibility is still based on authored mask tilemaps plus absolute `z_index` relationships.
- The level system does not currently derive visibility masks automatically.

## Reference Implementation

- [`../../architecture/bagua_tower/bagua_tower.tscn`](../../architecture/bagua_tower/bagua_tower.tscn) is the best current reference.
- Bagua uses:
  - `ground_level`: absolute `level_id = 2`
  - `upper_level`: relative `level_id = +2`
  - `roof_level`: relative `level_id = +2`
  - corner rooms: relative `level_id = 0`
  - door portals: absolute `0 -> 2`
  - stairs: relative `0 -> 2`

## Known Limitation

- Visibility masking remains a separate authored concern.
- Direct spawn, teleport, or restore into non-base floors should still call `LevelRegistry.apply_level_to_actor(level_id, actor)` explicitly.
- If a new landmark needs non-formula level behavior, [`../../common/level_registry.gd`](../../common/level_registry.gd) must be updated.

## Ownership / Boundaries

- Shared level-id rules and static level data belong in [`../../common/level_registry.gd`](../../common/level_registry.gd).
- Room tile-level resolution belongs in [`../../common/level_node_2d.gd`](../../common/level_node_2d.gd).
- Actor mask / z transitions belong in reusable traversal components under [`../../architecture/components/`](../../architecture/components/).
- Visibility behavior belongs in [`../../common/auto_visibility_node_2d.gd`](../../common/auto_visibility_node_2d.gd) plus scene-authored mask tilemaps.
- Reusable room scenes should prefer relative level ids instead of hardcoded global runtime ids.

## Relevant Files

- [`../../common/level_registry.gd`](../../common/level_registry.gd)
- [`../../common/level_node_2d.gd`](../../common/level_node_2d.gd)
- [`../../architecture/components/portal.gd`](../../architecture/components/portal.gd)
- [`../../architecture/components/steps.gd`](../../architecture/components/steps.gd)
- [`../../architecture/bagua_tower/bagua_tower.tscn`](../../architecture/bagua_tower/bagua_tower.tscn)
- [`../../architecture/bagua_tower/tests/test_bagua_portal_levels.tscn`](../../architecture/bagua_tower/tests/test_bagua_portal_levels.tscn)
- [`../../architecture/bagua_tower/tests/test_bagua_stairs_visibility.tscn`](../../architecture/bagua_tower/tests/test_bagua_stairs_visibility.tscn)
- [`../../architecture/bagua_tower/tests/test_bagua_stairs_walk.tscn`](../../architecture/bagua_tower/tests/test_bagua_stairs_walk.tscn)
- [`../../scenes/test_level_resolution.tscn`](../../scenes/test_level_resolution.tscn)
- [`../../scenes/test_portal_overlap.tscn`](../../scenes/test_portal_overlap.tscn)

## Validation

- Validate relative-level resolution with [`../../scenes/test_level_resolution.tscn`](../../scenes/test_level_resolution.tscn).
- Validate concurrent portal usage with [`../../scenes/test_portal_overlap.tscn`](../../scenes/test_portal_overlap.tscn).
- Validate direct portal actor transitions with [`../../architecture/bagua_tower/tests/test_bagua_portal_levels.tscn`](../../architecture/bagua_tower/tests/test_bagua_portal_levels.tscn).
- Validate Bagua ascent, descent, and visibility behavior with [`../../architecture/bagua_tower/tests/test_bagua_stairs_visibility.tscn`](../../architecture/bagua_tower/tests/test_bagua_stairs_visibility.tscn).
- Validate physical stair traversal with [`../../architecture/bagua_tower/tests/test_bagua_stairs_walk.tscn`](../../architecture/bagua_tower/tests/test_bagua_stairs_walk.tscn).
