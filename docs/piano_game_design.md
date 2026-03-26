# Kulangsu Piano Game Design

Read [`design_brief.md`](design_brief.md) first for the minimum-token summary. Use this doc when working on the standalone piano mini-game prototype in [`../game/piano_game/piano_game.tscn`](../game/piano_game/piano_game.tscn) or when planning how short performance beats should integrate into the main game.

## Purpose

This document captures both:

- the current implementation shape of the `piano_game` prototype
- the intended design role of piano performance inside Kulangsu

The prototype is useful, but it should support the main island loop rather than drift into a separate arcade mode.

## Current Status

The current piano game is a standalone scene:

- Scene: [`../game/piano_game/piano_game.tscn`](../game/piano_game/piano_game.tscn)
- Runtime script: [`../game/piano_game/piano_game.gd`](../game/piano_game/piano_game.gd)
- Chart generator: [`../game/piano_game/beat_json_generator.gd`](../game/piano_game/beat_json_generator.gd)

It is not yet wired into the main app shell in [`../main.tscn`](../main.tscn), the gameplay HUD, or story progression in [`../game/app_state.gd`](../game/app_state.gd).

Today it behaves more like a self-contained prototype or authoring sandbox than a finished player-facing game mode.

## Design Role Inside Kulangsu

Piano interaction should reinforce the island fantasy:

- listening
- recall
- gentle performance
- emotional payoff

It should not become a long, punishing score-attack mode.

The right use cases are:

- confirming that the player recognized a short melody fragment
- resolving a landmark objective with a brief performance beat
- giving an in-world musical response after exploration and dialogue

The wrong use cases are:

- full-song arcade sessions as mandatory mainline content
- dense note spam that asks for expert rhythm-game skill
- UI-heavy mode swaps that break the calm exploration tone

## Current Runtime Flow

### 1. Song and chart load

[`../game/piano_game/piano_game.gd`](../game/piano_game/piano_game.gd) loads:

- an MP3 stream from `mp3_path`
- a beat JSON file from `json_path`, or from the derived `*.beats.json` path when `auto_json_from_mp3` is enabled

If either asset fails to load, the prototype should clear the active song and chart state rather than keep stale note data alive from a previous load.

The current example scene points at:

- [`../resources/audio/Kulangsu Breeze.mp3`](../resources/audio/Kulangsu Breeze.mp3)
- [`../resources/audio/Kulangsu Breeze.beats.json`](../resources/audio/Kulangsu Breeze.beats.json)

### 2. Chart shaping

The loaded onset list is transformed in a few steps:

- stride thinning and probability thinning
- minimum onset energy filtering
- minimum note interval filtering
- energy-band lane assignment

The result is a reduced chart meant to stay readable instead of mirroring every detected transient in the source audio.
If those filters remove every note, the prototype should fail the load instead of starting a meaningless zero-note run.

### 3. Lane layout

Lanes are derived from the unique characters in `key_chars`.

Important rules:

- one unique character equals one lane
- lanes are centered as a cluster in the viewport
- note density is distributed by onset-energy quantile instead of by original pitch

This means the scene is not simulating a real piano keyboard. It is a readability-first rhythm layer built on top of a melody track.

### 4. Note travel and judgement

Each note:

- spawns ahead of its hit time
- moves from `spawn_y` to `hit_y`
- is judged against `perfect`, `great`, and `good` timing windows
- becomes a miss if it passes beyond the late window

Judgement input should only be accepted while the song is actively playing so the end-state result stays stable once the phrase is over.

The current script also tracks:

- combo
- max combo
- weighted score out of 100
- per-result counts

### 5. End-of-song behavior

When the song and remaining notes are done, the script prints a final summary to the console.

This is enough for prototype evaluation, but a shipped version should expose completion and result data to the wider game flow instead of relying on console output.

## Beat JSON Contract

The current chart format written by [`../game/piano_game/beat_json_generator.gd`](../game/piano_game/beat_json_generator.gd) is a lightweight dictionary with:

- `bpm`
- `duration`
- `hop_seconds`
- `phase_offset`
- `beats`
- `onsets`
- `onset_energy`

`piano_game.gd` only depends on `onsets`, optional `onset_energy`, and optional `bpm`.

That makes the generator loosely coupled to the runtime scene, which is good for iteration.

## Chart Generation Intent

[`../game/piano_game/beat_json_generator.gd`](../game/piano_game/beat_json_generator.gd) is an authoring tool, not a final player feature.

Its job is to:

- capture the MP3 through an audio bus
- detect onset peaks
- estimate a beat grid
- measure local onset energy
- optionally filter onsets toward beat subdivisions
- write a reusable JSON chart beside the source track

This is appropriate for fast prototyping of short melody interactions.

It should stay editor-friendly and predictable, even if the analysis stays intentionally approximate.
If the target chart path is not writable, generation should fail explicitly instead of silently writing to an unrelated fallback path.

## Integration Rules For The Main Game

When this system is brought into the story flow, keep these rules true:

- Use it for short phrases or short payoff moments, not full-length songs by default.
- Prefer 3 or fewer lanes for core story beats unless a specific sequence proves otherwise.
- Keep charts sparse enough that first-pass success comes from recognition and timing, not memorization.
- Treat misses as soft friction, not failure states that eject the player from a story beat.
- Return the player to the overworld or dialogue outcome immediately after the phrase resolves.

## UI And Presentation Rules

The current prototype draws directly in world-space style with a minimal HUD. That is a good starting point for readability, but the production version should align with the broader Kulangsu UI direction:

- the screen should stay visually calm
- performance UI should feel embedded, not like a separate arcade shell
- results should resolve in-world first, with minimal overlay clutter
- prompts and lane labels should remain legible on the project's stretched viewport

If this scene is embedded into the main game, prefer a contained overlay or framed interaction state rather than a hard app-level mode break.

## Recommended Next Step

The next implementation step should be integration, not complexity expansion.

Specifically:

1. Trigger a short piano phrase from a landmark or resident interaction.
2. Feed success or partial success into [`../game/app_state.gd`](../game/app_state.gd).
3. Replace console-only completion with a clear callback, signal, or result payload that the app shell can consume.
4. Tune charts around emotional clarity and story readability before adding more difficulty options.

## Known Gaps In The Current Prototype

- No connection to main quest or landmark progression
- No app-shell overlay integration
- No explicit result handoff to the rest of the game
- No authored visual theming beyond debug-friendly primitives
- No distinction yet between practice mode, story mode, and optional challenge mode

Those are acceptable prototype limits, but they should shape the next round of work.
