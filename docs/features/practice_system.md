# Practice System

Design doc for the practice and recognition layer that now sits between fragment recovery and the final harbor-stage performance. The first ordered-confirmation prompt is live; this doc captures the shipped first pass plus the follow-on expansion points.

## Goal

- Give the player a way to engage with a melody fragment before performing it at a landmark.
- Keep the interaction low-stakes, short, and emotionally clear. Recognition matters more than dexterity.
- Establish a shared model that all four landmark performance points can reuse.

## User / Player Experience

After collecting enough melody fragments to reconstruct the phrase, the player should feel that they "know" it well enough to reproduce it at the landmark's performance point. The practice layer exists to make that transition feel earned rather than automatic.

The experience should be: hear a short phrase → confirm you recognize it → perform it at the right place → the world responds. There should be no long rhythm-game stage, no score, and no hard fail. A wrong attempt produces gentle corrective feedback and lets the player try again immediately.

## Recommended Design

### Practice vs. Performance Distinction

**Practice** is optional preparation that can happen once the melody is `reconstructed`. The current first pass is triggered from the journal Melody tab. It gives the player a chance to order the known phrase segments before committing to the performance point.

**Performance** is the landmark-specific activation that awards the fragment and changes the world. It requires the player to be at the correct performance landmark and have the necessary melody state.

Keeping these two separate means the practice layer can be built and tested independently of the performance trigger.

### Melody Tier Gating

| Tier | Player can… |
|---|---|
| `heard` | Trigger a passive listen (no input required). |
| `reconstructed` | Trigger a simple recognition prompt. |
| `performed` | World response is live; repeat performance available as ambient replay. |
| `resonant` | Full island resonance is live; optional journal replay can remain available, but no new mandatory input is introduced. |

The current first pass only offers the active prompt at `reconstructed` and above. `heard` remains journal/context flavor rather than an input-driven prompt.

### Recognition Prompt (First Version)

The shipped first version is a **short ordered confirmation**: the player sees 2–4 known fragment segments labeled by their source landmark and selects them in the order that feels right for the melody contour.

- Order is shown as a list, not a notation UI.
- Each segment tap now plays a short feedback tone so the player hears the phrase assemble as they select it.
- A correct sequence completes rehearsal immediately, or moves the melody to `performed` when the prompt was opened from the landmark performance point.
- An incorrect sequence shows a short hint and lets the player try again with no penalty.
- Correct and wrong submissions now play short confirmation sounds, and the prompt ducks BGM for the full overlay lifetime so those cues remain audible.
- There is no time limit.

This avoids requiring the `piano_game` module before the first performance lands.

### Performance Point Activation

Each landmark can have one performance point: a `StorySubjectArea2D` placed at the canonical performance spot listed in `melody_catalog.gd`. The player presses R at that node when the melody is in `reconstructed` state and any story-side gating for that performance point is satisfied. The recognition prompt opens. On success, `AppState.complete_prompt_request(...)` advances the melody or landmark and fires the appropriate world response.

Current landmark-specific uses of the reusable prompt for `festival_melody`:

- **Trinity Church**: choir chime after `steps -> garden -> yard`
- **Bi Shan Tunnel**: mural chamber after the three echo markers are traced
- **Long Shan Tunnel**: exit route after the two lit pockets are steadied
- **Festival Stage** at Piano Ferry: final harbor performance point

Bagua Tower still uses the simpler synthesis trigger plus Suyin follow-up dialogue for now.

## Rules

- Practice is always optional. Skipping journal practice does not block performance.
- Performance requires the melody to be in `reconstructed` state or higher.
- Performance requires the player to be at the melody's `performance_landmark`.
- The `festival_stage` performance point specifically requires both Bagua alignment and `spring_festival_resolved`, so the harbor performance cannot outrun the seasonal story.
- A failed recognition attempt is not a fail state. The player retries immediately.
- Performance state is stored in `AppState.melody_progress[melody_id]["performed"]`.
- The `piano_game` module is a candidate for the full performance interaction but should not be required for the first working version.
- Free Walk mode should allow performance replay without re-advancing melody state.

## Edge Cases

