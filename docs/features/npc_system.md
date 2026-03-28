# NPC System

Read this file first when the task is specifically about residents, NPC dialogue, resident spawning, or resident journal behavior.

## Quick Start For Future Agents

Open these files first in this order:

1. [`../../game/resident_catalog.gd`](../../game/resident_catalog.gd)
2. [`../../game/app_state.gd`](../../game/app_state.gd)
3. [`../../scenes/game_main.gd`](../../scenes/game_main.gd)
4. [`../../characters/control/npc_controller.gd`](../../characters/control/npc_controller.gd)
5. [`../../ui/screens/journal_overlay.gd`](../../ui/screens/journal_overlay.gd)

For tunnel-route bugs, also open [`../../architecture/tunnel.gd`](../../architecture/tunnel.gd) immediately after `game_main.gd`.

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
- Resident talk progression uses a two-layer model: `conditional_beats` (priority-sorted, condition-gated, checked first) and then the linear `dialogue_beats` spine indexed by `conversation_index`.
- Nearby resident bubbles should default to `...` until explicit talk input reveals a line.
- Residents should only be targetable when the player shares the same absolute z/layer context.
- Residents should only be visible and targetable when they share the player's current tunnel context: both outside, or inside the same tunnel after actually entering its interior level rather than merely overlapping the tunnel footprint on the surface.
- Tunnel context is intentionally interior-only for both player and residents: surface overlap with a tunnel footprint should not count as being inside that tunnel.
- Residents and collectible landmark triggers should share the top closest-target priority so the nearest same-layer target wins and active cues remain collectible in mixed spaces.
- Residents may stay stationary or follow authored route points; routed tunnel residents should still pause for nearby talk and use the same tunnel visibility rules as the player.
- When a route crosses between a tunnel portal anchor and its paired surface entry anchor, the resolved route must insert portal-direction-aligned waypoints so the resident enters and exits along the portal axis instead of cutting across the side.
- Player and resident actors must stay under the same y-sorted actor layer in the main scene so character overlap reads correctly.

## Current Authoring Model

- The source of truth for which residents exist is `ResidentCatalog.resident_order()`.
- Story residents live in `ResidentCatalog._story_residents()`.
- Ambient residents live in `ResidentCatalog._ambient_residents()`.
- `AppState` builds runtime resident profiles from the catalog defaults and exposes the getters the rest of the game uses.
- `scenes/game_main.gd` never hardcodes individual residents; it loops over `AppState.get_resident_ids()` and spawns them from catalog metadata.
- Tunnel-root spawns and tunnel-owned movement waypoints are snapped back onto the authored tunnel path if an offset drifts off the walkable area.
- Tunnel-internal route expansion prefers higher-connectivity walkable cells so residents stay nearer the middle of a tunnel path when multiple shortest routes exist.
- `NPCController` uses `resident_id` to pull appearance from `AppState`, keeps a local revealed-line state, defaults the nearby bubble to `...`, and follows the resolved runtime route produced from catalog metadata.
- `scenes/game_main.gd` re-syncs both player and resident tunnel context from actual tunnel interiors rather than any surface footprint overlap.
- Routed residents now rely on the same portal overlap logic as the player for actual tunnel-side level changes; the route builder only shapes the approach and crossing points.
- For paired tunnel portal and surface entry anchors, `scenes/game_main.gd` expands the authored route with explicit portal-direction approach points so surface-to-tunnel travel stays aligned with the portal facing.
- Tunnel portal route-point offsets are interpreted in portal-local space: `x` controls distance through the portal axis and `y` controls lateral alignment along the portal opening.
- `scenes/game_main.gd` resolves authored `movement.route_points` once at spawn time: it validates anchors, resolves anchor positions, snaps tunnel points to walkable cells, expands same-tunnel point pairs across the tunnel path, and inserts portal-facing helper points for paired portal/surface transitions.
- `NPCController` only receives resolved world-space route points; it does not resolve scene anchors or tunnel path cells on the fly.
- Routed NPCs use `HumanBody2D.move_with_speed()` for ordinary route motion so walls still block them, and only fall back to direct positional bypass on route points explicitly flagged with `allow_collision_bypass`.
- The journal never reads the catalog directly; it asks `AppState.build_resident_journal_text()`.

