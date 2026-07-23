# Household Care Story Moment

## Goal

- Provide the first embodied `family_memory` scene that can be completed or
  seasonally missed without blocking the main route.
- Establish one bounded, reusable policy shape for completed-versus-missed moments
  without introducing another mutable state owner or a general runtime registry.

## Player Experience

- After `winter_memory_reveal`, A Po's courtyard appears near Piano Ferry.
- The player enters the courtyard, tends the basin and blanket, and receives A Po's
  reflective response.
- Completing the care leaves warm window/lantern light and tended props.
- Reaching `spring_festival_prepared` first closes the opportunity and leaves dry
  leaves, an untended basin, later regret dialogue, and regret ending texture.
- Both outcomes preserve Spring Festival, the family route, and final-act access.

## Rules

- Moment id: `family_household_care`.
- Route: `family_memory`.
- Completed event/fact: `family_household_care_seen`.
- Missed fact: `family_household_care_missed`.
- Opener: `winter_memory_reveal`.
- Phase: `winter`.
- Exact closer: `spring_festival_prepared`.
- A previously committed terminal outcome cannot change.
- If one transition or malformed legacy save has both outcomes and no committed
  outcome, completed wins.
- A miss is terminal for route projection, appears in `missed_beat_ids`, and grants
  no completion score.
- Ambient clock movement and generic season changes do not close the window.

## Edge Cases

- A pre-ledger save inside the open Winter window remains eligible.
- A pre-ledger save at or beyond the closer acquires the missed fact on decode.
- Seen, missed, and malformed dual-fact saves normalize idempotently.
- Repeated completion, closing, normalization, and load do not add commits,
  autosaves, or flip the outcome.
- Starting New Story or Free Walk resets transition base state so an old terminal
  outcome cannot leak into the new mode.

## Architecture And Ownership

- `AppStateService` remains the only mutable shared-state and persistence owner.
- `StoryMomentLedger` is a pure explicit policy over canonical `story_flags`.
- `AppStateTransition.base_snapshot` preserves the committed outcome during one
  detached command.
- `StorySaveCodec` applies the same normalizer during save decode.
- `StoryRouteGraph` projects missed events and care/regret ending tone.
- `StoryEventCatalog` owns semantic arrival and care bindings.
- `APosHouseholdCourtyard3D` owns only scene-local visual projection from detached
  saved facts; it never writes route state.

## Relevant Files

- Scene:
  `architecture/apo_household/apo_household_courtyard_3d.tscn`
- Scene presentation:
  `architecture/apo_household/apo_household_courtyard_3d.gd`
- Ledger policy:
  `game/story_moment_ledger.gd`
- Route authoring:
  `game/storylines/routes/family_memory.tres`
- Projection and journal:
  `game/story_route_graph.gd`, `game/journal_builder.gd`
- Story bindings and response:
  `game/story_event_catalog.gd`, `game/story_world_reactivity.gd`,
  `game/residents/definitions/tea_vendor_hua.tres`
- Production composition:
  `scenes/game_world_3d.tscn`, `scenes/game_world_3d.gd`

## Data Flow

1. A `StorySubject3D` emits an arrival or care subject request.
2. `StoryInteractionCoordinator` dispatches through
   `AppState.activate_story_subject(...)`.
3. StoryEvent effects update the detached working snapshot.
4. The ledger normalizes exclusive terminal facts before projection and autosave.
5. The committed projection updates the journal, household presentation, later
   resident dialogue, and ending summary.

## Validation

Automated coverage:

- `game/tests/story_routes/test_story_routes.tscn`
- `game/tests/story_routes/test_story_event_service.tscn`
- `game/tests/story_routes/test_story_reactivity.tscn`
- `game/tests/state/test_app_state_ownership.tscn`
- `game/tests/persistence/test_story_state_persistence.tscn`
- `game/tests/persistence/test_story_autosave.tscn`
- `game/tests/persistence/test_household_care_continue_fixtures.tscn`
- `scenes/tests/test_game_world_3d.tscn`

Manual closure checks:

- Run `game/tests/persistence/fixtures/open_winter_continue.tscn`, then use
  Title -> Continue to review the open Winter fixture.
- Run `game/tests/persistence/fixtures/legacy_post_closer_continue.tscn`, then use
  Title -> Continue to review the legacy post-closer fixture.
- New Game -> winter reveal -> household -> journal -> continue.
- New Game -> winter reveal -> festival preparation -> journal -> continue.

The two fixed Continue scenes preserve the pre-review story autosave before opening
the production title flow. Run
`game/tests/persistence/fixtures/restore_previous_save.tscn` after the review to
restore it. The open fixture uses the current save format; the post-closer fixture
intentionally remains V1 and omits both household outcome facts so Continue must
normalize it to the missed path.

Milestone A remains pending manual visual acceptance until those four production
checks inspect the expected route, journal, continuation, dialogue, and world
presentation.

## Out Of Scope

- A general household simulator or inventory system.
- Arbitrary runtime registration or suffix-based discovery of missable moments.
- Real-time expiry, hidden day-count expiry, or a literal calendar planner.
- Blocking Spring Festival or ending eligibility on either care outcome.
