# Low-Poly 3D Overworld Replacement Plan

This plan records the **hard-cutover** path for the runtime-direction decision described in
[`implementation_plan.md`](implementation_plan.md) and
[`../features/low_poly_3d_integration.md`](../features/low_poly_3d_integration.md): the low-poly 3D
lane replaces the 2D overworld outright. When this plan lands, `scenes/game_main.tscn` and its 2D
render stack are deleted, not kept behind a fallback flag.

Read [`../design_brief.md`](../design_brief.md), [`../architecture.md`](../architecture.md), and the
two documents above before executing any phase here. Do not start the cutover phases (D onward)
until every sidecar evidence gate in the implementation plan is green.

## Current Status (2026-07-13)

The 3D overworld is built, validated in-engine (Godot 4.7, Apple M5, Metal Forward+), and playable
through the entire app shell. Per-item status is inline in the phases below; the rollup:

- **Built and validated (green):** 3D world scene (terrain, actor, orthographic camera, sky/fog
  atmosphere); interaction dispatch through the same shared story services (no 3D story fork);
  25 residents spawned from shared `AppState` data, wandering, pausing/facing on talk;
  world-anchored speech balloons; three stylized landmark buildings (Piano Ferry, Trinity Church,
  Bagua Tower) with generated collision; story resume-anchor save/restore; shared BGM and landmark
  cue playback. Headless smoke test
  `test_game_world_3d.tscn` passes (world build, spawn, five landmark anchors, story subjects,
  full resident count, controller/coordinator resident talk dispatch, audio managers, resume anchor +
  fallback, interaction contract). Full-shell run
  exercised title → New Game → traveler setup → 3D overworld with HUD,
  status panel, hints, autosave, resident dialogue with real story progression, and journal gating,
  all with 0 errors / 0 warnings.
- **Visual and diagnostic performance acceptance green:** all five fixed-camera PNGs are captured
  and accepted. With cycling 3D weather active, the reproducible standalone Metal editor-debug
  runner measured 14.963 ms p95, 20.420 ms worst, 92 max draw calls, 231,166 max primitives,
  264.98 MiB video / 140.50 MiB static memory, and a 534.52 ms cold terrain rebuild over 60 seconds
  at 2880×1620 physical pixels. Every numeric budget passes; the earlier 1,222 embedded-editor
  draw-call estimate was not reproduced.
- **Decision made + runtime flipped (2026-07-06):** the runtime-direction decision is recorded as
  **replace the 2D overworld** in `implementation_plan.md`, and `main.gd` now instantiates only
  `game_world_3d.tscn` (toggle and `game_main.tscn` preload removed). The 3D overworld is the runtime;
  the 2D scene has been deleted.
- **Legacy removal complete:** the orphaned 2D character/NPC renderer, physics controllers,
  behavior tree, pixel-route tests, 2D speech balloon, and Universal LPC runtime/editor submodule
  have been removed. The final 2D overworld residuals — legacy landmark/component scenes,
  level/portal helpers, tilemap terrain/water, overlay weather nodes, and their focused tests — are
  also removed. Traveler setup and journal previews render the shared 3D actor/model contract.
- **Open (accepted follow-ups):** tunnel interior geometry (Bi Shan / Long Shan are still marker
  anchors) and the release-export performance repeat.

The runtime flip is complete. Reversibility is provided by source control rather than a second live
overworld path.

## Decision Framing

The implementation plan's "Runtime-direction decision" (evidence stage 6) has three allowed
outcomes: replace the 2D overworld, ship 3D as an optional mode, or stop the experiment. This plan
is the execution record for the **replace** outcome. It does not itself authorize the cutover; it
sequences the work so the decision can be made on evidence and then carried out safely.

The choice is a **hard cutover**: once 3D reaches parity and the decision is recorded, the 2D scene
is removed in the same body of work rather than maintained in parallel. That keeps a single runtime
path and avoids a long-lived dual-render maintenance burden, at the cost of no runtime fallback.
Reversibility is provided by source control (a tagged pre-cutover commit and a feature branch), not
by keeping dead 2D scenes wired into the tree.

## What Gets Replaced Versus Preserved

The render replacement is deliberately narrow: it swaps the *presentation and spatial* layer while
leaving the *story, progression, and data* layer untouched. Keeping that boundary is what makes a
hard cutover feasible.

Replaced (2D render stack, deleted at cutover):

