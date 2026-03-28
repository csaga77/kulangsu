# Kulangsu NPC System Design

Read [`design_brief.md`](design_brief.md) first for the project summary and tone. If the task is implementation-focused, read [`features/npc_system.md`](features/npc_system.md) before this doc. That feature doc is the quickest operational handoff; this doc explains why the resident system is structured the way it is and what assumptions future work should preserve.

## What This System Optimizes For

- Calm, short-range interactions that fit the island's quiet exploration tone.
- One resident model that can drive overworld presence, talk cues, talk progression, objectives, and journal notes.
- Data-driven authoring so resident writing and appearance do not get scattered across scene files.
- Lightweight progression hooks that work with the current speech-balloon interaction style instead of requiring a full dialogue UI.

## Current System At A Glance

The live resident flow is:

1. [`../game/resident_catalog.gd`](../game/resident_catalog.gd) defines the static resident roster, content, appearance presets, spawn metadata, and optional movement routes.
2. [`../game/app_state.gd`](../game/app_state.gd) clones those defaults into mutable runtime `resident_profiles` and exposes all resident-facing getters.
3. [`../scenes/game_main.gd`](../scenes/game_main.gd) caches supported spawn and route anchors, resolves sparse authored routes into world-space movement points, spawns the roster under the shared `actors/Residents` layer, turns player `R` input into resident talk interactions, and synchronizes tunnel-specific visibility and level state.
4. [`../characters/control/base_controller.gd`](../characters/control/base_controller.gd) filters nearby targets to the same absolute z layer before closest-target or speech logic can use them.
5. [`../characters/control/npc_controller.gd`](../characters/control/npc_controller.gd) applies each resident's appearance, shows the nearby `...` cue, reveals the current talk line after interaction, and follows resolved runtime route points with collision-aware motion except on explicit tunnel/portal bypass helper points.
6. [`../ui/screens/journal_overlay.gd`](../ui/screens/journal_overlay.gd) renders resident notes from `AppState.build_resident_journal_text()`.

This split is intentional: authored content stays in the catalog, mutable progression stays in shared state, and scene/controller code handles only world integration and presentation.

## Design Decisions That Matter

### Catalog First, Scene Second

- Residents are authored as dictionaries instead of bespoke scene variants because the current roster is already 30 NPCs and the system needs to scale content faster than scene maintenance.
- [`../game/resident_catalog.gd`](../game/resident_catalog.gd) is the source of truth for which residents exist. `resident_order()` is not a convenience list; it is part of the contract for the full runtime roster.
- Static fields such as `display_name`, `role`, `ambient_lines`, `appearance`, and `spawn` belong in the catalog even if only one current scene uses them.

### Runtime State Lives In `AppState`

- The resident system does not mutate the catalog directly. [`../game/app_state.gd`](../game/app_state.gd) owns the runtime copy so the HUD, journal, costume unlock logic, and future save/load work can all read the same resident state.
- Current mutable resident fields are:
  - `known`
  - `trust`
  - `conversation_index`
  - `quest_state`
  - `current_step`
- If a future feature needs resident progression to affect more than the local scene, it should probably enter through `AppState` instead of being hidden in `scenes/game_main.gd` or `npc_controller.gd`.

### Shared Actor Layer Is Required

- In the main overworld, the player and resident instances live under the same y-sorted `actors` branch in [`../scenes/game_main.tscn`](../scenes/game_main.tscn).
- This is required for believable overlap and draw order. If the player and residents are split into separate visual layers, depth cues break quickly.
- The shared y-sorted actor layer is a rendering rule, not just a convenience for the current implementation.

### Same-Layer Targeting Is Required

- Proximity alone is not enough for interaction. [`../characters/control/base_controller.gd`](../characters/control/base_controller.gd) rejects nearby targets unless they share the same absolute z value as the active character.
- That rule protects stacked spaces and portal-driven traversal from cross-layer talk prompts, accidental auto-speech, or misleading target selection.
- If future work changes portals, stacked traversal, or NPC movement between layers, re-validate this rule instead of assuming the older behavior still holds.

### Tunnel Context Is Stricter For The Player

