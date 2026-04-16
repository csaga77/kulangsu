# Event and Story System Design

Read [`design_brief.md`](design_brief.md) first. This document builds on the existing systems described in [`core_game_workflow.md`](core_game_workflow.md) and [`npc_system_design.md`](npc_system_design.md).

## Current Direction: Generic Nested StoryEvent System

This section captures the current agreed direction for future implementation work.
If the older gap-oriented suggestions below conflict with this section, prefer this section.

## Implementation Status

A first-pass runtime is now live in the codebase.

Current shipped pieces:

- `game/story_event_service.gd` is composed by `AppState` as the shared StoryEvent bridge
- `AppState` now exposes `describe_story_subject(...)`, `activate_story_subject(...)`, `notify_story_world_event(...)`, `pick_story_candidate(...)`, `matches_story_conditions(...)`, and `apply_story_effects(...)`
- `game_main.gd` now routes resident talk and scene-owned `StoryInspectable` inspect interactions through stable subject ids instead of separate route-specific callbacks
- resident conditional beats now reuse the shared candidate-selection, condition-matching, and effect-application paths
- resident routine overrides are now a live world-effect channel that can reposition already spawned residents and persist through story autosave/continue

Current shipped subject ids:

- `npc:<resident_id>`
- `inspectable:<inspectable_id>`

Still not migrated:

- authored recursive `StoryEventDefinition` trees for the four top-level route families
- a director that arbitrates across many active route-family definitions instead of the current shared helpers over route graph, resident data, and inspectable catalogs
- landmark-trigger progression and other non-interaction signals moving fully through `notify_story_world_event(...)`
- a published-fact ledger replacing `story_route_graph.gd` as the canonical progression source

### Goals

- Keep the **world system generic**: terrain, NPCs, landmarks, `LevelNode2D`, and interaction geometry stay reusable and story-agnostic.
- Move progression meaning into a **generic StoryEvent system**.
- Allow **multiple active story events at once**.
- Allow **nested story events** so one top-level event can contain child events and steps.
- Let a story event drive both:
  - what an NPC says
  - what the player sees when interacting with a world subject such as a landmark, prop, or level-bound inspect surface

### Core Runtime Model

- **`StoryEventDirector`**
  - the single coordinator
  - receives world interactions and other world events
  - queries all active story events
  - resolves conflicting responses
  - applies the resulting world effects
- **`StoryEventService`**
  - generic runtime logic
  - should not contain Trinity-/Bagua-/tunnel-specific branching
  - is instantiated with authored event content rather than hardcoded rules
- **`StoryEventDefinition`**
  - authored event tree data
  - describes nested event structure, bindings, conditions, responses, and effects
- **`StoryEventContext`**
  - read-only access to world state, world subjects, published facts, and optional capabilities
- **`StoryEventEffect`**
  - the only write path back into world/app state
- **`StoryEventFact`**
  - published event facts that other active events may read

### Event Tree Shape

The generic service should operate over a tree, not a flat list.

Example:

```text
trinity_church
  choir
    steps
    garden
    yard
    chime
```

Use a **generic service per top-level event family**, with nested child events or steps inside the definition tree.
Do not turn every nested event into its own service instance unless there is a real ownership boundary.

### Using This With Current Story Lines

With the current content, the generic runtime should be authored around the same top-level route families already present in the playable story and route graph.

Use one top-level `StoryEventDefinition` tree for each current canonical route:

```text
family_memory
  summer_return_complete
  trinity_memory_awakened
  winter_memory_reveal
  parent_care
  spring_festival_prepared
  spring_festival_resolved

study_future
  autumn_pressure_named
  autumn_pressure_shared
  future_commitment_choice
  future_commitment_witnessed
  future_commitment_end
  summer_exam_complete

preservation_inheritance
  preservation_inheritance_seen
  preservation_tower_perspective
  stewardship_followthrough

melody_landmarks
  melody_ferry_settled
  melody_church_restored
  melody_bi_shan_restored
  melody_long_shan_restored
  melody_bagua_aligned
  harbor_festival_performed
```

This means:

- the current five-landmark melody line becomes one top-level event family with landmark-specific child beats
- the current study line becomes one parallel top-level event family
- the current parent line remains nested under `family_memory` in the current canon instead of becoming a separate bespoke runtime
- preservation remains its own top-level family with harbor, tower, map, and postcard follow-through under the same tree

If the story later needs a fully separate parent-specific route, that can become its own top-level family without changing the generic runtime model. The important part is that the runtime stays generic while authored content decides whether a line is top-level or nested.

