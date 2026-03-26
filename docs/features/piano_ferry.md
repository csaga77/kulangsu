# Piano Ferry Onboarding Arc

Lightweight opening arc for the arrival district. The player talks to Caretaker Lian, inspects one harbor clue in the plaza, returns to Lian, and unlocks the journal plus the first uphill landmark lead.

## Goal

- Give the first minutes of the game one complete local loop instead of only a directional nudge.
- Teach the intended flow: talk, inspect, return, then choose the next landmark.
- Unlock the journal only after the player has completed one readable clue cycle.

## User / Player Experience

The player arrives at the ferry plaza with the island feeling unusually quiet. Caretaker Lian points them toward the old piano crate near the notice board instead of immediately sending them uphill. The player walks a short distance, presses `R` at the harbor clue, and gets a short melody hint about the plaza's opening pulse. Returning to Lian resolves the onboarding arc: Trinity Church becomes the first real lead, the journal unlocks, and the player has both an emotional reason and a practical route for leaving the harbor.

The mood stays calm. There is no timer, no wrong answer, and no fragment reward here. The ferry teaches the loop and frames the island melody before the landmark arcs begin.

## Rules

- Piano Ferry starts `available` in `New Game`, `introduced` in `Free Walk`, and `reward_collected` in `Continue` and `Postgame`.
- `ferry_caretaker` beat 0 carries `"landmark_states": {"piano_ferry": "introduced"}`. This reveals the harbor clue trigger and sets the immediate objective to inspect the piano crate.
- The harbor clue is a single `LandmarkTrigger` node placed directly in `piano_ferry.tscn`.
- Pressing `R` at the harbor clue calls `AppState.activate_landmark_trigger("piano_ferry", "harbor_refrain", ...)`.
- When the trigger fires:
  - `landmark_progress["piano_ferry"]["harbor_clue_found"]` becomes `true`
  - landmark state advances to `resolved`
  - the clue emits one short `melody_hint`
  - objective updates to return to Caretaker Lian
- `ferry_caretaker` beat 1 is gated on `"gate": "piano_ferry_harbor_clue"`. Before the gate passes, she repeats the harbor-clue fallback.
- When beat 1 fires:
  - `trinity_church` unlocks to `available`
  - `"landmark_reward": "piano_ferry"` resolves the onboarding arc
  - the journal unlocks
  - `festival_melody.next_lead` updates to Trinity Church
  - Piano Ferry advances to `reward_collected`
- `ferry_caretaker` beat 2 is gated on `"gate": "first_fragment_restored"` so the post-church harbor follow-up does not appear too early.

## Edge Cases

- Pressing `J` before the ferry arc resolves should not open the journal. The app shell instead shows a short status reminder telling the player to return to Caretaker Lian with the harbor clue.
- Opening the pause menu before the ferry arc resolves shows the journal button as disabled.
- Re-activating the harbor clue after collection is a no-op.
- If `_resolve_piano_ferry()` is called again in a seeded mode, it should keep `ferry_plaza` in known sources and leave fragment counts unchanged.
- `Free Walk` starts with the journal already unlocked even though the ferry clue can still be played as ambient onboarding content.

## Architecture / Ownership

- `AppState` owns Piano Ferry progress state, the journal unlock flag, and the harbor-clue collection/resolution flow.
- `resident_catalog.gd` owns Caretaker Lian's gate logic and the Trinity Church handoff beat.
- `piano_ferry.tscn` hosts the `LandmarkTrigger` node directly; its configuration lives in exported properties.
- `main.gd` and `scenes/game_main.gd` query `AppState.is_journal_unlocked()` to keep controls text and journal access in sync with the onboarding state.

## Relevant Files

- Scenes:
  - [`../../architecture/piano_ferry.tscn`](../../architecture/piano_ferry.tscn)
- Scripts:
  - [`../../game/app_state.gd`](../../game/app_state.gd)
  - [`../../game/resident_catalog.gd`](../../game/resident_catalog.gd)
  - [`../../game/landmark_trigger.gd`](../../game/landmark_trigger.gd)
  - [`../../main.gd`](../../main.gd)
  - [`../../scenes/game_main.gd`](../../scenes/game_main.gd)
  - [`../../ui/screens/pause_overlay.gd`](../../ui/screens/pause_overlay.gd)
- Shared state or catalogs:
  - `AppState.landmark_progress["piano_ferry"]`
  - `AppState.melody_progress["festival_melody"]`
- Related docs:
  - [`../contracts.md`](../contracts.md) — Shared State Contract and Landmark Progress Contract
  - [`core_melody_loop.md`](core_melody_loop.md)
  - [`../core_game_workflow.md`](../core_game_workflow.md)

## Signals / Nodes / Data Flow

- Signals emitted:
  - `AppState.landmark_progress_changed("piano_ferry", progress)` — on intro and clue resolution
  - `AppState.melody_hint_shown(text)` — when the harbor clue is inspected
- Signals consumed:
  - `AppState.landmark_progress_changed` — consumed by the ferry `LandmarkTrigger`
- Data flow:
  - player talks to `ferry_caretaker` beat 0 -> landmark advances to `introduced`
  - player presses `R` at `HarborRefrain` -> `activate_landmark_trigger` -> `harbor_clue_found = true` -> objective points back to Lian
  - player talks to `ferry_caretaker` beat 1 -> gate passes -> Trinity Church unlocks -> `_resolve_piano_ferry()` unlocks the journal and marks the first lead

## Contracts / Boundaries

- The `landmark_progress["piano_ferry"]` shape (`state`, `harbor_clue_found`) is part of the Landmark Progress Contract in `contracts.md`.
- `main.gd` should gate journal opening through `AppState.is_journal_unlocked()` rather than duplicating local tutorial state.
- `LandmarkTrigger` must not write `AppState` fields directly.

## Validation

- Start a `New Game`. Confirm the journal does not open from `J` or the pause menu.
- Talk to Caretaker Lian once. Confirm the harbor clue becomes available and the objective points to the piano crate / notice board.
- Press `R` at the harbor clue. Confirm the melody hint appears and the objective points back to Lian.
- Talk to Lian again. Confirm Trinity Church unlocks, the journal opens from `J`, and the Melody tab points to the church as the next lead.
- Talk to Lian a third time before resolving Trinity Church. Confirm the follow-up gate fallback appears instead of the post-fragment line.

## Out Of Scope

- A ferry-specific fragment reward.
- Extra cinematic staging for arrival.
- Additional harbor-side ambient resident arcs beyond the current catalog content.