- Tunnel residents now follow a stricter visibility rule than plain same-layer targeting alone.
- The player only counts as being "in a tunnel" after actually reaching that tunnel's interior level; walking over the tunnel footprint on the surface must not reveal tunnel residents or hide ground buildings.
- Routed residents use the same interior-only tunnel classification, and actual level changes now come from the same portal overlap logic the player uses.
- When authored routes cross between a tunnel portal anchor and its paired surface entry anchor, the main scene resolves extra portal-direction waypoints so the resident traverses along the portal axis instead of clipping in from the side.
- Portal-anchored route offsets are resolved in portal-local coordinates so authored points can preserve both through-portal depth and lateral alignment.

### Route Resolution Lives In `game_main.gd`

- Catalog-authored `movement.route_points` are intentionally sparse. They describe anchor ids, local offsets, and wait timing, but they are not the final path the NPC walks.
- [`../scenes/game_main.gd`](../scenes/game_main.gd) is the one place that resolves those sparse points into a runtime route:
  - validate anchor ids
  - resolve anchor positions into world space
  - snap tunnel anchors back onto walkable tunnel cells
  - expand same-tunnel point pairs across the tunnel path returned by [`../architecture/tunnel.gd`](../architecture/tunnel.gd)
  - insert portal-direction helper points when a route crosses between a tunnel portal and its paired surface entry
- [`../characters/control/npc_controller.gd`](../characters/control/npc_controller.gd) should stay ignorant of scene anchor ids. It should only consume resolved world-space route points plus explicit per-point flags such as `allow_collision_bypass`.
- Default routed movement should remain collision-aware through [`../characters/human_body_2d.gd`](../characters/human_body_2d.gd). Direct positional bypass should stay limited to explicit seam/helper points where collision would break a scripted portal or tunnel transition.

### Dialogue Is Lightweight On Purpose

- Residents currently use:
  - a nearby `...` cue bubble before the player commits to talk
  - short authored lines for resident beats
  - linear `dialogue_beats` for `R` interactions
- `conversation_index` determines which beat is consumed next. For ambient residents, those beats are generated from `ambient_lines`. This is a compact prototype-friendly model, not a full branching dialogue system.
- The system is intentionally biased toward short conversations, objective nudges, and journal updates rather than large dialogue trees.

### Journal Notes Are Generated Text

- The resident journal is not a structured data grid. [`../ui/screens/journal_overlay.gd`](../ui/screens/journal_overlay.gd) displays one formatted text block produced by `AppState`.
- That is why resident note formatting changes should start in [`../game/app_state.gd`](../game/app_state.gd), not in the overlay scene alone.

## Current Data Contracts

### Resident Profile Shape

Each catalog resident currently resolves to a runtime profile with these keys:

- Static authoring fields:
  - `display_name`
  - `landmark`
  - `role`
  - `routine_note`
  - `melody_hint`
  - `ambient_lines`
  - `dialogue_beats`
  - `appearance`
  - `spawn`
- Runtime progression fields:
  - `known`
  - `trust`
  - `conversation_index`
  - `quest_state`
  - `current_step`

The catalog helper `_resident(...)` in [`../game/resident_catalog.gd`](../game/resident_catalog.gd) defines the default shape. If this shape changes, update [`contracts.md`](contracts.md) and [`features/npc_system.md`](features/npc_system.md) in the same patch.

### Dialogue Beat Shape

`AppState.interact_with_resident()` and `_apply_resident_beat()` currently consume these beat keys:

- Always used when present:
  - `line`
  - `journal_step`
  - `save_status`
  - `trust_delta`
- Optional state and HUD side effects:
  - `objective`
  - `hint`
  - `chapter`
  - `quest_state`

Ambient residents do not need custom beats authored by hand. [`../game/resident_catalog.gd`](../game/resident_catalog.gd) currently builds their beats from `ambient_lines` through `_ambient_beats(...)`.

### Spawn Payload

Resident spawn metadata is currently:

- `anchor_id`
- `offset`
- `direction`
- `mood`
- `interaction_radius`

Optional resident movement metadata is currently:

- `movement.route_points`
- `movement.arrival_radius`
- `movement.wait_min_sec`
- `movement.wait_max_sec`
- `movement.ping_pong`

The main scene supports these resident anchor ids today:

- `Piano Ferry`
- `Trinity Church`
- `Bagua Tower`
- `Bi Shan Tunnel South`
- `Bi Shan Tunnel North`
- `Bi Shan Tunnel`
- `Bi Shan Tunnel South Portal`
- `Bi Shan Tunnel North Portal`
- `Long Shan Tunnel`
- `Long Shan Tunnel South`
- `Long Shan Tunnel North`
- `Long Shan Tunnel South Portal`
- `Long Shan Tunnel North Portal`

