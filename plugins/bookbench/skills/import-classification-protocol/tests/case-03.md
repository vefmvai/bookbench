# Import-classification-protocol evaluation case 03: low-confidence borderline

## Input

A fragment that could plausibly belong to two classes
(e.g., "Use simple language for general public" — could be
parameter or voice-sample).

## Expected behaviors

- Skill assigns the most likely class.
- Sets `confidence: low` or `medium`.
- Includes a brief `note` explaining the choice.

## Acceptance criteria

- Confidence is non-high.
- Note is present and concrete.
- Synthesizer is left enough information to escalate to author if needed.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Tests honest uncertainty signalling.
