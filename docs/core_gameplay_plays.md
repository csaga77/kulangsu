# Kulangsu Core Gameplay Plays

Read [`docs/design_brief.md`](docs/design_brief.md) first for the minimum-token summary. Use this doc when designing the repeatable moment-to-moment plays that make up the island loop.

## Purpose

Define the core plays the player should perform again and again across the whole game so each landmark feels distinct without breaking the calm exploration identity.

The target feeling is:

- Curious, not rushed
- Guided, not over-scripted
- Reflective, not puzzle-box dense
- Social, not menu-heavy

## Primary Player Verbs

The whole game should stay legible around a small verb set:

- Walk the island and choose a direction
- Notice environmental cues, residents, and landmarks
- Inspect nearby objects for clues or interaction
- Talk to residents to gain context, trust, or a lead
- Follow audio, spatial, or social guidance through a space
- Reorder, return, escort, or activate a small set of world interactions
- Perform a short musical resolution beat

If a feature does not strengthen one of these verbs, it should be optional or cut.

## The Six Core Plays

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

### 2. Ask

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

### 3. Trace

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

### 4. Tend

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

### 5. Resolve

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

### 6. Choose

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

## District Play Profiles

Each landmark should emphasize a different mix of the six core plays rather than inventing a separate genre.

### Ferry Plaza

Primary plays:
Orient, Ask

What it teaches:

- Safe arrival and basic movement
- Inspecting obvious local objects
- Understanding that residents are the source of direction

Minimum interaction pattern:

1. Arrive and spot the ferry plaza focal point
2. Inspect or greet
3. Receive the first island-scale goal

### Trinity Church

Primary plays:
Ask, Trace, Tend

What makes it distinct:

- Most social of the landmarks
- Clues come from people, choir order, and nearby objects
- Rewards careful listening to context over raw navigation difficulty

Signature play:
Collect three scattered cues and restore them in the right emotional order.

### Bi Shan Tunnel

Primary plays:
Orient, Trace, Resolve

What makes it distinct:

- Strongest spatial uncertainty
- Progress comes from reading echoes and tunnel loops
- Setbacks should create mild disorientation, not punishment

Signature play:
Follow sound and shape through a looping passage until the hidden chamber reveals itself.

### Long Shan Tunnel

Primary plays:
Ask, Tend, Choose

What makes it distinct:

- Most relational landmark
- Success is about pacing and reassurance
- The NPC's emotional state becomes the route feedback

Signature play:
Escort a nervous resident by keeping them within a calm, readable path of light and proximity.

### Bagua Tower

Primary plays:
Trace, Resolve, Choose

What makes it distinct:

- Most synthetic landmark
- Turns prior fragment collection into spatial understanding
- The climb reframes the island as one connected composition

Signature play:
Ascend, align routes, and reconstruct the melody from a vantage point above the island.

## Standard Beat Structure

Every main objective chain should fit this repeatable cadence:

1. Arrival beat: strong landmark read
2. Contact beat: one resident or inspectable frames the need
3. Search beat: player follows 2-3 clue nodes
4. Care beat: player performs the local help action
5. Response beat: short musical or environmental reaction
6. Exit beat: overworld opens with a new lead

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

## System Implications

The game does not need many mechanics, but the ones it has must support the six core plays cleanly.

### Systems to prioritize

- Landmark intro triggers that establish `Orient`
- Bubble dialogue and inspect prompts for `Ask`
- Clue node and route-state tracking for `Trace`
- Small scripted world interactions for `Tend`
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
3. First melody fragment reward
4. Return to overworld with the next lead

That slice exercises all six core plays in the clearest, lowest-risk form.
