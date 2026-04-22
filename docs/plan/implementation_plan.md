# Kulangsu Implementation Plan

This is the canonical implementation plan for the current playable game.

Read `AGENTS.md`, [`../design_brief.md`](../design_brief.md), [`../architecture.md`](../architecture.md), and [`../core_game_workflow.md`](../core_game_workflow.md) before starting a new task.

## Current State

The seasonal multi-route story architecture is now live.

Shipped foundations:

- `season_phase`-driven progression instead of `chapter` as the primary gate
- four canonical routes: family, study, preservation, melody
- one pinned HUD lead plus multi-route journal view
- modular storyline authoring in `game/storylines/`, with route projection and endgame trigger logic in `game/story_route_graph.gd`
- first-pass StoryEvent runtime in `game/story_event_service.gd`, including subject-based resident talk, landmark-trigger routing, and inspectable routing through `AppState`
- first authored StoryEvent tree file in `game/story_event_catalog.gd`, now owning the full `melody_landmarks` interaction spine: ferry harbor clue, Trinity cue/chime, Bi Shan echoes/chamber, Long Shan entry/checkpoints/exit, Bagua synthesis, and the harbor-stage prompt-open
- save/load support for seasonal story state, route state, lead pinning, and endgame state
- story-driven resident routine overrides that persist through autosave/continue and reapply to live actors in `game_main`
- resident gating against `season_phase`, route state, and `story_flags`
- guarded final-act start with `spring_festival_resolved` as the earliest allowed endgame threshold
- `AppState` composition pattern with extracted helpers for profile, journal, save, landmark progression, resident interaction, audio settings, and story routes
- explicit manual-versus-auto lead presentation plus an in-journal `Auto Lead` clear action
- weather system with manager-owned overworld preset cycling, wind sync, and runtime rig instancing
- shared overworld weather preset resource consumed by both `game_main` and the focused weather sandbox
- BGM weighted selection with 12-track catalog, commitment window, silence gaps, and landmark cue ducking
- landmark audio cues for all five canonical landmarks plus the festival stage
- first resident override resources shipped through `game/residents/definitions/`
- differentiated ending and departure copy for exam, honest-future, and harbor-performance routes, including soft-ending stay-versus-leave text
- added cross-route resident follow-through across harbor, church, and Bagua districts after winter-memory, preservation, future-choice, second-summer, and resonant-festival beats
- scene-level milestone status feedback for major route events so world-state changes are not only visible in journal text
- harbor, church, and Bagua inspectable surfaces now carry route-state reactivity so non-resident world objects reflect Spring Festival, winter-memory, future-choice, second-summer, and preservation beats

Regression coverage now includes:

- full landmark cue progression
- story autosave and continue
- seasonal route progression outside the landmark spine
- resident interaction gate/trust/autosave coverage
- cross-route resident reactivity coverage
- arbitrary `story_flags` persistence coverage
- override-backed resident profile persistence coverage
- external resident override parity coverage
- BGM lazy catalog validation and location-fallback variety
- portal/level transitions across Bagua Tower, tunnels, and multi-level spaces

## Content Reality Check

The architecture and authored content are now much closer together, but route density is still uneven.

Current practical coverage:

- `family_memory` now carries harbor return, church memory, winter revelation, A Po and parent-care reflection, Spring Festival preparation, and aftermath, but still leans heavily on resident talk instead of household scenes
- `study_future` now echoes across Pei, Lin, Min, and Jun, but still needs more lived middle beats between the major turns
- `preservation_inheritance` now spans harbor, Bagua, postcards, and map-making language, but still needs more inspectable and prop-level world response
- `melody_landmarks` remains the richest embodied route and now has a resonant follow-through after the public performance
- final-act text now differentiates the three ending triggers, but the closing movement still happens mostly through overlays rather than bespoke playable scenes

## Architecture Reality Check

