# BGM System Implementation Plan

Read `bgm_system.md` and `bgm_tagging_guide.md` first, then this file.

## Overview

Six phases to implement the weighted BGM selection system. Critical path: **Catalog → Selection Engine → BGM Manager → game_main integration.** The system can be built and tested before any real audio assets exist using placeholder tracks.

## New Files

| File | Phase | Purpose |
|---|---|---|
| `game/bgm_catalog.gd` | 1 | Track definitions with affinity weights |
| `game/bgm_time_system.gd` | 1 | Time-of-day context provider (stub with defaults) |
| `game/bgm_season_system.gd` | 1 | Season/weather context provider (stub with defaults) |
| `game/bgm_selection_engine.gd` | 2 | Weighted-random selection logic |
| `game/bgm_manager.gd` | 2 | Playback state machine, transitions, commitment window |
| `scenes/bgm_player.tscn` + `.gd` | 3 | AudioStreamPlayer wrapper with fade/gap support |
| `game/tests/test_bgm_catalog.gd` | 5 | Catalog structure validation |
| `game/tests/test_bgm_selection_engine.gd` | 5 | Scoring, selection, history, exclusivity tests |
| `scenes/tests/test_bgm_manager.tscn` + `.gd` | 5 | Scene integration test |

## Files to Modify

| File | Phase | Change |
|---|---|---|
| `default_bus_layout.tres` | 3 | Add BGM, BGM_LocationFX, Ambient, Motif, SFX, UI buses |
| `scenes/game_main.gd` | 3 | Instantiate BGM Manager, wire AppState signals, initialize context |
| `scenes/game_main.tscn` | 3 | Add BGM Player node |
| `docs/architecture.md` | 6 | Register BGM subsystem |
| `docs/contracts.md` | 6 | Add BGM Manager contract (ownership, signals, API) |
| `docs/module_map.md` | 6 | Add BGM files to directory map |

## Phase 1 — Foundation (no audio assets needed)

No dependencies between these three files. Can build in parallel.

### 1.1 BGM Catalog (`game/bgm_catalog.gd`)

Follow the existing `MelodyCatalog` pattern: `class_name BgmCatalog`, static `build_catalog()` returning a Dictionary keyed by track ID.

Each entry contains:
- `file`: resource path (`res://resources/audio/music/bgm/...`)
- `tier`: `"commons"`, `"location"`, or `"exclusive"`
- `duration`: seconds (for commitment window tracking)
- `location`: Dictionary of zone → weight (0.0–1.0)
- `time`: Dictionary of period → weight
- `progress`: Dictionary of tier → weight
- `season`: Dictionary of season → weight
- `weather`: Dictionary of weather → weight
- `variants`: Dictionary of context → file path (optional)

Start with 5–8 placeholder entries to validate the system before tagging all tracks.

**Validation:** Parse catalog, verify all weight groups present, all values 0.0–1.0, at least one value > 0.0 per group.

### 1.2 BGM Time System (`game/bgm_time_system.gd`)

Exposes:
- `get_current_time_period() -> String` — returns `"morning"`, `"afternoon"`, `"evening"`, or `"night"`
- Signal: `time_period_changed(period: String)`

Default behavior: returns `"afternoon"` until a real time-of-day system exists.

**Validation:** Call method, verify valid return value.

### 1.3 BGM Season System (`game/bgm_season_system.gd`)

Exposes:
- `get_current_season() -> String` — returns `"spring"`, `"summer"`, `"autumn"`, or `"winter"`
- `get_current_weather() -> String` — returns `"clear"`, `"rain"`, `"fog"`, or `"wind"`
- Signals: `season_changed(season: String)`, `weather_changed(weather: String)`

Default behavior: returns `"summer"` and `"clear"` until real systems exist.

**Validation:** Call methods, verify valid return values.

## Phase 2 — Selection Logic

Depends on Phase 1.

### 2.1 BGM Selection Engine (`game/bgm_selection_engine.gd`)

Static methods:

- `score_track(track: Dictionary, context: Dictionary) -> float`
  - Multiply: `location[zone] × time[period] × progress[tier] × season[season] × weather[weather]`
  - If any factor is 0.0, return 0.0

- `select_next_track(catalog: Dictionary, context: Dictionary, recent_history: PackedStringArray) -> String`
  - Score all tracks
  - Zero out tracks in recent history buffer
  - Zero out Tier 3 tracks whose exclusive conditions are not met
  - Normalize remaining scores to probabilities
  - Weighted random selection via `randf()`
  - Return selected track ID

- `filter_exclusive_conditions(track: Dictionary, context: Dictionary) -> bool`
  - Check if a Tier 3 track's conditions are satisfied (factors with 0.0 must not match current context)

