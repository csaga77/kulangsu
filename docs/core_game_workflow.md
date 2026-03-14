# Kulangsu Core Game Workflow

Read [`docs/design_brief.md`](docs/design_brief.md) first for the minimum-token summary. Use this doc only when story and progression structure need more detail.

## Design Goal
Build the game around a calm exploration-to-performance loop:

1. Arrive on the island with a simple personal goal.
2. Explore landmarks and meet residents.
3. Restore the island's "music memory" by helping each district.
4. Unlock a final island-wide performance.
5. End with departure or staying by choice.

This fits the current project strengths:

- Large explorable island terrain in [`terrain.tscn`](terrain.tscn)
- Free movement and inspect input in [`characters/control/player_controller.gd`](characters/control/player_controller.gd)
- Proximity dialogue balloon interactions in [`characters/control/base_controller.gd`](characters/control/base_controller.gd)
- Landmark spaces already placed in the island scene:
  - Piano Ferry
  - Bagua Tower
  - Trinity Church
  - Bi Shan Tunnel
  - Long Shan Tunnel

## Pillars

- Exploration first: movement through the island is the main moment-to-moment play.
- Landmark stories: each major landmark delivers one self-contained objective chain.
- Social discovery: NPC interactions reveal routes, history, and unlock tasks.
- Musical restoration: progress is tracked as recovered melody fragments.
- Low punishment: setbacks cost time and rerouting, not hard failure screens.

## Player Fantasy
The player is a newcomer to Kulangsu who gradually learns the island by walking it, listening to its residents, and reactivating musical memories hidden across important places. By the end, the player is no longer a tourist passing through, but someone who understands how the island's people and places connect.

## Core Loop

1. Enter a district.
2. Find a local resident, clue, or landmark interaction point.
3. Learn a short objective.
4. Traverse the space to solve it.
5. Receive a melody fragment, relationship gain, and the next lead.
6. Return to the overworld and choose the next landmark.

For the repeatable moment-to-moment play design that should power each of those steps, see [`docs/core_gameplay_plays.md`](docs/core_gameplay_plays.md).

## Full Game Flow

### 1. Title Screen

- `Start Game`
- `Continue`
- `Free Walk` for sandbox exploration
- `Credits`

### 2. Opening / Arrival

The game begins at the Piano Ferry terminal. The ferry arrival is the framing device for both the start and the end.

Player learns:

- Move
- Walk / run toggle
- Inspect nearby objects
- Talk to residents when close

Immediate objective:
`Find out why the island feels quiet today.`

### 3. Tutorial District: Ferry Plaza

Purpose:

- Teach basic movement and proximity interaction
- Introduce first named NPC
- Give the first explicit destination

Sequence:

1. Player spawns near the ferry.
2. Nearby NPC auto-bubbles a short greeting.
3. Player inspects the ferry plaza marker, piano crate, or notice board.
4. NPC explains that four island landmarks each hold part of the missing festival melody.
5. World map / journal opens after this conversation.

Reward:

- Journal unlocked
- Main quest unlocked: `Restore the Festival Melody`

### 4. Open Exploration Phase

The island opens after the ferry tutorial. The player can visit the landmarks in flexible order, but each one should reinforce a different style of play.

Recommended route:

1. Trinity Church
2. Bi Shan Tunnel
3. Long Shan Tunnel
4. Bagua Tower

The route should stay flexible, but soft guidance comes from NPC hints and difficulty.

## Landmark Objective Arcs

### A. Trinity Church: Learn to Listen

Theme:
Memory, harmony, community

Gameplay focus:

- Talking to multiple NPCs
- Reading environmental clues
- Light route finding inside and around the church

Objective chain:

1. Meet the church caretaker.
2. Find three missing choir cues scattered around the church grounds.
3. Return them in the correct order.
4. Trigger a short chime sequence.

Reward:

- Melody Fragment 1
- Church district trust
- Hint that sound travels strangely through the tunnels

### B. Bi Shan Tunnel: Learn Safe Traversal

Theme:
Hidden passage, echo, uncertainty

Gameplay focus:

- Navigating layered spaces
- Using tunnel entrances and visibility masking
- Following sound cues or reflected notes

Objective chain:

1. Find the correct tunnel entrance.
2. Follow echo cues through the tunnel without getting turned around.
3. Reach a hidden chamber or mural node.
4. Inspect the chamber to recover the next fragment.

Failure state:

- Wrong turns loop the player back to an earlier tunnel segment.
- No death; only orientation loss and time pressure.

Reward:

- Melody Fragment 2
- Shortcut unlocked across the island

### C. Long Shan Tunnel: Help Someone Through

Theme:
Companionship, guidance, trust

Gameplay focus:

- Escort / follow behavior
- Keeping pace with an NPC
- Protecting route clarity rather than combat

Objective chain:

1. Meet an anxious NPC who refuses to cross alone.
2. Lead them through the tunnel at a calm pace.
3. Stop at safe lit pockets when the NPC becomes nervous.
4. Exit together and hear their story.

