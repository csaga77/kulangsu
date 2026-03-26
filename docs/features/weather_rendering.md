# Weather Rendering

Read this file first when the task is specifically about the reusable rain/fog overlays, weather-focused visual tuning, or the dedicated weather validation sandbox.

This document is also the current handoff guide for the weather system. Another agent should be able to read this file, open the listed files, and continue weather work without needing the full conversation history.

## Goal

- Keep weather rendering reusable and local to shared rendering helpers instead of burying it inside unrelated test scenes or gameplay systems.
- Give future weather-effect tuning a focused sandbox where rain density, wind, fog coverage, and overlay behavior can be checked quickly.
- Keep the current weather work rendering-first. The project does not have a broader gameplay weather state machine yet.

## Current Status

- The weather system is currently a reusable rendering stack plus a focused sandbox, not a full gameplay/weather-progression system.
- The shared reusable pieces live in [`../../common/`](../../common).
- The dedicated integration/tuning target is [`../../scenes/tests/test_weather.tscn`](../../scenes/tests/test_weather.tscn).
- The sandbox is the source of truth for default tuning. The scene instance values are captured at startup and reused for the panel reset flow.

## Design Intent

- Rain should read as a calm, screen-wide isometric weather layer instead of a few isolated particle streaks.
- Fog should read as a screen-wide isometric haze, not a bottom-only shoreline band.
- Wind direction should be easy to judge from both rain and fog.
- Wind strength should produce an obvious speed change in fog drift instead of only subtle shader motion.
- Ground rain hits should stay lightweight and small, and should read against the repo's `64 x 32` isometric tile convention.
- Thunder should read as a short flash of light, not a long ambient lighting wash.
- Weather validation should happen in a scene built for weather, not while also mentally filtering through unrelated dialogue, journal, or progression behavior.

## Runtime Stack

The current validation scene is assembled like this:

```text
test_weather.tscn
- Water (TileMapLayer)
- BackdropTerrain (TileMapLayer)
- Ground (TileMapLayer)
- GroundImpacts (RainGroundImpacts)
- Actors
- ForegroundOccluders
- WeatherLayer (CanvasLayer)
  - FogOverlay
  - RainOverlay
- ThunderLayer (CanvasLayer)
  - ThunderFill
  - ThunderGlow
- WeatherControlsLayer (CanvasLayer)
  - WeatherPanel
```

Important implications:

- Terrain and ground are tilemap-backed.
- Ground impacts are world-space and sample painted cells from `Ground`.
- Fog and rain are screen-space overlays under `WeatherLayer`.
- Thunder is a separate screen-space pass above the world/weather but below the controls UI.
- The weather controls are sandbox-only. They are for tuning and validation, not gameplay state.

## Ownership

- [`../../common/rain_overlay.tscn`](../../common/rain_overlay.tscn) and [`../../common/rain_overlay.gd`](../../common/rain_overlay.gd) own the reusable rain overlay.
- [`../../common/fog_overlay.tscn`](../../common/fog_overlay.tscn) and [`../../common/fog_overlay.gd`](../../common/fog_overlay.gd) own the reusable fog overlay.
- [`../../common/rain_ground_impacts.gd`](../../common/rain_ground_impacts.gd) owns the lightweight isometric raindrop ground-hit effect.
- [`../../scenes/tests/test_weather.tscn`](../../scenes/tests/test_weather.tscn) and [`../../scenes/tests/test_weather.gd`](../../scenes/tests/test_weather.gd) own the sandbox scene, tilemap-backed reference terrain, thunder pass, actor readability setup, and in-scene weather controls.

Keep weather rendering local to `common/` and focused validation scenes. Do not move weather state into UI, `AppState`, or unrelated gameplay modules unless the game gets an actual authored weather system.

## Change Routing

If you need to change something, start here:

- Tune rain particle look, coverage, density math, or screen/world anchoring:
  Use [`../../common/rain_overlay.gd`](../../common/rain_overlay.gd) and [`../../common/rain_overlay.tscn`](../../common/rain_overlay.tscn).
- Tune fog distribution, motion, or shader look:
  Use [`../../common/fog_overlay.gd`](../../common/fog_overlay.gd) and [`../../common/fog_overlay.tscn`](../../common/fog_overlay.tscn).
