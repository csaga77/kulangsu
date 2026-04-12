# Kulangsu Design Brief

Read this first. It is the minimum-token design context for new Codex threads.

## Game Identity

- Calm exploration game set on Kulangsu.
- Tone: ferry harbor, piano island, soft storybook atmosphere.
- Prioritize readability, restraint, and orientation over busy UI or arcade energy.

## Player Loop

1. Arrive on the island with a simple question.
2. Open several story routes at once through landmarks and residents.
3. Follow one pinned lead on the HUD while tracking the wider route ledger in the journal.
4. Hear, collect, and reconstruct melody fragments from residents and places while also advancing family, study, and preservation beats.
5. Let seasonal anchors move the year toward a short final act and ending choice.

## Core Content Model

- Seasonal multi-route structure rather than one main quest route.
- The five-landmark melody route remains one major route, not the only route.
- Progress is tracked through `season_phase`, `route_progress`, `story_flags`, melody fragments, reconstructed melodies, landmarks, residents, location, player appearance, and wardrobe unlocks.
- `chapter` remains a compatibility/display label, not the authoritative progression key.
- `Free Walk` is a low-pressure exploration mode separate from story progression.

## UI Direction

- Keep gameplay screens mostly clear.
- Use overlays instead of hard scene swaps while in-game.
- Title screen should feel composed and atmospheric, not like a tool menu.
- HUD should stay minimal: objective, compact status, contextual hint, save feedback.
- Speech balloons remain the right pattern for local moment-to-moment interaction.

## Architecture Anchors

- UI entry point: [`../main.tscn`](../main.tscn)
- App shell logic: [`../main.gd`](../main.gd)
- Shared UI state: [`../game/app_state.gd`](../game/app_state.gd)
- Shared UI styling: [`../ui/ui_style.gd`](../ui/ui_style.gd)
- Current dedicated screens: boot, title, player setup, game HUD

## Layout Rule That Must Stay True

- The project uses a stretched viewport.
- UI is authored against a `1920 x 1080` design canvas and scaled to fit by the app shell.
- Do not assume large fixed desktop layouts or place controls with fragile offsets.

## Audio Asset Guardrail

- Treat `.ogg` in `resources/audio/` as a real format requirement, not just a file extension.
- Shipped `.ogg` assets must be encoded as Ogg Vorbis at `44100 Hz`.
- Do not commit Ogg FLAC or other codecs under a `.ogg` extension. Godot may report the file exists but still fail to load it through the normal resource path.
- For landmark cues, prompt SFX, and BGM, transcode source audio to Vorbis before wiring it into scenes, catalogs, or docs.
- If you need a conversion path, start with [`../addons/mp3_to_ogg/`](../addons/mp3_to_ogg) or an equivalent ffmpeg Vorbis transcode step.

## Current App Flow

1. Boot
2. Title
3. `Continue` / `New Game` / `Free Walk`
4. Character setup for new runs
5. In-game HUD
6. In-game overlays: journal, pause, settings, credits, ending, confirm modal
7. Return to title or quit

Input expectations:

- `Esc` backs out one level first.
- `J` toggles journal during gameplay.

## Landmark Structure

- Ferry plaza teaches movement, inspect, and first objective.
- Trinity Church: listening, NPC clues, light route finding.
- Bi Shan Tunnel: navigation and echo cues.
- Long Shan Tunnel: escort and reassurance.
- Bagua Tower: vertical traversal and synthesis.

**These five landmarks remain canonical.** They now sit inside a broader seasonal multi-route structure, with the melody route as the strongest symbolic route rather than the sole mainline. An external GDD references Sunlight Rock and Zheng Chenggong Statue as additional landmarks, but these are not part of the current authored route and are out of scope until an explicit world-design decision is made. Do not add, replace, or reorder landmarks without updating this file, `core_game_workflow.md`, and the relevant landmark feature docs.

## Non-Goals

- Do not add mandatory combat to the main loop.
- Do not let the HUD dominate the frame.
- Do not replace atmospheric interaction with heavy menu friction.

## If You Need More Detail

- Repository runtime map and ownership boundaries: [`architecture.md`](architecture.md)
- Directory map and key entry points: [`module_map.md`](module_map.md)
- Submodule roles and governance: [`submodules.md`](submodules.md)
- Submodule-owned doc entry points and when to read them: [`submodules.md`](submodules.md)
- Shared interfaces and boundaries: [`contracts.md`](contracts.md)
- Release and versioning policy: [`release_policy.md`](release_policy.md)
- Repo coding and documentation rules: [`coding_rules.md`](coding_rules.md)
- Planning-doc index and canonical implementation plan: [`plan/README.md`](plan/README.md), [`plan/implementation_plan.md`](plan/implementation_plan.md)
- Feature-doc guide: [`features/README.md`](features/README.md)
- Feature-doc template: [`features/template.md`](features/template.md)
- Core melody loop, current gap list, and MVP implementation order: [`features/core_melody_loop.md`](features/core_melody_loop.md)
- Multi-level landmark and stacked-room design: [`features/multi_level_spaces.md`](features/multi_level_spaces.md)
- NPC and resident system slice: [`npc_system_design.md`](npc_system_design.md)
- Event and story extension ideas: [`event_story_system_design.md`](event_story_system_design.md)
- Player wardrobe and costume unlocks: [`player_costume_system.md`](player_costume_system.md)
- Reusable board game module: [`grid_board_game_design.md`](grid_board_game_design.md)
- Marble game prototype rules and architecture: [`marble_game_design.md`](marble_game_design.md)
- Piano mini-game prototype and integration guidance: [`piano_game_design.md`](piano_game_design.md)
- Repeatable moment-to-moment gameplay design: [`core_gameplay_plays.md`](core_gameplay_plays.md)
- Dedicated narrative summary and story framing: [`story/summer_of_piano_island_story_framework.md`](story/summer_of_piano_island_story_framework.md)
- UI architecture and constraints: [`ui_design_context.md`](ui_design_context.md)
- Story and progression flow: [`core_game_workflow.md`](core_game_workflow.md)
- Full title/settings/pause/endgame flow: [`ui_workflow.md`](ui_workflow.md)