Failure state:

- If the NPC lags too far behind, they stop and call out.
- Player returns to re-engage instead of restarting the whole sequence.

Reward:

- Melody Fragment 3
- Companion relationship unlock
- New dialogue options in previously visited zones

### D. Bagua Tower: Master Perspective

Theme:
Overview, synthesis, revelation

Gameplay focus:

- Vertical progression
- Traversing doors, stairs, and layered rooms
- Reading the island as a whole

Objective chain:

1. Reach the tower entrance.
2. Unlock access to upper rooms by solving a simple route puzzle.
3. Assemble the previously found fragments at the top chamber.
4. Reveal the full melody contour and final festival location.

Reward:

- Melody Fragment 4
- Final song reconstructed
- Endgame unlocked

## Midgame Support Systems

### Journal

Tracks:

- Current objective
- Landmark progress
- Known residents
- Collected melody fragments
- Open shortcuts

### Relationship Layer

Each landmark should have at least one resident whose trust grows after helping them.

Benefits:

- Cleaner directions
- Optional lore
- Cosmetic endgame changes
- Better final turnout at the festival

### Optional Collectibles

Examples:

- Postcards
- Historical plaques
- Sheet music scraps
- Sound memories

Purpose:

- Reward exploration of side paths
- Deepen island identity
- Improve completion ending

## Progress Structure

### Main Progress Gate

The player needs all four melody fragments to trigger the finale.

### Soft Gates

- NPC hints point toward the next suitable landmark.
- Tunnel shortcuts unlock after completion.
- Certain doors or upper layers only open after earlier story beats.

### No Hard Combat Gate

The current project reads best as atmospheric adventure. Avoid mandatory combat in the main flow unless the project direction changes later.

## Story State Flow

Use a small chapter-and-phase model so story progression stays readable in both code and UI.

### Chapter Order

1. `Arrival`
2. `First Lead`
3. `Open Exploration`
4. `Festival Ready`
5. `Festival Night`
6. `Postgame`

### Phase Rules

Each chapter should advance through a short set of reusable phases:

- `discover`: player reaches a landmark or trigger space
- `brief`: resident or inspectable object explains the task
- `solve`: player performs traversal or interaction objective
- `resolve`: resident reacts and reward is granted
- `return`: journal updates and next lead opens

This lets the project share one quest structure across all four landmark arcs instead of building every district as a one-off script.

### AppState Targets

The shared UI state in [`game/app_state.gd`](game/app_state.gd) should reflect the current story beat with lightweight values:

- `mode`: `Title`, `Story`, `Free Walk`, or `Postgame`
- `chapter`: broad progression label such as `Arrival` or `Festival Night`
- `location`: current district or landmark label
- `objective`: one clear action sentence
- `hint`: current control reminder or context-sensitive prompt
- `fragments_found`: restored melody count out of four

The doc in [`docs/ui_design_context.md`](docs/ui_design_context.md) already assumes this state drives the HUD and overlays, so gameplay progression should update it as soon as objectives change.

## Landmark State Template

Each major district should use the same internal quest states, with custom content layered on top.

### Shared Quest States

1. `locked`
2. `available`
3. `introduced`
4. `in_progress`
5. `resolved`
6. `reward_collected`

### Transition Rules

- `locked` to `available`: enabled by tutorial completion or a prior landmark hint
- `available` to `introduced`: first resident conversation or landmark inspection
- `introduced` to `in_progress`: player accepts or activates the local objective
- `in_progress` to `resolved`: success condition met
- `resolved` to `reward_collected`: fragment, trust, and shortcut updates are granted

### Per-Landmark Data Needed

Each landmark entry should eventually define:

- Landmark id
- Resident id or lead NPC
- Intro trigger
- Solve trigger list
- Reward payload
- Shortcut unlock or follow-up hint
- Recovery text if the player gets lost or stalls

This can live in a lightweight resource, dictionary table, or singleton-managed data block later. The important design constraint is that all four arcs expose the same fields.

## Objective and Journal Structure

The journal should not just mirror flavor text. It should carry the minimum information needed to prevent drift while preserving the calm tone.

### Main Objective Format

Use one sentence with an action verb:

- `Speak with the church caretaker.`
- `Follow the tunnel echoes to the hidden chamber.`
- `Guide the resident through Long Shan Tunnel.`
- `Return to Ferry Plaza at sunset.`

### Journal Entry Format

Each active entry should contain:

- Title
- Current step
- One or two clue lines
- Reward preview if appropriate
- Completion marker after resolution

### Resident Notes

Resident notes should unlock only after introduction and should answer:

- Who they are
- Where they are usually found
- Why they matter to the melody restoration

This gives exploration context without turning the game into a dense quest log.

## Save and Recovery Checkpoints

The intended flow already avoids harsh failure, so save behavior should support continuity rather than tension.

### Autosave Moments

- After the ferry tutorial unlocks the main quest
- On landmark introduction
- On landmark completion
- When a shortcut opens
- Before the festival start prompt
- After the ending choice

