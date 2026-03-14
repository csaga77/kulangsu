# Kulangsu UI Design Context

## Purpose
This document captures the current UI design direction and implementation context so future UI work can continue from a stable baseline.

This is not a full feature spec. It is the reusable context for:

- visual direction
- screen hierarchy
- layout constraints
- shared state model
- rules that should stay true as the UI evolves

## Final UI Direction

The UI should feel calm, readable, and atmospheric.

The target tone is:

- ferry / harbor / piano island
- soft and understated rather than arcade-like
- minimal during play
- slightly storybook in menus
- diegetic where possible, but practical when clarity matters

The UI should support exploration first, with menus and overlays helping orientation without overwhelming the screen.

## Core Principles

- Keep gameplay screens mostly clear.
- Use overlays instead of hard scene changes while the player is in-game.
- Make the title screen feel intentional and atmospheric, not like a placeholder tool menu.
- Preserve strong readability over visual complexity.
- Avoid fixed-position assumptions that break under the project’s stretched viewport.
- Treat the whole UI as one system, not independent one-off screens.

## Current UI Architecture

### App Shell

The UI is currently orchestrated by:

- [ui/app_flow_root.gd](/Users/bchen/Workspace/Godot/kulangsu/ui/app_flow_root.gd)
- [ui/app_flow_root.tscn](/Users/bchen/Workspace/Godot/kulangsu/ui/app_flow_root.tscn)

This app shell is the startup scene through:

- [project.godot](/Users/bchen/Workspace/Godot/kulangsu/project.godot)

The shell is responsible for:

- boot flow
- title flow
- game scene embedding
- pause / journal / settings / credits / ending overlays
- confirm modals
- fit-to-window scaling

### Shared UI State

The UI reads from a shared singleton:

- [game/app_state.gd](/Users/bchen/Workspace/Godot/kulangsu/game/app_state.gd)

`AppState` currently stores:

- mode
- chapter
- location
- objective
- hint text
- save status
- fragment progress
- landmark list
- resident list
- ending summary

This is the correct place for future UI-facing progression state.

### Shared Styling

Reusable UI styling helpers live in:

- [ui/ui_style.gd](/Users/bchen/Workspace/Godot/kulangsu/ui/ui_style.gd)

It currently provides:

- panel style
- title gradient

Future shared UI colors, typography rules, spacing tokens, and component styles should grow from here instead of being hardcoded in many files.

## Current Screen Structure

### Implemented Dedicated Screens

- [ui/screens/boot_screen.tscn](/Users/bchen/Workspace/Godot/kulangsu/ui/screens/boot_screen.tscn)
- [ui/screens/title_screen.tscn](/Users/bchen/Workspace/Godot/kulangsu/ui/screens/title_screen.tscn)
- [ui/screens/game_hud.tscn](/Users/bchen/Workspace/Godot/kulangsu/ui/screens/game_hud.tscn)

### Overlays Still Built in the App Shell

These currently exist as programmatically built panels in `app_flow_root.gd`:

- Journal
- Pause
- Settings
- Credits
- Ending
- Confirm modal

These can be split into dedicated scenes later, but the current behavior and content should be preserved unless intentionally redesigned.

## Final Flow the UI Should Support

The intended app flow is:

1. Boot
2. Title screen
3. `Continue` / `New Game` / `Free Walk`
4. In-game HUD
5. In-game overlays:
   - Journal
   - Pause
   - Settings
   - Credits
   - Ending
6. Return to title or quit

Important behavior:

- `Esc` backs out one level before doing anything broader
- `J` toggles the journal during gameplay
- `Continue` should feel like resuming context, not starting over
- `Free Walk` should feel like a lower-pressure mode, not just another save slot

## Title Screen Design Context

The title screen should communicate tone before gameplay starts.

Current implementation:

- full-screen background
- soft veil overlay
- centered hero copy
- centered menu card

Relevant files:

- [ui/screens/title_screen.tscn](/Users/bchen/Workspace/Godot/kulangsu/ui/screens/title_screen.tscn)
- [ui/screens/title_screen.gd](/Users/bchen/Workspace/Godot/kulangsu/ui/screens/title_screen.gd)

Design intent:

- title and copy should feel composed and centered
- buttons should be grouped into a single card
- the screen should read well at the project’s scaled viewport, not only at desktop-native size
- atmosphere matters more than dense information

Do not revert to:

- large fixed-offset layouts
- wide two-column title compositions that assume lots of safe space
- controls positioned by guesswork rather than container layout

## HUD Design Context

The HUD should stay minimal and support orientation rather than dominate the frame.

Current content:

- objective card
- mode / chapter / location / fragment status card
- interaction hint card
- save status text

Relevant files:

- [ui/screens/game_hud.tscn](/Users/bchen/Workspace/Godot/kulangsu/ui/screens/game_hud.tscn)
- [ui/screens/game_hud.gd](/Users/bchen/Workspace/Godot/kulangsu/ui/screens/game_hud.gd)

Design intent:

- objective should remain easy to scan
- progress status should be compact
- hint text should be visible but not loud
- HUD should not compete with the world for attention

Future refinement should likely make the HUD truly responsive instead of only scaled as one canvas.

## Layout Constraint Learned During Implementation

This is the most important implementation lesson so far:

The project uses a stretched viewport, and UI that assumes a large desktop-sized fixed layout will fall off-screen.

Because of that, the app shell now uses a fixed design canvas that is scaled to fit the real viewport.

Current rule:

- the UI is authored against a design size of `1920 x 1080`
- the shell scales that canvas to fit inside the actual viewport
- all screens should assume they live inside that scaled design canvas

Relevant code:

- [ui/app_flow_root.gd](/Users/bchen/Workspace/Godot/kulangsu/ui/app_flow_root.gd)

Future UI work should respect this unless the entire UI system is intentionally rebuilt.

## Relationship to Gameplay UI

There is still an existing in-world speech UI:

- [gui/speech_balloon.tscn](/Users/bchen/Workspace/Godot/kulangsu/gui/speech_balloon.tscn)
- [gui/speech_balloon.gd](/Users/bchen/Workspace/Godot/kulangsu/gui/speech_balloon.gd)

That remains the right pattern for ambient moment-to-moment interaction.

The larger shell UI should complement it, not replace it.

Recommended split:

- speech balloons for short local reactions
- shell overlays for objectives, pause, settings, journal, and ending summary

## Content Model the UI Assumes

The UI currently assumes the game is structured around:

- districts / landmarks
- a main objective
- melody fragment progress
- known residents
- chapter / location framing

That aligns with:

- [docs/core_game_workflow.md](/Users/bchen/Workspace/Godot/kulangsu/docs/core_game_workflow.md)
- [docs/ui_workflow.md](/Users/bchen/Workspace/Godot/kulangsu/docs/ui_workflow.md)

Future UI work should continue supporting that model unless the game structure changes.

## What Should Stay Stable

- App shell as the UI entry point
- `AppState` as the shared UI-facing state source
- shared styles centralized in `ui_style.gd`
- centered, readable title presentation
- minimal HUD
- overlay-driven in-game menus
- fit-to-window scaling at the shell level

## Best Next UI Steps

If work continues on the UI, the most sensible order is:

1. Split journal, pause, settings, credits, ending, and confirm modal into dedicated scenes.
2. Replace hardcoded prototype strings with real quest and discovery data from gameplay.
3. Make the HUD responsive within the scaled canvas instead of relying mostly on fixed offsets.
4. Expand `ui_style.gd` into a more complete theme/token layer.
5. Add motion and transitions carefully, keeping the calm tone intact.

## One-Sentence Summary

Kulangsu’s final UI direction is a calm, story-forward shell wrapped around the exploration gameplay, centered on a shared app state, reusable styles, minimal HUD, overlay-based menus, and a fit-to-window canvas that protects the UI from the project’s stretched viewport.