- `select_variant(track_id: String, track: Dictionary, context: Dictionary) -> String`
  - Priority: progress variant > weather variant > seasonal variant > base file
  - Return the resolved file path

**Validation:** Unit tests with hardcoded catalogs and contexts. Verify scoring math, history filtering, exclusive enforcement, variant resolution. Run 100+ selections and verify distribution clusters around expected probabilities.

### 2.2 BGM Manager (`game/bgm_manager.gd`)

State machine that orchestrates playback. Owned by game_main scene.

State:
- `current_track_id: String`
- `current_file: String`
- `play_start_time: float`
- `commitment_window_expiry: float`
- `recent_history: PackedStringArray` (3-track FIFO)
- `current_context: Dictionary` (location, time, progress, season, weather)
- `pending_location: String` (queued location change during commitment window)

Public API:
- `set_location(location: String)` — update location context, trigger reselection if outside commitment window
- `set_context(context: Dictionary)` — update any/all context factors
- `request_reselection()` — force next-track selection (for testing)
- `get_current_track_id() -> String`
- `get_is_in_commitment_window() -> bool`

Internal:
- `_select_and_play_next_track()` — pull from selection engine, resolve variant, play with fade-in
- `_on_track_finished()` — schedule silence gap (5–15s randomized) then next selection
- `_on_location_changed(location: String)` — from AppState; queue or trigger reselection
- `_on_fragments_changed()` — from AppState; update progress context for next selection
- `_calculate_progress_tier() -> String` — derive from AppState melody_progress
- `_process(delta)` — check commitment window expiry; if expired and pending location change, trigger reselection

Transition timings:
- Track ending naturally: 3–5s fade-out
- Location-triggered reselection: 4–6s fade-out, silence gap, 2–3s fade-in
- Weather change: 6–8s fade-out (slower), gap, fade-in
- Progress change: continue to natural end, next selection uses new context

Signals (for debugging/logging):
- `track_selected(track_id: String, file: String)`
- `track_started_playing(track_id: String)`

**Validation:** Integration tests with mock AppState. Verify commitment window prevents rapid reselection, location change queues correctly, history buffer works, silence gaps apply.

## Phase 3 — Scene Integration

Depends on Phase 2.

### 3.1 BGM Player (`scenes/bgm_player.tscn` + `.gd`)

Scene structure:
```
BGMPlayer (Node)
├── AudioStreamPlayer (routes to BGM bus)
└── SilenceTimer (Timer, one-shot, for silence gaps)
```

Script wraps AudioStreamPlayer:
- `play_track(file_path: String, fade_in_duration: float)`
- `stop_track(fade_out_duration: float)`
- `is_playing() -> bool`
- Fade in/out via Tween
- Connect `AudioStreamPlayer.finished` to notify BGM Manager
- Connect `SilenceTimer.timeout` to notify BGM Manager

**Validation:** Manually call play/stop/fade, verify audio bus routing and tween behavior.

### 3.2 Audio Bus Layout (`default_bus_layout.tres`)

Upgrade to:
```
Master
├── BGM
│   └── BGM_LocationFX (per-zone effects: reverb for tunnels, high-pass for tower)
├── Ambient (environmental loops — waves, wind, rain sfx)
├── Motif (landmark fragment motifs, one-shot)
├── SFX (gameplay sound effects)
└── UI (menu and overlay sounds)
```

Preserve existing buses (`New Bus`, `BeatCapture` from piano game).

**Validation:** Open audio bus dock in Godot editor, verify structure.

### 3.3 game_main Integration

Modifications to `scenes/game_main.gd`:
- In `_ready()`: instantiate BGM Manager and BGM Player as child nodes
- Wire signals:
  - `AppState.fragments_changed → bgm_manager._on_fragments_changed`
  - Location zone enter/exit → `bgm_manager.set_location()`
- Initialize context with current state (location, progress tier)
- Request first track selection

Modifications to `scenes/game_main.tscn`:
- Add BGMPlayer node as child (not affected by y_sort)

**Validation:** Run game, verify BGM starts on island entry, changes on location change, updates on fragment pickup.

## Phase 4 — Variants and Future Hooks

### 4.1 Variant Resolution

Extend BGM Manager's `_select_and_play_next_track()` to call `select_variant()` before playing. This resolves the correct file based on current season/weather/progress.

**Validation:** Catalogs with variant entries; verify correct file chosen per context.

### 4.2 Time-of-Day Integration (future)

When a real time-of-day system is built:
- Replace `bgm_time_system.gd` defaults with actual clock logic
- Connect `time_period_changed` signal to BGM Manager
- BGM Manager updates context and considers reselection at period transitions

### 4.3 Season/Weather Integration (future)