### Checkpoint Resume Rules

- Resume at the nearest safe district entry, not inside a fragile escort or tunnel puzzle moment
- Restore the current chapter, objective, fragment count, and landmark states
- Re-show the latest journal objective on load so the player regains context immediately

### Recovery Messaging

When the player loses track of a puzzle state, prefer world-consistent prompts:

- `The echo fades here. Try listening again near the entrance.`
- `Your companion has stopped in the last lit pocket.`
- `The caretaker is still waiting for the choir cues.`

## Festival Finale Workflow

The ending sequence should behave like a playable ritual, not a detached cutscene.

### Festival Entry Conditions

- All four fragments restored
- Player returns to Ferry Plaza
- Festival prompt explicitly confirmed

### Finale Sequence Beats

1. Lock free-roam interactions except the festival nodes
2. Gather helped residents into the plaza
3. Activate the four fragment stations in order
4. Play environmental response pass across lights, windows, crowd, and music
5. Transition into ending choice

### Ending Outcome Inputs

The final presentation should read from:

- Fragment completion
- Number of resolved resident stories
- Optional collectible count
- Leave or stay choice

This is enough to support the current three ending tones without creating a large branching narrative tree.

## Prototype-First Implementation Order

Build the workflow in the smallest loop that proves the design.

### Slice 1: Arrival to First Fragment

- Ferry arrival objective
- One lead NPC at Ferry Plaza
- Journal unlock
- Trinity Church full arc
- Rewarding the first melody fragment

### Slice 2: Shared Quest Plumbing

- Landmark state tracking
- Journal entries populated from quest state
- Autosave checkpoints
- Fragment counter reflected in HUD

### Slice 3: Tunnel Variants

- Bi Shan echo navigation
- Long Shan escort pacing
- Shortcut unlock messaging

### Slice 4: Endgame

- Bagua Tower resolution
- Festival controller
- Ending summary and postgame state

## Endgame Flow

### 1. Return to Ferry Plaza

After recovering all fragments, the player is told the festival can begin at sunset near the ferry / central plaza.

### 2. Final Preparation

Player can:

- Speak to residents one last time
- Finish a few optional side tasks
- Choose whether to start the performance now

### 3. Festival Performance

This is the payoff sequence.

Structure:

1. Residents from completed quest lines gather.
2. The player activates each recovered melody fragment in order.
3. The full arrangement plays.
4. The island visually responds:
   - lights
   - windows
   - crowd movement
   - environmental audio swell

### 4. Ending Choice

After the performance, offer a simple emotional choice:

- `Leave on the morning ferry`
- `Stay on the island a little longer`

This supports two ending tones without branching the whole game.

## Ending States

### Standard Ending

Player restores the melody and departs. The island is no longer quiet, and the ferry ride frames closure.

### Community Ending

If the player completes most side stories, more NPCs appear at the festival and the ending emphasizes belonging.

### Wanderer Ending

If the player chooses to stay, postgame free exploration remains available with lighter ambient dialogue.

## Failure and Recovery

Avoid heavy fail states. Use recovery loops that fit the tone.

Preferred setbacks:

- Getting lost in tunnels
- Escort NPC stopping
- Temporary blocked path
- Missed clue requiring another conversation

Avoid:

- Frequent hard resets
- Combat deaths as the primary fail condition
- Long checkpoint loss

## Scene-to-System Mapping

### Existing systems already aligned

- Overworld exploration: [`main.tscn`](main.tscn)
- Global player reference: [`game/game_global.gd`](game/game_global.gd)
- Interaction radius and dialogue bubble logic: [`characters/control/base_controller.gd`](characters/control/base_controller.gd)
- Player input and inspect action: [`characters/control/player_controller.gd`](characters/control/player_controller.gd)
- NPC autonomous presence and talk detection: [`characters/control/npc_controller.gd`](characters/control/npc_controller.gd)
- Layered traversal through portals / stairs: [`architecture/components/portal.gd`](architecture/components/portal.gd)
- Tunnel masking and layered tunnel traversal: [`architecture/tunnel.gd`](architecture/tunnel.gd)

### Systems to add next

1. Quest state machine
2. Journal / map UI
3. Landmark objective triggers
4. Melody fragment inventory
5. Endgame festival sequence controller
6. Save / load progression data

## Suggested Production Milestones

### Milestone 1: Playable Vertical Slice

- Ferry arrival
- One NPC
- One journal objective
- Trinity Church quest
- One melody fragment reward

### Milestone 2: Traversal Expansion

- Both tunnels functional as objective spaces
- Shortcuts unlocking properly
- Escort NPC prototype

### Milestone 3: Structure Lock

- Bagua Tower progression
- Four fragments connected to one main quest
- Journal and completion tracking

### Milestone 4: Endgame

- Festival assembly
- Ending choice
- Postgame free walk

## One-Sentence Loop

Arrive by ferry, explore the island's landmark districts, help residents recover four pieces of a lost festival melody, reunite the island through a final performance, and choose whether to leave Kulangsu or remain part of it.
