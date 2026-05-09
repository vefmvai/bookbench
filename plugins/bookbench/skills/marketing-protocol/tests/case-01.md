# Marketing-protocol evaluation case 01: SUCCESs framework primary attribute

## Input

A chapter where the central thesis hinges on a counter-intuitive fact (e.g.,
"plants spend more energy on respiration than on photosynthesis at night").

## Expected behaviors

- Skill helps marketer pick `Unexpected` as SUCCESs primary.
- Recommends a hook formulation that leans on the unexpected fact.
- Avoids `Concrete` if it has been used 5+ times recently.

## Acceptance criteria

- SUCCESs_primary set to `Unexpected`.
- Hook foregrounds the counter-intuitive element.
- No SUCCESs_primary repetition beyond `overuse_threshold`.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Tests SUCCESs framework selection.
