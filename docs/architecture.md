# Kulangsu Architecture

Read [`design_brief.md`](design_brief.md) first. This file is the high-level map of the running game and the ownership boundaries future changes should respect.

## Repo Shape

This repository has two layers:

- the main Godot game project
- supporting submodule repositories listed in [`submodules.md`](submodules.md)

Most gameplay and scene work happens in the main repo. Shared or vendor-style code in submodules should be treated as separate ownership boundaries.

## Startup Flow

1. [`../project.godot`](../project.godot) boots the app through [`../ui/app_flow_root.tscn`](../ui/app_flow_root.tscn).
2. [`../ui/app_flow_root.gd`](../ui/app_flow_root.gd) builds the UI shell, manages screen state, and instantiates [`../main.tscn`](../main.tscn) for gameplay.
3. [`../main.gd`](../main.gd) connects the player, terrain, landmarks, residents, and interaction state to the UI-facing autoload [`../game/app_state.gd`](../game/app_state.gd).
4. Screen scripts under [`../ui/screens/`](../ui/screens) read shared state and send actions back to the shell.

## Main Systems

### App Shell And Screens

Primary files:

- [`../ui/app_flow_root.tscn`](../ui/app_flow_root.tscn)
- [`../ui/app_flow_root.gd`](../ui/app_flow_root.gd)
- [`../ui/screens/`](../ui/screens)
- [`../ui/ui_style.gd`](../ui/ui_style.gd)

Responsibilities:

- boot, title, new game, free walk, pause, journal, settings, credits, ending, and confirm flows
- scaling the `1920 x 1080` authored UI to the live viewport
- keeping gameplay in one scene while overlays come and go on top of it

Boundary:

- UI scripts should present state and route actions. They should not become the home for gameplay rules.

### World Scene And Overworld Integration

Primary files:

- [`../main.tscn`](../main.tscn)
- [`../main.gd`](../main.gd)
- [`../terrain.tscn`](../terrain.tscn)
- [`../terrain.gd`](../terrain.gd)

Responsibilities:

- main island scene setup
- player spawn and camera context
- shared y-sorted actor layer for the player and spawned residents
- landmark lookup and location syncing
- data-driven resident spawning, inspect/talk prompts, and overworld resident presentation
- feeding current world context into `AppState`

Boundary:

- Keep scene-specific world integration here instead of scattering it across UI files or unrelated helpers.

### Shared State And Catalogs

Primary files:

- [`../game/app_state.gd`](../game/app_state.gd)
- [`../game/melody_catalog.gd`](../game/melody_catalog.gd)
- [`../game/resident_catalog.gd`](../game/resident_catalog.gd)
- [`../game/player_appearance_catalog.gd`](../game/player_appearance_catalog.gd)
- [`../game/player_costume_catalog.gd`](../game/player_costume_catalog.gd)

Responsibilities:

- shared mode, chapter, location, objective, hint, save status, and summary data
- shared melody definitions and melody-progress state used by the journal and future performance systems
- resident and player-facing catalog data
- resident runtime profiles plus resident appearance, spawn, and journal-facing lookup helpers
- state that multiple screens or systems need to read consistently

Boundary:

- `AppState` is for shared UI/progression state. Do not use it as a dumping ground for scene-local implementation details.

### Scene-Graph Utility Singleton

Primary file:

- [`../game/game_global.gd`](../game/game_global.gd)

Responsibilities:

- holds the live `HumanBody2D` player node reference for the current scene
- exposes a `player_changed` signal so scene-graph systems can react when the player node is replaced
- provides a static `get_instance()` accessor so non-UI systems (terrain, AI, behavior trees) can reach the player without going through `AppState`

Boundary:

- `GameGlobal` is a scene-graph plumbing singleton, not a progression or UI-state store
- keep it lean: player-node reference and signal only
- UI and progression code should use `AppState`, not `GameGlobal`, for anything player-facing or save-relevant
- `main.gd` sets the player reference in `_ready()` after the scene is live

### Characters, Interaction, And Behavior

Primary folders:

- [`../characters/control/`](../characters/control)
- [`../characters/control/bt/`](../characters/control/bt)
- [`../characters/universal_lpc/`](../characters/universal_lpc)
- [`../gui/`](../gui)

Responsibilities:

- player and NPC control
- interaction discovery and inspect requests
- behavior-tree support code
- resident presentation hookup, character visuals, and in-world speech balloon UI
- metadata-driven LPC sprite composition and development-time metadata generation tooling

Notes:

- The runtime game consumes the prebuilt Universal LPC metadata under [`../resources/sprites/universal_lpc/`](../resources/sprites/universal_lpc).
- [`../characters/human_body_2d.gd`](../characters/human_body_2d.gd) owns the root material/shader setup for composed avatars, while the child Universal LPC node composes the visible layers.

### World Spaces And Landmark Content

Primary folders:

- [`../architecture/`](../architecture)
- [`../architecture/components/`](../architecture/components)
- [`../common/`](../common)

Responsibilities:

- landmark scenes such as Bagua Tower, tunnels, church, and ferry content
- reusable architectural pieces shared by those spaces
- shared multi-level helpers such as `LevelNode2D` and `LevelRegistry`

### Reusable Game Modules

Primary folders:

- [`../game/grid_board_game/`](../game/grid_board_game)
- [`../game/marble_game/`](../game/marble_game)
- [`../game/piano_game/`](../game/piano_game)

Responsibilities:

- self-contained gameplay modules and prototypes
- feature-specific scenes, scripts, rules, AI helpers, and local test scenes

Boundary:

- Extend the owning feature folder before creating duplicate logic elsewhere.

### Submodule Layer

Primary folders:

- [`../godot_common/`](../godot_common)
- [`../godot_tilemap/`](../godot_tilemap)
- [`../codex_agents/`](../codex_agents)
- [`../3rdparty/Universal-LPC-Spritesheet-Character-Generator/`](../3rdparty/Universal-LPC-Spritesheet-Character-Generator)

Responsibilities:

- shared support code used by the main project
- reusable tilemap tooling and helpers
- agent runbooks and shared documentation assets
- third-party LPC asset generator content

Boundary:

- These folders are governed as submodules. Update them intentionally, and document interface or pointer changes in the parent repo.

## System Relationships

- The app shell owns navigation and overlays.
- The world scene owns moment-to-moment overworld behavior.
- `AppState` is the bridge between gameplay context and UI presentation.
- Feature modules stay local until they are intentionally wired into the main flow.
- Submodules provide supporting code or assets, but the parent repo owns how they are integrated.

## Where Changes Usually Belong

- Screen flow, menus, overlays, HUD: [`../ui/`](../ui)
- Shared player-facing state: [`../game/app_state.gd`](../game/app_state.gd)
- Overworld logic and resident syncing: [`../main.gd`](../main.gd)
- Player or NPC behavior: [`../characters/control/`](../characters/control)
- Landmark scenes and reusable architecture pieces: [`../architecture/`](../architecture)
- Reusable mini-games or subsystems: [`../game/`](../game)

## Update This Doc When

- the startup scene or app shell ownership changes
- a new top-level subsystem is introduced
- ownership moves between UI, world integration, shared state, or feature modules
- a feature module becomes part of the main game flow
- a submodule becomes a required integration point for new runtime behavior
