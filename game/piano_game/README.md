# piano_game

Self-contained rhythm/melody interaction prototype.

## Integration Status

**Standalone prototype — not yet wired into the main story flow.**

`piano_game.gd` and `piano_game.tscn` define the module interface, but there is currently no trigger in `scenes/game_main.gd`, `main.gd`, or any landmark scene that instantiates or enters this module during normal gameplay.

Before connecting this module to the main loop, read `docs/features/core_melody_loop.md` (MVP Step 5 — Add One Performance Point) for the intended integration path. The design intent is a short, low-complexity performance trigger at a specific landmark, not a full rhythm-game stage.

## Contents

- `piano_game.gd` / `piano_game.tscn` — module root and scene
- `beat_json_generator.gd` — development-time tool for authoring beat data
