# NPC System

Read this file first when the task is specifically about residents, NPC dialogue, resident spawning, or resident journal behavior.

## Quick Start For Future Agents

Open these files first in this order:

1. [`../../game/resident_catalog.gd`](../../game/resident_catalog.gd)
2. [`../../game/app_state.gd`](../../game/app_state.gd)
3. [`../../scenes/game_main.gd`](../../scenes/game_main.gd)
4. [`../../characters/control/npc_controller.gd`](../../characters/control/npc_controller.gd)
5. [`../../ui/screens/journal_overlay.gd`](../../ui/screens/journal_overlay.gd)

Use [`../npc_system_design.md`](../npc_system_design.md) only when you need the broader design rationale after reading this summary.

## Goal

- Give Kulangsu a reusable resident system that keeps NPC content data-driven instead of scattering dialogue and presentation rules across scenes.
- Let residents drive objectives, local atmosphere, and journal notes without requiring a full dialogue UI for every interaction.

## User / Player Experience

- The player can approach residents across the island and see a contextual `Talk` prompt instead of a generic inspect prompt.
- Residents show a simple `...` bubble while the player is in talk range, then reveal the current talk line when the player presses `R`.
- The journal records resident notes that explain who a person is, where they are found, and what lead they currently provide.
- The main overworld feels populated because the current resident roster is spawned across the ferry, church, tunnel entrances, and Bagua Tower.

## Rules

- Resident authoring lives in one catalog and each resident id must appear in the catalog order list.
- Each resident entry owns identity, landmark context, ambient lines, dialogue beats, appearance preset, and spawn metadata.
- Ambient lines must stay short enough for speech balloons.
- Talk beats may update objective, chapter, save status, trust, and resident journal state through `AppState`.
- Resident talk progression is linear right now. `conversation_index` advances through the resident's `dialogue_beats`.
- Nearby resident bubbles should default to `...` until explicit talk input reveals a line.
- Residents should only be targetable when the player shares the same absolute z/layer context.
- Residents should only be visible and targetable when they share the player's current tunnel context: both outside, or inside the same tunnel after actually entering its interior level rather than merely overlapping the tunnel footprint on the surface.
- Player tunnel context is intentionally stricter than resident tunnel reacquisition: the player must reach the tunnel interior level, while routed residents may reacquire tunnel level/visibility from tunnel geometry as they move back in.
- If a resident and a collectible landmark trigger overlap in range, the resident should win the closest-target selection so `Talk` stays reliable.
- Residents may stay stationary or follow authored route points; routed tunnel residents should still pause for nearby talk and use the same tunnel visibility rules as the player.
- Player and resident actors must stay under the same y-sorted actor layer in the main scene so character overlap reads correctly.

## Current Authoring Model

- The source of truth for which residents exist is `ResidentCatalog.resident_order()`.
- Story residents live in `ResidentCatalog._story_residents()`.
- Ambient residents live in `ResidentCatalog._ambient_residents()`.
- `AppState` builds runtime resident profiles from the catalog defaults and exposes the getters the rest of the game uses.
- `scenes/game_main.gd` never hardcodes individual residents; it loops over `AppState.get_resident_ids()` and spawns them from catalog metadata.
- Tunnel-root spawns and tunnel-owned movement waypoints are snapped back onto the authored tunnel path if an offset drifts off the walkable area.
- `NPCController` uses `resident_id` to pull appearance from `AppState`, keeps a local revealed-line state, defaults the nearby bubble to `...`, and can follow optional route loops built from catalog metadata.
- `scenes/game_main.gd` re-syncs player tunnel context from actual interior-level entry, while residents still regain tunnel level/visibility from tunnel geometry so routed tunnel residents can move in and out cleanly without player surface overlap falsely counting as tunnel entry.
- The journal never reads the catalog directly; it asks `AppState.build_resident_journal_text()`.

## Common Tasks

### Add A New Resident

1. Add the new resident id to `ResidentCatalog.resident_order()`.
2. Add the resident entry in `ResidentCatalog._story_residents()` or `ResidentCatalog._ambient_residents()`.
3. Define `appearance` with `_look(...)`.
4. Define `spawn` with `_spawn(anchor_id, offset, direction, mood, interaction_radius)`.
5. If the `anchor_id` is new, add it to the spawn-anchor map in [`../../scenes/game_main.gd`](../../scenes/game_main.gd).
6. Run the project and confirm the resident appears, speaks, and shows up in the journal after introduction.

