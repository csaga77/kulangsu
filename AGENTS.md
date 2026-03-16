## Quick Start

- Read `docs/design_brief.md` first for the project goal, player loop, and UI direction.
- Then read `docs/architecture.md`, `docs/module_map.md`, and `docs/submodules.md` before making structural changes.
- Read `docs/contracts.md` when changing shared state, interfaces, signals, public APIs, or submodule boundaries.
- Read `docs/release_policy.md` before changing versioning, release preparation, or submodule pinning practices.
- Use `docs/features/README.md` and `docs/features/template.md` when you add or significantly change a feature.
- Read `codex_agents/AGENTS.md` only for generic agent behavior and reusable runbook guidance.

Only open the longer design docs if the task needs more depth:

- `docs/ui_design_context.md` for UI architecture and layout constraints
- `docs/core_game_workflow.md` for story and progression structure
- `docs/ui_workflow.md` for full-screen and menu flow details

## Project Conventions

- This is a Godot 4 GDScript project with scene ownership centered on `.tscn` files plus nearby scripts.
- Follow the generic Godot/GDScript rules in `codex_agents/GODOT_DEVELOPMENT_RUNBOOK.md`; this file only captures Kulangsu-specific constraints and boundaries.
- Keep documentation links relative to the file they live in.
- Preserve existing resource paths, scene names, and exported properties unless the task requires a change.
- Do not invent dependencies, build steps, save systems, or workflows that are not present in the repo.

## Architecture Boundaries

- `ui/app_flow_root.tscn` and `ui/app_flow_root.gd` own startup, title flow, overlay flow, and UI scaling.
- `main.tscn` and `main.gd` own the island scene, landmark syncing, resident spawning, and world-to-UI integration.
- `game/app_state.gd` owns shared UI-facing and progression-facing state. Do not turn it into a dump for scene-local logic.
- Reusable gameplay modules should stay under `game/` in their existing feature folders such as `grid_board_game`, `marble_game`, and `piano_game`.
- Landmark scenes and reusable building pieces belong under `architecture/`.
- Keep gameplay rules in gameplay modules and controllers, not in UI scripts.
- Treat `godot_common`, `godot_tilemap`, `codex_agents`, and `3rdparty/Universal-LPC-Spritesheet-Character-Generator` as submodule boundaries, not normal local folders.

## Change Scope Rules

- Prefer minimal, safe changes that fit the existing module and scene structure.
- Do not refactor unrelated systems while solving a focused task.
- Reuse established patterns in nearby files before introducing new abstractions.
- Do not move assets, rename resources, or add new globals unless the task clearly requires it.
- Do not edit a submodule from the parent repo unless the task actually requires changing that submodule.
- Do not invent dependencies, release workflows, CI jobs, or tooling that are not present in the repo.

## Testing And Validation

- If behavior changes, run the project or the most relevant scene when practical.
- For app flow, HUD, overlay, or shared-state changes, validate through the main project flow.
- For isolated features, use the existing validation scenes under `scenes/` and feature-local test scenes such as the ones in `game/grid_board_game/`.
- If you cannot run validation, say so explicitly in the final handoff.

## Documentation Maintenance

Documentation must stay consistent with the codebase.

If a change introduces or significantly changes a feature, system behavior, module structure, or architecture, update the relevant docs in the same patch whenever practical.

At minimum:

- Update `README.md` when the project overview, setup, or validation guidance changes.
- Update `docs/architecture.md` when subsystem ownership or relationships change.
- Update `docs/module_map.md` when code or content moves, or when a new module is introduced.
- Update `docs/submodules.md` when submodule roles, boundaries, or update expectations change.
- Update `docs/contracts.md` when interfaces, data flow, public APIs, or cross-module expectations change.
- Update `docs/release_policy.md` when release/versioning practice or submodule pinning policy changes.
- Add or update a feature spec under `docs/features/` when a gameplay feature, UI flow, reusable module, or important system behavior changes.
- Update `docs/design_brief.md` if the quick-start product framing changes materially.
