# Factcheck-protocol evaluation case 02: weasel phrase without source

## Input

Draft contains: "Studies show that most people retain 20% of what they read."
No source is attached.

## Expected behaviors

- Skill flags the vague-attribution.
- Recommends one of: provide source, hedge ("according to <author>"), or
  remove.
- Tags the claim `[UNVERIFIABLE]`.

## Acceptance criteria

- Claim labeled `[UNVERIFIABLE]`.
- Recommendation lists at least three options for the writer.
- The vague phrase is logged in `Vague-attributions log` of factchecker MEMORY.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Mirrors anti-ai-cliche pattern #5 but at the protocol level.