### Change Resident Dialogue Or Progression

1. Edit the resident's `ambient_lines` or `dialogue_beats` in [`../../game/resident_catalog.gd`](../../game/resident_catalog.gd).
2. If the beat introduces new state keys or new side effects, update [`../../game/app_state.gd`](../../game/app_state.gd) and the docs in [`../contracts.md`](../contracts.md).
3. Verify that `R` advances the talk beat and that objective/save status/journal text update as expected.

### Change Resident Appearance

1. Edit the resident's `_look(...)` config in [`../../game/resident_catalog.gd`](../../game/resident_catalog.gd).
2. Confirm that every selected LPC path supports the resident's body type and chosen variant in the shipped metadata. A matching path name alone does not guarantee the combination can render.
3. Do not hardcode appearance in scenes; `NPCController` applies resident appearance automatically.
4. Verify both the main scene and [`../../game/tests/npc_system/test_scene.tscn`](../../game/tests/npc_system/test_scene.tscn) if that resident id is used there.
5. Treat `Failed to resolve combined texture for selection layer` warnings as a resident-content bug and fix the catalog entry instead of ignoring the warning.

### Move A Resident

1. Adjust the resident's `spawn` dictionary in [`../../game/resident_catalog.gd`](../../game/resident_catalog.gd).
2. Prefer changing the `offset` first.
3. Only add a new `anchor_id` if the resident truly belongs to a different hub or needs a new placement cluster.
4. If adding a new anchor id, update [`../../scenes/game_main.gd`](../../scenes/game_main.gd) and document it below in `Current Resident Anchors`.

### Add Resident Movement Or Schedules

1. Start in [`../../characters/control/npc_controller.gd`](../../characters/control/npc_controller.gd).
2. Author simple loop routes in [`../../game/resident_catalog.gd`](../../game/resident_catalog.gd) with `_route(...)` and `_route_point(...)`.
3. Add any new `anchor_id` values to [`../../scenes/game_main.gd`](../../scenes/game_main.gd) so spawn and route points resolve to scene nodes.
4. Keep resident content in the catalog and movement logic in controller/world code.
5. Validate route behavior with [`../../game/tests/npc_system/test_tunnel_npc_travel.tscn`](../../game/tests/npc_system/test_tunnel_npc_travel.tscn) when the route crosses tunnel boundaries.

## Current Resident Anchors

The catalog `spawn.anchor_id` values and `movement.route_points[].anchor_id` values currently supported by [`../../scenes/game_main.gd`](../../scenes/game_main.gd) are:

- `Piano Ferry` -> `terrain/ground/buildings/piano_ferry`
- `Trinity Church` -> `terrain/ground/buildings/TrinityChurch`
- `Bagua Tower` -> `terrain/ground/buildings/BaguaTower`
- `Bi Shan Tunnel South` -> `terrain/ground/bi_shan_tunnel_entries/entry_south`
- `Bi Shan Tunnel North` -> `terrain/ground/bi_shan_tunnel_entries/entry_north`
- `Bi Shan Tunnel` -> `terrain/bi_shan_tunnel`
- `Bi Shan Tunnel South Portal` -> `terrain/bi_shan_tunnel/exit_south`
- `Bi Shan Tunnel North Portal` -> `terrain/bi_shan_tunnel/exit_north`
- `Long Shan Tunnel` -> `terrain/long_shan_tunnel`
- `Long Shan Tunnel South` -> `terrain/ground/long_shan_tunnel_entries/entry_south`
- `Long Shan Tunnel North` -> `terrain/ground/long_shan_tunnel_entries/entry_north`
- `Long Shan Tunnel South Portal` -> `terrain/long_shan_tunnel/exit_south`
- `Long Shan Tunnel North Portal` -> `terrain/long_shan_tunnel/exit_north`

If a resident uses an unsupported `anchor_id`, startup should warn and skip that resident.

## Edge Cases

