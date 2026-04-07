# Kulangsu Implementation Plan

This plan covers two workstreams that emerged from an architecture and gameplay review session in April 2026. Each task is designed to be picked up independently by a new agent or contributor.

Read `AGENTS.md` first, then `docs/design_brief.md` and `docs/architecture.md` before starting any task.

## Context

**Where the project stands:** All seven MVP steps are complete — melody catalog, five landmark arcs, journal with melody tab, practice/performance prompts, persistent world response, save/continue. A 7-track seed-pool BGM system is live. The core gameplay loop works end-to-end.

**Two problems identified:**
1. `game/app_state.gd` (2,289 lines) and `scenes/game_main.gd` (943 lines) are too large and absorb too many responsibilities.
2. The music/audio layer is mostly text-based. The BGM system is running, but landmark motifs, `resonant` world feedback, and piano game integration are missing.

---

## Workstream A: Architecture Cleanup

Extract focused services from AppState and game_main.gd. Each task is independently shippable. Do them in order — later tasks may depend on earlier extractions being stable.

### A1. Extract debug drawing from game_main.gd

**Scope:** Move `_draw()`, `_draw_npc_route_debug()`, `_npc_route_matches_debug_filter()`, and `_npc_route_debug_color()` (~127 lines) into a new `npc_route_debug_drawer.gd` child node.

**Target file:** `scenes/npc_route_debug_drawer.gd`

**How:**
- Create a Node2D script that owns the debug drawing logic.
- `game_main.gd` conditionally adds it as a child (e.g., only when a debug flag or export is set).
- The debug drawer reads NPC route data from the actor layer children — it never writes state.
- Move the `_process()` queue_redraw guard into the debug drawer.

**Validation:** Run the full project, enable route debug, confirm routes still render. Run with debug off, confirm no performance cost.

**Docs to update:** `docs/module_map.md` (add entry under World Integration).

**Risk:** Zero. Dev-only visual tool with no state dependencies.

---

### A2. Extract player profile service from AppState

**Scope:** Move all player appearance and costume cycling logic (~178 lines) into a new `game/player_profile_service.gd`.

**Methods to extract:**
- `get_player_profile()`, `get_player_body_display_name()`, `get_player_gender_display_name()`, `get_player_skin_display_name()`, `get_player_hair_style_display_name()`, `get_player_hair_color_display_name()`
- `set_player_profile()`, `cycle_player_body_frame()`, `cycle_player_gender()`, `cycle_player_skin_tone()`, `cycle_player_hair_style()`, `cycle_player_hair_color()`
- `get_player_appearance_config()`, `_cycle_player_profile_option()`
- `get_player_costume_ids()`, `get_player_costume()`, `get_unlocked_player_costume_ids()`, `get_equipped_player_costume_id()`, `get_equipped_player_costume()`, `get_equipped_player_costume_display_name()`, `equip_player_costume()`, `cycle_player_costume()`
- `_emit_player_appearance_changed()`, `_refresh_player_costumes()`
- `build_player_costume_journal_text()`, `build_player_setup_summary_text()`

**How:**
- Create `PlayerProfileService` that takes references to `PlayerAppearanceCatalog` and `PlayerCostumeCatalog`.
- AppState holds one `PlayerProfileService` instance, delegates all profile/costume calls to it.
- Signals `player_profile_changed`, `player_appearance_changed`, `player_costume_changed`, and `player_costumes_changed` stay on AppState. The service calls back through a reference or AppState re-emits.
- The service owns the `m_player_profile`, `m_unlocked_costume_ids`, and `m_equipped_costume_id` fields.

**Validation:** Run player setup screen. Cycle all options. Equip costumes. Start New Game, verify appearance applies. Open journal, verify costume tab renders. Run `test_story_autosave.tscn`, verify profile round-trips through save/load.

**Docs to update:** `docs/contracts.md` (add Player Profile contract), `docs/architecture.md`, `docs/module_map.md`.

**Risk:** Low. Self-contained domain with no cross-dependencies.

---

### A3. Extract route resolver from game_main.gd

