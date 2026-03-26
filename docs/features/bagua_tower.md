# Bagua Tower Arc

Two-step synthesis arc for the final landmark. The player climbs to the top chamber, activates the synthesis trigger, and then confirms the completed melody with Tower Keeper Suyin to claim the fourth fragment.

## Goal

- Give the player a clear climactic moment: climb high, let the phrases come together, and complete the island melody.
- Award the fourth melody fragment and advance the melody to `performed` state.
- Set up the post-arc flow toward the festival performance.

## User / Player Experience

The player arrives at Bagua Tower after Long Shan Tunnel resolves. Tower Keeper Suyin is near the lower stairs. Three conversations advance the arc:
1. Beat 0 introduces the tower's perspective-as-synthesis concept.
2. Beat 1 (once the player has at least one fragment) frames the assembly task and marks the landmark `in_progress`, making the synthesis chamber trigger visible.
3. The player climbs to the top chamber and presses R. The synthesis fires: the landmark advances to `resolved` and the objective points back to Suyin.
4. Beat 2 is gated on `synthesis_done`. Once it fires, the final fragment is awarded, the melody reaches `performed`, and the post-arc objective launches.

The mood is contemplative. There is no combat, no timer, and no scoring. The synthesis chamber is only reachable by climbing, which provides natural pacing.

## Rules

- Bagua Tower starts `locked`. It unlocks to `available` when either `_resolve_long_shan_tunnel()` fires OR `tunnel_guide` beat 2 fires `"unlock_landmark": "bagua_tower"` (whichever happens first — both paths are safe).
- `tower_keeper` beat 0 carries `"landmark_states": {"bagua_tower": "available"}` (belt-and-suspenders confirm).
- `tower_keeper` beat 1 carries `"landmark_states": {"bagua_tower": "in_progress"}`. After beat 1, the landmark is `in_progress` and the synthesis chamber trigger becomes visible at the top of the tower.

- The `synthesis_chamber` trigger is a `LandmarkTrigger` visible once the landmark is `in_progress`.
- When the player presses R at the chamber with 3+ fragments, `_resolve_bagua_tower_synthesis()` fires:
  - `landmark_progress["bagua_tower"]["synthesis_done"]` is set to `true`.
  - Landmark state advances to `resolved`.
  - Objective updates to "Return to Tower Keeper Lin to confirm the island melody."
- `tower_keeper` beat 2 is gated on `"gate": "bagua_synthesis_done"`. The gate passes once `synthesis_done` is `true`. When it fires, `"landmark_reward": "bagua_tower"` calls `_resolve_bagua_tower()`:
  - Landmark state advances to `reward_collected`.
  - `tower_synthesis` is added to `festival_melody.known_sources`.
  - `festival_melody.fragments_found` increments by 1.
  - If `fragments_found >= 4`, `festival_melody.state` advances to `performed`.
  - Objective updates to "The island melody is complete. Find the festival stage to perform it."
- Before the gate passes, beat 2 returns the `gate_fallback`: "The synthesis chamber at the top is not ready yet. Climb higher and let the phrases settle from there."
- In `Free Walk` mode, the landmark starts `available` and the arc can be played through normally.

## Edge Cases

- If the player reaches the chamber with fewer than 3 fragments, a status line reads "The tower shows distance but not yet direction. Recover more fragments first." and nothing fires.
- If `_resolve_bagua_tower()` is called more than once, `tower_synthesis` is only appended once and fragment counts are clamped to `fragments_total`.
- If the melody already has 4 fragments from a save edge case, the `performed` check still runs correctly (clamped).
- Free Walk should not advance story chapter.

## Architecture / Ownership

- `AppState` owns all landmark progress state, the synthesis logic, and the fragment reward.
- The `LandmarkTrigger` placed at the top of the tower self-manages its own visibility by subscribing to `AppState.landmark_progress_changed`.
- `LandmarkTrigger` owns its own collected state and hide/disable behavior.
- `scenes/game_main.gd` routes R-inspect on `LandmarkTrigger` nodes to `AppState.activate_landmark_trigger()`.
- `resident_catalog.gd` owns the authored beat gates and `landmark_states` fields for `tower_keeper`.
- `bagua_tower.tscn` hosts the `LandmarkTrigger` node directly; its configuration lives in its exported properties.

