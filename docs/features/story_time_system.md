# Story Time System

## Purpose

The story time system is the first runtime slice of Kulangsu's lightweight life-time model. It gives the story a present-day clock without turning exploration into a strict life-sim schedule.

## Runtime State

`AppStateSnapshot` owns the canonical story-time fields:

- `story_day`: one-based day count for the current story run
- `world_hour`: clock hour from `0.0` to `<24.0`
- `time_of_day`: derived by `AppStateProjection` from `world_hour`

Current day phases:

- `morning`: `05:00` to before `12:00`
- `afternoon`: `12:00` to before `17:00`
- `evening`: `17:00` to before `21:00`
- `night`: `21:00` to before `05:00`

`game/story_time_service.gd` is a stateless transform helper for normalization, display labels, hour/day advancement, and day-phase jumps. `AppStateService` supplies a detached clock, commits the returned normalized snapshot, and emits one `state_committed` change set containing `TIME`. Compound time effects produce one final snapshot and one commit. `time_of_day` is derived from `world_hour`; do not treat it as an independent source of truth.

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

The shipped slice does not yet implement automatic missable-event expiry. Optional events can be time-gated, and authored effects can advance time, but current runtime state does not automatically publish a transformed absence.

Exploration should not secretly drain time. Time should move when an authored action, scene, or transition makes the passage meaningful.

## Milestone A Story-Moment Contract

Milestone A adds one bounded story-moment ledger without turning the clock into a
general scheduler. The parent project owns this policy; the generic storyline-editor
addon does not.

`AppStateSnapshot.story_flags` remains the canonical mutable and persisted store.
The planned `StoryMomentLedger` is a stateless definition/normalization helper over
that store, not another runtime owner. It starts with exactly one explicit
definition:

| Moment | Route event / seen fact | Missed fact | Opens after | Allowed phase | Exact closer |
| --- | --- | --- | --- | --- | --- |
| `family_household_care` | `family_household_care_seen` | `family_household_care_missed` | `winter_memory_reveal` | `winter` | `spring_festival_prepared` |

Do not derive moments from id suffixes or allow arbitrary runtime registration. New
moments must be added to the parent-owned definition table with their route, opener,
allowed phase, closer, seen fact, and missed fact.

The household-care route event is open only when the opener is true, the current
phase is Winter, the closer is false, and neither terminal outcome exists. Resolving
`spring_festival_prepared` is the exact expiry action. Neither ambient play time,
`story_day`, `world_hour`, nor a subsequent generic phase change expires this first
moment.

Normalization runs inside the existing detached `AppStateTransition` after authored
effects and ordinary story-flag normalization, but before route projection,
change-set construction, autosave, commit notification, or queued imperative events:

1. For a live command, if the transition's base snapshot already has seen or missed,
   preserve that first terminal outcome and reject any attempted flip in the
   detached working copy.
2. Otherwise, if the working seen fact is true, force missed false. Seen therefore
   wins a same-command completion-plus-close result.
3. Otherwise, if the working missed fact is already true, keep it.
4. Otherwise, if the exact closer is true, publish the missed fact.
5. Otherwise leave both facts false and keep the moment open or not-yet-open
   according to its opener and phase.

The operation is idempotent. Repeating normalization, the care completion command,
or the closing command cannot flip or republish a terminal outcome. If a crafted
command attempts completion and closure in the same detached transaction, the
explicit seen outcome wins only when the base snapshot did not already contain a
terminal outcome. During old-save decode there is no prior live transition outcome,
so malformed dual-fact input deterministically normalizes to seen.
`spring_festival_prepared` and
`spring_festival_resolved` never depend on either outcome.

The same normalizer runs after decoding an old save and before its first resumed
projection:

- before the opener: both outcomes remain false
- after `winter_memory_reveal` but before `spring_festival_prepared`: the moment
  remains available
- at or beyond `spring_festival_prepared` with neither outcome: missed is published
- with one existing outcome: that outcome is preserved
- with both outcomes: seen wins deterministically

Both facts serialize through the existing `story_flags` payload. No parallel save
field is introduced. The close transition produces the normal single story-state
commit and, when the triggering command requests it, one autosave.

Route projection treats a missed outcome as terminal closure, not as a permanently
blocked route beat. The mapped event id appears in `missed_beat_ids`, disappears
from `available_beat_ids` and `blocked_beat_ids`, and counts as terminal for the
route state without adding its completion score. Seen continues to use
`resolved_beat_ids` and its authored score. Journal presentation labels the missed
optional beat separately from unavailable work.

Later consumers use the same published facts through ordinary StoryEvent
conditions:

- Spring Festival dialogue selects care-seen or care-missed copy.
- Household/courtyard props and ambience retain a cared-for/warm or
  untended/absent state after the window closes.
- Ending tone and summary projection add care or regret texture, while ending
  eligibility remains unchanged.

## Validation

Current coverage checks:

- StoryEvent time conditions against the default morning start
- StoryEvent effects advancing to a later day phase, advancing by authored hours, and advancing to the next day
- story autosave persistence and restore for the saved day phase
- `game/tests/state/test_app_state_ownership.tscn` verifies canonical clock ownership and single-commit behavior for compound time effects

Milestone A must add:

- route opening after `winter_memory_reveal`, exact closure on
  `spring_festival_prepared`, and continued access to the Spring Festival route
- exclusive and idempotent seen/missed normalization, including dual-fact input and
  a same-transaction seen-plus-close attempt
- projection coverage proving a miss is terminal, has no completion score, and is
  absent from available and blocked leads
- persistence fixtures for old saves before and after the closer plus seen, missed,
  and conflicting round trips
- one-commit/one-autosave coverage for the closing transition
- both dialogue, prop/ambience, and ending-tone branches
- manual Continue checks for an open-window save and a legacy post-closer save, plus
  production playthroughs of the seen and missed paths through journal and Continue
