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

- [`../../common/level_context_2d.gd`](../../common/level_context_2d.gd) stores `runtime_levels`, a `PackedInt32Array` that maps local slots to runtime level ids.
- Parent landmark scenes such as [`../../architecture/bagua_tower/bagua_tower.tscn`](../../architecture/bagua_tower/bagua_tower.tscn) own this mapping.
- Reusable room scenes such as the Bagua corner rooms use `INHERIT_PARENT` so they do not bake in runtime ids.
- Current Bagua Tower mapping is local slots `0/1/2 -> runtime levels 2/4/6`.

### 3. Actor Level Transitions

- [`../../architecture/components/steps.gd`](../../architecture/components/steps.gd) wires a stair scene from three hand-authored masks:
  - `layer1`: source floor
  - `collision_layer`: middle stair-only traversal layer
  - `layer2`: destination floor
- [`../../architecture/components/portal.gd`](../../architecture/components/portal.gd) changes an actor's `collision_mask` and `z_index` as the body crosses the portal's local x-axis.
- Portal transition state is tracked per body instance so overlapping actors do not overwrite each other.
- Portal side detection now tolerates centerline contact, which matters for descending Bagua stairs.

### 4. Visibility

- [`../../common/auto_visibility_node_2d.gd`](../../common/auto_visibility_node_2d.gd) hides or reveals nodes based on:
  - the player's current global position / ground rect
  - configured `visibility_mask_nodes`
  - the absolute `z_index` relationship between the player and masking layers
- Bagua Tower floors use hand-authored mask tilemaps plus `AutoVisibilityNode2D` to reveal the upper level only when the player is on that floor.

## Reference Implementation

- [`../../architecture/bagua_tower/bagua_tower.tscn`](../../architecture/bagua_tower/bagua_tower.tscn) is the best current reference for the intended pattern.
- Parent ownership:
  - `base/level_context` defines the local-slot -> runtime-level mapping.
  - `base/ground_level`, `upper_level`, and `roof_level` resolve through context slots.
- Reusable child content:
  - the Bagua corner room scenes inherit their resolved level from the parent floor node.
- Traversal:
  - stair instances own the floor-to-floor mask transitions.
  - portal nodes inside each stair scene switch actor collision masks and `z_index`.

## Known Limitation

- The project does not yet have one runtime source of truth for level state.
- `LevelContext2D` and `LevelNode2D` currently solve only the room tile-physics level mapping problem.
- Actor collision masks, stair transition masks, portal `delta_z`, and visibility mask tilemaps are still authored separately in scenes.
- This means new floors can still desynchronize if a scene author updates only one of:
  - the room's resolved level / physics atlas column
  - the actor collision masks used by portals or stairs
  - the `z_index` assumptions used by visibility masking
- Direct spawn, teleport, or restore into non-base floors still requires explicit actor mask / z setup outside the room-level mapping system.

## Recommended Direction

- Introduce a shared runtime level profile, for example `LevelSpec`, that defines:
  - logical level id
  - tile physics atlas column
  - actor collision mask
  - actor z layer or occlusion rank
  - optional transition-only mask
- Add one actor-facing API that applies a level profile consistently on spawn, teleport, restore, and portal traversal.
- Convert portals and stairs to transition between level profiles or level slots, not raw bitmasks.
- Keep the current parent-owned `LevelContext2D` pattern for reusable rooms even if the actor-level system is upgraded later.

## Ownership / Boundaries

- Room tile-level resolution belongs in [`../../common/level_node_2d.gd`](../../common/level_node_2d.gd) and [`../../common/level_context_2d.gd`](../../common/level_context_2d.gd).
- Actor mask / z transitions belong in reusable traversal components under [`../../architecture/components/`](../../architecture/components/).
- Visibility behavior belongs in [`../../common/auto_visibility_node_2d.gd`](../../common/auto_visibility_node_2d.gd) plus scene-authored mask tilemaps.
- Parent landmarks own local-slot mapping and should place stairs / portals where they know the `from` and `to` floors.
- Reusable room scenes should not own global runtime level ids.

## Relevant Files

- Scenes:
  - [`../../architecture/bagua_tower/bagua_tower.tscn`](../../architecture/bagua_tower/bagua_tower.tscn)
  - [`../../architecture/bagua_tower/bagua_tower_corner_room_north.tscn`](../../architecture/bagua_tower/bagua_tower_corner_room_north.tscn)
  - [`../../architecture/components/stairs_se_to_ne_4_0.tscn`](../../architecture/components/stairs_se_to_ne_4_0.tscn)
- Scripts:
  - [`../../common/level_node_2d.gd`](../../common/level_node_2d.gd)
  - [`../../common/level_context_2d.gd`](../../common/level_context_2d.gd)
  - [`../../common/auto_visibility_node_2d.gd`](../../common/auto_visibility_node_2d.gd)
  - [`../../architecture/components/steps.gd`](../../architecture/components/steps.gd)
  - [`../../architecture/components/portal.gd`](../../architecture/components/portal.gd)
- Validation scenes:
  - [`../../scenes/test_level_context.tscn`](../../scenes/test_level_context.tscn)
  - [`../../scenes/test_portal_overlap.tscn`](../../scenes/test_portal_overlap.tscn)
  - [`../../scenes/test_bagua_stairs_visibility.tscn`](../../scenes/test_bagua_stairs_visibility.tscn)

## Validation

- Validate local-slot resolution with [`../../scenes/test_level_context.tscn`](../../scenes/test_level_context.tscn).
- Validate concurrent portal usage with [`../../scenes/test_portal_overlap.tscn`](../../scenes/test_portal_overlap.tscn).
- Validate real Bagua ascent + descent + visibility behavior with [`../../scenes/test_bagua_stairs_visibility.tscn`](../../scenes/test_bagua_stairs_visibility.tscn).
- When editing stacked spaces, verify both directions of traversal. Do not assume a passing ascent implies descent is correct.

## Out Of Scope

- Replacing the current visibility system.
- Redesigning Bagua Tower content layout.
- Automatically deriving every collision mask and visibility rule from `LevelContext2D` in the current patch.
