# Kulangsu Implementation Plan

This is the canonical implementation plan for the current playable game.

Read `AGENTS.md`, [`../design_brief.md`](../design_brief.md), [`../architecture.md`](../architecture.md), and [`../core_game_workflow.md`](../core_game_workflow.md) before starting a new task.

## Current State

The seasonal multi-route story architecture is now live.

Shipped foundations:

- `season_phase`-driven progression instead of `chapter` as the primary gate
- four canonical routes: family, study, preservation, melody
- one pinned HUD lead plus multi-route journal view
- route graph and endgame trigger logic in `game/story_route_graph.gd`
- save/load support for seasonal story state, route state, lead pinning, and endgame state
- resident gating against `season_phase`, route state, and `story_flags`
- guarded final-act start with `spring_festival_resolved` as the earliest allowed endgame threshold
- `AppState` composition pattern with extracted helpers for profile, journal, save, landmark progression, and story routes
- weather system with manager-owned overworld preset cycling, wind sync, and runtime rig instancing
- BGM weighted selection with 12-track catalog, commitment window, silence gaps, and landmark cue ducking
- landmark audio cues for all five canonical landmarks plus the festival stage

Regression coverage now includes:

- full landmark cue progression
- story autosave and continue
- seasonal route progression outside the landmark spine
- BGM lazy catalog validation and location-fallback variety
- portal/level transitions across Bagua Tower, tunnels, and multi-level spaces

## Content Reality Check

The architecture and state model are ahead of the authored content depth.

Current practical coverage:

- `family_memory` has a workable spine, but the A Po and parent threads are still under-authored
- `study_future` functions, but is still too compressed to feel like a full year-long line
- `preservation_inheritance` has one strong foothold and still needs route depth
- `melody_landmarks` remains the richest embodied route
- `spring_festival_resolved` works as a gate, but still needs a stronger sequence-level treatment

## Architecture Reality Check

`AppState` (2,084 lines, ~130 functions, 30 signals) is the shared state hub. The composition pattern is working: helpers own implementation while `AppState` owns the signal surface and public API. But several extraction boundaries are incomplete, and `resident_catalog.gd` (1,630 lines) is the next monolith that will grow fastest as route content deepens.

Current pressure points:

- landmark progression extraction is inconsistent: some collection logic delegates, some stays local in `AppState`
- resident dialogue engine (~350 lines of interaction, conditional beat, and gate logic) is the heaviest local block in `AppState`
- audio/volume settings (~100 lines) have zero overlap with game progression but live in `AppState`
- save/load payload construction and normalization (~300 lines) partially overlaps `story_save_service.gd`
- player profile facade is 20+ one-liner forwarding functions (~90 lines)
- all resident definitions, dialogue spines, and conditional beats live in `resident_catalog.gd` with no per-resident split
- high-traffic dictionary payloads (landmark progress, melody progress, autosave) are untyped

## What Remains

The next phase has two parallel tracks: content authoring (Workstreams 1-4) and architecture cleanup (Workstream 0) that should run before or alongside content work to keep the codebase maintainable as content grows.

## Workstream 0: AppState Decomposition And Architecture Cleanup

Goal:

- reduce `AppState` from ~2,084 lines to ~900-1,000 lines by completing and extending the existing composition pattern
- clean up incomplete extraction boundaries before content authoring makes them harder to move
- prepare `resident_catalog.gd` for growth

Recommended task order (safest to most coupled):

### 0A: Finish Landmark Progression Extraction

Complete the extraction that was started in `game/landmark_progression.gd`. Currently `_collect_trinity_church_cue()`, `_collect_bi_shan_echo()`, `_collect_long_shan_checkpoint()`, `_collect_piano_ferry_harbor_clue()`, and related collection logic still live directly in `AppState`. Move these into `landmark_progression.gd`. `AppState` keeps the state storage (`landmark_progress` dict), the get/set/advance API, thin landmark bridge methods such as `activate_landmark_trigger(...)`, `complete_prompt_request(...)`, and the existing prompt-request/resolution facades, plus signal emission so runtime callers and tests keep the current public contract.

Functions to move: `_collect_piano_ferry_harbor_clue`, `_collect_trinity_church_cue`, `_collect_bi_shan_echo`, `_collect_long_shan_checkpoint`, and the remaining one-liner landmark facades.

Scope boundary: keep `_default_landmark_progress`, `_build_landmark_progress`, `_build_story_melody_progress`, `_normalize_melody_progress`, and `_sync_fragment_summary_from_melodies` in `AppState` (or in a pure state-builder helper). These are used by `StorySaveService` during payload normalization; moving them into `LandmarkProgression` would make the save service transitively depend on a behavioral helper and muddy the extraction direction. `LandmarkProgression` should own only interaction/progression behavior, not initialization or save normalization.

Lines saved: ~150.

Primary files:

- `game/app_state.gd`
- `game/landmark_progression.gd`

Validation: existing `test_cue_progression` scene must still pass unchanged.

