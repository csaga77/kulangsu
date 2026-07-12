# Marble Game Design

Read [`design_brief.md`](design_brief.md) first for the minimum-token project summary. Use this doc when working on the marble game prototype in [`../game/marble_game`](../game/marble_game).

## Purpose

This document captures the current design and implementation shape of the marble game prototype so future work can extend it without re-deriving the rules from code.

The prototype is currently a self-contained low-poly 3D physics toy rather than part of the island progression loop. It is still useful as a reference for:

- tactile physics interaction
- reusable minigame architecture
- controller-driven ball logic
- turn-based versus free-play rule experiments

## Current Playable Setup

Primary scene:

- [`../game/marble_game/marble_game.tscn`](../game/marble_game/marble_game.tscn)

Primary scripts:

- [`../game/marble_game/marble_game.gd`](../game/marble_game/marble_game.gd)
- [`../game/marble_game/marble_game_mode.gd`](../game/marble_game/marble_game_mode.gd)
- [`../game/marble_game/marble_game_free_mode.gd`](../game/marble_game/marble_game_free_mode.gd)
- [`../game/marble_game/marble_game_turn_mode.gd`](../game/marble_game/marble_game_turn_mode.gd)
- [`../game/marble_game/marble_ball.gd`](../game/marble_game/marble_ball.gd)
- [`../game/marble_game/marble_ball_controller.gd`](../game/marble_game/marble_ball_controller.gd)
- [`../game/marble_game/marble_ball_player_controller.gd`](../game/marble_game/marble_ball_player_controller.gd)
- [`../game/marble_game/marble_ball_ai_controller.gd`](../game/marble_game/marble_ball_ai_controller.gd)
- [`../game/marble_game/marble_hole.gd`](../game/marble_game/marble_hole.gd)
- [`../game/marble_game/damping_area.gd`](../game/marble_game/damping_area.gd)

The shipped scene currently defaults to `FreeMode`, contains one player-controlled marble and one AI marble, and restarts itself after a full clear. Rendering and physics are fully 3D and use no external tilemap resources.

## Player Experience

The prototype reads as a compact low-poly tabletop diorama:

- faceted 3D marbles spawn around a recessed hole
- each marble is kicked by drag input or simple AI
- the hole acts as both target and physical drop/catch state
- a raised sand patch adds damping while solid rails shape wall bounces

The feel is closer to a short physics toy than a scored sports game. The strongest qualities today are immediacy and visual readability rather than progression depth.

## Design Pillars

- Physical clarity: the player should understand why a marble moved, bounced, slowed, or fell into the hole.
- Short recovery loop: restarts should be fast enough to encourage replay and rule iteration.
- Rule modularity: free-play and turn-based behavior should be swappable without rebuilding the scene.
- Low UI overhead: the scene should communicate state mostly through marble motion and controller availability.

## Core Systems

### Game Root

[`../game/marble_game/marble_game.gd`](../game/marble_game/marble_game.gd) owns shared state for:

- discovered marbles
- current mode instance
- game status
- active turn ball
- winner and loser tracking
- restart and game-over signaling
- configured board spawn bounds

It is the orchestration layer, not the rule layer. Modes are meant to decide when kicks are allowed, how winners are assigned, and when the round ends.

### Mode Layer

[`../game/marble_game/marble_game_mode.gd`](../game/marble_game/marble_game_mode.gd) is the rule extension point. It provides:

- shared rest-settle timing
- shared velocity thresholds
- initial throw behavior
- ball event hooks

Ball events now enter modes through the root game only, which keeps kick and hole logic from being double-processed.

Two modes exist today:

- [`../game/marble_game/marble_game_free_mode.gd`](../game/marble_game/marble_game_free_mode.gd)
- [`../game/marble_game/marble_game_turn_mode.gd`](../game/marble_game/marble_game_turn_mode.gd)

### Ball Layer

[`../game/marble_game/marble_ball.gd`](../game/marble_game/marble_ball.gd) combines:

- `RigidBody3D` rolling and collision
- collision and hole state signaling
- low-segment sphere-mesh presentation and dynamic 3D shadows
- positional hit sound playback
- damping aggregation from overlapping `Area3D` zones
- delegation to a controller resource

This makes the marble scene reusable across player, AI, and future scripted controllers.

### Controller Layer

