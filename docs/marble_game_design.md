# Marble Game Design

Read [`docs/design_brief.md`](docs/design_brief.md) first for the minimum-token project summary. Use this doc when working on the marble game prototype in [`game/marble_game`](game/marble_game).

## Purpose

This document captures the current design and implementation shape of the marble game prototype so future work can extend it without re-deriving the rules from code.

The prototype is currently a self-contained physics toy rather than part of the island progression loop. It is still useful as a reference for:

- tactile physics interaction
- reusable minigame architecture
- controller-driven ball logic
- turn-based versus free-play rule experiments

## Current Playable Setup

Primary scene:

- [`game/marble_game/marble_game.tscn`](game/marble_game/marble_game.tscn)

Primary scripts:

- [`game/marble_game/marble_game.gd`](game/marble_game/marble_game.gd)
- [`game/marble_game/marble_game_mode.gd`](game/marble_game/marble_game_mode.gd)
- [`game/marble_game/marble_game_free_mode.gd`](game/marble_game/marble_game_free_mode.gd)
- [`game/marble_game/marble_game_turn_mode.gd`](game/marble_game/marble_game_turn_mode.gd)
- [`game/marble_game/marble_ball.gd`](game/marble_game/marble_ball.gd)
- [`game/marble_game/marble_ball_controller.gd`](game/marble_game/marble_ball_controller.gd)
- [`game/marble_game/marble_ball_player_controller.gd`](game/marble_game/marble_ball_player_controller.gd)
- [`game/marble_game/marble_ball_ai_controller.gd`](game/marble_game/marble_ball_ai_controller.gd)
- [`game/marble_game/marble_hole.gd`](game/marble_game/marble_hole.gd)
- [`game/marble_game/damping_area.gd`](game/marble_game/damping_area.gd)

The shipped scene currently defaults to `FreeMode`, contains one player-controlled marble and one AI marble, and restarts itself after a full clear.

## Player Experience

The prototype currently reads as a compact tabletop challenge:

- marbles spawn around a central hole
- each marble is kicked by drag input or simple AI
- the hole acts as both target and elimination state
- damping zones and wall bounces shape the motion

The feel is closer to a short physics toy than a scored sports game. The strongest qualities today are immediacy and visual readability rather than progression depth.

## Design Pillars

- Physical clarity: the player should understand why a marble moved, bounced, slowed, or fell into the hole.
- Short recovery loop: restarts should be fast enough to encourage replay and rule iteration.
- Rule modularity: free-play and turn-based behavior should be swappable without rebuilding the scene.
- Low UI overhead: the scene should communicate state mostly through marble motion and controller availability.

## Core Systems

### Game Root

[`game/marble_game/marble_game.gd`](game/marble_game/marble_game.gd) owns shared state for:

- discovered marbles
- current mode instance
- game status
- active turn ball
- winner and loser tracking
- restart and game-over signaling
- configured board spawn bounds

It is the orchestration layer, not the rule layer. Modes are meant to decide when kicks are allowed, how winners are assigned, and when the round ends.

### Mode Layer

[`game/marble_game/marble_game_mode.gd`](game/marble_game/marble_game_mode.gd) is the rule extension point. It provides:

- shared rest-settle timing
- shared velocity thresholds
- initial throw behavior
- ball event hooks

Ball events now enter modes through the root game only, which keeps kick and hole logic from being double-processed.

Two modes exist today:

- [`game/marble_game/marble_game_free_mode.gd`](game/marble_game/marble_game_free_mode.gd)
- [`game/marble_game/marble_game_turn_mode.gd`](game/marble_game/marble_game_turn_mode.gd)

### Ball Layer

[`game/marble_game/marble_ball.gd`](game/marble_game/marble_ball.gd) combines:

- `RigidBody2D` motion
- collision and hole state signaling
- rolling shader presentation
- hit sound playback
- damping aggregation from overlapping areas
- delegation to a controller resource

This makes the marble scene reusable across player, AI, and future scripted controllers.

### Controller Layer

[`game/marble_game/marble_ball_controller.gd`](game/marble_game/marble_ball_controller.gd) is an abstract controller contract.

Current implementations:

- [`game/marble_game/marble_ball_player_controller.gd`](game/marble_game/marble_ball_player_controller.gd): click-drag kick input
- [`game/marble_game/marble_ball_ai_controller.gd`](game/marble_game/marble_ball_ai_controller.gd): delayed kick toward the hole with jitter and strength variation

Controllers are resources, so a scene can mix human and AI marbles without changing the marble body script.
The shared spawn helper now samples inside the root game’s exported board bounds before throwing a marble away from the hole.

### Hole and Damping

[`game/marble_game/marble_hole.gd`](game/marble_game/marble_hole.gd) owns:

- overlap tracking
- `m_in_hole` state transitions
- inward pull force

[`game/marble_game/damping_area.gd`](game/marble_game/damping_area.gd) provides localized friction-like behavior by contributing additional linear and angular damping while a marble is inside the area.

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

The current scene is a small enclosed board:

- world bounds form a rectangle from `(0, 0)` to `(544, 352)`
- the hole sits near the upper-left quadrant at `(144, 118)`
- one damping polygon sits left of center
- the camera follows the player marble

Because the hole is off-center, spawn and shot tuning must account for the small playfield and asymmetric safe space.

## What Is Working Well

- The split between root game state, mode rules, and per-ball controllers is a strong reusable pattern.
- The marble presentation is already appealing thanks to the rolling shader and hit audio.
- `FreeMode` is useful for rapid feel iteration.
- `TurnMode` already has the beginnings of a readable winner / loser structure.

## Recent Stability Notes

- Mode callbacks are routed through [`game/marble_game/marble_game.gd`](game/marble_game/marble_game.gd) only.
- Restart spawn sampling uses the scene’s configured board bounds and avoids obvious ball overlap when possible.
- The prototype currently loads without the earlier stale scene connection issue.

## Recommended Next Steps

1. Add a small deterministic probe or test scene for turn-mode rules so kick counting, extra chances, and loser resolution can be verified quickly after changes.
2. If the board becomes more crowded, upgrade spawn selection from simple clearance checks to shape queries against live physics.

## Fit With The Main Game

If the marble game is later pulled into the island experience, it should likely be framed as:

- a small resident challenge
- a harbor or plaza side activity
- a low-stakes tactile diversion rather than a competitive high-pressure mode

That direction fits the project tone better than turning it into a loud arcade interruption.