**Scope:** Move tunnel portal math and route resolution (~178 lines) into a new `scenes/route_resolver.gd`.

**Methods to extract:**
- `_build_resident_movement_config()`
- `_resolve_actor_anchor_position()`, `_resolve_route_anchor_position()`, `_resolve_directional_portal_route_position()`
- `_build_tunnel_boundary_transition_points()`, `_append_unique_transition_point()`
- `_get_tunnel_entry_anchor_id_for_portal()`, `_resolve_portal_center_position()`
- `_get_portal_direction_vector()`, `_get_portal_lateral_vector()`, `_get_portal_tunnel_side_sign()`
- `_get_portal_for_anchor()`

**How:**
- Create `RouteResolver` as a static utility or a simple RefCounted object.
- It takes node references (portals, anchors, tunnel nodes) and returns world-space positions and waypoint arrays.
- `game_main.gd` calls `RouteResolver.build_movement_config(...)` during resident spawning.
- No signals, no state. Pure spatial calculation.

**Validation:** Run the full project. Verify all resident routes display correctly (use debug drawer from A1 if extracted). Run `test_npc_route_collision.tscn`, `test_tunnel_npc_travel.tscn`.

**Docs to update:** `docs/module_map.md`.

**Risk:** Low. Pure math with no side effects.

---

### A4. Extract journal text builder from AppState

**Scope:** Move all `build_*_journal_text()` methods (~146 lines) into a new `game/journal_builder.gd`.

**Methods to extract:**
- `build_map_journal_text()`
- `build_resident_journal_text()`
- `build_melody_journal_text()`
- `build_player_costume_journal_text()` (if not already moved in A2)
- `build_player_setup_summary_text()` (if not already moved in A2)

**How:**
- Create `JournalBuilder` as a static utility class.
- Each method takes AppState (or a read-only interface/dictionary) as a parameter and returns a String.
- `journal_overlay.gd` calls `JournalBuilder` for the Map, Residents, Melody, and Wardrobe body text instead of calling those builders on `AppState` directly.
- If `build_player_setup_summary_text()` remains in this task, `player_customization_overlay.gd` also calls `JournalBuilder` for the setup summary.
- No signals, no state mutation. Pure text generation.

**Validation:**
- Open the journal and verify the live tabs still render correctly: Objectives, Map, Residents, Melody, and Wardrobe.
- Compare the builder-backed text output before and after for Map, Residents, Melody, and Wardrobe.
- If `build_player_setup_summary_text()` remains in A4, open the player customization overlay and verify the setup summary matches pre-refactor output.
- Test in New Game, Continue, Free Walk, and Postgame modes.

**Docs to update:** `docs/module_map.md`, `docs/contracts.md` (note journal/setup text ownership change if applicable).

**Risk:** Low. Pure functions. The only coupling is that it reads many AppState fields.

---

### A5. Extract save/load service from AppState

**Scope:** Move story autosave serialization (~170 lines) into a new `game/story_save_service.gd`.

**Methods to extract:**
- `_build_story_autosave_payload()`
- `_read_story_autosave_payload()`
- `_normalize_story_autosave_payload()`, `_normalize_saved_resident_profiles()`, `_normalize_saved_landmark_progress()`, `_normalize_saved_summary()`
- `_apply_story_autosave_payload()`
- `_build_story_save_metadata_from_payload()`
- `_autosave_story_progress()`
- `_is_story_persistable_mode()`

**How:**
- Create `StorySaveService` that takes an AppState reference for reading/writing fields.
- AppState calls `StorySaveService.save()` and `StorySaveService.load()` at the existing trigger points.
- `save_metadata_changed` signal stays on AppState. The service calls `app_state.emit_save_metadata(...)`.
- The service owns the file I/O, version normalization, and payload shape.

**Validation:** Run `test_story_autosave.tscn`. Verify all six test assertions pass: first-save creation, real Continue, safe resume anchors, pre-ending save retention, postgame restore, departure-save clearing. Also manually test: New Game → complete ferry tutorial → kill and Continue.

**Docs to update:** `docs/contracts.md` (update save/load ownership), `docs/architecture.md`, `docs/module_map.md`.