- `scenes/game_main.tscn` / `scenes/game_main.gd` (root `Node2D`, `Camera2D`, `$actors` layer,
  `$terrain`) and its extracted 2D helpers where they assume 2D space
- `terrain/terrain.tscn` / `terrain/terrain.gd` and the TileMap water setup
  (`terrain/water_layer_setup.gd`), replaced by the `LowPolyTerrain3D` pipeline
- `characters/human_body_2d.*`, `characters/resident_npc.*`, the 2D controller stack, its behavior
  tree, and the Universal LPC renderer/addon
- 2D landmark scenes: `architecture/piano_ferry.tscn`, `architecture/trinity_church.tscn`,
  `architecture/bagua_tower/*.tscn`, `architecture/bi_shan_tunnel.tscn`,
  `architecture/long_shan_tunnel.tscn`, and the 2D `architecture/components/*` pieces
  (portals, stairs, doors, walls, windows) once 3D equivalents exist
- `godot_common/scenes/camera_2d_controller.gd` usage in the overworld (submodule code stays, but
  the overworld stops depending on it)
- the 2D weather overlays (fog, rain, cloud-shadow, ground-impact) as authored for canvas/`Node2D`
  space, replaced by 3D-space weather passes
- 2D in-world UI placement and `common/gui/speech_balloon.tscn`, replaced by the dedicated
  camera-facing `SpeechBalloon3D`

Preserved (dimension-neutral, must not be forked):

- `game/app_state.gd` and every story/progression service it composes
- `game/story_event_service.gd`, `game/story_event_catalog.gd`, `game/story_route_graph.gd`,
  `game/storylines/**`, and the typed storyline resources
- all resident definition `.tres` data under `game/residents/definitions/` and the resident catalog
  loader
- `game/melody_catalog.gd`, save/resume (`game/story_save_service.gd`), journal, BGM, and
  landmark-cue audio
- the whole `ui/` shell, HUD, and overlay layer, which already reads shared state rather than the
  world scene directly
- the **stable subject-id interaction contract**. `StorySubjectArea2D` is a `LevelArea2D`; the 3D
  world needs an `Area3D`-based equivalent that emits the *same* subject ids into the *same*
  `StoryEventService` dispatch, per the interaction contract in
  [`../features/low_poly_3d_integration.md`](../features/low_poly_3d_integration.md). No 3D-only
  story, save, resident, or route fork is permitted.

## Existing 3D Foundation This Plan Builds On

The sidecar already ships most spatial primitives, so the cutover is mostly integration, not
greenfield rendering work:

- terrain: `LowPolyTerrain3D` + `LowPolyTerrainSampler` + `LowPolyTerrainMeshBuilder` +
  `LowPolyTerrainCell`, shader-displaced water, `LowPolyWaterWindAdapter`
- style/coords: `LowPolyArtStyle3D` (+ `low_poly_postcard_diorama_style.tres`),
  `LowPolyWorldCoordinates3D`
- actor/control: `HumanBody3D`, `BaseController3D`, `PlayerController3D`, `Camera3DController`
- landmarks: the Low-Poly Building Editor and versioned `BuildingSpec` pipeline,
  with authored runtime scenes for Bagua Tower, Piano Ferry, and Trinity Church
- review scenes: `scenes/tests/test_game_world_3d.tscn`, `test_building_tour_3d.tscn`,
  `characters/tests/test_character_collisions.tscn`, `test_low_poly_terrain_3d.tscn`,
  `test_camera_3d_occlusion.tscn`

Gaps the cutover must close: multi-level/tunnel interiors and entrances in 3D, routed
tunnel-resident visibility, representative landmark result equality, formal
visual/performance acceptance, and a recorded runtime-direction decision.

## Preconditions: Sidecar Evidence Gates (must be green first)

The replacement does not begin until the six sidecar stages in `implementation_plan.md` are
satisfied. Phases A–C below are those stages restated as this plan's entry criteria; do not proceed
to Phase D until all are recorded green.

- **A. Correctness baseline.** All headless smoke scenes (actor, collision, terrain/water, camera
  occlusion, building tour, production world) return process status `0`.
  *Status: green.* `scenes/tests/test_game_world_3d.tscn` passes (`PASS: game_world_3d smoke test`,
  exit 0), validating world build, terrain, player spawn, five landmark anchors, resident spawning,
  registered story subjects, and a resident talk dispatch through the shared story services.