- Tune ground-hit spawn logic, iso placement, or draw behavior:
  Use [`../../common/rain_ground_impacts.gd`](../../common/rain_ground_impacts.gd).
- Change default weather feel, control panel behavior, or reset behavior:
  Use [`../../scenes/tests/test_weather.tscn`](../../scenes/tests/test_weather.tscn) and [`../../scenes/tests/test_weather.gd`](../../scenes/tests/test_weather.gd).
- Change sandbox layout, actors, or tilemap-backed terrain references:
  Use [`../../scenes/tests/test_weather.gd`](../../scenes/tests/test_weather.gd) first, then [`../../scenes/tests/test_weather.tscn`](../../scenes/tests/test_weather.tscn) if a scene-structure change is needed.
- Add a new reusable weather render pass:
  Put the render/helper node under `common/`, instantiate and validate it in `test_weather`, then document it here.

## Core Behaviors

### Rain Overlay

- `RainOverlay` is a `GPUParticles2D`-based screen overlay.
- In a `CanvasLayer`, it anchors to the viewport instead of following world movement.
- Density is derived from visible area in [`../../common/rain_overlay.gd`](../../common/rain_overlay.gd).
- The particle emission box uses half-extents of the visible size, matching Godot's `emission_box_extents` behavior.
- Wind angle and wind strength currently drive both particle direction and gravity.
- The overlay adjusts `local_coords` and `visibility_rect` based on whether it is being used in screen space or world space.

### Fog Overlay

- `FogOverlay` is a `Node2D` with a single shader-driven `ColorRect`.
- The fog shader currently lives as an embedded subresource in [`../../common/fog_overlay.tscn`](../../common/fog_overlay.tscn), not in a standalone `.gdshader` file. This is easy to miss when searching.
- In a `CanvasLayer`, the fog anchors to the viewport just like the rain overlay.
- The script in [`../../common/fog_overlay.gd`](../../common/fog_overlay.gd) advances a persistent `drift_offset` every frame.
- Wind angle defines drift direction.
- Wind strength scales drift speed.
- The shader uses that drift offset to move multiple noise bands and wisps, producing a screen-wide isometric haze rather than a local ground fog patch.

### Ground Impacts

- `RainGroundImpacts` is a pooled `Node2D` effect, not a spawned-per-drop scene system.
- Spawn rate is derived from:
  `base_spawn_rate + rain_density * density_spawn_multiplier`
- The effect samples actual painted cells from the assigned tilemap layer instead of guessing arbitrary positions.
- Impacts are snapped and drawn against the repo's `64 x 32` isometric convention.
- If the assigned `Ground` layer is empty, or the `spawn_layer_path` is wrong, the effect will appear to stop working.

### Thunder

- The thunder effect is currently sandbox-owned, not a shared reusable weather node yet.
- It uses a short neutral fill plus additive glow in `ThunderLayer`.
- Its scheduling and flash sequencing live in [`../../scenes/tests/test_weather.gd`](../../scenes/tests/test_weather.gd).

## Weather Controls

The in-scene panel is the main tuning surface.

Current controls:

- `Rain Enabled`
- `Fog Enabled`
- `Thunder Enabled`
- `Rain Density`
- `Wind Angle`
- `Wind Strength`
- `Drop Speed`
- `Drop Size`
- `Fog Density`
- `Fog Height`
- `Fog Drift`
- `Thunder Strength`
- `Impact Gain`
- `Trigger Thunder`
- `Reset`

Important behavior:

- The scene instance values are captured in `m_weather_defaults` by [`../../scenes/tests/test_weather.gd`](../../scenes/tests/test_weather.gd) during `_capture_weather_defaults()`.
- Reset restores those captured values, not separate hardcoded defaults.
- If you change the intended default weather feel, update the instance values in [`../../scenes/tests/test_weather.tscn`](../../scenes/tests/test_weather.tscn). The script then syncs the controls from the scene state.
- Wind angle and wind strength are shared inputs: changing them updates both rain and fog.
- `Rain Enabled` currently toggles the rain overlay and ground impacts together.

## Sandbox Responsibilities

`test_weather` is intentionally doing more than only showing a background:

- It rebuilds `Water`, `BackdropTerrain`, and `Ground` from the shared terrain tileset.
- It keeps `GroundImpacts` tied to the painted `Ground` tilemap.
- It includes a player and NPCs so weather readability can be judged around moving silhouettes and nearby speech balloons.
- It keeps temporary `ForegroundOccluders` proxy geometry for fast shelter/occlusion checks.
- It keeps a focused weather control panel so frequent tuning does not require Inspector edits.

Do not let `test_weather` become the default place to test unrelated NPC, journal, or progression features.

## Known Constraints And Pitfalls

- In a `CanvasLayer`, the rain and fog overlays should stay anchored to the viewport instead of shifting when the player or camera moves.
- Outside a `CanvasLayer`, `RainOverlay` still depends on the active `Camera2D` for coverage sizing.
- Weather tuning is sensitive to viewport size and zoom. If rain looks sparse or fog looks wrong, check camera and overlay coverage before changing effect numbers.
- The fog shader is embedded in [`../../common/fog_overlay.tscn`](../../common/fog_overlay.tscn). If a change seems to have no effect, confirm you edited the shader subresource and not only the script.
- If fog appears static, inspect `drift_offset` updates in [`../../common/fog_overlay.gd`](../../common/fog_overlay.gd) before retuning the shader again.
- If ground impacts disappear, confirm that `Ground` is painted and that `RainGroundImpacts.spawn_layer_path` still points to the right node.
- `ForegroundOccluders` are still temporary proxies. They are not a long-term world-authoring solution.
- Thunder is still scene-local. If thunder needs to become reusable, move it deliberately and document the new ownership split.

## Extension Workflow

When adding a new weather feature, follow this order:

1. Decide whether the feature is reusable rendering or scene-specific validation.
2. Put reusable rendering helpers in `common/`.
3. Instantiate and validate the feature in [`../../scenes/tests/test_weather.tscn`](../../scenes/tests/test_weather.tscn).
4. Add weather-panel controls only for knobs that are likely to be tuned repeatedly.
5. Keep gameplay/weather-state decisions out of `AppState` unless a broader authored weather system is actually being introduced.
6. Update this doc, [`../module_map.md`](../module_map.md), and [`../../README.md`](../../README.md) when the feature changes weather ownership or validation workflow.

## Good Next Extensions

These are reasonable follow-on features for the current design:

- shelter and roof masking for rain/fog
- authored foreground shelter geometry to replace proxy occluders
- reusable thunder node if lightning needs to be used outside the sandbox
- additional fog controls such as tint, band scale, or turbulence
- scene-level weather presets if the project starts using weather beyond the sandbox

## Validation

- Run [`../../scenes/tests/test_weather.tscn`](../../scenes/tests/test_weather.tscn) for focused weather tuning.
- Use the in-scene weather control panel to toggle rain, fog, or thunder on or off, trigger thunder manually, and tune the main shared parameters while the scene is running.
- Adjust the shared weather nodes in the inspector only when a change needs a deeper structural retune than the panel exposes.
- Walk the player around the pier and approach residents to confirm weather still reads cleanly around actors and nearby `...` talk cues.
- Check these things before considering a weather tweak complete:
  - rain coverage still feels screen-wide at the current camera zoom
  - fog reads across the whole screen for the isometric camera instead of collapsing into a local band
  - fog drift still follows the shared wind direction
  - stronger wind clearly speeds the fog up instead of leaving it nearly static
  - the layered fog pass still reads like drifting mist and haze instead of a flat alpha wash
  - optional thunder flashes still keep the world and rain visually coherent instead of flashing only one layer
  - thunder still reads as a quick flash of light instead of a long ambient wash
  - ground impacts stay lightweight and readable without turning the lower half of the frame into visual noise
  - player and resident silhouettes remain legible under both rain and foreground occluders
  - the overlay stays visually separate from unrelated resident or UI validation

## Current Exceptions

- [`../../scenes/tests/test_weather.tscn`](../../scenes/tests/test_weather.tscn) is mostly tilemap-backed now.
- The remaining non-tilemap content in that sandbox is the temporary `ForegroundOccluders` proxy layer made from `Line2D` and `Polygon2D` nodes.
- Replace those proxies with authored tilemap or scene content only when weather tuning actually needs more realistic shelter geometry.

## Out Of Scope

- A full dynamic weather state machine, forecast schedule, or story-driven weather progression.
- Audio mixing, puddles, looping storm audio, volumetric world fog, wet-surface shaders, or gameplay rules that depend on weather state.