**Risk:** Low. Self-contained lifecycle. Only coupling is that it snapshots and restores AppState fields.

---

### A6. Extract tunnel context from game_main.gd

**Scope:** Move tunnel detection and resident visibility syncing (~42 lines) into a new `scenes/tunnel_context.gd`.

**Methods to extract:**
- `_find_player_tunnel()`, `_find_resident_tunnel()`, `_find_tunnel_for_actor()`
- `_sync_tunnel_resident_visibility()`

**How:**
- Create a small helper node that `game_main.gd` creates and wires to the player position signal.
- It reads tunnel nodes from the scene tree and owns both resident `visible` state and the current `LevelRegistry.apply_level_to_actor(...)` tunnel/non-tunnel level sync.
- Preserve every current sync trigger, not just player movement:
  - call `tunnel_context.sync()` from the existing player-position path
  - call it after resident spawning / resume-anchor application
  - connect resident `global_position_changed` signals to it, because residents can cross tunnel boundaries while the player stands still
- If the event-only wiring proves brittle during playtest, keep a lightweight `_process()` fallback until the helper's triggers are proven complete.

**Validation:** Enter and exit both tunnels. Verify residents appear/disappear correctly at tunnel boundaries. Then stand still near a tunnel entrance and wait for routed residents to cross so you confirm visibility and level-state updates still happen without player movement. Run `test_tunnel_visibility.tscn`.

**Docs to update:** `docs/module_map.md`.

**Risk:** Low. Small, focused responsibility.

---

### A7. Extract resident spawner from game_main.gd

**Scope:** Move `_spawn_catalog_residents()` (~57 lines) into a new `scenes/resident_spawner.gd`.

**How:**
- Create a helper that takes the actor layer node, AppState reference, landmark anchor cache, and route resolver (from A3).
- It instantiates `ResidentNPC` actors, applies definitions and spawn configs, resolves routes, and adds them to the actor layer.
- Called once from `game_main._ready()`.

**Validation:** Run the full project. Verify all residents spawn at correct positions with correct routes. Run `test_npc_control.tscn`, `test_tunnel_npc_travel.tscn`.

**Docs to update:** `docs/module_map.md`.

**Risk:** Low. One-shot population logic.

---

### A8. Extract landmark progression from AppState

**Scope:** Move all per-landmark collection, completion, resolution, and prompt dispatch logic (~576 lines) into a new `game/landmark_progression.gd`.

**Methods to extract:**
- Collection handlers: `_collect_piano_ferry_harbor_clue()`, `_collect_trinity_church_cue()`, `_collect_bi_shan_echo()`, `_collect_long_shan_checkpoint()`
- Completion handlers: `_complete_trinity_church_chime()`, `_complete_bi_shan_chamber()`, `_complete_long_shan_route()`
- Resolution handlers: `_resolve_landmark()`, `_resolve_piano_ferry()`, `_resolve_trinity_church()`, `_resolve_bi_shan_tunnel()`, `_resolve_long_shan_tunnel()`, `_resolve_bagua_tower_synthesis()`, `_resolve_bagua_tower()`
- Prompt builders: `_request_melody_prompt()`, `_request_trinity_chime_prompt()`, `_request_bi_shan_chamber_prompt()`, `_request_long_shan_route_prompt()`, `_build_melody_prompt_segments()`
- Festival handlers: `_award_festival_source_once()`, `_emit_fragment_story_milestones()`, `_sync_festival_state_from_fragments()`, `_perform_festival_melody()`

**How:**
- Create `LandmarkProgression` that takes an AppState reference.
- AppState's `activate_landmark_trigger()` delegates to `LandmarkProgression.handle_trigger(landmark_id, trigger_id, display_name, melody_hint)`.
- AppState's `complete_prompt_request()` delegates landmark-specific completions to `LandmarkProgression.complete_prompt(request)`.
- The service reads and writes landmark progress through AppState's existing `get_landmark_progress()` / `set_landmark_progress()` / `advance_landmark_state()` API.
- The service emits melody hints and prompt requests through AppState signals.
- Landmark state fields and signals stay on AppState. The business logic moves out.

