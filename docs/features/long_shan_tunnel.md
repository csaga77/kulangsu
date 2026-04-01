# Long Shan Tunnel Arc

Escort-style arc for the third landmark. The player accompanies Tunnel Guide Ren through the tunnel and exits at the north mouth to complete the arc.

## Goal

- Give the player a paced traversal task where staying on the lit route with a resident matters emotionally, even without true NPC-follow AI.
- Award one melody fragment on exit and unlock Bagua Tower.
- Establish the pattern for arcs driven by a mix of resident dialogue beats and world trigger checkpoints.

## User / Player Experience

The player arrives at Long Shan Tunnel after Trinity Church resolves. Tunnel Guide Ren is near the south entrance. The first conversation asks the player to walk a calm route and stop when the light thins. A second beat reinforces the rhythm. Once the player has talked to Ren twice (landmark is `in_progress`), two invisible lit-pocket checkpoints become available in sequence before the north exit can resolve. Reaching both pockets and then the exit completes the crossing: the fragment is awarded, the journal updates, and the objective points back to Ren for the actual Bagua Tower handoff.

The tone stays quiet. There is no timer, no NPC pathfinding, and no failure state. "Escort" here means the player traverses the tunnel while a resident's words stay with them — it is a mood and a framing, not a mechanical chase.

When the player properly enters the tunnel interior, the surface ground/building layer should hide so the tunnel art and tunnel residents read as the active space. Walking across the tunnel footprint on the surface must not reveal those tunnel-only residents.

## Rules

- Long Shan Tunnel starts `locked`. It unlocks to `available` when `_resolve_trinity_church()` fires (simultaneously with Bi Shan Tunnel).
- The `tunnel_entry` trigger is a `LandmarkTrigger` visible once state is `available`. Reaching it calls `AppState.activate_landmark_trigger("long_shan_tunnel", "tunnel_entry", ...)`. AppState advances the landmark to `introduced`.
- `tunnel_guide` beat 0 fires when the player talks to Ren. Beat 0 carries `"landmark_states": {"long_shan_tunnel": "introduced"}` which confirms the landmark state (may already be introduced by the entry trigger — either order is safe).
- `tunnel_guide` beat 1 fires on the next interaction. Beat 1 carries `"landmark_states": {"long_shan_tunnel": "in_progress"}`.
- Two intermediate lit-pocket triggers (`light_pocket_south`, `light_pocket_north`) become visible once the landmark is `in_progress`.
  - `light_pocket_north` requires `light_pocket_south`.
  - Both write into `landmark_progress["long_shan_tunnel"]["checkpoints_collected"]`.
- The `tunnel_exit` trigger becomes visible once the landmark is `in_progress`. Reaching it calls `AppState.activate_landmark_trigger("long_shan_tunnel", "tunnel_exit", ...)`. AppState only resolves the arc after both lit pockets have been collected:
  - Landmark state advances to `reward_collected`.
  - `long_shan_route` is confirmed in `festival_melody.known_sources`.
  - `festival_melody.fragments_found` increments by 1 as its own third fragment.
  - `festival_melody.state` updates to `heard` or `reconstructed`.
  - Objective updates to point back to Tunnel Guide Ren.
- `tunnel_guide` beat 2 is gated on `"gate": "long_shan_exit_reached"`. It only fires once the landmark is `reward_collected`. It carries `"unlock_landmark": "bagua_tower"` and is the beat that actually opens the tower route.
- Before the gate passes, beat 2 returns the `gate_fallback` line: "The passage is not done yet. Stay close and keep moving toward the exit."
- In `Free Walk` mode, the landmark starts `available` and the arc can be played through normally.
- In `Continue` mode, the landmark starts `available` — the player can walk the escort arc fresh.

## Edge Cases

- If the player reaches the exit before talking to Ren twice (state not `in_progress`), a status line reads "Tunnel exit reached — talk to Tunnel Guide Ren before crossing." and nothing resolves.
- If the player reaches the exit before touching both lit pockets, a status line reads "The route is still uneven. Pause with Ren at the lit pockets before crossing." and nothing resolves.
- If the player talks to Ren before hitting the entry trigger, beat 0's `landmark_states` field still advances the landmark to `introduced` — the entry trigger is then redundant but harmless.
- If the player reaches the exit correctly but does not talk to Ren afterward, Bagua Tower stays locked and the objective still points back to him.
- If `_resolve_long_shan_tunnel()` is called more than once, `long_shan_route` is only confirmed once and fragment counts are clamped.
- Free Walk should not advance story chapter. The Bagua unlock still routes through Ren's post-exit beat in Free Walk — this is acceptable in sandbox mode.

## Architecture / Ownership

- `AppState` owns all landmark progress state, the lit-pocket checkpoint logic, the exit resolution logic, and the fragment reward.
- Each `LandmarkTrigger` placed in the scene self-manages its own visibility by subscribing to `AppState.landmark_progress_changed`.
- `LandmarkTrigger` owns its own collected state and hide/disable behavior.
- `scenes/game_main.gd` routes R-inspect on `LandmarkTrigger` nodes to `AppState.activate_landmark_trigger()`.
- `tunnel.gd`, `auto_visibility_node_2d.gd`, and `scenes/game_main.gd` together own the tunnel-only presentation rule: player interior entry hides the surface layer, while routed tunnel residents can move in and out and only remain visible when the player shares that tunnel context.
- `resident_catalog.gd` owns the authored beat gates and `landmark_states` fields for `tunnel_guide`.
- `long_shan_tunnel.tscn` hosts the `LandmarkTrigger` nodes directly; their configuration lives in their exported properties.