- **B. One-landmark interaction slice.** Piano Ferry slice proves approach, deterministic prompt
  selection, one subject dispatch through existing story services, camera-occluder fade, readable
  scale, and one documented resume anchor — without touching `game_main.tscn`.
  *Status: green runtime baseline; landmark follow-up open.* The runtime-world smoke exercises
  controller/coordinator resident dispatch, compares equivalent fresh 2D/3D resident result/state
  parity, and proves semantic resume fallback. Landmark result parity remains a Phase F gate.
- **C. Visual + performance acceptance.** Fixed-camera evidence under `design/qa/low_poly_3d/` and a
  `performance.md` meeting the plan's frame-time, draw-call, triangle, memory, and rebuild budgets.
  *Status: visual green; performance diagnostic green, release repeat open.*
  `design/qa/low_poly_3d/acceptance.md` records the 2026-07-06 fixed-camera visual acceptance
  (nonblank coherent frames, readable actors,
  recognizable landmark approach, legible water/seabed, smoke test green, full-shell integration).
  `design/qa/low_poly_3d/performance.md` records the reproducible 60-second standalone Metal
  editor-debug capture and raw JSON. With cycling 3D weather active, every numeric budget passes at
  2880×1620 physical pixels, including 92 max draw calls and a 534.52 ms cold rebuild. Remaining:
  repeat the runner through a
  release export. No speculative mesh merge is justified by the measured draw-call count.

If any gate fails, the cutover stalls at that gate. This plan's later phases assume all three hold.

## Cutover Phases

### Phase D — Build the 3D runtime world scene

Status: **production, engine-validated.** `scenes/game_world_3d.tscn` and
`scenes/game_world_3d.gd` boot standalone and through the full shell. The scene owns terrain,
`HumanBody3D` in the `player` group, `PlayerController3D`, orthographic `Camera3D` plus
`Camera3DController`, lighting, and five landmark anchors. It adds `AppState` resolution through
`AppRuntime`, landmark/resident sync, nearest-landmark location sync, semantic resume placement,
shared audio, resident spawning, story-subject dispatch, and 3D weather. `main.gd` instantiates it
directly. Focused subsystem tests plus `scenes/tests/test_game_world_3d.tscn` now own the regressions
previously kept in the retired combined prototype fixture.

Create `scenes/game_world_3d.tscn` / `scenes/game_world_3d.gd` as the 3D counterpart of
`game_main`. It owns the same integration responsibilities `game_main.gd` owns today — actor spawn
and camera context, landmark lookup and location syncing, resident spawning, tunnel context, weather
host registration, BGM context, and feeding world context into `AppState` — but expressed with 3D
nodes (`Node3D` root, `Camera3D` via `Camera3DController`, `LowPolyTerrain3D`, `HumanBody3D`).

Keep `game_main.gd`'s proven structure: reuse the extracted helpers (`route_resolver.gd`,
`resident_spawner.gd`, `tunnel_context.gd`, `npc_route_debug_drawer.gd`) by generalizing their
coordinate assumptions through `LowPolyWorldCoordinates3D` rather than rewriting their logic. Where a
helper is irreducibly 2D, add a 3D sibling next to it instead of branching inside it.

At the end of Phase D the 3D world scene boots standalone (its own test entry), places the player on
generated terrain, and syncs location to `AppState` — but is not yet wired into `main.tscn`.

### Phase E — Port each world subsystem to parity

Port subsystems one at a time against the per-subsystem table below, each with its own focused test
scene under `scenes/tests/` and a green headless run before the next begins:

1. **Terrain + water** — replace TileMap island with `LowPolyTerrain3D`, including collision and
   surface-height queries the actor and placement code consume.
2. **Actor + camera** — `HumanBody3D` + `PlayerController3D` + `Camera3DController` as the runtime
   player, using the existing input map.
3. **Five canonical landmarks** — author Piano Ferry, Trinity Church, Bi Shan Tunnel, Long Shan
   Tunnel, and Bagua Tower as low-poly buildings via the Building Editor / `BuildingSpec` pipeline,
   placed through `LowPolyWorldCoordinates3D`. The five landmarks stay canonical and in the same
   roles ([`../design_brief.md`](../design_brief.md)); this is a render change, not a content change.
   *Status: three stylized landmarks wired in.* `game_world_3d.tscn` now instances the existing
   authored stylized scenes for Piano Ferry (`architecture/piano_ferry/piano_ferry_stylized_3d.tscn`),
   Trinity Church (`architecture/trinity_church/trinity_church_stylized_3d.tscn`), and Bagua Tower
   (`architecture/bagua_tower/bagua_tower_stylized_3d.tscn`) in place of their proxy silhouettes,
   keeping node names, runtime placement, and interaction subjects. Bi Shan and Long Shan tunnels
   remain plain marker anchors because no stylized tunnel scenes exist yet.
   Still needs in-editor scale/orientation/collision checks against the diorama and, eventually,
   stylized tunnel entrances.
