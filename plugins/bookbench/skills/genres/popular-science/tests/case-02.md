# Popular-science methodology evaluation case 02: 5 mixed parameters

## Input

The same spec as case-01 but with the author's overrides on 2 of the 5
mixed parameters (e.g., "use_anecdotes: false", "target_word_count: 4500").

## Expected behaviors

- Skill respects the author overrides.
- Sets the remaining 3 mixed parameters from genre defaults.
- Reports which values came from overrides vs defaults.

## Acceptance criteria

- 5 mixed parameters set; 2 from override, 3 from default.
- Output explicitly tags origin (override / default).

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Tests the override / default cascade.