### 0B: Extract Resident Interaction Service

Extract the dialogue engine into a new `game/resident_interaction_service.gd` following the same `RefCounted` helper pattern as `landmark_progression.gd`. The service takes an `AppState` reference in its constructor and calls back through public methods and bridge emitters.

Framing: this is a stateful `AppState` helper, not a clean independent service. Resident interaction applies objectives, hints, landmark rewards, story events, lead pinning, autosave, costume refresh, summary counts, trust milestones, and route refresh. Those coupling points are fine for a composed helper, but do not pretend the extracted unit can stand alone — the goal is line reduction and surface isolation inside `AppState`, not a reusable module.

Functions to move: `interact_with_resident`, `_pick_conditional_beat`, `_check_conditional_conditions`, `_check_beat_gate`, `_apply_resident_beat`, `_seed_resident_progress`, `_count_helped_residents`, `_sync_known_residents`, `_emit_trust_milestone_if_max`, `get_resident_ambient_line`, `get_known_resident_names`.

`AppState` keeps thin facade methods so the public API does not change for callers.

Lines saved: ~350.

Primary files:

- `game/app_state.gd`
- `game/resident_interaction_service.gd` (new)

Validation: existing `test_npc_control`, `test_scene` (resident speech sandbox), `test_cue_progression`, `test_story_routes`, and `test_story_autosave` scenes must still pass. Add a focused resident-interaction regression scene covering conditional beats, gate fallbacks, trust milestones, and one route/autosave-affecting beat path.

### 0C: Extract Audio Settings Service

Extract volume/speed settings into a new `game/audio_settings_service.gd`. This cluster (`master_volume_percent`, `music_volume_percent`, `prompt_volume_percent`, `dialogue_text_speed_percent`, bus-scaling math, `_apply_runtime_settings`) has no game-progression dependency, but the extraction must preserve the `AppState` API and signals consumed by the settings overlay, prompt audio, landmark cues, and BGM bus volume.

Lines saved: ~100.

Primary files:

- `game/app_state.gd`
- `game/audio_settings_service.gd` (new)

Validation:

- settings overlay slider signal flow still drives `AppState` setters
- bus volume changes apply to Master, Music, and Prompt buses
- prompt cue volume still scales with `prompt_volume_percent`
- BGM ducking restores the correct post-duck volume when a landmark cue ends
- dialogue text speed still updates in the speech balloon after slider change

### 0D: Remove Stale AppState Save Duplicates And Move Configure Flows

`StorySaveService` already owns the active payload pipeline. The remaining cleanup is two-part:

1. Delete the stale private payload duplicates still living in `AppState` (`_build_story_autosave_payload`, `_read_story_autosave_payload`, `_normalize_story_autosave_payload`, `_apply_story_autosave_payload`, `_normalize_saved_*` helpers, `_build_story_save_metadata_from_payload`) after confirming no caller bypasses the service.
2. Move `configure_new_game()`, `configure_continue()`, and `configure_free_walk()` into `StorySaveService`. All three share the same setup/defaulting path and belong with the payload code they invoke. `AppState` should keep thin `configure_*` facades that delegate to the helper so the shell, contracts, and tests continue to call the same public API.

Framing: `StorySaveService` is already a stateful `AppState` helper, not a clean boundary. It reads private owner state (`_manual_pinned_lead_id`) and calls private defaults (`_default_resident_profiles`, `_default_landmark_progress`, `_update_summary_counts`). Moving `configure_*` in will deepen that coupling. Either add explicit owner-bridge methods for the private surface the service touches, or accept the service as a tightly coupled `AppState` helper and document it as such. Do not claim a public-setter-only boundary.

Lines saved: ~300.

Primary files:

- `game/app_state.gd`
- `game/story_save_service.gd`

Validation: `test_story_autosave` and `test_story_routes` scenes must still pass. New Game, Continue, and Free Walk flows must still work end-to-end through the existing `AppState.configure_*` entry points.

### 0E: Extract Weather Tuning To Resource

Move the four inline weather constant dictionaries (`MAIN_RAIN_PROPERTIES`, `MAIN_FOG_PROPERTIES`, `MAIN_CLOUD_PROPERTIES`, `MAIN_IMPACT_PROPERTIES`) from `scenes/game_main.gd` into a `WeatherPresetResource` or `.tres` file. Pure data, no behavioral change.

Primary files:

- `scenes/game_main.gd`
- `weather/overworld_weather_preset.gd` (new resource script)
- `weather/overworld_weather_preset.tres` (new resource instance)

Validation: both `scenes/game_main.gd` and `weather/tests/test_weather.gd` must consume the new resource (no duplicated inline constants left in the sandbox). Add a value parity check or focused smoke assertion confirming the loaded preset matches the prior inline values so the sandbox cannot drift.

### 0F: Begin Resident Catalog Split (Prerequisite For Workstream 1)