- Player reaches the performance landmark before reconstructing the melody: show a "the phrase is not ready yet" message and do not open the prompt.
- Player opens journal practice before reconstruction: keep the button disabled and do not open the prompt.
- Player already performed the melody: journal practice can still replay the ordered prompt; the world performance point itself remains hidden once collected.
- The performance prompt should fail softly if the melody catalog entry is missing. Log a warning and do not crash.
- Free Walk seeds melody state differently; practice and performance in Free Walk should read from AppState normally but not set story chapter.

## Architecture / Ownership

- `AppState` owns the public prompt-request/completion bridge plus the melody state it mutates, while authored StoryEvent world-event bindings now own landmark-specific prompt completions such as the Trinity choir chime, the Bi Shan chamber contour, the Long Shan exit route, and the harbor-stage performance.
- `game/landmark_progression.gd` now mainly owns generic melody-prompt validation/building and the remaining compatibility fallback path.
- `melody_catalog.gd` owns the `performance_landmark`, `performance_prompt`, and prompt segment ordering fields per melody.
- The in-world activation point still lives on a `StorySubjectArea2D` at Festival Stage.
- The recognition prompt UI now lives in `ui/screens/melody_prompt_overlay.*`. It owns the local select/correct/wrong one-shot sounds, but it does not write melody or landmark state directly; it reports the full prompt request back through the shell into `AppState.complete_prompt_request(...)`.
- `main.gd` owns prompt-lifetime BGM ducking by telling the live gameplay scene to duck or release its `BgmManager` when the overlay opens and closes.
- The `piano_game` module can be integrated as the recognition prompt backend once the interface is stable.

## Relevant Files

- Shared state or catalogs:
  - [`../../game/app_state.gd`](../../game/app_state.gd) — prompt request/completion methods plus `melody_progress[id]["performed"]`, `melody_progress[id]["state"]`
  - [`../../game/melody_catalog.gd`](../../game/melody_catalog.gd) — `performance_landmark`, `performance_prompt`, and prompt-segment metadata per melody
  - [`../../game/piano_game/piano_game.gd`](../../game/piano_game/piano_game.gd) — candidate performance backend (currently standalone)
- UI:
  - [`../../ui/screens/melody_prompt_overlay.gd`](../../ui/screens/melody_prompt_overlay.gd) — ordered-confirmation prompt UI
  - [`../../ui/screens/journal_overlay.gd`](../../ui/screens/journal_overlay.gd) — journal-side practice entry point
- Related docs:
  - [`core_melody_loop.md`](core_melody_loop.md) — MVP Step 5 (Add One Performance Point)
  - [`trinity_church.md`](trinity_church.md) — first simplified performance point
  - [`../contracts.md`](../contracts.md) — Shared State Contract
  - [`../core_game_workflow.md`](../core_game_workflow.md) — Festival Finale section

## Contracts / Boundaries

- If the `performed` flag shape or the melody state transition rules change, update `contracts.md` (Shared State Contract).
- The recognition prompt UI must not write melody state directly. It should report completion back through the shell so `AppState` remains the state owner.

## Validation

- Reach the Festival Stage with `festival_melody` in `reconstructed` state and Spring Festival resolved.
- Reach the Trinity choir chime after collecting `steps`, `garden`, and `yard`. Confirm the same ordered-confirmation prompt opens and only then returns the objective to Mei.
- Reach the Bi Shan mural chamber after collecting all three echoes. Confirm the prompt opens before the fragment is awarded.
- Reach the Long Shan exit after both lit pockets. Confirm the route prompt opens before the fragment is awarded.
- Open the journal Melody tab after Bi Shan and confirm `Practice Festival Melody` is enabled.
- Complete the journal prompt correctly. Confirm the prompt closes and melody state remains unchanged.
- Press R at the performance point. Confirm the recognition prompt opens.
- Complete the prompt correctly. Confirm `performed` flag is set and the journal Melody tab updates.
- Attempt the prompt with incorrect order. Confirm gentle feedback and immediate retry.
- Return to the journal after performing. Confirm the button changes to replay language instead of the initial practice wording.

## Out Of Scope

- Long rhythm-game stages or score-attack ranking.
- Mandatory dexterity input (precise timing, held notes, multi-finger chords).
- Full `piano_game` integration before the first working recognition prompt exists.
- Separate practice mini-game screen. The first version is embedded in the journal or world.
