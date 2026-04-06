# BGM Track Tagging Guide

How to tag music tracks so the BGM selection system can weigh them correctly.

Read `bgm_system.md` first for the overall design.

## Catalog Format

Each track is one entry in `game/bgm_catalog.gd`, following the project's existing catalog pattern. A track entry looks like this:

```gdscript
"harbor_morning": {
    "file": "res://resources/audio/music/bgm/bgm_harbor_morning.ogg",
    "tier": "commons",           # "commons", "location", or "exclusive"
    "duration": 42.0,            # seconds, for commitment window tracking
    "location": {                # 0.0 = never, 1.0 = strong affinity
        "ferry_plaza": 0.9,
        "trinity_church": 0.2,
        "bi_shan_tunnel": 0.1,
        "long_shan_tunnel": 0.1,
        "bagua_tower": 0.3,
        "overworld": 0.6,
    },
    "time": {
        "morning": 0.9,
        "afternoon": 0.4,
        "evening": 0.2,
        "night": 0.1,
    },
    "progress": {
        "early": 0.7,
        "searching": 0.8,
        "gathering": 0.5,
        "performed": 0.3,
        "resonant": 0.3,
    },
    "season": {
        "spring": 0.8,
        "summer": 0.7,
        "autumn": 0.4,
        "winter": 0.3,
    },
    "weather": {
        "clear": 0.8,
        "rain": 0.2,
        "fog": 0.4,
        "wind": 0.5,
    },
    "variants": {},              # see Variants section below
},
```

### Weight Rules

- Every factor group (location, time, progress, season, weather) must have at least one value > 0.0, otherwise the track can never be selected (the product of all weights will be zero).
- Weights are relative within their group. A track with `morning: 0.9, night: 0.1` is 9x more likely in the morning than at night, but it can still play at night.
- For Tier 3 exclusive tracks, set all non-matching values to `0.0` to enforce hard exclusivity. For example, the rain-only track would have `clear: 0.0, rain: 1.0, fog: 0.0, wind: 0.0`.
- For Tier 1 commons, keep all weights above `0.1` so they remain reachable in any context. They should feel universal.
- For Tier 2 location-leaning, the primary location gets `0.6–0.9`, secondary locations get `0.2–0.4`, and distant locations get `0.05–0.1`.

### How Weights Combine

The selection score for a track is:

```
score = location[current_zone]
      × time[current_period]
      × progress[current_tier]
      × season[current_season]
      × weather[current_weather]
```

All five are multiplied together. A track that fits well on three axes but poorly on one will score low — every axis matters.

## Tagging Workflow

When you have a new track, listen to it and ask these five questions:

### 1. Where does this feel like?

Close your eyes and listen. Does it feel like an open harbor? A stone tunnel? A high place? A walk between landmarks? Tag the location that comes to mind highest, then fill in the others relative to it.

If it doesn't strongly suggest any place, it's probably a Tier 1 commons track — give all locations moderate weights (0.4–0.7) with slight variation.

### 2. What time of day is this?

Bright and fresh = morning. Full and warm = afternoon. Mellow and settling = evening. Sparse and quiet = night. Most tracks will lean toward one or two periods. Give the dominant period 0.7–0.9 and let the others trail off.

If the track feels timeless (works at any hour), keep all time weights in the 0.5–0.7 range.

### 3. How far into the story does this belong?

Sparse, tentative, searching pieces belong to early/searching progress. Fuller, warmer pieces belong to gathering/performed. Pieces with a sense of completion or memory belong to resonant.

If a track works across the whole game, flatten the progress weights (0.4–0.7 across the board) but give a slight bump to the tier it fits best.

### 4. What season is this?

Spring = new, light. Summer = full, bright. Autumn = warm, golden, mellow. Winter = crystalline, sparse, still. Most calm piano pieces lean summer or autumn. Give the best-fit season 0.7–0.9.

### 5. What weather is this?

Clear is the default — most tracks should have clear at 0.6–0.8. Rain tracks sound intimate, muffled, or have a rhythmic quality. Fog tracks sound distant and soft. Wind tracks have movement or restlessness. If the track doesn't strongly suggest weather, keep clear high and the others at 0.2–0.4.

## Variants

If a track has seasonal or weather variants, list them in the `variants` dictionary:

```gdscript
"variants": {
    "autumn": "res://resources/audio/music/bgm/bgm_harbor_morning_autumn.ogg",
    "rain": "res://resources/audio/music/bgm/bgm_harbor_morning_rain.ogg",
},
```

The system checks for a variant matching the current context before playing the base file. Priority order: progress variant > weather variant > seasonal variant > base.

A track does not need variants. Most won't have them. Variants are for tracks where you've intentionally produced an alternate version.

## Tier-Specific Tagging Patterns

### Tier 1 — Island Commons

```
location: all values 0.3–0.7 (no strong peaks)
time: one or two periods at 0.7–0.8, others at 0.3–0.5
progress: spread across 0.3–0.8 with a gentle lean
season: one or two at 0.7–0.8, others at 0.3–0.5
weather: clear at 0.6–0.8, others at 0.2–0.4
```

These tracks should be reachable from almost any context. Avoid putting any weight below 0.1.

### Tier 2 — Location-Leaning

```
location: primary at 0.7–0.9, one or two secondaries at 0.2–0.4, rest at 0.05–0.15
time: similar to commons
progress: similar to commons or slightly narrower
season: similar to commons
weather: similar to commons, or add a weather variant instead
```

The location weights do most of the work here. Keep the other axes relatively open so the track doesn't become too rare.

### Tier 3 — Exclusive

```
location: either one location at 1.0 and rest at 0.0, or all at 0.5+ if the exclusivity comes from another axis
time: either one period at 1.0 and rest at 0.0, or open
progress: often the exclusive axis — e.g., resonant at 1.0, rest at 0.0
season: usually open unless the track is season-exclusive
weather: rain at 1.0 and rest at 0.0 for the rain track, etc.
```

At least one axis should have hard zeros to enforce the exclusive condition. The other axes can be open.

## Naming Convention

```
resources/audio/music/bgm/bgm_[descriptive_name].ogg                    — base track
resources/audio/music/bgm/bgm_[descriptive_name]_[variant_type].ogg     — variant

Examples:
resources/audio/music/bgm/bgm_harbor_morning.ogg
resources/audio/music/bgm/bgm_harbor_morning_autumn.ogg
resources/audio/music/bgm/bgm_harbor_morning_rain.ogg
resources/audio/music/bgm/bgm_quiet_wandering.ogg
resources/audio/music/bgm/bgm_tunnel_echo.ogg
resources/audio/music/bgm/bgm_after_the_stage.ogg
```

## Setting Duration

After trimming the track to its final loop length, record the exact duration in seconds in the `duration` field. The BGM system uses this to enforce the minimum commitment window (currently 45 seconds). If the track is shorter than 45 seconds, it will always play to completion before a location-triggered reselection can happen.

## Quick-Start Checklist

1. Listen to the track once without thinking about tags.
2. Write down the first location, time, and mood that come to mind.
3. Fill in the `duration` field from the trimmed file length.
4. Open the catalog template and fill in weights starting from those instincts.
5. Compare weights to 2–3 existing tracks in the catalog — does this new track occupy a different niche or overlap too much?
6. If it overlaps heavily with an existing track, consider whether it should be a variant of that track instead of a separate entry.
7. Add it to `bgm_catalog.gd`, test in-game by forcing selection, then adjust weights based on how it feels in context.