The `ResidentCatalog` contract already supports external `.tres` definitions from `game/residents/definitions/` that override built-in entries. A template exists at `game/residents/templates/template_resident_definition.tres`. Start migrating one or two residents to standalone `.tres` files to validate the workflow before Workstream 1 adds significant content.

Primary files:

- `game/resident_catalog.gd`
- `game/residents/definitions/` (new `.tres` files)

Validation: the existing resident speech sandbox mostly reloads a building scene and does not assert catalog/resource override behavior. Add a focused regression that loads an external `.tres`, verifies it overrides the built-in entry, and compares runtime profile fields (dialogue beats, conditional beats, spawn, movement, appearance) against the built-in baseline.

## Workstream 1: Route Content Depth

Goal:

- deepen the authored beats inside the new route structure

Depends on: 0B (resident interaction extraction) and 0F (resident catalog split) are strongly recommended before heavy content authoring to keep diffs manageable.

Tasks:

- add more resident beats to `family_memory`, especially around A Po, the parents, and church-linked memory
- add more study/future beats so the route feels like a year-long pressure line instead of a few turning points
- add more preservation beats outside Bagua Tower so architecture becomes visible across the island
- author Spring Festival as a clearer multi-step sequence instead of a thin resolution gate
- add more optional landmark-route enrichment that affects ending tone without becoming mandatory

Priority order inside this workstream:

1. `family_memory`: make care, absence, and family sacrifice more visible in play
2. `study_future`: spread pressure and future-choice uncertainty across the year
3. `preservation_inheritance`: create a short district-spanning route chain
4. `spring_festival_resolved`: build a stronger emotional culmination scene
5. `melody_landmarks`: keep adding enrichment without re-centering the whole game around it

Primary files:

- `game/resident_catalog.gd` (and per-resident `.tres` definitions once 0F is underway)
- `game/resident_interaction_service.gd` (once 0B ships)
- `docs/story/summer_of_piano_island_story_framework.md`
- `docs/core_game_workflow.md`

## Workstream 2: World-State Reactivity

Goal:

- make route progress change what the island feels like, not just what the journal says

Depends on: 0B (resident interaction extraction) and 0F (resident catalog split). Workstream 2 expands the same resident conditional beat surface that 0B isolates and 0F starts migrating into `.tres` resources. Running it before those tasks creates avoidable merge and retest churn.

Tasks:

- expand resident conditional beats that respond to `story_flags`
- add more authored dialogue reactions between harbor, church, tower, and tunnel residents
- let more inspectables or ambient cues react to family, preservation, or melody progress
- surface route-state changes in more districts once major anchors resolve

Primary files:

- `game/resident_catalog.gd`
- `scenes/game_main.gd`
- `game/app_state.gd`

## Workstream 3: Final-Act And Ending Polish

Goal:

- make the final act feel like a short authored closing movement rather than only an overlay state

Depends on: 0D. Ending polish touches endgame behavior and summary text, and endgame state is persisted and restored through the save payload. Doing ending work in parallel with the save-service cleanup risks save/load regressions — sequence this after 0D or coordinate tightly.

Tasks:

- author a clearer closing sequence per trigger path
- differentiate exam, harbor-performance, and future-turning-point endings more sharply
- deepen stay-versus-leave text and summary language
- add more ending-tone tags or summary wording driven by resident trust and route mix

Primary files:

- `main.gd`
- `ui/screens/ending_overlay.gd`
- `ui/screens/departure_overlay.gd`
- `game/story_route_graph.gd`

## Workstream 4: Journal And HUD Polish

Goal:

- make the new route architecture easier to read moment to moment

Tasks:

- improve wording for pinned leads and route summaries
- make manual lead pinning more explicit in the journal
- refine how current task versus pinned lead is presented on the HUD
- decide whether to expose route sections or route icons in the journal later

Primary files:

- `ui/screens/game_hud.gd`
- `ui/screens/journal_overlay.gd`
- `game/journal_builder.gd`

## Workstream 5: Content Tooling And Test Growth

Goal:

- keep the new architecture maintainable as content expands

Tasks:

- add more regression tests for route-specific resident beats and conditional reactivity
- add validation around arbitrary `story_flags` persistence once more authored flags are introduced
- consider lightweight authoring helpers for route/event definitions if the catalog grows significantly
- add a focused resident-interaction regression scene covering conditional beats, gate fallbacks, and trust milestones

Primary files:

- `game/tests/`
- `game/story_route_graph.gd`
- `game/story_save_service.gd`

## Deferred Design Questions

- whether to add more non-landmark routes beyond the current four
- whether to add more major-event endgame triggers after the current structure settles
- whether to expose more route state directly in the world instead of mostly in dialogue and journal text
- whether to add more authored wandering content after soft endings without introducing a separate after-ending mode
- whether to introduce typed `Resource` subclasses for high-traffic dictionary payloads (landmark progress, melody progress, autosave) to catch key-typo bugs at parse time
- whether to collapse the player profile facade by exposing the profile service directly to UI consumers
