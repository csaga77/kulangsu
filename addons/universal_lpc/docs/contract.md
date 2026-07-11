# Universal LPC Addon Contract

## Runtime API

- `UniversalLpcSprite2D` is the reusable visible character node.
- Its `configuration` dictionary selects `body_type` plus LPC layer paths and variants.
- `animation_name`, `expression_name`, and `is_playing` control presentation after configuration has loaded.
- `configuration_changed` is emitted after a new configuration is accepted.
- `metadata_file` defaults to `res://addons/universal_lpc/universal_lpc_metadata.json` and may be overridden by a consuming project.

## Metadata And Asset Contract

- The metadata file describes layer definitions, animation layouts, body types, expressions, and the generated sprite target path.
- Kulangsu's checked-in metadata resolves textures below `res://resources/sprites/universal_lpc/spritesheets`.
- Runtime code consumes prebuilt metadata and sprites. It does not regenerate character assets during gameplay.
- `UniversalLpcFactory` owns metadata parsing and texture caching for all renderer instances using the configured manifest.

## Development-Time Contract

- `UniversalLpcMetadataGenerator` reads Universal LPC source definitions from `res://3rdparty/Universal-LPC-Spritesheet-Character-Generator` by default.
- Generating metadata may update the addon's manifest while generated combined sprites remain project content under `res://resources/sprites/universal_lpc`.
- `UniversalLpcAssetAuditor` reports missing animation rows and source/definition mismatches without changing source art.
- A consuming project may override all source, metadata, target, and report paths.

## Integration Boundary

- The addon owns LPC metadata interpretation and visible layered-sprite composition.
- Consuming actors own movement, collision, gameplay animation selection, materials, and higher-level appearance catalogs.
- The upstream Universal LPC generator remains a third-party dependency and is not modified through this addon.
