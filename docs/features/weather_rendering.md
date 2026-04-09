# Weather Rendering

Read this file first when the task is specifically about the reusable rain/fog overlays, weather-focused visual tuning, or the dedicated weather validation sandbox.

This document is also the current handoff guide for the weather system. Another agent should be able to read this file, open the listed files, and continue weather work without needing the full conversation history.

## Goal

- Keep weather rendering reusable and local to shared rendering helpers instead of burying it inside unrelated test scenes or gameplay systems.
- Give future weather-effect tuning a focused sandbox where rain density, wind, fog coverage, and overlay behavior can be checked quickly.
- Keep the current weather work rendering-first. The project now has a global overworld weather manager, but not a story-authored forecast or full gameplay weather progression system.

## Current Status

- The weather system is currently a reusable rendering stack, a global overworld weather manager, and a focused sandbox, not a full gameplay/weather-progression system.
- The shared reusable pieces live in [`../../weather/`](../../weather).
- [`../../scenes/game_main.gd`](../../scenes/game_main.gd) and [`../../weather/tests/test_weather.gd`](../../weather/tests/test_weather.gd) now register weather hosts instead of serializing rain/fog/cloud/impact nodes directly into their scenes.
- [`../../weather/weather_manager.gd`](../../weather/weather_manager.gd) now instantiates the runtime weather rig, drives random preset-to-preset transitions for the overworld rain and fog, and keeps cloud-shadow drift aligned with the shared wind.
- [`../../weather/weather_runtime.gd`](../../weather/weather_runtime.gd) resolves that manager as a scene-owned runtime service without using a Project Settings autoload.
- The dedicated integration/tuning target is [`../../weather/tests/test_weather.tscn`](../../weather/tests/test_weather.tscn).
- The sandbox is the source of truth for default tuning. Its runtime weather values are captured at startup and reused for the panel reset flow.
- Thunder is still sandbox-owned for now. The main scene currently uses the shared reusable weather pieces only.
- In gameplay, the manager-created overworld `WeatherLayer` should render above the world canvas so terrain does not hide the rain, while the shell UI stays on a higher `CanvasLayer` above weather.
- In gameplay, tunnel interiors should suppress the shared rain, fog, and ground-impact passes entirely so the player does not see outdoor weather inside a tunnel.

## Design Intent

- Rain should read as a calm, screen-wide isometric weather layer instead of a few isolated particle streaks.
- Fog should read as a screen-wide isometric haze, not a bottom-only shoreline band.
- Cloud shadows should read as broad, slow-moving multiply-darkened world shadows that drift with the weather direction without darkening actors or UI.
- Cloud shadow size should be easy to tune without editing raw noise scales by hand.
- Wind direction should be easy to judge from both rain and fog.
- Wind strength should produce an obvious speed change in fog drift instead of only subtle shader motion, and calm wind should allow the fog to settle instead of drifting anyway.
- Ground rain hits should stay lightweight and small, and should read against the repo's `64 x 32` isometric tile convention.
- Thunder should read as a short flash of light, not a long ambient lighting wash.
- Weather validation should happen in a scene built for weather, not while also mentally filtering through unrelated dialogue, journal, or progression behavior.
- Weather changes in gameplay should feel gentle and atmospheric. The cycle should drift between presets over time, not pop abruptly or swing like an arcade storm system.

## Runtime Stack

The current validation scene is assembled like this:

```text
test_weather.tscn
- Water (TileMapLayer)
- BackdropTerrain (TileMapLayer)
- Ground (TileMapLayer)
- Actors
- ForegroundOccluders
- ThunderLayer (CanvasLayer)
  - ThunderFill
  - ThunderGlow
- WeatherControlsLayer (CanvasLayer)
  - WeatherPanel

WeatherManager runtime rig
- CloudShadows (CloudShadowOverlay) attached under the registered world parent
- GroundImpacts (RainGroundImpacts) attached under the registered impacts parent
- WeatherLayer (CanvasLayer) attached under the registered overlay parent
  - FogOverlay
  - RainOverlay
```

