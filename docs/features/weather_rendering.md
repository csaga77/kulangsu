# Weather Rendering

Read this file first when the task is specifically about the reusable rain overlay, weather-focused visual tuning, or the dedicated weather validation sandbox.

## Goal

- Keep weather rendering reusable and local to shared rendering helpers instead of burying it inside unrelated test scenes or gameplay systems.
- Give future weather-effect tuning a focused sandbox where rain density, wind, and overlay coverage can be checked quickly.

## User / Player Experience

- Rain should read as a calm, screen-wide weather layer rather than a handful of isolated particle streaks.
- Wind changes should be obvious enough to tune direction and force without turning the island into a noisy storm scene.
- Weather validation should happen in a scene built for weather, not while also mentally filtering through NPC, journal, or dialogue behavior.
- The dedicated weather sandbox should expose the main tuning knobs in-scene so quick rain iteration does not depend on inspector edits.

## Rules

- The reusable rain effect lives in [`../../common/rain_overlay.tscn`](../../common/rain_overlay.tscn) and [`../../common/rain_overlay.gd`](../../common/rain_overlay.gd).
- Lightweight ground-hit weather feedback lives in [`../../common/rain_ground_impacts.gd`](../../common/rain_ground_impacts.gd).
- Ground impacts should snap and read against the repo's isometric `64 x 32` ground convention instead of using generic top-down splash shapes.
- The dedicated weather sandbox should use `TileMapLayer` terrain and ground for outdoor hit validation instead of a hand-drawn background or platform proxy.
- The dedicated weather sandbox may keep a small number of temporary foreground occluder proxies when that is the fastest way to validate rain layering, shelter readability, or under-cover silhouettes.
- The dedicated weather sandbox should include a controllable player plus a few resident actors so rain readability can be checked around moving silhouettes and nearby speech balloons.
- The dedicated weather sandbox should keep a lightweight weather control panel for the most common rain and ground-impact adjustments.
- Weather rendering should stay in shared rendering/common helpers until the game has a broader authored weather system.
- Validation tile layers in [`../../scenes/test_weather.tscn`](../../scenes/test_weather.tscn) exist only to make rain coverage, direction, and visibility easy to judge; the remaining hand-authored foreground shapes are only proxy occluders.
- Keep the weather sandbox focused on rendering and tuning. Do not let it become the new home for NPC, journal, or progression checks.

## Edge Cases

- In a `CanvasLayer`, the rain overlay should stay anchored to the viewport instead of shifting when the player or camera moves.
- Outside a `CanvasLayer`, the rain overlay still depends on the active `Camera2D` for coverage sizing.
- Weather tuning is sensitive to viewport size and zoom; if rain suddenly looks sparse or overcrowded, verify the camera and overlay coverage before changing particle values.
- If a future overlay stops reading as screen-wide, first confirm whether it is being drawn in a true overlay layer or mixed into y-sorted world content.

## Architecture / Ownership

- [`../../common/rain_overlay.tscn`](../../common/rain_overlay.tscn), [`../../common/rain_overlay.gd`](../../common/rain_overlay.gd), and [`../../common/rain_ground_impacts.gd`](../../common/rain_ground_impacts.gd) own the reusable weather rendering pieces.
- [`../../scenes/test_weather.tscn`](../../scenes/test_weather.tscn) and [`../../scenes/test_weather.gd`](../../scenes/test_weather.gd) own the dedicated validation environment, tilemap-backed reference terrain, and temporary foreground occluder proxies.
- Keep weather rendering local to `common/` and focused validation scenes. Do not move it into UI, `AppState`, or unrelated gameplay modules unless an actual weather gameplay system is introduced.

## Relevant Files

- Scenes:
  - [`../../common/rain_overlay.tscn`](../../common/rain_overlay.tscn)
  - [`../../scenes/test_weather.tscn`](../../scenes/test_weather.tscn)
- Scripts:
  - [`../../common/rain_overlay.gd`](../../common/rain_overlay.gd)
  - [`../../common/rain_ground_impacts.gd`](../../common/rain_ground_impacts.gd)
  - [`../../scenes/test_weather.gd`](../../scenes/test_weather.gd)
- Related docs:
  - [`../module_map.md`](../module_map.md)

## Signals / Nodes / Data Flow

- Signals emitted:
  - None dedicated to weather rendering yet.
- Signals consumed:
  - `RainOverlay` reads the active viewport camera each frame.
- Important node paths, dictionaries, resources, or data flow:
- `RainOverlay` updates its particle emitter extents from the viewport and uses screen-space anchoring automatically when it lives under a `CanvasLayer`.
- `RainGroundImpacts` keeps a fixed pool of short-lived impact states, snaps them to the isometric ground projection, and redraws them from a single node instead of spawning per-hit scenes.
- `test_weather.gd` rebuilds water, distant terrain, and the pier footprint from the terrain tileset into `TileMapLayer` nodes, and `RainGroundImpacts` samples the pier layer so impacts land on actual painted tiles.
- `test_weather.tscn` keeps a shared `Actors` layer with a player and resident instances so weather can be checked against gameplay-scale characters.
- `test_weather.tscn` still includes a small `ForegroundOccluders` proxy layer for quick shelter/occlusion validation without needing a fully authored foreground set.
- `test_weather.tscn` keeps the rain overlay under a dedicated `CanvasLayer` so visual tuning happens in an actual overlay context.
- `test_weather.tscn` also keeps a weather-controls `CanvasLayer` that adjusts the shared rain overlay and ground-impact gain in real time.

## Contracts / Boundaries

- If the reusable weather effect stops being camera-followed or stops being overlay-based, update this doc and [`../module_map.md`](../module_map.md).
- If a broader authored weather system is introduced, document which part lives in shared rendering helpers and which part lives in gameplay/state code.

## Validation

- Run [`../../scenes/test_weather.tscn`](../../scenes/test_weather.tscn) for focused rain tuning.
- Use the in-scene weather control panel to tune rain density, wind angle, wind strength, drop speed, drop size, and ground-impact gain while the scene is running.
- Adjust the `RainOverlay` instance or `GroundImpacts` node in the inspector only when a change needs a deeper structural retune than the panel exposes.
- Walk the player around the pier and approach residents to confirm rain still reads cleanly around actors and nearby `...` talk cues.
- Check three things before considering a weather tweak complete:
  - rain coverage still feels screen-wide at the current camera zoom
  - wind direction and force remain readable against the tilemap shoreline and pier edges
  - ground impacts stay lightweight and readable without turning the lower half of the frame into visual noise
  - player and resident silhouettes remain legible under both rain and foreground occluders
  - the overlay stays visually separate from unrelated resident or UI validation

## Current Exceptions

- [`../../scenes/test_weather.tscn`](../../scenes/test_weather.tscn) is mostly tilemap-backed now.
- The remaining non-tilemap content in that sandbox is the temporary `ForegroundOccluders` proxy layer made from `Line2D` and `Polygon2D` nodes.
- Replace those proxies with authored tilemap or scene content only when weather tuning actually needs more realistic shelter geometry.

## Out Of Scope

- A full dynamic weather state machine, forecast schedule, or story-driven weather progression.
- Audio mixing, puddles, lightning, wet-surface shaders, or gameplay rules that depend on weather state.
