# Kulangsu Core Gameplay Plays

Read [`design_brief.md`](design_brief.md) first for the minimum-token summary. Use this doc when designing the repeatable moment-to-moment plays that make up the island loop.

## Purpose

Define the core plays the player should perform again and again across the whole game so each landmark feels distinct without breaking the calm exploration identity.

The target feeling is:

- Curious, not rushed
- Guided, not over-scripted
- Reflective, not puzzle-box dense
- Social, not menu-heavy

The musical layer should reinforce that tone:

- Music is discovered in residents and places, not only in reward screens
- Melody reconstruction is a story and navigation tool, not a separate hardcore music game
- Practice and performance beats should stay short, readable, and emotionally clear

## Primary Player Verbs

The whole game should stay legible around a small verb set:

- Walk the island and choose a direction
- Hear and notice musical motifs in dialogue, ambience, and landmarks
- Notice environmental cues, residents, and landmarks
- Inspect nearby objects for clues or interaction
- Talk to residents to gain context, trust, or a lead
- Follow audio, spatial, or social guidance through a space
- Collect and reconstruct melody fragments
- Reorder, return, escort, or activate a small set of world interactions
- Perform a short musical resolution beat

If a feature does not strengthen one of these verbs, it should be optional or cut.

## The Eight Core Plays

These are the repeatable gameplay units that should combine into every district arc.

### 1. Orient

Question answered:
`Where am I, and what seems important here?`

Player actions:

- Enter a district or landmark threshold
- Read silhouettes, lighting, sound, and NPC placement
- Spot a likely point of interest from the environment before opening UI

Design rules:

- Start each district with one strong visual anchor
- Give the player one obvious safe path and one curiosity path
- Keep the HUD quiet enough that landmarks remain the primary guide

Success signal:
The player can point toward their next likely interaction within a few seconds of arrival.

### 2. Hear

Question answered:
`What is this place sounding like, and what memory is it pointing to?`

Player actions:

- Notice NPC humming, bells, wind tones, piano chords, or repeated motifs
- Pause near a sound source long enough to recognize it
- Associate a short melody fragment with a place, person, or story beat

Design rules:

- Melody discovery should often happen before explicit quest framing
- Environmental music should act like a clue language, not just background ambience
- Sound sources should be local and readable so players can follow them in motion

Success signal:
The player starts linking music to a person, location, or memory without opening a menu.

### 3. Ask

Question answered:
`Who here can help me understand this place?`

Player actions:

- Approach a resident, caretaker, or witness
- Trigger a short bubble exchange
- Learn the local need, mood, or missing piece

Design rules:

- Conversations should be short, specific, and grounded in place
- Residents should give direction through landmarks and habits, not coordinates
- New objectives should come from people or inspectables, not abstract quest popups

Success signal:
The player leaves the interaction with one clear sentence of intent.

### 4. Trace

Question answered:
`What clues can I follow through this space?`

Player actions:

- Move between clue points
- Compare environmental details
- Use route memory, echoes, sightlines, or repeated motifs

Design rules:

- Clues should be discoverable while moving, not hidden behind dense UI
- Each landmark should favor one clue language:
  - Trinity Church: visual order and social context
  - Bi Shan Tunnel: echo direction and tunnel rhythm
  - Long Shan Tunnel: NPC pacing and safe pools of light
  - Bagua Tower: height, doors, and perspective alignment
- Missed clues should delay progress, not hard-stop it

Success signal:
The player feels like they are reading the place, not solving an abstract lock.

### 5. Tend

Question answered:
`How do I help this person or place recover?`

Player actions:

- Return found items or cues
- Escort or reassure an NPC
- Re-activate a dormant object or route
- Complete a small sequence in a calm tempo

Design rules:

- Helping should feel caring and embodied, not like inventory bookkeeping
- Interaction counts stay small; three beats is usually enough
- The player should stay moving during the task whenever possible

Success signal:
The landmark’s problem feels eased by the player’s presence and follow-through.

### 6. Perform

Question answered:
`Can I turn what I heard and gathered into a meaningful action?`

Player actions:

- Practice a short phrase or ordering beat
- Hum, tap, or activate a melody at a special location
- Use a reconstructed tune to reveal a story, route, or emotional response

Design rules:

- Performance should be low-complexity and low-stakes
- Musical interactions should validate recognition more than dexterity
- Mini-games should be brief variants on listening, ordering, or timing, not full rhythm-game stages

Success signal:
The player feels like they gently completed a memory instead of passing a reflex test.

### 7. Resolve

Question answered:
`What changed because I helped?`

Player actions:

- Trigger a musical or environmental payoff
- Watch the resident, space, or soundscape respond
- Receive a melody fragment, trust gain, or shortcut unlock

Design rules:

- Rewards should be presented in-world first, UI second
- The musical payoff should be short but emotionally legible
- Every resolution should alter something persistent:
  - resident dialogue
  - route access
  - ambient sound
  - journal state

Success signal:
The island feels slightly more alive than it did a minute earlier.

### 8. Choose

Question answered:
`Where do I go next, and why?`

Player actions:

- Re-enter the overworld
- Check the journal only if needed
- Follow the next emotional or practical lead

Design rules:

- After each resolution, give one soft nudge and one optional detour
- Avoid funneling players through a mandatory menu step between landmarks
- The journal should confirm direction, not replace discovery

Success signal:
The player starts moving toward the next landmark with minimal friction.

## Melody Discovery and Reconstruction

Melodies should be encountered throughout exploration, not only handed out as quest completion tokens.

