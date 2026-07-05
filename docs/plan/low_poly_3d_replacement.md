# Low-Poly 3D Overworld Replacement Plan

This plan records the **hard-cutover** path for the runtime-direction decision described in
[`implementation_plan.md`](implementation_plan.md) and
[`../features/low_poly_3d_integration.md`](../features/low_poly_3d_integration.md): the low-poly 3D
lane replaces the 2D overworld outright. When this plan lands, `scenes/game_main.tscn` and its 2D
render stack are deleted, not kept behind a fallback flag.

Read [`../design_brief.md`](../design_brief.md), [`../architecture.md`](../architecture.md), and the
two documents above before executing any phase here. Do not start the cutover phases (D onward)
until every sidecar evidence gate in the implementation plan is green.

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
- `characters/human_body_2d.*`, `characters/resident_npc.*`, and the 2D controller stack
  (`characters/control/player_controller.gd`, `base_controller.gd`, `npc_controller.gd`)
- 2D landmark scenes: `architecture/piano_ferry.tscn`, `architecture/trinity_church.tscn`,
  `architecture/bagua_tower/*.tscn`, `architecture/bi_shan_tunnel.tscn`,
  `architecture/long_shan_tunnel.tscn`, and the 2D `architecture/components/*` pieces
  (portals, stairs, doors, walls, windows) once 3D equivalents exist
- `godot_common/scenes/camera_2d_controller.gd` usage in the overworld (submodule code stays, but
  the overworld stops depending on it)
- the 2D weather overlays (fog, rain, cloud-shadow, ground-impact) as authored for canvas/`Node2D`
  space, replaced by 3D-space weather passes
- 2D in-world UI placement for `common/gui/speech_balloon.tscn` (the balloon content can stay; its
  world anchoring moves to 3D)

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
- landmarks: `LowPolyLandmarkProxy3D` plus the Low-Poly Building Editor and versioned `BuildingSpec`
  pipeline, with authored concepts for Bagua Tower and Piano Ferry
- review scenes: `scenes/tests/test_low_poly_world_3d.tscn`, `test_building_tour_3d.tscn`,
  `characters/tests/test_character_collisions.tscn`, `test_low_poly_terrain_3d.tscn`,
  `test_camera_3d_occlusion.tscn`

Gaps the cutover must close: multi-level/tunnel interiors and portals in 3D, a 3D interaction-subject
node, a 3D resident presenter driven by existing definitions, 3D-space weather, world-anchored
speech balloons, and a 3D runtime world scene that owns the same integration responsibilities
`game_main.gd` owns today.

## Preconditions: Sidecar Evidence Gates (must be green first)

The replacement does not begin until the six sidecar stages in `implementation_plan.md` are
satisfied. Phases A–C below are those stages restated as this plan's entry criteria; do not proceed
to Phase D until all are recorded green.

- **A. Correctness baseline.** All headless smoke scenes (actor, collision, terrain/water, camera
  occlusion, building tour, combined world) return process status `0`.
- **B. One-landmark interaction slice.** Piano Ferry slice proves approach, deterministic prompt
  selection, one subject dispatch through existing story services, camera-occluder fade, readable
  scale, and one documented resume anchor — without touching `game_main.tscn`.
- **C. Visual + performance acceptance.** Fixed-camera evidence under `design/qa/low_poly_3d/` and a
  `performance.md` meeting the plan's frame-time, draw-call, triangle, memory, and rebuild budgets.

If any gate fails, the cutover stalls at that gate. This plan's later phases assume all three hold.

## Cutover Phases

### Phase D — Build the 3D runtime world scene

Status: **scaffolded, not engine-validated.** `scenes/game_world_3d.tscn` and
`scenes/game_world_3d.gd` now exist. The scene mirrors the validated
`scenes/tests/test_low_poly_world_3d.tscn` (terrain, `HumanBody3D` in the `player` group,
`PlayerController3D`, orthographic `Camera3D` + `Camera3DController`, sun, five landmark proxies).
The script reuses that test scene's proven world-config and terrain-elevation-follow logic and adds
the runtime-integration layer: `AppState` resolution via `AppRuntime`, landmark-list/resident-list
sync, nearest-landmark location sync, story resume-anchor placement (Piano Ferry fallback), and the
two methods `main.gd` calls on a game root (`sync_ui_state()`, `set_prompt_bgm_ducked()`). It is a
`Node3D` drop-in for `main.gd`'s `GAME_SCENE` contract but is **not** wired into `main.tscn` yet, so
it changes no existing runtime behavior.

