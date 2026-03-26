# Kulangsu Player Appearance And Costume System

Read [`design_brief.md`](design_brief.md) first for the project summary. This doc covers the current wardrobe slice and the intended direction for future player cosmetic work.

## Goals

- Let the player define a personal body, gender presentation, skin tone, and hair before arriving on the island.
- Keep costumes as a calm flavor-and-identity system, not stat gear.
- Reuse the existing `HumanBody2D` and Universal LPC layering pipeline instead of creating a second avatar renderer.
- Let story progress and resident trust unlock new looks without adding inventory bookkeeping.
- Keep character setup and wardrobe browsing inside the existing shell UI so appearance changes feel lightweight and reversible.

## Current Implementation

### Base Appearance Catalog

- Curated base appearance options live in [`../game/player_appearance_catalog.gd`](../game/player_appearance_catalog.gd).
- The current profile supports:
  - body frame
  - gender presentation
  - skin tone
  - hair style
  - hair color
- These options are intentionally curated instead of exposing every raw LPC sheet, which keeps the combinations readable and known-good.

### Costume Catalog

- Static costume definitions live in [`../game/player_costume_catalog.gd`](../game/player_costume_catalog.gd).
- Each entry defines:
  - display name
  - short summary
  - unlock route text
  - costume-layer sprite selections that are merged on top of the player profile
- New costumes are not complete until their id is also added to the catalog order and unlock logic in [`../game/player_costume_catalog.gd`](../game/player_costume_catalog.gd).

The prototype wardrobe currently ships with four presets:

- `Harbor Arrival`
- `Choir Visit`
- `Tunnel Weather`
- `Festival Evening`

### Runtime Wardrobe State

- [`../game/app_state.gd`](../game/app_state.gd) now stores:
  - the player profile
  - unlocked costume ids
  - currently equipped costume id
  - the resolved player appearance config used by the live avatar
- The final avatar is composed from:
  - base profile selections from the appearance catalog
  - costume selections from the wardrobe catalog
- Costume unlocks are recalculated whenever mode, fragment progress, or resident trust changes.
- If the currently equipped look becomes invalid for the new state, the system falls back to the default arrival outfit automatically.

### Universal LPC Runtime Contract

- The shipped game consumes the prebuilt metadata file at [`../resources/sprites/universal_lpc/universal_lpc_metadata.json`](../resources/sprites/universal_lpc/universal_lpc_metadata.json).
- Regenerating Universal LPC metadata is a development-time workflow driven by the validation tooling under [`../characters/universal_lpc/tests/test_universal_lpc_sprite_generator.tscn`](../characters/universal_lpc/tests/test_universal_lpc_sprite_generator.tscn), not a runtime game step.
- [`../characters/human_body_2d.gd`](../characters/human_body_2d.gd) remains the root avatar node and owns the material/shader setup for the composed character.
- [`../characters/universal_lpc/universal_lpc_sprite_2d.gd`](../characters/universal_lpc/universal_lpc_sprite_2d.gd) handles metadata-driven layer composition under `HumanBody2D`.
- Animation authoring for this slice should stay within the shipped default LPC animation set and any explicitly supported custom animation layouts captured in the prebuilt metadata.
- [`../characters/human_body_2d.gd`](../characters/human_body_2d.gd) currently auto-drives idle, walk, run, and jump presentation from movement state; custom animation layouts still require an explicit gameplay/UI caller that sets the active animation name.

### Player Application

- [`../scenes/game_main.gd`](../scenes/game_main.gd) listens for `AppState.player_appearance_changed`.
- The active player `HumanBody2D` receives the new appearance config immediately through `set_configuration`.
- This keeps the overworld avatar, journal state, and future save data aligned around one source of truth.

### Start-Of-Game Character Setup

- [`../ui/screens/player_customization_overlay.gd`](../ui/screens/player_customization_overlay.gd) and [`../ui/screens/player_customization_overlay.tscn`](../ui/screens/player_customization_overlay.tscn) now provide a setup overlay before `New Game` and `Free Walk`.
- The overlay currently supports:
  - body
  - gender
  - skin tone
  - hair style
  - hair color
  - a live player preview
- [`../main.gd`](../main.gd) now routes new runs through this setup step before gameplay begins.

### Journal Wardrobe Flow

