# Eval case 02 — pattern promotion to upgrade-candidates.md

> Verifies that `book-observer` promotes a recurring signal to
> `upgrade-candidates.md` only when it appears ≥3 times across distinct
> sections.

## Setup

`.book/ops-observations/` already contains process-notes from earlier
sections that recorded a recurring complaint:

### `section-1-process-notes.md`

Contains a Friction event:
- pattern: "editor aggressively rewrites the writer's voice on each pass"
- affected_role: book-editor
- impact: revise loop, token waste

### `section-2-process-notes.md`

Same pattern recorded again:
- pattern: "editor aggressively rewrites the writer's voice on each pass"
- affected_role: book-editor
- impact: revise loop, token waste

### `section-3-process-notes.md`

Same pattern recorded a third time:
- pattern: "editor aggressively rewrites the writer's voice on each pass"
- affected_role: book-editor
- impact: revise loop, token waste

### `rawlog.jsonl` (current session, section 4)

Mock event stream confirms a fourth occurrence of the same pattern:
multiple Task calls to `book-editor` with `tool_status:"ok"` followed by
a `UserPromptSubmit` event whose paraphrased content is
"the editor is rewriting the writer's voice again, please rein it in".

## Expected observer output

### Section 4 notes

`section-4-process-notes.md` records the fourth occurrence with the
same `pattern` text.

### `upgrade-candidates.md`

The observer **promotes** this pattern, since occurrences across
distinct sections now equals 4 (≥3 threshold met). Append-only YAML
entry:

```yaml
- id: uc-0001
  first_seen: 2026-05-07T08:00:00Z
  last_seen: 2026-05-07T11:00:00Z
  category: quality-regression
  severity: medium
  occurrences: 4
  signal_pattern: |
    Editor agent overrides the writer's voice on each revise pass.
    Recurs across multiple sections; suggests insufficient guidance
    in agent-guidelines/editor/author-deviations.md or in the
    writer's voice-samples that the editor consults.
  affected_role: book-editor
  affected_step: edit
  suggested_fix: |
    Tighten editor's allowed-edit scope: limit edits to grammar,
    typography, and red-thread checks only; treat voice deviations
    as warnings, not edits. May require an additional knob in
    .book/agent-guidelines/editor/voice-policy.md.
  related_decisions: []
  status: candidate
```

## Acceptance criteria

- The fourth occurrence is recorded in `section-4-process-notes.md`.
- The pattern is promoted to `upgrade-candidates.md` exactly once
  (idempotency test: second invocation must NOT create a duplicate
  uc-0001 entry; instead it updates `last_seen` and `occurrences`).
- The candidate has `category: quality-regression`, since it concerns
  the editor catching issues in a way that creates revise loops, not
  pure token waste.
- `severity: medium` is appropriate; `high` reserved for ≥7
  occurrences or for entries with severe blocking impact.
- Privacy self-check: clean. No book-specific terminology in
  `signal_pattern` or `suggested_fix` (the eval uses generic
  workflow vocabulary).

## Pass / fail

- **PASS** if `upgrade-candidates.md` contains exactly one new entry
  with the expected fields after the first invocation, AND zero new
  entries (only an update) after the second invocation.
- **FAIL** if a duplicate entry is appended OR if the entry is missing
  OR if the category/severity is wrong.

## Privacy gate

`signal_pattern` and `suggested_fix` use only generic vocabulary:
"editor", "writer", "voice", "revise pass". No character names, no
genre-specific thematic terms, no quotes from the author.
