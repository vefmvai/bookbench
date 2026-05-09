# Case 01: Base-mode edit pass with -10% target

## Input

Coordinator calls editor in base-mode for section 4 after factcheck `pass`.
Inputs:
- sections/004/draft.md (3450 words).
- sections/004/factcheck.md (status: pass).
- context/voice-profile.md, cross-references.md.
- sections/003/summary.md.
- agent-guidelines/editor/{cohesion-rules, author-deviations}.md
  (author-deviations: "do not merge short paragraphs; preserve em-dash usage").
- agent-memory/editor/MEMORY.md (with two recent voice decisions and 5
  prior anti-cliche occurrences).

## Expected behaviors

- Reads guidelines via index-driven protocol; honors author-deviations.
- Applies four levels of edit (structure → paragraphs → sentences → words).
- Does NOT merge short paragraphs (per author-deviations).
- Does NOT alter em-dash typography (per author-deviations).
- Reduces word count by ~10% (target: ~3105 words; ±5% acceptable).
- Writes sections/004/edited.md with full frontmatter (created_by,
  draft_word_count, edited_word_count, delta_pct, target_met,
  anti_cliche_occurrences, voice_decisions_count, cohesion_callbacks,
  needs_recheck_blocks).
- Includes `## Deviation log` and `## Voice decisions` sections.
- PostToolUse hook fires; double-pass anti-cliche self-check.
- Updates editor/MEMORY.md.
- Returns one-paragraph summary.

## Acceptance criteria

- edited.md exists with frontmatter.
- delta_pct between -7% and -13%; target_met set accordingly.
- Short paragraphs not merged; em-dash usage preserved.
- Deviation log lists each non-trivial change with line numbers.
- editor/MEMORY.md has new entries (cohesion-rule occurrences, anti-cliche
  occurrences, voice decisions).
- No Edit on factcheck.md or draft.md.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

Tests Procedure EDIT-SECTION end-to-end with author-deviations honored.
Common failures: merging short paragraphs anyway, missing Deviation log.
