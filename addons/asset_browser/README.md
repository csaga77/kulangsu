# Asset Browser

Blender-style asset browser panel for dragging `.tscn` files into the 3D viewport. This
README is the plugin's entry point; the project-level
[`../../docs/module_map.md`](../../docs/module_map.md) keeps a one-line pointer here.

## Overview

The plugin adds a dockable panel that browses scene assets under a configurable root folder
(default `res://assets`), with:

- a subfolder filter list (with an "All" view) and a search box,
- grid and list view modes with an adjustable tile size,
- generated thumbnails cached under `user://asset_browser_cache/`,
- multi-select, and drag-and-drop of selected `.tscn` files into the viewport.

Key scripts: `asset_browser_panel.gd` (the dock UI), `thumbnail_generator.gd` (thumbnail
rendering/caching), and `viewport_drop_target.gd` (viewport drop handling).

## Ownership & Boundary

Project-local editor tooling. Editor plugins are authoring helpers: they must not become
runtime gameplay services or be wired into `main.tscn`.
