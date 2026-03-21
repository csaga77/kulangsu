# Kulangsu Feature Docs

This folder is the preferred place to document feature-level behavior.

Use feature docs to capture:

- gameplay rules and player-facing behavior
- feature requirements and intended outcomes
- ownership boundaries between scenes, scripts, state, and content
- boundaries, contracts, and module interactions that future edits must preserve
- important edge cases or constraints
- validation expectations

## When To Add Or Update A Feature Doc

Add a new feature doc when:

- you introduce a new gameplay feature, UI flow, reusable system, or mini-game
- an existing root-level design doc is too broad for the change you are making

Update an existing feature doc when:

- behavior or rules change
- boundaries or ownership move between modules
- a new contract or integration point becomes important to the feature
- new edge cases, validation steps, or important limitations appear

## How To Use This Folder

- Start from [`template.md`](template.md).
- Keep each file focused on one durable feature or subsystem.
- Link to deeper design docs when they already exist instead of duplicating long explanations.
- This folder is still only partially populated. If a system currently has only a root-level design doc one level up, treat that existing doc as the source of truth until a short feature summary is added here.
- Avoid creating duplicate docs with overlapping ownership. Prefer extending the existing authoritative doc, then add a concise feature summary here when the extra entry point would help future contributors.
- Keep the feature doc in the same patch as the code change when practical.
- If a feature changes architecture, interfaces, or release implications, also update [`../architecture.md`](../architecture.md), [`../contracts.md`](../contracts.md), or [`../release_policy.md`](../release_policy.md) as needed.

## Relationship To Existing Design Docs

This repo already has deeper system design docs at the root of [`../`](../), including:

- [`../npc_system_design.md`](../npc_system_design.md)
- [`../player_costume_system.md`](../player_costume_system.md)
- [`../grid_board_game_design.md`](../grid_board_game_design.md)
- [`../marble_game_design.md`](../marble_game_design.md)
- [`../piano_game_design.md`](../piano_game_design.md)
- [`../core_gameplay_plays.md`](../core_gameplay_plays.md)

Use those as deeper reference material when they are still accurate, but prefer this folder for the short, implementation-facing summary a future Codex session needs first.
