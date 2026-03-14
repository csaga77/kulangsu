# Kulangsu Design Brief

Read this first. It is the minimum-token design context for new Codex threads.

## Game Identity

- Calm exploration game set on Kulangsu.
- Tone: ferry harbor, piano island, soft storybook atmosphere.
- Prioritize readability, restraint, and orientation over busy UI or arcade energy.

## Player Loop

1. Arrive on the island with a simple question.
2. Explore landmarks and meet residents.
3. Complete short landmark-specific objective chains.
4. Recover four melody fragments.
5. Unlock a final island-wide performance and ending choice.

## Core Content Model

- Main quest plus lightweight district objectives.
- Progress is tracked through melody fragments, landmarks, residents, chapter, and location.
- `Free Walk` is a low-pressure exploration mode separate from story progression.

## UI Direction

- Keep gameplay screens mostly clear.
- Use overlays instead of hard scene swaps while in-game.
- Title screen should feel composed and atmospheric, not like a tool menu.
- HUD should stay minimal: objective, compact status, contextual hint, save feedback.
- Speech balloons remain the right pattern for local moment-to-moment interaction.

## Architecture Anchors

- UI entry point: [`/Users/bchen/Workspace/Godot/kulangsu/ui/app_flow_root.tscn`](/Users/bchen/Workspace/Godot/kulangsu/ui/app_flow_root.tscn)
- App shell logic: [`/Users/bchen/Workspace/Godot/kulangsu/ui/app_flow_root.gd`](/Users/bchen/Workspace/Godot/kulangsu/ui/app_flow_root.gd)
- Shared UI state: [`/Users/bchen/Workspace/Godot/kulangsu/game/app_state.gd`](/Users/bchen/Workspace/Godot/kulangsu/game/app_state.gd)
- Shared UI styling: [`/Users/bchen/Workspace/Godot/kulangsu/ui/ui_style.gd`](/Users/bchen/Workspace/Godot/kulangsu/ui/ui_style.gd)
- Current dedicated screens: boot, title, game HUD

## Layout Rule That Must Stay True

- The project uses a stretched viewport.
- UI is authored against a `1920 x 1080` design canvas and scaled to fit by the app shell.
- Do not assume large fixed desktop layouts or place controls with fragile offsets.

## Current App Flow

1. Boot
2. Title
3. `Continue` / `New Game` / `Free Walk`
4. In-game HUD
5. In-game overlays: journal, pause, settings, credits, ending, confirm modal
6. Return to title or quit

Input expectations:

- `Esc` backs out one level first.
- `J` toggles journal during gameplay.

## Landmark Structure

- Ferry plaza teaches movement, inspect, and first objective.
- Trinity Church: listening, NPC clues, light route finding.
- Bi Shan Tunnel: navigation and echo cues.
- Long Shan Tunnel: escort and reassurance.
- Bagua Tower: vertical traversal and synthesis.

## Non-Goals

- Do not add mandatory combat to the main loop.
- Do not let the HUD dominate the frame.
- Do not replace atmospheric interaction with heavy menu friction.

## If You Need More Detail

- UI architecture and constraints: [`/Users/bchen/Workspace/Godot/kulangsu/docs/ui_design_context.md`](/Users/bchen/Workspace/Godot/kulangsu/docs/ui_design_context.md)
- Story and progression flow: [`/Users/bchen/Workspace/Godot/kulangsu/docs/core_game_workflow.md`](/Users/bchen/Workspace/Godot/kulangsu/docs/core_game_workflow.md)
- Full title/settings/pause/endgame flow: [`/Users/bchen/Workspace/Godot/kulangsu/docs/ui_workflow.md`](/Users/bchen/Workspace/Godot/kulangsu/docs/ui_workflow.md)