All references were statically checked (ext-resource UIDs, called APIs, base classes) because no
Godot engine is available in the authoring environment. It still needs an in-editor/headless boot,
a dedicated headless smoke scene, and the Phase E subsystem ports before it can host runtime play.

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
   still use `LowPolyLandmarkProxy3D` placeholders because no stylized tunnel scenes exist yet.
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
   *Status: first pass scaffolded (needs engine validation).* `game/story_subject_3d.gd` mirrors
   `StorySubjectArea2D`'s subject-id/action/display/presence contract on `Area3D`.
   `game_world_3d.gd` now owns deterministic proximity selection, hint text, and inspect dispatch
   via `PlayerController3D.inspect_requested`, calling the same `AppState.activate_story_subject(...)`
   path as `game_main`. One subject per landmark is authored in the scene using the exact
   `subject_id`s from the 2D landmark scenes (`landmark:piano_ferry.harbor_refrain`,
   `landmark:trinity_church.steps`, `landmark:bi_shan_tunnel.echo_a`,
   `landmark:long_shan_tunnel.tunnel_entry`, `landmark:bagua_tower.synthesis_chamber`) so dispatch
   is identical. Still needs an in-engine boot, a headless dispatch-equivalence test, and richer
   per-landmark subject coverage.
6. **Residents** — a 3D resident presenter that renders existing `ResidentDefinition` data with
   `HumanBody3D`; identity, dialogue, routine, and story gates stay in the shared definitions.
   *Status: first pass scaffolded (needs engine validation).* `characters/resident_presenter_3d.gd`
   spawns one `HumanBody3D` per resident from the same `AppState` resident APIs the 2D
   `ResidentSpawner` uses, placed at its landmark anchor (tunnel entry/portal anchors cluster at
   their tunnel proxy until 3D interiors exist). Each resident carries an `npc:<id>` `StorySubject3D`
   so talking routes through the same `activate_story_subject(...)` path; the returned dialogue line
   surfaces via save-status until speech balloons are anchored (item 8). Still needs routed NPC
   movement, tunnel visibility, per-resident model customization, and engine validation.
7. **Weather + atmosphere** — re-target fog/rain/cloud-shadow/ground-impact passes to 3D space and
   register the 3D world as the weather host with `WeatherManager`.
   *Status: base atmosphere added; cycled passes pending.* `game_world_3d.tscn` now has a
   `WorldEnvironment` (soft sky background, sky-sourced ambient, filmic tonemap, subtle depth fog)
   and the water already consumes `WeatherManager` wind via `LowPolyWaterWindAdapter`. Still to do:
   3D-space rain/fog/cloud-shadow passes registered through `WeatherManager`, which need in-editor
   visual tuning rather than blind authoring.
8. **Speech balloons + world UI** — anchor `speech_balloon` content to 3D actor positions.
   *Status: first pass scaffolded (needs engine validation).* `common/gui/speech_balloon_3d.gd` is a
   billboarded `Label3D` that floats above a resident and auto-hides; the presenter attaches one to
   each resident and `game_world_3d` shows the story-returned dialogue line there (and in
   save-status). The atlas-based 2D balloon styling is intentionally not reproduced.

### Phase F — Story / resident / save ownership parity

Prove in the full 3D world (not just the slice) that: subject dispatch produces identical story
outcomes to the 2D path for the canonical landmark beats; residents apply the same dialogue/trust
progression; and save/continue restores through stable semantic resume anchors, with entry-anchor
fallback when a requested anchor is missing. The 2D save must remain loadable through the cutover;
any prototype-only state needs a versioned migration, never a schema fork.

### Phase G — Record the decision and execute the cutover

1. Record the explicit "replace the 2D overworld" outcome in `implementation_plan.md`, linking the
   green validation commands, visual evidence, performance report, interaction contract, and this
   plan.
2. Tag a pre-cutover commit and work the cutover on a dedicated branch (source-control rollback).
3. Repoint `main.gd` / `main.tscn` to instantiate `scenes/game_world_3d.tscn` instead of
   `scenes/game_main.tscn`.
4. Delete the 2D render stack listed in "What Gets Replaced," and remove now-dead `preload`/
   `ext_resource` references.
5. Run the full regression suite and the standard main-flow validation; confirm no scene or resource
   references dangle.

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
| `characters/resident_npc.*` | 3D resident presenter | Driven by existing `.tres` definitions |
| `architecture/*.tscn` (2D landmarks + components) | Building Editor / `BuildingSpec` low-poly builds | Five canonical landmarks, same roles |
| `LevelNode2D`/`LevelArea2D`/`portal`/stairs | 3D level + portal + stair components | Preserve `level_id` + tunnel masking |
| `StorySubjectArea2D` | `StorySubject3D` (`Area3D`) | Same `subject_id` → same `StoryEventService` |
| 2D weather overlays | 3D-space weather passes | Re-register host with `WeatherManager` |
| 2D speech-balloon anchoring | 3D-anchored balloons | Balloon content reused |

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

- Character customization in 3D: whole-model swaps versus model-internal material variants (must
  resolve before wiring residents in Phase E, item 6).
- Whether coarse street/building-footprint terrain sampling is the intended final style or needs
  cleaner extraction.
- Whether any optional character clips beyond `idle`/`walk`/`run` are validated and mapped before
  cutover, or deferred to post-cutover polish.

## Update This Doc When

- an evidence gate flips from open to green, or the runtime-direction decision is recorded
- a subsystem port lands (move it from "to build" to "shipped" and update the replacement map)
- the cutover executes (then fold this plan's durable parts into `implementation_plan.md` per the
  merge rule in [`README.md`](README.md), and delete this file if it becomes redundant)
