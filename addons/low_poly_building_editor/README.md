# Low-Poly Building Editor

Godot editor plugin for grid-snapped low-poly building authoring — an editor dock plus 3D
viewport tools for walls, floors, stairs, pillars, roofs, openings, and props, authored as
normal scene nodes so the result serializes into `.tscn` files. The Wall tool can draw
either individual spans or enclosed rectangular rooms.

`Building3D` is the scene-owned assembly root and carries no editor-tool configuration;
the editor dock owns temporary tool defaults. `BuildingFactory` creates and names
building blocks, while transient wall and roof geometry resolvers perform intersection,
overlap, opening-propagation, and clipping calculations.

Styled blocks use typed hierarchies. Their base classes own only universal state and
low-level generation infrastructure; optional intermediate layers own properties shared
by a genuine subset; and concrete pillar, roof, window, and door styles own their style
identity, style controls, and geometry. See the normative future-block pattern in
[`docs/contract.md`](docs/contract.md#building-block-style-pattern).

This README is the plugin's entry point; the full documentation lives in [`docs/`](docs):

- [`docs/feature.md`](docs/feature.md) — goals, authoring experience, rules, edge cases, ownership, and validation.
- [`docs/contract.md`](docs/contract.md) — stable contract and governance for the plugin's nodes, storage, and editor interaction.

The focused smoke scene is
[`test_low_poly_building_editor_3d.tscn`](test_low_poly_building_editor_3d.tscn). The
project-level [`../../docs/module_map.md`](../../docs/module_map.md),
[`../../docs/architecture.md`](../../docs/architecture.md), and
[`../../docs/contracts.md`](../../docs/contracts.md) keep one-line pointers here.