- [`../ui/screens/journal_overlay.gd`](../ui/screens/journal_overlay.gd) and [`../ui/screens/journal_overlay.tscn`](../ui/screens/journal_overlay.tscn) now include a `Wardrobe` tab.
- The tab shows:
  - a live player preview
  - current look
  - current body / gender / hair summary
  - unlocked count
  - all known costume entries with status and unlock route
  - `Previous Look` / `Next Look` controls for cycling unlocked presets
  - hair style and hair color controls for in-game updates

This keeps the feature overlay-based and consistent with the project’s minimal HUD direction.

## Unlock Rules

- `Harbor Arrival` is always available.
- `Choir Visit` unlocks after earning trust with Choir Caretaker Mei.
- `Tunnel Weather` unlocks after helping Tunnel Guide Ren or restoring two melody fragments.
- `Festival Evening` unlocks once the full melody is restored.
- `Free Walk` exposes the whole wardrobe for sandbox browsing.
- `Postgame` keeps the full wardrobe available, including the festival outfit.

## Design Rules

- Initial character setup should stay curated and legible rather than becoming a raw asset browser.
- In-story costume changes should remain preset looks, not combinatorial paper-doll editing.
- Unlocks should read as gifts, local borrowing, or story recognition rather than loot drops.
- Wardrobe text should stay short enough to scan in the journal without feeling like a spreadsheet.
- New outfits should use asset paths already supported by the shipped Universal LPC metadata unless the sprite pipeline is intentionally expanded.
- A valid-looking LPC path is not enough on its own; the shipped metadata must support the requested body types and color/variant choices for that path.
- New appearance content should assume prebuilt metadata and existing runtime animation support, not on-demand metadata generation in the shipped game.

## Adding New Content

### New Costume Preset

1. Add the costume entry and selection map in [`../game/player_costume_catalog.gd`](../game/player_costume_catalog.gd).
2. Add the costume id to `ORDER` so journal cycling and unlocked-list ordering stay deterministic.
3. Update `is_costume_unlocked(...)` so the preset can actually become available in story mode, free walk, or postgame.
4. Keep the unlock hint text aligned with the real unlock rule so the journal stays trustworthy.
5. Before shipping the preset, confirm each selected LPC path supports the body types and variants the player can actually reach with that costume.

### New Base Appearance Option

1. Add the curated option in [`../game/player_appearance_catalog.gd`](../game/player_appearance_catalog.gd).
2. Confirm the referenced LPC path and variant already exist in the shipped metadata at [`../resources/sprites/universal_lpc/universal_lpc_metadata.json`](../resources/sprites/universal_lpc/universal_lpc_metadata.json).
3. Confirm the path also supports the intended `body_type` values for that option set; some shipped LPC entries only support a subset of male/female/teen variants.
4. If the change introduces a brand new profile field instead of a new option value, update the `AppState` getters/cyclers plus both customization surfaces in [`../ui/screens/player_customization_overlay.gd`](../ui/screens/player_customization_overlay.gd) and [`../ui/screens/journal_overlay.gd`](../ui/screens/journal_overlay.gd).

### New LPC Asset Or Animation Support

1. Prefer reusing paths and variants already present in the shipped metadata.
2. If new metadata must be generated, treat that as development tooling work and revalidate the shipped JSON before relying on the new content in gameplay.
3. Do not assume metadata alone makes a custom animation playable in the game; add or update an explicit runtime trigger path when the feature needs one.

## Validation

- Start a new run or free walk and confirm the setup overlay preview updates correctly for every changed profile field.
- Open the journal wardrobe tab and confirm the preview, labels, unlocked count, and costume cycling reflect the new content.
- Validate the live overworld avatar through the main project flow so `AppState.player_appearance_changed` still updates the active player immediately.
- If unlock rules changed, confirm both the locked and unlocked states read correctly in the journal text.
- If new LPC assets or animations were introduced, use [`../characters/universal_lpc/tests/test_universal_lpc_sprite_generator.tscn`](../characters/universal_lpc/tests/test_universal_lpc_sprite_generator.tscn) or another focused validation scene before relying on the full game flow.
- Treat `Failed to resolve combined texture for selection layer` warnings as content bugs. They usually mean the chosen path, body type, or variant is unsupported by the shipped metadata.

## Good Next Steps

1. Add small wardrobe unlock feedback when a new look becomes available after a resident beat.
2. Save both the player profile and the equipped costume in real save data once persistence exists beyond the current prototype session.
3. Add separate in-game controls for skin tone or body changes only if the project wants that flexibility after arrival.
