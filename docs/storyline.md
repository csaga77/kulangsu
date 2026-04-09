# Kulangsu Storyline

Read [`design_brief.md`](design_brief.md) first for the minimum-token summary. Use this file when you need the dedicated narrative summary for the current game rather than the system and progression detail in [`core_game_workflow.md`](core_game_workflow.md).

## Purpose

This document is the narrative source of truth for Kulangsu's current main story.

Keep story premise, thematic throughline, landmark-by-landmark narrative progression, and ending framing here.
Keep implementation state machines, quest plumbing, UI flow, and save behavior in the other docs that own those systems.

## Story Premise

The player arrives on Kulangsu by ferry as a newcomer on a day when the island feels strangely quiet.

What first reads as a small curiosity gradually becomes the main mystery of the game: parts of the island's shared musical memory have faded, and the old festival tune that once connected its landmarks and residents no longer fully carries across the island.

The player's journey is not about defeating an enemy or solving a single hard puzzle. It is about walking the island, listening carefully, helping residents, and restoring the melody that lets the island feel whole again.

## Player Role

The player character is intentionally framed as an outsider at the start:

- they arrive by ferry
- they do not yet understand the island's rhythms
- they learn Kulangsu through residents, landmarks, and repeated return trips across the same spaces

By the end of the story, the player should no longer feel like a tourist passing through. They should feel like someone who understands how the island's people and places connect.

## Narrative Spine

The current canonical story arc is:

1. Arrive on the island with a simple question about why it feels so quiet.
2. Notice that residents, places, and ambient sounds still carry partial traces of a missing melody.
3. Help each landmark district resolve its local tension.
4. Recover four melody fragments tied to the island's lost festival tune.
5. Reconstruct and perform the full melody at Ferry Plaza.
6. Choose whether to leave on the morning ferry or stay a little longer.

The story should feel calm, intimate, and place-driven throughout. Even when the player is progressing the main quest, the emotional tone should stay closer to listening and belonging than to urgency or danger.

## Central Mystery

The island's quiet is the story's main mystery.

The current docs intentionally keep the exact cause somewhat soft. What matters in the present draft is the felt truth:

- the island is missing part of its musical memory
- residents remember pieces of it differently
- landmarks hold onto fragments through sound, routine, and place
- restoring the melody helps the island feel inhabited and connected again

Future story expansion can explain the history in more detail, but new writing should preserve this gentle, memory-first framing unless the project direction changes deliberately.

## Landmark Story Beats

The current five-landmark route is the narrative backbone.

### Piano Ferry

Ferry Plaza is both the opening frame and the ending frame.

The player arrives here, notices the unusual quiet, meets Caretaker Lian, and hears the harbor refrain more clearly near the old piano crate. This district establishes that music on Kulangsu is not just performance. It is memory, orientation, and social connection.

### Trinity Church

Trinity Church is the first full lesson in listening.

The church arc is about harmony, memory, and community. By following the scattered choir cues and returning to Mei, the player learns that the island's missing music can still be found in ordered traces. The reward is not only the first fragment, but the realization that the melody is distributed through people and places rather than lost outright.

### Bi Shan Tunnel

Bi Shan Tunnel turns the story inward.

This arc emphasizes uncertainty, echo, and hidden passage. The player follows reflected cues through a disorienting space and learns that memory on the island does not always present itself directly. Some parts of the melody must be recovered through attention, patience, and spatial trust.

### Long Shan Tunnel

Long Shan Tunnel shifts the story from listening to companionship.

Instead of simply tracing echoes, the player helps another person cross safely. This landmark makes trust and reassurance part of the restoration arc. The recovered fragment matters, but so does the fact that the player becomes someone residents can rely on.

### Bagua Tower

Bagua Tower is the synthesis point.

After learning the island piece by piece, the player finally gains enough perspective to assemble the fragments into a coherent whole. The tower should feel like revelation rather than escalation for its own sake: the player can now read the island as one connected composition instead of a string of isolated tasks.

## Festival And Resolution

Once the melody is restored, the player returns to Ferry Plaza for the harbor-stage performance.

This sequence is the emotional payoff for the whole journey. The island responds through light, sound, gathered residents, and a renewed sense of presence. The festival should feel like the island remembering itself in public.

The ending then asks a simple personal question:

- leave on the morning ferry
- stay a little longer

That choice should feel like the final expression of what the player has become over the course of the walk across the island.

## Ending Tones

The current story supports three ending tones:

- Standard ending: the melody is restored and the player departs with a sense of closure
- Community ending: stronger resident turnout and relationship payoff emphasize belonging
- Wanderer ending: the player stays, and postgame exploration continues in a lighter, resonant state

These are tonal variations on the same core story, not three separate branching plots.

## Narrative Rules

- Keep the story calm, local, and place-driven.
- Keep the main conflict centered on memory, connection, and restoration rather than villainy.
- Keep the ferry as the framing image for both arrival and departure.
- Keep the five-landmark route canonical unless the project makes an explicit world-design change.
- Let residents and landmarks carry the story more than exposition dumps or detached cutscenes.
- Treat the final performance as a communal ritual, not a victory screen.

## Related Docs

- [`design_brief.md`](design_brief.md) for the shortest project summary
- [`core_game_workflow.md`](core_game_workflow.md) for quest flow, chapter structure, and ending-state implementation framing
- [`event_story_system_design.md`](event_story_system_design.md) for narrative-system extension ideas such as conditional dialogue and festival turnout
- [`npc_system_design.md`](npc_system_design.md) for how resident writing and progression hooks are structured in data and runtime state
