# Practice System

Design doc for the practice and performance layer. No implementation exists yet. Read this before adding any practice or performance state to the game.

## Goal

- Give the player a way to engage with a melody fragment before performing it at a landmark.
- Keep the interaction low-stakes, short, and emotionally clear. Recognition matters more than dexterity.
- Establish a shared model that all four landmark performance points can reuse.

## User / Player Experience

After collecting one or more melody fragments, the player should feel that they "know" the phrase well enough to reproduce it at the landmark's performance point. The practice layer exists to make that transition feel earned rather than automatic.

The experience should be: hear a short phrase → confirm you recognize it → perform it at the right place → the world responds. There should be no long rhythm-game stage, no score, and no hard fail. A wrong attempt produces gentle corrective feedback and lets the player try again immediately.

## Recommended Design

### Practice vs. Performance Distinction

**Practice** is optional preparation that can happen anywhere a melody fragment is "known." The player can trigger it from the journal Melody tab or from a landmark's ambient cue. It gives the player a chance to hear the phrase and confirm the contour before committing to the performance point.

**Performance** is the landmark-specific activation that awards the fragment and changes the world. It requires the player to be at the correct performance landmark and have the necessary melody state.

Keeping these two separate means the practice layer can be built and tested independently of the performance trigger.

### Melody Tier Gating

| Tier | Player can… |
|---|---|
| `heard` | Trigger a passive listen (no input required). |
| `reconstructed` | Trigger a simple recognition prompt. |
| `performed` | World response is live; repeat performance available as ambient replay. |
| `resonant` | Full island resonance; ambient-only, no further player input required. |

For the first implementation, only `reconstructed` and above need an active interaction. `heard` can be a passive listen that plays audio (when audio exists) or shows a short descriptive line.

### Recognition Prompt (First Version)

The simplest workable first version is a **short ordered confirmation**: the player sees 2–4 phrase segments labeled by their source (e.g. "Harbor Opening", "Church Phrase", "Tunnel Echo") and selects them in the order that feels right for the melody contour.

- Order is shown as a list, not a notation UI.
- A correct sequence moves the melody to `performed` at the landmark.
- An incorrect sequence shows a short hint ("That order felt reversed — try starting from the harbor phrase.") and lets the player try again with no penalty.
- There is no time limit.

This avoids requiring the `piano_game` module before the first performance lands.

### Performance Point Activation

Each landmark has one performance point: a `LandmarkTrigger` (or equivalent Area2D) placed at the canonical performance spot listed in `melody_catalog.gd`. The player presses R at that node when the melody is in `reconstructed` state. The recognition prompt opens. On success, `AppState` advances the melody to `performed` and fires the world response.

Current performance landmark for `festival_melody`: **Bagua Tower** (as defined in `melody_catalog.gd`).

For Trinity Church specifically: the chime activation at the end of the choir cue arc is effectively the first performance point, simplified. The current implementation resolves it implicitly through the caretaker's resolved beat. When a proper performance system exists, this can be upgraded to use the recognition prompt at the church performance spot before the beat fires.

## Rules

- Practice is always optional. Skipping practice does not block performance.
- Performance requires the melody to be in `reconstructed` state or higher.
- Performance requires the player to be at the melody's `performance_landmark`.
- A failed recognition attempt is not a fail state. The player retries immediately.
- Performance state is stored in `AppState.melody_progress[melody_id]["performed"]`.
- The `piano_game` module is a candidate for the full performance interaction but should not be required for the first working version.
- Free Walk mode should allow performance replay without re-advancing melody state.

## Edge Cases

- Player reaches the performance landmark before reconstructing the melody: show a "the phrase is not ready yet" message and do not open the prompt.
- Player already performed the melody: show a "replay" option instead of the main prompt; replay does not re-award the fragment.
- The performance prompt should fail softly if the melody catalog entry is missing. Log a warning and do not crash.
- Free Walk seeds melody state differently; practice and performance in Free Walk should read from AppState normally but not set story chapter.

## Architecture / Ownership

- `AppState` owns the `performed` flag per melody and the state transition to `performed`.
- `melody_catalog.gd` owns the `performance_landmark` and `performance_prompt` fields per melody.
- A future `PerformanceTrigger` or extended `LandmarkTrigger` node will own the in-world activation point.
- The recognition prompt UI belongs in a new overlay or a dedicated screen script under `ui/screens/`. It should not live in `AppState` or `main.gd`.
- The `piano_game` module can be integrated as the recognition prompt backend once the interface is stable.

## Relevant Files

- Shared state or catalogs:
  - [`../../game/app_state.gd`](../../game/app_state.gd) — `melody_progress[id]["performed"]`, `melody_progress[id]["state"]`
  - [`../../game/melody_catalog.gd`](../../game/melody_catalog.gd) — `performance_landmark`, `performance_prompt` per melody
  - [`../../game/piano_game/piano_game.gd`](../../game/piano_game/piano_game.gd) — candidate performance backend (currently standalone)
- Related docs:
  - [`core_melody_loop.md`](core_melody_loop.md) — MVP Step 5 (Add One Performance Point)
  - [`trinity_church.md`](trinity_church.md) — first simplified performance point
  - [`../contracts.md`](../contracts.md) — Shared State Contract
  - [`../core_game_workflow.md`](../core_game_workflow.md) — Festival Finale section

## Contracts / Boundaries

- When this system is implemented, add a `PerformanceTrigger` contract to `contracts.md`.
- If the `performed` flag shape or the melody state transition rules change, update `contracts.md` (Shared State Contract).
- The recognition prompt UI must not write melody state directly. It should call `AppState` setters only.

## Validation

Once implemented:
- Reach Bagua Tower with `festival_melody` in `reconstructed` state.
- Press R at the performance point. Confirm the recognition prompt opens.
- Complete the prompt correctly. Confirm `performed` flag is set and the journal Melody tab updates.
- Attempt the prompt with incorrect order. Confirm gentle feedback and immediate retry.
- Return to the performance point after performing. Confirm the replay option appears instead of the main prompt.

## Out Of Scope

- Long rhythm-game stages or score-attack ranking.
- Mandatory dexterity input (precise timing, held notes, multi-finger chords).
- Full `piano_game` integration before the first working recognition prompt exists.
- Separate practice mini-game screen. The first version is embedded in the journal or world.