`AppState` (about 1.3k lines, 30 signals) is still the shared state hub. The Workstream 0 cleanup shipped first, and the follow-on content/HUD/ending pass now builds on that bridge surface cleanly. The next monolith is `resident_catalog.gd` (about 1.6k lines), which is still where most route growth lands until more residents move into per-definition resources.

Current pressure points:

- most resident definitions, dialogue spines, and conditional beats still live in `resident_catalog.gd`; only the first override resources have moved into per-resident `.tres` files
- `AppState` still carries a broad facade/signal surface, including many one-line forwarding methods that are useful for compatibility but still add maintenance cost
- `StorySaveService` and `LandmarkProgression` remain intentionally tight `AppState` helpers, so future cleanup still needs to preserve the bridge API instead of assuming those helpers are independently reusable modules
- `StoryEventService` is now live as a shared subject/effect bridge, and `story_event_catalog.gd` now owns the full melody-landmark interaction spine plus its landmark prompt-completion/reward world events, but most progression still projects off typed storyline route resources plus `story_route_graph.gd`, resident dictionaries, and `story_world_reactivity.gd` instead of a fuller recursive event definition set plus a published-fact ledger
- route-content work will keep touching large built-in resident dictionaries until more residents migrate out of the script catalog
- storyline authoring is now decoupled from the old central route graph, but the current `game/storylines/*.gd` modules are still flat code-authored dictionaries with no editor-native picker workflow, typed schema, or graph view
- high-traffic dictionary payloads (landmark progress, melody progress, autosave) are still untyped
- regression coverage is now strong for landmark, route, resident-interaction, reactivity, and autosave flows, but still lighter around settings/audio behavior and richer world-object reactivity

## What Remains

Workstream 0 is complete. Workstreams 1-5 all have a shipped first pass, but they are still active tracks rather than fully finished bodies of work. The next phase is no longer the architecture pass itself; it is about deepening those content and polish workstreams until the remaining embodied-scene, world-reactivity, and closing-movement gaps are closed. Resident migration remains useful sidecar cleanup, but it is not the recommended next focus while the manual conversion path is still relatively expensive.

### Status Summary

| Workstream | Status | Next Priority |
|------------|--------|---------------|
| Workstream 0 | Complete | — |
| Workstream 1 | First pass shipped | Priority 1 (content depth) |
| Workstream 2 | First pass shipped | Priority 2 (world reactivity) |
| Workstream 3 | First pass shipped | Priority 3 (ending polish after more content) |
| Workstream 4 | First pass shipped | Lower (polish) |
| Workstream 5 | First pass shipped | Priority 4 (editor workflow), then Priority 5 (validation) |
| Resident Migration | Partial (6 migrated; remaining require manual `.tres` conversion) | Deferred sidecar (touch when content work needs it) |

### Priority 1: Route Content Depth (recommended next)

- add more embodied household, festival, and closing-movement scenes so the strongest beats are not carried mostly by overlays and talk lines
- focus first on `family_memory` household beats or `study_future` middle beats

### Priority 2: World-State Reactivity (depends on content depth)

- extend route reactivity into inspectables, props, ambient audio, district dressing, and more non-resident surfaces
- keep widening cross-district follow-through so major anchors feel visible outside the specific resident who resolved them

### Priority 3: Final-Act And Ending Polish (after more embodied content)

- turn more of the final-act and departure texture into playable closing movement rather than leaving it mostly in overlays
- keep sharpening trigger-specific aftermath and ferry framing once more embodied content exists to support it

### Priority 4: Storyline Editor Workflow (before major route-count expansion)

- introduce an editor-native, typed storyline data model first, then let the runtime loader/projector read that data without changing route semantics
- ship inspector-first authoring and validation before any graph view so the source of truth becomes stable before UI polish work starts
- make cross-route dependencies safe to author through searchable event-id pickers and validation instead of raw string editing

### Priority 5: Validation Expansion (lower urgency, opportunistic)

- widen validation around settings/audio behavior and richer world-state reactivity
- add focused coverage for future typed payload migrations and storyline-editor migrations if that cleanup starts

### Deferred Sidecar: Resident Migration (manual conversion; not the recommended next focus)

