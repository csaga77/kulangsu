# Kulangsu Implementation Plan

This plan covers the next phase of work following the architecture cleanup and audio foundation completed in April 2026. Each task is designed to be picked up independently by a new agent or contributor.

Read `AGENTS.md` first, then `docs/design_brief.md` and `docs/architecture.md` before starting any task.

## What Has Been Completed

**Architecture Cleanup (Workstream A) — Done.**
AppState dropped from 2,289 to 1,761 lines. Eight focused helpers were extracted: `player_profile_service.gd`, `journal_builder.gd`, `story_save_service.gd`, `landmark_progression.gd`, `route_resolver.gd`, `resident_spawner.gd`, `tunnel_context.gd`, `npc_route_debug_drawer.gd`. Contracts, architecture, and module map docs are all updated.

**Audio Foundation (Workstream B) — Done.**
Landmark audio cues live (6 OGG clips, BGM ducking). Melody prompt overlay has segment-select, correct-order, and wrong-order audio feedback. `resonant` tier now has unique postgame dialogue beats and resonant-only BGM selection (`night_tide_memory`). BGM pool expanded to 12 tracks across 3 tiers with full 5-factor affinity weights. Piano game integration decision documented: optional free-play station, not mandatory story gate.

**Additional work shipped:** Weather rendering system (rain, fog, cloud shadows, ground impacts) with `WeatherManager` and `WeatherRuntime`. Story framework doc (`docs/story/summer_of_piano_island_story_framework.md`) as narrative source of truth.

---

## Current State Summary

| System | Status | Key Metric |
|---|---|---|
| Core melody loop | Playable end-to-end | 5 landmarks, 4 fragments, 3 endings |
| AppState | Cleaned up | 1,761 lines with composed helpers |
| game_main.gd | Cleaned up | 954 lines with extracted helpers |
| BGM | 12-track V1 live | Location + progress weights active; time/season/weather defaulted |
| Landmark cues | Live | 6 OGG one-shot motifs with BGM ducking |
| Prompt audio | Live | Select, correct, wrong feedback + BGM ducking |
| Weather rendering | Complete | Rain, fog, cloud shadows, ground impacts, random preset cycling |
| Piano game | Standalone prototype | Integration path documented, not wired |
| Save/Continue | Autosave-backed | Single-slot, versioned, safe resume anchors |
| Resonant tier | Live | Postgame dialogue beats + exclusive BGM track |

---

## Workstream C: Systems Integration

These tasks wire existing standalone systems together. Each is independently shippable.

### C1. Wire weather state into BGM selection

**Scope:** The BGM system already has `weather` as one of its five context factors, but it's hardcoded to `"clear"`. The weather manager already cycles through presets (calm, light rain, steady rain, gusty shower, mist). Connect them.

**How:**
- Add a signal to `WeatherManager` (e.g., `weather_state_changed(weather_label: String)`) that fires when the active preset changes. Map preset names to the BGM weather categories: `clear`, `rain`, `fog`, `wind`.
- `game_main.gd` (or `BgmManager` directly) subscribes to this signal and updates the BGM context.
- `BgmManager` already scores tracks by weather affinity — once the context value is no longer `"clear"`, weather-appropriate tracks will naturally float to the top.
- No new tracks needed; the existing catalog already has weather weights authored per track.

