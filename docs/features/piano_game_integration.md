# Piano Game Integration Decision

Read `design_brief.md`, `core_melody_loop.md`, and `piano_game_design.md` first.

## Decision

Choose **Option 2: Optional free-play station**.

The ordered-confirmation prompt stays the canonical story-facing performance layer for now. The current `game/piano_game/` prototype should become an optional activity at Piano Ferry after the journal unlocks, not a mandatory replacement for landmark or finale progression.

## Why This Option

- It fits the calm-exploration tone better than turning the prototype into a required finale skill check.
- It lets the current story loop keep its short, recognition-first prompt design.
- It gives the prototype a real home in the island without forcing long rhythm-game sessions into the main path.
- It keeps future festival-only integration open if the prototype is later shortened and softened into a purpose-built phrase mode.

## Future Contract

### Entry

- A dedicated Piano Ferry interaction opens the piano game only after `AppState.is_journal_unlocked()` is true.
- The trigger lives in world content or a focused Ferry-side helper, not in `AppState`.
- `main.gd` owns opening and closing the piano interaction as an overlay or framed mode, following the same shell pattern as the melody prompt.

### Runtime Ownership

- `game/piano_game/` owns chart loading, note spawning, timing judgement, and local score/result calculation.
- `AppState` does not own per-note runtime or score counters.
- `AppState` only receives a small completion summary if the game eventually grants cosmetics or another optional reward.

### Result Shape

Recommended first result payload:

```gdscript
{
	"song_id": "ferry_free_play",
	"completed": true,
	"score_percent": 82.5,
	"max_combo": 14,
	"counts": {
		"perfect": 8,
		"great": 5,
		"good": 2,
		"miss": 1,
	},
}
```

- `main.gd` consumes this payload first.
- `AppState` only needs a follow-up call if a reward threshold or journal note is intentionally tied to free play.

### Audio Ownership

- `game_main.gd` keeps ownership of the live `BgmManager`.
- `main.gd` is responsible for ducking or muting BGM before the piano game starts and restoring it when the overlay closes.
- The piano game owns its own playback stream and should not route song playback through `BgmManager`.
- If a dedicated bus is added later, keep the split as: `BGM` for overworld music, piano-game playback on its own bus, one-shot UI feedback on UI/SFX.

## Implementation Steps

1. Add a Ferry-side trigger or interaction point near the existing piano crate.
2. Gate that interaction behind journal unlock so it appears after the onboarding handoff.
3. Wrap `game/piano_game/` in a shell-owned overlay scene instead of hard scene swapping.
4. Replace console-only completion with a clear result signal that `main.gd` can consume.
5. Start with no story reward; optionally add a journal note or cosmetic unlock only after the free-play loop feels good.
6. Revisit festival-only integration later only if the prototype is shortened into a brief phrase-performance mode.

## Non-Goals

- Do not replace the harbor-stage ordered prompt yet.
- Do not gate story completion on score thresholds.
- Do not turn the free-play station into a leaderboard or arcade ranking feature.
