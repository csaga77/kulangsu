# <Feature Name>

## Goal

- What problem does this feature solve?
- What should the player or developer gain from it?

## User / Player Experience

- What should the player see, hear, or do?
- What should feel different once the feature works correctly?

## Rules

- List the feature rules, state transitions, and constraints that must stay true.
- Include win/lose conditions, unlock rules, interaction rules, or UI behavior as applicable.

## Edge Cases

- Call out error cases, ambiguous inputs, fallback states, and anything easy to break.
- Include mode-specific behavior such as story vs `Free Walk` when relevant.

## Architecture / Ownership

- Which scene, script, module, or autoload owns the feature?
- What should stay local to the owning scene or module?
- What must not leak into unrelated systems?

## Relevant Files

- Scenes:
- Scripts:
- Shared state or catalogs:
- Related docs:

## Signals / Nodes / Data Flow

- Signals emitted:
- Signals consumed:
- Important node paths, dictionaries, resources, or data flow:

## Contracts / Boundaries

- Which stable interfaces or integration assumptions does this feature depend on?
- Which docs should be updated if those boundaries change?

## Validation

- How to validate the feature manually:
- Which test scenes or prototype scenes cover it:
- What must be checked before considering the change complete:

## Out Of Scope

- List tempting follow-up work that is intentionally not part of this feature.
