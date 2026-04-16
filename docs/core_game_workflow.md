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

These same four routes are also the natural top-level authoring families for the current first-pass generic `StoryEvent` runtime and its longer-term authored event-tree migration.

- each route should map to one top-level `StoryEventDefinition` tree
- multiple route trees may be active at the same time
- smaller lines such as parent-care beats should stay nested under their current route family unless the canon later promotes them into a separate top-level route

In the current story shape, that means:

- `family_memory` owns harbor return, church memory, winter reveal, parent-care beats, and Spring Festival family resolution
- `study_future` owns autumn pressure, shared study strain, future-choice honesty, and second-summer release
- `preservation_inheritance` owns harbor recognition, tower perspective, and stewardship follow-through
- `melody_landmarks` owns the five-landmark path and the harbor performance payoff

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

In other words, the route ledger remains the player-facing progression view, while the current StoryEvent bridge supplies shared interaction routing and reactive text and the longer-term migration can move the underlying beats and facts into authored event trees.

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
- `Choir Student Lin` turns autumn pressure into a shared social feeling and later hears the future route become honest instead of performative
- `Bell Repairer Qiao` gives the winter reveal a church-side echo that ties family memory to brass, ritual, and what was left unsaid
- `Postcard Seller An` starts the preservation route from the harbor and then reflects Bagua's wider perspective back onto the postcard rack
- `Terrace Painter Nian` pays the preservation route off with the island-wide tower perspective once Bagua is reachable
- `Map Student Jia` turns that tower perspective into stewardship language instead of mere wayfinding
- `Tea Vendor Hua` gives Spring Festival both a visible harbor-preparation beat and a quieter aftermath beat once it resolves
- `Ferry Porter Jun` hears second summer arrive as a harbor rhythm instead of one more deadline
- `Window Caretaker Su` gives the melody route a soft post-festival follow-through once the harbor performance settles into ordinary island air

This means the player can currently reach a valid ending by strongly following the family, study, and preservation routes while leaving most of the landmark melody route unfinished.

Under the current first-pass StoryEvent model, these resident beats and landmark-facing inspect beats resolve through the same interaction pipeline entry, even though canonical route progression still comes from the route graph and existing authored beat data:

- NPC talk
- landmark interaction
- level-bound inspect surfaces
- district props and stewardship-facing inspectables

That shared pipeline is what lets one active route change what an NPC says while another active route changes what a landmark or `LevelNode2D`-bound subject says.

## Current Coverage And Gameplay Gaps

The current structure is in place, and each non-melody route now has at least a short authored chain instead of a single turning-point line. The next gaps are more about depth and reactivity than missing route shape.

Current read of the playable slice:

- `family_memory` now runs through harbor return, church memory, winter revelation, A Po and parent-care reflection, harbor preparation, and Spring Festival aftermath
- `study_future` now stretches across Pei, Lin, Min, and Jun, with both the honest-future turn and second-summer release receiving broader district follow-through
- `preservation_inheritance` now starts at the harbor, widens at Bagua Tower, and continues through map and postcard reactions instead of collapsing into one tower exchange
- `spring_festival_resolved` now lands as preparation, resolution, and quieter aftermath rather than a single gate line
- `melody_landmarks` remains the route with the clearest physical progression and strongest environmental play, and it now gets a softer resonant follow-through after the public performance

Current gameplay-content priority order:

1. Add more embodied household scenes around A Po, the parents, and daily care so the family route is not carried mostly by talk beats.
2. Push preservation and melody reactivity into more inspectables, props, and district-facing world cues instead of leaving it mostly in resident dialogue.
3. Turn the differentiated ending copy into more playable authored closing moments once the final-act overlay language settles.
4. Keep enriching the landmark route without letting it reclaim the role of sole progression spine.
5. Continue migrating residents out of `resident_catalog.gd` so route growth does not stay trapped in one large script.

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
- pinned lead with explicit manual-versus-auto routing state
- other live leads
- route emphasis and lead-control guidance
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
- `harbor_festival_performed` is a soft ending. The player can leave on the morning ferry or stay a little longer; `Continue Exploring` clears the active ending state, restores the saved seasonal phase, and keeps the story running in-world.
- the harbor soft ending also lets `festival_melody` settle into its `resonant` follow-through once play resumes.

`Free Walk` remains a separate non-canon exploration mode.
