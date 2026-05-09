# Case 01: Compose spec.md for a chapter on a generic topic

## Input

Coordinator calls strategist with `<files_to_read>`:
- chapters/004/ does not exist yet
- agent-guidelines/strategist/README.md (with default contents)
- context/parameters.md (genre: popular-science, target-length: ~3500 words)
- context/red-thread-keywords.md
- context/glossary.md
- chapters/003/summary.md (previous chapter)
- agent-memory/strategist/MEMORY.md (with one prior chapter template
  used twice in a row: "TED-3-act")

Prompt: "Plan chapter 4 — topic 'Photosynthesis: how plants harvest light'.
Continues from chapter 3 (basics of cell biology)."

## Expected behaviors

- Reads guidelines via index-driven protocol (README first, then referenced files).
- Reads context, prior summary, own memory.
- Writes chapters/004/spec.md with all required sections: frontmatter,
  goals (≥2 bullets), hook strategy with technique chosen, three theses,
  expected word count, red-thread positioning, callback to chapter 3,
  S-NNN locked decisions, NEEDS_FACTCHECK markers (≥1 for a science topic).
- Selects a chapter_template DIFFERENT from "TED-3-act" (since memory shows
  consecutive_with_same is at threshold).
- Updates strategist/MEMORY.md: appends concept entries, plot connector,
  template usage, red-thread tracking deltas.
- Returns a one-paragraph summary to coordinator.

## Acceptance criteria

- chapters/004/spec.md exists with frontmatter and required sections.
- chapter_template ≠ "TED-3-act".
- ≥1 [NEEDS_FACTCHECK] block.
- "Связка с предыдущей главой" callbacks chapter-3 by name.
- agent-memory/strategist/MEMORY.md has ≥3 new entries.
- No mentor-mode tokens appear in spec.md.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Tests Procedure FORM-SPEC end-to-end with the consecutive-template variation
rule and the cross-chapter cohesion rule.
