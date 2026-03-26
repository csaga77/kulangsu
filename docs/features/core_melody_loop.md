# Core Melody Loop

Read this file first when the task is about Kulangsu's core gameplay loop, melody fragments, musical progression, or turning the high-level RPG pitch into an implementation-ready slice for the current repo.

## Quick Start For Future Agents

Open these files first in this order:

1. [`../design_brief.md`](../design_brief.md)
2. [`../core_game_workflow.md`](../core_game_workflow.md)
3. [`../../game/app_state.gd`](../../game/app_state.gd)
4. [`../../game/resident_catalog.gd`](../../game/resident_catalog.gd)
5. [`../../scenes/game_main.gd`](../../scenes/game_main.gd)
6. [`../../ui/screens/journal_overlay.gd`](../../ui/screens/journal_overlay.gd)

Use [`../core_gameplay_plays.md`](../core_gameplay_plays.md) after this file when you need the broader tone and repeatable-play rationale.

## Goal

- Keep the game centered on a calm exploration-to-performance loop instead of combat or score-chasing.
- Align the external "music RPG" pitch with the systems that already exist in this repo.
- Make the next MVP steps concrete without forcing a large rewrite of the current shell, overworld, or resident systems.

## User / Player Experience

- The player arrives on Kulangsu, explores a readable overworld, and notices that different residents and landmarks carry parts of the island's missing melody.
- Residents and nearby objects give short clues through speech balloons and contextual `R` interactions instead of a large dialogue UI.
- The journal confirms what the player has learned: current objective, known residents, discovered landmarks, and melody progress.
- Each landmark should eventually deliver a short local arc:
  - hear a clue
  - understand who or what needs help
  - traverse the space
  - restore part of the melody
  - see the island respond
- Musical interaction should stay short, low-stakes, and emotionally clear. Recognition matters more than dexterity.

## Current System Mapping

This is how the current repo already maps to the high-level RPG pitch.

### Core Loop Mapping

- `Explore` already exists through the main island scene in [`../../scenes/game_main.gd`](../../scenes/game_main.gd) and the terrain/landmark setup.
- `Hear` is represented mostly through resident writing, ambient lines, and melody clue text in [`../../game/resident_catalog.gd`](../../game/resident_catalog.gd), but not yet as a formal runtime melody state.
- `Collect` exists today as a fragment counter in [`../../game/app_state.gd`](../../game/app_state.gd) and the journal `Melody` tab in [`../../ui/screens/journal_overlay.gd`](../../ui/screens/journal_overlay.gd).
- `Practice` is still mostly design intent. There is not yet a shared practice state or training loop in the main overworld flow.
- `Perform` is also mostly design intent. The shell supports ending/postgame flow, but there is not yet a reusable in-world performance-point system.
- `Unlock` exists today mainly as updated objectives, resident trust, costume unlocks, journal notes, and prototype fragment count changes.
- `Deepen` exists today through resident trust, follow-up dialogue beats, and additional journal context rather than a full authored melody mastery system.

### Current Canonical Landmarks

The current playable project is built around these landmarks:

- `Piano Ferry`
- `Trinity Church`
- `Bi Shan Tunnel`
- `Long Shan Tunnel`
- `Bagua Tower`

The external GDD's `Sunlight Rock` and `Zheng Chenggong Statue` are not part of the current canonical landmark loop yet. If the project wants those areas to replace or join the current route, that should be treated as a world-design decision first, not a silent content swap.

### Current System Mapping By Feature

- Melody system:
  - fragment count exists
  - melody-specific authored metadata does not
  - journal melody view is currently summary-only
- NPC system:
  - strong current fit
  - residents are already the main source of local clues, trust, and objective nudges
- Performance system:
  - shell and story framing exist
  - reusable in-world performance triggers do not yet exist in the main loop
- Growth system:
  - current progression is tracked through chapter, objective, trust, fragments, and costume unlocks
  - explicit melody growth tiers are not yet implemented