## Relevant Files

- Scenes:
  - [`../../architecture/bagua_tower.tscn`](../../architecture/bagua_tower.tscn)
- Scripts:
  - [`../../game/landmark_trigger.gd`](../../game/landmark_trigger.gd)
  - [`../../game/app_state.gd`](../../game/app_state.gd)
  - [`../../game/resident_catalog.gd`](../../game/resident_catalog.gd)
  - [`../../scenes/game_main.gd`](../../scenes/game_main.gd)
- Shared state or catalogs:
  - `AppState.landmark_progress["bagua_tower"]`
  - `AppState.melody_progress["festival_melody"]`
- Related docs:
  - [`../contracts.md`](../contracts.md) — Landmark Progress Contract
  - [`core_melody_loop.md`](core_melody_loop.md) — MVP Step 5 (performance point) is next after this arc
  - [`practice_system.md`](practice_system.md) — performance point design
  - [`trinity_church.md`](trinity_church.md) — beat gate pattern
  - [`../core_game_workflow.md`](../core_game_workflow.md)

## Signals / Nodes / Data Flow

- Signals emitted:
  - `AppState.landmark_progress_changed("bagua_tower", progress)` — on any state advance
  - `AppState.melody_progress_changed("festival_melody", state)` — on arc resolution
  - `AppState.fragments_changed(found, total)` — on arc resolution
- Signals consumed:
  - `AppState.landmark_progress_changed` — consumed by the `LandmarkTrigger` to self-manage visibility
- Data flow:
  - `_resolve_long_shan_tunnel()` or `tunnel_guide` beat 2 → `advance_landmark_state("bagua_tower", "available")`
  - Player talks to tower_keeper (beats 0 and 1) → `landmark_states` confirms `available` then `in_progress` → `landmark_progress_changed` → chamber trigger appears
  - Player presses R at synthesis_chamber → `activate_landmark_trigger` → `_resolve_bagua_tower_synthesis` → landmark `resolved` + `synthesis_done`
  - Player talks to tower_keeper beat 2 → gate passes → `_apply_resident_beat` → `_resolve_landmark("bagua_tower")` → `_resolve_bagua_tower` → final fragment + `performed` state

## Contracts / Boundaries

- The `"gate"`, `"gate_fallback"`, `"landmark_reward"`, and `"landmark_states"` beat fields are part of the resident beat contract.
- The `landmark_progress["bagua_tower"]` shape (`state`, `synthesis_done`) is part of the Landmark Progress Contract in `contracts.md`. Update that file if fields are added or renamed.
- `LandmarkTrigger` must not read or write `AppState` fields directly.

## Validation

- Run the game, complete the Long Shan Tunnel arc. Confirm bagua_tower advances to `available`.
- Talk to tower_keeper (beats 0 and 1). Confirm landmark advances to `in_progress` and the synthesis chamber trigger appears at the top.
- Climb to the chamber with fewer than 3 fragments. Confirm the "not yet direction" status line appears.
- Collect 3+ fragments (complete earlier arcs), climb to the chamber, press R. Confirm synthesis_done is set, landmark advances to `resolved`, and objective updates.
- Talk to tower_keeper beat 2. Confirm gate passes, final fragment is awarded, melody state is `performed`, and journal Melody tab updates.
- Talk to tower_keeper beat 2 before synthesis. Confirm gate_fallback line appears.

## Integration Checklist

- [ ] Place one `LandmarkTrigger` node in `bagua_tower.tscn`: `synthesis_chamber`.
- [ ] Set `landmark_id = "bagua_tower"`, `visible_in_states = [in_progress]`, `hide_if_flag = "synthesis_done"`.
- [ ] Position the trigger at the top chamber room in the tower.
- [x] `tower_keeper` beat 1 `"landmark_states"` uses `"in_progress"` — synthesis chamber trigger becomes visible after beat 1 fires.
- [ ] Confirm `collision_layer` matches the layer used for inspectable objects.

## Out Of Scope

- Audio or visual effects for the synthesis moment.
- The full performance point UI for the festival stage (that is MVP Step 5 in core_melody_loop.md).
- Any changes to the tower scene's staircase layout or level transitions.
- Ambient resident arcs at the tower (terrace_painter_nian, map_student_jia). Those are separate.
