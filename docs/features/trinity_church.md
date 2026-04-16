# Trinity Church Arc

The first complete landmark loop. Establishes the quest plumbing pattern that Bi Shan Tunnel, Long Shan Tunnel, and Bagua Tower will reuse.

## Goal

- Give the player a concrete, low-pressure task with a clear start, solve, and reward.
- Prove the landmark quest state machine, pickup trigger system, and melody fragment award end-to-end.
- Set the template for the remaining three landmark arcs.

## User / Player Experience

The player arrives at Trinity Church after Caretaker Lian at the ferry points them there. Choir Caretaker Mei explains that three choir cues have scattered across the church grounds. The player walks the grounds, presses `R` at three invisible cue volumes placed at the front steps, the side garden, and the quiet yard, and collects each cue in that authored order. Once all three are in hand, the player must settle them together at a choir-chime performance point near the steps. Only after that short confirmation does Mei resolve the arc: the phrase settles, the fragment is awarded, and the journal updates to point toward the tunnels. The church caretaker's ambient lines change after resolution.

The mood should stay calm throughout. There is no timer and no hard fail state. The cue order is authored through trigger visibility rather than punishment: the next cue only appears once the previous one has been collected.

## Rules

- Trinity Church starts `locked`. It unlocks to `available` when the `ferry_caretaker` fires her first dialogue beat (`"unlock_landmark": "trinity_church"`).
- The three choir cue triggers (steps, garden, yard) are invisible `StorySubjectArea2D` volumes that become collectible once the landmark state and StoryEvent presence rules allow them.
- Each cue is a `StorySubjectArea2D` node authored inside `trinity_church.tscn`. Collecting one resolves through the authored StoryEvent subject `landmark:trinity_church.<cue_id>`.
- Cue order is authored in StoryEvent conditions against those reusable scene-owned subject ids:
  - `steps` has no prerequisite.
  - `garden` requires `steps`.
  - `yard` requires `steps` and `garden`.
- Each cue's authored StoryEvent effect emits one short `melody_hint` line when collected (e.g. "A low bell tone echoes from the old stone steps..."). This gives the player incremental melody feedback during the pickup walk without pushing melody-only text into `StorySubjectArea2D`.
- Landmark state advances to `in_progress` on first cue collection.
- After the third cue, `AppState` emits one extra chime-flavoured `melody_hint` and redirects the objective to the `choir_chime` trigger near the steps.
- The choir chime is its own `StorySubjectArea2D` node. It only becomes usable once `steps`, `garden`, and `yard` are all present in `cues_collected`.
- Pressing `R` at the choir chime opens the reusable ordered-confirmation prompt with the authored order `steps -> garden -> yard`.
- When the prompt succeeds, the authored `prompt_completed:trinity_chime` StoryEvent binding:
  - sets `landmark_progress["trinity_church"]["chime_performed"] = true`
  - advances the landmark to `resolved`
  - redirects the objective back to Mei
- The church_caretaker's resolved dialogue beat (beat index 2) now has `"gate": "trinity_church_chime"`. It only fires after the choir chime prompt succeeds. Before that, she responds with the gate fallback line.
- When the gate passes and the resolved beat fires, `"landmark_reward": "trinity_church"` routes through the authored `landmark_reward:trinity_church` StoryEvent binding:
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
- If the player collects all three cues without ever talking to church_caretaker, the objective updates to the choir chime first, then back to Mei after the prompt succeeds.
- If `activate_landmark_trigger` is called with an already-collected cue_id, it is a no-op.
- If the player presses `R` at the choir chime before all three cues are collected, a status line explains that the phrase still needs every choir cue.
- If the church reward event is applied more than once (e.g. due to a save/load edge case), `church_bells` is only appended once and fragment counts stay clamped to `fragments_total`.
- Free Walk should not advance story chapter or set tunnel states differently. Currently it does advance `bi_shan_tunnel` and `long_shan_tunnel` to `available` on resolve — this is acceptable in sandbox mode.

## Architecture / Ownership

- `AppState` owns the shared landmark progress state and the public interaction bridge.
- `game/story_event_catalog.gd` and `game/story_event_service.gd` now own Trinity's cue collection logic, choir-chime prompt request, `prompt_completed:trinity_chime`, and the downstream `landmark_reward:trinity_church` resolution flow as authored StoryEvent bindings.
- `game/landmark_progression.gd` now mainly supplies the generic melody prompt builder plus compatibility fallbacks for any unmigrated prompt/reward path.
- Each `StorySubjectArea2D` under the packed `TrinityChurch` scene resolves visibility through StoryEvent metadata and shared story-state signals.
- `scenes/game_main.gd` routes R-inspect on church world subjects through the shared `activate_story_subject(...)` path.
- `resident_catalog.gd` owns the authored beat gates and landmark reward keys for church_caretaker and ferry_caretaker.
- `ui/screens/melody_prompt_overlay.*` provides the shared confirmation UI used by the choir chime and later melody performances.
- `trinity_church.tscn` owns both the church presentation and the reusable cue/chime world subjects for that landmark.
- `trinity_church.tscn` hosts the controller as a child node. No logic lives in the scene file itself.