- 6 residents already migrated to `.tres` files
- keep migrating touched residents when content work already requires editing them, or when review velocity becomes the bottleneck
- avoid making manual conversion the headline task until helper/tooling work makes that path meaningfully cheaper

## Workstream 1: Route Content Depth

First-pass shipped outcome:

- `family_memory` now has explicit A Po and parent-care reflection after winter, plus a Spring Festival aftermath beat
- `study_future` now keeps sounding across church and harbor residents after the future choice and second-summer release
- `preservation_inheritance` now reaches beyond Bagua's first perspective beat into postcard and map-stewardship reactions
- `melody_landmarks` now has a softer resonant follow-through after the harbor performance

Still open:

- add more embodied household, festival, and district scenes so route depth is not carried mostly by talk beats
- spread the mid-route beats across more playable spaces and smaller turns instead of relying on a handful of major resident conversations

Primary files:

- `game/resident_catalog.gd`
- `docs/story/summer_of_piano_island_story_framework.md`
- `docs/core_game_workflow.md`

## Workstream 2: World-State Reactivity

First-pass shipped outcome:

- new conditional beats now react to winter-memory, Spring Festival, future-choice, second-summer, preservation, and resonant-festival state across ferry, church, and Bagua districts
- `scenes/game_main.gd` now surfaces selected route-event resolutions as world-status feedback instead of leaving those turns only in journal state
- route-aware inspectables at Piano Ferry, Trinity Church, and Bagua Tower now carry non-resident world reactivity alongside dialogue follow-through
- first-pass StoryEvent routing now unifies resident talk, inspectable resolution, shared condition matching, and live resident routine overrides behind the `AppState` story-subject bridge
- route progress now changes more of what the island feels like without requiring landmark-only progression

Still open:

- extend route-state changes into inspectables, props, ambient audio, district dressing, and more non-resident surfaces
- migrate landmark triggers and broader route authoring into recursive StoryEvent definitions so typed storyline route resources plus the route graph projection stop being the only canonical progression source
- keep widening cross-district follow-through so major anchors feel visible outside the specific resident who resolved them

Primary files:

- `game/resident_catalog.gd`
- `game/story_event_service.gd`
- `game/story_world_reactivity.gd`
- `architecture/piano_ferry.tscn`
- `architecture/trinity_church.tscn`
- `architecture/bagua_tower/bagua_tower.tscn`
- `scenes/game_main.gd`

## Workstream 3: Final-Act And Ending Polish

First-pass shipped outcome:

- ending and departure overlays now have trigger-specific title, summary, and departure language for exam, honest-future, and harbor-performance runs
- soft endings now present explicit stay-versus-leave text instead of only a generic continue prompt
- route emphasis and expanded tone tags now feed the final summary language

Still open:

- turn more of the final-act and departure texture into playable closing movement rather than leaving it mostly in overlays
- keep sharpening trigger-specific aftermath and ferry framing once more embodied content exists to support it

Primary files:

- `ui/screens/ending_overlay.gd`
- `ui/screens/departure_overlay.gd`
- `game/story_route_graph.gd`

## Workstream 4: Journal And HUD Polish

First-pass shipped outcome:

- the HUD now distinguishes manual versus automatic pinned-lead state
- the journal now shows lead-selection mode, route emphasis, richer per-route counts, and lead-control guidance
- the `Auto Lead` action now makes manual lead clearing explicit instead of leaving it implied

Still open:

- decide whether later route-sectioning, icons, or other stronger visual grouping would help once more route content lands
- keep tuning wording and density as the ledger grows so readability does not slip

Primary files:

- `ui/screens/game_hud.gd`
- `ui/screens/journal_overlay.gd`
- `ui/screens/journal_overlay.tscn`
- `game/journal_builder.gd`

## Workstream 5: Storyline Editor Workflow, Content Tooling, And Test Growth

First-pass shipped outcome:

