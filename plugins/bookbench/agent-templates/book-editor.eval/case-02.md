# Case 02: Skill-mode review (consistency-check) writes a separate review file

## Input

Coordinator calls editor in skill-mode `consistency-check` for chapter 4.
Inputs:
- chapters/004/edited.md.
- skill `consistency-check` is active.
- agent-guidelines/editor/, context/cross-references.md.

## Expected behaviors

- Editor activates the consistency-check skill.
- Reads edited.md and applies the skill's checklist.
- Writes chapters/004/reviews/consistency-check.md with frontmatter
  (review_type, skill_used, issues_found, severity_distribution).
- Body lists each issue with line numbers and severity.
- Does NOT modify edited.md in this mode.
- Returns: "consistency-check review of chapter 4: K issues, severity {...}".

## Acceptance criteria

- chapters/004/reviews/consistency-check.md created.
- chapters/004/edited.md is byte-identical to the version before skill-mode call.
- Each issue has severity (high/medium/low).

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Tests Procedure SKILL-MODE-REVIEW. Common failure: editing edited.md anyway
because the model "wants to apply the findings".
