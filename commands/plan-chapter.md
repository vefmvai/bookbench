---
description: Runs Phase 1 (book-strategist) plus the spec gate for chapter N. Creates chapters/<id>/spec.md and asks the author to approve. Does not start writing — that is the job of /book:write-chapter.
argument-hint: "<chapter-number>"
allowed-tools: [Task, Read, Write, Edit, AskUserQuestion]
---

# /book:plan-chapter

<purpose>
Generate the chapter specification (`spec.md`) for chapter N — a structural ToR — without proceeding into the rest of the micro-cycle.
</purpose>

<!-- ЭТАП 13: реализовано — см. <execution> ниже -->

## Inputs

- `<chapter-number>` (positional argument).
- Existing `chapters/<id>/spec.md` (if present, asks: overwrite, create v2, show current).
- `.book/ROADMAP.md`, `.book/PROJECT.md`, `.book/config.yaml`.
- `.book/context/{red-thread-keywords, parameters, voice-profile, target-audience, common-misconceptions}.md`.
- `.book/agent-guidelines/strategist/`.
- `.book/.claude/agent-memory/strategist/MEMORY.md`.
- `.book/chapters/<previous-id>/summary.md` (cross-chapter context budget).

<execution>

This command implements Phase 1 (strategist) + Phase 1g (spec gate) of the chapter micro-cycle. PS-13-02 says when `spec.md` is missing for `/book:write-chapter`, refuse with a hint (rather than auto-call); here we are the source of `spec.md`.

### Step 1 — Validate argument

```bash
ARG="$ARGUMENTS"
[ -z "$ARG" ] && { echo "Usage: /book:plan-chapter <chapter-number>"; exit 0; }
N=$(printf '%s' "$ARG" | sed -E 's/[^0-9]//g')
[ -z "$N" ] && { echo "Chapter number must be an integer ≥ 1."; exit 0; }
[ "$N" -lt 1 ] 2>/dev/null && { echo "Chapter number must be ≥ 1."; exit 0; }
PADDED=$(printf '%03d' "$N")
CHDIR=".book/chapters/chapter-${PADDED}"
echo "N=$N PADDED=$PADDED CHDIR=$CHDIR"
```

### Step 2 — Pre-flight book state

```bash
[ -d .book ] || { echo "No .book/. Run /book:start."; exit 0; }
[ -f .book/ROADMAP.md ] || { echo ".book/ROADMAP.md is missing. Run /book:plan-book first."; exit 0; }
PLANNED=$(grep -cE '^## (Chapter|Глава)' .book/ROADMAP.md || echo 0)
[ "$PLANNED" -lt "$N" ] && {
  echo "ROADMAP has only $PLANNED planned chapters; you asked for $N."
  echo "Either /book:plan-book to extend, or pass a smaller chapter number."
  exit 0
}
```

### Step 3 — Existing chapter folder

```bash
EXISTS=0
[ -d "$CHDIR" ] && EXISTS=1
HAS_SPEC=0
[ -s "$CHDIR/spec.md" ] && HAS_SPEC=1
COMPLETED=false
[ -f "$CHDIR/chapter-state.yaml" ] && COMPLETED=$(awk '/^completed:/{print $2; exit}' "$CHDIR/chapter-state.yaml" || echo false)
```

If `COMPLETED == true` — present an `AskUserQuestion`:

- Title: «Chapter ${N} is already completed»
- Options: `Re-plan (back up the current spec)` / `Show current spec` / `Cancel`.
- On `Cancel` — exit. On `Show` — print head 40 lines of `spec.md`, then re-ask. On `Re-plan` — back up:

```bash
TS=$(date -u +%Y%m%dT%H%M%SZ)
mkdir -p "$CHDIR"
cp "$CHDIR/spec.md" "$CHDIR/spec-prev-${TS}.md" 2>/dev/null || true
cp "$CHDIR/chapter-state.yaml" "$CHDIR/chapter-state-prev-${TS}.yaml" 2>/dev/null || true
```

If `HAS_SPEC == 1 && COMPLETED == false` — `AskUserQuestion`: `Overwrite (back up current)` / `Show current` / `Cancel`.

### Step 4 — Scaffold chapter folder

```bash
if [ ! -d "$CHDIR" ]; then
  mkdir -p "$CHDIR"
  cp -R .book/chapters/.template/. "$CHDIR/"
  # Patch chapter-state.yaml with chapter_id, created
  NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  sed -i.bak -E "s/^chapter_id: TBD/chapter_id: chapter-${PADDED}/" "$CHDIR/chapter-state.yaml"
  sed -i.bak -E "s/^created: TBD/created: ${NOW}/" "$CHDIR/chapter-state.yaml"
  sed -i.bak -E "s/^last_phase_change: TBD/last_phase_change: ${NOW}/" "$CHDIR/chapter-state.yaml"
  rm -f "$CHDIR/chapter-state.yaml.bak"
fi
```

### Step 5 — Compose `<files_to_read>` for `book-strategist`

Per `context-control.md` § 2.1 (strategist budget 15–50 KB). Include:

```
${CHDIR}/chapter-state.yaml
.book/ROADMAP.md
.book/PROJECT.md
.book/config.yaml
.book/context/parameters.md
.book/context/red-thread-keywords.md
.book/context/glossary.md
.book/context/target-audience.md
.book/context/voice-profile.md
.book/context/common-misconceptions.md
```

If `${CHDIR}/spec.md` already exists (revise mode) — also include `${CHDIR}/spec.md` plus the author note.

If `${PREV_PADDED}` chapter directory exists, also include:

```
.book/chapters/chapter-${PREV_PADDED}/summary.md
```

