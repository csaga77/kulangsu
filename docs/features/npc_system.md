# 3D Resident NPC System

## Summary

The production NPC system spawns the full resident roster as low-poly `HumanBody3D` actors in `game_world_3d`. It reuses the canonical resident catalog, story services, subject ids, progression, and save data without a 3D-only content fork.

## Main Components

- [`../../characters/resident_factory.gd`](../../characters/resident_factory.gd): assembles residents, subjects, speech balloons, and wander controllers.
- [`../../characters/control/resident_controller_3d.gd`](../../characters/control/resident_controller_3d.gd): local XZ wandering, stuck recovery, and talk pauses.
- [`../../characters/character_model_catalog_3d.gd`](../../characters/character_model_catalog_3d.gd): shared player/resident GLB selection.
- [`../../game/story_subject_3d.gd`](../../game/story_subject_3d.gd): stable `npc:<resident_id>` proximity subject.
- [`../../scenes/game_world_3d.gd`](../../scenes/game_world_3d.gd): anchor resolution, subject selection, and dispatch to shared services.

## Authoring

Author residents as external `ResidentDefinition` resources under [`../../game/residents/definitions/`](../../game/residents/definitions). Keep identity, dialogue, gates, effects, and routine semantics in those resources. `routine.spawn.anchor_id` must resolve in the 3D world. The 3D runtime currently uses local anchor-relative wandering rather than authored pixel routes.

Appearance fields retained from earlier content are compatibility data. Visible presentation comes from integrated low-poly GLBs selected by `CharacterModelCatalog3D`; adding a new visible category requires a model and an explicit mapping.

## Contracts

- Story subject ids and shared dispatch results are stable across presentation changes.
- Resident gameplay rules never move into actor or UI scripts.
- World-space movement uses 3D physics and XZ coordinates only.
- Dialogue bubbles are camera-facing `Label3D` nodes.
- The legacy layered 2D renderer, controllers, behavior tree, and route-collision exceptions are retired.

## Validation

Use `test_resident_catalog_external_defs.tscn`, `test_resident_interaction.tscn`, and `test_game_world_3d.tscn` for catalog, rule, and full-world coverage respectively.
