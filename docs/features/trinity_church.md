# Trinity Church Arc

The first complete landmark loop. Establishes the quest plumbing pattern that Bi Shan Tunnel, Long Shan Tunnel, and Bagua Tower will reuse.

## Goal

- Give the player a concrete, low-pressure task with a clear start, solve, and reward.
- Prove the landmark quest state machine, pickup trigger system, and melody fragment award end-to-end.
- Set the template for the remaining three landmark arcs.

## User / Player Experience

The player arrives at Trinity Church after Caretaker Lian at the ferry points them there. Choir Caretaker Mei explains that three choir cues have scattered across the church grounds. The player walks the grounds, presses R near three glowing or visually distinct spots (the front steps, the side garden, and the quiet yard), and collects each cue. Once all three are in hand, returning to Mei and pressing R triggers the resolution: the phrase settles, the fragment is awarded, and the journal updates to point toward the tunnels. The church caretaker's ambient lines change after resolution.

The mood should stay calm throughout. There is no timer, no failure state, and no wrong order for collecting the three cues. The ordering gate applies only to the resolution beat — the player cannot trigger Mei's resolved dialogue until all three are in hand.

## Rules

- Trinity Church starts `locked`. It unlocks to `available` when the `ferry_caretaker` fires her first dialogue beat (`"unlock_landmark": "trinity_church"`).
- The three choir cue triggers (steps, garden, yard) are visible and collectible once the landmark state is `available`, `introduced`, or `in_progress`.
- Each cue is a `LandmarkTrigger` node placed directly in the scene. Collecting one calls `AppState.activate_landmark_trigger("trinity_church", cue_id, display_name, melody_hint)`.
- Each cue carries a `melody_hint` export — flavour text shown on-screen when collected (e.g. "A low bell tone echoes from the old stone steps..."). This gives the player incremental melody feedback during the pickup walk.
- Landmark state advances to `in_progress` on first cue collection.
- The church_caretaker's resolved dialogue beat (beat index 2) has `"gate": "trinity_church_cues"`. It only fires when all three cues are in `cues_collected`. Before that, she responds with the gate fallback line.
- When the gate passes and the resolved beat fires, `"landmark_reward": "trinity_church"` triggers `AppState._resolve_trinity_church()`:
  - Landmark state advances to `reward_collected`.
  - `church_bells` is added to `festival_melody.known_sources`.
  - `festival_melody.fragments_found` increments by 1.
  - `festival_melody.state` updates to `heard` (1 fragment) or `reconstructed` (2+).
  - `bi_shan_tunnel` and `long_shan_tunnel` landmark states advance to `available`.
- Cue triggers hide themselves after collection. The controller re-hides all cues when landmark state is `resolved` or `reward_collected`.
- In `Free Walk` mode, the landmark starts `available` and the arc can be played through normally.
- In `Continue` mode, the landmark starts `reward_collected` and cues are hidden. No arc re-play.

## Edge Cases

- If the player talks to church_caretaker before collecting any cues, her beat 0 fires normally (no gate). Beat 1 fires normally. Beat 2 is gated.
- If the player collects all three cues without ever talking to church_caretaker, the objective updates to "Return to Choir Caretaker Mei" and the hint updates. The gate passes when she is next approached.
- If `activate_landmark_trigger` is called with an already-collected cue_id, it is a no-op. The `LandmarkTrigger.collect()` guard also prevents double-collection.
- If `_resolve_trinity_church()` is called more than once (e.g. due to a save/load edge case), `church_bells` is only appended once (guarded by `find` check) and fragment counts are clamped to `fragments_total`.
- Free Walk should not advance story chapter or set tunnel states differently. Currently it does advance `bi_shan_tunnel` and `long_shan_tunnel` to `available` on resolve — this is acceptable in sandbox mode.

## Architecture / Ownership

- `AppState` owns all landmark progress state, the pickup collection logic, and the fragment reward.
- Each `LandmarkTrigger` placed in the scene self-manages its own visibility by subscribing to `AppState.landmark_progress_changed`.
- `LandmarkTrigger` owns its own collected state and hide/disable behavior.
- `scenes/game_main.gd` routes R-inspect on `LandmarkTrigger` nodes to `AppState.activate_landmark_trigger()`.
- `resident_catalog.gd` owns the authored beat gates and landmark reward keys for church_caretaker and ferry_caretaker.
- `trinity_church.tscn` hosts the controller as a child node. No logic lives in the scene file itself.

