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
7. `Postgame`

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
7. Choose whether the story lingers on the island or departs from it.

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

- `Caretaker Lian` anchors the harbor return and spring-festival recognition
- `Dock Musician Pei` names autumn pressure, future honesty, and second-summer release
- `Choir Caretaker Mei` awakens and sharpens the church-linked memory line
- `Terrace Painter Nian` anchors preservation and inheritance from the tower district

This means the player can currently reach a valid ending by strongly following the family, study, and preservation routes while leaving most of the landmark melody route unfinished.

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
- ending tone is shaped by the trigger, route mix, resident trust/turnout, and the final stay-or-leave choice

## Ending And Postgame

The ending frame still keeps the ferry departure-versus-stay contrast.

- `Leave` turns the story into a departure ending, then returns to title
- `Stay` turns the story into an afterword and unlocks `Postgame`

`Postgame` is for endings that imply staying or lingering on the island. It is not a generic sandbox reset.

`Free Walk` remains a separate non-canon exploration mode.