Important implications:

- Terrain and ground are tilemap-backed.
- Cloud shadows are world-space and should sit above terrain but below actors and ground impacts.
- Ground impacts are world-space and sample painted cells from `Ground`.
- Fog and rain are screen-space overlays under `WeatherLayer`.
- In the real overworld scene, that `WeatherLayer` sits above terrain/actors and below the shell UI layer.
- Thunder is a separate screen-space pass above the world/weather but below the controls UI.
- The weather controls are sandbox-only. They are for tuning and validation, not gameplay state.

## Ownership

- [`../../weather/rain_overlay.tscn`](../../weather/rain_overlay.tscn) and [`../../weather/rain_overlay.gd`](../../weather/rain_overlay.gd) own the reusable rain overlay.
- [`../../weather/fog_overlay.tscn`](../../weather/fog_overlay.tscn) and [`../../weather/fog_overlay.gd`](../../weather/fog_overlay.gd) own the reusable fog overlay.
- [`../../weather/cloud_shadow_overlay.tscn`](../../weather/cloud_shadow_overlay.tscn) and [`../../weather/cloud_shadow_overlay.gd`](../../weather/cloud_shadow_overlay.gd) own the reusable drifting ground-shadow pass.
- [`../../weather/rain_ground_impacts.gd`](../../weather/rain_ground_impacts.gd) owns the lightweight isometric raindrop ground-hit effect.
- [`../../scenes/game_main.gd`](../../scenes/game_main.gd) owns how the real overworld scene registers weather hosts and default properties.
- [`../../weather/weather_manager.gd`](../../weather/weather_manager.gd) owns runtime weather-rig instancing, random preset selection, hold timing, smooth interpolation between overworld weather states, and the live application of synced wind settings to registered rain/fog/cloud targets.
- [`../../weather/weather_runtime.gd`](../../weather/weather_runtime.gd) owns the runtime lookup path for that single shared manager instance.
- [`../../weather/tests/test_weather.tscn`](../../weather/tests/test_weather.tscn) and [`../../weather/tests/test_weather.gd`](../../weather/tests/test_weather.gd) own the sandbox scene, tilemap-backed reference terrain, thunder pass, actor readability setup, in-scene weather controls, and the weather-host registration used for runtime weather nodes.

Keep weather rendering local to `weather/` and focused validation scenes. Do not move weather state into UI, `AppState`, or unrelated gameplay modules unless the game gets an actual authored weather system.

## Change Routing

If you need to change something, start here:

- Tune rain particle look, coverage, density math, or screen/world anchoring:
  Use [`../../weather/rain_overlay.gd`](../../weather/rain_overlay.gd) and [`../../weather/rain_overlay.tscn`](../../weather/rain_overlay.tscn).
- Tune fog distribution, motion, or shader look:
  Use [`../../weather/fog_overlay.gd`](../../weather/fog_overlay.gd) and [`../../weather/fog_overlay.tscn`](../../weather/fog_overlay.tscn).
- Tune cloud-shadow coverage, softness, or drift behavior:
  Use [`../../weather/cloud_shadow_overlay.gd`](../../weather/cloud_shadow_overlay.gd) and [`../../weather/cloud_shadow_overlay.tscn`](../../weather/cloud_shadow_overlay.tscn).
- Tune ground-hit spawn logic, iso placement, or draw behavior:
  Use [`../../weather/rain_ground_impacts.gd`](../../weather/rain_ground_impacts.gd).
- Change default weather feel, control panel behavior, or reset behavior:
  Use [`../../weather/tests/test_weather.tscn`](../../weather/tests/test_weather.tscn) and [`../../weather/tests/test_weather.gd`](../../weather/tests/test_weather.gd).
