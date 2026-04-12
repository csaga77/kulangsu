# BGM System Design

Read `core_melody_loop.md` first, then this file.

## Overview

The BGM system maintains a weighted pool of music tracks. Five context factors — location, time of day, progress, season, and weather — shape the probability of which track plays next. No track is deterministically mapped to a single context. The island has moods, not a soundtrack.

## V1 Scope

Build the real catalog/controller architecture first. Do not ship a separate one-off placeholder loop system that will later be replaced.

V1 should:

- add a `bgm_catalog.gd` plus one controller that owns the active `AudioStreamPlayer`
- use only the context the game already has: `location` and melody `progress`
- treat missing systems as fixed defaults until they exist: `time = afternoon`, `season = summer`, `weather = clear`
- start with a small seed pool: 4 Island Commons, 2 Location-Leaning tracks, and 1 Exclusive track
- make the first Exclusive track depend on live factors such as `performed`/`resonant`, not on deferred systems such as rain or time of day
- ship without variants unless one is needed to prove the pipeline

The live pool has now moved beyond that first seed pass to 12 tracks total:

- 5 Island Commons
- 5 Location-Leaning tracks
- 2 Exclusive tracks

## File Storage

All BGM pool tracks live under `resources/audio/music/bgm/`. Landmark motifs and prompt feedback live under `resources/audio/sfx/`.

```
resources/audio/
├── music/
│   └── bgm/                      — pool tracks and variants
│       ├── Stillness.ogg
│       ├── Moonlit Tides Save Theme.ogg
│       └── ...
└── sfx/
    ├── landmark_cues/            — landmark motif one-shots
    │   ├── trinity_chime.ogg
    │   └── ...
    └── melody_prompt/            — prompt select/correct/wrong feedback
        ├── segment_select.ogg
        └── ...
```

Format: OGG Vorbis preferred (native loop support in Godot 4). 44100 Hz, normalized to ~-14 LUFS.

## Context Factors

### Location

Five zones corresponding to the canonical landmarks, plus open overworld:

- `ferry_plaza` — open, social, harbor atmosphere
- `trinity_church` — enclosed, reflective, sacred
- `bi_shan_tunnel` — deep, reverberant, mysterious
- `long_shan_tunnel` — intimate, steady, companion presence
- `bagua_tower` — elevated, expansive, high-register
- `overworld` — default when not inside a landmark zone

### Time of Day

Four periods. Exact hour boundaries TBD.

V1 default: `afternoon` for all selection passes until a time-of-day system exists.

- `morning` — bright, still, beginning
- `afternoon` — warm, active, full
- `evening` — mellow, reflective, settling
- `night` — sparse, quiet, contemplative

### Progress

Derived directly from `AppState.melody_progress.state`:

- `unknown` — before the melody has been meaningfully heard
- `heard` — one or more fragments found, the island is starting to speak
- `reconstructed` — enough fragments are known to practice the melody
- `performed` — harbor performance complete, the island is whole
- `resonant` — soft-ending follow-through, the island remembers

### Season / Weather

Season:

- `spring` — light, airy, new growth
- `summer` — full, warm, bright
- `autumn` — mellow, lower tones, golden
- `winter` — sparse, crystalline, still

V1 default: `summer` for all selection passes until a season system exists.

Weather (evaluated independently from season):

- `clear` — default, no modification
- `rain` — muffled quality, intimacy
- `fog` — distant, soft edges, reduced high end
- `wind` — subtle movement, restlessness

V1 default: `clear` for all selection passes until a weather system exists.

## Track Pool Structure

The counts below are the long-term target. The first playable pass seeded 7 tracks; the live pool now sits at 12 while still following the same tiering rules:

- 5 Island Commons
- 5 Location-Leaning tracks
- 2 Exclusive tracks

Expand toward the larger counts only after the controller, selection rules, and in-game feel are stable.

### Tier 1 — Island Commons (8–10 base tracks)

General-purpose tracks that can play anywhere. They define the island's overall musical identity. Weights shift based on all five context factors but no track is excluded from any context.

Mood spread within this tier:

