# Kulangsu Docs Index

Start here if you need to understand the current source of truth before editing code or docs.

## Canonical Docs

Open these in roughly this order:

1. [`design_brief.md`](design_brief.md) for the shortest product and UI summary
2. [`core_game_workflow.md`](core_game_workflow.md) for the current gameplay and progression structure
3. [`story/summer_of_piano_island_story_framework.md`](story/summer_of_piano_island_story_framework.md) for story canon
4. [`plan/implementation_plan.md`](plan/implementation_plan.md) for the active implementation priorities
5. [`architecture.md`](architecture.md), [`module_map.md`](module_map.md), and [`contracts.md`](contracts.md) for ownership and boundaries

These files are the current source of truth for the shipped seasonal multi-route game.

## Supporting Docs

Use these when you need more depth on a particular slice:

- [`core_gameplay_plays.md`](core_gameplay_plays.md) for repeatable moment-to-moment gameplay patterns
- [`ui_design_context.md`](ui_design_context.md) and [`ui_workflow.md`](ui_workflow.md) for UI layout and overlay flow
- [`features/README.md`](features/README.md) for implementation-facing feature summaries
- [`submodules.md`](submodules.md) for submodule boundaries and routing

## Plan Docs

[`plan/`](plan/) now keeps only the current status and implementation plan. It is no longer an archive of superseded draft directions.

## Consolidation Rule

When docs overlap, prefer moving durable information into the doc that already owns that topic instead of creating another parallel design file.

- story canon belongs in [`story/summer_of_piano_island_story_framework.md`](story/summer_of_piano_island_story_framework.md)
- gameplay and progression structure belongs in [`core_game_workflow.md`](core_game_workflow.md)
- moment-to-moment play patterns belong in [`core_gameplay_plays.md`](core_gameplay_plays.md)
- implementation sequencing belongs in [`plan/implementation_plan.md`](plan/implementation_plan.md)
- system ownership belongs in [`architecture.md`](architecture.md), [`module_map.md`](module_map.md), and [`contracts.md`](contracts.md)