## Current Routed Residents

- `tunnel_guide` / Tunnel Guide Ren is the reference case for an inside-only tunnel route. He spawns inside Long Shan Tunnel and currently routes south portal -> mid-tunnel point -> north portal without leaving the tunnel walls.
- `tunnel_listener_nuo` / Tunnel Listener Nuo is the reference case for a tunnel-to-surface route. She starts inside Bi Shan Tunnel, crosses the south portal, and exits through the paired surface entry using the portal-direction front-approach helper points.
- If Ren breaks but Nuo still works, start by inspecting Long Shan tunnel path snapping and same-tunnel route expansion.
- If Nuo breaks but Ren still works, start by inspecting portal-direction transition helpers, portal-local offsets, and portal overlap-driven level changes.

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

1. Author or adjust the sparse route in [`../../game/resident_catalog.gd`](../../game/resident_catalog.gd) with `_route(...)` and `_route_point(...)`.
2. Add any new `anchor_id` values to [`../../scenes/game_main.gd`](../../scenes/game_main.gd) so spawn and route points resolve to scene nodes.
3. Only change [`../../scenes/game_main.gd`](../../scenes/game_main.gd), [`../../architecture/tunnel.gd`](../../architecture/tunnel.gd), or [`../../characters/control/npc_controller.gd`](../../characters/control/npc_controller.gd) if the route needs new resolution rules, tunnel path behavior, or runtime movement behavior.
4. Keep resident content in the catalog and movement logic in controller/world code.
5. If a route stays inside a tunnel, author tunnel and portal anchors only and let [`../../architecture/tunnel.gd`](../../architecture/tunnel.gd) expand the interior walk path between them.
6. If a route crosses a tunnel boundary, author both the portal anchor and the paired surface entry anchor so the main scene can build the front-entrance transition automatically.
7. For tunnel portal anchors, author `offset.x` as distance through the portal axis and `offset.y` as lateral placement along the portal opening.
8. Validate route behavior with [`../../game/tests/npc_system/test_tunnel_npc_travel.tscn`](../../game/tests/npc_system/test_tunnel_npc_travel.tscn) and the route debug overlay whenever the route uses tunnel anchors or portal crossings.

### Debug Resident Routes

1. Open [`../../scenes/game_main.tscn`](../../scenes/game_main.tscn) and enable `debug_draw_npc_routes` on the root `game_main` node.
2. Set `debug_npc_route_filter` to a resident id such as `tunnel_guide` or a display-name fragment such as `Ren` to isolate one route.
3. Use `Ren` for inside-only Long Shan tunnel path checks and `Nuo` for portal-to-surface transition checks.
4. In play mode, look for numbered waypoint rings, the resident marker, and the white line to the current target waypoint.
5. Orange outer rings mark route points that intentionally bypass collision, such as tunnel path helper points or portal transition helpers.
6. If the numbered points do not match the authored route count, that is expected: [`../../scenes/game_main.gd`](../../scenes/game_main.gd) may expand the sparse authored route into additional resolved helper points.

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
- If route geometry looks wrong, inspect both the sparse authored route in [`../../game/resident_catalog.gd`](../../game/resident_catalog.gd) and the expanded runtime route in `NPCController.m_route_points`; the main scene may have inserted tunnel-path or portal transition helper points.
- The journal text is generated as one formatted text block, not a structured list widget. If you change the resident note format, update both the docs and the journal renderer.
- The main overworld currently uses shared hub anchors with offsets, not dedicated per-resident scene markers.
- Collected landmark triggers must immediately drop out of closest-target selection so they do not block nearby resident talk prompts.