## Rules

- Keep the core loop readable: explore, notice, talk, trace, help, perform, resolve.
- Keep music as a world-language system, not a detached rhythm-game layer.
- Keep shared melody progress in [`../../game/app_state.gd`](../../game/app_state.gd), not in UI scripts.
- Keep landmark-specific mechanics local to landmark scenes, feature modules, or focused controllers.
- Keep resident-authored melody clues in [`../../game/resident_catalog.gd`](../../game/resident_catalog.gd) or a future melody catalog, not hardcoded in random scene scripts.
- Do not introduce mandatory combat, score ranking, or long precision-performance stages into the core loop.
- `Free Walk` should remain low-pressure and may seed melody state differently from story mode.

## Gap List

These are the biggest differences between the current project and the target "music RPG" design.

1. ~~There is no formal melody catalog.~~ **Resolved.** `game/melody_catalog.gd` now owns melody definitions. `AppState` now owns per-melody runtime state (`melody_progress`) with named ids, fragment counts, progression tier, known sources, next lead, and performed flag. `melody_progress_changed` is a live signal. The journal `Melody` tab reads full melody-specific text from `AppState.build_melody_journal_text()`.
2. ~~The journal `Melody` tab only shows recovered fragment count.~~ **Resolved.** The journal now shows melody name, district, stage, fragment progress, clue map, next lead, and world-response summary per melody.
3. The main loop has resident-driven objective beats, but not yet landmark-specific gameplay closures such as cue ordering, escort resolution, or tower synthesis in the live runtime.
4. There is no shared `practice` or `performance` state in the main story loop.
5. `Continue` is prototype-seeded state, not real story persistence.
6. The external GDD proposes a landmark list that differs from the repo's current authored route.
7. The external GDD suggests JSON data files, but the current project is still primarily catalog-driven through GDScript.

## MVP Implementation Order

Use this order to close the gap with the smallest architectural risk.

> **Note:** Steps 1–3 below have been completed. The melody catalog, melody runtime state in AppState, and the updated journal Melody tab are all live. The current starting point is Step 4.

### ~~1. Formalize Melody Progress As Shared State~~ ✓ Done

`AppState` now owns per-melody runtime state with named ids, fragment counts, progression tier, known sources, next lead, and performed flag.

### ~~2. Add One Authored Melody Catalog~~ ✓ Done

[`../../game/melody_catalog.gd`](../../game/melody_catalog.gd) owns melody definitions. Residents point into it by id.

### ~~3. Upgrade The Journal Melody Tab~~ ✓ Done

The `Melody` journal tab now shows melody name, district, stage, fragment progress, clue map, next lead, and world-response summary per melody.

### 4. Build One Complete Landmark Loop ✦ Code Complete — Triggers Placed

The route now has a lightweight onboarding arc plus all four landmark arcs implemented in code:

- Piano Ferry onboarding arc (Caretaker Lian -> harbor clue trigger -> journal unlock -> Trinity Church handoff)

- Trinity Church arc (choir cue collection via three `LandmarkTrigger` nodes)
- Bi Shan Tunnel arc (echo tracing via three echo triggers + mural chamber trigger)
- Long Shan Tunnel arc (escort via entry/exit `LandmarkTrigger` nodes + `tunnel_guide` dialogue beats)
- Bagua Tower arc (synthesis chamber `LandmarkTrigger` + `tower_keeper` dialogue beats)

The remaining manual steps are confirming collision layers and tuning trigger positions to match the final scene layouts.

See [`piano_ferry.md`](piano_ferry.md), [`trinity_church.md`](trinity_church.md), [`bi_shan_tunnel.md`](bi_shan_tunnel.md), [`long_shan_tunnel.md`](long_shan_tunnel.md), and [`bagua_tower.md`](bagua_tower.md) for per-landmark integration checklists.