[`../game/marble_game/marble_ball_controller.gd`](../game/marble_game/marble_ball_controller.gd) is an abstract controller contract.

Current implementations:

- [`../game/marble_game/marble_ball_player_controller.gd`](../game/marble_game/marble_ball_player_controller.gd): click-drag kick input
- [`../game/marble_game/marble_ball_ai_controller.gd`](../game/marble_game/marble_ball_ai_controller.gd): delayed kick toward the hole with jitter and strength variation

Controllers are resources, so a scene can mix human and AI marbles without changing the marble body script. Player input projects the mouse through the active `Camera3D` onto the marble-height board plane before calculating the kick impulse.
The shared spawn helper samples X/Z positions inside the root game’s exported `Rect2` board bounds before throwing a marble away from the hole.

### Hole and Damping

[`../game/marble_game/marble_hole.gd`](../game/marble_game/marble_hole.gd) owns:

- overlap tracking
- `m_in_hole` state transitions
- inward and downward pull force into a physical catch pocket

[`../game/marble_game/damping_area.gd`](../game/marble_game/damping_area.gd) provides localized friction-like behavior through a visible sand-colored `Area3D`, contributing additional linear and angular damping while a marble overlaps it.

## Mode Rules

### Free Mode

Current behavior:

- all marbles are thrown outward from the hole on restart
- all non-hole marbles remain kickable
- the mode waits for a shared settle window before evaluating completion
- the round ends only when every marble is inside the hole at a rest moment
- after game over, the scene auto-restarts after a short delay

This mode currently works best as a sandbox for shot feel, damping, hole pull, and controller tuning.

### Turn Mode

Current behavior:

- only one marble is active for a kick window
- the mode alternates through eligible marbles after shared rest
- a first-hit collision can award an extra kick
- when a marble enters the hole, it becomes part of a lock state
- during lock state, remaining challengers receive limited attempts
- locked marbles resolve as winners
- the last non-winner still outside the hole becomes the loser

This mode is the more game-like ruleset and is the better foundation if the prototype becomes a proper minigame.

## Scene Layout Notes

The current scene is a small enclosed 3D board:

- X/Z world bounds form a rectangle from `(0, 0)` to `(13.6, 8.8)`
- the hole sits near the upper-left quadrant at `(3.6, 2.95)`
- one raised damping patch sits near the board center
- four `StaticBody3D` rails enclose the playfield
- a fixed perspective `Camera3D`, two-direction light rig, and ambient environment present the board as a tabletop diorama
- the floor is split around the target opening so marbles physically drop into its lower catch plate

Because the hole is off-center, spawn and shot tuning must account for the small playfield and asymmetric safe space.

## What Is Working Well

- The split between root game state, mode rules, and per-ball controllers is a strong reusable pattern.
- Low-segment meshes, warm rails, a recessed target, and real lighting make the board read clearly as low-poly 3D.
- Camera-ray input preserves direct drag interaction despite the perspective view.
- `FreeMode` is useful for rapid feel iteration.
- `TurnMode` already has the beginnings of a readable winner / loser structure.

## Recent Stability Notes

- Mode callbacks are routed through [`../game/marble_game/marble_game.gd`](../game/marble_game/marble_game.gd) only.
- Restart spawn sampling maps the scene’s configured `Rect2` bounds onto the X/Z plane and avoids obvious ball overlap when possible.
- The prototype currently loads without the earlier stale scene connection issue.
- [`../game/marble_game/tests/test_marble_game_3d.gd`](../game/marble_game/tests/test_marble_game_3d.gd) verifies the 3D node types, marble discovery, rail containment, floor support, and a post-impulse physics sample.

## Recommended Next Steps

1. Add a deterministic probe for turn-mode rules so kick counting, extra chances, and loser resolution can be verified quickly after changes.
2. Add an in-world drag trajectory preview if the perspective camera makes shot strength difficult to judge during playtesting.
3. If the board becomes more crowded, upgrade spawn selection from simple clearance checks to 3D shape queries against live physics.

## Fit With The Main Game

If the marble game is later pulled into the island experience, it should likely be framed as:

- a small resident challenge
- a harbor or plaza side activity
- a low-stakes tactile diversion rather than a competitive high-pressure mode

That direction fits the project tone better than turning it into a loud arcade interruption.
