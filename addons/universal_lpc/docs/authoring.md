# Universal LPC Character Authoring

This guide owns the reusable workflow for selecting, generating, validating, and distributing Universal LPC character content. Consuming projects should keep gameplay-specific appearance catalogs, unlock rules, and UI behavior in their own documentation.

## Content Layout

- `../universal_lpc_metadata.json` is the prebuilt runtime manifest.
- `../resources/spritesheets/` contains the generated textures referenced by that manifest.
- `../tests/test_universal_lpc_sprite_generator.tscn` is the metadata and sprite-composition tool scene.
- `../tests/test_universal_lpc_asset_audit.tscn` compares source sheets, metadata declarations, and player-facing animation requirements.
- The upstream source checkout defaults to `res://3rdparty/Universal-LPC-Spritesheet-Character-Generator` and remains a separate third-party dependency.

## Appearance Configuration

`UniversalLpcSprite2D.configuration` accepts a high-level dictionary containing a `body_type` and a `selections` dictionary. Each selection maps an LPC definition path to one variant name.

Before shipping a selection:

1. Confirm the path exists in `universal_lpc_metadata.json`.
2. Confirm its definition supports every intended `body_type`.
3. Confirm the requested variant exists for those body types and layers.
4. Confirm player-facing layers cover every required animation row, normally `idle`, `walk`, `run`, and `jump`.
5. Treat unresolved texture warnings as invalid content rather than an acceptable fallback.

A path existing in the manifest is not enough if its definition only supports another body type or a narrower variant set.

## Metadata And Sprite Generation

Enable the `Universal LPC 2D Character` plugin and use **Open Sprite Composer** in its editor dock. The opened generator scene exposes inspector tool buttons for loading and generating metadata.

The default outputs are:

- manifest: `res://addons/universal_lpc/universal_lpc_metadata.json`
- generated sprites: `res://addons/universal_lpc/resources`

Runtime actors consume these prebuilt outputs. Metadata and combined sprites must not be generated during gameplay.

## Adding Assets Or Animations

1. Prefer paths and variants already present in the shipped manifest.
2. If source definitions or sheets change, regenerate the manifest and any affected combined sprites through the composer scene.
3. Run the source asset audit before painting or generating missing rows; separate genuine source-art gaps from JSON mismatches, aliases, and dynamic-path definitions.
4. Re-run sprite composition after generation and confirm all required body-type, variant, direction, expression, and animation combinations resolve.
5. Add an explicit gameplay or UI caller when a new animation needs to be triggered. Metadata availability alone does not make an animation playable.

## Validation

- Run `test_universal_lpc_sprite_generator.tscn` to load the manifest and validate layered composition.
- Use **Run Source Asset Audit** in the editor dock, or run `test_universal_lpc_asset_audit.tscn` directly, to inspect missing source rows and declaration mismatches.
- Run the consuming project's actor smoke scene after changing paths, metadata, configuration behavior, or animation layouts.
- Treat `Failed to resolve combined texture for selection layer` warnings as content-contract failures.

## Licensing And Attribution

Universal LPC artwork has per-asset licensing and attribution requirements. Review the upstream generator's `README.md` and `CREDITS.csv`, preserve the required credits for every selected asset, and confirm that each asset's license is compatible with the intended distribution platform.
