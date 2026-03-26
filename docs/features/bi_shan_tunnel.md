# Bi Shan Tunnel Arc

Navigation and echo-tracing arc for the second landmark. Establishes the pickup-only arc pattern for landmarks with no story-resident gatekeeper.

## Goal

- Give the player a self-guided exploration task with no dialogue gating.
- Prove that the pickup trigger system works for landmark arcs that are driven entirely by world interaction rather than conversation.
- Award one melody fragment and open the Long Shan Tunnel as the next destination.

## User / Player Experience

The player enters Bi Shan Tunnel after Trinity Church resolves. Three faint echo markers are scattered along the tunnel walls — a north-wall spot, an arch midpoint, and a mural approach near the far end. The player walks the tunnel, presses R at each glowing marker, and hears a short descriptive line as each echo is collected. Once all three are in hand, a fourth marker appears at the mural chamber at the far end. Pressing R at the chamber resolves the arc: the mural panel responds, the fragment is awarded, and the journal updates to point toward Long Shan Tunnel.

The mood stays quiet throughout. There is no timer, no failure state, and no required order for the three echo markers. The chamber trigger is simply hidden until all three echoes are collected.

When the player enters through a tunnel mouth and reaches the tunnel interior, the surface ground/building layer should hide so the tunnel graphics and tunnel residents read cleanly. Walking over the same footprint on the surface must not trigger that tunnel-only presentation.

## Rules

- Bi Shan Tunnel starts `locked`. It unlocks to `available` when `_resolve_trinity_church()` fires (simultaneously with Long Shan Tunnel).
- The three echo triggers (echo_a, echo_b, echo_c) are visible and collectible once the landmark state is `available`, `introduced`, or `in_progress`.
- Each echo trigger is a `LandmarkTrigger` node placed directly in the scene. Collecting one calls `AppState.activate_landmark_trigger("bi_shan_tunnel", echo_id, display_name)`.
- Landmark state advances to `in_progress` on first echo collection.
- The mural chamber trigger (`trigger_id: "chamber"`) becomes visible only once all three echoes are in `echoes_collected`.
- When the player presses R at the chamber with all echoes collected, `_resolve_bi_shan_tunnel()` fires:
  - Landmark state advances to `reward_collected`.
  - `tunnel_echo` is added to `festival_melody.known_sources`.
  - `festival_melody.fragments_found` increments by 1.
  - `festival_melody.state` updates to `heard` (1 fragment) or `reconstructed` (2+).
  - Objective updates to point toward Long Shan Tunnel.
- Echo triggers and the chamber trigger hide themselves after collection. The controller re-hides all triggers when the landmark state is `resolved` or `reward_collected`.
- In `Free Walk` mode, the landmark starts `available` and the arc can be played through normally.
- In `Continue` mode, the landmark starts `introduced` with no echoes collected — the arc is playable from the top.

## Edge Cases

- If the player reaches the chamber before collecting all three echoes, a status line reads "The mural panel is silent. Trace the three tunnel echoes first." and nothing advances.
- If `_collect_bi_shan_echo` is called with an already-collected echo_id, it is a no-op. The `LandmarkTrigger.collect()` guard also prevents double-collection.
- If `_resolve_bi_shan_tunnel()` is somehow called more than once, `tunnel_echo` is only appended once (guarded by `find` check) and fragment counts are clamped to `fragments_total`.
- Free Walk should not advance story chapter. Currently it does advance landmark state on resolve — this is acceptable in sandbox mode.

## Architecture / Ownership

- `AppState` owns all landmark progress state, the echo collection logic, and the fragment reward.
- Each `LandmarkTrigger` placed in the scene self-manages its own visibility by subscribing to `AppState.landmark_progress_changed`.
- `LandmarkTrigger` owns its own collected state and hide/disable behavior.
- `scenes/game_main.gd` routes R-inspect on `LandmarkTrigger` nodes to `AppState.activate_landmark_trigger()`.
- `tunnel.gd`, `auto_visibility_node_2d.gd`, and `scenes/game_main.gd` together own the tunnel-only presentation rule: player interior entry hides the surface layer, while tunnel residents only appear when the player shares that tunnel context.
- `bi_shan_tunnel.tscn` hosts the `LandmarkTrigger` nodes directly; their configuration lives in their exported properties.

## Relevant Files

