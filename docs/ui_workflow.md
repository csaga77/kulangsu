# Kulangsu UI Workflow

Read [`docs/design_brief.md`](docs/design_brief.md) first for the minimum-token summary. Use this doc only when full menu and screen flow detail is needed.

## UI Goal
Design a full UI journey from app launch to app exit that supports a calm exploration game, stays lightweight during play, and gives the player clear orientation without breaking immersion.

The current project already includes an in-world dialogue UI in [`gui/speech_balloon.tscn`](gui/speech_balloon.tscn), so the rest of the interface should follow the same principle:

- readable
- minimal
- warm
- diegetic where possible

## Core UI Principles

- Keep the screen mostly clear during exploration.
- Put critical actions within one or two inputs from anywhere.
- Prefer overlays over hard scene swaps when the player is in-game.
- Use the ferry / island / music theme to unify menus and progression screens.
- Always give the player an obvious next step or a safe way back.

## End-to-End App Flow

1. App launch
2. Splash / boot
3. Title screen
4. Main menu
5. Settings or credits if selected
6. Save slot / new game flow
7. Intro transition
8. In-game HUD
9. Context overlays during play
10. Pause menu
11. Endgame flow
12. Ending screen
13. Postgame choice
14. Return to title or quit app

## 1. App Launch

### Boot State

When the app opens:

- Show a short black-to-painted-island fade
- Display studio / project mark if needed
- Load save metadata in the background
- Initialize audio, input, and user settings

Rules:

- Skip quickly on any confirm input
- Total time should be short, around 1 to 3 seconds
- If save data fails, continue with a warning modal instead of blocking launch

## 2. Splash / Startup Transition

Visual idea:

- Ferry bell sound
- Gentle sea / wind ambience
- Island silhouette or map fragment

Purpose:

- Set tone immediately
- Hide loading
- Transition naturally into the title screen

## 3. Title Screen

### Layout

Background:

- Slow animated view of Kulangsu harbor or ferry approach

Foreground:

- Game title
- Subtitle or short poetic line
- Main menu options

### Primary Actions

- `Continue`
- `New Game`
- `Free Walk`
- `Settings`
- `Credits`
- `Quit`

### Behavior

- If no save exists, `Continue` is disabled or hidden
- Focus defaults to `Continue` when save data exists, otherwise `New Game`
- `Esc` on title opens a small quit confirm dialog

## 4. Settings Flow

Settings should be reachable from both title and pause, with the same panel structure.

### Settings Categories

- Audio
- Display
- Controls
- Accessibility
- Language later if needed

### Audio

- Master volume
- Music volume
- Ambient volume
- UI volume

### Display

- Window mode
- Resolution or scale
- VSync
- Brightness if needed

### Controls

- Movement bindings
- Inspect binding
- Pause binding
- Walk / run behavior

Current bindings already implied by [`project.godot`](project.godot):

- Move: `WASD` / arrows
- Walk modifier
- Jump
- Inspect

### Accessibility

- Text speed
- Dialogue auto-advance toggle later if narrative expands
- Font scale
- Contrast mode
- Reduce motion

### Settings UX Rules

- Apply preview immediately where safe
- Keep `Apply`, `Revert`, and `Back`
- On `Back` with unsaved changes, show confirm dialog

## 5. Credits Flow

Credits should open as a dedicated screen from title and as a modal panel from pause after ending unlocks.

Content:

- Project title
- Team names
- Asset attributions
- Audio credits
- Open source acknowledgements

Existing attribution source:
- [`credit.md`](credit.md)

## 6. New Game / Continue Flow

### Continue

Selecting `Continue`:

- Loads latest autosave directly
- Shows a short loading card with current chapter and location
- Enters play

### New Game

Selecting `New Game` opens a lightweight setup flow:

1. Choose save slot
2. Confirm overwrite if needed
3. Optional player name later
4. Begin intro

### Free Walk

Purpose:

- Let the player roam the island without story pressure

Rules:

- Separate save state from story mode
- Disable main quest progression
- Keep inspect, movement, and landmark browsing active

## 7. Intro Transition Into Play

Sequence:

1. Fade from title to ferry arrival card
2. Show chapter title
3. Show one-line objective
4. Fade into live gameplay

Recommended card content:

- `Arrival at Kulangsu`
- `Find out why the island feels quiet today.`

This should feel like a title card, not a big cutscene UI.

## 8. In-Game HUD

The default HUD should stay minimal.

### Always-Visible Elements

- Small objective line
- Context hint area
- Optional subtle save icon when autosaving

### Conditional Elements

- Inspect prompt when near an interactive object
- Talk prompt when near an NPC
- Landmark discovered banner
- Melody fragment acquired banner

### HUD Layout

- Top-left: current objective
- Bottom-center or bottom-right: contextual interaction hint
- Top-right: collectible / melody status icon cluster

Do not keep a large minimap open by default.

## 9. In-Game UI States

### A. Interaction Hint

Appears when near something relevant.

Examples:

- `R Inspect`
- `Talk`
- `Enter`
- `Climb`

This should be small and fade in/out quickly.

### B. Speech / Dialogue

Current in-world pattern already exists in [`gui/speech_balloon.gd`](gui/speech_balloon.gd).

Use two dialogue tiers:

- Ambient speech balloon for short reactive lines
- Full dialogue panel for important quest conversations

### C. Full Dialogue Panel

Use when:

- Starting a quest
- Making a meaningful choice
- Delivering lore that should not disappear too fast

Layout:

- Character name
- Portrait later if desired
- Dialogue text
- `Next`
- `Back` only if log review exists

Optional:

- Dialogue history toggle

### D. Journal Overlay

Opened with a dedicated input.

Tabs:

- Objectives
- Map
- Residents
- Melody Fragments
- Wardrobe

Wardrobe tab:

- Show a live player preview
- Show current equipped look and unlocked count
- List each preset with summary and unlock route
- Let the player cycle unlocked looks without leaving the journal
- Let the player change hair style and hair color during gameplay

Behavior:

- Pauses movement
- Darkens world slightly
- Opens on last viewed tab

### E. Character Setup Overlay

Opened from `New Game` and `Free Walk` before gameplay begins.

Shows:

- body options
- gender presentation options
- skin tone options
- hair style options
- hair color options
- live player preview

Behavior:

- Uses the same shared appearance state as the in-game player
- `Back` returns to title without starting gameplay
- Confirm enters the requested mode with the chosen profile

### F. Map Overlay

Inside the journal or as a sister tab.

Shows:

- Current player location
- Discovered landmarks
- Objective highlight
- Unlocked shortcuts

Avoid showing everything from the start.

### G. Collection / Reward Toasts

For momentary positive feedback:

- `Landmark Discovered`
- `Shortcut Unlocked`
- `Melody Fragment Recovered`

Rules:

- Animate softly
- No loud arcade style popups
- Stack cleanly if multiple events fire close together

## 10. Pause Menu Flow

Opened from in-game with pause input.

### Pause Menu Options

- `Resume`
- `Journal`
- `Settings`
- `Return to Title`
- `Quit to Desktop`

### Pause Layout

- Blur or dim gameplay in background
- Show current chapter and location
- Show save timestamp

### Safety Rules

- `Return to Title` asks for confirmation
- `Quit to Desktop` asks for confirmation
- Autosave before leaving in-story play where safe

## 11. Save Flow

### Autosave

Trigger on:

- Landmark completion
- Entering a new district
- Important dialogue completion
- Endgame start

Feedback:

- Small non-blocking save icon in HUD

### Manual Save

If included:

- Available from pause menu
- Use named slots with chapter, location, and playtime

If manual save is omitted early on, autosave alone is acceptable for the prototype.

## 12. Failure / Recovery UI

This game should avoid harsh fail screens.

Preferred recovery UI:

- Short message banner
- Objective updated
- Retry from nearby

Examples:

- `You lost the echo trail. Listen again at the tunnel entrance.`
- `Your companion stopped. Go back and reassure them.`

Avoid large `Game Over` screens in the main story flow.

## 13. Endgame UI Flow

After all melody fragments are collected:

1. Objective updates to return to the ferry plaza
2. Journal highlights final event
3. Festival start prompt appears at the event location
4. Confirm starting the finale

Festival start modal:

- `Begin the Performance`
- `Not Yet`

## 14. Ending Sequence UI

After the festival:

- Fade to ending art / scene
- Show ending narration text
- Show completion summary

### Completion Summary Content

- Melody fragments recovered
- Residents helped
- Optional collectibles found
- Total playtime

### Ending Choice

- `Leave on the Morning Ferry`
- `Stay a Little Longer`

## 15. Postgame / End App Flow

After the ending choice:

### Option A: Stay

- Load postgame free exploration
- Mark story as completed
- Unlock credits and chapter review in title

### Option B: Leave

- Show final ferry departure card
- Fade into credits
- Return to title screen

## 16. App Exit Flow

The app can close from:

- Title screen `Quit`
- Pause menu `Quit to Desktop`

### Quit Confirm Modal

Text:
`Leave Kulangsu for now?`

Actions:

- `Cancel`
- `Quit`

If in active story mode:

- Attempt autosave first
- Then exit

## 17. Recommended Scene / Screen Structure

### Frontend Screens

- Boot screen
- Title screen
- Settings screen / panel
- Credits screen
- Save slot screen

### In-Game UI Layers

- HUD layer
- Dialogue layer
- Journal / map overlay
- Toast / notification layer
- Pause layer
- Modal confirm layer

## 18. Navigation Rules

- `Esc` closes the current overlay before opening pause
- `Esc` from pause resumes game
- `Esc` from title opens quit confirm
- Primary confirm key activates focused button
- Secondary cancel key always backs out one level

This keeps the UI predictable.

## 19. Suggested Screen-by-Screen Workflow

### Full Primary Path

1. Open app
2. Splash fades into title
3. Choose `Continue` or `New Game`
4. Optional settings / credits
5. Enter intro card
6. Play with minimal HUD
7. Open journal/map as needed
8. Pause for settings or return flow
9. Trigger finale
10. View ending summary
11. Return to title or continue postgame
12. Quit app from title or pause

## 20. MVP UI Build Order

### Phase 1

- Title screen
- Main menu
- Minimal HUD
- Pause menu
- Quit confirms

### Phase 2

- Journal
- Map
- Objective tracker
- Reward toasts

### Phase 3

- Save slot UI
- Full dialogue panel
- Endgame summary
- Credits screen

## One-Sentence UI Summary

The UI should guide the player from a soft ferry-themed title screen into a mostly unobtrusive exploration HUD, surface richer overlays only when needed, and close the experience with a gentle ending, credits, and clean return-or-quit choices.