- If a resident id is missing from runtime state, NPC speech should fail soft instead of crashing.
- If a spawn anchor is missing in the main scene, the resident should be skipped with a warning rather than breaking startup.
- Unknown residents should stay hidden from the resident journal until introduced.
- `Free Walk`, `Continue`, and `Postgame` may seed resident progress differently, so docs and future save work should treat resident state as mode-aware.
- If a resident and the player overlap physically but live on different absolute z layers, they should not target each other, show a talk prompt, or show a resident speech cue.
- If a resident is inside Bi Shan or Long Shan Tunnel while the player is outside, that resident should be hidden and should drop out of closest-target selection until they exit or the player joins them.
- If the player is inside Bi Shan or Long Shan Tunnel, residents outside that same tunnel should be hidden and should drop out of closest-target selection until the player exits or the resident re-enters.
- Tunnel-routed residents should switch back to the correct outside or tunnel level state as soon as they cross the tunnel boundary.
- The journal text is generated as one formatted text block, not a structured list widget. If you change the resident note format, update both the docs and the journal renderer.
- The main overworld currently uses shared hub anchors with offsets, not dedicated per-resident scene markers.
- Collected landmark triggers must immediately drop out of closest-target selection so they do not block nearby resident talk prompts.

## Architecture / Ownership

- [`../../game/resident_catalog.gd`](../../game/resident_catalog.gd) owns resident content and spawn metadata.
- [`../../game/app_state.gd`](../../game/app_state.gd) owns runtime resident profiles, shared resident getters, and journal text generation.
- [`../../scenes/game_main.gd`](../../scenes/game_main.gd) owns overworld spawn/movement-anchor mapping, resident instantiation, tunnel-context syncing, and talk-prompt wiring.
- [`../../characters/control/npc_controller.gd`](../../characters/control/npc_controller.gd) owns resident presentation hookup, nearby bubble reveal behavior, and simple route-following movement.
- [`../../ui/screens/journal_overlay.gd`](../../ui/screens/journal_overlay.gd) owns resident note presentation in the journal.

## Relevant Files

- Scenes:
  - [`../../scenes/game_main.tscn`](../../scenes/game_main.tscn)
- [`../../game/tests/npc_system/test_npc_layer_interaction.tscn`](../../game/tests/npc_system/test_npc_layer_interaction.tscn)
- [`../../game/tests/npc_system/test_npc_control.tscn`](../../game/tests/npc_system/test_npc_control.tscn)
- [`../../game/tests/npc_system/test_tunnel_visibility.tscn`](../../game/tests/npc_system/test_tunnel_visibility.tscn)
- [`../../game/tests/npc_system/test_tunnel_npc_travel.tscn`](../../game/tests/npc_system/test_tunnel_npc_travel.tscn)
- [`../../game/tests/npc_system/test_scene.tscn`](../../game/tests/npc_system/test_scene.tscn)
- Scripts:
  - [`../../scenes/game_main.gd`](../../scenes/game_main.gd)
  - [`../../characters/control/npc_controller.gd`](../../characters/control/npc_controller.gd)
  - [`../../ui/screens/journal_overlay.gd`](../../ui/screens/journal_overlay.gd)
- Shared state or catalogs:
  - [`../../game/app_state.gd`](../../game/app_state.gd)
  - [`../../game/resident_catalog.gd`](../../game/resident_catalog.gd)
- Related docs:
  - [`../npc_system_design.md`](../npc_system_design.md)
  - [`../core_game_workflow.md`](../core_game_workflow.md)
  - [`../ui_workflow.md`](../ui_workflow.md)

## Signals / Nodes / Data Flow

- Signals emitted:
  - `resident_profile_changed`
  - `residents_changed`
- Signals consumed:
  - player controller `closest_object_changed`
  - player controller `inspect_requested`
- Important node paths, dictionaries, resources, or data flow:
  - `scenes/game_main.tscn` keeps the overworld actor layer at `actors`, with the player at `actors/player`
  - `scenes/game_main.gd` maps resident spawn and movement `anchor_id` values to concrete scene nodes
  - `NPCController.resident_id` links an instantiated actor to resident catalog data
  - optional `resident_profile.movement.route_points` expand into resolved world-space route positions at spawn time
  - `AppState.interact_with_resident()` advances talk beats and updates resident runtime state
  - `NPCController.reveal_dialogue()` swaps the nearby `...` cue to the just-triggered resident line
  - `AppState.build_resident_journal_text()` is the only resident-note text source used by the journal UI
  - `BaseController` filters nearby interaction targets to the same absolute z layer before closest-object or speech logic runs

## Safe Extension Order

When extending the NPC system, make changes in this order unless the task is strictly UI-only:

