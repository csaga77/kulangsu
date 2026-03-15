# Kulangsu NPC System Design

Read [`docs/design_brief.md`](docs/design_brief.md) first for the project summary. This doc covers the current resident-system slice and the intended direction for future NPC work.

## Goals

- Keep NPC interactions calm, local, and readable.
- Let residents drive objectives, melody clues, and journal notes.
- Reuse one resident data model across ambient speech, talk interactions, and UI.
- Stay compatible with the current speech balloon pattern instead of replacing it with heavy dialogue UI.

## Current Implementation

### Resident Catalog

- Static resident content lives in [`game/resident_catalog.gd`](game/resident_catalog.gd).
- Each resident entry defines:
  - display name
  - home landmark
  - role and routine note
  - melody hint
  - appearance preset
  - spawn anchor and overworld placement offset
  - ambient speech lines
  - talk interaction beats

This keeps resident writing in one place instead of scattering strings across scene scripts.

### Runtime Resident State

- [`game/app_state.gd`](game/app_state.gd) now stores runtime resident profiles.
- Runtime fields include:
  - `known`
  - `trust`
  - `conversation_index`
  - `quest_state`
  - `current_step`

Resident interactions update the same shared state the HUD and journal already read from, which keeps the UI aligned with gameplay progress.

### NPC Controller Hook

- [`characters/control/npc_controller.gd`](characters/control/npc_controller.gd) now exposes `resident_id`.
- Resident appearance presets are applied automatically to `HumanBody2D` from the resident catalog.
- Ambient speech balloons pull from the resident profile in `AppState`.
- JSON behavior trees can still be used for autonomous motion, but prototype residents can disable them and remain stationary.

### Talk Interaction Flow

- [`main.gd`](main.gd) now distinguishes NPCs from generic inspectables.
- When the player is near a resident:
  - the hint changes from `Inspect` to `Talk`
  - pressing `R` advances that resident's talk beat
  - the objective, chapter, save status, and resident notes can all update from that beat

This gives the project a lightweight "full conversation" stand-in before a dedicated dialogue panel exists.

### Journal Integration

- [`ui/screens/journal_overlay.gd`](ui/screens/journal_overlay.gd) now renders resident notes instead of only a flat resident name list.
- The resident tab currently shows:
  - role
  - usual location
  - trust level
  - current lead
  - melody clue

That matches the design goal from [`docs/core_game_workflow.md`](docs/core_game_workflow.md): resident notes should answer who the person is, where they are found, and why they matter.

## Prototype Coverage

### Main Overworld

- [`main.gd`](main.gd) now spawns the full 30-resident roster from catalog-defined spawn metadata.
- The main scene keeps the player and resident instances under one shared y-sorted actor layer so characters sort against each other consistently.
- Spawn anchors currently map to five overworld hubs:
  - Piano Ferry
  - Trinity Church
  - Bi Shan Tunnel south entrance
  - Long Shan Tunnel south entrance
  - Bagua Tower
- This keeps the overworld population testable without hand-placing 30 separate scene instances.

### Sandbox Scene

- [`scenes/test_scene.tscn`](scenes/test_scene.tscn) now maps its three NPCs to resident ids.
- Use this scene as the faster sandbox for checking:
  - ambient speech
  - talk prompts
  - resident journal updates
  - progression between conversation beats

## Data Model Rules

- Ambient speech should stay short enough for a speech balloon.
- Talk beats should be able to update gameplay state without needing custom one-off code per resident.
- Trust is a lightweight pacing signal, not a deep relationship simulator.
- Resident data should prefer landmark context and melody clues over exposition dumps.

## Best Next Steps

1. Add a dedicated dialogue overlay for longer resident conversations, while keeping speech balloons for ambient lines.
2. Replace the shared hub anchor offsets with dedicated scene markers if individual resident placement needs finer art-direction control.
3. Connect resident beats to landmark quest state so residents can unlock and resolve district arcs directly.
4. Add postgame resident variants so the same system can support festival and free-walk dialogue changes.