- Change how reusable rain/fog/ground impacts are attached to the overworld scene:
  Use [`../../scenes/game_main.gd`](../../scenes/game_main.gd) and [`../../weather/weather_manager.gd`](../../weather/weather_manager.gd).
- Change the overworld's random preset list, hold duration, transition timing, or synced gameplay wind application:
  Use [`../../weather/weather_manager.gd`](../../weather/weather_manager.gd), [`../../weather/weather_runtime.gd`](../../weather/weather_runtime.gd), and the registration/config path in [`../../scenes/game_main.gd`](../../scenes/game_main.gd).
- Change sandbox layout, actors, or tilemap-backed terrain references:
  Use [`../../weather/tests/test_weather.gd`](../../weather/tests/test_weather.gd) first, then [`../../weather/tests/test_weather.tscn`](../../weather/tests/test_weather.tscn) if a scene-structure change is needed.
- Add a new reusable weather render pass:
  Put the render/helper node under `weather/`, instantiate and validate it in `test_weather`, then document it here.

## Core Behaviors

### Cloud Shadow Overlay

- `CloudShadowOverlay` is a world-space `Node2D` with a shader-driven `ColorRect`.
- It tracks camera coverage for sizing, but samples shader noise in world coordinates so the shadow pattern does not stick to the screen when the player moves.
- It is intended to sit above terrain and below actors so only the ground/world scene darkens.
- The shader now uses a multiply-style darkening pass instead of a faint alpha tint, so readable cloud shapes come from the tint value plus the cloud mask instead of only transparency.
- `cloud_size` scales the broad and detail noise sampling together, so larger values create bigger drifting shadow masses without retuning the shader by hand.
- `speed_gain` multiplies the wind-driven drift rate, so cloud shadows can move faster or slower without changing the shared rain/fog wind settings.
- It drifts slowly using the shared weather wind angle and wind strength.
- In gameplay, tunnel suppression should hide it alongside rain and fog.

### Rain Overlay

- `RainOverlay` is a `GPUParticles2D`-based screen overlay.
- In a `CanvasLayer`, it anchors to the viewport instead of following world movement.
- Density is derived from visible area in [`../../weather/rain_overlay.gd`](../../weather/rain_overlay.gd).
- The particle emission box uses half-extents of the visible size, matching Godot's `emission_box_extents` behavior.
- Wind angle and wind strength currently drive both particle direction and gravity.
- The overlay adjusts `local_coords` and `visibility_rect` based on whether it is being used in screen space or world space.

### Fog Overlay

- `FogOverlay` is a `Node2D` with a single shader-driven `ColorRect`.
- The fog shader currently lives as an embedded subresource in [`../../weather/fog_overlay.tscn`](../../weather/fog_overlay.tscn), not in a standalone `.gdshader` file. This is easy to miss when searching.
- In a `CanvasLayer`, the fog anchors to the viewport just like the rain overlay.
- The script in [`../../weather/fog_overlay.gd`](../../weather/fog_overlay.gd) advances a persistent `drift_offset` every frame.
- Wind angle defines drift direction.
- Wind strength scales drift speed.
- The shader uses that drift offset to move multiple noise bands and wisps, producing a screen-wide isometric haze rather than a local ground fog patch.

### Ground Impacts

- `RainGroundImpacts` is a pooled `Node2D` effect, not a spawned-per-drop scene system.
- Spawn rate is derived from:
  `base_spawn_rate + rain_density * density_spawn_multiplier`
- Ground impacts only spawn when current rain density is above zero, so the overworld can transition into dry presets without leaving stray raindrop hits behind.
- The effect samples actual painted cells from the assigned tilemap layer instead of guessing arbitrary positions.
- The effect caches painted-cell world positions and only refilters the current camera band as the view changes, so repeated impact spawns do not rescan the whole tilemap every burst.
- Impacts are snapped and drawn against the repo's `64 x 32` isometric convention.
- If the assigned `Ground` layer is empty, or the registered `spawn_layer` is wrong, the effect will appear to stop working.

