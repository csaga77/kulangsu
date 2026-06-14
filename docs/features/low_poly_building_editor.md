# Low-Poly Building Editor

## Goal

- Provide a Godot-native editor plugin for quickly authoring grid-snapped low-poly building blockouts.
- Keep building authoring in normal scene trees so generated walls, openings, props, and transforms serialize into `.tscn` files.

## User / Player Experience

- This is a developer-facing tool, not runtime player UI.
- Authors enable the `Low-Poly Building Editor` plugin, use its dock to choose `Wall`, `Prop`, or `Window`, and place content directly in the 3D viewport.
- Wall drawing supports click-start/click-end and click-drag-release flows with live snapped preview geometry.
- Prop and window placement uses translucent green/red previews before committing nodes.
- While the cursor is over a 3D viewport, `R` rotates the prop preview in 90-degree steps (prop mode only) and `Escape` or right-click cancels the active preview.
- The prop palette folder is configurable in the dock, defaults to `res://assets`, and includes `.tscn`, `.scn`, `.gltf`, and `.glb` scene assets. The configured folder persists across editor sessions via editor project metadata.

## Rules

- `BuildingEditor3D` is the coordinator node for one building assembly.
- `ProceduralWall3D` stores its parent-local `start_point` and `end_point`; its node transform and mesh are rebuilt from those endpoints.
- Wall drawing snaps to `BuildingEditor3D.grid_step` and can lock to 45-degree increments for eight-way wall direction.
- New wall spans merge into an existing collinear wall of matching thickness and height when their ranges overlap.
- Non-collinear walls that intersect (crossings, T-junctions, corners) collapse on commit into one surviving `ProceduralWall3D`: every participating span is split at centerline intersections, including the segment being intersected, stored as typed `WallSegment3D` resources in `extra_segments`, their openings and props reparent to the survivor, and the other wall nodes are removed. The survivor rebuilds one combined mesh whose faces are clipped and whose shared endpoints are mitered by extending wall side faces to their endpoint-direction side-line intersections without adding butt-style joint caps; drawing the same physical spans in the opposite start/end direction produces the same miter points. Top and bottom caps stay tied to wall footprints, with targeted overlap clipping at joins, so split 3+ joins render filled while enclosed wall loops keep their room interiors open. Toggle via `BuildingEditor3D.merge_intersecting` (default on).
- Window/prop placement and viewport picking are segment-aware: raycasts test every segment of a wall and previews align to the hit segment's frame.
- `BuildingOpening3D` children create rectangular wall holes without boolean operations. The wall compiles a split box-grid mesh around all openings.
- Window openings stay axis-aligned to their wall face; opening rotation is not supported, so the frame visual always matches the cut rectangle.
- Window openings keep their segment-local position and face alignment when wall endpoints, joints, absorbed segments, or whole walls are dragged.
- Window placement snaps horizontally to the coordinator's grid step, and the opening's bottom edge sits at the configurable sill height from the dock (persisted with the dock state, default 0.9) instead of following the cursor's vertical position.
- In Window tool mode, hovering over a placed opening highlights it blue (center) or yellow (edge). Clicking and dragging the center repositions it; dragging an edge resizes it — left/right edges adjust width symmetrically, top/bottom edges adjust height (Y locks to sill + half-height). Both snap to grid. Releasing commits via undo/redo; Escape or right-click cancels.
- In Wall tool mode, hovering near any primary or absorbed segment endpoint highlights it yellow (resize); hovering a shared joint endpoint also shows an orange joint marker; hovering the middle highlights blue (move). Shift-clicking the middle of a wall span inserts a joint at the snapped hit point, splitting that span into two connected segments. Dragging an isolated endpoint moves only that endpoint (grid-snapped); dragging a shared joint endpoint moves every connected segment endpoint at that joint; Option/Alt-dragging a shared joint endpoint detaches only the picked segment endpoint; dragging any single endpoint near another endpoint or joint snaps it there to connect. Dragging the middle translates the whole merged wall. If an endpoint drag collapses a span to zero length, release deletes that segment, promoting another span to the primary segment when needed; collapsing the only span deletes the wall node. If a drag edit crosses another wall or another segment in the same merged wall, all participating spans are normalized so the crossing point becomes a new editable endpoint on both the crossing and intersected segments.
- Wall meshes duplicate vertices per face, carry vertex colors, and use rough flat materials for hard low-poly face breaks.
- Wall mesh normals point outward, triangle winding follows Godot's `BoxMesh` convention, and wall materials use backface culling so lighting follows the generated face normals.
- Generated collision children are editor/runtime rebuild artifacts and should not be edited by hand.

## Edge Cases