4. **Multi-level + tunnels + portals** — port `LevelNode2D`/`LevelArea2D`/`LevelRegistry`,
   `components/portal`, and stairs to 3D interiors, preserving `level_id` semantics and tunnel
   masking/visibility behavior.
   *Status: deferred — this is authoring, not a script port.* The 2D `Portal`/`LevelArea2D` system is
   a z-layer visibility trick that fakes vertical overlap in 2D; the whole `LevelRegistry` masking
   machinery exists only because 2D cannot represent real stacked space. In true 3D the tunnels
   become actual walkable geometry with collision, so most of that machinery dissolves rather than
   ports. The remaining real work is modelling the five tunnel/interior spaces as low-poly meshes
   (via the Building Editor) and placing their entrances — an in-editor content task that needs
   engine iteration, tracked as the largest open Phase E item.
5. **Interaction subjects** — add an `Area3D`-based `StorySubject3D` that exposes the same stable
   `subject_id` set as `StorySubjectArea2D` and dispatches through `StoryEventService`. Removing or
   restyling a building must not change subject ids.
   *Status: complete for the authored production catalog.* `game/story_subject_3d.gd` preserves
   the subject-id/action/display/presence contract on `Area3D`.
   `StoryInteractionCoordinator`, composed by `game_world_3d.gd`, owns deterministic world-local
   proximity selection, hint text, and inspect dispatch
   via `PlayerController3D.inspect_requested`, calling the same `AppState.activate_story_subject(...)`
   path as the shared story services. All 15 landmark subjects and all 5 inspectable subjects are
   authored under their production landmark proxies. The runtime smoke asserts the exact id set,
   exercises resident selection and dispatch through the controller/coordinator path, and validates the
   dimension-neutral subject result contract.
6. **Residents** — a resident factory that renders existing `ResidentDefinition` data with
   `HumanBody3D`; identity, dialogue, routine, and story gates stay in the shared definitions.
   *Status: first pass engine-validated.* `characters/resident_factory.gd`
   spawns one `HumanBody3D` per resident from the same `AppState` resident APIs the 2D
   `ResidentSpawner` uses, placed at its landmark anchor (tunnel entry/portal anchors cluster at
   their tunnel proxy until 3D interiors exist). Each resident carries an `npc:<id>` `StorySubject3D`
   so talking routes through the same `activate_story_subject(...)` path; the returned dialogue line
   surfaces via save-status until speech balloons are anchored (item 8).
   `characters/control/resident_controller_3d.gd` (a `BaseController3D`) now gives each resident a
   calm local wander around its spawn anchor (stroll to a random nearby point, pause, repeat) with a
   stuck-timeout, gravity-grounded and wall-sliding via `HumanBody3D` + world colliders. Talking to a
   resident turns it to face the player and holds it still briefly (via `ResidentController3D.pause_for`),
   matching the 2D reveal-dialogue behaviour. The smoke test asserts that the spawned count matches
   the complete shared resident roster. Still needed: authored 3D routes (vs. free wander), tunnel
   visibility and per-resident model customization. Player body-frame/presentation profiles now map
   to the male/female/boy GLB scenes through whole-model swaps.
7. **Weather + atmosphere** — re-target fog/rain/cloud-shadow/ground-impact passes to 3D space and
   register the 3D world as the weather host with `WeatherManager`.
   *Status: first pass shipped and engine-validated.* `game_world_3d.tscn` has a
   `WorldEnvironment` plus `WeatherRig3D`, registered as the manager's generic state target. The
   shared cycle now drives player-following 3D rain particles, environment fog, moving cloud-cover
   sun modulation, and water wind through `LowPolyWaterWindAdapter`. The runtime smoke verifies
   registration, cycling, steady-rain emission, and wind propagation; the graphical steady-rain
   capture records the tuned first-pass presentation.