- per-route storyline resources now live under `game/storylines/routes/`, so adding or editing a route no longer requires touching the central route graph
- added focused route-reactivity coverage in `game/tests/story_routes/test_story_reactivity.tscn`
- added focused StoryEvent bridge coverage in `game/tests/story_routes/test_story_event_service.tscn`
- added arbitrary-flag plus override-backed resident profile persistence coverage in `game/tests/persistence/test_story_state_persistence.tscn`
- kept the existing seasonal-route, resident-interaction, and autosave regressions green after the content pass

Phases 1–3 shipped:

- Phase 1 — typed Resource schema:
  - `game/storylines/resources/storyline_ending_tone_rule.gd` — `StorylineEndingToneRule`
  - `game/storylines/resources/storyline_event_resource.gd` — `StorylineEventResource` with `to_dict()` and `validate()`
  - `game/storylines/resources/storyline_route_resource.gd` — `StorylineRouteResource` with `to_storyline_dict()` and `validate()`
  - `StorylineCatalog` now loads `.tres` files from `game/storylines/routes/` as the canonical source; legacy `*_storyline.gd` loading remains only as a compatibility path for older routes that still need migration
  - the public API (`build_route_definitions` / `build_event_definitions`) is unchanged so the runtime, journal, and save systems need no edits
- Phase 2 — inspector-first workflow:
  - `@tool` `validate()` methods on all three resource classes check for empty ids, duplicate event ids within a route, invalid `phase_window` values, and missing `ending_behavior` on endgame events, while project-wide prerequisite existence checks remain in the editor tooling so valid cross-route dependencies are not treated as route-local warnings
  - `addons/storyline_editor/storyline_validator_inspector_plugin.gd` — `EditorInspectorPlugin` that shows a validation-warning panel which auto-refreshes when inspector edits change route or event validation status, listens to normal inspector property edits so browser warnings and inspector status messages update immediately, keeps `StorylineEventResource.phase_window` as a native array property while constraining each entry to the canonical season-phase list, swaps `story_flags_all` / `story_flags_any` editing away from raw string arrays into a route-rooted event picker that mirrors the storyline browser and keeps those `All` / `Any` dependencies synchronized with graph/browser refreshes, and swaps `StorylineRouteResource` event creation away from raw array editing into a Route Events panel that generates unique default ids like `<route_name>_new_event_1`, confirms before deleting events, and refreshes the storyline browser immediately
- Phase 3 — route browser dock:
  - `addons/storyline_editor/storyline_route_browser.gd` — Scene/Import-stack dock with one combined storyline tree whose top-level rows are routes with source badges and whose child rows are route events; also surfaces project-wide missing-prerequisite validation warnings, provides a `+ New` scaffold action for `StorylineRouteResource` files, and uses a selection-driven `Delete` action that confirms before deleting either the selected route's authored source files or the selected event from its canonical typed route resource while clearing any now-deleted inspector selection
  - selecting a route row emits an inspector-edit request so the plugin opens that `StorylineRouteResource` in the Inspector using the same typed-resource promotion flow as the graph editor; selecting an event row does the same for the backing `StorylineEventResource`, while double-clicking an event still emits `event_show_in_graph_requested` to scroll and highlight the node in the graph editor

Phase 4 shipped (first pass):