If `${PREV_PADDED-2}` chapter directory exists, optionally also `.book/chapters/chapter-${PREV2_PADDED}/summary.md` (≤ 2 KB each).

If `.book/.claude/agent-memory/strategist/MEMORY.md` exists, include it.

If `.book/agent-guidelines/strategist/README.md` exists, include it.

### Step 6 — Call the strategist via `Task`

Single Task invocation:

- `subagent_type`: `book-strategist`
- `description`: `Form spec.md for chapter ${N}`
- `prompt`: structured instruction:

  ```
  You are book-strategist for /book:plan-chapter ${N}.

  Mode: ${MODE}    # one of: fresh | revise (when spec.md exists)
  Author note (if revise): "${AUTHOR_NOTE}"

  Required output: ${CHDIR}/spec.md

  Mandatory sections of spec.md (per artifact-protocol.md § 3.2 and book-strategist
  Procedure FORM-SPEC):
    - YAML frontmatter (chapter_id, created_by, created, chapter_template,
      expected_word_count, red_thread_keywords, locked_decisions, prerequisites).
    - "# ТЗ главы ${N}: <title>" or "# Chapter ${N} spec: <title>"
    - "## Goals" (bullets)
    - "## Hook strategy"
    - "## Three key theses" (1, 2, 3)
    - "## Expected length"
    - "## Locus in red thread"
    - "## Connection to previous chapter"
    - "## Decisions for this chapter (S-NNN)"
    - "## Factcheck hints" (with [NEEDS_FACTCHECK] markers if relevant)
    - "## Spec completion checklist"

  Constraints:
    - Use ROADMAP.md as the authoritative source for the chapter title and thesis.
    - Use red-thread-keywords.md to choose 2–3 keywords for this chapter.
    - expected_word_count: read from .book/config.yaml.writing.chapter_target_chars (or
      override from .book/context/parameters.md).
    - Do not write the chapter body; this is the writer's job. Just the spec.
    - Do not verify facts. If you mark [NEEDS_FACTCHECK] — that is a hint to the factchecker,
      not an admission of doubt.

  After writing the file, return a 5-line summary. Do not return the full spec body.
  ```

- `files_to_read`: list from Step 5.

### Step 7 — Verify outputs

```bash
[ -s "$CHDIR/spec.md" ] || { echo "Strategist did not write spec.md"; exit 1; }
# Required sections (heuristic checks — substring match)
for section in '## Goals' '## Цели' '## Hook' '## Hook-стратегия' '## Three key theses' '## 3 ключевых тезиса'; do
  : # noop — strategist may use either Russian or English headings; we accept both
done
# Minimal acceptance: file > 500 bytes and contains chapter_id frontmatter
test "$(wc -c < "$CHDIR/spec.md")" -gt 500 || { echo "spec.md is too short"; exit 1; }
grep -qE '^chapter_id:' "$CHDIR/spec.md" || { echo "spec.md frontmatter missing chapter_id"; exit 1; }
echo "spec.md verified."
```

If verification fails — `AskUserQuestion` with `retry` / `inspect` / `cancel`.

### Step 8 — Spec gate (Phase 1g)

Read `${CHDIR}/spec.md` (head 80 lines). Show the author a compact summary:

```
Chapter ${N} spec ready.
  Template:    <chapter_template>
  Words:       <expected_word_count>
  Hook:        <one-line description>
  Three theses:
    1. <thesis 1>
    2. <thesis 2>
    3. <thesis 3>
  Connection to previous: <one line or "none">
  NEEDS_FACTCHECK markers: K
```

`AskUserQuestion`:

- Title: «Spec for chapter ${N}»
- Options:
  - `Accept (move to writing)` — proceed to Step 9.
  - `Refine (give guidance)` — follow up free-text; back-up current spec; re-call strategist in revise mode.
  - `Reject (cancel)` — exit; do not update STATE.

For stage 13 refine runs at most once per command invocation.

### Step 9 — Atomic state update

On `Accept`:

```bash
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
# Patch chapter-state.yaml
sed -i.bak -E "s/^phase: .*/phase: spec-review/" "$CHDIR/chapter-state.yaml"
sed -i.bak -E "s/^last_phase_change: .*/last_phase_change: ${NOW}/" "$CHDIR/chapter-state.yaml"
rm -f "$CHDIR/chapter-state.yaml.bak"

# Patch .book/STATE.md
sed -i.bak -E "s/^- \`current_section\`:.*/- \`current_section\`: chapter_loop/" .book/STATE.md
sed -i.bak -E "s/^- \`current_chapter\`:.*/- \`current_chapter\`: chapter-${PADDED}/" .book/STATE.md
sed -i.bak -E "s/^- \`last_action\`:.*/- \`last_action\`: plan-chapter ${N} accepted/" .book/STATE.md
rm -f .book/STATE.md.bak
printf '\n%s — `/book:plan-chapter %s` — spec accepted (chapter-%s)\n' "$NOW" "$N" "$PADDED" >> .book/STATE.md
```

### Step 10 — Next-step message

```
Spec for chapter ${N} accepted: ${CHDIR}/spec.md

Recommended next:
  /book:write-chapter ${N}    — run the full 5+1-phase micro-cycle.
  /book:plan-chapter ${N+1}   — pre-plan the next chapter (optional).
```

### Constitutional rules for this command

- **MUST** validate the chapter number is a positive integer.
- **MUST** call `book-strategist` exactly once (plus at most one revise call).
- **MUST** pass an explicit `<files_to_read>` block bounded by per-role budget.
- **MUST** never proceed to writing — that is `/book:write-chapter`.
- **NEVER** call `book-writer`, `book-factchecker`, `book-editor`, `book-marketer` from this command.

</execution>
