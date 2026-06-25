# MP3 to OGG Converter — Feature

## Goal

- Give content authors an in-editor way to batch-convert MP3 source files into OGG Vorbis files that Godot can import as real Vorbis streams.
- Avoid the common pitfall of shipping Ogg FLAC with a `.ogg` extension, which Godot does not treat as a usable stream.

## User / Developer Experience

- The plugin adds a right-dock panel titled "MP3 to OGG Converter".
- The panel exposes: an ffmpeg path field with a browse button, source-folder and target-folder fields with browse buttons, an OGG quality spinner, a Convert button, a Copy button for the log, a progress label, a progress bar, and a scrolling log.
- The ffmpeg field is pre-filled by probing common install locations for the current OS; the author can override it via the browse dialog.
- Conversion runs in the background so the editor stays responsive; progress and per-file results stream into the log as they complete.
- Field values (ffmpeg path, source, target, quality) persist per-project across editor sessions.

## Rules

- OGG quality is an integer from 0 to 10 (default 6) passed straight to ffmpeg's `-q:a`; higher means better quality and larger files.
- The source folder must be an existing `res://` folder or an existing absolute path; otherwise conversion is rejected with a logged error.
- The target folder must resolve inside the project (a `res://` path, or an absolute path under the project root); it is created recursively if missing.
- Only `.mp3` files in the top level of the source folder are converted (the scan is not recursive).
- Each output is written as `<source-stem>.ogg` in the target folder.
- An output that already exists is skipped (logged as `SKIP existing`) rather than overwritten.
- Conversion requires a working ffmpeg with a Vorbis encoder; `libvorbis` is preferred, falling back to the native `vorbis` encoder with the strict-experimental flag when required.

## Edge Cases

- If no ffmpeg binary can be executed from the configured path or the OS candidate list, conversion is rejected with a logged error.
- If ffmpeg reports no Vorbis encoder, conversion stops and the log notes the expected encoders (`vorbis`, `libvorbis`).
- If the source folder cannot be opened or contains no `.mp3` files, the run ends without producing output.

## Architecture / Ownership

- `plugin.gd` is the `EditorPlugin`; it instances the dock control and registers it through Godot's editor-managed `EditorDock` API so its placement restores from startup.
- `mp3_to_ogg_dock.gd` owns the dock UI, settings persistence, ffmpeg/encoder resolution, the background conversion worker, and log/progress output.

## Relevant Files

- Scripts: `plugin.gd`, `mp3_to_ogg_dock.gd`
- Contract: `contract.md`

## Validation

- With ffmpeg installed, point the source field at a folder of `.mp3` files and a `res://` target, run Convert, and confirm `.ogg` files appear in the target and import as Vorbis streams.
- Re-run and confirm existing outputs are skipped.
- Restart the editor and confirm the ffmpeg/source/target/quality fields are restored.