- 3–4 still / contemplative pieces (weighted toward `unknown`/`heard`, night, winter)
- 3–4 warm / wandering pieces (weighted toward afternoon, summer, `reconstructed`)
- 2–3 gently hopeful pieces (weighted toward performed/resonant, morning, spring)

Variant strategy:

- 4–5 of these tracks get seasonal variants (same melody, different instrumentation/color per season)
- 2–3 get progress variants (alternate arrangements with fuller harmony or instrumentation in late game)
- Estimated files: 25–33

### Tier 2 — Location-Leaning (6–8 base tracks)

Strong affinity for one or two locations but not hard-locked. A church-leaning track might play 60% of the time at Trinity Church but can still appear elsewhere at low probability.

Distribution:

- 1–2 tracks leaning ferry plaza (open, harbor, social)
- 1–2 tracks leaning church (enclosed, sacred, bell-like tones)
- 1–2 tracks leaning tunnels (reverb, depth, shared between Bi Shan and Long Shan)
- 1–2 tracks leaning tower (height, ascending register, air)

Variant strategy:

- 2–3 get weather variants (same piece, different processing — rain version, fog version)
- No seasonal variants needed; identity comes from spatial character
- Estimated files: 8–11

### Tier 3 — Exclusive Moments (4–6 tracks)

Hard-locked to specific conditions. Rare. The player notices when these appear.

Candidates:

- `after_the_stage` — any location + performed/resonant progress. Proof the island changed. Best first Exclusive candidate for V1 because it relies only on current live progression.
- `dawn_harbor` — ferry plaza + morning only. The arrival feeling.
- `island_rain` — any location + rain. The island's rain voice.
- `resonant_night` — any location + night + resonant state. The rarest piece. Island fully at rest.
- `restored_landmark` — specific landmark + after that landmark's fragment is found. One per landmark arc (up to 4: church, Bi Shan, Long Shan, Bagua). Only heard on revisit.

Variant strategy:

- None. These are singular. Their rarity is the point.
- Estimated files: 4–6 condition-gated tracks + up to 4 restored-landmark tracks = 8–10 total

### Long-Term Pool Summary

| Tier | Base tracks | With variants | Role |
|---|---|---|---|
| Island Commons | 8–10 | 25–33 files | Backbone identity |
| Location-Leaning | 6–8 | 8–11 files | Spatial character |
| Exclusive Moments | 8–10 | 8–10 files | Rare discoveries |
| **Total** | **24–28** | **41–54 files** | |

## Selection Rules

### When Selection Happens

A new track is selected when:

- The current track finishes naturally (fade-out at end of loop)
- The player enters a new location zone AND the current track has played for at least the minimum commitment duration

A new track is NOT selected when:

- The current track has been playing for less than the minimum commitment duration, even if the player changed zones
- The game is in a cutscene, overlay, or pause state

### Minimum Commitment Duration

A track must play for at least **45 seconds** before the system considers a reselection triggered by location change. This prevents rapid zone-crossing from producing jarring BGM flip-flopping.

If the player changes zones during the commitment window, the system notes the new zone but waits. When the commitment duration passes or the track ends (whichever comes first), the next selection uses the player's current zone at that moment — not the zone they were in when the track started.

### Selection Algorithm

When selecting the next track:

1. Score every track in the pool against the current context (location, time, progress, season, weather). Each track carries per-factor affinity weights. The score is the product of all five weights.
   In V1, resolve deferred systems to fixed defaults: `time = afternoon`, `season = summer`, `weather = clear`.
2. Zero out any track in the recent history buffer.
3. Zero out any Tier 3 track whose exclusive condition is not met.
4. Normalize remaining scores to probabilities.
5. Weighted random selection.

### Fallback Order

If all candidate scores collapse to zero:

1. Ignore the recent-history exclusion once and rescore.
2. If still empty, fall back to Tier 1 commons only.
3. If still empty, pick any valid base track that matches the current location well enough to avoid silence caused by tagging mistakes.
4. If still empty, stay silent and log a warning.

### Recent History Buffer

