# Popular-science methodology evaluation case 01: 8 variables filled

## Input

A section spec for a popular-science section on a generic topic. The skill
is invoked to set 8 genre variables (target audience level, density of
analogies, factcheck rigour, ...).

## Expected behaviors

- Skill outputs concrete values for all 8 variables.
- Each value cites the genre default and any deviation from defaults.

## Acceptance criteria

- All 8 variables have non-default-only values.
- Reasoning for each variable is short and concrete.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Smoke test for the methodology contract from stage 02 / 03.