## Architecture / Ownership

- [`../../game/resident_catalog.gd`](../../game/resident_catalog.gd) owns resident content and spawn metadata.
- [`../../game/app_state.gd`](../../game/app_state.gd) owns runtime resident profiles, shared resident getters, and journal text generation.
- [`../../scenes/game_main.gd`](../../scenes/game_main.gd) owns overworld spawn/movement-anchor mapping, resident instantiation, tunnel-context syncing, and talk-prompt wiring.
- [`../../architecture/tunnel.gd`](../../architecture/tunnel.gd) owns tunnel walkable-path snapping, interior checks, and same-tunnel route expansion helpers.
- [`../../characters/control/npc_controller.gd`](../../characters/control/npc_controller.gd) owns resident presentation hookup, nearby bubble reveal behavior, and simple route-following movement.
- [`../../ui/screens/journal_overlay.gd`](../../ui/screens/journal_overlay.gd) owns resident note presentation in the journal.

## Relevant Files

- Scenes:
  - [`../../scenes/game_main.tscn`](../../scenes/game_main.tscn)
- [`../../game/tests/npc_system/test_npc_layer_interaction.tscn`](../../game/tests/npc_system/test_npc_layer_interaction.tscn)
- [`../../game/tests/npc_system/test_npc_control.tscn`](../../game/tests/npc_system/test_npc_control.tscn)
- [`../../game/tests/npc_system/test_npc_route_collision.tscn`](../../game/tests/npc_system/test_npc_route_collision.tscn)
- [`../../game/tests/npc_system/test_tunnel_visibility.tscn`](../../game/tests/npc_system/test_tunnel_visibility.tscn)
- [`../../game/tests/npc_system/test_tunnel_npc_travel.tscn`](../../game/tests/npc_system/test_tunnel_npc_travel.tscn)
- [`../../game/tests/npc_system/test_scene.tscn`](../../game/tests/npc_system/test_scene.tscn)
- Scripts:
  - [`../../scenes/game_main.gd`](../../scenes/game_main.gd)
  - [`../../architecture/tunnel.gd`](../../architecture/tunnel.gd)
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
  - `scenes/game_main.gd` expands sparse authored `movement.route_points` into resolved world-space route positions before calling `NPCController.configure_movement()`
  - same-tunnel point pairs expand through [`../../architecture/tunnel.gd`](../../architecture/tunnel.gd) walkable path cells
  - tunnel portal-to-surface entry route pairs expand into additional portal-direction waypoints at spawn time
  - `NPCController.resident_id` links an instantiated actor to resident catalog data
  - `NPCController.m_route_points` stores the resolved runtime route, not the sparse authored route from the catalog
  - `NPCController` uses collision-aware movement by default and only bypasses collision on route points flagged with `allow_collision_bypass`
  - `AppState.interact_with_resident()` advances talk beats and updates resident runtime state
  - `NPCController.reveal_dialogue()` swaps the nearby `...` cue to the just-triggered resident line
  - `AppState.build_resident_journal_text()` is the only resident-note text source used by the journal UI
  - `BaseController` filters nearby interaction targets to the same absolute z layer before closest-object or speech logic runs

## Safe Extension Order

When extending the NPC system, make changes in this order unless the task is strictly UI-only:

1. Update resident content or data shape in [`../../game/resident_catalog.gd`](../../game/resident_catalog.gd).
2. Update shared runtime behavior in [`../../game/app_state.gd`](../../game/app_state.gd) if the change affects state, getters, or beat side effects.
3. Update world integration in [`../../scenes/game_main.gd`](../../scenes/game_main.gd) only if spawn anchors, prompt behavior, route resolution, or actor-layer assumptions need to change.
4. Update [`../../architecture/tunnel.gd`](../../architecture/tunnel.gd) only if tunnel walkability, tunnel-path expansion, or interior checks need to change.
5. Update [`../../characters/control/npc_controller.gd`](../../characters/control/npc_controller.gd) only if NPC presentation or runtime route-following behavior changes.
6. Update [`../../ui/screens/journal_overlay.gd`](../../ui/screens/journal_overlay.gd) only if the player-facing resident notes need to render differently.
7. Update the docs in the same patch.

