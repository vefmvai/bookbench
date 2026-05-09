# Case 03: Ambiguous fragment lands in `other` with a note

## Input

`<files_to_read>` includes inputs/notes.md with one paragraph:
"Maybe we should talk about how the framework handles failure cases.
Or maybe that goes in the appendix."

This is meta-commentary, not content of the book.

## Expected behaviors

- Reads the fragment.
- Recognises that none of the 10 specific classes fit.
- Assigns `class: other` with a `note: "meta-commentary on book structure"`.
- `confidence: medium` (or low, depending on calibration).
- Writes the JSON.

## Acceptance criteria

- The fragment appears in JSON with `class: other`.
- `note` field is non-empty and explains why.
- No interpretive text in the JSON beyond the note field.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Tests honest "I don't know" behavior. Common failure: forcing the fragment
into a wrong class to avoid `other`.
