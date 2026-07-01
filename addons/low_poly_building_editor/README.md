# Low-Poly Building Editor

Godot editor plugin for grid-snapped low-poly building authoring — an editor dock plus 3D
viewport tools for walls, floors, stairs, pillars, roofs, openings, and props, authored as
normal scene nodes so the result serializes into `.tscn` files. The Wall tool can draw
either individual spans or enclosed rooms with a configurable side count of at least
three; four sides preserves rectangular-room creation. The Floor tool's Rectangle and
Polygon styles choose only how a new footprint is drawn: two opposite corners or a
multi-click outline. Both use the same grid-snapped editing gestures afterward. Any
vertex can be dragged, any edge can move both adjacent vertices, and vertices can be
inserted with Shift-click on an edge or removed with Option/Alt-click. Hole uses the
same Rectangle/Polygon creation choice and the same outline-editing gestures.
Flat roofs follow the same pattern: Rectangle and Polygon change only creation, then
both expose shared vertex, edge, insertion, removal, and body-drag editing. Other roof
styles retain their rectangular footprints. Floor slabs and polygon Flat roofs share
the same polygon-prism topology builder, so generated top, underside, and boundary
faces follow one outline; Flat-roof overhang preserves one render corner per authored
corner, including acute footprints.

`Building3D` is the scene-owned assembly root and carries no editor-tool configuration;
the editor dock owns temporary tool defaults. `BuildingFactory` creates and names
building blocks, while transient wall and roof geometry resolvers perform intersection,
overlap, opening-propagation, and clipping calculations.

The dock's global **Debug Display** controls draw one shared, transient wireframe across
walls, floors, stairs, pillars, roofs, openings, and placed props. Edges are deduplicated,
depth-tested by default, and can optionally use X-ray mode. Display changes replace only
the overlay; they never rebuild authored mesh or collision geometry. New
`BuildingMesh3D` subclasses inherit this behavior automatically.

A scene can contain multiple independent `Building3D` roots or packed building scene
instances. **Add Building** creates and selects a new root; selecting any building root
or one of its authored descendants makes that building the target for subsequent tool
operations. Geometry merging and clipping never cross between building roots.

Styled blocks use typed hierarchies. Their base classes own only universal state and
low-level generation infrastructure; optional intermediate layers own properties shared
by a genuine subset; and concrete pillar, roof, window, and door styles own their style
identity, style controls, and geometry. See the normative future-block pattern in
[`docs/contract.md`](docs/contract.md#building-block-style-pattern).

Serialized generated meshes are validated caches. Walls, floors, stairs, pillars, and
roofs share `BuildingMesh3D` cache signatures; windows and doors cache their generated
part meshes. Loading reuses matching geometry while recreating unsaved collision/debug
children, and authored or clipping changes invalidate only the affected cache.

## Seeded Building Generation

The plugin also provides a deterministic JSON-to-scene path for AI agents and batch
authoring. [`building_spec.gd`](building_spec.gd) parses and validates the versioned
input, [`building_spec_compiler.gd`](building_spec_compiler.gd) builds ordinary
`Building3D` nodes through `BuildingFactory`, and
[`generate_building.gd`](generate_building.gd) saves the result as an editable `.tscn`.

Generate the included example:

```sh
godot --headless --path . \
  --script addons/low_poly_building_editor/generate_building.gd -- \
  --spec res://addons/low_poly_building_editor/examples/seeded_villa.json \
  --output res://generated/buildings/seeded_villa.tscn \
  --report res://generated/buildings/seeded_villa.report.json
```

Generator version 1 supports one rectangular storey, one required entrance, repeated
validated facade windows, optional porch pillars, footprint jitter, and one flat, shed,
gable, hip, or dome roof. A style value of `random` resolves deterministically from `seed`.
The command prints the same machine-readable report it optionally writes to `--report`.
Invalid specs and buildings that cannot fit their entrance do not produce a scene.

### Visual Variant Batches

[`generate_variants.gd`](generate_variants.gd) expands one base spec across consecutive
seeds, saves every editable scene and isometric thumbnail, and writes a manifest plus a
contact sheet for AI or human ranking:

```sh
godot --path . --audio-driver Dummy \
  --script addons/low_poly_building_editor/generate_variants.gd -- \
  --spec res://addons/low_poly_building_editor/examples/seeded_villa.json \
  --output-dir res://generated/buildings/villa_variants \
  --count 12
```

Thumbnail generation requires a graphical rendering driver, so this command intentionally
does not use `--headless` (Godot's macOS headless display exposes only the dummy renderer).
Automation may launch a tiny off-screen window with Godot's `--resolution` and `--position`
options. Each manifest entry maps a seed and resolved parameters to its `.tscn` and `.png`;
`contact_sheet.png` preserves manifest order.

Run [`tests/test_building_variants_gallery_3d.tscn`](tests/test_building_variants_gallery_3d.tscn)
to inspect the included 12-seed example as a live 4×3 scene. `N` and `P` compile adjacent
seed batches, `R` restores seeds 18432–18443, and the mouse wheel adjusts the orthographic
camera. Each generated root retains its resolved generator values as metadata for runtime
inspection.

This README is the plugin's entry point; the full documentation lives in [`docs/`](docs):

- [`docs/feature.md`](docs/feature.md) — goals, authoring experience, rules, edge cases, ownership, and validation.
- [`docs/contract.md`](docs/contract.md) — stable contract and governance for the plugin's nodes, storage, and editor interaction.

The focused smoke scene is
[`tests/test_low_poly_building_editor_3d.tscn`](tests/test_low_poly_building_editor_3d.tscn), the focused
dome smoke scene is [`tests/test_dome_roof_3d.tscn`](tests/test_dome_roof_3d.tscn), and the
interactive generator gallery is
[`tests/test_building_variants_gallery_3d.tscn`](tests/test_building_variants_gallery_3d.tscn). The
project-level [`../../docs/module_map.md`](../../docs/module_map.md),
[`../../docs/architecture.md`](../../docs/architecture.md), and
[`../../docs/contracts.md`](../../docs/contracts.md) keep one-line pointers here.
