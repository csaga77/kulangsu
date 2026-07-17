# Landmark Definitions

## Goal

Give every canonical landmark one typed, inspectable source for static identity and world-integration metadata. This prevents `AppState`, the production world, StoryEffect validation, and audio tests from drifting through duplicated landmark lists and dictionaries.

## User / Player Experience

This is an architecture feature rather than a new player-facing mechanic. Existing landmark names, placement, resume behavior, audio motifs, and initial progression remain unchanged.

## Rules

- `LandmarkCatalog` defines the canonical landmark order.
- Every entry is a `LandmarkDefinition` resource with a stable id, display name, audio cue, and a `default` progress profile.
- A landmark included in world navigation must also define a production proxy `NodePath` and authored isometric position.
- Exactly one definition is the default resume anchor.
- Named progress profiles currently include `default`, `new_game`, `continue`, and `free_walk`; missing requested profiles fall back to `default`.
- Built progress dictionaries are deep copies. Canonical runtime mutations belong only to the snapshot committed by `AppStateService`; consumers use detached projections.
- Story actions, visibility conditions, and reward logic do not belong in `LandmarkDefinition`; they remain in StoryEvents and `StorySubject3D` nodes.

## Edge Cases

- `festival_stage` participates in progress and audio validation but is not a world-navigation proxy.
- Unknown audio cue ids resolve to `null` and fail StoryEffect schema validation.
- Invalid or duplicate definitions are reported by `LandmarkCatalog.validate()` and covered by the catalog contract test.
- Semantic resume values remain display names for save compatibility; the catalog resolves the default name from the stable landmark id.

## Architecture / Ownership

- `game/landmarks/landmark_definition.gd` and `landmark_progress_profile.gd` own the resource schemas.
- `game/landmarks/definitions/` owns the authored `.tres` records.
- `game/landmarks/landmark_catalog.gd` owns ordering, lookup, derived lists, progress construction, cue lookup, and validation.
- `AppState` owns mutable progress and save state.
- `game_world_3d.tscn` owns the actual proxy nodes and interaction hotspots; `game_world_3d.gd` consumes catalog paths and coordinates.

## Relevant Files

- Scenes: `scenes/game_world_3d.tscn`
- Scripts: `game/landmarks/`, `scenes/game_world_3d.gd`, `game/app_state.gd`, `game/story_effect_schema.gd`
- Tests: `game/tests/landmarks/test_landmark_catalog.tscn`, `scenes/tests/test_landmark_cue_loading.tscn`, `scenes/tests/test_game_world_3d.tscn`
- Related docs: `docs/architecture.md`, `docs/module_map.md`, `docs/contracts.md`

## Signals / Nodes / Data Flow

`LandmarkDefinition .tres -> LandmarkCatalog -> AppState initial snapshots / StoryEffect id validation / game_world_3d placement and cue playback`

The catalog emits no signals and owns no mutable gameplay state.

## Contracts / Boundaries

New landmark work updates the typed resource and catalog first. Consumers derive their lists from the catalog and must not introduce parallel landmark-id, placement, audio-path, or initial-progress tables.

## Validation

- Run `game/tests/landmarks/test_landmark_catalog.tscn`.
- Run `scenes/tests/test_landmark_cue_loading.tscn`.
- Run `game/tests/story_routes/test_story_event_service.tscn` for StoryEffect and landmark-flow coverage.
- Run `scenes/tests/test_game_world_3d.tscn` when proxy paths, coordinates, or world inclusion change.

## Out Of Scope

- Moving StoryEvent conditions/effects into landmark definitions.
- Replacing semantic display-name resume values in existing saves with stable ids.
- Generalizing the catalog into an addon or cross-project asset database.
