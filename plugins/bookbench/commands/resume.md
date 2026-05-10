---
description: Resumes work on the current book after a pause. Reads STATE.md and recent section summaries, recaps the last session, lists open items (revise loops, unresolved variants, debug sessions) and proposes the next concrete step.
argument-hint: ""
allowed-tools: [Read, Edit, Bash, Glob, Grep]
---

# /bookbench:resume

<purpose>
Re-enter the project after a break — give the author a short situational briefing and a recommended next command.
</purpose>

<!-- ЭТАП 13: реализовано — см. <execution> ниже -->

## Inputs

- `.book/STATE.md`, `.book/ROADMAP.md`.
- Last 3 entries in `.book/sections/<id>/summary.md` (the most recent section only).
- Active debug sessions in `.book/debug/`.
- `INGEST-DECISIONS.md` if any unresolved competing-variants exist.

## Outputs

- Verbal briefing on stdout.
- (PS-13-03) `.book/STATE.md.last_action` is updated with `resume` and a new History line.

<execution>

This command is a short read + brief. PS-13-03: a very small write is allowed (one history line + `last_action`). This is not a full subagent call; it is a coordinator-style briefing.

### Step 1 — Detect book

```bash
[ -d .book ] || {
  echo "No .book/ directory. Run /bookbench:start to initialise a book here."
  exit 0
}
```

### Step 2 — Read state

Read:

- `.book/STATE.md` — `current_section`, `current_section`, `last_action`, last 3 History entries.
- `.book/ROADMAP.md` — count of planned sections (best-effort).

```bash
LAST_HISTORY=$(grep -E '^[0-9]{4}-' .book/STATE.md | tail -n 3 || true)
CURRENT_SECTION=$(awk -F'`' '/current_section/{print $3; exit}' .book/STATE.md | sed -E 's/^: //; s/^[[:space:]]+//; s/[[:space:]]+$//')
LAST_ACTION=$(awk -F'`' '/last_action/{print $3; exit}' .book/STATE.md | sed -E 's/^: //; s/^[[:space:]]+//; s/[[:space:]]+$//')
PLANNED_SECTIONS=$(grep -cE '^## (Section|Раздел)' .book/ROADMAP.md 2>/dev/null || echo 0)
```

### Step 3 — Read latest section context (if any)

If `CURRENT_SECTION` is non-empty, normalise to a section folder name (`section-${N}` where `${N}` is zero-padded to three digits):

```bash
if [ -n "$CURRENT_SECTION" ]; then
  N=$(printf '%s' "$CURRENT_SECTION" | sed -E 's/[^0-9]//g')
  PADDED=$(printf '%03d' "$N" 2>/dev/null || echo "$N")
  CHDIR=".book/sections/section-${PADDED}"
  if [ -d "$SECDIR" ]; then
    LOOP_COUNT=$(awk '/^loop_count:/{print $2; exit}' "$SECDIR/section-state.yaml" 2>/dev/null || echo 0)
    PHASE=$(awk '/^phase:/{print $2; exit}' "$SECDIR/section-state.yaml" 2>/dev/null || echo unknown)
    COMPLETED=$(awk '/^completed:/{print $2; exit}' "$SECDIR/section-state.yaml" 2>/dev/null || echo false)
    SUMMARY_HEAD=$(head -n 12 "$SECDIR/summary.md" 2>/dev/null || true)
  fi
fi
```

### Step 4 — Active debug

```bash
DEBUG_FILES=$(ls .book/debug/ 2>/dev/null | head -n 5 || true)
DEBUG_COUNT=$(ls .book/debug/ 2>/dev/null | wc -l | tr -d ' ' || echo 0)
```

### Step 5 — Pending INGEST-DECISIONS

```bash
PENDING_INGEST=0
if [ -f .book/INGEST-DECISIONS.md ]; then
  PENDING_INGEST=$(grep -cE '^- \[ \]' .book/INGEST-DECISIONS.md || echo 0)
fi
```

### Step 6 — Compose briefing

Print 5–12 lines, neutral partner tone. Recommendation logic (Trigger → Action):

- If `PLANNED_SECTIONS == 0` → recommend `/bookbench:plan-book`.
- Else if no `sections/section-*` directories — recommend `/bookbench:plan-section 1`.
- Else if `CURRENT_SECTION` set and `COMPLETED == false` and `PHASE` known — recommend resuming the appropriate phase. The phase-to-command mapping:
  - `planning|spec-review` → `/bookbench:plan-section ${N}` (re-run / continue spec).
  - `writing|factcheck|editing|reviewing` → `/bookbench:write-section ${N}` (the coordinator will pick up at the right phase based on which artefacts exist).
  - `marketing|review|approval-pending` → `/bookbench:write-section ${N}` (coordinator finalises).
  - `done` → recommend `/bookbench:audit-section ${N}` or `/bookbench:plan-section $((N+1))`.
- Else if `CURRENT_SECTION` set and `COMPLETED == true` — recommend `/bookbench:plan-section $((N+1))`.
- If `PENDING_INGEST > 0` — add a separate line: «You have ${PENDING_INGEST} pending ingest decisions in INGEST-DECISIONS.md».

Sample format:

```
Resume — "${BOOK_TITLE}"
  Last action: ${LAST_ACTION}
  Last 3 history entries:
    <line 1>
    <line 2>
    <line 3>

Current section: ${CURRENT_SECTION:-none}
  Phase:        ${PHASE:-n/a}
  Loop count:   ${LOOP_COUNT:-n/a}
  Completed:    ${COMPLETED:-n/a}

${PENDING_INGEST > 0 ? "Pending ingest decisions: ${PENDING_INGEST}" : ""}
${DEBUG_COUNT > 0 ? "Active debug sessions: ${DEBUG_COUNT}" : ""}

Recommended next:
  ${RECOMMENDED_COMMAND}    — ${ONE_LINE_REASON}
```

### Step 7 — Append a `resume` history line (PS-13-03)

This is the only mutation. Edit `.book/STATE.md`:

- Update the `last_action: ` line in the «Current» section to `last_action: resume`.
- Append a new History line: `<ISO 8601> — /bookbench:resume — printed briefing`.

Use the Edit tool (replace `last_action:` line) and Bash append (for History) to keep the change minimal.

### Constitutional rules for this command

- **MUST** print the briefing even if `current_section` is `null`.
- **MUST** finish in ≤ 3 seconds on a small book.
- **MUST** make exactly one append to `STATE.md`. No other mutations.
- **NEVER** open section draft.md or edited.md (that would inflate context). Only the section-state.yaml + summary.md (head 12 lines).
- **NEVER** call any subagent.

</execution>
