Keep this file Kulangsu-specific.

Common agent rules, shared workflow guidance, and reusable runbook conventions belong in `codex_agents/`, not here.

## Quick Start

- Read `docs/design_brief.md` first for the project goal, player loop, and UI direction.
- For source-control-only tasks, skip the gameplay design docs and start with `scripts/source_control_report.py`, `docs/submodules.md`, and `codex_agents/SOURCE_CONTROL_RUNBOOK.md`.
- For helper-ROI or token-efficiency workflow review, start with `scripts/token_efficiency_audit.py` and `codex_agents/TOKEN_EFFICIENCY_RUNBOOK.md`.
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

- `codex_agents/AGENTS.md` for shared agent guidance and runbook routing; open `codex_agents/README.md` only when overview or onboarding context helps
- `godot_common/AGENTS.md`, `godot_common/README.md`, and `godot_common/docs/` for the shared Godot support-code submodule
- `godot_tilemap/AGENTS.md`, `godot_tilemap/README.md`, and `godot_tilemap/docs/` for the tilemap helper/tooling submodule
- `3rdparty/Universal-LPC-Spritesheet-Character-Generator/README.md` for upstream LPC generator usage and licensing details

Submodule read order when editing inside a submodule:

- `godot_common`: `godot_common/AGENTS.md` -> `godot_common/README.md` -> `godot_common/docs/architecture.md` -> `godot_common/docs/module_map.md` -> `godot_common/docs/coding_rules.md`
- `godot_tilemap`: `godot_tilemap/AGENTS.md` -> `godot_tilemap/README.md` -> `godot_tilemap/docs/architecture.md` -> `godot_tilemap/docs/module_map.md` -> `godot_tilemap/docs/coding_rules.md`
- `codex_agents`: `codex_agents/AGENTS.md` -> the relevant runbook or `codex_agents/docs/` file for the task -> `codex_agents/README.md` if overview or onboarding context is needed
- `3rdparty/Universal-LPC-Spritesheet-Character-Generator`: upstream `README.md` first, then tool docs if the task touches generator workflows

## Project Conventions

- This is a Godot 4 GDScript project with scene ownership centered on `.tscn` files plus nearby scripts.
- Follow the generic Godot/GDScript, scope, resource, and validation rules in `codex_agents/GODOT_DEVELOPMENT_RUNBOOK.md`.
- Follow the generic Git and submodule-history rules in `codex_agents/SOURCE_CONTROL_RUNBOOK.md`.
- For parent-repo Git inspection, prefer `python3 scripts/source_control_report.py` before manual Git status commands, and rerun it after commits, pushes, pulls, rebases, or submodule pointer updates when you need a fresh summary.
- For token-efficiency review, prefer `python3 scripts/token_efficiency_audit.py` and do not run it on every normal task; use it when helper workflows change or on periodic amortized review.
- This file only captures Kulangsu-specific constraints, boundaries, and exceptions.

## Architecture Boundaries

- `main.tscn` and `main.gd` own startup, title flow, overlay flow, and UI scaling.
- `scenes/game_main.tscn` and `scenes/game_main.gd` own the island scene, landmark syncing, resident spawning, and world-to-UI integration.
- `game/app_state.gd` owns shared UI-facing and progression-facing state. Do not turn it into a dump for scene-local logic.
- Reusable gameplay modules should stay under `game/` in their existing feature folders such as `grid_board_game`, `marble_game`, and `piano_game`.
- Landmark scenes and reusable building pieces belong under `architecture/`.
- Keep gameplay rules in gameplay modules and controllers, not in UI scripts.
- Treat `godot_common`, `godot_tilemap`, `codex_agents`, and `3rdparty/Universal-LPC-Spritesheet-Character-Generator` as submodule boundaries, not normal local folders.

## Change Scope Rules

- Do not edit a submodule from the parent repo unless the task actually requires changing that submodule.
- Use [`docs/submodules.md`](docs/submodules.md) for Kulangsu-specific submodule routing and doc entry points.

## Testing And Validation

- Follow the generic validation expectations in `codex_agents/GODOT_DEVELOPMENT_RUNBOOK.md`.
- For app flow, HUD, overlay, or shared-state changes, validate through the main project flow.
- For isolated features, use the existing validation scenes under `scenes/tests/` and feature-local test scenes such as the ones in `game/grid_board_game/`.

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