**Validation:** Run `test_cue_progression.tscn` — this is the critical regression scene covering the full Ferry → Trinity → Bi Shan → Long Shan → Bagua → harbor-stage progression. All fragment awards, dependable-route notes, Bagua gating, and the in-world ending trigger must still work. Also run the full manual playtest route from `core_melody_loop.md`.

**Docs to update:** `docs/contracts.md` (update landmark progress contract to note delegation), `docs/architecture.md`, `docs/module_map.md`, `docs/features/core_melody_loop.md`.

**Risk:** Medium-high. This is the most coupled extraction. Cross-references melody progress, fragment counts, resident trust, and prompt dispatch. Do this last after all other extractions are stable.

---

## Workstream B: Music & Audio

These tasks build on the existing BGM system. They can run in parallel with Workstream A (they don't depend on the refactoring).

### B1. Define what `resonant` changes — or remove the tier

**Scope:** Design decision + small implementation. The `resonant` tier currently exists in AppState but produces no observable world change beyond a journal button label.

**Option 1 — Give it meaning (recommended):**
- Define 1-2 concrete changes per landmark that activate when `festival_melody.state == "resonant"`:
  - **Audio:** The BGM system already supports a `progress` weight factor. `after_the_stage` is an exclusive track that only plays at `performed`/`resonant`. Consider adding one more `resonant`-exclusive track, or adjusting `after_the_stage` weights so it plays more frequently in postgame.
  - **Dialogue:** Add one unique postgame dialogue beat per key resident (Lian, Mei, Ren, Suyin). Currently they fall through to generic "calm" text. Use the existing `conditional_beats` system with a gate on melody state `resonant`.
  - **Visual (optional, low priority):** One small environmental change per landmark — a lit window at Trinity Church, a soft glow in Bi Shan's chamber, a flag at the ferry stage. These would be `LandmarkTrigger`-style nodes that check `resonant` state visibility.
- Update `configure_postgame()` to note which changes are live.

**Option 2 — Remove it:**
- Keep three tiers: `heard → reconstructed → performed`.
- Remove `resonant` from all live consumers, not just default seed data:
  - `configure_postgame()` should seed `performed` postgame state instead of a fourth tier
  - `_sync_festival_state_from_fragments()` and any practice/performance gates should stop treating `resonant` as a distinct progression stage
  - journal replay labels, melody state display names, and BGM progress weights should collapse to the three-tier model
- Update `docs/features/core_melody_loop.md`, `docs/core_gameplay_plays.md`, `docs/contracts.md`, and any BGM docs that currently describe `performed/resonant` exclusivity.

**Files to read first:** `game/app_state.gd` (search `configure_postgame`, `resonant`), `game/bgm_catalog.gd` (search `after_the_stage`), `game/resident_catalog.gd` (search `conditional_beats`).

**Validation:** If Option 1: complete the harbor performance, choose "Stay a Little Longer", verify new dialogue beats fire, verify BGM weight shift is audible, verify any visual changes appear. If Option 2: run `test_cue_progression.tscn` and the manual ending smoke pass.

---

### B2. Add per-landmark audio cues

**Scope:** Create short audio clips (or placeholder tones) for each landmark and wire them to LandmarkTrigger interactions.

**Design goal:** The player should hear a distinct motif when they discover a melody clue at each landmark — before the journal tells them what they found. This grounds the "hear before you name it" design pillar from `core_gameplay_plays.md`.

**Suggested motifs:**
- Piano Ferry: gentle two-note piano pulse (matches `melody_hint`: "a patient two-note pulse")
- Trinity Church: bell chime fragment (matches choir/bell theme)
- Bi Shan Tunnel: reverb echo tone (matches echo/contour theme)
- Long Shan Tunnel: warm sustained note (matches companionship/reassurance theme)
- Bagua Tower: ascending interval (matches height/synthesis theme)

**How:**
- Create 5 short OGG clips (3-8 seconds each) in `resources/audio/sfx/landmark_cues/`. Use the `addons/mp3_to_ogg/` editor plugin if sourcing from MP3.
- Split the trigger path in two, because the current implementation has both collected pickups and prompt-opening interactions:
  - for pickups that return `true` and are consumed in-scene, a `LandmarkTrigger`-owned or scene-local `AudioStreamPlayer` is fine
  - for interactions that intentionally return `false` because they open a prompt (`choir_chime`, `chamber`, `tunnel_exit`, `festival_stage`), trigger the cue from the same `AppState.activate_landmark_trigger(...)` branch or attach cue metadata to the emitted prompt request; do not rely on `LandmarkTrigger.collect()`
- Do not route cue selection through `melody_hint_shown` alone; it only carries text and does not uniquely identify which trigger fired.
- The BGM system should duck briefly (reduce volume by ~6dB for the cue duration) so the motif is audible. Add a reusable `duck_for_cue(duration)` / `set_ducked(...)` style API to `BgmManager`, then call it from the world or shell layer that already owns the active `BgmManager`.

**Files to read first:** `game/landmark_trigger.gd`, `game/bgm_manager.gd`, landmark `.tscn` files under `architecture/`.

**Validation:** Walk to each landmark trigger. Verify cue plays, BGM ducks, and cue doesn't overlap with other audio. Verify cue does not play on repeat visits (trigger is already collected/hidden).

**Docs to update:** `docs/features/bgm_system.md` (add duck behavior), `docs/contracts.md` (note LandmarkTrigger audio contract), `docs/features/core_melody_loop.md` (update gap #8).

---

### B3. Add performance audio feedback to melody prompts

**Scope:** Add audio feedback to the `MelodyPromptOverlay` ordered-confirmation UI.

**Current state:** The prompt is fully text-based — the player selects fragment labels in order with no audio. The prompt is used at Trinity Church (choir chime), Bi Shan (chamber contour), Long Shan (exit route), journal practice, and the harbor-stage performance.

**Design goal:** Each segment selection should play a short tone, and completing the correct order should play a brief resolution chord. Wrong order should play a gentle "try again" sound.

**How:**
- Create 3-4 short OGG tones: `segment_select.ogg` (0.5s), `order_correct.ogg` (1.5s), `order_wrong.ogg` (0.8s), and optionally per-landmark variants.
- Add `AudioStreamPlayer` nodes to `MelodyPromptOverlay` (`ui/screens/melody_prompt_overlay.gd`).
- On segment tap: play `segment_select`.
- On correct order submit: play `order_correct`, await its short finish (or a capped timer), then emit the existing completion signal. This is required if the harbor-stage resolution chord should land before the ending overlay opens.
- On wrong order submit: play `order_wrong`, then proceed with existing retry logic.
- Duck BGM for the entire lifetime of the prompt, not just on submit:
  - start ducking when `main.gd` opens the overlay
  - release ducking when `main.gd` closes it
  - keep the overlay's audio feedback local to the panel, but keep BGM ownership in the shell / scene-owned manager path

**Files to read first:** `ui/screens/melody_prompt_overlay.gd`, `game/bgm_manager.gd`.

**Validation:** Open journal, practice a reconstructed melody — verify audio plays and BGM ducks for the full prompt. Complete Trinity Church choir chime — verify correct/wrong sounds. Complete harbor-stage performance — verify the resolution chord finishes before the ending overlay opens.

---

### B4. Define the piano game's role and integration path

**Scope:** Design decision document. The piano game (`game/piano_game/`) is a complete standalone rhythm-game prototype. It needs a canonical decision about its role.

**Current state:** The piano game loads its own MP3, runs beat detection, renders 3-lane note spawning with timing judgment, and prints scores to console. It is NOT connected to `main.tscn`, `app_state.gd`, the HUD, or story progression.

**Options to evaluate:**

1. **Festival-only performance backend.** Replace or supplement the ordered-confirmation prompt at the harbor-stage with a short piano game segment. The prompt selects the song, the piano game plays 30-60 seconds of it, and success/failure routes back through `AppState.complete_prompt_request()`. This makes the finale feel like a real musical moment.

2. **Optional free-play station.** Place a piano game trigger at Ferry Plaza (near the piano crate). Players can play it any time after the journal unlocks. It does not gate progression — it's a side activity. Scores could optionally feed into the `resonant` tier or cosmetic unlocks.

3. **Both.** Option 1 for story integration, Option 2 for replayability.

4. **Keep it as a prototype.** Do not integrate. The ordered-confirmation prompt is the performance layer. The piano game stays as an authoring sandbox for future use.

**Deliverable:** A short decision document (`docs/features/piano_game_integration.md`) that picks one option, defines the integration contract (which AppState signals it connects to, what it returns, who owns the audio bus handoff from BGM), and lists the implementation steps.

**Files to read first:** `docs/piano_game_design.md`, `game/piano_game/piano_game.gd`, `game/piano_game/beat_json_generator.gd`, `game/bgm_manager.gd`, `ui/screens/melody_prompt_overlay.gd`.

---

### B5. Expand BGM seed pool (content task)

**Scope:** Add tracks to the BGM catalog following the existing tagging guide.

**Current state:** 7 tracks in 3 tiers — 4 commons, 2 location-leaning, 1 exclusive. The long-term target documented in `bgm_tagging_guide.md` is 24-28 base tracks.

**Recommended next batch (V2, 4-6 tracks):**
- 1 location-leaning track for Bi Shan Tunnel (echo/reverb feel, heard/reconstructed weighted)
- 1 location-leaning track for Long Shan Tunnel (warm/companionship feel)
- 1 location-leaning track for Bagua Tower (ascending/contemplative, reconstructed-weighted, with optional performed carryover)
- 1 additional commons track (evening/night capable, to balance the afternoon-heavy V1 pool)
- 1 additional exclusive for `resonant` state (if B1 chose Option 1)

**How:**
- Follow `docs/bgm_suno_guide.md` for generation guidance (compatible keys, BPM 65-80, normalize to -14 LUFS).
- Save as OGG in `resources/audio/music/bgm/`.
- Add entries to `game/bgm_catalog.gd` following the existing per-track format.
- Tag weights using `docs/features/bgm_tagging_guide.md` workflow.

**Validation:** Run `test_bgm_manager.tscn` after catalog changes. Play the full game, visit each landmark, verify variety feels better.

---

## Task Dependencies

```
Workstream A (sequential):
  A1 → A2 → A3 → A4 → A5 → A6 → A7 → A8

Workstream B (mostly parallel, some ordering):
  B1 (standalone — do early, informs B2 and B5)
  B2 (standalone — after B1 decision)
  B3 (standalone)
  B4 (standalone — design decision, informs future work)
  B5 (after B1, after B4 if piano game changes the audio direction)

A and B are independent and can run in parallel.
```

## Expected Outcomes

After Workstream A:
- `app_state.gd`: ~900 lines (from 2,289). Owns signals, state fields, configuration, mode/chapter/location setters, and resident interaction dispatch.
- `game_main.gd`: ~500 lines (from 943). Owns scene init, player spawn, camera, BGM setup, location sync, landmark cache, and signal wiring.
- Eight new focused files, each under 200 lines with a single responsibility.

After Workstream B:
- The island has audible landmark cues that ground the "hear before you name it" pillar.
- Performance prompts have audio feedback instead of being purely text-based.
- The `resonant` tier either does something meaningful or is removed.
- The piano game has a documented integration path (or an explicit decision to keep it standalone).
- The BGM pool has enough variety for location-specific mood across all five landmarks.

## Global Rules

- Read `AGENTS.md` before starting any task.
- Read `docs/contracts.md` before changing shared state, signals, or cross-module interfaces.
- Update `docs/contracts.md`, `docs/architecture.md`, and `docs/module_map.md` when ownership moves.
- Run the cited validation scenes after each task. Do not skip `test_cue_progression.tscn` for any task that touches landmark or melody state.
- Do not introduce mandatory combat, score ranking, or long rhythm-game stages.
- Do not change the canonical five-landmark route without updating `docs/design_brief.md` and `docs/core_game_workflow.md`.
- Prefer GDScript catalogs over JSON data files unless authoring scale justifies migration.
