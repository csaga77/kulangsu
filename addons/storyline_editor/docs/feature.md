# Storyline Graph Editor — Feature

## Goal

- Give authors a visual, in-editor way to browse, inspect, and edit storyline routes, events, and their prerequisite dependencies.
- Stay a view/edit layer over the canonical storyline route resources without becoming a second source of truth.

## User / Developer Experience

Enable via Project → Project Settings → Plugins. The plugin adds three coordinated surfaces:

**Route browser** (left dock, "Storyline Browser") — one combined storyline tree whose top-level rows are routes and whose child rows are that route's events. It surfaces project-wide missing-prerequisite validation warnings, offers `+ New` to scaffold a route, and a selection-driven `Delete`. Deleting a route confirms, then removes that route's authored resource files; deleting an event confirms, then removes it from the canonical typed route resource. A deleted route/event that was open in the Inspector is cleared. Selecting a route opens its `StorylineRouteResource` in the Inspector, selecting an event opens its `StorylineEventResource`, and double-clicking an event highlights it in the graph.

**Storyline Graph** (bottom panel) — a `GraphEdit` dependency view/editor showing all events as color-coded nodes with prerequisite edges. Nodes expose separate `All` and `Any` input slots for hard versus optional prerequisites. It supports per-route filtering, zoom/pan, dependency editing by connecting/disconnecting edges (dragging either end of a connection removes it), an `Arrange` toolbar action that resets the visible graph to automatic dependency layout, and node selection that opens the backing `StorylineEventResource` in the Inspector. Layout persists across editor restarts. Cross-route dependencies are visible in "All routes" mode.

**Validation / inspector bridge** — an `EditorInspectorPlugin` shows a validation-warning panel that auto-refreshes when inspector edits change validation status. It replaces raw-array editing for `phase_window` with an inline Phase Window panel adjacent to `season_phase` (filtering already-selected phases and disabling `Add Element` once all are chosen), and replaces `story_flags_all` / `story_flags_any` raw string arrays with a route-rooted event picker that mirrors the browser.

## Rules

- The three surfaces share one refresh path: structural route/event changes from any surface refresh the route filter, browser tree, and visible graph nodes without a manual refresh.
- All edits write back to the saved typed route resource for the target route/event; the editor never holds an independent copy of storyline state.
- New events scaffolded from the route-events panel get unique default ids of the form `<route_name>_new_event_<n>`.
- Destructive actions (deleting a route or event) prompt for confirmation before touching files or resources.

## Edge Cases

- Deleting a route or event that is currently open in the Inspector clears the now-stale selection.
- If a panel script fails to instantiate, the plugin logs a warning and the remaining panels still load.
- Graph layout is read from a checked-in layout config; missing or partial layout falls back to automatic dependency layout.

## Architecture / Ownership

- `plugin.gd` is the `EditorPlugin`; it registers the graph editor (bottom panel), the route browser (left dock via the editor-managed `EditorDock` API), and the inspector plugin, and wires their signals to a single deferred catalog-refresh handler.
- The panels read route/event data through `StorylineCatalog` (`build_route_definitions`, `build_event_definitions`, `load_route_resources`, `route_display_order`) at editor time; the catalog and the `.tres` route resources under `game/storylines/routes/` remain canonical.

## Relevant Files

- Scripts: `plugin.gd`, `storyline_graph_editor.gd`, `storyline_route_browser.gd`, `storyline_route_event_panel.gd`, `storyline_prerequisite_picker_panel.gd`, `storyline_phase_window_panel.gd`, `storyline_validation_panel.gd`, `storyline_validator_inspector_plugin.gd`, `storyline_inspector_status_bridge.gd`
- Canonical data: `game/storylines/routes/` (`StorylineRouteResource` / `StorylineEventResource`), layout at `game/storylines/storyline_graph_layout.cfg`
- Contract: `contract.md`

## Validation

- Enable the plugin, open the browser and graph, and confirm routes/events load.
- Create and delete a test event and route; confirm confirmation prompts, file/resource changes, and that all three surfaces refresh.
- Edit prerequisites in the graph and confirm the change is written to the backing resource and reflected in the inspector picker.