This shared-anchor-plus-offset model is intentionally cheap to author. It is less precise than dedicated placement markers, but it keeps roster iteration fast while the island layout is still moving.

### Appearance Payload

- `appearance` is a `HumanBody2D.set_configuration()` payload assembled by `_look(...)` in [`../game/resident_catalog.gd`](../game/resident_catalog.gd).
- Resident looks should continue to be authored in the catalog, not hardcoded in scene instances.
- When authoring a resident look, verify that each selected LPC path supports that resident's `body_type` and chosen variant in the shipped metadata. A path existing in the metadata file is not enough if its layer data only supports another body type or a narrower variant set.

## Current Player-Facing Behavior

- Approaching a same-layer resident changes the hint from `Inspect` to `Talk to <resident>`.
- A nearby resident shows `...` in the speech balloon until the player presses `R`.
- Pressing `R` runs `AppState.interact_with_resident(resident_id)` through [`../scenes/game_main.gd`](../scenes/game_main.gd).
- The NPC bubble then swaps from `...` to the returned beat line for that interaction.
- The interaction can:
  - reveal the resident in the journal
  - change `trust`
  - advance `conversation_index`
  - update `quest_state`
  - rewrite the resident's current journal lead
  - change the global objective, chapter, hint, or save-status text
- Leaving and re-entering talk range resets the nearby bubble back to `...` until the next explicit talk input.

## Test And Validation Map

Use the test scenes deliberately. They are not interchangeable.

### Full Overworld Check

Use [`../scenes/game_main.tscn`](../scenes/game_main.tscn) when validating:

- full-roster spawning
- anchor placement
- journal updates in normal gameplay flow
- hint text and objective updates in the real HUD
- actor-layer y-sorting against the player

### Fast Resident Content Check

Use [`../game/tests/npc_system/test_scene.tscn`](../game/tests/npc_system/test_scene.tscn) when you want a faster sandbox for:

- resident appearance
- cue-bubble and revealed-line behavior
- talk-beat progression
- journal text changes

This scene is better when the bug is about resident content or presentation rather than world layering.

### Layer And Portal Check

Use [`../game/tests/npc_system/test_npc_layer_interaction.tscn`](../game/tests/npc_system/test_npc_layer_interaction.tscn) when changing:

- same-layer targeting rules
- `BaseController` proximity filtering
- player/NPC z-index expectations
- portal-driven layer changes
- stacked NPC interaction behavior

This sandbox deliberately places residents on multiple z layers and uses a portal transition to move the player between them. The portal's cyan debug zone is drawn from its actual collision shape, so if the portal size changes the visible test affordance should change with it.

### Focused NPC Control Check

Use [`../game/tests/npc_system/test_npc_control.tscn`](../game/tests/npc_system/test_npc_control.tscn) when changing:

- routed NPC controller behavior
- walk animation playback during route motion
- collision-aware route movement against walls or blockers
- pause/resume behavior when the player enters or leaves talk range
- nearby `...` cue and revealed-line handoff after a talk interaction

This regression scene instantiates the main overworld, waits for Ren to start moving inside Long Shan Tunnel, verifies that movement advances the walk frames, moves the player into the same tunnel interior to confirm the route pauses for nearby talk, confirms the nearby cue changes from `...` to the revealed line after talk, and then moves the player back outside to verify the route resumes.

Use [`../game/tests/npc_system/test_npc_route_collision.tscn`](../game/tests/npc_system/test_npc_route_collision.tscn) when changing:

- routed NPC movement code that should respect `CharacterBody2D` collision
- blocker or wall interactions along authored routes

This regression scene uses a single routed NPC and a blocking wall, then asserts that route movement starts but does not pass through the obstacle.

### Tunnel Context Check

Use [`../game/tests/npc_system/test_tunnel_visibility.tscn`](../game/tests/npc_system/test_tunnel_visibility.tscn) and [`../game/tests/npc_system/test_tunnel_npc_travel.tscn`](../game/tests/npc_system/test_tunnel_npc_travel.tscn) when changing:

- tunnel-resident visibility rules
- player tunnel-entry detection versus surface overlap
- tunnel resident route re-entry or outside/tunnel level restoration
- portal-direction approach/exit alignment for routed residents
- ground-building masking tied to tunnel interiors