- Use one landmark as the first full vertical slice.
- Good first candidates:
  - `Piano Ferry` for the simplest onboarding loop
  - `Trinity Church` for clue ordering and reconstruction
- The first slice should include:
  - approach and clue
  - resident guidance
  - local task
  - fragment recovery
  - one short performance or activation beat
  - visible world response

### 5. Add One Performance Point

- Create one world trigger where a reconstructed melody can be performed.
- Keep the first version low complexity:
  - simple ordering
  - short timing window
  - contextual activation
- Do not require full integration of [`../../game/piano_game/`](../../game/piano_game) before the first usable version lands.

### 6. Add Persistent World Response

- After a successful performance, change at least one persistent thing:
  - resident dialogue
  - objective text
  - route availability
  - hint text
  - ambient/journal state

### 7. Revisit Save / Continue Only After The Loop Exists

- Do not design full save serialization first.
- Once one melody loop works end to end, then define how `Continue` should store and restore melody, resident, and landmark state together.

## Recommended Growth Tiers

The external GDD uses `recognize -> hum -> perform -> resonate`. The current docs already use `heard -> reconstructed -> performed`.

Recommended project-aligned tier model:

1. `heard`
2. `reconstructed`
3. `performed`
4. `resonant`

Use `resonant` only if the game truly needs a fourth state that means "this melody has changed the island and now feeds back into later content." Do not add it just to satisfy a level count.

## Recommended Data Structures And File Layout

Prefer a GDScript-first authoring pass that matches the rest of the repo.

### Recommended First-Pass Files

- New shared catalog:
  - [`../../game/melody_catalog.gd`](../../game/melody_catalog.gd)
- Existing files to extend:
  - [`../../game/app_state.gd`](../../game/app_state.gd)
  - [`../../game/resident_catalog.gd`](../../game/resident_catalog.gd)
  - [`../../ui/screens/journal_overlay.gd`](../../ui/screens/journal_overlay.gd)
  - landmark scene/controller files under [`../../architecture/`](../../architecture) or focused feature modules under [`../../game/`](../../game)

### Recommended Melody Definition Shape

First-pass authored melody data should include:

- `melody_id`
- `display_name`
- `district`
- `summary`
- `fragment_total`
- `performance_landmark`
- `performance_prompt`
- `unlock_condition`
- `world_response_summary`

Optional fragment-level data can include:

- `fragment_id`
- `source_type`
- `source_id`
- `journal_note`
- `order_index`

### Recommended Runtime Shape In AppState

Each melody runtime entry can start with:

- `state`
- `fragments_found`
- `fragments_total`
- `known_sources`
- `next_lead`
- `performed`

The first implementation should avoid deep nested save schemas until the loop is proven fun.

### Recommended Resident Integration

Resident entries should reference melodies by id instead of embedding large melody state directly.

Useful resident-facing keys may include:

- `melody_id`
- `melody_hint`
- `fragment_reward_id`
- `performance_lead`

### Recommended File-Layout Decision

Do not move immediately to:

- `data/melodies.json`
- `data/fragments.json`
- `data/npcs.json`

That structure may become useful later, but the current project is already organized around GDScript catalogs. Match the existing architecture first, then migrate to JSON only if authoring scale or tooling pressure justifies it.

## Edge Cases

- `Free Walk` should not accidentally advance or fake the full story loop unless that mode is intentionally changed.
- `Continue` is still prototype data. Do not document it as a real save/load flow.
- A resident clue may reveal a melody before the player can perform it; the journal should handle partial knowledge cleanly.
- Melody progress should fail soft when content is missing. A bad melody id should not crash resident interaction or journal rendering.
- Performance points should fail with readable feedback, not silent no-op behavior.
- Landmark tasks should still preserve the calm tone when the player takes the wrong route or arrives early.

## Architecture / Ownership

