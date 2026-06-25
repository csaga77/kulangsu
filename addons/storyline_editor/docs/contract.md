# Storyline Graph Editor — Contract

Keep this contract and [`feature.md`](feature.md) in sync.

## Owned by

- [`../plugin.gd`](../plugin.gd)
- [`../storyline_graph_editor.gd`](../storyline_graph_editor.gd)
- [`../storyline_route_browser.gd`](../storyline_route_browser.gd)
- [`../storyline_route_event_panel.gd`](../storyline_route_event_panel.gd)
- [`../storyline_prerequisite_picker_panel.gd`](../storyline_prerequisite_picker_panel.gd)
- [`../storyline_phase_window_panel.gd`](../storyline_phase_window_panel.gd)
- [`../storyline_validation_panel.gd`](../storyline_validation_panel.gd)
- [`../storyline_validator_inspector_plugin.gd`](../storyline_validator_inspector_plugin.gd)
- [`../storyline_inspector_status_bridge.gd`](../storyline_inspector_status_bridge.gd)

## Current contract

- The plugin is editor-only and must not be referenced by runtime gameplay code.
- The plugin is a view/edit layer only: `StorylineCatalog` and the `.tres` route resources under `game/storylines/routes/` are the single source of truth. All panels read through `StorylineCatalog` (`build_route_definitions`, `build_event_definitions`, `load_route_resources`, `route_display_order`) and all edits write back to the canonical typed route resource; the plugin must never introduce a parallel store.
- The route browser registers through the editor-managed `EditorDock` API with a stable `layout_key` (`storyline_browser`); the graph editor is a bottom-panel control.
- The browser exposes signals `event_show_in_graph_requested`, `route_inspector_requested`, `event_inspector_requested`, `event_delete_requested`, and `catalog_changed`; the graph editor exposes `catalog_changed`. `plugin.gd` owns the wiring between these and the graph editor's `select_event` / `edit_event_in_inspector` / `edit_route_in_inspector` / `delete_event` methods.
- Catalog-change refresh is coalesced: any `catalog_changed` queues a single deferred `_refresh_storyline_views`, which calls `refresh_from_disk` on the browser and graph and `refresh_storyline_controls` on the inspector plugin. New signal sources must route through this same coalesced refresh.
- Graph layout persists to the checked-in `game/storylines/storyline_graph_layout.cfg`.
- Destructive route/event operations must confirm before deleting authored resource files or removing an event from its route resource, and must clear a now-stale Inspector selection.

## Governance

- If panel registration, the cross-panel signal set, the coalesced refresh path, the canonical-source assumption, or the layout-persistence location changes, update this contract and [`feature.md`](feature.md).
- Do not move storyline authority into the plugin; route/event meaning stays in the typed resources and `StorylineCatalog`.
