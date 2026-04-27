# Summer of Piano Island — Story Framework

Read [`../design_brief.md`](../design_brief.md) first for the minimum-token summary. This file is the single source of truth for Kulangsu's story direction and narrative framing.

Use this document for:

- protagonist and family background
- story themes and emotional lines
- the seasonal frame of the current playable game
- the meaning of each major route
- ending tone and story constraints

Keep implementation plumbing, state shapes, and UI behavior in the docs that own those systems.

## Canon Position

The current playable canon is a seasonal multi-route coming-of-age story.

- The year is structured by authored season phases.
- Multiple routes may be active at once.
- The five-landmark melody route remains canonical, but it is one route among several.
- The game no longer assumes one guided landmark spine as the sole progression path.

## Title

**Summer of Piano Island**

## Core Premise

A Year 12 boy begins a decisive year on Kulangsu, stretching from one summer into the next.

He has lived on the island since returning with his family in Year 5, and from then on he lived with his grandmother. But after her death at the end of Year 11, the home and island he thought he knew feel changed. Grief, distance from his parents, exam pressure, uncertainty about the future, and a half-avoided relationship to the island's older buildings have all made home feel familiar and estranged at the same time.

Summer 1 is therefore not his first arrival on Kulangsu. It is an emotional re-entry into an island he already lives on: the moment when he begins to hear that familiar places now sound incomplete. The ferry remains important as the island's central image of arrival and departure, reflecting his parents' repeated comings and goings, visitors passing through, and the final question of whether he will leave or stay.

Over the course of the game, the player does not solve one problem. He lives inside several overlapping ones:

- memory and guilt
- family sacrifice and emotional distance
- study pressure and the fear of choosing the wrong life
- preservation, inheritance, and what deserves to be carried forward
- the island's fading public melody

The story is about learning to hear those lines together.

## Main Character

A Year 12 boy living on Piano Island.

He is:

- intelligent
- sensitive
- observant
- under heavy expectation
- uncertain about which future is actually his

He loves:

- music
- sports
- comic books
- 4WD model cars
- robot models

He admires martial-arts masters because they seem to possess the steadiness and certainty he lacks.

He is pulled toward several possible futures:

- architecture
- computer science
- politics / foreign affairs
- sports
- music

He also has the possibility of a prestigious pre-selection path that others admire more than he does.

### Core Inner Struggle

He is preparing for an exam that may define his future while not knowing which future is genuinely his.

## Family Background

The family returned to the island when he was in **Year 5**, after job changes forced his parents to leave better positions in the provincial capital and return to his father's hometown.

From that point on, the boy lived with his grandmother on Kulangsu. Home was therefore not only the island in general, but the daily space of Grandma's routines, illness, church-going, small habits, and gradual forgetting.

At around the same time, his grandmother's Alzheimer's had advanced enough that she could no longer care for herself. Because both parents were often away for work, the family hired **A Po**, a woman in her 60s, to help care for both the grandmother and the boy.

After the grandmother passed away peacefully at the end of Year 11, A Po remained the practical emotional anchor of the household.

### Father

- works in another city
- usually only returns during Lunar New Year / Spring Festival
- steady, respected, responsible
- lost the career he loved because of bureaucracy
- later gets a chance to return to that work during the boy's final school year

### Mother

- works with a sports team
- usually returns only briefly on weekends
- disciplined, capable, respected
- is also moving toward a major career opportunity during this same year

### A Po

- practical, loyal, warm in action more than speech
- held daily life together while others were absent
- keeps care tangible even when love is difficult to name

## Seasonal Frame

The current story frame begins with the first summer after Grandma's death. This is not a physical return from years away, but an emotional return to hearing and understanding the island after loss.

The current story frame is:

1. `Summer 1`
2. `Autumn / Study`
3. `Winter`
4. `Spring Festival / Spring`
5. `Second Summer`
6. `Final Act`