### Global Weather Manager

- `WeatherManager` is a shared scene-owned runtime service, not a reusable render node.
- It creates and owns the runtime weather rig from scene-provided host parents and default-property dictionaries, so gameplay scenes and the sandbox no longer serialize rain/fog/cloud/impact nodes directly.
- It captures the current registered weather values on startup, holds for a random duration, then transitions to a different preset over another random duration.
- The current preset list covers calm haze, mist, light rain, steady rain, and a gustier shower.
- It interpolates rain density, rain drop speed/size, fog density, fog height, fog drift speed, wind angle, and wind strength.
- It owns the synced wind application into rain, fog, and cloud-shadow targets, so gameplay scenes and the weather sandbox do not need their own per-pass wind propagation helpers.
- The random cycle currently affects the playable overworld only. The weather sandbox reuses the manager for wind-sync behavior while keeping `cycles_enabled = false` so it remains a predictable tuning environment.
- If future work needs authored districts, chapters, or forecast control, replace the preset selection policy in `WeatherManager` instead of pushing that logic down into `RainOverlay` or `FogOverlay`.

### Tunnel Suppression

- The overworld scene currently decides when to hide weather because of tunnel interiors, but it now does so through `WeatherManager.set_registered_visibility(...)` instead of manually toggling every runtime weather node.
- This logic lives in [`../../scenes/game_main.gd`](../../scenes/game_main.gd) alongside the existing tunnel-context visibility sync.
- When tunnel suppression activates, ground impacts are also cleared so outdoor raindrop hits do not reappear when the player exits.
- The sandbox does not apply this behavior because it is meant for direct weather inspection, not tunnel integration validation.

### Thunder

- The thunder effect is currently sandbox-owned, not a shared reusable weather node yet.
- It uses a short neutral fill plus additive glow in `ThunderLayer`.
- Its scheduling and flash sequencing live in [`../../weather/tests/test_weather.gd`](../../weather/tests/test_weather.gd).

## Weather Controls

The in-scene panel is the main tuning surface.

The panel is currently split into four tabs so each weather family can be tuned without one long scrolling grid.

Current controls:

- `Wind` tab: `Wind Angle`, `Wind Strength`
- `Rain` tab: `Rain Enabled`, `Sync With Wind`, `Thunder Enabled`, `Rain Density`, `Drop Speed`, `Drop Size`, `Impact Gain`, `Thunder Strength`, `Trigger Thunder`
- `Fog` tab: `Fog Enabled`, `Sync With Wind`, `Fog Density`, `Fog Height`, `Fog Drift`
- `Cloud` tab: `Cloud Enabled`, `Sync With Wind`, `Shadow Direction`, `Cloud Size`, `Shadow Speed Gain`, `Shadow Darkness`
- Shared action: `Reset`

Important behavior:

- The runtime weather values are captured in `m_weather_defaults` by [`../../weather/tests/test_weather.gd`](../../weather/tests/test_weather.gd) during `_capture_weather_defaults()`.
- Reset restores those captured values, not separate hardcoded defaults.
- If you change the intended default weather feel, update the sandbox weather host config in [`../../weather/tests/test_weather.gd`](../../weather/tests/test_weather.gd) and any matching UI-default values in [`../../weather/tests/test_weather.tscn`](../../weather/tests/test_weather.tscn). The script then syncs the controls from the live scene state.
- The panel layout now groups the tuning surface into `Wind`, `Rain`, `Fog`, and `Cloud` tabs. Thunder remains in the `Rain` tab because it is currently sandbox-only storm feedback, not a shared weather pass.
- The `Wind` tab owns the master wind angle and wind strength values instead of borrowing them from the rain overlay.
- `Wind Angle` now spans the full `0..360` range for shared wind direction, but `RainOverlay` locally clamps that angle to `30..150` so rain stays in the intended isometric slant range even when fog or cloud shadows are driven to other compass directions.
- Each of `Rain`, `Fog`, and `Cloud` now has a `Sync With Wind` toggle. When enabled, that pass follows the master `Wind` tab angle and strength through `WeatherManager`. When disabled, it keeps its current wind settings until sync is turned back on.
- `Cloud Enabled` currently toggles the world-space `CloudShadows` pass on or off without losing the rest of the cloud-shadow tuning values.
- The `Rain Enabled`, `Fog Enabled`, and `Cloud Enabled` checkboxes now drive each subsystem's exported `enabled` property instead of directly rewriting node visibility, so gameplay visibility suppression can stay separate from tuning-time on/off state.
- `Cloud Size` currently maps to `CloudShadowOverlay.cloud_size`, so it is the main sandbox knob for enlarging or tightening the drifting cloud masses.
- `Shadow Direction` currently maps to `CloudShadowOverlay.wind_angle_degrees` when cloud sync is off, so cloud-shadow drift can still be steered independently during tuning.
- `Shadow Speed Gain` currently maps to `CloudShadowOverlay.speed_gain`, so it is the main sandbox knob for scaling cloud-shadow movement on top of the shared wind.
- `Shadow Darkness` currently maps to `CloudShadowOverlay.shadow_strength`, so it is the main sandbox knob for how strongly the multiply shadow pass darkens the ground.
- `Rain Enabled` currently toggles the rain overlay and ground impacts together through their shared `enabled` state.

## Sandbox Responsibilities

`test_weather` is intentionally doing more than only showing a background:

- It rebuilds `Water`, `BackdropTerrain`, and `Ground` from the shared terrain tileset.
- It keeps `GroundImpacts` tied to the painted `Ground` tilemap.
- It registers its weather hosts with `WeatherManager` at runtime instead of embedding reusable weather nodes directly in the scene file.
- It includes a player and NPCs so weather readability can be judged around moving silhouettes and nearby speech balloons.
- It seeds `AppState` in `_enter_tree()` before the resident NPC controllers initialize so the readability actors do not pollute weather validation with startup `add_child()` errors.
- It keeps temporary `ForegroundOccluders` proxy geometry for fast shelter/occlusion checks.
- It keeps a focused weather control panel so frequent tuning does not require Inspector edits.

Do not let `test_weather` become the default place to test unrelated NPC, journal, or progression features.

## Known Constraints And Pitfalls

- In a `CanvasLayer`, the rain and fog overlays should stay anchored to the viewport instead of shifting when the player or camera moves.
- `CloudShadowOverlay` is intentionally not a `CanvasLayer` pass. It needs world-space sampling so the shadows stay attached to the ground when the camera moves.
- If cloud shadows seem to disappear, check both the multiply shader defaults and the registered `coverage` / `shadow_strength` values before assuming the node is missing.
- In tool mode, the overlays should not keep rewriting saved scene transforms. Their runtime anchoring is intentional, but the scene file should stay stable when opened in the editor.
- Outside a `CanvasLayer`, `RainOverlay` still depends on the active `Camera2D` for coverage sizing.
- Tunnel suppression for gameplay weather is currently scene-owned in `game_main.gd`, not built into the reusable overlay nodes themselves.
- Weather tuning is sensitive to viewport size and zoom. If rain looks sparse or fog looks wrong, check camera and overlay coverage before changing effect numbers.
- The fog shader is embedded in [`../../weather/fog_overlay.tscn`](../../weather/fog_overlay.tscn). If a change seems to have no effect, confirm you edited the shader subresource and not only the script.
- If fog appears static, inspect `drift_offset` updates in [`../../weather/fog_overlay.gd`](../../weather/fog_overlay.gd) before retuning the shader again.
- If ground impacts disappear, confirm that `Ground` is painted and that the sandbox or gameplay scene is still registering the correct `spawn_layer`.
- `ForegroundOccluders` are still temporary proxies. They are not a long-term world-authoring solution.
- Thunder is still scene-local. If thunder needs to become reusable, move it deliberately and document the new ownership split.
- The overworld cycle is random and manager-owned. It is not currently saved, seeded from story state, or coordinated with BGM.