### Current Route Ownership Pattern

The current routes should be treated as the main authoring families, while smaller emotional or location-bound lines remain nested inside them.

Recommended current grouping:

- `family_memory` owns harbor return, church memory, winter reveal, A Po reflection, parent-care beats, and Spring Festival family resolution
- `study_future` owns autumn pressure, shared study stress, future-choice honesty, harbor witnessing, and second-summer release
- `preservation_inheritance` owns harbor recognition, tower perspective, and stewardship reactions around maps, postcards, and visible memory
- `melody_landmarks` owns ferry refrain, the five landmark restoration path, and the public harbor performance payoff

This keeps the current route list stable for the player while giving implementation a durable tree structure under each route.

### World Subjects And Actions

The world should expose stable **subject ids** rather than asking story code to reason about raw node internals.

Examples:

- `npc:ferry_caretaker`
- `landmark:trinity_church.choir_chime`
- `level:bagua_tower.upper_railings`
- `prop:piano_ferry.notice_board`

Actions should stay generic:

- `talk`
- `inspect`
- `collect`
- `perform`

The director should be able to ask the same questions for every subject:

```text
describe_subject(subject_id, action, ctx)
activate_subject(subject_id, action, ctx)
```

This gives one interaction pipeline for NPC talk, inspect text, collectible triggers, performance points, and level-bound surfaces.

The current implementation has only shipped the first two pieces of that pipeline so far:

- `describe_subject(subject_id, action, ctx)`
- `activate_subject(subject_id, action, ctx)`

`notify_world_event(...)` exists on `AppState` and `StoryEventService`, but current landmark progression still mostly resolves through the existing landmark bridge and route graph helpers.

### How Current Routes Use World Subjects

The same world subject can be meaningful to multiple active event families at different times.

Examples:

- `npc:caretaker_lian` may answer to `family_memory` during harbor return and Spring Festival beats, to `melody_landmarks` during the harbor refrain, and to `study_future` when the harbor witnesses a future-choice turn
- `npc:mother` and other family-facing residents can stay under `family_memory.parent_care` rather than requiring a separate parent-specific runtime
- `level:bagua_tower.upper_railings` can present melody-facing text before `melody_bagua_aligned`, then preservation-facing or family-facing reflection once other facts are true
- `prop:postcard_rack` can stay a generic world subject whose inspect text shifts when `preservation_tower_perspective` or later stewardship beats become active

The world system should not care which route currently owns meaning. It only exposes stable subjects and actions to the director.

### Multiple Active Events

There can be many active story events at once.

When the player interacts with a subject:

1. the `StoryEventDirector` asks all active events for candidate responses
2. presentation output is resolved to a single winner
3. additive effects are merged when safe
4. resulting effects are applied through the generic world/app-state layer

Suggested conflict-resolution order:

1. exact subject match beats broad match
2. action-specific response beats generic response
3. higher event priority beats lower priority
4. deeper child event beats its parent when still tied

Use one winner for presentation (talk line, inspect text, label, verb), but allow multiple merged side effects when they do not conflict.

### Dependencies

Story events are independent in ownership, but may have optional dependencies.

Use three dependency channels:

- **required generic world access** through `StoryEventContext`
- **optional capabilities** such as melody prompts, audio cues, journal hooks, or cutscene hooks through nullable interfaces
- **optional cross-event dependencies** through published facts, not direct service-to-service calls

Preferred pattern:

- read facts such as `trinity_church.choir_complete`
- avoid direct calls such as `trinity_service.complete_choir()`

Current-route examples:

- `family_memory.winter_memory_reveal` may depend on the earlier family-memory church beat and optionally react to `study_future.autumn_pressure_named`
- `spring_festival_prepared` may read preservation facts so festival text carries more weight once the island has been seen as inheritance
- `harbor_festival_performed` may require melody progress plus Spring Festival completion without either family calling melody code or melody calling family code directly

### Ownership Boundaries

- `LevelNode2D`, terrain, landmarks, NPCs, and other world primitives remain generic and reusable.
- Scene-authored nodes still own placement, collision shape, and level binding.
- Story events own current meaning: dialogue, inspect text, unlock rules, and progression side effects.
- `LevelNode2D` itself should not carry story logic. If interacting with a level-bound surface matters to story, bind that surface to a stable subject id.

### Migration Direction

This direction implies the following refactor target:

