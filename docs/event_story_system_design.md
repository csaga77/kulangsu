# Event and Story System Design Suggestions

Read [`design_brief.md`](design_brief.md) first. This document builds on the existing systems described in [`core_game_workflow.md`](core_game_workflow.md) and [`npc_system_design.md`](npc_system_design.md).

## What Already Works

Before proposing additions, it is worth naming what the codebase already handles well:

- **Melody catalog** (`melody_catalog.gd`) defines sources, fragments, states (`heard → reconstructed → performed → resonant`), and performance landmarks.
- **Melody progress** in `AppState` tracks per-melody runtime state with `known_sources`, `fragments_found`, `next_lead`, and `performed`.
- **Landmark progress** in `AppState` tracks per-landmark state (`locked → available → introduced → in_progress → resolved → reward_collected`) plus landmark-specific sub-state like `cues_collected` and `echoes_collected`.
- **Dialogue beat gating** already exists: beats carry `gate` and `gate_fallback` fields, checked by `_check_beat_gate()` before the beat fires.
- **Beat side-effects** already drive `objective`, `hint`, `chapter`, `save_status`, `unlock_landmark`, `landmark_states`, and `landmark_reward` changes.
- **Signal bus** in `AppState` already emits typed signals for mode, chapter, location, objective, melody progress, landmark progress, and resident profile changes.

The system is not starting from zero. The gaps below are about extending what exists, not replacing it.

## Gap 1: Conditional Dialogue Selection

### Problem

Resident dialogue is currently a linear array indexed by `conversation_index`, with an optional single `gate` per beat. This works for the authored tutorial flow (Ferry → Trinity Church), but it cannot express cross-landmark reactivity. For example, after the Long Shan escort, Caretaker Lian at Ferry Plaza should say something different — but a linear index cannot branch on `landmark_progress.long_shan_tunnel.state == "resolved"`.

### Suggestion: Add a `conditional_beats` List

Keep the existing `dialogue_beats` as the linear spine. Add an optional `conditional_beats` array per resident. The system checks conditional beats first and falls back to the linear index only if no conditional beat matches.

```
# In resident_catalog.gd, per-resident entry:
"conditional_beats": [
    {
        "conditions": {
            "landmark_state": {"long_shan_tunnel": "resolved"},
            "trust_min": 2,
        },
        "priority": 10,
        "once": true,
        "line": "You walked someone through the dark. The harbor hears that kind of thing.",
        "trust_delta": 1,
        "journal_step": "Lian noticed you helped in Long Shan Tunnel.",
    },
    {
        "conditions": {
            "fragments_found_min": 3,
        },
        "priority": 20,
        "once": true,
        "line": "Three phrases and the plaza is already humming louder. The tower will want to hear them together.",
        "objective": "Carry the recovered phrases to Bagua Tower.",
    },
],
```

### Evaluation Logic

In `interact_with_resident()`, before checking the linear beat index:

1. Filter `conditional_beats` to those whose `conditions` are all satisfied.
2. Among matches, pick the highest `priority` that has not already fired (if `once` is true).
3. If a match is found, return it and apply its side-effects.
4. If no match, fall back to the existing linear `dialogue_beats[conversation_index]` path.

### Condition Keys

Keep the condition vocabulary small and queryable from `AppState`:

| Key | Meaning |
|---|---|
| `landmark_state` | Dictionary of `{landmark_id: required_state}` |
| `melody_state` | Dictionary of `{melody_id: required_state}` |
| `fragments_found_min` | Minimum total fragments |
| `trust_min` | Minimum trust with this resident |
| `chapter` | Required current chapter |
| `mode` | Required current mode |
| `resident_known` | Array of resident ids that must be known |

All of these are already readable from `AppState` without new infrastructure.

### What This Preserves

- Ambient residents keep working with zero changes (they have no `conditional_beats`).
- The linear beat spine stays authoritative for the main quest progression.
- Conditional beats layer context-awareness on top without touching the linear index.
- The catalog-first, AppState-second pattern is preserved.

## Gap 2: World Reaction Layer

### Problem

When a landmark resolves, the design wants the island to "feel slightly more alive." Currently, landmark resolution fires `landmark_progress_changed` and updates melody/fragment state, but there is no systematic way for ambient systems (NPCs, sound, visuals) to react to story milestones without coupling directly to `AppState` internals.

### Suggestion: Story Milestone Signal

Add a small set of high-level story signals to `AppState` that fire after compound state changes resolve:

```gdscript
signal story_milestone(milestone_id: String, context: Dictionary)
```

Milestones are emitted from `_resolve_landmark()` and `_apply_resident_beat()` after all state updates are done. Example milestone ids:

- `"landmark_resolved"` with `{landmark_id, fragment_awarded}`
- `"fragment_restored"` with `{melody_id, source_id, total_found}`
- `"festival_ready"` with `{fragments_found, helped_residents}`
- `"resident_trust_max"` with `{resident_id}`

