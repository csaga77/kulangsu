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

## Qualitative result

The scene ran at real-time `1.0×` speed with residents wandering and the camera following, with no
visible stutter or hitching during the acceptance run, and 0 errors / 0 warnings. Terrain cold build
completed within the scene's `_ready` without a perceptible stall.

## Target budget (from the implementation plan) — NOT YET FORMALLY MEASURED

Measure on a **release export at 1920×1080**, after a 5s warm-up over a 60s interaction-slice run:

| Metric | Target | Measured |
|---|---|---|
| p95 frame time | ≤ 16.7 ms | pending |
| worst sustained frame time | ≤ 33.3 ms | pending |
| visible draw calls | ≤ 500 | pending |
| visible triangles | ≤ 750,000 | pending |
| peak process memory | < 1 GiB | pending |
| cold terrain rebuild | < 3 s | pending |

## Next step

Export a release build (or run with `--profile`/the debugger Monitors), capture the metrics above at
1920×1080, and record them here. The largest expected cost is the per-mesh trimesh collision on the
stylized buildings (~300 concave shapes); if draw calls or triangles exceed budget, switch those to a
single simplified collider per building (`generate_landmark_collision` already gates the current path).