- current hardcoded progression in `landmark_progression.gd` should be split into generic StoryEvent runtime plus authored event definitions
- current non-resident inspect text in `story_world_reactivity.gd` should move into the same StoryEvent-driven subject model
- `game_main.gd` should become a thin interaction router into the director
- scene-owned interaction geometry should remain scene-authored, while `LandmarkTrigger` / `StoryInspectable` behavior should converge on a thinner generic world-subject binding layer
- the current route ledger and UI route categories should remain player-facing views, even if their backing state is generated from active `StoryEventDefinition` trees and published facts

### Concrete Runtime Spec

The sections below describe the preferred first implementation shape.
Field names may change to fit GDScript ergonomics, but the ownership model and data flow should stay stable.

### Runtime Ownership

The runtime should be split across the existing boundaries rather than introducing a new global singleton.

- `AppState` remains the public shared-state bridge for UI, save, route summaries, and other gameplay systems
- `StoryEventDirector` should live under `game/` as a focused progression helper owned by `AppState` or composed through it
- `game_main.gd`, resident interaction, and inspect systems should route story-facing interactions through the shared bridge instead of calling route-specific services directly
- scene-authored world nodes continue to own placement, collision, and level context, while the StoryEvent layer owns meaning, gating, and side effects

This keeps the public progression boundary where the project already expects it while still moving route-specific logic out of scene scripts.

### Definition Shape

Use one recursive authored definition type for both top-level route families and nested beats.

Preferred authored fields:

- `id`: stable local id
- `kind`: `route`, `beat`, `step`, or `reaction`
- `priority`: conflict-resolution weight
- `display_name`: optional UI-facing label
- `activation_conditions`: requirements to become available
- `completion_conditions`: requirements for automatic completion when applicable
- `subject_bindings`: interactions this node claims while active
- `children`: nested authored nodes
- `effects_on_activate`: effects applied when the beat is explicitly activated
- `effects_on_complete`: effects applied when the beat completes
- `published_facts`: namespaced facts emitted by this node

The same structure should work whether the node represents a route family, a resident beat, a landmark step, or a lightweight world reaction.

Illustrative shape:

```text
StoryEventDefinition
  id
  kind
  priority
  activation_conditions
  completion_conditions
  subject_bindings[]
  effects_on_activate[]
  effects_on_complete[]
  published_facts[]
  children[]
```

### Subject Binding Shape

`subject_bindings` are the authored bridge between generic world subjects and route-specific meaning.

Preferred binding fields:

- `subject_id`: stable world subject id
- `action`: `talk`, `inspect`, `collect`, `perform`, `enter`, or another generic action
- `phase`: when this binding is valid for the node, usually `available`, `active`, or `completed`
- `conditions`: extra local checks beyond the node's base conditions
- `presentation`: text, label, prompt, or talk payload to show if this binding wins
- `effects`: side effects to apply if this binding activates
- `lead_weight`: optional scoring hint for route/journal lead selection
- `consumes_interaction`: whether this binding should claim the world interaction

Illustrative binding:

```text
subject_binding
  subject_id = level:bagua_tower.upper_railings
  action = inspect
  phase = available
  presentation = preservation-facing reflection
  effects = [publish_fact, journal_note]
  lead_weight = 20
  consumes_interaction = true
```

### Runtime State Model

Each authored node should have a serializable runtime state entry keyed by its full event path.

Preferred node states:

- `locked`: not yet available
- `available`: can currently surface to the player
- `active`: currently in progress or pinned as a live beat
- `completed`: beat resolved and can still provide aftermath reactions if authored
- `suppressed`: temporarily hidden by route logic or one-shot branch resolution

Each runtime save should also keep:

- the per-node state map
- published facts and their payloads
- completed-once reaction ids
- derived route summaries for UI projection

Facts should be serializable, namespaced, and free of scene-node references.
Prefer string ids such as `family_memory.winter_memory_reveal` or `melody_landmarks.bagua_aligned` over direct service references.

### Stable Subject Id Convention

World-facing story logic should depend on stable string ids, not scene-node paths.

Preferred current taxonomy:

- `npc:<resident_id>`
- `landmark:<landmark_id>`
- `landmark:<landmark_id>.<part_id>`
- `level:<scene_or_landmark_id>.<surface_id>`
- `prop:<prop_id>`
- `district:<district_id>`

Examples:

- `npc:caretaker_lian`
- `npc:mother`
- `landmark:trinity_church.choir_chime`
- `level:bagua_tower.upper_railings`
- `prop:harbor.postcard_rack`

