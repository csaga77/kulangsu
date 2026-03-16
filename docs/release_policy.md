# Kulangsu Release Policy

This file documents the current release and versioning practice for this repository based on what is actually checked in today.

## Current State

- The primary branch is currently `main`.
- No tagged release history is present in the root repository.
- No CI/CD or automated release workflow is checked in at the root.
- No export automation or packaged build script is checked in at the root.
- Submodule revisions are versioned by the parent repo commit that pins each submodule pointer.

## Practical Versioning Rules

- Treat the root repo commit as the authoritative version snapshot of the playable project.
- Treat each submodule pointer change as part of the versioned state of the root repo.
- Do not imply semantic-version or release-tag guarantees unless the repo starts using them explicitly.

## Release Governance

When preparing a milestone, demo, or shareable project snapshot:

1. Confirm the intended root commit.
2. Confirm all required submodule pointers are at the intended commits.
3. Run the project or the most relevant validation scenes for the changed systems.
4. Call out any unverified areas explicitly if full validation was not possible.

## What Counts As A Release-Significant Change

- changes to startup flow or the main playable path
- changes to shared state contracts
- changes to submodule pointers that affect runtime behavior or tooling
- changes to feature rules that affect player-facing behavior

## Documentation Expectations

Update this file when:

- the repo adopts tags, release branches, CI/CD, or export automation
- submodule pinning policy changes
- release preparation expectations change materially