## Relevant Files

- Scenes:
  - [`../../architecture/trinity_church.tscn`](../../architecture/trinity_church.tscn)
  - [`../../terrain/terrain.tscn`](../../terrain/terrain.tscn)
- Scripts:
  - [`../../game/story_subject_area.gd`](../../game/story_subject_area.gd)
  - [`../../game/app_state.gd`](../../game/app_state.gd)
  - [`../../game/story_event_catalog.gd`](../../game/story_event_catalog.gd)
  - [`../../game/story_event_service.gd`](../../game/story_event_service.gd)
  - [`../../game/landmark_progression.gd`](../../game/landmark_progression.gd)
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
  - `AppState.melody_hint_shown(text)` — on each cue collection (emitted by the authored cue-collection StoryEvent effects)
  - `AppState.melody_prompt_requested(request)` — when the choir chime is activated after all three cues are found
  - `AppState.melody_progress_changed("festival_melody", state)` — on Mei's final arc resolution
  - `AppState.fragments_changed(found, total)` — on arc resolution (via set_melody_progress)
- Signals consumed:
  - `AppState.landmark_progress_changed` — consumed by each `StorySubjectArea2D` through StoryEvent presence sync
- Data flow:
  - `ferry_caretaker` beat 0 fires → `_apply_resident_beat` reads `"unlock_landmark": "trinity_church"` → `advance_landmark_state("trinity_church", "available")` → StoryEvent presence rules show cue subjects
  - Player presses R near a cue → `scenes/game_main.gd._on_inspect_requested` → `StorySubjectArea2D` builds subject context → `AppState.activate_story_subject(...)` → authored Trinity cue binding applies shared landmark-progress effects → `landmark_progress_changed`
  - Player presses R at `ChoirChime` after all cues are found → `StorySubjectArea2D` builds subject context → `AppState.activate_story_subject(...)` → authored Trinity choir-chime binding emits `melody_prompt_requested`
  - Prompt succeeds → `AppState.complete_prompt_request(...)` → `StoryEventService.notify_world_event("prompt_completed:trinity_chime", ...)` → authored Trinity completion binding returns the objective to Mei
  - Player presses R on church_caretaker after the chime settles → `interact_with_resident` → gate passes → beat fires → `_apply_resident_beat` reads `"landmark_reward": "trinity_church"` → `StoryEventService.notify_world_event("landmark_reward:trinity_church", ...)` → melody and landmark state update

## Contracts / Boundaries

- The `"gate"`, `"gate_fallback"`, `"unlock_landmark"`, and `"landmark_reward"` beat fields are part of the resident beat contract. If they are renamed or removed, update `contracts.md` and `_apply_resident_beat`.
- The `landmark_progress["trinity_church"]` shape (`state`, `cues_collected`, `chime_performed`) is part of the Landmark Progress Contract in `contracts.md`. Update that file if fields are added or renamed.
- `StorySubjectArea2D` must not read or write `AppState` fields directly; it uses the public API and shared StoryEvent metadata.

## Validation

- Run the game, start a New Game, talk to Caretaker Lian. Confirm trinity_church advances to `available` and the steps cue is the first one available near the church.
- Walk to each cue and press R. Confirm the garden cue waits for the steps cue, the yard cue waits for steps plus garden, and the objective/hint updates after the third.
- Press `R` at the choir chime after collecting all three cues. Confirm the ordered prompt opens and the landmark only advances to `resolved` after a correct order.
- Talk to church_caretaker before collecting all cues. Confirm the gate fallback line appears.
- Collect all three cues, complete the choir chime, and talk to church_caretaker again. Confirm the resolved line fires, the journal Melody tab shows `church_bells` as a confirmed source, and fragments_found increments.
- Open the journal after resolution. Confirm the Melody tab shows fragment count 1/4 and church_bells listed.
- Start a Continue game. Confirm no cue triggers appear and the church caretaker is in resolved state.
- Start a Free Walk game. Confirm cue triggers appear and the arc plays through.

## Integration Checklist

- [x] Place three `StorySubjectArea2D` nodes in `trinity_church.tscn` — one for each cue: `steps`, `garden`, `yard`.
- [x] Place one `StorySubjectArea2D` node in `trinity_church.tscn` for `choir_chime`, gated behind all three cue ids.
- [x] For each: set `subject_id` to the authored StoryEvent subject (`landmark:trinity_church.steps`, `...garden`, `...yard`, `...choir_chime`).
- [x] Keep collection order and visibility rules in `game/story_event_catalog.gd` subject metadata instead of per-node exports.
- [ ] Position each trigger node at the matching world location in the scene.
- [x] Confirm `collision_layer` matches the layer used for inspectable objects.

## Out Of Scope

- A bespoke visual marker for choir cues. The current implementation intentionally keeps cues invisible and relies on proximity prompts plus melody-hint text.
- A bespoke church-only minigame. The current implementation intentionally reuses the shared ordered-confirmation prompt.
- Any changes to the church scene's tile layout, roof, or doors.
- The choir student and bell repairer resident arcs (ambient residents at the church). Those are separate from the main arc.
