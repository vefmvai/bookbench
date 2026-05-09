# Case 03: Red-thread keyword silent for too long

## Input

Coordinator calls strategist for chapter 9. agent-memory/strategist/MEMORY.md
shows red-thread-keyword "framework-thesis" with `silence_streak: 5`
(threshold: 3). Other context files exist as usual.

## Expected behaviors

- Strategist reads memory and detects the silent keyword.
- Writes chapters/009/spec.md normally, AND adds a note in spec.md:
  "Keyword `framework-thesis` did not appear for 5 chapters; consider
  bringing it back in this chapter or the next."
- Updates the red-thread tracking entries in MEMORY.md.

## Acceptance criteria

- spec.md contains an explicit reminder about `framework-thesis`.
- The reminder cites the silence_streak value (5).
- MEMORY.md `silence_streak` for `framework-thesis` is updated based on
  whether the keyword appears in the new chapter or not.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Tests the `last_seen_chapter` / `silence_streak` mechanism for cross-chapter
red-thread cohesion. Common failure mode: ignoring the warning threshold
or hallucinating a different keyword.
