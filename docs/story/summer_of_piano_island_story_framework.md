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

These are authored emotional phases, not calendar simulation.

Each phase is advanced by key story anchors rather than by timekeeping UI.

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

The current playable game uses these anchors to move the year:

- `summer_reentry_complete`
- `autumn_pressure_named`
- `winter_memory_reveal`
- `spring_festival_resolved`
- `summer_exam_complete`

These anchors should always feel like emotional turns in the year, not checklist checkpoints. The summer anchor should be understood as emotional re-entry into the island, not a physical return from elsewhere.

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

## Storyline Gap Priorities

The next narrative expansion should stay focused on the gaps that most affect the shape of the year:

1. Deepen `family_memory` with more embodied household scenes around A Po, the parents, and the cost of care so those beats are not carried mostly by dialogue alone.
2. Expand `study_future` with more lived middle beats and small world responses so the route keeps its year-long pressure shape between the major turning points.
3. Grow `preservation_inheritance` into stronger district-facing reactions, props, inspectables, and character-led tasks through Mr. Lin, Mei, Uncle Zhao, Madam Wei, Mr. Huang, Professor Xu, and A Po so stewardship is visible even when the player is not in a resident conversation.
4. Turn the improved ending and departure language into more playable closing movement once the route-specific copy settles.
5. Keep `melody_landmarks` optional for completion while giving its resonant follow-through more wandering texture after the public performance.

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
- Do not let the final act start before spring has emotionally settled.
