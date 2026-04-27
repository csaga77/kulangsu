# Story Time System

## Purpose

The story time system is the first runtime slice of Kulangsu's lightweight life-time model. It gives the story a present-day clock without turning exploration into a strict life-sim schedule.

## Runtime State

`AppState` owns the shared story-time fields:

- `story_day`: one-based day count for the current story run
- `world_hour`: clock hour from `0.0` to `<24.0`
- `time_of_day`: derived day phase from `world_hour`

Current day phases:

- `morning`: `05:00` to before `12:00`
- `afternoon`: `12:00` to before `17:00`
- `evening`: `17:00` to before `21:00`
- `night`: `21:00` to before `05:00`

`game/story_time_service.gd` owns normalization, display labels, hour/day advancement, and day-phase jumps. `time_of_day` is derived from `world_hour`; do not treat it as an independent source of truth.

The in-game HUD displays the compact story-time label, for example `Day 1, Morning`, in the status card beside season, location, and melody-fragment progress.

## StoryEvent Integration

StoryEvent conditions may read:

- `time_of_day`
- `world_hour_min`
- `world_hour_max`
- `story_day_min`
- `story_day_max`

StoryEvent effects may write:

- `story_day`
- `world_hour`
- `advance_hours`
- `advance_to_time_of_day`
- `advance_day`
- `advance_time` as a nested dictionary containing the same advancement keys

Use `time_of_day` for most story authoring. Use exact `world_hour_min` / `world_hour_max` only when clock precision matters, such as ferries, meals, school starts, or bells.

## Boundaries

The current slice does not implement automatic missable-event expiry. Optional events can be time-gated, and authored effects can advance time, but a future pass still needs a missed/transformed moment ledger before seasonal or daily absence can shape later reactions automatically.

Exploration should not secretly drain time. Time should move when an authored action, scene, or transition makes the passage meaningful.

## Validation

Current coverage checks:

- StoryEvent time conditions against the default morning start
- StoryEvent effects advancing to a later day phase, advancing by authored hours, and advancing to the next day
- story autosave persistence and restore for the saved day phase