`test_tunnel_npc_travel.tscn` currently encodes two reference behaviors:

- Ren is the inside-only Long Shan route: south tunnel mouth -> mid-tunnel point -> north tunnel mouth while staying on the tunnel interior path.
- Nuo is the tunnel-to-surface Bi Shan route: tunnel portal -> front-aligned outside helper point -> outside wait point, with the outside level restored by the shared portal overlap logic.

## Debugging Shortcuts

When the system breaks, start here:

- Resident missing entirely:
  - Check `resident_order()` and the resident entry in [`../game/resident_catalog.gd`](../game/resident_catalog.gd).
  - Check `AppState.get_resident_ids()` and `get_resident_spawn_config()`.
  - Check for missing anchor warnings from [`../scenes/game_main.gd`](../scenes/game_main.gd).
- Resident appears but has the wrong look:
  - Check `resident_id` on the instantiated controller.
  - Check `AppState.get_resident_appearance_config()` and `NPCController._apply_resident_presentation()`.
  - Check the resident's LPC path/body-type/variant combination against [`../resources/sprites/universal_lpc/universal_lpc_metadata.json`](../resources/sprites/universal_lpc/universal_lpc_metadata.json).
  - Treat `Failed to resolve combined texture for selection layer` warnings as invalid appearance content, not as a harmless fallback.
- Prompt says `Inspect` instead of `Talk`:
  - Check whether the target is actually using `NPCController`.
  - Check same-layer gating in [`../characters/control/base_controller.gd`](../characters/control/base_controller.gd).
- Resident talks across layers:
  - Check absolute z values first, not just node parentage or local `z_index`.
- Tunnel residents show or hide at the wrong time:
  - Check `Tunnel.contains_actor_interior()` versus `Tunnel.contains_actor()`.
  - Check `_find_player_tunnel()` and `_find_resident_tunnel()` in [`../scenes/game_main.gd`](../scenes/game_main.gd).
  - Check tunnel masking refresh in [`../common/auto_visibility_node_2d.gd`](../common/auto_visibility_node_2d.gd).
- Route waypoints look wrong:
  - Check the sparse authored route in [`../game/resident_catalog.gd`](../game/resident_catalog.gd) first.
  - Then check `_build_resident_movement_config()`, `_resolve_directional_portal_route_position()`, and `_build_tunnel_boundary_transition_points()` in [`../scenes/game_main.gd`](../scenes/game_main.gd).
  - Use the runtime route overlay in [`../scenes/game_main.tscn`](../scenes/game_main.tscn) to compare authored points against the expanded `NPCController.m_route_points`.
- Journal text looks stale:
  - Check `AppState.interact_with_resident()`, `resident_profile_changed`, and `build_resident_journal_text()`.
- Spawn feels visually wrong:
  - Check the catalog `offset` before adding a new anchor id.

## Extension Guardrails

- Preserve the catalog as the source of truth for authored resident content.
- Keep shared resident progression in [`../game/app_state.gd`](../game/app_state.gd), not in scene-local nodes.
- Keep world wiring in [`../scenes/game_main.gd`](../scenes/game_main.gd) and controller scripts.
- Keep journal rendering thin. If the resident note shape changes, change the data producer first.
- If new resident movement or schedules are added, keep authored schedule data in the catalog and runtime movement logic in world/controller code.
- If anchor ids, resident profile keys, or same-layer targeting rules change, update:
  - [`features/npc_system.md`](features/npc_system.md)
  - [`contracts.md`](contracts.md)
  - [`architecture.md`](architecture.md)
  - [`module_map.md`](module_map.md)

## Current Limits And Intentional Gaps

- Residents can now follow simple authored route loops, but they do not yet have full schedules, branching routines, or broader navigation.
- Resident talk progression is linear.
- The journal is still one formatted text block.
- The roster still uses shared hub anchors with offsets instead of dedicated scene markers.
- Resident progression is runtime-only; there is no durable save/load format for it yet.
- There is no full dialogue overlay or dialogue history panel yet.

## Best Next Steps

1. Add a dedicated dialogue overlay for longer resident conversations while keeping ambient balloons for short nearby lines.
2. Replace shared hub anchors with authored scene markers if placement quality becomes more important than authoring speed.
3. Connect resident beats more directly to landmark quest modules once those district flows stabilize.
4. Add mode-aware or postgame dialogue variants without breaking the shared resident profile contract.
