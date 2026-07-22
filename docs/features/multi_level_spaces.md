# Multi-Level Spaces

## Goal

Define how stacked rooms, stairs, and tunnel interiors should work in the production 3D world without reviving the retired z-index/TileMap level simulation.

## Current Status

- The 2D `LevelNode2D`, `LevelArea2D`, `LevelRegistry`, portal, stair, visibility-mask, room, and tunnel-interior stack was removed after the 3D runtime cutover.
- `HumanBody3D` already supports gravity, native wall and stair-slope movement, and capped dynamic-body pushing.
- The production Bagua building is 3D geometry, but its story subject currently uses the world scene's shared proximity interaction layer rather than authored interior floors.
- Bi Shan and Long Shan remain traversable marker anchors. Walkable tunnel interiors, interior resident routing, and tunnel-specific visibility are accepted post-cutover gaps.
- All current landmark and inspectable hotspots are `StorySubject3D` nodes authored in [`../../scenes/game_world_3d.tscn`](../../scenes/game_world_3d.tscn).

## 3D Contract For Future Work

- Use real `Node3D` transforms, collision, stairs, doors, and portals. Do not encode floors through canvas `z_index`, tile-atlas columns, or collision-bit formulas inherited from the removed renderer.
- A portal must define explicit 3D source/destination transforms and preserve actor orientation/state intentionally.
- Story hotspots remain stable `subject_id` adapters through `StorySubject3D`; spatial placement changes must not fork story rules.
- Tunnel interiors should own their geometry, collision, entry/exit transforms, resident anchors, and camera/occlusion context.
- Save/resume anchors remain semantic landmark ids resolved by `game_world_3d`, not raw interior coordinates.
- Add focused 3D validation before making any new traversal component production-critical.

## Reference Files

- [`../../characters/human_body_3d.gd`](../../characters/human_body_3d.gd)
- [`../../characters/control/base_controller_3d.gd`](../../characters/control/base_controller_3d.gd)
- [`../../characters/control/player_controller_3d.gd`](../../characters/control/player_controller_3d.gd)
- [`../../scenes/game_world_3d.tscn`](../../scenes/game_world_3d.tscn)
- [`../../scenes/game_world_3d.gd`](../../scenes/game_world_3d.gd)
- [`../../game/story_subject_3d.gd`](../../game/story_subject_3d.gd)
- [`../../scenes/tests/test_environment_3d.tscn`](../../scenes/tests/test_environment_3d.tscn)
- [`../../characters/tests/test_character_collisions.tscn`](../../characters/tests/test_character_collisions.tscn)

## Validation

- Use [`../../characters/tests/test_character_collisions.tscn`](../../characters/tests/test_character_collisions.tscn) for wall, gravity, stair, and pushing behavior.
- Use [`../../scenes/tests/test_environment_3d.tscn`](../../scenes/tests/test_environment_3d.tscn) for character interactions with an authored building, terrain, camera, and collision together.
- Use [`../../scenes/tests/test_game_world_3d.tscn`](../../scenes/tests/test_game_world_3d.tscn) for production landmark subjects and resume anchors.

## Out Of Scope Until Authored

- Walkable Bi Shan and Long Shan interiors.
- A reusable 3D portal/room-level framework.
- Tunnel-resident route masking and interior camera rules.