1. Update resident content or data shape in [`../../game/resident_catalog.gd`](../../game/resident_catalog.gd).
2. Update shared runtime behavior in [`../../game/app_state.gd`](../../game/app_state.gd) if the change affects state, getters, or beat side effects.
3. Update world integration in [`../../scenes/game_main.gd`](../../scenes/game_main.gd) only if spawn anchors, prompt behavior, or actor-layer assumptions need to change.
4. Update [`../../characters/control/npc_controller.gd`](../../characters/control/npc_controller.gd) only if NPC presentation or talk behavior changes.
5. Update [`../../ui/screens/journal_overlay.gd`](../../ui/screens/journal_overlay.gd) only if the player-facing resident notes need to render differently.
6. Update the docs in the same patch.

## Contracts / Boundaries

- If resident profile keys, spawn metadata shape, or `AppState` resident getters change, update [`../contracts.md`](../contracts.md) and [`../architecture.md`](../architecture.md).
- If the main-scene actor layer or spawn-anchor node assumptions change, update [`../contracts.md`](../contracts.md), [`../module_map.md`](../module_map.md), and [`../npc_system_design.md`](../npc_system_design.md).
- If the resident journal presentation changes materially, update [`../ui_workflow.md`](../ui_workflow.md) and [`../ui_design_context.md`](../ui_design_context.md).

## Validation

- Run the full project and verify that the main scene loads with the resident roster present.
- Confirm that approaching a resident changes the hint to a talk prompt and that `R` advances their dialogue.
- In Trinity Church and other mixed interaction spaces, confirm that nearby residents still win target selection over collectible cue triggers.
- Open the journal and verify that introduced residents appear with updated notes.
- Use [`../../game/tests/npc_system/test_npc_layer_interaction.tscn`](../../game/tests/npc_system/test_npc_layer_interaction.tscn) when testing same-layer gating, portal-driven z changes, and closest-target behavior across stacked resident layers.
- Use [`../../game/tests/npc_system/test_npc_control.tscn`](../../game/tests/npc_system/test_npc_control.tscn) when changing routed NPC controller behavior such as walk animation playback, nearby talk pause/resume, or dialogue reveal handling.
- Use [`../../game/tests/npc_system/test_tunnel_visibility.tscn`](../../game/tests/npc_system/test_tunnel_visibility.tscn) for tunnel-resident placement, tunnel-context visibility, and tunnel spacing regression coverage.
- Use [`../../game/tests/npc_system/test_tunnel_npc_travel.tscn`](../../game/tests/npc_system/test_tunnel_npc_travel.tscn) for tunnel route crossing, level-state syncing, and in/out tunnel resident travel coverage.
- Use [`../../game/tests/npc_system/test_scene.tscn`](../../game/tests/npc_system/test_scene.tscn) as a faster sandbox for resident speech and journal checks.
- Use the main project flow to verify that tunnel residents spawn on walkable tunnel cells, can move in and out through tunnel entrances, and only remain visible when they share the player's current tunnel context.

Quick validation checklist:

- No startup warnings about missing NPC spawn or movement anchors
- Residents on a different absolute z layer do not become the closest target and do not trigger `Talk`
- Tunnel residents spawn on walkable tunnel cells instead of outside the tunnel boundary
- Tunnel residents inherit the correct tunnel level on spawn and switch back to the outside level after leaving the tunnel
- Tunnel residents only stay visible when they share the player's current tunnel context
- Walking over a tunnel footprint on the surface must not reveal tunnel residents or hide the ground layer
- New or changed residents appear under the shared `actors` layer and sort correctly against the player
- Crossing the portal in `test_npc_layer_interaction.tscn` changes the player's absolute z and swaps which resident row is targetable
- The nearby cue still shows `...` before talk, and the revealed resident line still fits in the speech balloon
- After collecting a nearby landmark trigger, the prompt should immediately fall through to the nearest valid resident if one is still in range
- Resident introduction still makes the resident appear in the journal
- If trust/objective/save status changed, the HUD and journal still reflect that state cleanly

## Known Limitations

- Residents can follow simple authored route loops, but there are still no full daily schedules, branching behaviors, or navigation-aware path planning outside authored routes.
- Story beats are still linear and resident-specific branching is not modeled.
- Spawn placement is offset-based around shared hubs rather than dedicated scene markers.
- There is no full dialogue panel or save-data serialization for resident progression yet.

## Out Of Scope

- A full branching dialogue panel with dialogue history.
- Authored daily schedules or autonomous patrol paths for the full roster.
- Save/load serialization for resident progress beyond the current runtime configuration helpers.
