# Low-Poly Building Editor

## Goal

- Provide a Godot-native editor plugin for quickly authoring grid-snapped low-poly building blockouts.
- Keep building authoring in normal scene trees so generated walls, openings, props, and transforms serialize into `.tscn` files.

## User / Player Experience

- This is a developer-facing tool, not runtime player UI.
- Authors enable the `Low-Poly Building Editor` plugin, then choose `Wall`, `Floor`, `Pillar`, `Roof`, `Prop`, `Door`, or `Window` from either the dock's tool dropdown or the building tool buttons added to the 3D viewport toolbar, and place content directly in the 3D viewport.
- The 3D viewport toolbar exposes one toggle button per building tool (next to Godot's native Transform/Move/Rotate/Scale/Select buttons) so authors can switch tools without moving focus to the dock; the toolbar and dock stay in sync, so selecting a tool in either place updates both.
- The building tool buttons are mutually exclusive with the native 3D viewport selection modes (Transform, Move, Rotate, Scale, Select): activating a building tool clears the native mode highlight, and clicking any native mode button (or its shortcut) deactivates the building tool and returns to that native mode. The native `Select` mode is the resting "no building tool" state, so the toolbar does not duplicate a Select button.
- The dock's top section shows shortcuts for the currently selected tool, followed by live status text and only that tool's properties/configuration section.
- Wall drawing supports click-start/click-end and click-drag-release flows with live snapped preview geometry; new walls draw on the dock's persisted parent-local base Y plane.
- Floor drawing supports click-corner/click-corner and click-drag-release flows with live snapped preview geometry; new floors are rectangular slabs whose top surface sits on the dock's persisted parent-local base Y plane.
- Pillar placement supports a click-to-place workflow with live snapped preview geometry; new pillars use the selected low-poly style, optional upper/lower rim settings, and their base sits on the dock's persisted parent-local base Y plane.
- Roof drawing supports click-corner/click-corner and click-drag-release flows with live snapped preview geometry; new roofs use the selected low-poly style and rotation, and their eaves sit on the dock's persisted parent-local base Y plane.
- Prop, door, and window placement uses translucent green/red previews before committing nodes.
- While the cursor is over a 3D viewport, `R` rotates the prop preview in 90-degree steps (prop mode only) and `Escape` or right-click cancels the active preview.
- The prop palette folder is configurable in the dock, defaults to `res://assets`, and includes `.tscn`, `.scn`, `.gltf`, and `.glb` scene assets. The configured folder persists across editor sessions via editor project metadata.

## Rules

- `BuildingEditor3D` is the coordinator node for one building assembly.
- `Wall3D` stores its parent-local `start_point` and `end_point`; its node transform and mesh are rebuilt from those endpoints.
- `Floor3D` stores opposite parent-local footprint corners in `start_point` and `end_point`; its node transform and mesh are rebuilt from those corners with thickness extending downward from the configured top surface.
- `Pillar3D` stores its parent-local `base_point`; its node transform and low-poly mesh are rebuilt from that base, lower radius, optional upper radius override, height, side count, style, upper/lower rim height and outset, and color.
- `Roof3D` stores opposite parent-local footprint corners in `start_point` and `end_point`; its node transform and low-poly mesh are rebuilt from those corners with style, roof face angle in degrees, thickness, overhang, Y rotation, color, and any covered render regions.
- Wall drawing snaps to `BuildingEditor3D.grid_step`, preserves the configured base Y height for new endpoints, and can lock to 45-degree increments for eight-way wall direction.
- Floor drawing snaps to `BuildingEditor3D.grid_step`, preserves the configured base Y height as the floor's top surface, and creates one persistent floor node per committed rectangle.
- In Floor tool mode, hovering over a placed floor highlights it blue for body moves and yellow for edge/corner resizes. Dragging the body translates the floor; dragging an edge resizes one footprint axis; dragging a corner resizes both axes. Edits snap to the active Floor grid, preserve the floor's existing top-surface Y, reject zero-area slabs, and commit through undo/redo.
- Pillar placement snaps to `BuildingEditor3D.grid_step`, preserves the configured base Y height, and creates one persistent pillar node per committed click. Built-in pillar styles are `Round`, `Square`, `Octagonal`, and `Tapered`; square and octagonal styles force their side counts, while round and tapered use the configured side count. The lower radius controls the base body radius, and the upper radius controls the top body radius when nonzero; `0` keeps the selected style's default top radius. Upper and lower rim controls set each rim band's height and radius outset; setting either rim value to `0` disables that rim. In Pillar tool mode, hovering over a placed pillar highlights it blue for body moves and yellow for radius resizes. Dragging the body translates the pillar; dragging the edge resizes its lower radius and scales a custom upper radius to preserve the pillar profile. Edits snap to the active Pillar grid, preserve the existing base Y, reject undersized radii, and commit through undo/redo.
- Roof drawing snaps to `BuildingEditor3D.grid_step`, preserves the configured base Y height as the roof eave plane, and creates one persistent roof node per committed rectangle. The first draw point and current draw point define opposite corners of the roof's rotated base footprint; the roof style then derives overhang, generated height, and style-specific top geometry from that base. Built-in roof styles are `Flat`, `Shed`, `Gable`, and `Hip`; shed, gable, and hip roofs use the configured face angle in degrees and derive their generated height from the relevant roof run, while flat roofs ignore the value. Hip roofs use a simple hipped form with a horizontal ridge along the longer footprint axis, two shorter triangular faces, and two longer trapezoid faces; square footprints degenerate to a centered apex while keeping all face angles equal. The hip Gable Drop setting turns the same hip shape into a half-hip or jerkinhead by clipping the ridge ends downward from the peak; positive values extend the ridge as needed to preserve the configured face angle, while `0` keeps the simple hip form. Roof thickness extends downward from the generated top surfaces, and overhang expands the roof beyond the committed footprint. The dock's Rotation value sets the starting Y rotation for new roofs; while drawing, `R` rotates the preview by 90 degrees and `Shift+R` rotates the opposite direction. The Roof debug triangle wireframe checkbox overlays a generated `RoofTriangleWireframe` line mesh from the final roof triangle index buffer for previews and newly created roofs. Same-eave roofs keep separate authored footprints, while overlap clipping compares roof surface heights across planar roof faces and removes only polygon render regions that sit under another roof, including overhang-to-overhang contact across different styles, angles, rotations, and materials. Face-level clipping keeps straight intersection edges instead of stair-stepping them through tiny rectangle fragments, and clipped edges receive fascia faces so roof thickness remains visible along cuts. Fully covered new or edited roofs are rejected instead of creating invisible authored nodes. In Roof tool mode, hovering over a placed roof highlights it blue for body moves and yellow for edge/corner resizes. Pressing `R` or `Shift+R` while hovering or selecting a placed roof rotates it around its footprint center through undo/redo. Dragging the body translates the roof; dragging an edge resizes one footprint axis in the roof's rotated local frame; dragging a corner resizes both axes. Gable edits keep the stored angle so the roof face angle stays fixed while the ridge height moves with footprint depth. Edits snap to the active Roof grid, preserve the existing eave-plane Y, reject zero-area roofs, recompute same-eave height-aware render-area clipping for the edited roof and sibling roofs, and commit through undo/redo.
- New wall spans merge into an existing collinear wall of matching thickness and height when their ranges overlap.
- Non-collinear walls that intersect (crossings, T-junctions, corners) remain separate `Wall3D` instances. When `BuildingEditor3D.merge_intersecting` is on (default), the coordinator refreshes geometry-only sibling clip segments after wall creation, edits, undo, redo, and scene load. Each wall rebuilds only its own authored spans while using sibling spans on the same base plane as non-rendered cutters, removing buried side and cap geometry without reparenting children or deleting the other wall node. Same-height cap overlap resolves by scene order so only one wall owns the shared top/bottom cap area.
- Window/prop placement and viewport picking are segment-aware: raycasts test every segment of a wall and previews align to the hit segment's frame.
- `BuildingOpening3D` children create rectangular wall holes without boolean operations. The wall compiles a split box-grid mesh around all openings.
- Window placement can create single windows, double windows, or frame-only openings. Window variants keep the full frame and add one or two translucent generated pane meshes inside the opening.
- Door placement uses the same segment-aware opening workflow as windows, but cuts openings down to the wall base and can place single doors, double doors, single door frames, or double door frames. Door frames omit the bottom frame piece; door variants add one or two generated panel meshes inside the opening.
- Window and door openings stay axis-aligned to their wall face; opening rotation is not supported, so the frame visual always matches the cut rectangle.
- Window openings keep their segment-local position and face alignment when wall endpoints, joints, extra segments, or whole walls are dragged.
- Window placement snaps horizontally to the coordinator's grid step, and the opening's bottom edge sits at the configurable sill height from the dock (persisted with the dock state, default 0.9) instead of following the cursor's vertical position. The selected window style and dimensions persist with the dock state.
- In Window or Door tool mode, hovering over a placed opening highlights it blue (center) or yellow (edge). Clicking and dragging the center repositions it; dragging an edge resizes it — left/right edges adjust width symmetrically, top/bottom edges adjust height (Y locks to the opening's sill + half-height). Both snap to grid. Releasing commits via undo/redo; Escape or right-click cancels.
- In Wall tool mode, hovering near any primary or extra segment endpoint highlights it yellow (resize); hovering a shared joint endpoint also shows an orange joint marker; hovering the middle highlights blue (move). Shift-clicking the middle of a wall span inserts a joint at the snapped hit point, splitting that span into two connected segments. Dragging an isolated endpoint moves only that endpoint (grid-snapped); dragging a shared joint endpoint moves every connected segment endpoint at that joint; Option/Alt-dragging a shared joint endpoint detaches only the picked segment endpoint; dragging any single endpoint near another endpoint or joint snaps it there to connect. Dragging the middle translates the wall's authored segment set. If an endpoint drag collapses a span to zero length, release deletes that segment, promoting another span to the primary segment when needed; collapsing the only span deletes the wall node. If a drag edit crosses another wall, sibling clip geometry refreshes without merging wall instances; same-wall crossings are still normalized so the crossing point becomes an editable endpoint on both involved segments.
- Wall meshes duplicate vertices per face, carry vertex colors, and use rough flat materials for hard low-poly face breaks.
- Floor meshes duplicate vertices per face, carry vertex colors, use rough flat materials, and generate collision from the slab footprint.
- Pillar meshes duplicate vertices per face, carry vertex colors, use rough flat materials, and generate cylinder collision from the outermost body or rim radius and height.
- Roof meshes duplicate vertices per face, carry vertex colors, use rough flat materials, optionally generate a debug triangle wireframe child from the final index buffer, and generate concave mesh collision from the closed roof solid.
- Wall mesh normals point outward, triangle winding follows Godot's `BoxMesh` convention, and wall materials use backface culling so lighting follows the generated face normals.
- Generated collision children are editor/runtime rebuild artifacts and should not be edited by hand.

## Edge Cases

- A wall shorter than half the active grid step, with an absolute floor of 0.1 units, is ignored.
- A floor whose width or depth is shorter than half the active grid step, with an absolute floor of 0.1 units, is ignored.
- A pillar radius shorter than the active pillar minimum, with an absolute floor of 0.05 units, is ignored or restored.
- A roof whose width or depth is shorter than half the active grid step, with an absolute floor of 0.1 units, is ignored.
- Roofs remove covered render geometry only where their same-eave render areas overlap and the local roof surface is under another roof surface; style, roof angle, thickness, overhang, rotation, and color differences do not prevent height-aware clipping. Matching overhangs participate in render-area clipping even when committed footprints only touch or are separated by less than the combined overhang. Cover regions are stored as simplified face-intersection polygons when available, with rectangle bounds kept only for compatibility and quick visibility checks.
- Dragging an existing segment to exactly zero length deletes it through undo/redo; nonzero spans below the minimum length are still rejected and restored.
- Window and door openings are rejected when they leave the wall bounds, overlap another opening, or straddle another authored segment or sibling intersection clip (the crossing wall's solid mass would block the hole). Doors are allowed to touch the wall base; windows keep bottom clearance from the base.
- Child openings are assigned to the segment whose face shell they sit on (distance to the face, not the centerline), so openings near junctions stay on the wall they were placed against; the window tool also pins the hit segment index as metadata, with geometric assignment as fallback.
- The opening preview re-parents to whichever wall is hovered, so moving between separate walls in window or door mode places against the correct node.
- Prop placement can fall back to the ground plane when no wall target exists.
- The first wall click or placement commit can create a `BuildingEditor3D` coordinator if the scene has none. Hover previews never mutate the scene or undo history.
- The first floor click can create a `BuildingEditor3D` coordinator if the scene has none. Floor previews never mutate the scene or undo history.
- The first pillar click can create a `BuildingEditor3D` coordinator if the scene has none. Pillar hover previews never mutate the scene or undo history.
- The first roof click can create a `BuildingEditor3D` coordinator if the scene has none. Roof previews never mutate the scene or undo history.
- Editing an existing floor uses editor-time ray math against floor boxes and does not access physics `direct_space_state` during GUI input.
- Editing an existing pillar uses editor-time ray math against finite cylinders and does not access physics `direct_space_state` during GUI input.
- Editing an existing roof uses editor-time ray math against roof bounds and does not access physics `direct_space_state` during GUI input.
- Preview walls are tagged with preview metadata and never participate in intersection clipping.
- Wall spans whose base heights differ by more than 0.01 units are not merged; they stay separate nodes.
- Undoing or redoing wall creation, edits, and deletion refreshes sibling clip geometry so separate intersecting wall nodes keep their own children and authored spans.
- Overlapping collinear spans of matching thickness and height extend an existing segment instead of stacking a duplicate span.
- If the configured folder is missing, the prop palette falls back to `res://assets` when available, then `res://`.

## Architecture / Ownership

- The editor plugin lives under `addons/low_poly_building_editor/`.
- The plugin owns dock UI, the 3D viewport toolbar tool selection (added to `CONTAINER_SPATIAL_EDITOR_MENU`), viewport input forwarding, previews, and undo/redo packing.
- The dock owns the canonical tool-mode selection state; the viewport toolbar drives it through the dock's `select_tool_mode()` entry point, and the plugin's `_on_tool_mode_changed` handler reflects the active mode back onto the toolbar buttons.
- The plugin keeps building tools mutually exclusive with the native viewport modes by locating each named native Transform/Move/Rotate/Scale/Select button independently (`Transform`/`ToolTriangle`, `ToolMove`, `ToolRotate`, `ToolScale`, `ToolSelect`) from its editor icon first, then from the toggle button's tooltip text, then from the native shortcut when both fail (Transform Q, Move W, Rotate E, Scale R, Select V): it clears their highlight while a building tool is active and listens to their mouse and button activations to deactivate the building tool when a native mode is chosen. If the native buttons cannot be located, the toolbar still works on its own without enforcing the exclusivity.
- A lightweight 3D viewport overlay plus root-level editor input capture handle placement clicks while a building tool is active so Godot's default select/transform mouse handling does not compete with wall, prop, or window placement. The root-level capture only acts over a 3D viewport that is currently visible on screen, so clicks in docks, the bottom panel, or other main screens (and hidden split-view viewports) are never intercepted.
- Viewport picking uses editor-time ray math against wall boxes, floor boxes, finite pillar cylinders, and roof bounds plus a ground-plane fallback, avoiding `direct_space_state` access during editor GUI input.
- `BuildingEditor3D` owns snapping, default wall settings, wall lookup, collinear merge target detection, and geometry-only intersecting-wall clip refresh.
- `BuildingEditor3D` owns default floor settings and floor node creation alongside wall defaults.
- `BuildingEditor3D` owns default pillar settings and pillar node creation alongside wall and floor defaults.
- `BuildingEditor3D` owns default roof settings, roof node creation, and same-eave roof overlap clipping alongside wall, floor, and pillar defaults.
- `Wall3D` owns its primary span plus authored `extra_segments`, transient sibling clip segments, opening-to-segment assignment, and the mesh/collision rebuild.
- `Floor3D` owns its rectangular slab mesh, vertex colors, material, and generated collision.
- `Pillar3D` owns its low-poly cylinder mesh, vertex colors, material, and generated collision.
- `Roof3D` owns its low-poly roof mesh, vertex colors, material, and generated collision.
- `MergedWallMeshBuilder` (`merged_wall_mesh_builder.gd`) owns the plan-space clipping math that can render a subset of wall segments while using all supplied same-plane segments as cutters.
- `WallSegment3D` (`wall_segment_3d.gd`) is the typed resource for one wall span, including static helpers for collinear segment merging and intersection splitting.
- `Wall3D` owns generated mesh, vertex colors, collision, and opening-driven rebuilds.
- `BuildingOpening3D` owns the visible window/door frame, window-pane, or door-panel marker and the dimensions consumed by wall mesh generation.

## Relevant Files

- Scenes: `scenes/tests/test_low_poly_building_editor_3d.tscn`
- Scripts: `addons/low_poly_building_editor/plugin.gd`, `building_editor_3d.gd`, `wall_3d.gd`, `floor_3d.gd`, `pillar_3d.gd`, `roof_3d.gd`, `building_opening_3d.gd`, `wall_segment_3d.gd`, `merged_wall_mesh_builder.gd`, `low_poly_building_editor_dock.gd`, `viewport_input_overlay.gd`, `viewport_input_capture.gd`
- Related docs: `docs/module_map.md`, `docs/contracts.md`

## Signals / Nodes / Data Flow

- Dock signals update active tool mode and wall/floor/pillar/roof/prop/window settings; the 3D viewport toolbar buttons call the dock's `select_tool_mode()` so the same `tool_mode_changed` signal carries selections from either UI.
- The plugin forwards 3D viewport mouse/key input while a building tool is active.
- The plugin commits scene mutations through `EditorUndoRedoManager`.
- `Wall3D` watches direct child opening signatures and segment data in editor mode and rebuilds when openings move or segments change.
- `Wall3D` captures direct child opening anchors before wall geometry edits and restores them into the updated segment frame so windows follow edited walls.
- Wall raycast hits carry a `segment` index so window and prop previews can target the correct authored span.

## Contracts / Boundaries

- The plugin is an editor authoring helper. It must not be wired into `main.tscn` or runtime gameplay flow.
- Scene-authored building content should remain normal Godot nodes under a `BuildingEditor3D` coordinator.
- If wall endpoint storage, floor corner storage, pillar base/radius storage, roof footprint storage, opening child semantics, or intersection clipping behavior changes, update this file plus `docs/contracts.md`.

## Validation

- Headless smoke scene: `scenes/tests/test_low_poly_building_editor_3d.tscn` (covers mesh conventions, floor slab generation, pillar style and rim generation, roof style generation, roof angle preservation, roof rotation, roof render-area merge detection, simplified polygon roof overlap clipping, mismatched roof overlap clipping, full-cover rejection, overhang-only roof clipping, stale roof-cover refresh, opening rules, door base-edge allowance and double-panel generation, double-window pane generation, opening anchors following edited segments, snapping, merge detection including height-mismatch rejection, intersection detection, geometry-only wall instance clipping, intersection splitting for multi-segment wall geometry, manual joint insertion, joint endpoint movement across connected segments, endpoint detach/reconnect behavior, connected wall top-cap preservation, multi-segment geometry with correct top-cap area, collinear segment extension, opening placement on extra segments, junction-adjacent segment assignment, and junction-straddling rejection).
- Manual editor validation: enable the plugin, create a coordinator, draw overlapping walls, place a window on a wall, and confirm undo/redo restores the wall mesh and child hierarchy.
- Place a prop on a wall positioned away from the scene origin and confirm the committed prop lands exactly where the preview showed.
- Confirm generated wall, floor, pillar, and roof meshes have vertex colors and generated collision.

## Out Of Scope

- True 3D CSG boolean unions; intersection baking clips in plan space and assumes walls in a group share a base plane.
- Rich asset thumbnails beyond the basic scene palette list.
- Runtime gameplay interaction with authored low-poly buildings.
