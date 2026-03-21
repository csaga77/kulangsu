# Kulangsu NPC System Design

Read [`design_brief.md`](design_brief.md) first for the project summary and tone. If the task is implementation-focused, read [`features/npc_system.md`](features/npc_system.md) before this doc. That feature doc is the quickest operational handoff; this doc explains why the resident system is structured the way it is and what assumptions future work should preserve.

## What This System Optimizes For

- Calm, short-range interactions that fit the island's quiet exploration tone.
- One resident model that can drive overworld presence, talk cues, talk progression, objectives, and journal notes.
- Data-driven authoring so resident writing and appearance do not get scattered across scene files.
- Lightweight progression hooks that work with the current speech-balloon interaction style instead of requiring a full dialogue UI.

## Current System At A Glance

The live resident flow is:

1. [`../game/resident_catalog.gd`](../game/resident_catalog.gd) defines the static resident roster, content, appearance presets, and spawn metadata.
2. [`../game/app_state.gd`](../game/app_state.gd) clones those defaults into mutable runtime `resident_profiles` and exposes all resident-facing getters.
3. [`../main.gd`](../main.gd) caches supported spawn anchors, spawns the roster under the shared `actors/Residents` layer, and turns player `R` input into resident talk interactions.
4. [`../characters/control/base_controller.gd`](../characters/control/base_controller.gd) filters nearby targets to the same absolute z layer before closest-target or speech logic can use them.
5. [`../characters/control/npc_controller.gd`](../characters/control/npc_controller.gd) applies each resident's appearance, shows the nearby `...` cue, reveals the current talk line after interaction, and keeps stationary residents facing the player while nearby.
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
- If a future feature needs resident progression to affect more than the local scene, it should probably enter through `AppState` instead of being hidden in `main.gd` or `npc_controller.gd`.

### Shared Actor Layer Is Required

- In the main overworld, the player and resident instances live under the same y-sorted `actors` branch in [`../main.tscn`](../main.tscn).
- This is required for believable overlap and draw order. If the player and residents are split into separate visual layers, depth cues break quickly.
- The shared y-sorted actor layer is a rendering rule, not just a convenience for the current implementation.

### Same-Layer Targeting Is Required

- Proximity alone is not enough for interaction. [`../characters/control/base_controller.gd`](../characters/control/base_controller.gd) rejects nearby targets unless they share the same absolute z value as the active character.
- That rule protects stacked spaces and portal-driven traversal from cross-layer talk prompts, accidental auto-speech, or misleading target selection.
- If future work changes portals, stacked traversal, or NPC movement between layers, re-validate this rule instead of assuming the older behavior still holds.

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

The main scene supports five anchor ids today:

- `Piano Ferry`
- `Trinity Church`
- `Bagua Tower`
- `Bi Shan Tunnel South`
- `Long Shan Tunnel South`

This shared-anchor-plus-offset model is intentionally cheap to author. It is less precise than dedicated placement markers, but it keeps roster iteration fast while the island layout is still moving.

### Appearance Payload

- `appearance` is a `HumanBody2D.set_configuration()` payload assembled by `_look(...)` in [`../game/resident_catalog.gd`](../game/resident_catalog.gd).
- Resident looks should continue to be authored in the catalog, not hardcoded in scene instances.

## Current Player-Facing Behavior

- Approaching a same-layer resident changes the hint from `Inspect` to `Talk to <resident>`.
- A nearby resident shows `...` in the speech balloon until the player presses `R`.
- Pressing `R` runs `AppState.interact_with_resident(resident_id)` through [`../main.gd`](../main.gd).
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

Use [`../main.tscn`](../main.tscn) when validating:

- full-roster spawning
- anchor placement
- journal updates in normal gameplay flow
- hint text and objective updates in the real HUD
- actor-layer y-sorting against the player

### Fast Resident Content Check

Use [`../scenes/test_scene.tscn`](../scenes/test_scene.tscn) when you want a faster sandbox for:

- resident appearance
- cue-bubble and revealed-line behavior
- talk-beat progression
- journal text changes

This scene is better when the bug is about resident content or presentation rather than world layering.

### Layer And Portal Check

Use [`../scenes/test_npc_layer_interaction.tscn`](../scenes/test_npc_layer_interaction.tscn) when changing:

- same-layer targeting rules
- `BaseController` proximity filtering
- player/NPC z-index expectations
- portal-driven layer changes
- stacked NPC interaction behavior

This sandbox deliberately places residents on multiple z layers and uses a portal transition to move the player between them. The portal's cyan debug zone is drawn from its actual collision shape, so if the portal size changes the visible test affordance should change with it.

## Debugging Shortcuts

When the system breaks, start here:

- Resident missing entirely:
  - Check `resident_order()` and the resident entry in [`../game/resident_catalog.gd`](../game/resident_catalog.gd).
  - Check `AppState.get_resident_ids()` and `get_resident_spawn_config()`.
  - Check for missing anchor warnings from [`../main.gd`](../main.gd).
- Resident appears but has the wrong look:
  - Check `resident_id` on the instantiated controller.
  - Check `AppState.get_resident_appearance_config()` and `NPCController._apply_resident_presentation()`.
- Prompt says `Inspect` instead of `Talk`:
  - Check whether the target is actually using `NPCController`.
  - Check same-layer gating in [`../characters/control/base_controller.gd`](../characters/control/base_controller.gd).
- Resident talks across layers:
  - Check absolute z values first, not just node parentage or local `z_index`.
- Journal text looks stale:
  - Check `AppState.interact_with_resident()`, `resident_profile_changed`, and `build_resident_journal_text()`.
- Spawn feels visually wrong:
  - Check the catalog `offset` before adding a new anchor id.

## Extension Guardrails

- Preserve the catalog as the source of truth for authored resident content.
- Keep shared resident progression in [`../game/app_state.gd`](../game/app_state.gd), not in scene-local nodes.
- Keep world wiring in [`../main.gd`](../main.gd) and controller scripts.
- Keep journal rendering thin. If the resident note shape changes, change the data producer first.
- If new resident movement or schedules are added, keep authored schedule data in the catalog and runtime movement logic in world/controller code.
- If anchor ids, resident profile keys, or same-layer targeting rules change, update:
  - [`features/npc_system.md`](features/npc_system.md)
  - [`contracts.md`](contracts.md)
  - [`architecture.md`](architecture.md)
  - [`module_map.md`](module_map.md)

## Current Limits And Intentional Gaps

- Residents are still stationary in the shipped slice.
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
