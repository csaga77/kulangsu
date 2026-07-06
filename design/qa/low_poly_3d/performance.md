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
| cold terrain rebuild | < 3 s | not instrumented | open |

Notes:
- Frame rate is comfortable even at a resolution well above the 1920×1080 target, so frame time is
  not the concern; the render is geometry-bound, not fill-bound.
- The `TIME_PROCESS` monitor read ~16.7 ms, which exceeds the observed frame time — likely editor/
  debug-server overhead. Trust the FPS reading for frame cadence; confirm on a release build.

## Draw-call finding and mitigations

~1,222 draw calls exceeds the ≤500 budget. Draw calls are geometry-count driven (not resolution), so
this likely remains over budget at 1920×1080. The current attribution is a hypothesis, not a profile:

1. Capture draw calls with residents hidden, then with each authored landmark hidden, to assign the
   cost before changing geometry.
2. The terrain already emits one `MeshInstance3D` per populated material pass; its 336 footprint
   cells and street cells are not 336 separate drawables. Do not schedule a redundant terrain merge.
3. Residents are independently moving, skinned GLB instances. A normal `MultiMeshInstance3D` is not
   a drop-in replacement for independently animated skeletons. First reduce material/surface count,
   use visibility distance/culling, or approve the measured tradeoff.
4. Stylized buildings contain many mesh surfaces. Consolidating static visual surfaces per material
   and replacing per-mesh trimesh collision with simplified authored colliders are the most plausible
   optimization paths after profiling.

Re-measure on a **release export at 1920×1080** after the profiled optimization or after recording an
explicitly approved draw-call exception.

## Next step

Export a release build, run the specified 5-second warm-up plus 60-second capture at 1920×1080, and
record p95 and worst sustained frame time. Instrument a cold terrain rebuild separately. Capture
resident-hidden and per-landmark-hidden samples before selecting a draw-call mitigation. Collision
does not itself add render draw calls, but replacing the current per-mesh concave shapes with
simplified authored colliders remains worthwhile for load time and physics cost.