- Scenes:
  - [`../../architecture/bi_shan_tunnel.tscn`](../../architecture/bi_shan_tunnel.tscn)
- Scripts:
  - [`../../game/landmark_trigger.gd`](../../game/landmark_trigger.gd)
  - [`../../game/app_state.gd`](../../game/app_state.gd)
  - [`../../scenes/game_main.gd`](../../scenes/game_main.gd)
- Shared state or catalogs:
  - `AppState.landmark_progress["bi_shan_tunnel"]`
  - `AppState.melody_progress["festival_melody"]`
- Related docs:
  - [`../contracts.md`](../contracts.md) — Landmark Progress Contract
  - [`core_melody_loop.md`](core_melody_loop.md)
  - [`trinity_church.md`](trinity_church.md) — arc pattern this one follows
  - [`../core_game_workflow.md`](../core_game_workflow.md)

## Signals / Nodes / Data Flow

- Signals emitted:
  - `AppState.landmark_progress_changed("bi_shan_tunnel", progress)` — on any echo collection or state advance
  - `AppState.melody_progress_changed("festival_melody", state)` — on arc resolution
  - `AppState.fragments_changed(found, total)` — on arc resolution (via set_melody_progress)
- Signals consumed:
  - `AppState.landmark_progress_changed` — consumed by each `LandmarkTrigger` to self-manage visibility
- Data flow:
  - `_resolve_trinity_church()` fires → `advance_landmark_state("bi_shan_tunnel", "available")` → `LandmarkTrigger._on_landmark_progress_changed` shows echo triggers
  - Player presses R near an echo → `scenes/game_main.gd._on_inspect_requested` → `AppState.activate_landmark_trigger` → `_collect_bi_shan_echo` → `landmark_progress_changed`
  - All echoes collected → chamber trigger appears → player presses R at chamber → `activate_landmark_trigger` with `trigger_id == "chamber"` → `_resolve_bi_shan_tunnel` → melody and landmark state update

## Contracts / Boundaries

- The `landmark_progress["bi_shan_tunnel"]` shape (`state`, `echoes_collected`) is part of the Landmark Progress Contract in `contracts.md`. Update that file if fields are added or renamed.
- `LandmarkTrigger` must not read or write `AppState` fields directly; it uses the public API (`get_landmark_progress`, `landmark_progress_changed`).

## Validation

- Run the game, start a New Game, complete the Trinity Church arc. Confirm bi_shan_tunnel advances to `available` and the three echo triggers appear inside the tunnel.
- Walk to each echo and press R. Confirm each one disappears and the mural chamber trigger appears after the third.
- Press R at the chamber. Confirm the arc resolves, the journal Melody tab shows `tunnel_echo` as a confirmed source, and fragments_found increments.
- Press R at the chamber before collecting all echoes. Confirm the "silent panel" status line appears and nothing advances.
- Start a Continue game. Confirm echo triggers are visible (echoes_collected is empty) and the arc is playable.
- Start a Free Walk game. Confirm echo triggers appear and the arc plays through.
- Enter the tunnel properly through a mouth and walk inside. Confirm the surface ground/building layer hides and tunnel residents appear.
- Move across the same tunnel footprint on the surface without entering the tunnel interior. Confirm the surface layer stays visible and tunnel residents stay hidden.

## Integration Checklist

- [x] Place four `LandmarkTrigger` nodes in `bi_shan_tunnel.tscn`: `echo_a`, `echo_b`, `echo_c`, and `chamber`.
- [x] For echo triggers: set `landmark_id = "bi_shan_tunnel"`, `collected_progress_key = "echoes_collected"`, `visible_in_states = [available, introduced, in_progress]`.
- [x] For the chamber trigger: same `landmark_id`, `requires_collected = [echo_a, echo_b, echo_c]`, `collected_progress_key = "echoes_collected"`, `visible_in_states = [in_progress]`.
- [x] Position each trigger node at the matching world location in the tunnel.
- [x] Confirm `collision_layer` matches the layer used for inspectable objects.

## Out Of Scope

- Audio or visual effects for echo resonance. The arc resolves via text/journal for now.
- Any changes to the tunnel scene's tile layout or lighting.
- Ambient resident arcs inside the tunnel (echo_sketcher_yan, mural_restorer_cai, etc.). Those are separate from the main arc.
