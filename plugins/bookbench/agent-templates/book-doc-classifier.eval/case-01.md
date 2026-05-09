# Case 01: Classify mixed-content imported markdown

## Input

`<files_to_read>` includes a single file `inputs/random-notes.md` containing
six paragraphs:
1. "The book targets readers with a high-school education."
2. "I want the tone to feel like a friend explaining over coffee."
3. "Photosynthesis is the process where plants ..." (definition).
4. "Common myth: plants get all their food from soil. Actually ..."
5. "Calvin cycle was named after Melvin Calvin, 1961 Nobel laureate."
6. "Cool metaphor: a leaf is like a solar panel."

## Expected behaviors

- Reads the input file.
- Splits into 6 fragments (one per paragraph).
- Classifies each into one of 11 classes:
  - 1 → parameter
  - 2 → voice-sample
  - 3 → glossary-term
  - 4 → common-misconception
  - 5 → source (or characters, depending on context)
  - 6 → used-metaphor
- Writes intel/classifications/random-notes.md.json with all 6 fragments,
  each having class, confidence, snippet, context_hint, candidate_target_role.
- Updates fragment_counts_by_class.

## Acceptance criteria

- intel/classifications/random-notes.md.json exists.
- Schema fields all present.
- ≥5 of 6 fragments correctly classified (allowing 1 borderline).
- No interpretation beyond `class + snippet + note`.
- No memory file is touched (classifier has no project memory).

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Tests Procedure CLASSIFY end-to-end. Common failure: writing prose
interpretations into the JSON instead of strict structured fields.