## Contracts / Boundaries

- If resident profile keys, spawn metadata shape, or `AppState` resident getters change, update [`../contracts.md`](../contracts.md) and [`../architecture.md`](../architecture.md).
- If the main-scene actor layer or spawn-anchor node assumptions change, update [`../contracts.md`](../contracts.md), [`../module_map.md`](../module_map.md), and [`../npc_system_design.md`](../npc_system_design.md).
- If the resident journal presentation changes materially, update [`../ui_workflow.md`](../ui_workflow.md) and [`../ui_design_context.md`](../ui_design_context.md).

## Validation

- Run the full project and verify that the main scene loads with the resident roster present.
- Confirm that approaching a resident changes the hint to a talk prompt and that `R` advances their dialogue.
- In Trinity Church and other mixed interaction spaces, confirm that the nearest same-layer resident or collectible cue wins target selection.
- Open the journal and verify that introduced residents appear with updated notes.
- Use [`../../game/tests/npc_system/test_npc_layer_interaction.tscn`](../../game/tests/npc_system/test_npc_layer_interaction.tscn) when testing same-layer gating, portal-driven z changes, and closest-target behavior across stacked resident layers.
- Use [`../../game/tests/npc_system/test_npc_control.tscn`](../../game/tests/npc_system/test_npc_control.tscn) when changing routed NPC controller behavior such as walk animation playback, nearby talk pause/resume, or dialogue reveal handling.
- Use [`../../game/tests/npc_system/test_npc_route_collision.tscn`](../../game/tests/npc_system/test_npc_route_collision.tscn) when changing routed NPC movement against blocking walls or other collision geometry.
- Use [`../../game/tests/npc_system/test_tunnel_visibility.tscn`](../../game/tests/npc_system/test_tunnel_visibility.tscn) for tunnel-resident placement, tunnel-context visibility, and tunnel spacing regression coverage.
- Use [`../../game/tests/npc_system/test_tunnel_npc_travel.tscn`](../../game/tests/npc_system/test_tunnel_npc_travel.tscn) for tunnel route crossing, level-state syncing, and the two reference routed residents: Ren's inside-only Long Shan route and Nuo's Bi Shan tunnel-to-surface route.
- Use [`../../game/tests/npc_system/test_scene.tscn`](../../game/tests/npc_system/test_scene.tscn) as a faster sandbox for resident speech and journal checks.
- Use the main project flow to verify that tunnel residents spawn on walkable tunnel cells, can move in and out through tunnel entrances, and only remain visible when they share the player's current tunnel context.

Quick validation checklist:

- No startup warnings about missing NPC spawn or movement anchors
- Residents on a different absolute z layer do not become the closest target and do not trigger `Talk`
- Tunnel residents spawn on walkable tunnel cells instead of outside the tunnel boundary
- Tunnel residents inherit the correct tunnel level on spawn and switch back to the outside level after leaving the tunnel
- Tunnel residents only stay visible when they share the player's current tunnel context
- Walking over a tunnel footprint on the surface must not reveal tunnel residents or hide the ground layer
- Ren's Long Shan route should resolve from the south tunnel mouth to a mid-tunnel point to the north tunnel mouth without leaving the tunnel walls
- Nuo's Bi Shan route should resolve from the tunnel portal to a front-aligned outside helper point before reaching her outside wait point
- Tunnel-routed residents enter and exit along the tunnel portal direction instead of cutting across the side
- Routed NPCs stop at blocking walls instead of sliding straight through route obstacles
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
