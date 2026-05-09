# Case 01: Write a fresh draft for a science chapter

## Input

Coordinator calls writer for chapter 4. `<files_to_read>` contains:
- chapters/004/spec.md (3 theses about photosynthesis, hook technique:
  "scene-opener", expected_word_count: 3500, ≥1 [NEEDS_FACTCHECK] block).
- agent-guidelines/writer/{voice-samples, forbidden-phrases, favorite-metaphors}.md.
- context/voice-profile.md, glossary.md.
- chapters/003/summary.md (cell biology basics).
- agent-memory/writer/MEMORY.md (metaphor family "voting" used 7 times,
  threshold 8 — already near saturation).

## Expected behaviors

- Reads all files via index-driven protocol.
- Validates spec.md frontmatter and required sections.
- Plans the hook (scene-opener, varying from previous 2-3 chapters).
- Plans metaphors avoiding "voting" family or using a radically different
  vehicle within it.
- Writes chapters/004/draft.md with frontmatter (chapter_id, created_by,
  created, last_updated, revision_iteration: 0, word_count, metaphor_families_used,
  opening_hook_technique, shitty_first_draft_ratio).
- Preserves [NEEDS_FACTCHECK] markers from spec.md in the draft.
- PostToolUse anti-ai-cliche-lint hook fires; writer responds to any block hits
  by rewriting and re-Writing.
- Updates writer/MEMORY.md (Used metaphors, Concrete examples, Opening hooks,
  Family-level metaphor index).
- Returns a one-paragraph summary to coordinator.

## Acceptance criteria

- chapters/004/draft.md exists with full frontmatter.
- word_count is within ±10% of expected_word_count.
- No body of text uses the "voting" family unless the vehicle is markedly new.
- ≥1 [NEEDS_FACTCHECK] preserved.
- agent-memory/writer/MEMORY.md updated with at least: 1 hook entry,
  1+ metaphor entries, 1+ concrete-example entries, family index incremented.
- No mentor-mode tokens; no AI-cliche block patterns.

## Target models

- claude-haiku-4-5 (smoke test)
- claude-sonnet-4-6 (default)
- claude-opus-4-7 (quality bar)

## Notes

End-to-end test of Procedure WRITE-DRAFT including memory protocol and hook
interaction. Failure modes: family overuse, missing [NEEDS_FACTCHECK],
hook techniques repeated three chapters in a row, no MEMORY updates.
