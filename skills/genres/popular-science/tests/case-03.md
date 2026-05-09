# Popular-science methodology evaluation case 03: forbid math formulas

## Input

A draft chapter that contains LaTeX-style equations and a Python code block.
The skill is invoked during write-time methodology check.

## Expected behaviors

- Skill recognises that `forbid_math_formulas: true` is a popular-science
  invariant.
- Recommends rewriting formulas as analogies (per anti-ai-cliche pattern #37).
- Does NOT silently accept the formulas.

## Acceptance criteria

- Output flags both the LaTeX block and the code block.
- Recommendation references analogy-based rewriting, not just removal.
- Cross-link to anti-ai-cliche pattern #37 is mentioned (or implicit in the
  reasoning).

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Tests genre-parameter enforcement.