**Files to read first:** `weather/weather_manager.gd`, `game/bgm_manager.gd`, `game/bgm_catalog.gd` (check existing weather weights), `docs/features/bgm_system.md` (open question #2 about weather-exclusive tracks).

**Validation:** Run the full project. Wait for weather to cycle to rain/fog. Verify BGM reselection happens (after commitment window or at track end). Verify tracks with higher rain/fog weights are favored. Run `test_bgm_manager.tscn` to confirm no regression.

**Docs to update:** `docs/features/bgm_system.md` (resolve open question #2), `docs/contracts.md` (add weather→BGM signal contract), `docs/features/weather_rendering.md` (note BGM integration).

**Risk:** Low. Both systems are live; this is signal wiring.

---

### C2. Wire piano game as optional free-play station

**Scope:** Implement the decision from `docs/features/piano_game_integration.md`: add a ferry-side trigger near the piano crate that opens the piano game as a shell-owned overlay after the journal unlocks.

**How:**
- Add a new `Area2D` trigger node near the piano crate in `architecture/piano_ferry.tscn`, gated behind `AppState.is_journal_unlocked()`.
- When the player inspects it, `main.gd` opens the piano game as an overlay (like journal/pause), not a scene swap.
- `main.gd` ducks BGM for the overlay lifetime (same pattern as melody prompt ducking).
- The piano game owns its own `AudioStreamPlayer` for the song.
- On completion, the piano game emits a result signal with `{ song_id, completed, score_percent }`. For V1, AppState ignores the result — no story reward yet.
- Replace the current console-only completion print with this result signal.
- Future: cosmetic unlock after free-play feels good (out of scope for this task).

**Files to read first:** `docs/features/piano_game_integration.md`, `game/piano_game/piano_game.gd`, `main.gd` (overlay management pattern), `game/bgm_manager.gd` (ducking API).

**Validation:** Start New Game, complete ferry tutorial (journal unlocks). Return to piano crate area, verify trigger appears. Interact, verify piano game opens as overlay with BGM ducked. Complete or exit the game, verify return to gameplay with BGM restored. Verify trigger does NOT appear before journal unlock.

**Docs to update:** `docs/features/piano_game_integration.md` (mark step 1-4 done), `docs/module_map.md`, `docs/contracts.md`.

**Risk:** Medium. Requires overlay management wiring in `main.gd` and audio bus handoff.

---

### C3. Add time-of-day system (minimal V1)

**Scope:** Create a lightweight time-of-day state that the BGM system can consume. The BGM catalog already has `time` weights per track (`morning`, `afternoon`, `evening`, `night`) but they're unused because time is fixed to `"afternoon"`.

**How:**
- Add a simple time state to `AppState`: `set_time_of_day(time: String)` + `time_of_day_changed(time: String)` signal.
- Create a minimal `TimeOfDayService` (or add to `game_main.gd`) that advances time based on real elapsed gameplay minutes. Suggested mapping: 0-5 min = morning, 5-15 min = afternoon, 15-25 min = evening, 25+ min = night. These are placeholders — tunable.
- `BgmManager` subscribes to the time signal and updates its context (same pattern as location).
- Weather rendering can optionally respond to time (dimmer lighting at night) but this is a stretch goal, not required.

**Design questions to resolve first:**
- Should time reset on Continue/New Game? (Probably yes.)
- Should time advance in Free Walk? (Probably yes, at the same rate.)
- Should time affect NPC dialogue? (Not in V1 — keep it BGM-only first.)
- Should time advance during overlays/menus? (Probably not.)

**Files to read first:** `game/bgm_manager.gd`, `game/bgm_catalog.gd` (time weights), `docs/features/bgm_system.md` (open question #1 about reselection on time change).

**Validation:** Start New Game, play for 5+ minutes, verify BGM track selection shifts toward afternoon→evening tracks. Check that evening/night-biased tracks (`stillness`, `moonlit_refrain`, `sanctuary_of_stillness`) become more likely. Run `test_bgm_manager.tscn`.

**Docs to update:** `docs/features/bgm_system.md` (resolve open question #1), `docs/contracts.md` (add time-of-day signal), `docs/architecture.md`.

**Risk:** Low-medium. The BGM system already handles the scoring; this is adding a state provider.

---

## Workstream D: Content & Polish

These tasks add content within the existing architecture. No structural changes needed.

### D1. Track resident help count in ending summary

**Scope:** The ending summary currently shows `"residents": "0"` — it's not automated. Wire it to the actual count of residents the player helped.

**How:**
- `AppState` already has `_count_helped_residents()`. Verify it returns the correct count based on resident trust levels.
- Update `_update_summary_counts()` to include the helped-residents count in the summary dictionary.
- Update the ending overlay to display the real count instead of the hardcoded "0".
- This affects the three ending tones: Community ending requires "most side stories" completed, so the count now provides real feedback.

**Files to read first:** `game/app_state.gd` (search `_count_helped_residents`, `_update_summary_counts`), `ui/screens/ending_overlay.gd` or equivalent.

**Validation:** Complete a full playthrough talking to all optional residents. Verify ending summary shows correct helped count. Complete a minimal playthrough skipping optionals. Verify lower count.

**Risk:** Very low. Reading existing state and displaying it.

---

### D2. Expand BGM pool to V2 (16-20 tracks)

**Scope:** Add 4-8 tracks to the BGM catalog, targeting gaps in the current coverage.

**Current gaps in the 12-track pool:**
- No morning-biased commons track (existing pool skews afternoon/evening)
- No weather-specific track that strongly favors rain or fog
- Only one night-dominant track (`moonlit_refrain`)
- Only two exclusive tracks — a third could serve the `reconstructed` milestone

**Recommended additions:**
- 1 morning commons (bright, gentle start-of-day feel)
- 1 rain-leaning commons (soft, contemplative, high `rain` weight)
- 1 night commons (ambient, distinct from `moonlit_refrain`)
- 1 overworld-biased afternoon track (adds variety to the most-played context)
- 1 optional `reconstructed`-exclusive or `heard`-leaning track (marks early-game discovery mood)

**How:**
- Follow `docs/bgm_suno_guide.md` for generation (compatible keys, BPM 65-80, normalize to -14 LUFS).
- Convert to OGG using `addons/mp3_to_ogg/` editor plugin.
- Add entries to `game/bgm_catalog.gd` following existing format.
- Tag weights using `docs/features/bgm_tagging_guide.md`.

**Validation:** Run `test_bgm_manager.tscn`. Play full project across all time periods and weather states (if C1 is done). Verify no single track dominates.

**Risk:** Very low. Content addition within existing architecture.

---

### D3. Add postgame resident dialogue depth

**Scope:** The `resonant` tier now gates unique dialogue beats, but they may still be thin. Deepen the postgame experience by adding 1-2 more `conditional_beats` per key resident.

**Current key residents:** Caretaker Lian (ferry), Choir Caretaker Mei (church), Tunnel Guide Ren (Long Shan), Tower Keeper Suyin (Bagua), Dock Musician Pei (ferry), Choir Member Yun (church).

**Design goal:** After the festival performance, each resident should have something new to say that reflects the island's restored state. The dialogue should feel like a coda — warm, brief, not a new quest.

**How:**
- Add `conditional_beats` entries in `game/resident_catalog.gd` (or in `.tres` definition files under `game/residents/definitions/`) with a gate on `melody_state == "resonant"`.
- Each beat should be 1-3 lines of dialogue, no branching.
- Optionally, one resident could hint at a future visit or reference a minor island detail that rewards exploration.

**Files to read first:** `game/resident_catalog.gd` (search `conditional_beats`), `docs/story/summer_of_piano_island_story_framework.md` (resident character notes).

**Validation:** Complete the harbor performance, choose "Stay a Little Longer." Visit each key resident. Verify new dialogue beats fire. Verify they don't fire before `resonant` state.

**Risk:** Very low. Content authoring within existing beat system.

---

### D4. Add optional collectibles (postcards or sound memories)

**Scope:** The design docs (`core_game_workflow.md`) describe optional collectibles — postcards, historical plaques, sheet music scraps, sound memories — as a way to reward exploration of side paths. None currently exist.

**Design decision needed first:** Pick one collectible type for a V1 pass. Recommended: **sound memories** — short ambient recordings tied to specific places. They fit the musical identity and can reuse the landmark cue audio infrastructure.

**How (if sound memories):**
- Define 5-8 collectible `Area2D` triggers placed off the main path (one per district, plus 2-3 hidden ones).
- On inspect, play a short ambient clip (reuse or extend the landmark cue infrastructure) and add a journal entry.
- Track collected count in `AppState`. Display in journal and ending summary.
- Completing all collectibles could improve the Community ending (more NPCs at festival, richer ambient response).

**Files to read first:** `game/landmark_trigger.gd` (reuse pattern for collectible triggers), `docs/core_game_workflow.md` (collectible design notes), `docs/story/summer_of_piano_island_story_framework.md`.

**Deliverable:** Design document first (`docs/features/collectibles.md`), then implementation.

**Risk:** Low. New content layer using existing trigger and journal infrastructure.

---

## Workstream E: Design Decisions (No Code)

These are documented decision points that need human input before implementation.

### E1. Resolve external GDD landmark list

**Status:** Gap #6 in `core_melody_loop.md`. The external GDD proposes Sunlight Rock and Zheng Chenggong Statue as landmarks. The current five-landmark route is canonical and well-tested. Adding or replacing landmarks is a world-design decision, not a code task.

**Decision needed:** Are the external GDD landmarks out of scope permanently, or is there a plan to add them as optional side content? If added, do they carry melody fragments (changing the 4-fragment model) or are they purely cosmetic/lore?

**Impact:** If landmarks are added, update `docs/design_brief.md`, `docs/core_game_workflow.md`, `docs/story/summer_of_piano_island_story_framework.md`, `game/melody_catalog.gd`, and all five landmark feature docs.

---

### E2. Evaluate JSON data migration

**Status:** Gap #7 in `core_melody_loop.md`. The external GDD suggests JSON data files. The project is GDScript catalog-based.

**Decision needed:** Is there authoring-scale pressure that justifies migration? If a non-programmer needs to author resident dialogue or melody definitions, JSON may be justified. If the current GDScript catalogs are sufficient, defer.

**Impact:** If migrated, update `docs/architecture.md`, `docs/contracts.md`, resident/melody catalog ownership.

---

## Workstream F: Story Integration

These tasks integrate the canonical story framework into the current five-landmark melody game without turning the project into a narrative reboot.

### F1. Map the story framework onto the current landmark route

**Scope:** Turn the canonical story framing in `docs/story/summer_of_piano_island_story_framework.md` into concrete content targets for the live playable route.

**Goal:** Make the current game read as a music-centered coming-of-age slice rather than a disconnected quest structure.

**How:**
- Treat the protagonist as someone returning to an emotionally distant home, not as a total outsider.
- Keep the current five-landmark route canonical.
- Map the four emotional lines onto the existing route:
  - Trinity Church -> grandmother, church memory, guilt, grace
  - Bi Shan Tunnel -> buried memory, shame, inward pressure
  - Long Shan Tunnel -> companionship, steadiness, practical care
  - Bagua Tower -> architecture, inheritance, future-facing perspective
  - Piano Ferry -> return, departure, family distance, harbor memory
- Produce a landmark-by-landmark crosswalk for:
  - resident beats to add or rewrite
  - journal text to deepen
  - inspectable objects or cues that should gain emotional meaning
  - ending-summary language or ending-tone emphasis updates

**Files to read first:** `docs/story/summer_of_piano_island_story_framework.md`, `docs/core_game_workflow.md`, `docs/event_story_system_design.md`, `game/resident_catalog.gd`, `game/app_state.gd`.

**Deliverable:** A compact content mapping document or tracked checklist before implementation begins.

**Risk:** Medium. This is where story quality improves or becomes muddled, so the mapping should be explicit before content edits start.

---

### F2. Reframe the opening and first fragment around memory and return

**Scope:** Use the existing opening and Trinity Church arc as the first integrated narrative slice.

**Goal:** Prove that the merged story works without adding home scenes, school scenes, or a new seasonal simulation layer.

**How:**
- Reframe Ferry Plaza as return to a too-quiet island rather than first discovery by a pure outsider.
- Give Caretaker Lian early dialogue or journal support that hints at:
  - changed perspective
  - family distance
  - known-but-distant homecoming
- Make Trinity Church the clearest early expression of:
  - grandmother memory
  - church routine
  - guilt and grace
  - memory returning through ordered listening
- Update the first-fragment reward text so it feels emotionally meaningful, not like a generic token grant.

**Files to read first:** `docs/story/summer_of_piano_island_story_framework.md`, `docs/features/piano_ferry.md`, `docs/features/trinity_church.md`, `game/resident_catalog.gd`, `game/journal_builder.gd`, `game/app_state.gd`.

**Validation:** Play Ferry Plaza through Trinity Church and confirm the landmark still reads cleanly as gameplay while the new emotional framing is legible through resident beats, journal updates, and objective text.

**Risk:** Low-medium. This is the safest place to test the merged story voice because it reuses the existing early-game route.

---

### F3. Deepen the tunnels and finale with emotional emphasis

**Scope:** Extend the new narrative framing across the rest of the route after the opening slice is working.

**How:**
- Use Bi Shan Tunnel to externalize avoided memory and inward disorientation.
- Use Long Shan Tunnel to emphasize trust, companionship, and steadying care.
- Use Bagua Tower to foreground architecture, inheritance, and future-facing perspective.
- Use the harbor finale and ending choice to connect:
  - quiet maturity
  - relationship emphasis
  - inheritance emphasis

**Files to read first:** `docs/story/summer_of_piano_island_story_framework.md`, `docs/features/bi_shan_tunnel.md`, `docs/features/long_shan_tunnel.md`, `docs/features/bagua_tower.md`, `game/resident_catalog.gd`, `ui/screens/ending_overlay.gd`.

**Validation:** Run the full landmark route and confirm each landmark still has a distinct gameplay role while also carrying one major emotional function from the story framework.

**Risk:** Medium. The main failure mode is over-explaining themes instead of letting place and action carry them.

---

### F4. Defer heavier narrative expansion until the current slice is strong

**Scope:** Preserve the current project's exploration-first identity by explicitly deferring larger narrative systems until the landmark route can carry the new framework well.

**Do not implement yet unless the project explicitly chooses a larger rewrite:**
- full home interior scenes
- school as a primary location
- explicit mock-exam systems
- large four-friend scene networks
- fully seasonal chapter simulation

**Why:** The current opportunity is to deepen meaning inside the existing game, not to outrun the codebase with a second game's worth of structure.

**Risk:** Low. This is a planning guardrail, not a coding task.

---

## Task Dependencies

```
Workstream C (integration — some ordering):
  C1 (weather→BGM) — standalone
  C2 (piano free-play) — standalone
  C3 (time-of-day) — standalone, but benefits from C1 being done first

Workstream D (content — mostly parallel):
  D1 (ending summary) — standalone
  D2 (BGM expansion) — benefits from C1 and C3 being done first
  D3 (postgame dialogue) — standalone
  D4 (collectibles) — standalone, design doc first

Workstream E (decisions — no code):
  E1 and E2 are independent design decisions

Workstream F (story integration):
  F1 should happen before F2 and F3
  F2 is the preferred first implementation slice
  F3 should follow after the opening slice reads well
  F4 is a standing scope guardrail

C, D, E, and F are independent at the top level, but F1 should inform any story-facing content work in D3 and D4.
```

## Global Rules

- Read `AGENTS.md` before starting any task.
- Read `docs/contracts.md` before changing shared state, signals, or cross-module interfaces.
- Update `docs/contracts.md`, `docs/architecture.md`, and `docs/module_map.md` when ownership moves.
- Run the cited validation scenes after each task. Do not skip `test_cue_progression.tscn` for any task that touches landmark or melody state.
- Do not introduce mandatory combat, score ranking, or long rhythm-game stages.
- Do not change the canonical five-landmark route without updating `docs/design_brief.md` and `docs/core_game_workflow.md`.
- Prefer GDScript catalogs over JSON data files unless authoring scale justifies migration.
- Treat `docs/story/summer_of_piano_island_story_framework.md` as the only story source of truth.
- Deepen the existing landmark route before introducing heavy home/school/season-simulation systems.
