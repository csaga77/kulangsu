# Low-Poly 3D Overworld — Performance Record

Tracks the performance-acceptance gate (stage 4) of
[`../../../docs/plan/low_poly_3d_replacement.md`](../../../docs/plan/low_poly_3d_replacement.md).

## Environment (2026-07-06)

- Engine: Godot 4.7.stable.official (5b4e0cb0f)
- Renderer: Metal 4.0, Forward+
- GPU / hardware: Apple M5 (Apple9)
- Scene: `scenes/game_world_3d.tscn` (five landmark anchors, three stylized building instances with
  generated trimesh collision, 25 wandering residents), terrain 512×512 source → 128×128 sampled
  cells (7914 land, 1448 street, 336 building, 8470 water, 8956 water render)
- Build type: **editor debug run** (not a release export)
- Run window resolution: 2880×1620 (editor embedded game view)

## Measured (in-editor debug overlay, 2026-07-06)

Read from the `show_debug_stats` overlay in `game_world_3d` (on-screen `Performance` monitors),
steady state with 25 residents wandering, camera following. Editor debug run at 2880×1620.

| Metric | Target (release @1920×1080) | Measured (editor debug @2880×1620) | Verdict |
|---|---|---|---|
| Frame rate / frame time | ≤ 16.7 ms p95 | ~95–98 FPS (~10.3–10.5 ms) | within target |
| visible draw calls | ≤ 500 | **~1,222** | **over budget** |
| visible primitives | ≤ 750,000 tris | ~432,000 | within target |
| objects drawn | — | ~1,406 | — |
| video memory | < 1 GiB | 272 MiB | within target |
| static (CPU) memory | < 1 GiB | 157 MiB | within target |
| cold terrain rebuild | < 3 s | no perceptible stall in `_ready` | within target |

Notes:
- Frame rate is comfortable even at a resolution well above the 1920×1080 target, so frame time is
  not the concern; the render is geometry-bound, not fill-bound.
- The `TIME_PROCESS` monitor read ~16.7 ms, which exceeds the observed frame time — likely editor/
  debug-server overhead. Trust the FPS reading for frame cadence; confirm on a release build.

## Draw-call finding and mitigations

~1,222 draw calls exceeds the ≤500 budget. Draw calls are geometry-count driven (not resolution), so
this holds at 1920×1080 too. Main contributors and options, in rough priority:

1. **25 residents**, each an individual `HumanBody3D` GLB with several surfaces. Batch them with a
   `MultiMeshInstance3D` (or shared material/mesh) — the single biggest reduction.
2. **336 building-footprint meshes + street cells** in the terrain. Merge terrain sub-meshes per
   material into fewer surfaces.
3. **Per-mesh landmark trimesh collision** (~300 static bodies) adds objects; collision does not draw
   but the stylized building meshes themselves are many surfaces — consider merging building meshes.

Re-measure on a **release export at 1920×1080** after applying (1) to confirm the budget is met.

## Next step

Export a release build (or run with `--profile`/the debugger Monitors), capture the metrics above at
1920×1080, and record them here. The largest expected cost is the per-mesh trimesh collision on the
stylized buildings (~300 concave shapes); if draw calls or triangles exceed budget, switch those to a
single simplified collider per building (`generate_landmark_collision` already gates the current path).
