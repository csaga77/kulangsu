Keep this file Kulangsu-specific.

Common agent rules, shared workflow guidance, and reusable runbook conventions belong in `codex_agents/`, not here.

## Quick Start

- Read `docs/design_brief.md` first for the project goal, player loop, and UI direction.
- Then read `docs/architecture.md`, `docs/module_map.md`, and `docs/submodules.md` before making structural changes.
- Read `docs/contracts.md` when changing shared state, interfaces, signals, public APIs, or submodule boundaries.
- Read `docs/release_policy.md` before changing versioning, release preparation, or submodule pinning practices.
- Use `docs/features/README.md` and `docs/features/template.md` when you add or significantly change a feature.
- Read `codex_agents/AGENTS.md` for generic agent behavior and reusable runbook guidance.
- If a task touches a submodule directly, read `docs/submodules.md` first, then open that submodule's own `AGENTS.md` and repo docs before changing anything inside it.

Only open the longer design docs if the task needs more depth:

- `docs/ui_design_context.md` for UI architecture and layout constraints
- `docs/core_game_workflow.md` for story and progression structure
- `docs/ui_workflow.md` for full-screen and menu flow details

Submodule doc entry points:

- `codex_agents/AGENTS.md` and `codex_agents/README.md` for shared agent guidance and runbook discovery
- `godot_common/AGENTS.md`, `godot_common/README.md`, and `godot_common/docs/` for the shared Godot support-code submodule
- `godot_tilemap/AGENTS.md`, `godot_tilemap/README.md`, and `godot_tilemap/docs/` for the tilemap helper/tooling submodule
- `3rdparty/Universal-LPC-Spritesheet-Character-Generator/README.md` for upstream LPC generator usage and licensing details

Submodule read order when editing inside a submodule:

- `godot_common`: `godot_common/AGENTS.md` -> `godot_common/README.md` -> `godot_common/docs/architecture.md` -> `godot_common/docs/module_map.md` -> `godot_common/docs/coding_rules.md`
- `godot_tilemap`: `godot_tilemap/AGENTS.md` -> `godot_tilemap/README.md` -> `godot_tilemap/docs/architecture.md` -> `godot_tilemap/docs/module_map.md` -> `godot_tilemap/docs/coding_rules.md`
- `codex_agents`: `codex_agents/AGENTS.md` -> `codex_agents/README.md` -> the relevant `codex_agents/docs/` files for the task
- `3rdparty/Universal-LPC-Spritesheet-Character-Generator`: upstream `README.md` first, then tool docs if the task touches generator workflows

## Project Conventions

- This is a Godot 4 GDScript project with scene ownership centered on `.tscn` files plus nearby scripts.
- Follow the generic Godot/GDScript rules in `codex_agents/GODOT_DEVELOPMENT_RUNBOOK.md`; this file only captures Kulangsu-specific constraints, boundaries, and exceptions.
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
- Do not mix top-level file changes and submodule pointer updates in the same parent-repo commit.
- If a task spans both the parent repo and one or more submodules, use separate commits:
  - commit the submodule repo changes inside each submodule first
  - commit the parent repo file changes separately
  - commit any parent repo submodule pointer updates separately
- Do not invent dependencies, release workflows, CI jobs, or tooling that are not present in the repo.

## Testing And Validation

- If behavior changes, run the project or the most relevant scene when practical.
- For app flow, HUD, overlay, or shared-state changes, validate through the main project flow.
- For isolated features, use the existing validation scenes under `scenes/` and feature-local test scenes such as the ones in `game/grid_board_game/`.
- If you cannot run validation, say so explicitly in the final handoff.

## Documentation Maintenance

Documentation must stay consistent with the codebase.

Keep shared/common documentation guidance in `codex_agents/`. Add rules here only when they are specific to Kulangsu, its architecture, or its repo workflow.

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
- If work changes a submodule directly, update that submodule's own `AGENTS.md`, `README.md`, and `docs/` files when their guidance or ownership notes change.
