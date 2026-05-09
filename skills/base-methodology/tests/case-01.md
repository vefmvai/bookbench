# Base-methodology evaluation case 01: invariants are present in any chapter

## Input

A draft.md from a hypothetical popular-science chapter on photosynthesis,
roughly 3000 words.

## Expected behaviors

- Skill is consulted by writer / editor.
- Output identifies whether the chapter satisfies the 23 base-methodology
  invariants (concrete-anchor frequency, hook structure, hedging discipline,
  registry uniqueness, ...).
- Returns a structured list of findings, not free-form prose.

## Acceptance criteria

- ≥1 explicit invariant referenced by name in the response.
- For each invariant flagged as failing, a concrete line / paragraph cited.
- No invented invariants outside the 23 documented ones.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Tests that the skill stays within its 23-invariant scope.
