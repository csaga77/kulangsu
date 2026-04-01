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
- `Hear` is represented through resident writing, ambient lines, melody clue text, and shared melody runtime state in [`../../game/app_state.gd`](../../game/app_state.gd).
- `Collect` exists today as a fragment counter in [`../../game/app_state.gd`](../../game/app_state.gd) and the journal `Melody` tab in [`../../ui/screens/journal_overlay.gd`](../../ui/screens/journal_overlay.gd).
- `Practice` now exists as a short ordered-confirmation prompt launched from the journal once the melody is reconstructed.
- `Perform` now routes through the same recognition/prompt layer at the harbor-stage performance point before the shell opens the ending/postgame flow.
- `Unlock` exists today mainly as updated objectives, resident trust, costume unlocks, journal notes, and fragment count changes.
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
  - shared melody runtime state exists
  - melody-specific authored metadata exists in `melody_catalog.gd`
  - journal melody view now shows landmark/source-specific detail
- NPC system:
  - strong current fit
  - residents are already the main source of local clues, trust, and objective nudges
- Performance system:
  - shell and story framing exist
  - a reusable recognition prompt now exists for journal practice, the Trinity choir chime, and the harbor-stage performance point
  - other landmark-specific performance beats may still resolve through simplified landmark dialogue for now
- Growth system:
  - current progression is tracked through chapter, objective, trust, fragments, melody state, and costume unlocks
  - the `heard -> reconstructed -> performed -> resonant` tier model now exists, but later island-side feedback from `resonant` is still light

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
3. ~~There is still no shared `practice` layer in the main story loop.~~ **Resolved.** The journal can now request a reusable ordered-confirmation practice prompt once the melody is reconstructed.
4. ~~Performance exists as one world trigger, but there is not yet a reusable recognition / prompt system for landmark performances.~~ **Resolved for the festival finale.** The harbor-stage performance point now routes through the reusable melody prompt before `performed` is set.
5. ~~`Continue` is prototype-seeded state, not real story persistence.~~ **Resolved.** Story mode now writes and loads a real versioned autosave, the title footer exposes latest save metadata, and `Continue` resumes from a safe landmark or tunnel-entry anchor instead of a fragile in-puzzle position.
6. The external GDD proposes a landmark list that differs from the repo's current authored route.
7. The external GDD suggests JSON data files, but the current project is still primarily catalog-driven through GDScript.

## MVP Implementation Order

Use this order to close the gap with the smallest architectural risk.

> **Note:** Steps 1–7 now have a working first pass. The melody catalog, melody runtime state in AppState, updated journal Melody tab, all five landmark arcs, the reusable practice/performance prompt, the harbor-stage performance point, the ending/postgame handoff, and real story autosave-backed `Continue` are all live. The current starting point is external-route cleanup and any future multi-slot save polish, not the first-pass loop itself.

### ~~1. Formalize Melody Progress As Shared State~~ ✓ Done

`AppState` now owns per-melody runtime state with named ids, fragment counts, progression tier, known sources, next lead, and performed flag.

### ~~2. Add One Authored Melody Catalog~~ ✓ Done

[`../../game/melody_catalog.gd`](../../game/melody_catalog.gd) owns melody definitions. Residents point into it by id.

### ~~3. Upgrade The Journal Melody Tab~~ ✓ Done

The `Melody` journal tab now shows melody name, district, stage, fragment progress, clue map, next lead, and world-response summary per melody.

### ~~4. Build One Complete Landmark Loop~~ ✓ Done

All five landmark arcs are fully integrated and confirmed:

- Piano Ferry onboarding arc (Caretaker Lian -> harbor clue trigger -> journal unlock -> Trinity Church handoff)
- Trinity Church arc (choir cue collection via three `LandmarkTrigger` nodes plus the `ChoirChime` confirmation point)
- Bi Shan Tunnel arc (echo tracing via three echo triggers + mural chamber trigger)
- Long Shan Tunnel arc (entry trigger + lit-pocket checkpoints + exit trigger + return-to-Ren handoff + `tunnel_guide` dialogue beats)
- Bagua Tower arc (synthesis chamber `LandmarkTrigger` + `tower_keeper` dialogue beats + harbor-stage handoff)

