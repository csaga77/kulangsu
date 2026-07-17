# Player 3D Appearance System

## Current Behavior

Player appearance is model-based. [`../characters/character_model_catalog_3d.gd`](../characters/character_model_catalog_3d.gd) maps the saved profile's body type and presentation to one integrated low-poly GLB:

- teen or child body types use `boy.glb`
- feminine presentation uses `female.glb`
- other adult/default profiles use `male.glb`

[`../scenes/game_world_3d.gd`](../scenes/game_world_3d.gd), the traveler setup overlay, and the journal wardrobe all use this same catalog. UI previews render `HumanBody3D` inside a transparent `SubViewport` through [`../characters/character_preview_3d.gd`](../characters/character_preview_3d.gd).

## Save Compatibility

Existing profile, skin, hair, color, and costume keys remain accepted and serialized so prior saves continue loading. Unsupported per-part controls are hidden because the 3D models carry their mesh, skin, hair, clothing, skeleton, and animation as one asset. Retaining a key does not mean the renderer applies it.

## Ownership

- `AppState` is the single runtime owner of the player profile plus unlocked/equipped costume ids; `PlayerProfile` defines the profile value type and `PlayerProfileService` provides stateless normalization, catalog lookup, and selection transforms.
- `CharacterModelCatalog3D` owns model selection policy.
- `HumanBody3D` owns model instancing, grounding, scale, facing, and locomotion animation.
- Customization and journal UI collect/display supported choices; they do not implement rendering rules.

## Extending Appearance

Add a validated integrated GLB under `assets/characters/`, then extend `CharacterModelCatalog3D` with an explicit stable mapping. If runtime mix-and-match customization is required later, design a new 3D attachment/skin contract rather than reviving the removed 2D layered sprite pipeline.

## Validation

- `ui/screens/tests/test_player_customization_overlay.tscn` validates the 3D preview, hidden unsupported controls, and model mapping.
- `game/tests/state/test_app_state_ownership.tscn` validates canonical profile/costume ownership, detached profile reads, and one signal per committed change.
- `characters/tests/test_human_body_3d.tscn` validates model structure and locomotion clips.
- `scenes/tests/test_game_world_3d.tscn` validates the production player model and world integration.