Scene-authored nodes may keep whatever hierarchy they want internally, but they should bind outward to one stable subject id.

### Interaction API

The first implementation should support three story-facing entry points.

1. `describe_subject(subject_id, action, context)`
2. `activate_subject(subject_id, action, context)`
3. `notify_world_event(event_id, payload, context)`

Use them like this:

- `describe_subject(...)` returns the best current presentation candidate for prompts, inspect text previews, or NPC prompt labels
- `activate_subject(...)` resolves the actual interaction, applies effects, and returns the winning presentation payload plus any world/app-state instructions
- `notify_world_event(...)` handles non-interaction story signals such as prompt completion, landmark arrival, season advancement, or scripted resident milestones

The interaction context should stay lightweight and serializable where possible:

- current location or district id
- current player level id
- current season phase
- optional actor id or resident id
- optional source subject id

Do not require route services to inspect raw world nodes to determine meaning.

### Candidate Resolution Contract

When many active nodes answer the same subject, the director should resolve them deterministically.

Preferred order:

1. exact `subject_id` match
2. exact `action` match
3. binding whose node is deeper in the active tree
4. higher node or binding priority
5. stronger local conditions satisfied
6. stable full event path as final deterministic tiebreak

For the first implementation:

- one candidate wins presentation
- one candidate owns any conflicting interaction-claim behavior
- non-conflicting side effects may merge if they target different channels

If two candidates both try to write the same channel, such as objective text or pinned lead, keep the winning candidate's value only.

### Effect Channels

Effects should be structured and routed through generic adapters instead of hardcoded route-specific callbacks.

Preferred first-pass effect channels:

- `publish_fact`
- `set_objective`
- `set_hint`
- `request_audio_cue`
- `request_melody_prompt`
- `update_route_lead`
- `unlock_subject`
- `append_journal_note`
- `advance_season_phase`
- `set_node_state`

Optional capabilities such as melody prompts, cutscenes, or UI callouts should be invoked through effect adapters, not embedded directly into event definitions.

### Route Projection Contract

The current route ledger should remain a projection over StoryEvent state rather than a parallel source of truth.

Per top-level route family, derive:

- `resolved_beats`: completed visible nodes
- `available_beats`: currently actionable nodes
- `blocked_beats`: known nodes whose conditions are not yet met
- `next_lead`: the highest-value available binding or authored lead beat
- `completion_score`: weighted progress across completed nodes

This keeps the player-facing route UI stable even if the underlying runtime stops being a hand-maintained route graph.

In the migration period, `story_route_graph.gd` may remain the projection or authoring helper while StoryEvent becomes the runtime source of truth.

### Current Route Authoring Sketch

The current routes should author against the runtime like this:

- `family_memory`
  - resident talk beats for harbor return, church memory, winter reveal, A Po reflection, parent-care aftermath, and Spring Festival family resolution
  - inspect reactions on family-facing or ritual-facing world subjects after those beats resolve
- `study_future`
  - resident talk beats for autumn pressure, shared social pressure, future honesty, harbor witnessing, and second-summer release
  - district props or harbor-facing reactions once those beats become visible
- `preservation_inheritance`
  - inspect-heavy bindings on tower overlooks, postcards, maps, and architecture-facing props
  - resident talk beats that shift from scenery to stewardship
- `melody_landmarks`
  - landmark and level-surface bindings for the five-landmark route
  - public performance payoff plus post-festival resonant aftermath on harbor-facing subjects

This means one route family may be mostly resident-facing while another is mostly inspect-facing, without needing different runtime systems.

### Save And Restore Expectations

StoryEvent runtime state should save as data, not by restoring live node references.

At minimum, persist:

- top-level route family state
- per-node state keyed by event path
- published facts
- one-shot reaction history
- current pinned lead projection inputs

On load:

- restore node states and facts first
- rebuild route summaries and available bindings
- let scene-authored world nodes re-query the runtime when they need current presentation

### Implementation Order

Recommended implementation sequence:

1. introduce stable subject ids and the generic interaction bridge without changing route content
2. move inspect text and landmark-facing reactions into StoryEvent subject bindings
3. migrate resident conditional dialogue selection onto StoryEvent-backed bindings or shared condition evaluation
4. move landmark progression and milestone publication behind StoryEvent effects
5. make route ledger and ending triggers read from StoryEvent-derived summaries instead of parallel hand-authored runtime state

This order keeps the world boundary stable while progressively reducing hardcoded route-specific branching.

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
