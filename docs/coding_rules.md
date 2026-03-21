# Kulangsu Coding Rules

Read [`design_brief.md`](design_brief.md), then check [`architecture.md`](architecture.md) and the nearby module before editing.

Generic Godot and GDScript conventions live in [`../codex_agents/GODOT_DEVELOPMENT_RUNBOOK.md`](../codex_agents/GODOT_DEVELOPMENT_RUNBOOK.md).
Generic source-control and submodule-history rules live in [`../codex_agents/SOURCE_CONTROL_RUNBOOK.md`](../codex_agents/SOURCE_CONTROL_RUNBOOK.md).

This file is only for Kulangsu-specific coding constraints.

Keep shared/common coding rules in [`../codex_agents/`](../codex_agents). Add rules here only when they are specific to Kulangsu's scene structure, UI flow, state ownership, or repo workflow.

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

## Documentation Rules

- Update [`coding_rules.md`](coding_rules.md) when repo conventions change.
- Keep older deep-dive docs in sync when they still describe the affected feature.
- Keep documentation changes in the same patch when practical.
- Move reusable or cross-project guidance into [`../codex_agents/`](../codex_agents) instead of duplicating it here.