- A wall shorter than half the active grid step, with an absolute floor of 0.1 units, is ignored.
- Dragging an existing segment to exactly zero length deletes it through undo/redo; nonzero spans below the minimum length are still rejected and restored.
- Window openings are rejected when they leave the wall bounds, overlap another opening, or straddle another segment of the merged wall (the crossing segment's solid mass would block the hole).
- Child openings are assigned to the segment whose face shell they sit on (distance to the face, not the centerline), so openings near junctions stay on the wall they were placed against; the window tool also pins the hit segment index as metadata, with geometric assignment as fallback.
- The window preview re-parents to whichever wall is hovered, so moving between separate walls in window mode places against the correct node.
- Prop placement can fall back to the ground plane when no procedural wall target exists.
- The first wall click or placement commit can create a `BuildingEditor3D` coordinator if the scene has none. Hover previews never mutate the scene or undo history.
- Preview walls are tagged with preview metadata and never participate in intersection merging.
- Wall spans whose base heights differ by more than 0.01 units are not merged; they stay separate nodes.
- Undoing an intersection merge restores the removed wall nodes, their children, and the survivor's previous primary span plus segment list.
- Absorbed collinear spans of matching thickness and height extend an existing segment instead of stacking a duplicate span.
- If the configured folder is missing, the prop palette falls back to `res://assets` when available, then `res://`.

## Architecture / Ownership

- The editor plugin lives under `addons/low_poly_building_editor/`.
- The plugin owns dock UI, viewport input forwarding, previews, and undo/redo packing.
- A lightweight 3D viewport overlay plus root-level editor input capture handle placement clicks while a building tool is active so Godot's default select/transform mouse handling does not compete with wall, prop, or window placement.
- Viewport picking uses editor-time ray math against procedural wall boxes plus a ground-plane fallback, avoiding `direct_space_state` access during editor GUI input.
- `BuildingEditor3D` owns snapping, default wall settings, wall lookup, collinear merge target detection, and intersecting-wall detection for commits.
- `ProceduralWall3D` owns its primary span plus absorbed `extra_segments`, opening-to-segment assignment, and the combined mesh/collision rebuild.
- `MergedWallMeshBuilder` (`merged_wall_mesh_builder.gd`) owns the plan-space clipping math that produces combined multi-segment geometry.
- `WallSegment3D` (`wall_segment_3d.gd`) is the typed resource for one wall span, including static helpers for collinear segment merging and intersection splitting.
- `ProceduralWall3D` owns generated mesh, vertex colors, collision, and opening-driven rebuilds.
- `BuildingOpening3D` owns the visible window frame marker and the dimensions consumed by wall mesh generation.

## Relevant Files

- Scenes: `scenes/tests/test_low_poly_building_editor_3d.tscn`
- Scripts: `addons/low_poly_building_editor/plugin.gd`, `building_editor_3d.gd`, `procedural_wall_3d.gd`, `building_opening_3d.gd`, `wall_segment_3d.gd`, `merged_wall_mesh_builder.gd`, `low_poly_building_editor_dock.gd`, `viewport_input_overlay.gd`, `viewport_input_capture.gd`
- Related docs: `docs/module_map.md`, `docs/contracts.md`

## Signals / Nodes / Data Flow

- Dock signals update active tool mode and wall/prop/window settings.
- The plugin forwards 3D viewport mouse/key input while a building tool is active.
- The plugin commits scene mutations through `EditorUndoRedoManager`.
- `ProceduralWall3D` watches direct child opening signatures and segment data in editor mode and rebuilds when openings move or segments change.
- `ProceduralWall3D` captures direct child opening anchors before wall geometry edits and restores them into the updated segment frame so windows follow edited walls.
- Wall raycast hits carry a `segment` index so window and prop previews can target the correct span of a merged wall.

## Contracts / Boundaries

- The plugin is an editor authoring helper. It must not be wired into `main.tscn` or runtime gameplay flow.
- Scene-authored building content should remain normal Godot nodes under a `BuildingEditor3D` coordinator.
- If wall endpoint storage, opening child semantics, or merge behavior changes, update this file plus `docs/contracts.md`.

## Validation

- Headless smoke scene: `scenes/tests/test_low_poly_building_editor_3d.tscn` (covers mesh conventions, opening rules, opening anchors following edited segments, snapping, merge detection including height-mismatch rejection, intersection detection, intersection splitting into editable endpoints, manual joint insertion, joint endpoint movement across connected segments, endpoint detach/reconnect behavior, connected wall top-cap preservation, multi-segment merged geometry with correct top-cap area, collinear segment extension, opening placement on extra segments, junction-adjacent segment assignment, and junction-straddling rejection).
- Manual editor validation: enable the plugin, create a coordinator, draw overlapping walls, place a window on a wall, and confirm undo/redo restores the wall mesh and child hierarchy.
- Place a prop on a wall positioned away from the scene origin and confirm the committed prop lands exactly where the preview showed.
- Confirm generated wall mesh has vertex colors and generated collision.

## Out Of Scope

- True 3D CSG boolean unions; intersection baking clips in plan space and assumes walls in a group share a base plane.
- Rich asset thumbnails beyond the basic scene palette list.
- Runtime gameplay interaction with authored low-poly buildings.
