# Base-methodology evaluation case 02: genre overlay does not break invariants

## Input

The same draft as case-01, but loaded together with a genre-specific
methodology skill (e.g., popular-science).

## Expected behaviors

- Skill output names which findings come from base-methodology vs which come
  from the overlaid genre methodology.
- Overlay parameters (e.g. specific word-count target) do not silence
  invariants.

## Acceptance criteria

- Findings clearly attributed: base-methodology vs genre methodology.
- No invariants are suppressed by genre parameters.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Tests the invariant / variable contract from stage 02.