### Who Subscribes

- **`game_main.gd`**: can update ambient sound layers, toggle visual details (lights in windows, crowd density), or change NPC idle behavior.
- **`npc_controller.gd`**: can trigger a one-shot reaction animation or mood change when a relevant milestone fires while the NPC is on screen.
- **Journal overlay**: can show a brief "The island remembers..." moment text.

### What This Preserves

- `AppState` remains the single emitter. No new singleton.
- Subscribers are loosely coupled — they connect to the signal and filter on `milestone_id`.
- The signal is purely informational. It does not carry commands or assume what the subscriber will do.

## Gap 3: Recovery and Story Debt

### Problem

The design relies on soft guidance (NPC hints, ambient cues) rather than hard gates. But if a player misses a musical cue or walks past a key NPC, there is no mechanism to re-surface the missed information. Over time, the player can drift without direction, especially in Free Walk mode.

### Suggestion: Idle Recovery Hints

Add a lightweight recovery system that triggers when the player has not made progress for a configurable duration.

### Data Model

Each landmark phase can define a recovery entry in the catalog:

```
# In a new story_recovery_catalog.gd or as an extension of landmark progress defaults:
"recovery_hints": {
    "piano_ferry": {
        "introduced": {
            "idle_seconds": 120,
            "resident_id": "ferry_caretaker",
            "hint_line": "The old piano crate is still by the notice board, if you want to listen again.",
        },
    },
    "trinity_church": {
        "in_progress": {
            "idle_seconds": 180,
            "resident_id": "church_caretaker",
            "hint_line": "Two of the choir cues are near the garden steps and the side yard. The third likes to hide.",
        },
    },
},
```

### Trigger Logic

`game_main.gd` tracks a timer since the last `landmark_progress_changed` or `objective_changed` signal. When the timer exceeds the configured `idle_seconds` for the current landmark and phase:

1. Find the specified `resident_id`.
2. If the resident is spawned and on the same layer, have them emit their `hint_line` as a speech balloon (bypassing the normal talk interaction).
3. Reset the timer.

This keeps recovery in-world and avoids UI popups, matching the calm tone.

### Story Debt for Free Walk

In Free Walk mode, maintain a small queue of unfired important cues (melody source discoveries, key NPC introductions). When the player enters a district, check the queue and surface the oldest unfired cue through the nearest relevant resident. This prevents Free Walk from feeling aimless without adding hard quest structure.

## Gap 4: Festival Attendance Model

### Problem

The finale gathers "helped residents" into the plaza, but the mechanism for deciding who appears and how many affect the ending tone is not defined.

### Suggestion: Festival Eligibility on Resident Profiles

Add a derived `festival_eligible` flag computed from existing state:

```gdscript
# In AppState or a festival_controller.gd:
func get_festival_attendees() -> PackedStringArray:
    var attendees := PackedStringArray()
    for resident_id in RESIDENT_CATALOG_SCRIPT.resident_order():
        var resident: Dictionary = resident_profiles.get(resident_id, {})
        if int(resident.get("trust", 0)) >= 1 and bool(resident.get("known", false)):
            attendees.append(resident_id)
    return attendees
```

### Ending Tone Thresholds

```
var attendee_count := get_festival_attendees().size()
var total_residents := RESIDENT_CATALOG_SCRIPT.resident_order().size()

# Standard ending: fragments complete, few attendees
# Community ending: attendee_count >= total_residents * 0.6
# Wanderer ending: player chooses "stay" regardless of attendance
```

### Festival Spawn Points

The festival controller queries `get_festival_attendees()` and assigns each to a pre-placed festival anchor in the Ferry Plaza scene. Residents beyond the anchor count get a fallback "crowd edge" position. Their appearance configs come from the same `get_resident_appearance_config()` used everywhere else.

### What This Preserves

- Trust and known state are already tracked per-resident.
- No new resident profile fields needed — eligibility is derived.
- The existing `_count_helped_residents()` method already does a simpler version of this.

## Implementation Priority

These four gaps have different urgency levels relative to the current milestone plan:

| Gap | When It Matters | Suggested Slice |
|---|---|---|
| Conditional dialogue | As soon as a second landmark arc is playable | Slice 2 (Shared Quest Plumbing) |
| World reaction signals | When ambient polish starts mattering | Slice 3 (Tunnel Variants) |
| Recovery / story debt | When playtesting reveals drift | Slice 2–3 boundary |
| Festival attendance | Endgame only | Slice 4 (Endgame) |

## Architecture Alignment

All four suggestions follow the existing project conventions:

- Authored content stays in catalog scripts.
- Mutable runtime state stays in `AppState`.
- World integration stays in `game_main.gd` and controllers.
- No new singletons or autoloads are introduced.
- Signal-based communication rather than direct coupling.
- The HUD and journal remain thin consumers of `AppState` data.
