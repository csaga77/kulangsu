# Kulangsu Coding Rules

Read [`design_brief.md`](design_brief.md), then check [`architecture.md`](architecture.md) and the nearby module before editing.

Generic Godot and GDScript conventions live in [`../codex_agents/GODOT_DEVELOPMENT_RUNBOOK.md`](../codex_agents/GODOT_DEVELOPMENT_RUNBOOK.md). This file is only for Kulangsu-specific coding constraints.

## Scene Ownership

- Keep scene-specific behavior inside the owning scene script unless reuse clearly justifies extraction.
- Follow the local ownership pattern before introducing a new abstraction.
- Prefer self-contained scene logic over scattering behavior across many helpers.
- Do not move logic into new autoloads unless the project truly needs shared global state.

## State and Data Flow

- Put shared UI-facing progression state in [`../game/app_state.gd`](../game/app_state.gd).
- Keep gameplay rules in gameplay scripts and modules, not in UI scripts.
- Keep rendering, shader, and presentation concerns separate from gameplay logic where practical.
- When a feature already has a local module folder under [`../game/`](../game), extend that module before creating parallel logic elsewhere.

## UI Rules

- Preserve the current app-shell pattern in [`../ui/app_flow_root.gd`](../ui/app_flow_root.gd).
- Keep in-game menus and panels as overlays unless a redesign intentionally changes the flow.
- Author UI against the `1920 x 1080` design canvas used by the shell.
- Do not rely on fragile fixed offsets that assume a large desktop viewport.
- Grow shared styling from [`../ui/ui_style.gd`](../ui/ui_style.gd) instead of hardcoding the same values across screens.

## Resources and Paths

- Preserve existing resource paths and loading patterns.
- Avoid renaming or moving scenes, scripts, assets, or exported properties unless the task requires it.
- Check scene references after touching `.tscn`, `.tres`, and preload paths.
- Use relative paths in project docs and agent instructions.

## Signals and Node Access

- Use signals for clear scene-to-scene or component-to-component events.
- Do not add a signal when a direct local call is simpler.
- Keep signal names explicit and consistent with nearby code.
- Prefer node access patterns that match the local file.
- Check for null when a node might not exist.

## Validation

- Update or add demo or test scenes when behavior changes.
- Make sure changed scenes still load.
- Recheck signal connections, exported defaults, and resource references.
- Prefer small reproducible validation scenes for new systems.

## Documentation Rules

- Update [`coding_rules.md`](coding_rules.md) when repo conventions change.
- Keep older deep-dive docs in sync when they still describe the affected feature.
- Keep documentation changes in the same patch when practical.

## Do Not

- Refactor unrelated systems while solving a focused task.
- Add new singleton state for scene-local behavior.
- Move assets or scripts without checking downstream references.
- Replace the overlay-driven in-game UI flow with hard scene swaps by accident.
- Leave docs stale after changing architecture, feature ownership, or workflow.