### Melody sources

- NPC humming and casual singing
- Environmental sound signatures such as bells, sea wind, piano rooms, and tunnel echoes
- Story scenes where a resident recalls or demonstrates a tune
- Objects with musical memory such as gramophones, pianos, crates, radios, or plaques

### Reconstruction model

Each key song should be built from a small number of fragments tied to different sources.

Example pattern:

- Fragment from a resident
- Fragment from a landmark object
- Fragment from an environmental sound point

When enough fragments are found, the melody becomes:

- recognizable in the journal
- usable at a performance point
- able to unlock a memory scene, story reaction, or route change

This is stronger than treating all fragment rewards as identical collectibles because it ties music to place and community.

## Light Practice Model

Practice and mastery ideas are useful, but they should be narrowed to fit Kulangsu's tone.

### Keep

- Recognition as the first level of understanding
- A brief practice step before a major performance
- Better outcomes when the player has fully explored related people and spaces

### Do not overbuild

- Large mastery grind ladders
- Score-chasing or precision rankings
- Long standalone rhythm-game sessions

### Recommended practice tiers

- `heard`: the player has encountered the melody source
- `reconstructed`: enough fragments have been combined to identify the tune
- `performed`: the melody has been used successfully at the right place

Optional completion depth can come from side stories and extra memories, not repeated skill grinding.

## District Play Profiles

Each landmark should emphasize a different mix of the eight core plays rather than inventing a separate genre.

### Ferry Plaza

Primary plays:
Orient, Hear, Ask

What it teaches:

- Safe arrival and basic movement
- Musical identity begins in ferry ambience and nearby residents
- Inspecting obvious local objects
- Understanding that residents are the source of direction

Minimum interaction pattern:

1. Arrive and spot the ferry plaza focal point
2. Hear the first local musical cue
3. Inspect or greet
4. Receive the first island-scale goal

### Trinity Church

Primary plays:
Hear, Ask, Trace, Tend

What makes it distinct:

- Most social of the landmarks
- Clues come from people, choir order, and nearby objects
- Rewards careful listening to context over raw navigation difficulty

Signature play:
Collect three scattered cues and restore them in the right emotional order.

### Bi Shan Tunnel

Primary plays:
Orient, Hear, Trace, Perform

What makes it distinct:

- Strongest spatial uncertainty
- Progress comes from reading echoes and tunnel loops
- Setbacks should create mild disorientation, not punishment

Signature play:
Follow sound and shape through a looping passage until the hidden chamber reveals itself.

### Long Shan Tunnel

Primary plays:
Ask, Tend, Perform, Choose

What makes it distinct:

- Most relational landmark
- Success is about pacing and reassurance
- The NPC's emotional state becomes the route feedback

Signature play:
Escort a nervous resident by keeping them within a calm, readable path of light and proximity.

### Bagua Tower

Primary plays:
Trace, Perform, Resolve, Choose

What makes it distinct:

- Most synthetic landmark
- Turns prior fragment collection into spatial understanding
- The climb reframes the island as one connected composition

Signature play:
Ascend, align routes, and reconstruct the melody from a vantage point above the island.

## Standard Beat Structure

Every main objective chain should fit this repeatable cadence:

1. Arrival beat: strong landmark read
2. Hear beat: a resident or the environment introduces a musical clue
3. Contact beat: one resident or inspectable frames the need
4. Search beat: player follows 2-3 clue nodes
5. Care beat: player performs the local help action
6. Performance beat: a short melody interaction completes the thread
7. Response beat: short musical or environmental reaction
8. Exit beat: overworld opens with a new lead

This should be the default template for story slices, journal entries, and quest scripting.

## Failure, Friction, and Recovery

The game becomes fragile if friction turns punitive. Preferred friction types:

- Brief loss of orientation
- Having to confirm a clue by revisiting a resident
- Escort slowdown
- Choosing a longer route before finding a shortcut

Avoid:

- Timers that force rushing
- Dense object-combination puzzles
- Combat as the gate to major progress
- Long resets that erase the mood of the place

Recovery support should come from:

- Repeated ambient cues
- Nearby residents repeating the next useful hint
- Journal entries that restate only the current actionable step
- Returning the player to a safe landmark edge instead of a fail screen

## Melody Journal

The journal should track both quest clarity and musical understanding.

Each melody entry should show:

- melody title or placeholder label
- fragments found
- related resident or location
- current state: `heard`, `reconstructed`, or `performed`

The journal should feel like a calm field notebook, not a completionist spreadsheet.

## System Implications

The game does not need many mechanics, but the ones it has must support the eight core plays cleanly.

### Systems to prioritize

- Landmark intro triggers that establish `Orient`
- Localized audio cues and discovery state for `Hear`
- Bubble dialogue and inspect prompts for `Ask`
- Clue node and route-state tracking for `Trace`
- Small scripted world interactions for `Tend`
- Lightweight practice and performance interactions for `Perform`
- Reward and world-state callbacks for `Resolve`
- Lightweight journal and hint updates for `Choose`

### Systems to avoid overbuilding

- Crafting inventories
- Combat progression trees
- Large objective trees with parallel prerequisites
- Puzzle-specific UI for each landmark

## Vertical Slice Recommendation

If the team needs one slice that proves the design, it should be:

1. Ferry Plaza intro
2. Trinity Church arc
3. First melody reconstruction and light performance beat
4. First melody fragment reward
5. Return to overworld with the next lead

That slice exercises the full exploration-to-melody loop in the clearest, lowest-risk form.