8. **Speech balloons + world UI** — anchor `speech_balloon` content to 3D actor positions.
   *Status: first pass engine-validated.* `common/gui/speech_balloon_3d.gd` is a
   billboarded `Label3D` that floats above a resident and auto-hides; the factory attaches one to
   each resident and `game_world_3d` shows the story-returned dialogue line there (and in
   save-status). The atlas-based 2D balloon styling is intentionally not reproduced.
9. **BGM + landmark cues** — reuse the dimension-neutral BGM catalog/manager and cue assets.
   *Status: engine-validated baseline.* `game_world_3d` creates the shared `BgmManager`, forwards
   melody-prompt ducking, listens for shared landmark-cue requests, applies prompt volume, and ducks
   BGM while a cue plays. The runtime smoke asserts both audio owners are present.

### Phase F — Story / resident / save ownership parity

Prove in the full 3D world (not just the slice) that: subject dispatch produces identical story
outcomes to the 2D path for the canonical landmark beats; residents apply the same dialogue/trust
progression; and save/continue restores through stable semantic resume anchors, with entry-anchor
fallback when a requested anchor is missing. The 2D save must remain loadable through the cutover;
any prototype-only state needs a versioned migration, never a schema fork.

*Status: resume anchor, controller/coordinator resident dispatch, resident result parity, and the exact
production landmark/inspectable subject set proven.*
`game_world_3d` updates the shared story
resume checkpoint (`AppState.set_story_resume_checkpoint`) to the last landmark the player reaches in
Story mode, and applies it on entry with a Piano Ferry fallback — the same stable landmark-name
anchors the story/save layer uses. `test_game_world_3d.tscn` asserts the resume anchor places the player
at the requested landmark and falls back to Piano Ferry for a missing anchor, alongside the existing
resident-talk dispatch check through the shared `AppState.activate_story_subject` path. It also
asserts the interaction contract: every landmark subject the adapter can resolve builds a well-formed
request (matching `subject_id`, resolved action, and dimension-neutral spatial context) and proximity
selection deterministically resolves an active subject. The smoke
now drives a resident interaction through `PlayerController3D.inspect_requested` and the interaction
coordinator and verifies all 15 landmark plus 5 inspectable production subject ids and cross-world
isolation.

### Phase G — Record the decision and execute the cutover

1. Record the explicit "replace the 2D overworld" outcome in `implementation_plan.md`, linking the
   green validation commands, visual evidence, performance report, interaction contract, and this
   plan.
2. Tag a pre-cutover commit and work the cutover on a dedicated branch (source-control rollback).
3. Repoint `main.gd` / `main.tscn` to instantiate `scenes/game_world_3d.tscn` instead of
   `scenes/game_main.tscn`.
   *Status: reversible toggle in place (not flipped).* `main.gd` now holds both `GAME_SCENE_2D` and
   `GAME_SCENE_3D` and selects between them with the `USE_3D_OVERWORLD` constant (default `false`, so
   the shipped runtime is unchanged). Setting it `true` runs the 3D overworld through the full app
   shell (title, HUD, journal, pause, save/continue) without deleting the 2D stack — the intended way
   to validate the whole flow before the final decision. The hard flip + 2D deletion stays gated on
   the runtime-direction decision below.
   *Full-shell validation passed (in-editor, Godot 4.7):* title → New Game → traveler setup → 3D
   overworld all worked; the HUD (pinned lead, status panel, contextual hints), autosave feedback,
   resident talk with real story progression (task advanced, next-beat hint surfaced), journal
   unlock-gating, and location sync all composed correctly over the 3D viewport with no integration
   errors.
   *Flip executed 2026-07-06.* `main.gd` now holds a single `GAME_SCENE` = `game_world_3d.tscn` and
   instantiates it directly; the `USE_3D_OVERWORLD` toggle and the `GAME_SCENE_2D`/`game_main.tscn`
   preload are removed. The 3D overworld is the runtime overworld, and the retired 2D scene has been
   deleted.
4. Delete the 2D character/NPC render stack, physics controllers, behavior tree, 2D speech balloon,
   legacy landmark/components and level/portal helpers, tilemap terrain/water, overlay weather stack,
   obsolete 2D-only tests, and Universal LPC submodule; remove dead references.
   *Completed 2026-07-13.* The dimension-neutral resident/story/save layer remains intact, and UI
   previews use `CharacterPreview3D` plus the shared model catalog.
5. Run focused actor, collision, resident, UI, weather, production-world, and main-flow validation;
   confirm no scene or resource references dangle. *Completed with the verified removal pass.*

### Phase H — Documentation and cleanup