When a real weather/season system is built (note: `scenes/tests/test_weather.tscn` already exists):
- Replace `bgm_season_system.gd` defaults with actual values
- Connect `season_changed` and `weather_changed` signals to BGM Manager
- Weather change triggers 6–8s fade-out and reselection

## Phase 5 — Testing

### 5.1 Unit Tests

`game/tests/test_bgm_catalog.gd`:
- Catalog structure validity
- Weight ranges (0.0–1.0)
- All five factor groups present per track
- At least one value > 0.0 per group

`game/tests/test_bgm_selection_engine.gd`:
- Scoring math (product of five weights)
- History buffer filtering
- Exclusive condition enforcement
- Weighted distribution (100+ selections cluster around expected probabilities)
- Variant priority (progress > weather > season > base)

### 5.2 Scene Integration Tests

`scenes/tests/test_bgm_manager.tscn` + `.gd`:
- Commitment window prevents rapid reselection (45s)
- Location change after window triggers reselection
- Location change during window queues for next opportunity
- Fragment pickup updates progress context
- Recent history buffer prevents repeats
- Silence gaps apply between tracks
- Exclusive tracks only play when conditions met

### 5.3 Full Playthrough Test

Run game_main end-to-end:
- BGM starts on scene ready
- Move player between locations; verify BGM updates after commitment window
- Pick up fragments; verify progress context updates
- Run 5+ minutes; verify variety, no crashes, no infinite loops

## Phase 6 — Documentation

Update existing docs to register the BGM subsystem:

- `docs/architecture.md` — add BGM system under main systems, note ownership by game_main
- `docs/contracts.md` — add BGM Manager contract: signals it listens to, API it exposes, what it reads from AppState
- `docs/module_map.md` — add all new BGM files to the directory map

## Build Order

```
Phase 1 (parallel, no deps):
  1.1 bgm_catalog.gd
  1.2 bgm_time_system.gd
  1.3 bgm_season_system.gd

Phase 2 (sequential, depends on Phase 1):
  2.1 bgm_selection_engine.gd
  2.2 bgm_manager.gd

Phase 3 (depends on Phase 2):
  3.1 bgm_player.tscn + .gd
  3.2 default_bus_layout.tres
  3.3 game_main integration

Phase 4 (extends Phase 3):
  4.1 Variant resolution

Phase 5 (parallel with Phase 4):
  5.1 Unit tests
  5.2 Scene integration tests
  5.3 Full playthrough

Phase 6 (parallel, non-blocking):
  6.1 Documentation updates
```

## Validation Checkpoints

| Checkpoint | What to Verify | After |
|---|---|---|
| Catalog validity | Structure, weight ranges, all factors present | Phase 1.1 |
| Context providers | Valid return values from time/season/weather stubs | Phase 1.2, 1.3 |
| Selection math | Scoring, distribution, history, exclusivity | Phase 2.1 |
| State machine | Commitment window, context updates, transitions | Phase 2.2 |
| Audio playback | Fade in/out, silence gaps, bus routing | Phase 3.1 |
| End-to-end | BGM plays on startup, responds to location/progress changes | Phase 3.3 |

## Open Questions

1. **Overlay behavior** — should BGM pause, duck volume, or continue during journal/pause/melody prompt overlays? Recommendation: continue playing (it's ambient), optionally duck volume during overlays.

2. **Free Walk mode** — same BGM pool with different weights, or separate pool? Current assumption: same pool.

3. **Save/load persistence** — should recent history buffer persist across save/load? If not, loading a game may replay a recent track. Recommendation: don't persist; the buffer is short-lived and the player won't notice.

4. **Float precision** — if weights are very small (e.g., 0.01 × 0.05 × 0.1 × 0.3 × 0.2 = 0.00003), normalization could hit rounding issues. Add an epsilon check or minimum score threshold to avoid zero-denominator edge cases.

5. **Catalog authoring order** — 44 existing OGG files need tagging. Build and validate with 5–8 tracks first, then expand incrementally. The tagging guide (`bgm_tagging_guide.md`) has the workflow.

## Risks

1. **AudioStreamPlayer lifecycle** — if game_main unloads unexpectedly, BGM Manager must clean up gracefully in `_exit_tree()`.

2. **Tween stutter under load** — fade transitions may stutter if the game is CPU-heavy. Test with profiler; consider `TRANS_LINEAR` for safety.

3. **Exclusive condition edge cases** — a track exclusive to both "rain" AND "night" simultaneously needs both conditions met. The filter logic must AND all zero-weight exclusions, not OR them.

4. **Large catalog performance** — scoring 50 tracks on every selection is cheap (50 multiplications + normalization), but verify it doesn't cause frame hitches when triggered during gameplay.
