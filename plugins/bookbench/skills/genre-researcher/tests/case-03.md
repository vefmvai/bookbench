# Genre-researcher evaluation case 03: author rejects the generated preset

## Input

User runs `/bookbench:research-genre memoir`. Skill runs all phases and produces a
preset. At Phase 5 the author rejects it (e.g., "I disagree with the section
structure").

## Expected behaviors

- Skill captures the rejection rationale.
- Per GR-10 fallback "author rejected", offers options:
  (a) refine with one round of dialogue,
  (b) start over with a different research strategy,
  (c) abort and leave only the partial files in pending state.
- Does NOT silently overwrite files based on partial feedback.

## Acceptance criteria

- AskUserQuestion offers all three options.
- Files are NOT written until the author confirms a refined version or aborts.
- If aborted: pending files end up under `pending/` with a marker.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Tests author-rejection fallback. Common failure: skill writes the rejected
preset anyway and asks "are you sure" after the fact.
