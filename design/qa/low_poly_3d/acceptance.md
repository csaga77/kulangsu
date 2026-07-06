# Low-Poly 3D Overworld — Visual Acceptance Note

Tracks the visual-acceptance gate (stage 3) of
[`../../../docs/plan/low_poly_3d_replacement.md`](../../../docs/plan/low_poly_3d_replacement.md).

## 2026-07-06 — In-editor acceptance run (Godot 4.7)

Environment: Godot 4.7.stable.official, Metal 4.0 Forward+, Apple M5 (Apple9),
`scenes/game_world_3d.tscn` via `scenes/tests/test_game_world_3d.tscn` and the full
project flow with `main.gd USE_3D_OVERWORLD = true`.

Observed and accepted:

- **Nonblank, coherent frames.** The low-poly island renders with the street-grid terrain,
  visible coastline/water, and the soft sky-tinted `WorldEnvironment` atmosphere. No black frames,
  no z-fighting, no incoherent overlap.
- **Readable player/resident silhouettes.** Residents (the `male.glb` stylized avatars) read clearly
  from the orthographic camera and are grounded on the terrain.
- **Recognizable landmark approach.** The stylized Trinity Church, Piano Ferry, and Bagua Tower
  buildings render with full detail and are approachable; the player registers as "at" a landmark
  (HUD `Location` updates) and the inspect/talk hint appears near them.
- **Legible water/seabed layering.** The shader-displaced water reads against the shoreline with the
  visible seabed under shallow areas.
- **Smoke test green.** `PASS: game_world_3d smoke test` with 0 errors / 0 warnings, covering world
  build, spawn, five landmark anchors, story subjects, resident talk dispatch, resume anchor, and
  the interaction contract.
- **Full-shell integration.** Title → New Game → traveler setup → 3D overworld; HUD (pinned lead,
  status panel, contextual hints), autosave feedback, resident dialogue with real story progression
  (task advanced, next-beat hint surfaced), journal unlock-gating, and location sync all composed
  correctly over the 3D viewport with no integration errors.

## 2026-07-06 — Fixed-camera evidence

The reproducible `capture_game_world_3d_qa.tscn` runner generated and this review accepted:

- [`world_overview.png`](world_overview.png): nonblank coherent island, coastline, road network,
  three authored landmarks, and distributed residents.
- [`player_scale.png`](player_scale.png): player/resident silhouettes remain readable against a
  landmark and terrain grid.
- [`landmark_approach.png`](landmark_approach.png): Piano Ferry approach, building scale, collision
  edge, residents, and coastline are legible.
- [`camera_occlusion.png`](camera_occlusion.png): Bagua Tower geometry between camera and player is
  visibly faded while the player remains readable.
- [`water_shoreline.png`](water_shoreline.png): water/shoreline/seabed layering remains distinct.

Formal visual sign-off is green. Formal performance sign-off still requires a release-export repeat;
the new standalone Metal editor-debug capture passes every numeric budget and replaces the earlier
embedded-editor draw-call estimate as the current diagnostic baseline.
