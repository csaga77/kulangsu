# BGM System Implementation Plan

Read [`bgm_system.md`](bgm_system.md) and [`bgm_tagging_guide.md`](bgm_tagging_guide.md) first, then use this file as the implementation-status and next-steps companion.

## Current Status

The V1 weighted BGM controller is already in the project.

Shipped files:

- `game/bgm_catalog.gd` — 7-track seed pool with location, progress, time, season, and weather weights
- `game/bgm_manager.gd` — runtime BGM controller with weighted selection, recent history, commitment window, fade/gap handling, and location-triggered reselection
- `scenes/game_main.gd` — scene-owned BGM manager setup
- `default_bus_layout.tres` — `BGM` bus
- `game/tests/bgm/test_bgm_manager.tscn` — focused regression scene for lazy loading, natural-end fade scheduling, and location fallback behavior

Current V1 scope:

- Real catalog/controller architecture, not a placeholder loop
- Live context from `AppState.location` and melody progress
- Deferred defaults of `afternoon`, `summer`, and `clear`
- Single-file playback, no layered variants
- 45-second minimum commitment window
- Recent-history exclusion with explicit fallback order
- Natural silence gaps between tracks
- Natural-end fade scheduling before loop completion

## Completed Work

### Phase 1 — Foundation

Done:

- Seed pool catalog in `game/bgm_catalog.gd`
- Scene-owned runtime controller in `game/bgm_manager.gd`
- `game_main` integration
- `BGM` audio bus wiring

Validation already in place:

- Headless project startup
- Startup track selection in the gameplay scene
- Focused BGM regression scene in `game/tests/bgm/test_bgm_manager.tscn`

### Phase 2 — Reliability Pass

Done:

- Startup catalog validation no longer preloads every stream
- Natural-end fades are scheduled before track completion
- Location-only fallback prefers non-recent alternatives before relaxing history

## Remaining Work

### Phase 3 — Live Tuning

Priority: next

- Walk Ferry Plaza, Trinity Church, both tunnels, and Bagua Tower in-editor
- Tune location weights for the 7-track seed pool
- Tune fade and gap timing based on how the island actually feels in motion
- Confirm overlay and pause behavior matches the intended tone

Recommended validation:

- One manual island loop in Story mode
- One manual island loop in Free Walk mode

### Phase 4 — Debug Visibility

Add lightweight BGM debugging so tuning does not depend on log reading alone.

Recommended additions:

- Current track label
- Current context snapshot
- Recent-history buffer
- Optional manual reselection trigger for testing

### Phase 5 — Motifs And Ambient Layers

These are the highest-value follow-ons after the base BGM controller feels stable.

- Landmark motif system on a separate `Motif` bus
- Ambient environmental loops on a separate `Ambient` bus
- Clear ownership boundaries so motifs do not mutate the BGM selector directly

### Phase 6 — Content Expansion

Expand only after the seed pool feels right in motion.

- Add more Island Commons and Location-Leaning tracks
- Add exclusive tracks beyond `after_the_stage`
- Add variants only after the base pool is stable

Variant policy remains:

- progress variant > weather variant > seasonal variant > base track
- one resolved file at a time
- no layered variants

### Phase 7 — Future Context Systems

Deferred until the island-side systems exist:

- Real time-of-day input
- Real season input
- Real weather input

When they land:

- Update `BgmManager` context wiring
- Preserve the same fallback order
- Keep progress changes soft: no hard reselection mid-track

### Phase 8 — Piano Integration

Keep this after overworld audio is stable.

- Reuse melody-progress state, not a parallel music progression model
- Let piano gameplay influence future track choice only at well-defined boundaries
- Avoid making the overworld BGM manager responsible for piano gameplay audio

## Validation Checklist

Use this when touching the BGM system again.

- Headless startup still exits cleanly
- `game/tests/bgm/test_bgm_manager.tscn` passes
- Startup selects a real playable track
- Recent-history exclusion still prevents obvious repeats
- Natural-end fade still begins before the stream finishes
- Location-change reselection still waits for the commitment window
- Manual island walk still sounds calm instead of busy

## Open Questions

1. Should overlays pause BGM, duck it slightly, or leave it untouched?
2. Should Free Walk eventually bias the same pool differently, or stay identical to Story mode?
3. When landmark motifs arrive, should they briefly duck BGM or sit fully independently on the mix?