## Relevant Files

- Scenes:
  - [`../../architecture/trinity_church.tscn`](../../architecture/trinity_church.tscn)
- Scripts:
  - [`../../game/landmark_trigger.gd`](../../game/landmark_trigger.gd)
  - [`../../game/app_state.gd`](../../game/app_state.gd)
  - [`../../game/resident_catalog.gd`](../../game/resident_catalog.gd)
  - [`../../scenes/game_main.gd`](../../scenes/game_main.gd)
- Shared state or catalogs:
  - `AppState.landmark_progress["trinity_church"]`
  - `AppState.melody_progress["festival_melody"]`
- Related docs:
  - [`../contracts.md`](../contracts.md) — Landmark Progress Contract
  - [`core_melody_loop.md`](core_melody_loop.md)
  - [`../core_game_workflow.md`](../core_game_workflow.md)

## Signals / Nodes / Data Flow

- Signals emitted:
  - `AppState.landmark_progress_changed("trinity_church", progress)` — on any cue collection or state advance
  - `AppState.melody_hint_shown(text)` — on each cue collection (carries the trigger's `melody_hint` flavour text)
  - `AppState.melody_progress_changed("festival_melody", state)` — on arc resolution
  - `AppState.fragments_changed(found, total)` — on arc resolution (via set_melody_progress)
- Signals consumed:
  - `AppState.landmark_progress_changed` — consumed by each `LandmarkTrigger` to self-manage visibility
- Data flow:
  - `ferry_caretaker` beat 0 fires → `_apply_resident_beat` reads `"unlock_landmark": "trinity_church"` → `advance_landmark_state("trinity_church", "available")` → `LandmarkTrigger._on_landmark_progress_changed` shows cue triggers
  - Player presses R near a cue → `scenes/game_main.gd._on_inspect_requested` → `AppState.activate_landmark_trigger` → `_collect_trinity_church_cue` → `landmark_progress_changed`
  - Player presses R on church_caretaker with all cues → `interact_with_resident` → gate passes → beat fires → `_apply_resident_beat` reads `"landmark_reward": "trinity_church"` → `_resolve_trinity_church` → melody and landmark state update

## Contracts / Boundaries

- The `"gate"`, `"gate_fallback"`, `"unlock_landmark"`, and `"landmark_reward"` beat fields are part of the resident beat contract. If they are renamed or removed, update `contracts.md` and `_apply_resident_beat`.
- The `landmark_progress["trinity_church"]` shape (`state`, `cues_collected`) is part of the Landmark Progress Contract in `contracts.md`. Update that file if fields are added or renamed.
- `LandmarkTrigger` must not read or write `AppState` fields directly; it uses the public API (`get_landmark_progress`, `landmark_progress_changed`).

## Validation

- Run the game, start a New Game, talk to Caretaker Lian. Confirm trinity_church advances to `available` and the three cue triggers appear near the church.
- Walk to each cue and press R. Confirm each one disappears and the objective/hint updates after the third.
- Talk to church_caretaker before collecting all cues. Confirm the gate fallback line appears.
- Collect all three cues and talk to church_caretaker again. Confirm the resolved line fires, the journal Melody tab shows `church_bells` as a confirmed source, and fragments_found increments.
- Open the journal after resolution. Confirm the Melody tab shows fragment count 1/4 and church_bells listed.
- Start a Continue game. Confirm no cue triggers appear and the church caretaker is in resolved state.
- Start a Free Walk game. Confirm cue triggers appear and the arc plays through.

## Integration Checklist

- [ ] Place three `LandmarkTrigger` nodes in `trinity_church.tscn` — one for each cue: `steps`, `garden`, `yard`.
- [ ] For each: set `landmark_id = "trinity_church"`, `collected_progress_key = "cues_collected"`, `visible_in_states = [available, introduced, in_progress]`.
- [ ] Position each trigger node at the matching world location in the scene.
- [ ] Confirm `collision_layer` matches the layer used for inspectable objects.

## Out Of Scope

- Audio or visual effects for the chime sequence. The arc resolves via text/journal for now.
- A formal "performance beat" UI for the chime. The resolution is implicit through the dialogue beat.
- Any changes to the church scene's tile layout, roof, or doors.
- The choir student and bell repairer resident arcs (ambient residents at the church). Those are separate from the main arc.
