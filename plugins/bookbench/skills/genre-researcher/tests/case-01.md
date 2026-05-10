# Genre-researcher evaluation case 01: research a generic detective genre

## Input

User runs `/bookbench:research-genre detective`. The genre is not in the built-in
presets. WebSearch is available.

## Expected behaviors

- Skill runs Phase 1 (genre profiling) — asks 5-10 short questions to the
  author about subgenre, audience, tone.
- Phase 2 (deep research) — collects sources from the 5 mandatory categories
  (books on the genre, author guides, essays by published authors, academic
  articles, GitHub projects); ≥5 sources by default.
- Phase 3 (methodology generation) — fills 8 variables and 5 mixed parameters
  per `invariants_vs_variables.md`.
- Phase 4 (workflow generation) — maps to catalog-30 blocks.
- Phase 5 (validation) — runs the 5-level validation pipeline.
- Outputs:
  `${CLAUDE_PLUGIN_DATA}/user-presets/detective.yaml`,
  `${CLAUDE_PLUGIN_DATA}/user-methodologies/detective.md`.

## Acceptance criteria

- Both output files exist and parse as valid YAML / Markdown.
- Methodology references concrete sources (not "according to research").
- Workflow uses block names from catalog-30, not invented ones.
- 5-level validation passed (logged inline).

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Headline test for the researcher. Common failure: hallucinated sources or
invented block names.
