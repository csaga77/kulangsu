# Universal LPC 2D Character Addon

This runtime addon composes layered 2D characters from Universal LPC metadata and generated spritesheets. It also includes the development-time metadata generator, source-asset auditor, and focused validation scenes used by Kulangsu.

The addon is runtime/tooling code rather than an `EditorPlugin`, so it does not need to be enabled in Project Settings. Its reusable entry point is [`universal_lpc_sprite_2d.gd`](universal_lpc_sprite_2d.gd), which exposes the `UniversalLpcSprite2D` node type.

## Contents

- `universal_lpc_sprite_2d.gd` - layered animated-sprite renderer
- `universal_lpc_factory.gd` - metadata and texture resolver/cache
- `universal_lpc_sprite_builder.gd` - inspector-facing selection builder
- `universal_lpc_metadata_generator.gd` - development-time metadata and combined-sheet generator
- `universal_lpc_asset_auditor.gd` - source-art and metadata coverage audit
- `universal_lpc_metadata.json` - prebuilt manifest consumed by the runtime
- `tests/` - focused generation, composition, and source-audit scenes

## Kulangsu Integration

Kulangsu's generated spritesheets remain under `res://resources/sprites/universal_lpc/spritesheets`. The prebuilt manifest's `target_path` points at that content directory. `HumanBody2D` remains a game-owned actor under `res://characters`; it embeds `UniversalLpcSprite2D` as its renderer.

Development-time generation and auditing read the upstream source checkout at `res://3rdparty/Universal-LPC-Spritesheet-Character-Generator`. That submodule is not part of this addon and remains governed separately.

Universal LPC artwork has per-asset licensing and attribution requirements. Review the upstream generator's `README.md` and `CREDITS.csv` before distributing generated art.

## Documentation

- [`docs/contract.md`](docs/contract.md) - runtime, metadata, asset, and integration contract
- [`docs/feature.md`](docs/feature.md) - architecture, generation workflow, and validation
