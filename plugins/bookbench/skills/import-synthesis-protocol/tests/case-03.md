# Import-synthesis-protocol evaluation case 03: conflict with rejected source

## Input

Classifier output contains `class: source` pointing to a magazine article.
factchecker/MEMORY.md `Outdated/rejected sources` already has this magazine
listed as unreliable.

## Expected behaviors

- Skill maps to factchecker MEMORY.
- Conflict-check finds the rejected entry.
- Sets `action: conflict` with `conflict_with: <rejected-id>`.
- Author must explicitly approve the import (override).

## Acceptance criteria

- INGEST-DECISIONS entry has `action: conflict`.
- conflict_with names the rejected entry id.
- Rationale ≤200 chars and explains the conflict.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Tests conflict-with-negative-list path.
