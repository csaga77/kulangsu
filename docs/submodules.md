# Kulangsu Submodules

This repository uses git submodules for shared code, tooling, vendor content, and agent support docs.

Source of truth:

- [`.gitmodules`](../.gitmodules)

## Current Submodules

### `godot_common`

- Path: [`../godot_common/`](../godot_common)
- Branch in `.gitmodules`: `main`
- Role in this repo: shared Godot support code reused by the main project

### `godot_tilemap`

- Path: [`../godot_tilemap/`](../godot_tilemap)
- Branch in `.gitmodules`: `main`
- Role in this repo: tilemap-related helpers and support code

### `3rdparty/Universal-LPC-Spritesheet-Character-Generator`

- Path: [`../3rdparty/Universal-LPC-Spritesheet-Character-Generator/`](../3rdparty/Universal-LPC-Spritesheet-Character-Generator)
- Branch in `.gitmodules`: `master`
- Role in this repo: third-party LPC asset generator content

### `codex_agents`

- Path: [`../codex_agents/`](../codex_agents)
- Branch in `.gitmodules`: `main`
- Role in this repo: shared agent runbooks, templates, and related docs

## Governance Rules

- Treat each submodule as its own repository boundary.
- Do not change a submodule unless the task actually requires it.
- If a task needs a submodule change, inspect that submodule’s own docs first.
- Keep parent-repo changes and submodule changes logically separate even when delivered together.
- When a submodule commit changes, the parent repo must update the submodule pointer intentionally.

## When To Edit A Submodule

Edit the submodule itself when:

- the bug or feature lives in the submodule, not just in how the parent repo uses it
- the parent repo needs a reusable fix that belongs upstream in the shared code
- a template, runbook, or shared helper should stay canonical in the submodule

Edit only the parent repo when:

- the issue is local integration, scene wiring, or content usage
- the parent repo can adapt without changing shared code
- you only need documentation about how the parent repo consumes the submodule

## Documentation Expectations

If submodule behavior or integration changes:

- Update [`architecture.md`](architecture.md) if ownership or relationships change.
- Update [`module_map.md`](module_map.md) if routing or folder roles change.
- Update [`contracts.md`](contracts.md) if the submodule interface or assumptions change.
- Update [`release_policy.md`](release_policy.md) if submodule pinning or release expectations change.

## Validation Expectations

- Verify the parent repo still loads or runs after changing a submodule pointer.
- Validate the smallest relevant flow that exercises the changed submodule integration.
- If a submodule was edited directly, call out both the submodule worktree state and the parent pointer change in the handoff.
