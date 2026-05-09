# Import-classification-protocol evaluation case 02: chat-export JSON

## Input

A JSON file exported from a chat tool. Contains 50+ messages alternating
user / model.

## Expected behaviors

- Skill parses by reply.
- Filters out conversational filler (greetings, follow-up questions
  without content) into `class: other`.
- Classifies content-bearing replies into the 11 classes.

## Acceptance criteria

- ≥90% of greeting / filler messages → class `other`.
- Classified content fragments have plausible classes.
- No fragments classified twice.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Tests format-handling for chat exports.
