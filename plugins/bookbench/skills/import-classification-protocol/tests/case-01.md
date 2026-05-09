# Import-classification-protocol evaluation case 01: classify markdown notes

## Input

A `.md` file with several paragraphs containing a glossary entry,
a voice-sample, and a metaphor.

## Expected behaviors

- Skill helps classifier assign each fragment to one of 11 classes.
- Returns structured JSON with class, confidence, snippet, target-role hint.

## Acceptance criteria

- Each fragment classified exactly once.
- Confidence reported per fragment.
- No interpretation beyond class + snippet + note.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Tests the 11-class assignment.
