# MP3 to OGG Converter — Contract

Keep this contract and [`feature.md`](feature.md) in sync.

## Owned by

- [`../plugin.gd`](../plugin.gd)
- [`../mp3_to_ogg_dock.gd`](../mp3_to_ogg_dock.gd)

## Current contract

- The plugin is editor-only authoring tooling and must not be referenced by runtime gameplay code.
- The dock registers through the editor-managed `EditorDock` API with a stable `layout_key` (`mp3_to_ogg_converter`) and a default right-dock slot, so its placement restores cleanly from startup.
- Dock settings persist through `EditorSettings.set_project_metadata` under section `mp3_to_ogg`, key `dock_state`, holding the ffmpeg path, source folder, target folder, and integer quality. Changing storage keys or shape must be done in `_load_persisted_settings` / `_save_persisted_settings` together.
- OGG quality is an integer in the inclusive range 0–10 and is forwarded as ffmpeg `-q:a`.
- The ffmpeg binary is resolved from the configured path first, then from per-OS candidate lists; conversion fails closed if none can be executed.
- The Vorbis encoder is resolved by parsing `ffmpeg -encoders`, preferring `libvorbis` over native `vorbis`; native `vorbis` adds the strict-experimental flag when ffmpeg's encoder help reports it is required.
- The source folder must be an existing `res://` folder or an existing absolute path; the target folder must resolve to a `res://` path inside the project and is created with `make_dir_recursive_absolute`.
- The `.mp3` scan is non-recursive (top level of the source folder only); each output is `<stem>.ogg` and existing outputs are skipped, never overwritten.
- Conversion runs on a background `Thread`; the worker communicates with the main thread through a mutex-guarded event queue drained in `_process`. UI must only be touched from the main-thread event handlers, never from the worker.

## Governance

- If dock registration, persisted-metadata keys, ffmpeg/encoder resolution, the quality range, output naming, or the skip/overwrite policy changes, update this contract and [`feature.md`](feature.md).
- Keep the worker/main-thread split intact: do not call editor or scene-tree APIs from the conversion worker.