These are authored emotional phases inside a light life-time simulation model. Days, day/night phases, and seasons can progress independently from storyline completion, so the world should feel as if it continues moving even when the player has not completed every available route beat.

The game should not use a heavy calendar-planner UI, but it should treat the passing year as real enough that some moments only exist during certain seasonal and daily windows. Story events can also move time: a long task may consume an afternoon, a family meal may move evening into night, an exam may skip most of a day, and a major festival or final performance may push the world into a new seasonal phase.

The seasons therefore behave as life-sim time phases with authored emotional meaning. They are not purely story-locked quest gates. Inside each season, day/night cycles provide smaller rhythms of availability, atmosphere, and missable daily texture.

### Seasonal Missability Principle

The game uses seasonal missability as an emotional design principle.

Seasons do not wait for the player. Some scenes, conversations, environmental details, character-intimacy moments, and small acts of care only exist during specific phases of the year. If the player misses them, the game should not fully replace them later. Instead, later scenes should remember the absence.

This supports the central themes of attention, memory, regret, loss, and the impossibility of perfectly preserving every moment.

Design rule:

missable does not mean broken; missable means emotionally transformed.

A missed beat should not usually block the main route. It should change later echoes, relationship tone, regret weight, ending texture, and the player's understanding of what was lost.

Examples of seasonal missability:

- A late-summer A Po memory about where Grandma sat may become a colder winter chair scene if the boy never asked in time.
- A Spring Festival meal still happens whether the boy is ready or not, but its warmth, silence, and meaning change depending on prior family-memory attention.
- A repair detail in the preservation route may disappear after autumn work is finished; Mei may later say, quietly, that the boy should have seen it before.
- Exam pressure continues even if the boy avoids study and future conversations; friends may move ahead without him.
- A melody fragment found in the right season may feel full and locally grounded, while the same fragment discovered late may feel thinner or less contextual.

Use gentle diegetic signals instead of aggressive expiry warnings. Characters may mention that repairs begin after Mid-Autumn, a parent is home for only two nights, the light falls a certain way only in late summer, or Spring Festival preparation starts soon. The player should feel that time matters without seeing a mechanical countdown.

Recommended split:

- Main route continuity: not missable
- Seasonal emotional scenes: missable
- Character intimacy scenes: missable
- Environmental details and inspectables: missable or seasonally transformed
- Critical ending access: not missable
- Ending tone: affected by completed, missed, and transformed moments

The final act should not only ask how much the player completed. It should also ask what the boy noticed, what he missed, what he repaired, what he left unresolved, and what he can now carry.

### Life-Time Simulation And Day / Night Principle

The game uses a light life-time simulation model for present-day world time.

World time normally moves forward through daily phases, days, and seasons. The player chooses how to spend time through ordinary actions such as walking, talking, inspecting, studying, helping residents, sketching buildings, listening for melody cues, joining meals, and resting. These actions can consume time, and accumulated days eventually move the season forward.

Recommended daily phases:

1. `Morning`
2. `Afternoon`
3. `Evening`
4. `Night`

These phases are atmosphere and availability states rather than a rigid timetable. They control available scenes, resident placement, lighting, ambient sound, shop/lane activity, school pressure, household routines, and emotional tone.

Design rule:

world time flows forward; memory time can move backward; authored events can move either.

Use two kinds of time:

- `World Time`: the current season, day, and day/night phase. This is the boy's present life on Kulangsu and normally moves forward.
- `Memory Time`: recalled past moments reached through dreams, old photographs, objects, music, buildings, stories, or conversations. This can move backward without literally rolling back the world state.

Events may move time in three directions:

1. **Forward within the day** — a school morning becomes afternoon, a repair task consumes the afternoon, or a family meal moves evening into night.
2. **Forward across days or seasons** — sleep, exams, festival sequences, travel, long recovery periods, and final performances may advance to another day or seasonal phase.
3. **Backward into memory** — a chair, hymn book, old window, melody phrase, photograph, lane, or conversation may temporarily move the player into an earlier remembered moment.

