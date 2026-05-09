# Voice-profile evaluation case 01: extract author voice from samples

## Input

`agent-guidelines/writer/voice-samples.md` containing 3 short author writing
samples (~500 words each). The skill is consulted to characterise the voice.

## Expected behaviors

- Skill produces a voice profile with concrete attributes:
  rhythm, sentence length distribution, favourite constructions, taboo
  constructions, typography preferences (em-dash usage etc.).
- Each attribute is backed by one or two example sentences from samples.

## Acceptance criteria

- Profile has ≥4 concrete attributes.
- Each attribute cites at least one sample.
- No invented attributes ("the author always X" without an example).

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Tests evidence-bound profiling.