## Relevant Files

- Scenes:
  - [`../../architecture/long_shan_tunnel.tscn`](../../architecture/long_shan_tunnel.tscn)
- Scripts:
  - [`../../game/landmark_trigger.gd`](../../game/landmark_trigger.gd)
  - [`../../game/app_state.gd`](../../game/app_state.gd)
  - [`../../game/resident_catalog.gd`](../../game/resident_catalog.gd)
  - [`../../scenes/game_main.gd`](../../scenes/game_main.gd)
- Shared state or catalogs:
  - `AppState.landmark_progress["long_shan_tunnel"]`
  - `AppState.melody_progress["festival_melody"]`
- Related docs:
  - [`../contracts.md`](../contracts.md) — Landmark Progress Contract
  - [`core_melody_loop.md`](core_melody_loop.md)
  - [`trinity_church.md`](trinity_church.md) — beat gate pattern
  - [`../core_game_workflow.md`](../core_game_workflow.md)

## Signals / Nodes / Data Flow

- Signals emitted:
- `AppState.landmark_progress_changed("long_shan_tunnel", progress)` — on state advance and lit-pocket collection
  - `AppState.melody_progress_changed("festival_melody", state)` — on arc resolution
  - `AppState.fragments_changed(found, total)` — on arc resolution
- Signals consumed:
  - `AppState.landmark_progress_changed` — consumed by each `LandmarkTrigger` to self-manage visibility
- Data flow:
- `_resolve_trinity_church()` fires → `advance_landmark_state("long_shan_tunnel", "available")` → `LandmarkTrigger._on_landmark_progress_changed` shows entry trigger
- Player reaches entry trigger → `activate_landmark_trigger` → `advance_landmark_state("long_shan_tunnel", "introduced")` → entry trigger hides
- Player talks to tunnel_guide (beats 0 and 1) → `landmark_states` fields confirm `introduced` then `in_progress` → `landmark_progress_changed` → lit-pocket and exit triggers appear
- Player reaches both lit pockets → `activate_landmark_trigger` → `checkpoints_collected` updates
- Player reaches exit trigger → `_resolve_long_shan_tunnel` → melody + landmark state update + objective points back to Ren
- Player talks to tunnel_guide beat 2 → gate passes → `unlock_landmark = "bagua_tower"`

## Contracts / Boundaries

- The `"gate"`, `"gate_fallback"`, `"unlock_landmark"`, and `"landmark_states"` beat fields are part of the resident beat contract. If renamed or removed, update `contracts.md` and `_apply_resident_beat`.
- The `landmark_progress["long_shan_tunnel"]` shape (`state`, `checkpoints_collected`) is part of the Landmark Progress Contract in `contracts.md`.
- `LandmarkTrigger` must not read or write `AppState` fields directly.

## Validation

- Run the game, complete the Trinity Church arc. Confirm long_shan_tunnel advances to `available` and the entry trigger appears near the south entrance.
- Walk to the entry trigger. Confirm the landmark advances to `introduced`.
- Talk to tunnel_guide twice. Confirm landmark advances to `in_progress`, the lit-pocket checkpoints appear in sequence, and the exit is now the final step.
- Press R at the two lit pockets, then the tunnel_exit trigger. Confirm the arc resolves, journal updates, and the objective points back to Ren instead of directly to Bagua.
- Talk to Ren after the exit resolves. Confirm his next beat opens Bagua Tower.
- Try talking to tunnel_guide at beat 2 before reaching the exit. Confirm the gate_fallback line appears.
- Start a Continue game. Confirm the arc is accessible (state: available, entry trigger visible).
- Enter the tunnel through a mouth and walk inside. Confirm the surface ground/building layer hides and tunnel residents appear.
- Move over the same tunnel footprint on the surface without entering the tunnel interior. Confirm the surface layer stays visible and tunnel residents stay hidden.

## Integration Checklist

- [x] Place four `LandmarkTrigger` nodes in `long_shan_tunnel.tscn`: `tunnel_entry`, `light_pocket_south`, `light_pocket_north`, and `tunnel_exit`.
- [x] For `tunnel_entry`: set `landmark_id = "long_shan_tunnel"`, `visible_in_states = [available]`.
- [x] For the lit-pocket cues: set `landmark_id = "long_shan_tunnel"`, `visible_in_states = [in_progress]`, `collected_progress_key = "checkpoints_collected"`, and gate the north pocket behind the south pocket.
- [x] For `tunnel_exit`: set `landmark_id = "long_shan_tunnel"`, `visible_in_states = [in_progress]`.
- [x] Position each trigger at the south mouth, two interior lit pockets, and the north mouth respectively.
- [x] Confirm `collision_layer` matches the layer used for inspectable objects.

## Out Of Scope

- True NPC-follow AI for the escort. The current version is trigger-based.
- Audio or visual effects for the passage completion.
- Any changes to the tunnel scene's tile layout or lighting.
- Ambient resident arcs inside the tunnel (raincoat_child_xiu, storyteller_wen, etc.). Those are separate.
