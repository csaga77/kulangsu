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

A Year 12 boy returns to Kulangsu during the year that stretches from one summer into the next.

He has grown up on the island, but he no longer hears it cleanly. Grief after his grandmother's death, distance from his parents, exam pressure, uncertainty about the future, and a half-avoided relationship to the island's older buildings have all made home feel familiar and estranged at the same time.

When he returns by ferry, the island sounds incomplete.

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

The current story frame is:

1. `Summer 1`
2. `Autumn / Study`
3. `Winter`
4. `Spring Festival / Spring`
5. `Second Summer`
6. `Final Act`
7. `Postgame`

These are authored emotional phases, not calendar simulation.

Each phase is advanced by key story anchors rather than by timekeeping UI.

## The Four Canonical Routes

### 1. Family and Memory

This is the emotional center of the game.

It carries:

- Grandma
- church-linked memory
- guilt and grace
- the meaning of returning home
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

It carries:

- architecture as visible memory
- old buildings as inheritance, not scenery
- the fear of losing what nobody properly noticed in time
- the possibility that preservation is also a future-facing choice

The player should feel the movement:

scenery -> attention -> meaning -> inheritance -> responsibility

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

## Current Seasonal Anchors

The current playable game uses these anchors to move the year:

- `summer_return_complete`
- `autumn_pressure_named`
- `winter_memory_reveal`
- `spring_festival_resolved`
- `summer_exam_complete`

These anchors should always feel like emotional turns in the year, not checklist checkpoints.

## Cross-Route Relationship Rules

The routes are meant to touch each other.

Current canonical relationships:

- church memory can unlock or intensify family-memory beats
- study pressure changes how preservation and harbor conversations are heard
- preservation gives Spring Festival and family beats more weight
- landmark resolutions can enrich family, preservation, and ending tone
- landmark completion should not be required for baseline completion of the year

## Endings

The story ends through a short final act, not instant credits from an ordinary route completion.

Only designated major events may start endgame, and none may do so before spring has resolved.

The ending should still preserve the ferry framing:

- leave on the morning ferry
- stay a little longer and let the island linger

Ending tone should be shaped by:

- the triggering event
- route mix and completion scores
- resident trust and turnout
- the final stay-or-leave choice

## Story Constraints

- Do not treat the protagonist as a total outsider; he is returning, not arriving for the first time.
- Do not flatten the game into only exam drama or only melody restoration.
- Do not make the island's old buildings decorative background; they matter thematically.
- Do not force the melody route to become the only valid path to an ending.
- Do not use a literal calendar planner UI for this story frame.
- Do not let the final act start before spring has emotionally settled.
