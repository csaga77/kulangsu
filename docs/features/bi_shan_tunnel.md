# Bi Shan Tunnel Arc

Navigation and echo-tracing arc for the second landmark. Establishes the pickup-only arc pattern for landmarks with no story-resident gatekeeper.

## Goal

- Give the player a self-guided exploration task with no dialogue gating.
- Prove that the pickup trigger system works for landmark arcs that are driven entirely by world interaction rather than conversation.
- Award one melody fragment, mark Bi Shan as a dependable tunnel route in the journal, and point the player either toward Long Shan Tunnel or back to Ren if both tunnels are now steady.

## User / Player Experience

The player enters Bi Shan Tunnel after Trinity Church resolves. Three faint echo markers are scattered along the tunnel walls — a north-wall spot, an arch midpoint, and a mural approach near the far end. The player walks the tunnel, presses `R` at each invisible cue volume, and hears a short descriptive line as each echo is collected. Once all three are in hand, a fourth marker appears at the mural chamber at the far end. Pressing `R` at the chamber now opens a short ordered-confirmation prompt that asks the player to settle the contour they just traced. On success, the fragment is awarded, the tunnel becomes legible as a calmer cross-island route, and the journal updates to point toward Long Shan Tunnel or back to Ren if Long Shan is already complete.

In the current production runtime, those named wall and chamber beats are proxy
`StorySubject3D` hotspots arranged around the Bi Shan marker footprint. There is no authored,
walkable tunnel interior yet.

The mood stays quiet throughout. There is no timer, no failure state, and no required order for the three echo markers. The chamber trigger is simply hidden until all three echoes are collected.

## Rules

- Bi Shan Tunnel starts `locked`. It unlocks to `available` when the Trinity church reward event resolves (simultaneously with Long Shan Tunnel).
- The three echo triggers (echo_a, echo_b, echo_c) are visible and collectible once the landmark state is `available`, `introduced`, or `in_progress`.
- Each echo trigger is a `StorySubject3D` node authored under the Bi Shan marker in `game_world_3d.tscn`. Collecting one resolves through the authored StoryEvent subject `landmark:bi_shan_tunnel.<echo_id>`.
- Landmark state advances to `in_progress` on first echo collection.
- The mural chamber trigger (`trigger_id: "chamber"`) becomes visible only once all three echoes are in `echoes_collected`.
- When the player presses R at the chamber with all echoes collected, `AppState` opens the reusable ordered-confirmation prompt for the Bi Shan contour. On success, the authored `prompt_completed:bi_shan_chamber` StoryEvent binding resolves:
  - Landmark state advances to `reward_collected`.
  - `bi_shan_echo` is added to `festival_melody.known_sources`.
  - `festival_melody.fragments_found` increments by 1.
  - `festival_melody.state` updates to `heard` (1 fragment) or `reconstructed` (2+).
  - `bi_shan_crossing` is added to `AppState.open_shortcuts` as a journal-facing route note.
  - Objective updates to point toward Long Shan Tunnel's lit-pocket route, or back to Ren if both tunnels can now be compared.
- Echo triggers and the chamber trigger hide themselves after collection. The controller re-hides all triggers when the landmark state is `resolved` or `reward_collected`.
- In `Free Walk` mode, the landmark starts `available` and the arc can be played through normally.
- In `Continue` mode, the landmark starts `available` with no echoes collected — the arc is playable from the top.

## Edge Cases

- If the player reaches the chamber before collecting all three echoes, a status line reads "The mural panel is silent. Trace the three tunnel echoes first." and nothing advances.
- If an already-collected echo subject is activated again, the authored StoryEvent binding resolves to a no-op.
- If the Bi Shan chamber reward event is applied more than once, `bi_shan_echo` is only appended once and fragment counts stay clamped to `fragments_total`.
- Free Walk should not advance story chapter. Currently it does advance landmark state on resolve — this is acceptable in sandbox mode.

## Architecture / Ownership

- `AppState` owns the shared landmark progress state and the public trigger bridge.
- `game/story_event_catalog.gd` and `game/story_event_service.gd` now own Bi Shan echo collection, the chamber prompt-open interaction, and the `prompt_completed:bi_shan_chamber` reward follow-through.
- `game/landmark_progression.gd` now mainly supplies the generic melody prompt builder and compatibility fallback behind that flow.
- `scenes/game_world_3d.tscn` owns the current Bi Shan marker anchor and its reusable echo/chamber
  world subjects. There is no production `bi_shan_tunnel.tscn`, interior level, or tunnel parent.
- The current marker-based gap and the ownership contract for a future authored interior are
  documented in [`multi_level_spaces.md`](multi_level_spaces.md).

## Relevant Files