All `LandmarkTrigger` nodes have `collision_layer = 1` (layer "object") confirmed explicit. The `SynthesisChamber` in `bagua_tower.tscn` has `z_index = -2` set to align its absolute z_index (6) with the player's z_index after climbing all tower stairs.

See [`piano_ferry.md`](piano_ferry.md), [`trinity_church.md`](trinity_church.md), [`bi_shan_tunnel.md`](bi_shan_tunnel.md), [`long_shan_tunnel.md`](long_shan_tunnel.md), [`bagua_tower.md`](bagua_tower.md), and [`../../game/tests/cue_progression/test_cue_progression.tscn`](../../game/tests/cue_progression/test_cue_progression.tscn) for the current integration coverage.

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

### ~~5. Add One Performance Point~~ ✓ Done

- `festival_stage` is now a real landmark trigger at Piano Ferry.
- Bagua Tower no longer marks the melody performed directly; it unlocks the harbor-stage performance point instead.
- Triggering the harbor stage now opens the reusable melody prompt first; only a correct order advances the melody to `performed` and opens the ending overlay through `festival_performed`.

### ~~6. Add Persistent World Response~~ ✓ Done

- After the harbor-stage performance:
  - the ending overlay opens from gameplay
  - `Stay a Little Longer` seeds `resonant` postgame state and writes the new postgame autosave
  - `Leave on the Morning Ferry` clears the resumable story autosave, shows the dedicated departure card, then rolls credits back to title

### ~~7. Revisit Save / Continue Only After The Loop Exists~~ ✓ Done

- Story mode now writes one versioned autosave payload from `AppState`.
- `Continue` restores melody, landmark, shortcut, resident, player-appearance, and postgame state together.
- `scenes/game_main.gd` now resumes from safe landmark and tunnel-entry anchors instead of interior tunnel positions.

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
- `Free Walk` should not overwrite the story autosave.
- `Continue` should resume at a safe checkpoint anchor, not a tunnel interior or a resident-facing interaction spot.
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
  - `save_metadata_changed`
- Current flow:
  - resident interaction starts in [`../../scenes/game_main.gd`](../../scenes/game_main.gd)
  - resident progression updates in [`../../game/app_state.gd`](../../game/app_state.gd)
  - the journal reads summary text from [`../../ui/screens/journal_overlay.gd`](../../ui/screens/journal_overlay.gd)
  - story autosave metadata stays in [`../../game/app_state.gd`](../../game/app_state.gd) and feeds the title shell in [`../../main.gd`](../../main.gd)

## Contracts / Boundaries

- If melody progress stops being simple fragment count and becomes named runtime state, update [`../contracts.md`](../contracts.md).
- If a melody catalog is introduced, update [`../architecture.md`](../architecture.md) and [`../module_map.md`](../module_map.md).
- If journal melody presentation changes materially, update [`../ui_workflow.md`](../ui_workflow.md) and [`../ui_design_context.md`](../ui_design_context.md).
- If the canonical landmark route changes, update [`../design_brief.md`](../design_brief.md) and [`../core_game_workflow.md`](../core_game_workflow.md).

## Validation

- Run the full project and confirm the overworld, HUD, and journal still open normally.
- Verify that melody-related resident dialogue still updates objective, hint, and resident notes correctly.
- Open the journal and confirm the `Melody` tab reflects the intended story state for `New Game`, `Continue`, and `Free Walk`.
- Run [`../../game/tests/persistence/test_story_autosave.tscn`](../../game/tests/persistence/test_story_autosave.tscn) when save/load or checkpoint behavior changes.
- Verify that journal practice opens only after the melody reaches `reconstructed`, and that a wrong ordered-confirmation attempt fails softly.
- Verify that the harbor-stage performance point opens the same prompt, and that success changes at least one persistent world-facing state without stranding the player on cancellation.

### Reusable Manual Playtest Route

Use this route when you want one end-to-end manual check of the current story-critical melody loop.

1. Start a `New Game`.
   Expectation: the journal is locked, objective is the ferry opening, and fragment count is `0 / 4`.

2. Complete Piano Ferry onboarding.
   Actions: talk to Caretaker Lian, inspect the harbor clue, return to Lian.
   Expectation: the journal unlocks only after the second talk, Trinity Church becomes the next lead, and fragment count stays `0 / 4`.

