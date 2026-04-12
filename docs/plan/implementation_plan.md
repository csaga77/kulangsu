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

Regression coverage now includes:

- full landmark cue progression
- story autosave and continue
- seasonal route progression outside the landmark spine

## What Remains

The next phase is mostly content, reactivity, and final-act polish rather than more progression architecture.

## Workstream 1: Route Content Depth

Goal:

- deepen the authored beats inside the new route structure

Tasks:

- add more resident beats to `family_memory`, especially around A Po, the parents, and church-linked memory
- add more study/future beats so the route feels like a year-long pressure line instead of a few turning points
- add more preservation beats outside Bagua Tower so architecture becomes visible across the island
- add more optional landmark-route enrichment that affects ending tone without becoming mandatory

Primary files:

- `game/resident_catalog.gd`
- `docs/story/summer_of_piano_island_story_framework.md`
- `docs/core_game_workflow.md`

## Workstream 2: World-State Reactivity

Goal:

- make route progress change what the island feels like, not just what the journal says

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

Primary files:

- `game/tests/`
- `game/story_route_graph.gd`
- `game/story_save_service.gd`

## Deferred Design Questions

- whether to add more non-landmark routes beyond the current four
- whether to add more major-event endgame triggers after the current structure settles
- whether to expose more route state directly in the world instead of mostly in dialogue and journal text
- whether to add more authored postgame-only wandering content for stay endings
