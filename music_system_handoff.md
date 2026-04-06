# Kulangsu Music System — Handoff for New Chat

Read `AGENTS.md` first, then `docs/design_brief.md`, then `docs/features/core_melody_loop.md`, then this file.

## Project Context

Kulangsu is a calm exploration game set on Kulangsu island (Godot 4 / GDScript). The player arrives by ferry, explores five landmarks, recovers four melody fragments from a lost festival tune, performs a harbor-stage finale, and chooses whether to leave or stay.

All seven MVP steps are complete: melody catalog, five landmark arcs with LandmarkTrigger nodes, journal with melody tab, practice/performance prompts, persistent world response, save/continue. The core gameplay loop works end-to-end as a text-based experience.

## Current Music System — What Actually Exists

### Melody Catalog (`game/melody_catalog.gd`)
- Single melody defined: `festival_melody` (island-wide)
- Four fragments mapped to landmarks: `church_bells` (Trinity Church), `bi_shan_echo` (Bi Shan Tunnel), `long_shan_route` (Long Shan Tunnel), `tower_chamber` (Bagua Tower)
- Ferry plaza has a non-fragment source: `ferry_plaza` (Harbor Refrain)

### Melody State Machine (`game/app_state.gd`)
- Per-melody runtime state: `{ state, fragments_found, fragments_total, known_sources, next_lead, performed }`
- Tier progression: `unknown → heard (1+ fragment) → reconstructed (2+ fragments) → performed (harbor performance success) → resonant (postgame only)`
- Signals: `melody_progress_changed`, `melody_hint_shown`, `melody_prompt_requested`, `fragments_changed`
- Full autosave/restore of melody state

### Performance System (`ui/screens/melody_prompt_overlay.gd`)
- Text-based ordered-confirmation prompts at each landmark and the festival stage
- Player selects fragment labels in correct order — no timing, no rhythm, no audio
- Wrong answers clear softly with retry hint
- Trinity Church: order `steps → garden → yard`; Festival stage: order all four fragments

### Resident Integration (`game/resident_catalog.gd`)
- 20+ residents with `melody_hint` text strings (narrative color, no mechanical links to melody_id)
- Hints emitted via `melody_hint_shown` signal, displayed as HUD text
- Examples: "She hears the melody as climbing notes that only align from above"

### Piano Game (`game/piano_game/`)
- Complete standalone rhythm-game prototype with lane-based note spawning, beat detection, scoring
- Loads `resources/audio/music/summer_of_qin_dao.mp3` + JSON beat chart
- NOT connected to `main.tscn`, `app_state.gd`, HUD, or story progression
- Design doc explicitly calls it "a self-contained authoring sandbox, not a finished player-facing mode"

### Audio Assets
- `resources/audio/music/summer_of_piano_island.mp3` (6.2 MB) — NOT used anywhere
- `resources/audio/music/summer_of_qin_dao.mp3` (4.6 MB) — only used by piano game prototype
- `resources/audio/sfx/marble_hit.mp3` (20 KB) — marble game only
- NO AudioStreamPlayer nodes in `main.tscn` or `game_main.tscn`
- NO ambient music, no landmark motifs, no melody fragment audio clips

### `resonant` State
- Set when player chooses "Stay a Little Longer" from ending overlay
- Seeds all landmarks to `reward_collected`, residents to trust level 2
- Changes journal practice button text from "Practice" to "Replay"
- NO island-side world response mechanics, NO audio changes, NO visual effects, NO new NPC interactions

## The Core Gap

The game's identity is "piano island" but there is no audio in the player's experience. All melody discovery, reconstruction, and performance is text-based. The design docs describe music as a "world-language" that players discover before it gets named — but the auditory implementation is entirely absent.

## Design Review Findings

### Strengths
- Complete end-to-end loop with all five landmark arcs
- Clean verb set (walk, hear, inspect, talk, trace, help, perform, resolve)
- Each landmark has a distinct gameplay mix (church=social, Bi Shan=spatial, Long Shan=relational, Bagua=vertical)
- Elegant tier model with explicit restraint on `resonant`
- No-punishment failure/recovery philosophy

### Open Issues
1. **No audio at all** — island exploration happens in silence
2. **`resonant` has no meaningful content** — label without payoff
3. **Relationship layer is thin** — mostly binary trust, unclear how it grades the ending
4. **Three endings need more separation** — currently differ only by NPC count at festival and final dialogue
5. **Piano game's role in main loop is undefined** — side attraction or core performance mechanic?
6. **Long Shan escort mechanic** — companion pacing/emotional feedback not specified beyond checkpoints

## Recommended Implementation Layers

### Layer 1 — Ambient Audio (highest impact, lowest risk)
- Add `AudioStreamPlayer` to `game_main.tscn` with a calm looping track
- Two existing MP3s available as placeholders (`summer_of_piano_island.mp3`, `summer_of_qin_dao.mp3`)
- No melody-state integration needed — just fills the silence

### Layer 2 — Per-Landmark Audio Cues (medium effort, grounds the "hear" verb)
- Create short audio clips per landmark (bell motif, reverb echo, piano phrase, etc.)
- Wire to `LandmarkTrigger` enter/exit signals or `melody_hint_shown`
- Makes "hear a clue before you name it" design pillar actually work

### Layer 3 — Piano Game Integration (high effort, optional)
- Wire existing piano game as alternative performance backend for festival finale
- Connect to `AppState.melody_prompt_requested`, feed correct beat chart, return success/failure
- Could also serve as optional free-play station at ferry plaza
- Docs already note this as a "later candidate"

### For `resonant` specifically
- Cheapest meaningful change: ambient track shifts or gains a layer in postgame
- One unique postgame dialogue line per resident (currently fallback "calm" text)
- One small visual change per landmark (lit window, glow, flag)
- Goal: make the island feel like it *remembers* what the player did

## Key Files to Read

| File | Purpose |
|---|---|
| `docs/design_brief.md` | Game identity, player loop, UI direction |
| `docs/core_game_workflow.md` | Full story flow, landmark arcs, ending states |
| `docs/core_gameplay_plays.md` | Eight core plays, district profiles, beat structure |
| `docs/features/core_melody_loop.md` | MVP steps, gap list, data structures, validation routes |
| `game/melody_catalog.gd` | Melody definitions (75 lines) |
| `game/app_state.gd` | Melody runtime state, signals, autosave (~2,290 lines) |
| `game/resident_catalog.gd` | Resident definitions with melody hints (~1,000 lines) |
| `ui/screens/melody_prompt_overlay.gd` | Ordered-confirmation performance UI |
| `ui/screens/journal_overlay.gd` | Journal melody tab rendering |
| `game/piano_game/piano_game.gd` | Standalone rhythm-game prototype (32 KB) |
| `game/piano_game/beat_json_generator.gd` | Audio analysis / beat detection tool (16 KB) |
| `docs/piano_game_design.md` | Piano game design and integration guidance |
| `docs/features/practice_system.md` | Practice tier model and prompt design |
| Landmark feature docs in `docs/features/` | Per-landmark arc details (piano_ferry, trinity_church, bi_shan_tunnel, long_shan_tunnel, bagua_tower) |

## Pending Git State

Commit `e059cd63` ("Finish Step 4: confirm trigger collision layers, fix Bagua Tower z_index, move player to ferry") is on local `main` HEAD. Push command: `cd ~/kulangsu && rm -f .git/index.lock && git push origin main`. A stale `.git/index.lock` (0-byte, from SmartGit) may need removal first.
