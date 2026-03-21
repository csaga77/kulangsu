# Kulangsu Submodules

This repository uses git submodules for shared code, tooling, vendor content, and agent support docs.

Source of truth:

- [`.gitmodules`](../.gitmodules)

## Current Submodules

### `godot_common`

- Path: [`../godot_common/`](../godot_common)
- Branch in `.gitmodules`: `main`
- Role in this repo: shared Godot support code reused by the main project
- Docs to read first: [`../godot_common/AGENTS.md`](../godot_common/AGENTS.md), [`../godot_common/README.md`](../godot_common/README.md), [`../godot_common/docs/architecture.md`](../godot_common/docs/architecture.md), [`../godot_common/docs/module_map.md`](../godot_common/docs/module_map.md), and [`../godot_common/docs/coding_rules.md`](../godot_common/docs/coding_rules.md)
- Documentation status inside submodule: agent-facing startup and architecture docs are now available in the submodule itself

### `godot_tilemap`

- Path: [`../godot_tilemap/`](../godot_tilemap)
- Branch in `.gitmodules`: `main`
- Role in this repo: tilemap-related helpers and support code
- Docs to read first: [`../godot_tilemap/AGENTS.md`](../godot_tilemap/AGENTS.md), [`../godot_tilemap/README.md`](../godot_tilemap/README.md), [`../godot_tilemap/docs/architecture.md`](../godot_tilemap/docs/architecture.md), [`../godot_tilemap/docs/module_map.md`](../godot_tilemap/docs/module_map.md), and [`../godot_tilemap/docs/coding_rules.md`](../godot_tilemap/docs/coding_rules.md)
- Documentation status inside submodule: agent-facing startup and architecture docs are now available in the submodule itself

### `3rdparty/Universal-LPC-Spritesheet-Character-Generator`

- Path: [`../3rdparty/Universal-LPC-Spritesheet-Character-Generator/`](../3rdparty/Universal-LPC-Spritesheet-Character-Generator)
- Branch in `.gitmodules`: `master`
- Role in this repo: third-party LPC asset generator content
- Docs to read first: [`../3rdparty/Universal-LPC-Spritesheet-Character-Generator/README.md`](../3rdparty/Universal-LPC-Spritesheet-Character-Generator/README.md)
- Additional docs: [`../3rdparty/Universal-LPC-Spritesheet-Character-Generator/tools/README.md`](../3rdparty/Universal-LPC-Spritesheet-Character-Generator/tools/README.md)
- Important note for this repo: the upstream README is also the best source for licensing and attribution expectations around LPC assets

### `codex_agents`

- Path: [`../codex_agents/`](../codex_agents)
- Branch in `.gitmodules`: `main`
- Role in this repo: shared agent runbooks, templates, and related docs
- Docs to read first: [`../codex_agents/AGENTS.md`](../codex_agents/AGENTS.md) and [`../codex_agents/README.md`](../codex_agents/README.md)
- Additional docs: [`../codex_agents/docs/architecture.md`](../codex_agents/docs/architecture.md), [`../codex_agents/docs/module_map.md`](../codex_agents/docs/module_map.md), [`../codex_agents/docs/coding_rules.md`](../codex_agents/docs/coding_rules.md), and feature docs under [`../codex_agents/docs/features/`](../codex_agents/docs/features)

## Submodule Documentation Index

Use this section when a task crosses the parent repo boundary and you need the submodule's own guidance, not just the parent repo's integration notes.

### Parent Repo First

Start with:

- [`submodules.md`](submodules.md) for ownership, edit rules, and pointer governance
- [`architecture.md`](architecture.md) and [`module_map.md`](module_map.md) for how the parent repo consumes each submodule
- [`contracts.md`](contracts.md) if the task changes a stable interface or assumption between the parent repo and a submodule

### Then Open The Relevant Submodule Docs

- `codex_agents`: start with [`../codex_agents/AGENTS.md`](../codex_agents/AGENTS.md), then [`../codex_agents/README.md`](../codex_agents/README.md)
- `godot_common`: start with [`../godot_common/AGENTS.md`](../godot_common/AGENTS.md), then [`../godot_common/README.md`](../godot_common/README.md)
- `godot_tilemap`: start with [`../godot_tilemap/AGENTS.md`](../godot_tilemap/AGENTS.md), then [`../godot_tilemap/README.md`](../godot_tilemap/README.md)
- `3rdparty/Universal-LPC-Spritesheet-Character-Generator`: start with [`../3rdparty/Universal-LPC-Spritesheet-Character-Generator/README.md`](../3rdparty/Universal-LPC-Spritesheet-Character-Generator/README.md), then check tool docs if the task touches generator workflows

### Documentation Caveat

- Third-party and vendor-style submodules may still rely primarily on their upstream README rather than a full local doc set.
- When a submodule's own docs are sparse, keep the parent repo's integration docs authoritative for how Kulangsu uses that submodule.
- If you improve or expand submodule docs upstream, update this file so future contributors can discover the new entry points.

## Governance Rules

- Treat each submodule as its own repository boundary.
- Do not change a submodule unless the task actually requires it.
- If a task needs a submodule change, inspect that submodule’s own docs first.
- Keep parent-repo changes and submodule changes logically separate even when delivered together.
- When a submodule commit changes, the parent repo must update the submodule pointer intentionally.
- Do not mix parent-repo file edits and submodule pointer updates in the same parent-repo commit.
- Preferred commit order for cross-repo work:
  - submodule repo commit(s)
  - parent repo file-change commit(s)
  - parent repo submodule-pointer commit(s)

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
