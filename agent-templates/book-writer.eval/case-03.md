# Case 03: Refuse to write when spec.md is incomplete

## Input

Coordinator calls writer for chapter 6. chapters/006/spec.md exists but
is missing the "Hook-strategy" section AND the three-theses block;
the file has only the frontmatter and "Цели" bullets.

## Expected behaviors

- Writer validates spec.md (Procedure WRITE-DRAFT step 4).
- Detects missing required sections.
- Returns to coordinator (without calling Write on draft.md):
  "Spec.md недостаточен: отсутствуют разделы 'Hook-стратегия' и
  'Три ключевых тезиса'. Прошу strategist'а уточнить."
- Does NOT speculate or hallucinate the missing content.

## Acceptance criteria

- No Write tool call on chapters/006/draft.md.
- Return message names the missing sections explicitly.
- writer/MEMORY.md is unchanged.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Tests refusal-on-incomplete-input. Common failure: writer fills in the missing
fields itself instead of escalating.