- [`../../game/app_state.gd`](../../game/app_state.gd) owns shared player-facing melody progress.
- [`../../game/resident_catalog.gd`](../../game/resident_catalog.gd) owns resident-authored clue text and resident-to-melody relationships.
- [`../../game/melody_catalog.gd`](../../game/melody_catalog.gd) owns melody definitions and fragment metadata.
- [`../../scenes/game_main.gd`](../../scenes/game_main.gd) owns overworld integration, location context, and resident interaction wiring.
- Landmark scenes under [`../../architecture/`](../../architecture) or focused gameplay modules under [`../../game/`](../../game) should own local task logic and performance triggers.
- [`../../ui/screens/journal_overlay.gd`](../../ui/screens/journal_overlay.gd) owns melody presentation in the journal.
- [`../../main.gd`](../../main.gd) owns shell flow and overlays, not gameplay rules.

## Relevant Files

- Scenes:
  - [`../../scenes/game_main.tscn`](../../scenes/game_main.tscn)
  - [`../../main.tscn`](../../main.tscn)
  - landmark scenes under [`../../architecture/`](../../architecture)
- Scripts:
  - [`../../scenes/game_main.gd`](../../scenes/game_main.gd)
  - [`../../main.gd`](../../main.gd)
  - [`../../ui/screens/journal_overlay.gd`](../../ui/screens/journal_overlay.gd)
- Shared state or catalogs:
  - [`../../game/app_state.gd`](../../game/app_state.gd)
  - [`../../game/resident_catalog.gd`](../../game/resident_catalog.gd)
  - [`../../game/melody_catalog.gd`](../../game/melody_catalog.gd)
- Related docs:
  - [`../design_brief.md`](../design_brief.md)
  - [`../core_game_workflow.md`](../core_game_workflow.md)
  - [`../core_gameplay_plays.md`](../core_gameplay_plays.md)
  - [`npc_system.md`](npc_system.md)
  - [`../ui_workflow.md`](../ui_workflow.md)

## Signals / Nodes / Data Flow

- Current signals already involved:
  - `objective_changed`
  - `hint_changed`
  - `fragments_changed`
  - `resident_profile_changed`
  - `summary_changed`
- Current flow:
  - resident interaction starts in [`../../scenes/game_main.gd`](../../scenes/game_main.gd)
  - resident progression updates in [`../../game/app_state.gd`](../../game/app_state.gd)
  - the journal reads summary text from [`../../ui/screens/journal_overlay.gd`](../../ui/screens/journal_overlay.gd)
- Recommended next additions:
  - a melody-state getter API in [`../../game/app_state.gd`](../../game/app_state.gd)
  - a melody journal text builder similar to the resident journal helper
  - optional melody-specific signals only if the UI or world needs a cleaner update hook than the existing fragment/objective signals

## Contracts / Boundaries

- If melody progress stops being simple fragment count and becomes named runtime state, update [`../contracts.md`](../contracts.md).
- If a melody catalog is introduced, update [`../architecture.md`](../architecture.md) and [`../module_map.md`](../module_map.md).
- If journal melody presentation changes materially, update [`../ui_workflow.md`](../ui_workflow.md) and [`../ui_design_context.md`](../ui_design_context.md).
- If the canonical landmark route changes, update [`../design_brief.md`](../design_brief.md) and [`../core_game_workflow.md`](../core_game_workflow.md).

## Validation

- Run the full project and confirm the overworld, HUD, and journal still open normally.
- Verify that melody-related resident dialogue still updates objective, hint, and resident notes correctly.
- Open the journal and confirm the `Melody` tab reflects the intended story state for `New Game`, `Continue`, and `Free Walk`.
- When the first performance point exists, verify:
  - early arrival is handled clearly
  - successful performance changes at least one persistent world-facing state
  - failure or cancellation does not strand the player in a broken objective state

## Out Of Scope

- Full combat or any combat replacement loop.
- Long rhythm-game stages or score-attack ranking.
- Immediate migration of all authoring into JSON data files.
- Full save/load serialization before a single complete melody loop exists.
- Replacing the current landmark route without an explicit world-design decision.
