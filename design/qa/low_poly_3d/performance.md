# Low-Poly 3D Overworld — Performance Record

Tracks the performance-acceptance gate (stage 4) of
[`../../../docs/plan/low_poly_3d_replacement.md`](../../../docs/plan/low_poly_3d_replacement.md).

## Reproducible standalone capture (2026-07-06)

- Engine: Godot 4.7.stable.official (5b4e0cb0f)
- Renderer: Metal 4.0, Forward+
- GPU / hardware: Apple M5 (Apple9)
- Scene: `scenes/game_world_3d.tscn` (five landmark anchors, three stylized building instances with
  generated trimesh collision, 25 wandering residents), terrain 512×512 source → 128×128 sampled
  cells (7914 land, 1448 street, 336 building, 8470 water, 8956 water render)
- Build type: **standalone editor-debug run** (not a release export)
- Render resolution: **2880×1620 physical pixels** (1440×810 logical Retina viewport), above the
  1920×1080 target pixel count
- Runner: `scenes/tests/capture_game_world_3d_qa.tscn`, 5-second warm-up followed by a measured
  60-second baseline; raw output is [`performance_latest.json`](performance_latest.json)

## Measured

Captured from frame timestamps plus Godot `Performance` monitors with 25 residents wandering.

| Metric | Target (release @1920×1080) | Standalone debug @2880×1620 | Diagnostic verdict |
|---|---|---|---|
| p95 frame time | ≤ 16.7 ms | 12.745 ms | pass |
| worst sustained frame time | ≤ 33.3 ms | 14.557 ms | pass |
| visible draw calls | ≤ 500 | 88.6 average / 91 max | pass |
| visible primitives | ≤ 750,000 | 225,946 average / 226,814 max | pass |
| video memory | < 1 GiB | 264.98 MiB | pass |
| static (CPU) memory | < 1 GiB | 126.71 MiB | pass |
| cold terrain rebuild | < 3 s | 546.0 ms | pass |

## Draw-call attribution

The earlier ~1,222 embedded-editor reading was not reproduced standalone and must not drive
optimization work. Controlled one-second visibility variants measured:

- baseline: ~88.6 calls
- residents hidden: 74 calls (about 15 fewer)
- Bagua Tower hidden: 27 calls (about 62 fewer)
- Piano Ferry hidden: 88 calls
- Trinity Church hidden: 88 calls

This camera position makes Bagua Tower the dominant visible static-surface cost, but total draw calls
are already far below budget. No speculative resident MultiMesh or redundant terrain merge is
justified by this evidence.

## Formal gate

Every numeric budget passes in the standalone editor-debug capture at a physical resolution above
the target. The remaining formality is to create/use a release export preset and repeat the same
runner at 1920×1080 or higher. Until then performance is **diagnostically green, formally open**.
