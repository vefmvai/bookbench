---
description: After a finished or paused book extracts workflow learnings — what worked, what did not, which guideline edits stabilised, which rejections recurred. Reads TUNING-LOG, REJECTIONS-LOG, UPDATE-LOG, STATE.md, current guidelines, audit reports; writes context/learnings.md. Optionally offers to fold global insights into ${CLAUDE_PLUGIN_DATA}/settings.yaml.
argument-hint: ""
allowed-tools: [Task, Read, Write, Bash, AskUserQuestion]
---

# /bookbench:extract-learnings

<purpose>
Help the author look back on the project: what stuck, what got rejected, which patterns recurred, what is worth carrying into the next book. Especially valuable before `/bookbench:archive` or before starting a new book in the same genre.
</purpose>

<!-- ЭТАП 14: реализовано — см. <execution> ниже -->

## Inputs

- `.book/TUNING-LOG.md`, `REJECTIONS-LOG.md`, `UPDATE-LOG.md`, `STATE.md`.
- All `.book/agent-guidelines/<role>/*.md` (current state).
- `.book/context/audit-book-report.md` (if exists).
- All `.book/sections/*/audit-report.md` (if exist).

## Outputs

- `.book/context/learnings.md` — structured learnings document.
- Optional: a follow-up offer to add insights to `${CLAUDE_PLUGIN_DATA}/settings.yaml`.

<execution>

Eight-step pattern with one Task delegation to `book-tuner` in cross-book retrospect mode.

### Step 1 — Pre-flight

```bash
[ -d .book ] || { echo "No .book/ directory."; exit 0; }

# Count sections with edited.md (proxy for "book is done enough to extract learnings")
N_SECTIONS=$(find .book/sections -maxdepth 2 -name 'edited.md' -type f | wc -l | tr -d ' ')
if [ "$N_SECTIONS" -lt 3 ]; then
  echo "Warning: only $N_SECTIONS sections finished — learnings will be thin."
  echo "Recommended: run /bookbench:extract-learnings after >= 3 sections."
fi
```

### Step 2 — Confirmation gate

Present an `AskUserQuestion`:

- Title: «Extract learnings from this book?»
- Body:
  - `Sections with edited.md: <N_SECTIONS>`
  - `Output:                  .book/context/learnings.md`
  - `TUNING-LOG entries:      <count>`
  - `REJECTIONS-LOG entries:  <count>`
  - Note: «Read-only with respect to sections and guidelines. Takes ~2-5 minutes.»
- Options:
  - `Run extraction` — proceed.
  - `Cancel` — exit.

### Step 3 — Pre-aggregate counters

```bash
TUNING_COUNT=$(grep -cE '^- id:' .book/TUNING-LOG.md 2>/dev/null || echo 0)
REJECTIONS_COUNT=$(grep -cE '^- id:' .book/REJECTIONS-LOG.md 2>/dev/null || echo 0)
APPLIED_COUNT=$(grep -cE 'status: applied' .book/TUNING-LOG.md 2>/dev/null || echo 0)
ROLLED_BACK_COUNT=$(grep -cE 'status: rolled-back' .book/TUNING-LOG.md 2>/dev/null || echo 0)
UPDATE_COUNT=$(grep -cE '^## Update on' .book/UPDATE-LOG.md 2>/dev/null || echo 0)
```

### Step 4 — Delegate to book-tuner in retrospect mode

```
Task(
  subagent_type: book-tuner,
  description: "Extract learnings — book retrospect",
  prompt: """
    You are book-tuner in RETROSPECT mode.

    Goal: produce a structured retrospective document at
    .book/context/learnings.md with five sections:

    1. Decisions — major choices made during this book (genre, structure,
       voice, audience, trusted sources). Source: STATE.md history.

    2. Lessons — patterns that emerged. What kind of edits was the author
       repeatedly making? What kind of rejections recurred? Source:
       TUNING-LOG.md, REJECTIONS-LOG.md.

    3. Patterns — guideline changes that stabilised vs got rolled back.
       For each role (writer, factchecker, editor, marketer, ...), list
       the durable guidelines vs the temporary experiments. Source:
       agent-guidelines/<role>/*.md + TUNING-LOG.md status fields.

    4. Surprises — things that did not go as expected. Source: REJECTIONS-LOG
       entries flagged severity=critical or rejection_count_total >= 3.

    5. Recommendations — for the author's next book in the same genre.
       Concrete: «for popular-science books, pre-load these trusted sources»;
       «for the next memoir, avoid X».

    Constraints:
      • Read-only with respect to section content. Do NOT modify any section
        file. You may only WRITE to .book/context/learnings.md.
      • Cite specific TUNING/REJECTIONS ids when referring to past decisions.
      • Be concrete: 1-2 sentence bullets, not paragraphs.

    Use the four-phase Procedure (collect / cluster / prioritise / propose)
    you use in `/bookbench:tune`, but the OUTPUT here is a retrospective, not
    proposals.
  """,
  files_to_read: [
    .book/STATE.md,
    .book/TUNING-LOG.md,
    .book/REJECTIONS-LOG.md,
    .book/UPDATE-LOG.md (if exists),
    .book/context/audit-book-report.md (if exists),
    .book/agent-guidelines/  (all roles, all files),
    .book/config.yaml,
    .book/PROJECT.md
  ]
)
```

### Step 5 — Verify output

```bash
[ -s .book/context/learnings.md ] || {
  echo "Tuner did not write learnings.md. Inspect Task output."
  exit 1
}
N_SECTIONS=$(grep -cE '^## ' .book/context/learnings.md)
[ "$N_SECTIONS" -ge 4 ] || echo "Warning: learnings.md has only $N_SECTIONS sections (expected >=5)."
```

### Step 6 — Optional fold into global settings

If learnings.md contains a section labelled `## Cross-book recommendations` (genre-level patterns), present an `AskUserQuestion`:

- Title: «Fold cross-book recommendations into global settings?»
- Body: «Found N items that look generalisable to other books in genre X. Add to `${CLAUDE_PLUGIN_DATA}/settings.yaml.recommended_for_<genre>`?»
- Options:
  - `Add to global settings` — append to settings.yaml.
  - `Skip` — leave only in learnings.md.

### Step 7 — STATE.md history append

```bash
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
LEARNINGS_LINES=$(wc -l < .book/context/learnings.md)
printf '\n%s — `/bookbench:extract-learnings` — wrote learnings.md (%d lines, %d tuning, %d rejections)\n' \
  "$NOW" "$LEARNINGS_LINES" "$TUNING_COUNT" "$REJECTIONS_COUNT" >> .book/STATE.md
```

### Step 8 — Next-step message

```
Learnings extracted: .book/context/learnings.md ($LEARNINGS_LINES lines)

Recommended next:
  /bookbench:archive             — archive the book (it is finished).
  /bookbench:start               — start the next book; the tuner will use these learnings.
  /bookbench:evolve propose      — (dev-mode) consider folding learnings into plugin defaults.
```

### Constitutional rules

- **MUST** be read-only with respect to sections and guidelines. Only `.book/context/learnings.md` is written.
- **MUST** delegate to `book-tuner` (it is the role with the right system prompt for analysis).
- **MUST** not propose changes to guidelines from this command — that is `/bookbench:tune`.
- **NEVER** invoke `/bookbench:evolve` automatically — the author decides explicitly.
- **NEVER** read inside `sections/*/draft.md` or `factcheck.md` (only `audit-report.md` and aggregate logs).

</execution>