## Extension Workflow

When adding a new weather feature, follow this order:

1. Decide whether the feature is reusable rendering or scene-specific validation.
2. Put reusable rendering helpers in `weather/`.
3. Instantiate and validate the feature in [`../../weather/tests/test_weather.tscn`](../../weather/tests/test_weather.tscn).
4. Add weather-panel controls only for knobs that are likely to be tuned repeatedly.
5. Keep gameplay/weather-state decisions out of `AppState` unless a broader authored weather system is actually being introduced.
6. Update this doc, [`../module_map.md`](../module_map.md), and [`../../README.md`](../../README.md) when the feature changes weather ownership or validation workflow.

## Good Next Extensions

These are reasonable follow-on features for the current design:

- shelter and roof masking for rain/fog
- authored foreground shelter geometry to replace proxy occluders
- reusable thunder node if lightning needs to be used outside the sandbox
- additional fog controls such as tint, band scale, or turbulence
- authored weather preset resources or inspector-driven preset authoring if the random overworld cycle needs designer-facing tuning
- authored routing rules for the overworld cycle, such as district-specific preset weights or time-of-day bias

## Validation

- Run [`../../scenes/game_main.tscn`](../../scenes/game_main.tscn) or the full app flow when you need to confirm that the shared weather layers read correctly over the real island terrain and resident silhouettes.
- Let the overworld run long enough to confirm at least one random preset transition occurs without sudden popping, stray dry-weather ground impacts, or obviously mismatched fog/rain wind direction.
- Run [`../../weather/tests/test_weather.tscn`](../../weather/tests/test_weather.tscn) for focused weather tuning.
- Use the in-scene weather control panel to toggle rain, fog, or thunder on or off, trigger thunder manually, and tune the main shared parameters while the scene is running.
- Adjust the shared weather nodes in the inspector only when a change needs a deeper structural retune than the panel exposes.
- Walk the player around the pier and approach residents to confirm weather still reads cleanly around actors and nearby `...` talk cues.
- Check these things before considering a weather tweak complete:
  - rain coverage still feels screen-wide at the current camera zoom
  - fog reads across the whole screen for the isometric camera instead of collapsing into a local band
  - cloud shadows drift slowly across the ground instead of appearing screen-stuck
  - cloud shadows stay below actors and do not darken the HUD
  - fog drift still follows the shared wind direction
  - stronger wind clearly speeds the fog up instead of leaving it nearly static
  - the layered fog pass still reads like drifting mist and haze instead of a flat alpha wash
  - optional thunder flashes still keep the world and rain visually coherent instead of flashing only one layer
  - thunder still reads as a quick flash of light instead of a long ambient wash
  - ground impacts stay lightweight and readable without turning the lower half of the frame into visual noise
  - player and resident silhouettes remain legible under both rain and foreground occluders
  - the overlay stays visually separate from unrelated resident or UI validation

## Current Exceptions

- [`../../weather/tests/test_weather.tscn`](../../weather/tests/test_weather.tscn) is mostly tilemap-backed now.
- The remaining non-tilemap content in that sandbox is the temporary `ForegroundOccluders` proxy layer made from `Line2D` and `Polygon2D` nodes.
- Replace those proxies with authored tilemap or scene content only when weather tuning actually needs more realistic shelter geometry.

## Out Of Scope

- A full authored forecast schedule, story-driven weather progression, save-persistent weather state, or thunder integration in gameplay.
- Audio mixing, puddles, looping storm audio, volumetric world fog, wet-surface shaders, or gameplay rules that depend on weather state.
