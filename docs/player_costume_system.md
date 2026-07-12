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
- Body frame and presentation stay curated.
- Skin tone now exposes the full shared LPC-safe palette supported by the player body, neutral face, and both human head shapes.
- Hair style now exposes every shipped standalone LPC hair layer that fully supports the project's player body types and required runtime rows, while still excluding child-only, unmapped, or partially missing definitions.
- Hair color now exposes the full shared LPC-safe palette used across those supported hair styles.

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

- The reusable runtime, metadata, asset, and tooling contract is owned by the plugin's [`contract.md`](../addons/universal_lpc/docs/contract.md); selection, generation, validation, and attribution guidance is owned by [`authoring.md`](../addons/universal_lpc/docs/authoring.md).
- [`../characters/human_body_2d.gd`](../characters/human_body_2d.gd) remains the root avatar node and owns the material/shader setup for the composed character.
- [`../addons/universal_lpc/universal_lpc_sprite_2d.gd`](../addons/universal_lpc/universal_lpc_sprite_2d.gd) handles metadata-driven layer composition under `HumanBody2D`.
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
- Setup changes now stay in a local draft until the player confirms, so `Back` returns to title without mutating the live profile.
- The setup preview always shows the default `Harbor Arrival` starting look instead of whichever costume happened to be equipped in the previous session.
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

## Design Rules

- Initial character setup should stay legible even though hair style now exposes the full player-safe shipped LPC hair list.
- In-story costume changes should remain preset looks, not combinatorial paper-doll editing.
- Unlocks should read as gifts, local borrowing, or story recognition rather than loot drops.
- Wardrobe text should stay short enough to scan in the journal without feeling like a spreadsheet.
- Validate new LPC selections, variants, body-type coverage, and animation rows through the plugin-owned [`authoring.md`](../addons/universal_lpc/docs/authoring.md) workflow before they land in a Kulangsu catalog.
- New appearance content should assume prebuilt metadata and existing runtime animation support, not on-demand metadata generation in the shipped game.

## Adding New Content

### New Costume Preset

1. Add the costume entry and selection map in [`../game/player_costume_catalog.gd`](../game/player_costume_catalog.gd).
2. Add the costume id to `ORDER` so journal cycling and unlocked-list ordering stay deterministic.
3. Update `is_costume_unlocked(...)` so the preset can actually become available in story mode or free walk.
4. Keep the unlock hint text aligned with the real unlock rule so the journal stays trustworthy.
5. Before shipping the preset, validate its LPC selections through [`authoring.md`](../addons/universal_lpc/docs/authoring.md).

### New Base Appearance Option

1. Add the option in [`../game/player_appearance_catalog.gd`](../game/player_appearance_catalog.gd). Hair styles should stay aligned with the full shipped set of player-safe standalone LPC hair definitions unless the project intentionally returns to a smaller curated subset.
2. Validate the referenced LPC selection, variant, body types, and required animation rows through [`authoring.md`](../addons/universal_lpc/docs/authoring.md).
3. If the change introduces a brand new profile field instead of a new option value, update the `AppState` getters/cyclers plus both customization surfaces in [`../ui/screens/player_customization_overlay.gd`](../ui/screens/player_customization_overlay.gd) and [`../ui/screens/journal_overlay.gd`](../ui/screens/journal_overlay.gd).

### New LPC Asset Or Animation Support

Follow the plugin-owned [`authoring.md`](../addons/universal_lpc/docs/authoring.md) workflow. If the feature needs a new animation, Kulangsu must still add or update an explicit gameplay/UI trigger after the addon metadata and sprite rows validate.

## Validation

- Start a new run or free walk and confirm the setup overlay preview updates correctly for every changed profile field.
- Change setup options, press `Back`, reopen the setup overlay, and confirm the original live profile is restored until `Begin Story` or `Enter Free Walk` is pressed.
- Open the journal wardrobe tab and confirm the preview, labels, unlocked count, and costume cycling reflect the new content.
- Validate the live overworld avatar through the main project flow so `AppState.player_appearance_changed` still updates the active player immediately.
- If unlock rules changed, confirm both the locked and unlocked states read correctly in the journal text.
- If LPC selections, assets, or animations changed, complete the plugin-owned [`authoring.md`](../addons/universal_lpc/docs/authoring.md) validation workflow before relying on the full game flow.
- Use [`../ui/screens/tests/test_player_customization_overlay.tscn`](../ui/screens/tests/test_player_customization_overlay.tscn) to regression-test draft setup behavior and confirm that setup only commits on confirm.

## Good Next Steps

1. Add small wardrobe unlock feedback when a new look becomes available after a resident beat.
2. Save both the player profile and the equipped costume in real save data once persistence exists beyond the current prototype session.
3. Add separate in-game controls for skin tone or body changes only if the project wants that flexibility after arrival.