The system remembers the last **3 tracks** played and excludes them from selection. This guarantees variety even when the player stays in one context for a long time. The buffer is a simple FIFO — when a new track plays, the oldest entry drops out.

### Silence Gaps

After a track fades out, there is a short silence gap (5–15 seconds, randomized) before the next track begins. The island should breathe. Constant music without pause feels like a soundtrack; music with gaps feels like the island choosing to play.

Exception: Tier 3 exclusive tracks may start with zero gap when their trigger condition is first met (e.g., the moment rain begins, the rain track can fade in immediately over the gap).

## Transitions

### Fade Behavior

- Track ending naturally: 3–5 second fade-out at the end of the loop.
- Location-triggered reselection (after commitment window): current track fades out over 4–6 seconds, silence gap, then new track fades in over 2–3 seconds.
- Weather change: current track fades out over 6–8 seconds (slower, less abrupt), new selection fades in.
- Progress change (fragment found): current track continues to its natural end. The next selection reflects the new progress state. No hard cut — the player doesn't hear a "level up" in the BGM.

### Cue Ducking

- Landmark cue motifs briefly duck BGM by about 6 dB through `BgmManager.duck_for_cue(duration)`.
- The melody prompt ducks BGM for the full lifetime of the overlay through `BgmManager.set_ducked(true/false)`.
- Cue ducking lowers the currently playing BGM instead of crossfading, so the island still feels continuous while one-shot motifs and prompt feedback stay readable.

### Crossfade Rule

No simultaneous playback of two BGM tracks. Always fade out fully, gap, then fade in. Two tracks overlapping muddies the calm tone.

Exception: ambient environmental sounds (waves, wind, rain sfx) are a separate audio bus and may overlap with BGM freely. These are not part of the BGM pool.

## Variant Selection

When a track is selected and it has variants:

- Seasonal variant: pick the variant matching the current season. If no variant exists for the current season, use the base version.
- Weather variant: if the current weather has a variant for this track, use it. Weather variant overrides seasonal variant (rain version of the summer version = just the rain version).
- Progress variant: if the player's progress tier has a variant for this track, use it. Progress variant is the highest priority and replaces any lower-priority choice.

Priority: progress variant > weather variant > seasonal variant > base track.

Variants are single-file substitutions. Only one version of a track plays at a time. Variants are not layered.

## Audio Bus Layout

Recommended Godot audio bus structure:

- `Master`
  - `BGM` — all BGM tracks route here
    - `BGM_LocationFX` — per-zone bus effects (reverb for tunnels, high-pass for tower, etc.)
  - `Ambient` — environmental loops (waves, wind, rain sfx)
  - `Motif` — landmark fragment motifs (one-shot, separate from BGM)
  - `SFX` — gameplay sound effects
  - `UI` — menu and overlay sounds

Location-based bus effects can color any track that plays in that zone without needing separate audio files per location. A warm Island Common track gains natural reverb when played inside Bi Shan Tunnel, simply by routing through the tunnel's bus preset.

## Integration Points

### Reads From

- `AppState.melody_progress` — progress tier
- `AppState.current_location` or zone detection signals — location
- Game clock or time-of-day system (later) — time
- Season/weather system (later) — season, weather

### Signals To Listen For

- `fragments_changed` — update progress tier for next selection
- `melody_progress_changed` — tier transition
- Location zone enter/exit signals from `LandmarkTrigger` or area nodes
- Weather change signal (later)
- Time-of-day period change signal (later)

### Does Not Own

- Landmark motifs (one-shot audio cues at landmarks — separate system)
- Piano game audio (standalone prototype)
- Performance/finale audio (tied to melody prompt system)
- Ambient environmental sounds (waves, rain sfx — separate bus, always-on loops)

## Open Questions

1. When time-of-day exists, should period changes wait for the current track to end or trigger reselection after the commitment window?
2. When weather exists, should weather-exclusive Tier 3 tracks always bypass the silence gap on first trigger?
3. Should Free Walk mode use the same BGM pool with different weights, or a separate pool?
4. What is the target total audio file size budget once the pool grows beyond the V1 seed set?
5. Should the BGM system persist its recent history across save/load, or reset on Continue?