Backward time should usually mean memory access, not an undo button. The player is not normally rewinding the present world. They are entering partial, selective, emotionally charged memory. After a backward-time event, the world returns to the present, sometimes with the current day phase advanced.

Examples of forward-time events:

- a school day may move morning directly into afternoon
- a long repair task with Mei may consume the afternoon and open an evening follow-up
- a family dinner may move evening into night
- a late-night study session may move to the next morning
- Spring Festival dinner may advance to the next morning or next phase
- exam day may skip most ordinary daily activity
- the final performance may move the story toward the final act

Examples of backward-time events:

- inspecting Grandma's old chair at night may enter a Year 6 afternoon memory near the window
- an old photograph may briefly return the boy to a family moment before Grandma's illness worsened
- a restored melody phrase may let the player hear a past festival evening
- sketching a villa gate may reveal an earlier household celebration or departure scene
- A Po's story may move the player into a remembered walking route with Grandma

Backward-time events can reveal, deepen, or recontextualize missed moments, but they should not fully erase the consequence of missing them. If the player missed an earlier A Po scene, a later memory may be fragmented, colder, or incomplete. Memory can recover meaning, but it cannot perfectly restore the lost present.

Use event-driven time movement sparingly and clearly. The player should feel that time moved because the action, memory, or emotional turn mattered, not because the game arbitrarily removed control.

Recommended split:

- Ambient day/night flow: independent
- Accumulated days and seasons: independent enough to make time feel alive
- Ordinary route scenes: may consume part of a day
- Major emotional events: may advance day, night, or several days
- Major seasonal anchors: may advance season
- Memory events: may move backward into the past, then return to present world time
- Critical ending access: not blocked by missing ordinary daily scenes
- Ending texture: affected by what the player noticed, missed, delayed, remembered, or arrived too late to see

## The Four Canonical Routes

These are the current top-level story families.
Smaller lines such as church-memory steps, parent-care beats, or landmark sub-beats belong inside these families unless the canon later promotes them into their own route.

These same families now also back the first-pass generic StoryEvent bridge, even though the fully authored recursive event-tree migration is still ahead.

### 1. Family and Memory

This is the emotional center of the game.

It carries:

- Grandma
- church-linked memory
- guilt and grace
- the meaning of returning home
- parent-care strain and the cost of absence
- the first Spring Festival without her

The player should feel the movement:

forgotten cruelty -> memory returning -> shame -> grief -> grace -> changed belonging

### 2. Study and Future

This is the main coming-of-age line.

It carries:

- exam pressure
- projected prestige
- fear of choosing wrong
- the difference between performance and honesty
- the emotional release of second summer

The player should feel the movement:

performance -> pressure -> confusion -> self-questioning -> honesty -> release

### 3. Preservation and Inheritance

This is the route that teaches the player to read the island differently.

At first, the island's old buildings are familiar but almost invisible to him. Villas, churches, tunnels, lanes, courtyards, gates, tilework, stone walls, balconies, and shaded paths are simply where life happens. As the route develops, he learns that these places carry memory in the same way people do.

This route carries:

- architecture as visible memory
- old buildings as inheritance, not scenery
- ordinary houses and ordinary lives as part of island memory
- the fear of losing what nobody properly noticed in time
- the cost and labor of keeping fragile places alive
- the possibility that preservation is also a future-facing choice

The player should feel the movement:

scenery -> attention -> meaning -> inheritance -> responsibility

This route should mirror the grandmother storyline. Just as the boy failed to fully understand Grandma while she was alive, he gradually realizes that the island's buildings may also disappear before people understand what they carried.

#### Preservation Route Characters

Use these characters to keep preservation personal, practical, and dramatic without turning it into a dry history lesson.

**Mr. Lin — retired architecture / art teacher**

Mr. Lin is an elderly teacher who still walks the island with a notebook. At first, the boy may think he is only staring strangely at walls, railings, windows, and tiles. Later, Mr. Lin becomes the mentor who teaches him how to see.