Update every affected canonical doc in the same body of work (this is required by `AGENTS.md`):
`architecture.md`, `module_map.md`, `design_brief.md` (render direction), `core_game_workflow.md`,
the terrain/actor/weather/landmark feature docs, and `implementation_plan.md`. Fold the now-obsolete
low-poly *sidecar* framing into a shipped-runtime description, and retire language that treats 3D as
a parallel exploration lane.

## Per-Subsystem Replacement Map

| 2D system (delete) | 3D replacement (build on) | Notes |
|---|---|---|
| `scenes/game_main.tscn/.gd` | `scenes/game_world_3d.tscn/.gd` | Same integration duties, 3D nodes |
| `terrain/terrain.tscn/.gd`, `water_layer_setup.gd` | `LowPolyTerrain3D` pipeline + water shader | Collision + surface-height queries required |
| `characters/human_body_2d.*` | `HumanBody3D` | Input map unchanged |
| `characters/control/*` (2D) | `BaseController3D` / `PlayerController3D` | XZ-plane movement |
| `godot_common` `Camera2DController` (usage) | `Camera3DController` | Orbit/zoom/occluder fade |
| `characters/resident_npc.*` | Resident factory | Driven by existing `.tres` definitions |
| `architecture/*.tscn` (2D landmarks + components) | Building Editor / `BuildingSpec` low-poly builds | Five canonical landmarks, same roles |
| `LevelNode2D`/`LevelArea2D`/`portal`/stairs | 3D level + portal + stair components | Preserve `level_id` + tunnel masking |
| `StorySubjectArea2D` | `StorySubject3D` (`Area3D`) | Same `subject_id` → same `StoryEventService` |
| 2D weather overlays | 3D-space weather passes | Re-register host with `WeatherManager` |
| 2D speech-balloon anchoring | `SpeechBalloon3D` | Dedicated camera-facing 3D label |

## Validation Strategy

Each phase ships with a focused headless scene under `scenes/tests/` that logs a `PASS` line and
returns process status `0` on success, nonzero on assertion failure (a logged `PASS` alone is
insufficient). The first such scene, `scenes/tests/test_game_world_3d.tscn`, boots the runtime world
and asserts terrain generation, player spawn, five landmark proxies, resident spawning, registered
story subjects, and a resident talk dispatch through `AppState.activate_story_subject`. Run it with:
`"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --scene res://scenes/tests/test_game_world_3d.tscn`. Keep the existing story/resident/route/autosave regressions green throughout — they
exercise the preserved layer and are the guard that the render swap did not leak into gameplay
rules. The final gate is the standard full main-flow validation after `main.tscn` is repointed.

## Risks and Mitigations

- **No runtime fallback (hard cutover).** Mitigate with a tagged pre-cutover commit and a dedicated
  branch; the cutover is one reviewable, revertible change set.
- **Hidden 2D coupling in "dimension-neutral" code.** `game_main.gd` is ~1000 lines and touches many
  systems; audit for `Vector2`, `Node2D`, and pixel-space assumptions before deleting, and route all
  placement through `LowPolyWorldCoordinates3D`.
- **Subject-id / save drift.** The single largest correctness risk. Treat the subject-id set and the
  resume-anchor ids as a frozen contract; add coverage asserting 3D dispatch and 2D dispatch resolve
  the same story outcomes before deleting the 2D path.
- **Performance regressions at full island scale.** The slice-level performance budget may not hold
  for the full five-landmark world; re-measure against the same budgets after Phase F, and record any
  approved tradeoff explicitly.
- **Landmark authoring cost.** Five production-quality low-poly landmarks is the largest content
  effort; sequence Piano Ferry (already default slice) first and reuse the `BuildingSpec` pipeline.

## Open Decisions

- Resident visual identity beyond the current shared male GLB; player customization is resolved as
  whole-model male/female/boy swaps from the shared profile's body-frame/presentation values.
- Whether coarse street/building-footprint terrain sampling is the intended final style or needs
  cleaner extraction.
- Whether any optional character clips beyond `idle`/`walk`/`run` are validated and mapped before
  cutover, or deferred to post-cutover polish.

## Update This Doc When

- an evidence gate flips from open to green, or the runtime-direction decision is recorded
- a subsystem port lands (move it from "to build" to "shipped" and update the replacement map)
- the cutover executes (then fold this plan's durable parts into `implementation_plan.md` per the
  merge rule in [`README.md`](README.md), and delete this file if it becomes redundant)
