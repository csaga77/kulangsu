# MP3 to OGG Converter

Editor dock plugin that batch-converts MP3 files to OGG Vorbis via ffmpeg, so shipped
`.ogg` audio under `resources/audio/` imports as real Vorbis streams (not Ogg FLAC).

This README is the plugin's entry point; the full documentation lives in [`docs/`](docs):

- [`docs/feature.md`](docs/feature.md) — goals, authoring experience, rules, edge cases, ownership, and validation.
- [`docs/contract.md`](docs/contract.md) — dock registration, persistence, ffmpeg/encoder, and threading contract.

The project-level [`../../docs/module_map.md`](../../docs/module_map.md) and
[`../../docs/architecture.md`](../../docs/architecture.md) keep one-line pointers here.