His role is to turn architecture from scenery into language. He should teach through small questions and close observation rather than lectures.

**Mei — young repair apprentice**

Mei is around the boy's age or slightly older. Her family works in traditional building repair: woodwork, tile repair, plaster, stone steps, old windows, and weathered frames.

She gives the route its hands-on reality. To her, preservation is not only beauty; it is dust, leaking roofs, money, time, and difficult work. She turns preservation from appreciation into labor.

**Uncle Zhao — owner of a fading villa**

Uncle Zhao owns an old family villa under pressure from decay, cost, relatives, or possible redevelopment. He should not be a villain. He is tired, practical, and burdened by inheritance.

His role is to show that memory can become heavy when nobody helps carry it. He makes preservation morally complicated rather than sentimental.

**Madam Wei — ordinary resident with an ordinary house**

Madam Wei lives in a modest old house with small details: a repaired door, faded tiles, a courtyard plant, a patched roof, or a worn threshold.

Her role is to remind the player that preservation is not only about famous villas, churches, or towers. Ordinary people and ordinary houses also remember.

**Mr. Huang — modern developer / investor**

Mr. Huang represents modernization, tourism, safety, jobs, and commercial pressure. He should be persuasive and partly reasonable, not cartoonishly evil.

His role is to test whether the boy's care for old places can become thoughtful action rather than simple nostalgia.

**Professor Xu — visiting historian**

Professor Xu knows maps, dates, owners, architectural styles, and migration history. He gives knowledge, but not necessarily intimacy.

His role is to provide historical context carefully, while leaving the boy to supply local care and emotional understanding.

**A Po — hidden preservation character**

A Po should also carry this route because she remembers how people used spaces: which path Grandma took to church, which wall she held when walking, which steps were difficult in rain, which lane had shade, and where daily care happened.

Her role is to connect architecture back to Grandma and make place feel lived rather than displayed.

#### Preservation Route Shape

A strong preservation route can unfold in six stages:

1. The boy walks past old buildings without truly seeing them.
2. Mr. Lin and Mei teach him to notice form, detail, repair, and use.
3. A Po or Madam Wei connects a place to Grandma or ordinary island life.
4. Uncle Zhao's villa or another site faces sale, decay, or redevelopment pressure.
5. The boy helps document, sketch, interview, repair, compare old stories, or gather memories. He cannot save everything, but he learns to act.
6. Bagua Tower synthesizes the route by letting him see the island as connected memory rather than isolated scenery.

The route should support gameplay such as inspecting old architectural details, sketching or documenting buildings, talking to elders, helping with small repair tasks, comparing old stories with visible remains, and noticing how places change across the year.


### 4. Melody and Landmarks

This is the most symbolic public route.

It carries:

- the five landmarks
- the island's missing public melody
- restoration through walking, listening, and helping
- the public form of memory being returned to others

The player should feel the movement:

fragment -> phrase -> route -> synthesis -> public remembering

## The Five-Landmark Route

The landmark route remains canonical.

It still runs through:

- Piano Ferry
- Trinity Church
- Bi Shan Tunnel
- Long Shan Tunnel
- Bagua Tower
- Festival Stage

Its meaning has changed slightly inside the broader architecture:

- it is the strongest symbolic route, not the only progression spine
- it can deepen family, preservation, and ending tone
- it is optional for baseline completion
- it remains the most public and musical expression of the island's memory

In current route grouping terms, this landmark line is the `melody_landmarks` family, while its individual landmarks are nested beats inside that family rather than separate top-level routes.

## Current Seasonal Anchors

The current playable game still uses major anchors to give each season emotional shape:

- `summer_reentry_complete`
- `autumn_pressure_named`
- `winter_memory_reveal`
- `spring_festival_resolved`
- `summer_exam_complete`

