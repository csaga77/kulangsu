# Resident Editor Workflow

Use the Godot Inspector to author new residents without editing `resident_catalog.gd`.

## Folders

- `definitions/`: runtime-loaded `.tres` resident definitions
- `templates/`: duplicate these into `definitions/` as a starting point

## Recommended Workflow

1. Duplicate `templates/template_resident_definition.tres` into `definitions/`.
2. Rename the file and set a unique `id`.
3. Leave `include_in_catalog = true` so the game loads it automatically.
4. Fill out the nested resources in the Inspector:
   - `appearance`
   - `dialogue`
   - `routine`
5. Set `routine.spawn.anchor_id` to an existing overworld anchor from `scenes/game_main.gd`.
6. If needed, add route points under `routine.movement.route_points`.
7. Open `characters/resident_npc.tscn` or an NPC test scene to preview the result in the editor.
8. Assign the resource through the `resident_definition` Inspector slot, which now only accepts `ResidentDefinition` resources.

## Notes

- A resource in `definitions/` with the same `id` as a built-in resident overrides the built-in catalog version.
- `sort_order` controls where new editor-authored residents appear after the built-in roster.
- `include_in_catalog = false` keeps a resource available for preview without spawning it in the main overworld.
