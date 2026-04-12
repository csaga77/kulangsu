# Kulangsu Core Game Workflow

Read [`design_brief.md`](design_brief.md) first for the minimum-token summary. Use [`story/summer_of_piano_island_story_framework.md`](story/summer_of_piano_island_story_framework.md) for the narrative source of truth. This file owns the gameplay and progression structure.

## Canon Structure

Kulangsu now uses a seasonal multi-route story architecture.

- There is no single main quest route.
- Multiple story routes can be active at the same time.
- The five-landmark melody route is one major route, not the only route.
- The HUD shows one pinned lead at a time.
- The journal shows the wider route ledger and the other live leads.
- Seasons are authored phase windows, not a day-by-day calendar simulation.

The current top-level frame is:

1. `Summer 1`
2. `Autumn / Study`
3. `Winter`
4. `Spring Festival / Spring`
5. `Second Summer`
6. `Final Act`

## Design Goal

Build the game around calm exploration, overlapping emotional routes, and a short final act that grows out of the player's route mix instead of a single hard-scripted landmark ending.

The game should feel like:

- returning home and hearing it imperfectly
- following several lives and worries at once
- letting landmark play, family memory, study pressure, and preservation concerns influence each other
- arriving at an ending through the shape of the year rather than a single quest-chain completion flag

## Core Player Loop

1. Return to a district and notice a lead, resident, or environmental cue.
2. Follow one pinned lead on the HUD while knowing other routes remain live in the journal.
3. Talk, inspect, and move through the island to resolve short authored beats.
4. Advance one or more route states, story flags, resident trust beats, or melody progress.
5. Let seasonal anchors move the year forward.
6. Enter a short final act once a designated major event lands after spring has resolved.
7. Resolve the ending by leaving the island or, for soft endings, returning to live story play.

For the repeatable moment-to-moment play design that powers those beats, see [`core_gameplay_plays.md`](core_gameplay_plays.md).

## Route Model

The current canonical routes are:

- `family_memory`: Grandma, church-linked grace, family distance, the emotional meaning of return
- `study_future`: exam pressure, identity strain, future-choice honesty, second-summer release
- `preservation_inheritance`: architecture, visible memory, inheritance, what should be carried forward
- `melody_landmarks`: the five-landmark route, restored public music, and island-scale symbolic payoff

Each route can be:

- active alongside other routes
- enriched by progress elsewhere
- ignored for a while without deadlocking the broader story

The route ledger tracks:

- resolved beats
- available beats
- blocked beats
- next lead
- cumulative completion score

## Opening State

The story still begins at the Piano Ferry.

The ferry tutorial teaches:

- movement
- inspect
- talk
- journal unlock timing

The opening remains:

1. Arrive at the ferry plaza.
2. Speak with Caretaker Lian.
3. Inspect the harbor clue.
4. Return to Lian.
5. Unlock the journal and the wider island.

What changes is what that handoff means.

The ferry opening now seeds multiple routes at once:

- the family-memory route through return and harbor belonging
- the melody route through the harbor refrain
- the study route once Pei becomes relevant

## Seasonal Anchors

Time advances through authored anchor beats, not by calendar ticks.

Current anchors:

- `summer_return_complete` opens the broader story after the harbor return settles
- `autumn_pressure_named` moves the year into Autumn / Study
- `winter_memory_reveal` moves the year into Winter
- `spring_festival_prepared` stages the harbor's emotional preparation for Spring Festival before the seasonal resolution lands
- `spring_festival_resolved` moves the year into Spring Festival / Spring
- `summer_exam_complete` moves the year into Second Summer and can also trigger the final act

These anchors replace the older assumption that `chapter` is the real progression key.

## Landmark Route

The five landmarks remain canonical world spaces and the melody route remains the strongest symbolic route.

Current melody route shape:

1. `Piano Ferry`: hear and settle the harbor refrain
2. `Trinity Church`: restore the first full phrase
3. `Bi Shan Tunnel`: turn echo into a dependable path
4. `Long Shan Tunnel`: turn route-finding into trust and accompaniment
5. `Bagua Tower`: align the island from above
6. `Festival Stage`: return the melody to the harbor in public

This route:

- still owns the island's most overt musical payoff
- still frames ferry arrival and ferry departure
- can enrich family, preservation, and ending tone
- is no longer required for baseline completion of the year

## Current Resident-Led Seasonal Beats

The current playable slice resolves seasonal anchors mostly through resident interaction:

- `Caretaker Lian` anchors the harbor return, the Spring Festival resolution, and the honest-future harbor ending
- `Dock Musician Pei` names autumn pressure, future honesty, and second-summer release
- `Choir Caretaker Mei` awakens and sharpens the church-linked memory line
- `Choir Student Lin` turns autumn pressure into a shared social feeling before the future route can resolve honestly
- `Postcard Seller An` starts the preservation route from the harbor instead of leaving it all to Bagua Tower
- `Terrace Painter Nian` now pays that preservation route off with the island-wide tower perspective once Bagua is reachable
- `Tea Vendor Hua` gives Spring Festival a visible harbor-preparation beat before Lian resolves it

This means the player can currently reach a valid ending by strongly following the family, study, and preservation routes while leaving most of the landmark melody route unfinished.

## Current Coverage And Gameplay Gaps

The current structure is in place, and each non-melody route now has at least a short authored chain instead of a single turning-point line. The next gaps are more about depth and reactivity than missing route shape.

Current read of the playable slice:

- `family_memory` now has a clearer four-step emotional chain through harbor return, church memory, winter revelation, harbor preparation, and Spring Festival resolution
- `study_future` now has two distinct outcomes: a second-summer exam release and an earlier honest-future harbor ending, both paced through more than one resident
- `preservation_inheritance` now starts at the harbor and pays off at Bagua Tower instead of collapsing into a single tower conversation
- `spring_festival_resolved` now lands as a sequence with visible preparation rather than a single gate line
- `melody_landmarks` remains the route with the clearest physical progression and strongest environmental play, but its public climax now waits for Spring Festival instead of cutting ahead of the seasonal arc

Current gameplay-content priority order:

1. Add more embodied family beats around A Po, the parents, and household care.
2. Add more reactivity after the new study/preservation beats so residents and objectives acknowledge the player's route mix more often.
3. Give Spring Festival and the honest-future ending more bespoke aftermath writing once the closing lead takes over.
4. Keep enriching the landmark route without letting it reclaim the role of sole progression spine.
5. Add more household and district-specific responses once major route beats have fired.

## HUD And Journal Structure

The HUD stays minimal.

It should show:

- one pinned lead
- the current task
- season label
- location
- fragment summary
- input hint
- save feedback

The journal should hold the wider multi-route view:

- season
- pinned lead
- other live leads
- per-route state
- resident notes
- melody notes
- map and shortcut notes

## Endgame Rules

Only designated major events may start the final act.

Current allowed triggers:

- `summer_exam_complete`
- `harbor_festival_performed`
- `future_commitment_end`

Guardrail:

- no event before `spring_festival_resolved` may trigger endgame

When endgame starts:

- new route beats stop becoming the live focus
- the pinned lead becomes the closing lead
- the game enters `Final Act` instead of hard-cutting to credits
- ending tone is shaped by the trigger, route mix, resident trust/turnout, and the final leave-or-continue choice when that ending allows it

## Ending Behaviors

The ending frame still keeps the ferry departure contrast, but there is no separate after-ending exploration mode anymore.

- `summer_exam_complete` and `future_commitment_end` are hard endings. The run can leave for credits or return to title, but it does not reopen live story play.
- `harbor_festival_performed` is a soft ending. `Continue Exploring` clears the active ending state, restores the saved seasonal phase, and keeps the story running in-world.
- the harbor soft ending also lets `festival_melody` settle into its `resonant` follow-through once play resumes.

`Free Walk` remains a separate non-canon exploration mode.
