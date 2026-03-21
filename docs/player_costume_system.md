# Kulangsu Player Appearance And Costume System

Read [`docs/design_brief.md`](docs/design_brief.md) first for the project summary. This doc covers the current wardrobe slice and the intended direction for future player cosmetic work.

## Goals

- Let the player define a personal body, gender presentation, skin tone, and hair before arriving on the island.
- Keep costumes as a calm flavor-and-identity system, not stat gear.
- Reuse the existing `HumanBody2D` and Universal LPC layering pipeline instead of creating a second avatar renderer.
- Let story progress and resident trust unlock new looks without adding inventory bookkeeping.
- Keep character setup and wardrobe browsing inside the existing shell UI so appearance changes feel lightweight and reversible.

## Current Implementation

### Base Appearance Catalog

- Curated base appearance options live in [`game/player_appearance_catalog.gd`](game/player_appearance_catalog.gd).
- The current profile supports:
  - body frame
  - gender presentation
  - skin tone
  - hair style
  - hair color
- These options are intentionally curated instead of exposing every raw LPC sheet, which keeps the combinations readable and known-good.

### Costume Catalog

- Static costume definitions live in [`game/player_costume_catalog.gd`](game/player_costume_catalog.gd).
- Each entry defines:
  - display name
  - short summary
  - unlock route text
  - costume-layer sprite selections that are merged on top of the player profile

The prototype wardrobe currently ships with four presets:

- `Harbor Arrival`
- `Choir Visit`
- `Tunnel Weather`
- `Festival Evening`

### Runtime Wardrobe State

- [`game/app_state.gd`](game/app_state.gd) now stores:
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
- Regenerating Universal LPC metadata is a development-time workflow driven by the validation tooling under [`../scenes/test_universal_lpc_sprite_generator.tscn`](../scenes/test_universal_lpc_sprite_generator.tscn), not a runtime game step.
- [`../characters/human_body_2d.gd`](../characters/human_body_2d.gd) remains the root avatar node and owns the material/shader setup for the composed character.
- [`../characters/universal_lpc/universal_lpc_sprite_2d.gd`](../characters/universal_lpc/universal_lpc_sprite_2d.gd) handles metadata-driven layer composition under `HumanBody2D`.
- Animation authoring for this slice should stay within the shipped default LPC animation set and any explicitly supported custom animation layouts captured in the prebuilt metadata.

### Player Application

- [`main.gd`](main.gd) listens for `AppState.player_appearance_changed`.
- The active player `HumanBody2D` receives the new appearance config immediately through `set_configuration`.
- This keeps the overworld avatar, journal state, and future save data aligned around one source of truth.

### Start-Of-Game Character Setup

- [`ui/screens/player_customization_overlay.gd`](ui/screens/player_customization_overlay.gd) and [`ui/screens/player_customization_overlay.tscn`](ui/screens/player_customization_overlay.tscn) now provide a setup overlay before `New Game` and `Free Walk`.
- The overlay currently supports:
  - body
  - gender
  - skin tone
  - hair style
  - hair color
  - a live player preview
- [`ui/app_flow_root.gd`](ui/app_flow_root.gd) now routes new runs through this setup step before gameplay begins.

### Journal Wardrobe Flow

- [`ui/screens/journal_overlay.gd`](ui/screens/journal_overlay.gd) and [`ui/screens/journal_overlay.tscn`](ui/screens/journal_overlay.tscn) now include a `Wardrobe` tab.
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
- New appearance content should assume prebuilt metadata and existing runtime animation support, not on-demand metadata generation in the shipped game.

## Good Next Steps

1. Add small wardrobe unlock feedback when a new look becomes available after a resident beat.
2. Save both the player profile and the equipped costume in real save data once persistence exists beyond the current prototype session.
3. Add separate in-game controls for skin tone or body changes only if the project wants that flexibility after arrival.