These anchors should feel like emotional turns in the year, not checklist checkpoints. They should shape the season's meaning, but they do not require every optional route beat to be completed before time moves forward. The summer anchor should be understood as emotional re-entry into the island, not a physical return from elsewhere.

## Cross-Route Relationship Rules

The routes are meant to touch each other.

Current canonical relationships:

- church memory can unlock or intensify family-memory beats
- study pressure changes how preservation and harbor conversations are heard
- preservation gives Spring Festival and family beats more weight
- landmark resolutions can enrich family, preservation, and ending tone
- landmark completion should not be required for baseline completion of the year

This also means one world subject may carry different meaning for different active routes at different times. A harbor resident, church surface, tower overlook, or postcard rack can be heard through more than one route without changing the canon route list itself.

## Current Playable Coverage

This section keeps the canon aligned with the game's current playable slice.

The intended story is broader than the currently authored resident and route content. For now, the game expresses each route at different levels of depth:

- `family_memory` currently lands the summer emotional re-entry, church-linked memory, winter reveal, A Po and parent-care reflection, Spring Festival preparation, and a quieter aftermath beat
- `study_future` currently lands the naming of autumn pressure, a shared-pressure social echo, the honest-future turn, harbor witnessing, and the release of second summer
- `preservation_inheritance` currently lands a harbor recognition beat, the Bagua tower perspective, and follow-through reactions that treat maps and postcards as stewardship rather than scenery
- `melody_landmarks` currently remains the most embodied route in terms of landmark spaces, musical restoration, public payoff, and soft post-festival resonance

This means the current playable story already supports the seasonal multi-route structure, but not all canonical emotional lines are equally developed yet.

With the seasonal missability principle, current playable coverage should track both completed and missed moments. A route can continue after a missed seasonal beat, but later reactions should reflect whether the boy noticed, avoided, or arrived too late.

## Storyline Gap Priorities

The next narrative expansion should stay focused on the gaps that most affect the shape of the year:

1. Deepen `family_memory` with more embodied household scenes around A Po, the parents, and the cost of care so those beats are not carried mostly by dialogue alone.
2. Expand `study_future` with more lived middle beats and small world responses so the route keeps its year-long pressure shape between the major turning points.
3. Grow `preservation_inheritance` into stronger district-facing reactions, props, inspectables, and character-led tasks through Mr. Lin, Mei, Uncle Zhao, Madam Wei, Mr. Huang, Professor Xu, and A Po so stewardship is visible even when the player is not in a resident conversation.
4. Add missed-beat echoes for each route so seasonal absence becomes visible through changed dialogue, props, ambience, and ending tone.
5. Turn the improved ending and departure language into more playable closing movement once the route-specific copy settles.
6. Keep `melody_landmarks` optional for completion while giving its resonant follow-through more wandering texture after the public performance.

Until those gaps are filled, the canon should be read as the target story shape rather than a claim that every route already has equal playable weight.

## Endings

The story ends through a short final act, not instant credits from an ordinary route completion.

Only designated major events may start endgame, and none may do so before spring has resolved.

The ending should still preserve the ferry framing:

- leave on the morning ferry
- stay a little longer and let the island linger when the ending allows it

Ending tone should be shaped by:

- the triggering event
- route mix and completion scores
- resident trust and turnout
- the final stay-or-leave choice

## Story Constraints

- Do not treat the protagonist as a total outsider or as someone newly arriving after years away; he has lived on Kulangsu since Year 5, and Summer 1 is an emotional re-entry after Grandma's death.
- Do not flatten the game into only exam drama or only melody restoration.
- Do not make the island's old buildings decorative background; they matter thematically.
- Do not force the melody route to become the only valid path to an ending.
- Do not use a literal calendar planner UI for this story frame.
- Do not make the day/night cycle a rigid life-sim timetable; use it as an authored atmosphere and availability rhythm.
- Do not freeze days, nights, or seasons until every route beat is completed; allow daily and seasonal moments to be missed, transformed, and remembered.
- Do not let the final act start before spring has emotionally settled.