- `addons/storyline_editor/` — GraphEdit-based dependency view added as an editor bottom panel
- reads live data directly from `StorylineCatalog`; events from all four typed route resources are shown as color-coded GraphNodes
- prerequisite edges (`story_flags_all` / `story_flags_any`) are drawn as directed connections; cross-route dependencies visible in "All routes" mode
- events are laid out in columns by topological depth (longest prerequisite chain), sorted within each column by route display order
- per-route filter, Refresh button, and graph-first authoring flow without a redundant in-panel details pane; event inspection/editing now happens through the Inspector when a node is selected
- dependency edges are now editable in the graph: each node exposes separate `All` and `Any` input slots, so connecting to `All` writes `story_flags_all`, connecting to `Any` writes `story_flags_any`, and dragging either end of an existing connection disconnects it from the targeted bucket
- compatibility-only: if a target route still lives in a legacy `*_storyline.gd` module, the first graph edit auto-promotes that route into `game/storylines/routes/<route_id>.tres` and then saves the dependency change there
- selecting a graph node now resolves the backing `StorylineEventResource` into the Inspector so authors can edit event properties directly from the graph; if an older legacy route is ever reopened, the graph still auto-promotes it into `game/storylines/routes/` first so the inspector edits the canonical typed resource
- graph edits emit a catalog refresh so the route browser updates its source badge and event tree without requiring a manual dock reload, and structural route/event changes from the browser or route-event inspector panel now refresh the graph's route filter and visible nodes without a manual graph reload
- manual graph layout now persists per user across editor restarts instead of resetting to auto-layout each session, and the graph toolbar can explicitly re-run automatic layout for the currently visible nodes
- widen validation around settings/audio behavior and any future typed payload migrations, and keep extending regression coverage as the authoring format evolves

Exit criteria for this workstream:

- authors can create and edit a storyline in the Godot editor without changing `story_route_graph.gd` or hand-editing raw GDScript dictionaries
- cross-route event dependencies are selectable and validated from the editor
- the runtime, journal, and autosave systems keep reading one canonical storyline source of truth
- any later graph editor writes back to that same source of truth instead of inventing a separate graph-only format

Primary files:

- `game/storylines/storyline_catalog.gd`
- `game/story_route_graph.gd`
- planned editor-native storyline resource classes near `game/storylines/`
- planned editor plugin under `addons/`
- `game/tests/story_routes/test_story_reactivity.gd`
- `game/tests/persistence/test_story_state_persistence.gd`
- `game/tests/story_routes/test_story_routes.gd`
- `game/tests/persistence/test_story_autosave.gd`

## Completed Workstream 0: AppState Decomposition And Architecture Cleanup

Shipped outcome:

- landmark progression behavior is now split between authored StoryEvent landmark bindings/world events and `game/landmark_progression.gd`'s remaining generic prompt-builder/fallback helpers, while `AppState` keeps the landmark bridge API and signal surface
- resident dialogue/application lives in `game/resident_interaction_service.gd` with `AppState` facades preserved for runtime callers and tests
- runtime settings state lives in `game/audio_settings_service.gd`
- `StorySaveService` owns the active payload pipeline plus `configure_new_game()`, `configure_continue()`, and `configure_free_walk()` implementation while `AppState` keeps the public bridge methods
- the shared default overworld weather tuning now lives in `weather/overworld_weather_preset.tres`, consumed by both `scenes/game_main.gd` and `weather/tests/test_weather.gd`
- the resident catalog split has started with resource overrides under `game/residents/definitions/`

Verification now in repo:

- `game/tests/cue_progression/test_cue_progression.tscn`
- `game/tests/persistence/test_story_autosave.tscn`
- `game/tests/story_routes/test_story_routes.tscn`
- `game/tests/npc_system/test_npc_control.tscn`
- `game/tests/npc_system/test_resident_interaction.tscn`
- `game/tests/npc_system/test_resident_catalog_external_defs.tscn`

## Deferred Design Questions

### High-Impact (affect significant architecture)

1. **Typed Resource Migration**: Whether to introduce `Resource` subclasses for high-traffic dictionary payloads (landmark progress, melody progress, autosave) to catch key-typo bugs at parse time
2. **Route State Visibility**: Whether to expose more route state directly in the world instead of mostly in dialogue and journal text

### Medium-Impact (add content or modes)

3. **Additional Routes**: Whether to add more non-landmark routes beyond the current four
4. **Additional Endgame Triggers**: Whether to add more major-event endgame triggers after the current structure settles
5. **Post-Ending Wandering**: Whether to add more authored wandering content after soft endings without introducing a separate after-ending mode

### Low-Impact (cleanup/refinement)

6. **Profile Facade Collapse**: Whether to collapse the player profile facade by exposing the profile service directly to UI consumers
