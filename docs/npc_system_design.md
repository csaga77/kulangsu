# Resident System Design

Kulangsu's production resident system is fully 3D. Shared resident definitions, dialogue, progression, save data, and story subject ids remain dimension-neutral; only presentation, movement, proximity, and world anchoring belong to the 3D world.

## Runtime Flow

1. [`../game/resident_catalog.gd`](../game/resident_catalog.gd) loads external [`../game/residents/definitions/`](../game/residents/definitions) resources.
2. [`../scenes/game_world_3d.gd`](../scenes/game_world_3d.gd) assigns landmark anchors and asks [`../characters/resident_presenter_3d.gd`](../characters/resident_presenter_3d.gd) to spawn residents.
3. The presenter creates a `HumanBody3D`, selects its integrated GLB through [`../characters/character_model_catalog_3d.gd`](../characters/character_model_catalog_3d.gd), attaches `ResidentController3D`, and registers an `npc:<resident_id>` `StorySubject3D`.
4. `PlayerController3D` reports inspection intent; `game_world_3d` resolves the closest subject and dispatches the stable id through `AppState.activate_story_subject(...)`.
5. Shared story/resident services apply dialogue, trust, route effects, and save state. The presenter only shows the resulting line in a camera-facing `SpeechBalloon3D` and pauses/faces the resident locally.

## Ownership

- `ResidentDefinition` and its nested resources own authored identity, dialogue, routine metadata, and compatibility appearance data.
- `AppState` and composed services own shared rules, progression, trust, persistence, and resident overrides.
- `game_world_3d` owns spatial anchors, closest-subject selection, and world-to-story dispatch.
- `ResidentPresenter3D` owns runtime assembly and presentation.
- `ResidentController3D` owns lightweight local wandering. The retired JSON behavior tree and 2D pixel-route controller are not part of the runtime contract.
- `CharacterModelCatalog3D` owns the current broad model mapping: adult masculine/default to `male.glb`, adult feminine/pregnant to `female.glb`, and teen/child to `boy.glb`.

## Compatibility

Existing appearance and profile keys remain loadable and serializable so old saves and authored resident resources remain valid. The 3D renderer does not interpret layered skin, hair, or costume paths. New presentation categories must be mapped explicitly in `CharacterModelCatalog3D` or supplied as integrated GLB assets.

## Validation

- [`../game/tests/npc_system/test_resident_catalog_external_defs.tscn`](../game/tests/npc_system/test_resident_catalog_external_defs.tscn) validates external resident resources and roster completeness.
- [`../game/tests/npc_system/test_resident_interaction.tscn`](../game/tests/npc_system/test_resident_interaction.tscn) validates dimension-neutral gating, trust, effects, autosave, and continue behavior.
- [`../scenes/tests/test_game_world_3d.tscn`](../scenes/tests/test_game_world_3d.tscn) validates full 3D resident spawning, subjects, interaction dispatch, and world integration.

The removed 2D layer-targeting, pixel-route collision, LPC composition, and 2D actor smoke tests are intentionally not compatibility requirements.