3. Complete Trinity Church.
   Actions: collect `steps`, then `garden`, then `yard`, then talk to Choir Caretaker Mei.
   Expectation: cue order is enforced through availability, the objective returns to Mei after the third cue, and the melody advances to `1 / 4`.

4. Complete Bi Shan Tunnel.
   Actions: collect `echo_a`, `echo_b`, `echo_c`, then inspect the chamber.
   Expectation: the chamber only resolves after all three echoes, and the melody advances to `2 / 4`.

5. Complete Long Shan Tunnel.
   Actions: enter the tunnel, talk to Ren twice, reach the south lit pocket, reach the north lit pocket, then use the exit and talk to Ren again.
   Expectation: the exit refuses early completion until both lit pockets are reached, the melody advances to `3 / 4`, and Bagua Tower unlocks after Ren's follow-up.

6. Complete Bagua Tower.
   Actions: talk to Suyin, talk again once three fragments are in hand, climb to the synthesis chamber, return to Suyin.
   Expectation: the chamber refuses early use below three fragments, Bagua awards the fourth fragment, and the harbor festival stage unlocks without marking the melody performed yet.

7. Complete the harbor performance.
   Actions: return to Piano Ferry, activate the Festival Stage, then enter the recovered phrase segments in the authored order.
   Expectation: the prompt opens first, a wrong order clears softly, the melody becomes `performed` only after success, and the ending overlay opens with postgame still available from the ending screen.

8. Choose `Stay a Little Longer`, return to title, then choose `Continue`.
   Expectation: the title footer shows the latest saved chapter/location summary, `Continue` is enabled, and the run resumes at the latest safe district anchor rather than an interior tunnel spot.

### Reusable Manual Ending Smoke Pass

Use this shorter route when you only need to verify the ending overlay, credits flow, and `Continue` behavior.

1. Complete the harbor performance and wait for the ending overlay.
   Expectation: the ending overlay opens immediately after a successful performance prompt.

2. Press `Esc` while the ending overlay is open.
   Expectation: the ending overlay stays open; it should not drop back into live gameplay.

3. Choose `Credits`, then back out.
   Expectation: credits return to the ending overlay, not to title or gameplay.

4. Choose `Stay a Little Longer`, then return to title and choose `Continue`.
   Expectation: `Continue` is still enabled and resumes the autosaved postgame harbor state.

5. Reopen the ending overlay, choose `Leave on the Morning Ferry`, then cancel the confirm.
   Expectation: the cancel action keeps the player on the ending overlay.

6. Choose `Leave on the Morning Ferry` again and confirm it.
   Expectation: the dedicated morning-ferry departure card opens before credits, and `Continue` is already disabled for this resolved run.

7. Continue from the departure card through credits, then return to title.
   Expectation: `Continue` is disabled because the resolved story run no longer has a resumable autosave.

### Manual Failure Checks

Run these quick checks when you want confidence that progression gates still fail softly:

1. Press `J` before returning to Lian with the harbor clue.
   Expectation: the journal stays locked and the game shows the onboarding reminder.

2. Try Trinity `garden` before `steps`, and `yard` before `garden`.
   Expectation: those later cues are not yet available.

3. Try the Long Shan exit before both lit pockets are collected.
   Expectation: the route refuses to resolve and points the player back to the lit pockets.

4. Try the Bagua synthesis chamber before three fragments are restored.
   Expectation: the chamber refuses to resolve and preserves the current objective state.

5. Open journal practice after Bi Shan or later, then intentionally submit the wrong order once.
   Expectation: the prompt stays open, gives a gentle retry hint, and clears the selected order without advancing melody state.

6. Choose `Leave on the Morning Ferry` from the ending overlay, return from credits to the title screen, and check the title menu.
   Expectation: `Continue` is disabled because the resolved story run no longer has a resumable autosave.

## Out Of Scope

- Full combat or any combat replacement loop.
- Long rhythm-game stages or score-attack ranking.
- Immediate migration of all authoring into JSON data files.
- Full save/load serialization before a single complete melody loop exists.
- Replacing the current landmark route without an explicit world-design decision.
