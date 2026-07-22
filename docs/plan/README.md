# Planning Docs

Read [`../design_brief.md`](../design_brief.md) first, then open the smallest planning document that matches the task.

Use this folder for:

- the current status of the active direction
- the current implementation plan

## Current Files

- [`implementation_plan.md`](implementation_plan.md) is the canonical status-and-plan document for the current playable game.
- [`low_poly_3d_replacement.md`](low_poly_3d_replacement.md) is the completed hard-cutover record for replacing the 2D overworld and retiring its character/NPC, landmark/component, level/portal, tilemap terrain/water, overlay weather, and LPC stack.

## Current Position

- The current playable canon is the seasonal multi-route architecture.
- The five-landmark melody route remains canonical as one major route inside that broader structure.
- Physical traversal jumping, carrying, deliberate push/pull, sitting, and ladder climbing form a required planned character-action workstream; [`implementation_plan.md`](implementation_plan.md) owns its sequencing and status.
- `implementation_plan.md` is the source of truth for what is shipped, what is still active, and what the next follow-on work should be.
- This folder no longer keeps historical or superseded draft notes.

## Merge Rule

If a temporary planning note is created during a live design change, merge the durable parts into the doc that already owns that topic, then delete the temporary note:

- story direction -> [`../story/summer_of_piano_island_story_framework.md`](../story/summer_of_piano_island_story_framework.md)
- gameplay-loop design -> [`../core_gameplay_plays.md`](../core_gameplay_plays.md) or [`../core_game_workflow.md`](../core_game_workflow.md)
- implementation sequencing -> [`implementation_plan.md`](implementation_plan.md)
- project framing and doc routing -> [`../design_brief.md`](../design_brief.md), [`../module_map.md`](../module_map.md), and [`../../README.md`](../../README.md)

When a planned workstream or roadmap item is implemented, update [`implementation_plan.md`](implementation_plan.md) and every affected canonical doc together in the same patch. At minimum, review [`../design_brief.md`](../design_brief.md), [`../core_game_workflow.md`](../core_game_workflow.md), [`../core_gameplay_plays.md`](../core_gameplay_plays.md), [`../story/summer_of_piano_island_story_framework.md`](../story/summer_of_piano_island_story_framework.md), [`../module_map.md`](../module_map.md), the relevant feature docs under [`../features/`](../features/), and this index file whenever planning status or routing changes.
