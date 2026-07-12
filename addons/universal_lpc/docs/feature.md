# Universal LPC 2D Character Feature

## Overview

The addon turns a high-level appearance dictionary into a stack of synchronized `AnimatedSprite2D` layers. Metadata maps each selected LPC path and variant to a generated texture, frame layout, animation, direction, and expression.

The runtime path is:

1. A consuming actor assigns `UniversalLpcSprite2D.configuration`.
2. `UniversalLpcFactory` loads the prebuilt manifest and resolves selected definitions.
3. `UniversalLpcSprite2D` creates and synchronizes visible animated layers.
4. The consuming actor selects animation and expression names as gameplay state changes.

## Regenerating Metadata

Enable the `Universal LPC 2D Character` plugin and use **Open Sprite Composer** in its editor dock. The opened `tests/test_universal_lpc_sprite_generator.tscn` scene exposes inspector tool buttons for loading and generating metadata. The default workflow writes the manifest to `res://addons/universal_lpc/universal_lpc_metadata.json` and generated sprites to `res://addons/universal_lpc/resources`.

Generation depends on the upstream Universal LPC submodule being initialized at `res://3rdparty/Universal-LPC-Spritesheet-Character-Generator`.

See [`authoring.md`](authoring.md) for the canonical appearance-selection, asset-generation, validation, and attribution workflow.

## Validation

- Run `tests/test_universal_lpc_sprite_generator.tscn` to load the manifest and validate sprite composition.
- Use **Run Source Asset Audit** in the editor dock, or run `tests/test_universal_lpc_asset_audit.tscn` directly, to compare source sheets with metadata declarations and player-facing animation requirements.
- Run the consuming project's actor smoke scene after changing addon paths, metadata, or configuration behavior.

Treat unresolved texture warnings as content-contract failures: the selected path, body type, variant, or generated texture does not match the manifest.