- Scenes:
  - [`../../scenes/game_world_3d.tscn`](../../scenes/game_world_3d.tscn)
  - [`../../terrain/low_poly_terrain_3d.gd`](../../terrain/low_poly_terrain_3d.gd)
- Scripts:
  - [`../../game/story_subject_3d.gd`](../../game/story_subject_3d.gd)
  - [`../../game/app_state.gd`](../../game/app_state.gd)
  - [`../../scenes/game_world_3d.gd`](../../scenes/game_world_3d.gd)
- Shared state or catalogs:
  - `AppStateSnapshot.landmark_progress["bi_shan_tunnel"]`, exposed to consumers by `AppStateProjection`
  - `AppStateSnapshot.melody_progress["festival_melody"]`, exposed to consumers by `AppStateProjection`
- Related docs:
  - [`../contracts.md`](../contracts.md) — Landmark Progress Contract
  - [`core_melody_loop.md`](core_melody_loop.md)
  - [`multi_level_spaces.md`](multi_level_spaces.md) — current marker-based gap and future 3D
    tunnel-space contract
  - [`trinity_church.md`](trinity_church.md) — arc pattern this one follows
  - [`../core_game_workflow.md`](../core_game_workflow.md)

## Signals / Nodes / Data Flow

- Signals emitted:
  - one `AppState.state_committed(changes)` containing `LANDMARKS` for echo/state changes and `MELODY` when the arc awards melody progress
- Signals consumed:
  - `StorySubject3D` listens to `state_committed` and refreshes its StoryEvent presence from the latest projection
- Data flow:
  - Trinity reward event resolves → `advance_landmark_state("bi_shan_tunnel", "available")` → StoryEvent presence rules show echo subjects
  - Player presses R near an echo → `StoryInteractionCoordinator` selects the scene-local `StorySubject3D` and builds its context → `AppState.activate_story_subject(...)` → authored Bi Shan echo binding updates `echoes_collected` → one `state_committed`
  - All echoes collected → chamber trigger appears → player presses R at chamber → `StorySubject3D` builds subject context → `AppState.activate_story_subject(...)` → authored Bi Shan chamber binding emits the prompt request → `complete_prompt_request(...)` → `StoryEventService.notify_world_event("prompt_completed:bi_shan_chamber", ...)` → melody and landmark state update

## Contracts / Boundaries

- The `landmark_progress["bi_shan_tunnel"]` shape (`state`, `echoes_collected`) is part of the Landmark Progress Contract in `contracts.md`. Update that file if fields are added or renamed.
- `StorySubject3D` must not read or write `AppState` fields directly; it uses the public API and shared StoryEvent metadata.

## Validation

- Run the game, start a New Game, complete the Trinity Church arc. Confirm bi_shan_tunnel advances
  to `available` and the three echo proxy subjects appear around the Bi Shan marker route.
- Walk to each proxy echo position and press R. Confirm each one disappears and the chamber proxy
  appears after the third.
- Press R at the chamber. Confirm the prompt opens before the arc resolves, then complete it and confirm the journal Melody tab shows `bi_shan_echo` as a confirmed source and fragments_found increments.
- Open the journal Map tab after the chamber resolves. Confirm `Bi Shan Tunnel Route` appears under `Dependable routes`.
- Press R at the chamber before collecting all echoes. Confirm the "silent panel" status line appears and nothing advances.
- Start a Continue game. Confirm echo triggers are visible (echoes_collected is empty) and the arc is playable.
- Start a Free Walk game. Confirm echo triggers appear and the arc plays through.
- If a future authored tunnel space, portal, or traversal component changes, also run the focused
  validation required by [`multi_level_spaces.md`](multi_level_spaces.md).

## Integration Checklist

- [x] Place four `StorySubject3D` nodes under the Bi Shan marker in `game_world_3d.tscn` for the tunnel arc: `echo_a`, `echo_b`, `echo_c`, and `chamber`.
- [x] For echo triggers: set `subject_id` to the authored StoryEvent subjects (`landmark:bi_shan_tunnel.echo_a`, `...echo_b`, `...echo_c`).
- [x] For the chamber trigger: set `subject_id = "landmark:bi_shan_tunnel.chamber"` and keep the echo prerequisite / visibility rules in StoryEvent subject metadata.
- [x] Position each trigger node at its story-space proxy location around the marker footprint;
  these positions do not claim authored interior geometry.

## Out Of Scope

- Audio or visual effects for echo resonance. The arc resolves via text/journal for now.
- Authored tunnel geometry or lighting; the current production representation is marker-based.
- Ambient resident arcs inside the tunnel (echo_sketcher_yan, mural_restorer_cai, etc.). Those are separate from the main arc.
