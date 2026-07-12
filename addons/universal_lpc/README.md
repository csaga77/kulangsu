# Universal LPC 2D Character Plugin

This Godot plugin composes layered 2D characters from Universal LPC metadata and generated spritesheets. It also includes an editor dock for the development-time sprite-composition and source-asset-audit workflows used by Kulangsu.

Enable `Universal LPC 2D Character` under **Project > Project Settings > Plugins**. Kulangsu enables it by default. The reusable runtime entry point remains [`universal_lpc_sprite_2d.gd`](universal_lpc_sprite_2d.gd), which exposes the `UniversalLpcSprite2D` node type independently of the editor dock.

## Contents

- `universal_lpc_sprite_2d.gd` - layered animated-sprite renderer
- `universal_lpc_factory.gd` - metadata and texture resolver/cache
- `universal_lpc_sprite_builder.gd` - inspector-facing selection builder
- `universal_lpc_metadata_generator.gd` - development-time metadata and combined-sheet generator
- `universal_lpc_asset_auditor.gd` - source-art and metadata coverage audit
- `universal_lpc_metadata.json` - prebuilt manifest consumed by the runtime
- `resources/spritesheets/` - generated LPC textures consumed by the manifest
- `plugin.gd` / `plugin.cfg` - editor plugin registration and dock lifecycle
- `universal_lpc_dock.gd` - editor status and workflow launcher
- `tests/` - focused generation, composition, and source-audit scenes

## Editor Dock

The `Universal LPC 2D Character` dock reports whether the prebuilt manifest and upstream source checkout are available. It provides actions to open the sprite-composition scene and run the source-asset audit scene, whose report appears in Godot's Output panel.

## Kulangsu Integration

Kulangsu's generated spritesheets are colocated under `res://addons/universal_lpc/resources/spritesheets`. The prebuilt manifest's `target_path` points at the addon's resource directory. `HumanBody2D` remains a game-owned actor under `res://characters`; it embeds `UniversalLpcSprite2D` as its renderer.

Development-time generation and auditing read the upstream source checkout at `res://3rdparty/Universal-LPC-Spritesheet-Character-Generator`. That submodule is not part of this addon and remains governed separately.

Universal LPC artwork has per-asset licensing and attribution requirements. Review the upstream generator's `README.md` and `CREDITS.csv` before distributing generated art.

## Documentation

- [`docs/contract.md`](docs/contract.md) - runtime, metadata, asset, and integration contract
- [`docs/feature.md`](docs/feature.md) - architecture, generation workflow, and validation
